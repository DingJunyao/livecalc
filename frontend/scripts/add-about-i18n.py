#!/usr/bin/env python3
"""为 Web 三语追加「关于」页文案。幂等（按行插入，不重排整个 JSON）。"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALES = ROOT / "src" / "locales"

T = {
    "zh-CN": {
        "block": {
            "server": "服务器",
            "contact": "联系方式",
            "legalSection": "法律文档",
            "privacyPolicy": "隐私政策",
            "termsOfService": "用户协议",
            "updatedAt": "文档更新时间",
            "aiSection": "AI 服务（模型与备案）",
            "aiDisabled": "当前服务器未启用 AI 推荐",
            "mapSection": "地图服务（审图号）",
            "mapDisabled": "当前服务器未启用地图",
            "provider": "提供方",
            "model": "模型",
            "filingNo": "备案号",
            "approvalNo": "审图号",
            "note": "备注",
            "loadFailed": "无法从服务器读取合规信息，请确认服务器已升级到最新版本",
            "localModeHint": "本地模式不连接服务器，无法展示服务器配置的合规信息。",
        },
        "route": "关于",
    },
    "en-US": {
        "block": {
            "server": "Server",
            "contact": "Contact",
            "legalSection": "Legal documents",
            "privacyPolicy": "Privacy Policy",
            "termsOfService": "Terms of Service",
            "updatedAt": "Documents updated",
            "aiSection": "AI services (model and filing)",
            "aiDisabled": "AI recommendations are disabled on this server",
            "mapSection": "Map services (approval numbers)",
            "mapDisabled": "Maps are disabled on this server",
            "provider": "Provider",
            "model": "Model",
            "filingNo": "Filing no.",
            "approvalNo": "Approval no.",
            "note": "Note",
            "loadFailed": "Could not read compliance information from the server. Check that it is up to date.",
            "localModeHint": "Local mode does not connect to a server, so server-configured compliance information is unavailable.",
        },
        "route": "About",
    },
    "ar": {
        "block": {
            "server": "الخادم",
            "contact": "وسيلة الاتصال",
            "legalSection": "المستندات القانونية",
            "privacyPolicy": "سياسة الخصوصية",
            "termsOfService": "شروط الخدمة",
            "updatedAt": "تحديث المستندات",
            "aiSection": "خدمات الذكاء الاصطناعي (النموذج والتسجيل)",
            "aiDisabled": "توصيات الذكاء الاصطناعي معطلة على هذا الخادم",
            "mapSection": "خدمات الخرائط (أرقام الاعتماد)",
            "mapDisabled": "الخرائط معطلة على هذا الخادم",
            "provider": "المزوّد",
            "model": "النموذج",
            "filingNo": "رقم التسجيل",
            "approvalNo": "رقم الاعتماد",
            "note": "ملاحظة",
            "loadFailed": "تعذر قراءة معلومات الامتثال من الخادم. تأكد من تحديثه.",
            "localModeHint": "لا يتصل الوضع المحلي بخادم، لذا لا تتوفر معلومات الامتثال المهيأة على الخادم.",
        },
        "route": "حول",
    },
}


def dump_block(block: dict) -> str:
    lines = ['  "about": {']
    items = list(block.items())
    for idx, (key, value) in enumerate(items):
        comma = "," if idx < len(items) - 1 else ""
        lines.append(f'    "{key}": {json.dumps(value, ensure_ascii=False)}{comma}')
    lines.append("  },")
    return "\n".join(lines)


def patch(locale: str, spec: dict) -> None:
    path = LOCALES / f"{locale}.json"
    text = path.read_text(encoding="utf-8")
    changed = False

    if '\n  "about": {' not in text:
        anchor = '  "adminCompliance": {'
        assert anchor in text, f"{path} 缺少 adminCompliance 锚点"
        text = text.replace(anchor, dump_block(spec["block"]) + "\n" + anchor, 1)
        changed = True

    # routes 里插在 adminMapSettings 之前（注意 profile 里本来就有 "about": "关于"，
    # 不能用全文 contains 判断）
    route_anchor = '    "adminMapSettings":'
    assert route_anchor in text, f"{path} 缺少 routes.adminMapSettings 锚点"
    head = text.split(route_anchor)[0].rstrip()
    marker = f'"about": {json.dumps(spec["route"], ensure_ascii=False)},'
    if not head.endswith(marker):
        text = text.replace(
            route_anchor, f'    {marker}\n' + route_anchor, 1
        )
        changed = True

    if changed:
        json.loads(text)
        path.write_text(text, encoding="utf-8")
    print(f"{locale}.json: {'已更新' if changed else '无需更改'}")


def main() -> int:
    for locale, spec in T.items():
        patch(locale, spec)
    return 0


if __name__ == "__main__":
    sys.exit(main())
