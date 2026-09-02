import { t } from '../plugins/i18n.ts'

export function localUserNickname(): string {
  return t('localValues.userNickname')
}

export function adminBackgroundMarker(): string {
  return t('localValues.adminBackgroundMarker')
}

export function unknownIngredientName(): string {
  return t('localValues.unknownIngredientName')
}

export function pendingReviewMarker(): string {
  return t('localValues.pendingReviewMarker')
}

export function proposalMarker(): string {
  return t('localValues.proposalMarker')
}

export function newNameSuffix(): string {
  return t('localValues.newNameSuffix')
}

export function fallbackPriceUnitValues(): string[] {
  return [
    t('prices.units.jin'),
    t('prices.units.piece'),
    'kg',
    t('prices.units.gram'),
    t('prices.units.liter'),
    t('prices.units.milliliter'),
    t('prices.units.box'),
    t('prices.units.package'),
    t('prices.units.bag'),
    t('prices.units.bottle'),
  ]
}
