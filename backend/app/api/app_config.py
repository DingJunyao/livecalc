"""公开信息端点：App 启动配置、法律文档（JSON / HTML）。

- `GET /api/v1/app/config`     公开；App 与审核环境都可读（不含任何密钥）
- `GET /api/v1/legal/{doc}`    公开；法律文档正文（Markdown），App 内展示用
- `GET /legal/{doc}`           公开；HTML 页，商店上架时直接填这个 URL
- `GET/PUT /api/v1/admin/compliance`  管理员编辑（AI 模型备案、地图审图号、法律文档）

AI / 地图的「展示信息」与「是否启用」分离：启用状态仍由既有配置决定
（`ai.providers.*.enabled`、`meal_plan.provider`、`available_maps`），
这里只补充模型名称、备案号、审图号等合规展示字段。
"""
from __future__ import annotations

import html
from typing import Dict, List

from fastapi import APIRouter, Depends, Query
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session

from app.api.admin import DEFAULT_MAP_CONFIG
from app.core.database import get_db
from app.core.security import get_current_admin_user
from app.models.map_config import MapConfiguration
from app.models.system_config import SystemConfig
from app.models.user import User
from app.models.usda import TranslationConfig
from app.services import compliance_info as ci
from app.services.ai_policy import DEFAULT_AI_POLICY

router = APIRouter()
pages_router = APIRouter()
admin_router = APIRouter()


def _registration_require_invite(db: Session) -> bool:
    row = db.query(SystemConfig).filter(
        SystemConfig.key == "registration_require_invite_code"
    ).first()
    return bool(row and str(row.value).strip().lower() == "true")


def _translation_config(db: Session) -> Dict:
    row = db.query(TranslationConfig).first()
    return (row.to_dict() if row else {}) or {}


def _ai_section(db: Session) -> dict:
    stored = _translation_config(db)
    providers_cfg = ((stored.get("ai") or {}).get("providers") or {})
    policy = dict(DEFAULT_AI_POLICY)
    policy.update(stored.get("ai_policy") or {})
    compliance = ci.get_ai_compliance(db)

    enabled_keys: List[str] = [
        key for key, cfg in providers_cfg.items()
        if isinstance(cfg, dict) and cfg.get("enabled")
    ]
    # 未显式启用但被 meal_plan 选中的提供方也算在用（便于展示其备案信息）
    meal_provider = (stored.get("meal_plan") or {}).get("provider")
    if meal_provider and meal_provider not in enabled_keys:
        enabled_keys.append(meal_provider)

    providers = []
    for key in enabled_keys:
        info = compliance.get(key) or {}
        cfg = providers_cfg.get(key) or {}
        providers.append({
            "key": key,
            "display_name": info.get("display_name") or key,
            "model_name": info.get("model_name") or cfg.get("model") or "",
            "filing_no": info.get("filing_no") or "",
            "note": info.get("note") or "",
        })

    return {
        "enabled": bool(providers) and policy.get("default_method") != "rule",
        "default_method": policy.get("default_method", "system_ai"),
        "allow_user_choice": bool(policy.get("allow_user_choice")),
        "daily_limit": policy.get("daily_ai_limit"),
        "show_badge": bool(policy.get("show_ai_badge", True)),
        "providers": providers,
    }


def _map_section(db: Session) -> dict:
    cfg = db.query(MapConfiguration).first()
    if cfg:
        enabled = bool(cfg.map_enabled)
        maps = list(cfg.available_maps or [])
        default_map = cfg.default_map
    else:
        enabled = bool(DEFAULT_MAP_CONFIG["map_enabled"])
        maps = list(DEFAULT_MAP_CONFIG["available_maps"])
        default_map = DEFAULT_MAP_CONFIG["default_map"]

    compliance = ci.get_map_compliance(db)
    providers = []
    for key in maps:
        info = compliance.get(key) or {}
        providers.append({
            "key": key,
            "display_name": info.get("display_name") or key,
            "approval_no": info.get("approval_no") or "",
            "note": info.get("note") or "",
        })
    # iOS 原生 MapKit（Apple 地图）不参与 available_maps：客户端按平台二选一展示，
    # 这里单独给出，避免 iOS 用户看到安卓底图列表。
    apple = compliance.get("apple") or {}
    return {
        "enabled": enabled,
        "default": default_map,
        "providers": providers,
        "apple": {
            "key": "apple",
            "display_name": apple.get("display_name") or "Apple 地图",
            "approval_no": apple.get("approval_no") or "",
            "note": apple.get("note") or "",
        },
    }


@router.get("/app/config")
async def get_app_config(db: Session = Depends(get_db)):
    """公开启动配置：注册策略、AI/地图合规展示信息、法律文档元信息。"""
    legal = ci.get_legal_docs(db)
    return {
        "registration_require_invite_code": _registration_require_invite(db),
        "ai": _ai_section(db),
        "map": _map_section(db),
        "legal": {
            "contact_email": legal.get("contact_email", ""),
            "updated_at": legal.get("updated_at", ""),
            "privacy_url": "/legal/privacy",
            "terms_url": "/legal/terms",
        },
    }


@router.get("/legal/{doc}")
async def get_legal_document(
    doc: str,
    locale: str = Query("zh", pattern="^(zh|en|ar)$"),
    db: Session = Depends(get_db),
):
    """法律文档正文（Markdown）。未编辑时返回随服务端分发的默认文案。"""
    if doc not in ci.LEGAL_DOCS:
        from app.core.exceptions import LocalizedHTTPException
        from fastapi import status

        raise LocalizedHTTPException(status_code=status.HTTP_404_NOT_FOUND, message='文档不存在')
    content, updated_at = ci.get_legal_document(db, doc, locale)
    return {
        "doc": doc,
        "locale": locale if locale in ci.LEGAL_LOCALES else "en",
        "content": content,
        "updated_at": updated_at,
    }


@pages_router.get("/legal/{doc}", response_class=HTMLResponse)
async def legal_html_page(
    doc: str,
    locale: str = Query("zh", pattern="^(zh|en|ar)$"),
    db: Session = Depends(get_db),
):
    """可直接填进 App Store / Play Console 的隐私政策、用户协议页面。"""
    if doc not in ci.LEGAL_DOCS:
        return HTMLResponse("<h1>404</h1>", status_code=404)
    loc = locale if locale in ci.LEGAL_LOCALES else "en"
    content, updated_at = ci.get_legal_document(db, doc, loc)
    legal = ci.get_legal_docs(db)
    title = "隐私政策" if doc == "privacy" else "用户协议"
    if loc == "en":
        title = "Privacy Policy" if doc == "privacy" else "Terms of Service"
    other = "terms" if doc == "privacy" else "privacy"
    other_title = ("用户协议" if other == "terms" else "隐私政策") if loc == "zh" else (
        "Terms of Service" if other == "terms" else "Privacy Policy")
    contact = legal.get("contact_email", "")
    body = ci.markdown_to_html(content)
    footer_bits = []
    if updated_at:
        footer_bits.append(f"更新时间 / Updated: {html.escape(updated_at)}")
    if contact:
        footer_bits.append(f"联系 / Contact: {html.escape(contact)}")
    footer = " · ".join(footer_bits)
    lang_switch = (
        f'<a href="/legal/{doc}?locale={"en" if loc == "zh" else "zh"}">'
        f'{"English" if loc == "zh" else "中文"}</a>'
    )
    page = f"""<!doctype html>
<html lang="{'zh-CN' if loc == 'zh' else 'en'}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} · LiveCalc</title>
<style>
  :root {{ color-scheme: light dark; }}
  body {{ max-width: 760px; margin: 0 auto; padding: 32px 20px 80px;
          font: 16px/1.75 -apple-system, "PingFang SC", "Microsoft YaHei", system-ui, sans-serif; }}
  h1 {{ font-size: 1.6rem; }} h2 {{ font-size: 1.15rem; margin-top: 1.8em; }}
  .meta {{ color: #888; font-size: .9rem; }}
  nav {{ margin-bottom: 24px; font-size: .9rem; }}
  code {{ background: #8882; padding: 0 .25em; border-radius: 3px; }}
</style>
</head>
<body>
<nav>{lang_switch} · <a href="/legal/{other}?locale={loc}">{html.escape(other_title)}</a></nav>
{body}
<p class="meta">{footer}</p>
</body>
</html>"""
    return HTMLResponse(page)


# ── 管理端 ───────────────────────────────────────────────────────────


@admin_router.get("/compliance")
async def get_compliance(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
):
    """当前合规展示信息（含默认值），供管理端编辑。"""
    legal = ci.get_legal_docs(db)
    return {
        "ai": {"providers": ci.get_ai_compliance(db)},
        "map": {"providers": ci.get_map_compliance(db)},
        "legal": legal,
        "effective": {"ai": _ai_section(db), "map": _map_section(db)},
    }


@admin_router.put("/compliance")
async def update_compliance(
    payload: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
):
    """部分更新：只传需要改的区块/字段。"""
    from app.core.exceptions import LocalizedHTTPException
    from fastapi import status

    if not isinstance(payload, dict) or not payload:
        raise LocalizedHTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, message='没有需要更新的字段'
        )
    try:
        if isinstance(payload.get("ai"), dict):
            ci.update_ai_compliance(db, payload["ai"].get("providers") or {})
        if isinstance(payload.get("map"), dict):
            ci.update_map_compliance(db, payload["map"].get("providers") or {})
        if isinstance(payload.get("legal"), dict):
            ci.update_legal_docs(db, payload["legal"])
    except ValueError as exc:
        raise LocalizedHTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, message='{error}', error=str(exc)
        )
    legal = ci.get_legal_docs(db)
    return {
        "ai": {"providers": ci.get_ai_compliance(db)},
        "map": {"providers": ci.get_map_compliance(db)},
        "legal": legal,
        "effective": {"ai": _ai_section(db), "map": _map_section(db)},
    }
