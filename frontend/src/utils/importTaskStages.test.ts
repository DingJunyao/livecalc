import assert from 'node:assert/strict'
import { test } from 'node:test'
import i18n from '../plugins/i18n.ts'
import { importTaskStageLabel } from './importTaskStages.ts'

test('importTaskStageLabel normalizes legacy Chinese stage values', () => {
  i18n.global.locale.value = 'zh-CN'
  assert.equal(importTaskStageLabel('\u51c6\u5907\u4e2d'), '\u51c6\u5907\u4e2d...')
  assert.equal(importTaskStageLabel('\u8fc1\u79fb\u4e2d 5/10'), '\u8fc1\u79fb\u4e2d...')
  assert.equal(importTaskStageLabel('\u5b8c\u6210'), '\u5df2\u5b8c\u6210')
  assert.equal(importTaskStageLabel('\u5931\u8d25'), '\u5931\u8d25')

  i18n.global.locale.value = 'en-US'
  assert.equal(importTaskStageLabel('\u51c6\u5907\u4e2d'), 'Preparing...')
  assert.equal(importTaskStageLabel('\u8fc1\u79fb\u4e2d 5/10'), 'Migrating...')
  assert.equal(importTaskStageLabel('\u5b8c\u6210'), 'Completed')
  assert.equal(importTaskStageLabel('\u5931\u8d25'), 'Failed')
})
