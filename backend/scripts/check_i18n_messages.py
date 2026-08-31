#!/usr/bin/env python3
"""Check backend exception messages against both translation catalogs."""

from __future__ import annotations

import argparse
import ast
from dataclasses import dataclass
from pathlib import Path
import sys


BACKEND_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROOT = BACKEND_ROOT / "app"
CATALOG_PATHS = {
    "en_US": BACKEND_ROOT / "app" / "locales" / "en_US" / "LC_MESSAGES" / "messages.po",
    "ar": BACKEND_ROOT / "app" / "locales" / "ar" / "LC_MESSAGES" / "messages.po",
}
CHECKED_CALLS = {
    "HTTPException",
    "AppException",
    "LocalizedHTTPException",
    "LocalizedAppException",
}


@dataclass(frozen=True)
class Issue:
    file: str
    line: int
    kind: str
    msgid: str
    detail: str = ""


def _has_chinese(value: str) -> bool:
    return any("\u4e00" <= char <= "\u9fff" for char in value)


def _parse_po_msgids(path: Path) -> set[str]:
    msgids: set[str] = set()
    parts: list[str] | None = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("msgid "):
            parts = [line[6:].strip()]
            continue
        if line.startswith("msgstr"):
            if parts:
                try:
                    msgid = "".join(ast.literal_eval(part) for part in parts)
                except (SyntaxError, ValueError):
                    msgid = ""
                if msgid:
                    msgids.add(msgid)
            parts = None
            continue
        if parts and line.startswith('"'):
            parts.append(line)

    return msgids


def _call_name(node: ast.Call) -> str | None:
    if isinstance(node.func, ast.Name):
        return node.func.id
    if isinstance(node.func, ast.Attribute):
        return node.func.attr
    return None


def _message_node(node: ast.Call, name: str) -> ast.expr | None:
    keyword_names = {"detail", "message"}
    for keyword in node.keywords:
        if keyword.arg in keyword_names:
            return keyword.value

    if name in {"AppException", "LocalizedAppException"} and node.args:
        return node.args[0]

    if name in {"HTTPException", "LocalizedHTTPException"} and len(node.args) > 1:
        return node.args[1]

    return None


def _node_has_chinese(node: ast.AST) -> bool:
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return _has_chinese(node.value)

    if isinstance(node, ast.JoinedStr):
        return any(
            isinstance(value, ast.Constant)
            and isinstance(value.value, str)
            and _has_chinese(value.value)
            for value in node.values
        )

    if isinstance(node, ast.BinOp):
        return _node_has_chinese(node.left) or _node_has_chinese(node.right)

    if isinstance(node, ast.Call):
        if isinstance(node.func, ast.Attribute) and node.func.attr == "format":
            return _node_has_chinese(node.func.value)
        return any(_node_has_chinese(arg) for arg in node.args)

    if isinstance(node, ast.FormattedValue):
        return _node_has_chinese(node.value)

    return False


def _dynamic_reason(node: ast.AST) -> str:
    if isinstance(node, ast.JoinedStr):
        return "f-string"
    if isinstance(node, ast.BinOp):
        return "concatenation"
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
        return ".format"
    if isinstance(node, ast.Name):
        return "named dynamic string"
    return "dynamic string"


def inspect_file(path: Path, msgids_by_language: dict[str, set[str]]) -> list[Issue]:
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"))
    except SyntaxError:
        return []

    issues: list[Issue] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue

        name = _call_name(node)
        if name not in CHECKED_CALLS:
            continue

        message_node = _message_node(node, name)
        if message_node is None:
            continue

        if isinstance(message_node, ast.Constant) and isinstance(message_node.value, str):
            msgid = message_node.value
            if not _has_chinese(msgid):
                continue

            missing = [
                language
                for language, msgids in msgids_by_language.items()
                if msgid not in msgids
            ]
            if missing:
                issues.append(
                    Issue(
                        file=str(path),
                        line=message_node.lineno,
                        kind="missing",
                        msgid=msgid,
                        detail=",".join(missing),
                    )
                )
            continue

        if isinstance(message_node, ast.Name) or _node_has_chinese(message_node):
            issues.append(
                Issue(
                    file=str(path),
                    line=message_node.lineno,
                    kind="dynamic",
                    msgid="<dynamic>",
                    detail=_dynamic_reason(message_node),
                )
            )

    return issues


def _format_issue(issue: Issue) -> str:
    if issue.kind == "missing":
        return f"{issue.file}:{issue.line}: msgid={issue.msgid!r} missing={issue.detail}"
    return f"{issue.file}:{issue.line}: msgid={issue.msgid} {issue.detail}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        default=[DEFAULT_ROOT],
        help="Files or directories to inspect (default: backend/app)",
    )
    args = parser.parse_args(argv)

    msgids_by_language = {
        language: _parse_po_msgids(path)
        for language, path in CATALOG_PATHS.items()
    }

    paths: list[Path] = []
    for raw_path in args.paths:
        path = raw_path.resolve()
        if path.is_file():
            paths.append(path)
        else:
            paths.extend(sorted(p for p in path.rglob("*.py") if "__pycache__" not in p.parts))

    issues: list[Issue] = []
    for path in paths:
        issues.extend(inspect_file(path, msgids_by_language))

    if issues:
        for issue in issues:
            print(_format_issue(issue))
        return 1

    print("Backend i18n messages complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
