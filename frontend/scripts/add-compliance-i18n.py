#!/usr/bin/env python3
"""为 Web 三语（zh-CN / en-US / ar）追加管理端「合规信息」页的文案。幂等。

做三件事（按行插入，避免重排整个 locale JSON）：
1. 根对象里新增 `adminCompliance` 块（ComplianceView.vue 使用）。
2. `admin.dashboard` 里新增卡片标题/副标题。
3. `routes` 里新增路由标题。
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALES = ROOT / "src" / "locales"

T = {
    "zh-CN": {
        "block": {
            "title": "合规信息",
            "hint": "这里填写 AI 模型备案信息、地图审图号与隐私政策/用户协议。App「关于」页会展示 AI 与地图信息；隐私政策与用户协议同时发布在 /legal/privacy 与 /legal/terms，可直接填入应用商店。清空法律文档正文会回退到内置默认文案。",
            "aiTitle": "AI 服务（模型与备案）",
            "aiHint": "Claude Code / Codex 直接使用本机安装的工具（工具本身可指向第三方模型）；OpenAI / Anthropic 兼容 API 可指向任意兼容服务。填写后展示给用户。",
            "mapTitle": "地图服务（审图号）",
            "mapHint": "高德、百度、腾讯、天地图均可合规使用；使用哪家就填写该家的审图号。App 内会展示已启用底图的名称与审图号。",
            "legalTitle": "隐私政策与用户协议",
            "legalHint": "Markdown：`#` 标题、`##` 小节、`- ` 列表。留空表示使用内置默认文案。",
            "contactEmail": "联系邮箱",
            "contactEmailPlaceholder": "例如 you@example.com",
            "providerKey": "标识",
            "displayName": "展示名称",
            "modelName": "模型名称",
            "filingNo": "备案号",
            "filingNoPlaceholder": "如：网信算备xxxxxxx号",
            "approvalNo": "审图号",
            "approvalNoPlaceholder": "如：GS(2024)xxxx号",
            "note": "备注",
            "privacyZh": "隐私政策（中文）",
            "privacyEn": "隐私政策（English）",
            "termsZh": "用户协议（中文）",
            "termsEn": "用户协议（English）",
            "publicUrls": "公开页面",
            "updatedAt": "更新时间",
            "effectiveTitle": "当前生效（App「关于」页展示）",
            "effectiveAi": "AI 服务",
            "effectiveAiEmpty": "当前没有启用 AI 提供方（或推荐方式为规则生成）",
            "effectiveMap": "地图服务",
            "save": "保存",
            "saved": "已保存",
            "saveFailed": "保存失败",
            "loadFailed": "加载失败",
        },
        "dashboard": {
            "complianceTitle": "合规信息",
            "complianceSubtitle": "AI 模型备案、地图审图号、隐私政策与用户协议",
        },
        "route": "合规信息",
    },
    "en-US": {
        "block": {
            "title": "Compliance information",
            "hint": "Configure AI model filing details, map approval numbers, and the privacy policy / terms. The app's About page shows the AI and map information; the legal documents are also published at /legal/privacy and /legal/terms for store listings. Clearing a legal document falls back to the built-in default text.",
            "aiTitle": "AI services (model and filing)",
            "aiHint": "Claude Code / Codex drive the tools installed on this machine (those tools may themselves point at third-party models); the OpenAI / Anthropic compatible APIs can point at any compatible service. Filled details are shown to users.",
            "mapTitle": "Map services (approval numbers)",
            "mapHint": "AMap, Baidu, Tencent and Tianditu can all be used lawfully; fill in the approval number for each provider you enable. The app shows the enabled providers and their approval numbers.",
            "legalTitle": "Privacy policy and terms of service",
            "legalHint": "Markdown: `#` heading, `##` section, `- ` list. Leave empty to use the built-in default text.",
            "contactEmail": "Contact email",
            "contactEmailPlaceholder": "e.g. you@example.com",
            "providerKey": "Key",
            "displayName": "Display name",
            "modelName": "Model name",
            "filingNo": "Filing number",
            "filingNoPlaceholder": "e.g. filing number issued by CAC",
            "approvalNo": "Approval number",
            "approvalNoPlaceholder": "e.g. GS(2024)xxxx",
            "note": "Note",
            "privacyZh": "Privacy policy (Chinese)",
            "privacyEn": "Privacy policy (English)",
            "termsZh": "Terms of service (Chinese)",
            "termsEn": "Terms of service (English)",
            "publicUrls": "Public pages",
            "updatedAt": "Updated",
            "effectiveTitle": "Currently effective (shown on the app's About page)",
            "effectiveAi": "AI services",
            "effectiveAiEmpty": "No AI provider is enabled (or recommendations are rule-based)",
            "effectiveMap": "Map services",
            "save": "Save",
            "saved": "Saved",
            "saveFailed": "Could not save",
            "loadFailed": "Could not load",
        },
        "dashboard": {
            "complianceTitle": "Compliance information",
            "complianceSubtitle": "AI model filings, map approval numbers, privacy policy and terms",
        },
        "route": "Compliance",
    },
    "ar": {
        "block": {
            "title": "معلومات الامتثال",
            "hint": "سجّل هنا بيانات تسجيل نماذج الذكاء الاصطناعي وأرقام اعتماد الخرائط وسياسة الخصوصية/شروط الخدمة. تعرض صفحة «حول» في التطبيق معلومات الذكاء الاصطناعي والخرائط؛ وتُنشر المستندات القانونية أيضًا على /legal/privacy و/legal/terms لاستخدامها في المتاجر. مسح نص المستند يعيد النص الافتراضي المدمج.",
            "aiTitle": "خدمات الذكاء الاصطناعي (النموذج والتسجيل)",
            "aiHint": "يشغّل Claude Code / Codex الأدوات المثبتة على هذا الجهاز (ويمكن لهذه الأدوات أن تشير إلى نماذج خارجية)؛ ويمكن لواجهات OpenAI / Anthropic المتوافقة أن تشير إلى أي خدمة متوافقة. تُعرض البيانات المعبأة للمستخدمين.",
            "mapTitle": "خدمات الخرائط (أرقام الاعتماد)",
            "mapHint": "يمكن استخدام Amap وBaidu وTencent وTianditu بشكل نظامي؛ أدخل رقم الاعتماد لكل مزود تفعّله. يعرض التطبيق المزودين المفعّلين وأرقام الاعتماد.",
            "legalTitle": "سياسة الخصوصية وشروط الخدمة",
            "legalHint": "Markdown: عنوان `#`، قسم `##`، قائمة `- `. اتركه فارغًا لاستخدام النص الافتراضي.",
            "contactEmail": "البريد الإلكتروني للتواصل",
            "contactEmailPlaceholder": "مثال: you@example.com",
            "providerKey": "المعرّف",
            "displayName": "الاسم المعروض",
            "modelName": "اسم النموذج",
            "filingNo": "رقم التسجيل",
            "filingNoPlaceholder": "مثال: رقم التسجيل الصادر عن الجهة المختصة",
            "approvalNo": "رقم الاعتماد",
            "approvalNoPlaceholder": "مثال: GS(2024)xxxx",
            "note": "ملاحظة",
            "privacyZh": "سياسة الخصوصية (الصينية)",
            "privacyEn": "سياسة الخصوصية (الإنجليزية)",
            "termsZh": "شروط الخدمة (الصينية)",
            "termsEn": "شروط الخدمة (الإنجليزية)",
            "publicUrls": "الصفحات العامة",
            "updatedAt": "آخر تحديث",
            "effectiveTitle": "المفعّل حاليًا (يُعرض في صفحة «حول»)",
            "effectiveAi": "خدمات الذكاء الاصطناعي",
            "effectiveAiEmpty": "لا يوجد مزود ذكاء اصطناعي مفعّل (أو التوصيات قائمة على القواعد)",
            "effectiveMap": "خدمات الخرائط",
            "save": "حفظ",
            "saved": "تم الحفظ",
            "saveFailed": "تعذر الحفظ",
            "loadFailed": "تعذر التحميل",
        },
        "dashboard": {
            "complianceTitle": "معلومات الامتثال",
            "complianceSubtitle": "تسجيل نماذج الذكاء الاصطناعي، أرقام اعتماد الخرائط، سياسة الخصوصية والشروط",
        },
        "route": "معلومات الامتثال",
    },
}


def _dump_block(block: dict, indent: int) -> str:
    pad = " " * indent
    lines = [f'{pad}"adminCompliance": {{']
    items = list(block.items())
    for idx, (key, value) in enumerate(items):
        comma = "," if idx < len(items) - 1 else ""
        lines.append(f'{pad}  "{key}": {json.dumps(value, ensure_ascii=False)}{comma}')
    lines.append(f"{pad}}},")
    return "\n".join(lines)


def patch(locale: str, spec: dict) -> None:
    path = LOCALES / f"{locale}.json"
    text = path.read_text(encoding="utf-8")
    changed = False

    if '"adminCompliance": {' not in text:
        anchor = '  "adminEmail": {'
        assert anchor in text, f"{path} 缺少 adminEmail 锚点"
        text = text.replace(anchor, _dump_block(spec["block"], 2) + "\n" + anchor, 1)
        changed = True

    dashboard_title = f'"complianceTitle": {json.dumps(spec["dashboard"]["complianceTitle"], ensure_ascii=False)}'
    if dashboard_title not in text:
        anchor = '      "aiSubtitle":'
        assert anchor in text, f"{path} 缺少 aiSubtitle 锚点"
        insert = (
            f'      "complianceTitle": {json.dumps(spec["dashboard"]["complianceTitle"], ensure_ascii=False)},\n'
            f'      "complianceSubtitle": {json.dumps(spec["dashboard"]["complianceSubtitle"], ensure_ascii=False)},\n'
        )
        text = text.replace(anchor, insert + anchor, 1)
        changed = True

    if '"adminCompliance": "' not in text:
        anchor = '    "adminMapSettings":'
        assert anchor in text, f"{path} 缺少 adminMapSettings 锚点"
        insert = f'    "adminCompliance": {json.dumps(spec["route"], ensure_ascii=False)},\n'
        text = text.replace(anchor, insert + anchor, 1)
        changed = True

    if changed:
        json.loads(text)  # 语法自检
        path.write_text(text, encoding="utf-8")
    print(f"{locale}.json: {'已更新' if changed else '无需更改'}")


def main() -> int:
    for locale, spec in T.items():
        patch(locale, spec)
    return 0


if __name__ == "__main__":
    sys.exit(main())
