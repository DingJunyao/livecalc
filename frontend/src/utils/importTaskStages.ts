import { t } from '../plugins/i18n.ts'

const LEGACY_STAGE_PREFIXES: Array<[string, string]> = [
  ['\u51c6\u5907\u4e2d', 'preparing'],
  ['\u8fc1\u79fb\u4e2d', 'migrating'],
  ['\u7b49\u5f85\u4e2d', 'pending'],
  ['\u5b8c\u6210', 'completed'],
  ['\u5df2\u5b8c\u6210', 'completed'],
  ['\u5931\u8d25', 'failed'],
]

function normalizeStage(stage: string): string {
  const trimmed = stage.trim()
  for (const [prefix, key] of LEGACY_STAGE_PREFIXES) {
    if (trimmed.startsWith(prefix)) return key
  }
  return trimmed
}

export function importTaskStageLabel(stage: string): string {
  switch (normalizeStage(stage)) {
    case 'pending':
      return t('importTasks.stages.pending')
    case 'preparing':
      return t('importTasks.stages.preparing')
    case 'migrating':
      return t('importTasks.stages.migrating')
    case 'completed':
      return t('importTasks.stages.completed')
    case 'failed':
      return t('importTasks.stages.failed')
    default:
      return stage
  }
}
