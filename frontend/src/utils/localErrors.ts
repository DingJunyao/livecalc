import { t } from '../plugins/i18n.ts'

export type LocalError = {
  status: number
  code: string
  params: Record<string, unknown>
}

export function localError(
  code: string,
  status = 400,
  params: Record<string, unknown> = {},
): LocalError {
  return { status, code, params }
}

export function isLocalError(error: unknown): error is LocalError {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    typeof (error as { code?: unknown }).code === 'string'
  )
}

export function translateLocalError(error: unknown): unknown {
  if (typeof error !== 'object' || error === null || !('code' in error)) return error
  const localError = error as { status?: number; code: string; params?: Record<string, unknown> }
  return {
    status: localError.status ?? 400,
    message: t(`localErrors.${localError.code}`, localError.params ?? {}),
  }
}
