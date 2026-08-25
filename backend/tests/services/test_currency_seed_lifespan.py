"""验证 ensure_currencies 在启动时无条件执行（不被 first_run_init_recipes 卡住）。"""
from pathlib import Path

MAIN_PY = Path(__file__).resolve().parents[2] / "app" / "main.py"


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def test_ensure_currencies_not_nested_in_first_run_else():
    src = MAIN_PY.read_text(encoding="utf-8")
    lines = src.splitlines()

    if_line = next(i for i, ln in enumerate(lines) if "settings.first_run_init_recipes" in ln and "if " in ln)
    comment_line = next(i for i, ln in enumerate(lines) if "确保币种字典完整" in ln and i > if_line)
    try_line = next(i for i in range(comment_line + 1, len(lines)) if lines[i].strip() == "try:")
    ensure_line = next(i for i, ln in enumerate(lines) if "ensure_currencies(db)" in ln)

    assert ensure_line > if_line, "ensure_currencies 调用应在 first_run 判断之后"
    assert ensure_line == try_line + 2, "ensure_currencies 应紧跟 try: 块内（try/import 两行之后）"
    assert _indent(lines[try_line]) == _indent(lines[if_line]), (
        f"ensure_currencies 的 try 块须在 first_run if/else 之外（缩进 {_indent(lines[try_line])} "
        f"应等于 if 缩进 {_indent(lines[if_line])}），当前嵌在条件块内——非首次启动库会跳过 seed"
    )
