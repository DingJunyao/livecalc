"""合规展示信息：AI 模型备案信息、地图审图号、隐私政策/用户协议。

存储：复用 `system_config` 键值表（value 存 JSON），**不新增表**，免迁移。
- `compliance_ai`  : {"providers": {key: {display_name, model_name, filing_no, note}}}
- `compliance_map` : {"providers": {key: {display_name, approval_no, note}}}
- `legal_docs`     : {"privacy": {"zh": str, "en": str},
                      "terms":   {"zh": str, "en": str},
                      "contact_email": str, "updated_at": iso}

默认文案放在 `app/resources/legal/*.md`（与移动端 `mobile/assets/legal` 同源），
管理员在 Web 管理端编辑后写库覆盖；未编辑时回退到默认文件。
"""
from __future__ import annotations

import html
import json
import logging
import re
from pathlib import Path
from typing import Dict, Optional, Tuple

from sqlalchemy.orm import Session

from app.models.system_config import SystemConfig

logger = logging.getLogger("compliance_info")

KEY_AI = "compliance_ai"
KEY_MAP = "compliance_map"
KEY_LEGAL = "legal_docs"

LEGAL_DOCS = ("privacy", "terms")
LEGAL_LOCALES = ("zh", "en")

# 与 ai 配置（DEFAULT_TRANSLATION_CONFIG.ai.providers）的 key 保持一致：
# Claude Code / Codex 直接驱动本机安装的对应工具（工具本身可指向第三方模型）；
# openai / anthropic 为“兼容 API”入口，可指向任何兼容服务。
DEFAULT_AI_PROVIDERS: Dict[str, dict] = {
    "claude_code": {"display_name": "Claude Code", "model_name": "", "filing_no": "", "note": ""},
    "codex": {"display_name": "Codex", "model_name": "", "filing_no": "", "note": ""},
    "openai": {"display_name": "OpenAI 兼容 API", "model_name": "", "filing_no": "", "note": ""},
    "anthropic": {"display_name": "Anthropic 兼容 API", "model_name": "", "filing_no": "", "note": ""},
}

# 与地图配置 available_maps 的 key 保持一致（天地图可合规使用，需填审图号）
DEFAULT_MAP_PROVIDERS: Dict[str, dict] = {
    "amap": {"display_name": "高德地图", "approval_no": "", "approval_no_satellite": "", "note": ""},
    "baidu": {"display_name": "百度地图", "approval_no": "", "approval_no_satellite": "", "note": ""},
    "tencent": {"display_name": "腾讯地图", "approval_no": "", "approval_no_satellite": "", "note": ""},
    "tianditu": {"display_name": "天地图", "approval_no": "", "approval_no_satellite": "", "note": ""},
    "osm": {"display_name": "OpenStreetMap", "approval_no": "", "approval_no_satellite": "", "note": "境外底图，中国境内不建议提供"},
    # iOS 原生 MapKit：中国区数据由高德提供。MapKit 没有审图号 API，
    # 需管理员在此手工填写与自然资源部公示一致的高德底图审图号。
    "apple": {"display_name": "Apple 地图", "approval_no": "", "approval_no_satellite": "",
              "note": "中国区数据由高德地图提供"},
}

_RESOURCES = Path(__file__).resolve().parent.parent / "resources" / "legal"


# ── 通用 JSON 存取 ────────────────────────────────────────────────────


def _get_json(db: Session, key: str) -> dict:
    row = db.query(SystemConfig).filter(SystemConfig.key == key).first()
    if not row or not row.value:
        return {}
    try:
        data = json.loads(row.value)
    except (TypeError, ValueError):
        logger.warning("配置 %s 不是合法 JSON，按空处理", key)
        return {}
    return data if isinstance(data, dict) else {}


def _set_json(db: Session, key: str, value: dict) -> None:
    payload = json.dumps(value, ensure_ascii=False)
    row = db.query(SystemConfig).filter(SystemConfig.key == key).first()
    if row:
        row.value = payload
    else:
        db.add(SystemConfig(key=key, value=payload))


# ── AI / 地图 ────────────────────────────────────────────────────────


def get_ai_compliance(db: Session) -> Dict[str, dict]:
    """补齐默认项后的 AI 提供方合规信息（key → 信息）。"""
    stored = _get_json(db, KEY_AI).get("providers") or {}
    merged: Dict[str, dict] = {}
    for key, defaults in DEFAULT_AI_PROVIDERS.items():
        info = dict(defaults)
        info.update(stored.get(key) or {})
        merged[key] = info
    # 允许管理员为未来新增的 provider 自定义条目（不在默认表里也保留）
    for key, info in stored.items():
        if key not in merged and isinstance(info, dict):
            merged[key] = {
                "display_name": info.get("display_name") or key,
                "model_name": info.get("model_name") or "",
                "filing_no": info.get("filing_no") or "",
                "note": info.get("note") or "",
            }
    return merged


def get_map_compliance(db: Session) -> Dict[str, dict]:
    stored = _get_json(db, KEY_MAP).get("providers") or {}
    merged: Dict[str, dict] = {}
    for key, defaults in DEFAULT_MAP_PROVIDERS.items():
        info = dict(defaults)
        info.update(stored.get(key) or {})
        merged[key] = info
    for key, info in stored.items():
        if key not in merged and isinstance(info, dict):
            merged[key] = {
                "display_name": info.get("display_name") or key,
                "approval_no": info.get("approval_no") or "",
                "approval_no_satellite": info.get("approval_no_satellite") or "",
                "note": info.get("note") or "",
            }
    return merged


def update_ai_compliance(db: Session, providers: dict) -> Dict[str, dict]:
    """只覆盖传入的字段；空字符串表示清空（不等于删除条目）。"""
    current = _get_json(db, KEY_AI)
    merged = dict(current.get("providers") or {})
    for key, info in (providers or {}).items():
        if not isinstance(info, dict):
            continue
        row = dict(merged.get(key) or {})
        for field in ("display_name", "model_name", "filing_no", "note"):
            if field in info:
                row[field] = str(info[field] or "")
        merged[key] = row
    _set_json(db, KEY_AI, {"providers": merged})
    db.commit()
    return get_ai_compliance(db)


def update_map_compliance(db: Session, providers: dict) -> Dict[str, dict]:
    current = _get_json(db, KEY_MAP)
    merged = dict(current.get("providers") or {})
    for key, info in (providers or {}).items():
        if not isinstance(info, dict):
            continue
        row = dict(merged.get(key) or {})
        for field in ("display_name", "approval_no", "approval_no_satellite", "note"):
            if field in info:
                row[field] = str(info[field] or "")
        merged[key] = row
    _set_json(db, KEY_MAP, {"providers": merged})
    db.commit()
    return get_map_compliance(db)


# ── 法律文档 ─────────────────────────────────────────────────────────


def _default_legal_text(doc: str, locale: str) -> str:
    path = _RESOURCES / f"{doc}_{locale}.md"
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        logger.warning("默认法律文档缺失：%s", path)
        return ""


def get_legal_docs(db: Session) -> dict:
    stored = _get_json(db, KEY_LEGAL)
    result = {"contact_email": stored.get("contact_email", ""),
              "updated_at": stored.get("updated_at", "")}
    for doc in LEGAL_DOCS:
        block = stored.get(doc) or {}
        result[doc] = {
            locale: (block.get(locale) or _default_legal_text(doc, locale))
            for locale in LEGAL_LOCALES
        }
    return result


def get_legal_document(db: Session, doc: str, locale: str) -> Tuple[str, str]:
    """返回 (正文, updated_at)。locale 不支持时回退英文。"""
    loc = locale if locale in LEGAL_LOCALES else "en"
    stored = _get_json(db, KEY_LEGAL)
    text = (stored.get(doc) or {}).get(loc) or _default_legal_text(doc, loc)
    return text, stored.get("updated_at", "")


def update_legal_docs(db: Session, payload: dict) -> dict:
    """payload: {privacy?: {zh,en}, terms?: {zh,en}, contact_email?}"""
    stored = _get_json(db, KEY_LEGAL)
    for doc in LEGAL_DOCS:
        block = payload.get(doc)
        if not isinstance(block, dict):
            continue
        row = dict(stored.get(doc) or {})
        for locale in LEGAL_LOCALES:
            if locale in block and block[locale] is not None:
                text = str(block[locale])
                if len(text) > 200_000:
                    raise ValueError("文档内容过大（上限 200KB）")
                row[locale] = text
        stored[doc] = row
    if "contact_email" in payload and payload["contact_email"] is not None:
        stored["contact_email"] = str(payload["contact_email"])[:200]
    from datetime import datetime, timezone

    stored["updated_at"] = datetime.now(timezone.utc).isoformat()
    _set_json(db, KEY_LEGAL, stored)
    db.commit()
    return get_legal_docs(db)


# ── Markdown → HTML（极简：标题/列表/段落/加粗/行内代码）────────────────


def markdown_to_html(markdown: str) -> str:
    def inline(text: str) -> str:
        text = html.escape(text)
        text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
        text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
        return text

    out = []
    in_list = False
    for raw in markdown.split("\n"):
        line = raw.rstrip()
        if line.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(line[2:])}</li>")
            continue
        if in_list:
            out.append("</ul>")
            in_list = False
        if not line.strip():
            continue
        if line.startswith("## "):
            out.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.startswith("# "):
            out.append(f"<h1>{inline(line[2:])}</h1>")
        else:
            out.append(f"<p>{inline(line)}</p>")
    if in_list:
        out.append("</ul>")
    return "\n".join(out)
