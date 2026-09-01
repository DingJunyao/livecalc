import { t } from '@/plugins/i18n'

export function importTaskStageLabel(stage: string): string {
  switch (stage) {
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
