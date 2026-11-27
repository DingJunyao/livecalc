"""将根目录 app-info.json 中的版本号同步到各包元数据文件。"""

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
APP_INFO_PATH = ROOT / "app-info.json"
FRONTEND_PACKAGE = ROOT / "frontend" / "package.json"
FRONTEND_LOCK = ROOT / "frontend" / "package-lock.json"
BACKEND_PYPROJECT = ROOT / "backend" / "pyproject.toml"
MOBILE_PUBSPEC = ROOT / "mobile" / "pubspec.yaml"
# 移动端运行时也要展示应用身份/链接，随包分发一份（由本脚本从根 app-info.json 生成）
MOBILE_APP_INFO = ROOT / "mobile" / "assets" / "app_info.json"


def _read_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def _write_json(path: Path, data: dict) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def main() -> None:
    version = _read_json(APP_INFO_PATH)["version"]

    for path in (FRONTEND_PACKAGE, FRONTEND_LOCK):
        data = _read_json(path)
        data["version"] = version
        packages = data.get("packages")
        if isinstance(packages, dict) and "" in packages:
            packages[""]["version"] = version
        _write_json(path, data)

    pyproject = BACKEND_PYPROJECT.read_bytes().decode("utf-8")
    pyproject = re.sub(
        r'(?m)^(version = ")[^"]*(")',
        rf"\g<1>{version}\g<2>",
        pyproject,
        count=1,
    )
    BACKEND_PYPROJECT.write_bytes(pyproject.encode("utf-8"))

    # 移动端：Flutter 版本格式为 <semver>+<build>，保留既有 build 号（发版时自行递增）
    pubspec = MOBILE_PUBSPEC.read_text(encoding="utf-8")
    match = re.search(r"(?m)^version:\s*[^+\n]+\+(\d+)\s*$", pubspec)
    build = match.group(1) if match else "1"
    pubspec = re.sub(
        r"(?m)^version:\s*\S+\s*$",
        f"version: {version}+{build}",
        pubspec,
        count=1,
    )
    MOBILE_PUBSPEC.write_bytes(pubspec.encode("utf-8"))

    # 移动端内置 app-info（离线也能显示作者/链接/版本）
    app_info = _read_json(APP_INFO_PATH)
    app_info["version"] = version
    MOBILE_APP_INFO.parent.mkdir(parents=True, exist_ok=True)
    _write_json(MOBILE_APP_INFO, app_info)

    print(
        f"Synced version {version} to frontend/package.json, frontend/package-lock.json, "
        f"backend/pyproject.toml, mobile/pubspec.yaml (+{build}), mobile/assets/app_info.json"
    )


if __name__ == "__main__":
    main()
