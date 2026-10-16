/**
 * AI / 机翻配置（`/admin/translation-config`）的默认结构与归一化。
 *
 * 与后端 `DEFAULT_TRANSLATION_CONFIG`（backend/app/api/usda_admin.py）逐字对齐。
 *
 * 为什么需要归一化：配置里除了 ai/machine 还有后加的 meal_plan / ai_policy 区块，
 * 页面模板直接访问 `config.ai_policy.xxx`。只要任一来源（旧版后端序列化、本地模式
 * IndexedDB 里保存过的旧结构）缺这些区块，渲染就会抛
 * "Cannot read properties of undefined" 导致整页白屏。取到配置后统一过一遍
 * normalizeTranslationConfig()，缺失区块/字段按默认补齐。
 *
 * 纯数据函数，无框架依赖，可由 `node --test` 直接运行。
 */

export type TranslationConfig = Record<string, any>

/** 后端默认配置的镜像（新增区块时两端一起加）。 */
export const DEFAULT_TRANSLATION_CONFIG: TranslationConfig = {
  ai: {
    providers: {
      claude_code: { enabled: false },
      codex: { enabled: false },
      openai: {
        enabled: false,
        base_url: 'https://api.openai.com/v1',
        api_key: '',
        model: 'gpt-4o-mini',
      },
      anthropic: {
        enabled: false,
        base_url: 'https://api.anthropic.com',
        api_key: '',
        model: 'claude-sonnet-4-6',
      },
    },
  },
  machine: {
    providers: {
      baidu: { enabled: false, appid: '', secret: '' },
      aliyun: { enabled: false, access_key_id: '', access_key_secret: '' },
      deepl: { enabled: false, auth_key: '' },
    },
  },
  // 餐食推荐（AI 组合层）与 AI 使用策略（全局；用户级见 user_ai_settings）
  meal_plan: { provider: 'claude_code', timeout_seconds: 120 },
  ai_policy: {
    default_method: 'system_ai',
    allow_user_choice: true,
    allow_byok: true,
    allow_custom_base_url: false,
    daily_ai_limit: 20,
    show_ai_badge: true,
  },
}

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value))
}

/** 就地递归合并（内部用）：override 覆盖 target；两侧都是对象时下钻，否则整体替换。 */
function mergeInto(target: TranslationConfig, override: any): TranslationConfig {
  const out: TranslationConfig = target
  for (const [key, value] of Object.entries(override || {})) {
    const current = out[key]
    if (
      value &&
      typeof value === 'object' &&
      !Array.isArray(value) &&
      current &&
      typeof current === 'object' &&
      !Array.isArray(current)
    ) {
      out[key] = mergeInto(current, value)
    } else {
      out[key] = value
    }
  }
  return out
}

/**
 * 递归合并：override 覆盖 base；两侧都是对象时下钻，否则整体替换。
 * 不修改入参（与后端 `_deep_merge` 同语义，另加一层克隆）。
 */
export function deepMergeConfig(base: TranslationConfig, override: any): TranslationConfig {
  return mergeInto(clone(base), override)
}

/** 默认值 + 已存储值（已存储值优先，未知顶层区块保留）。 */
export function normalizeTranslationConfig(stored: any): TranslationConfig {
  return mergeInto(clone(DEFAULT_TRANSLATION_CONFIG), stored)
}
