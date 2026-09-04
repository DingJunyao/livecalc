import { isLocalError, localError, translateLocalError, type LocalError } from './localErrors.ts'

export type ImportTaskError = string | LocalError | null | undefined

const STORAGE_MIGRATION_ERROR_CODES: Record<string, string> = {
  'S3 endpoint is required': 's3EndpointRequired',
  'S3 bucket is required': 's3BucketRequired',
  'S3 access key and secret key are required': 's3CredentialsRequired',
  'Current storage is not a valid S3 configuration': 's3CurrentConfigInvalid',
}

export function toStableTaskError(error: unknown): LocalError {
  if (isLocalError(error)) return error
  const message = error instanceof Error ? error.message : String(error)
  return localError(STORAGE_MIGRATION_ERROR_CODES[message] || 'storageMigrationFailed')
}

export function importTaskErrorLabel(error: ImportTaskError): string {
  if (!error) return ''
  if (typeof error === 'string') return error
  const translated = translateLocalError(error) as { message?: string }
  return translated.message ?? ''
}
