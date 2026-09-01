import { t } from '@/plugins/i18n'

export interface ProviderOption {
  value: string
  label: string
}

export const AI_PROVIDER_ORDER = ['claude_code', 'codex', 'openai', 'anthropic']
export const MACHINE_PROVIDER_ORDER = ['baidu', 'aliyun', 'deepl']

const PROVIDER_LABEL_KEYS: Record<string, string> = {
  claude_code: 'adminAI.providers.claudeCode',
  codex: 'adminAI.providers.codex',
  openai: 'adminAI.providers.openaiCompatible',
  anthropic: 'adminAI.providers.anthropicCompatible',
  baidu: 'adminAI.providers.baidu',
  aliyun: 'adminAI.providers.aliyun',
  deepl: 'adminAI.providers.deepl',
}

export function enabledProviderOptions(
  config: any,
  regions: Array<'ai' | 'machine'>,
  localMode = false,
): ProviderOption[] {
  if (!config) return []
  const options: ProviderOption[] = []
  const seen = new Set<string>()
  const order = [...AI_PROVIDER_ORDER, ...MACHINE_PROVIDER_ORDER]
  for (const region of regions) {
    const providers = config?.[region]?.providers || {}
    for (const key of order) {
      const value = providers[key]
      if (!value || value.enabled !== true) continue
      if (localMode && (key === 'claude_code' || key === 'codex')) continue
      if (localMode && region === 'machine') continue
      if (localMode && (key === 'openai' || key === 'anthropic') && !value.api_key) continue
      if (seen.has(key)) continue
      seen.add(key)
      const labelKey = PROVIDER_LABEL_KEYS[key]
      options.push({ value: key, label: labelKey ? t(labelKey) : key })
    }
  }
  return options
}
