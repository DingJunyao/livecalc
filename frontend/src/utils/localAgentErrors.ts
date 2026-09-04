import { t } from '../plugins/i18n.ts'

export function agentErrorMessage(
  code: string,
  params: Record<string, unknown> = {},
): string {
  return t(`localErrors.${code}`, params)
}

export function agentToolError(
  code: string,
  params: Record<string, unknown> = {},
): { error: string } {
  return { error: agentErrorMessage(code, params) }
}
