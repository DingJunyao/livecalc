import { test } from 'node:test'
import assert from 'node:assert/strict'

import {
  DEFAULT_TRANSLATION_CONFIG,
  deepMergeConfig,
  normalizeTranslationConfig,
} from './translationConfig.ts'

test('缺失区块按默认补齐（旧后端只回 ai/machine 时不再白屏）', () => {
  const cfg = normalizeTranslationConfig({
    ai: { providers: { openai: { enabled: true } } },
    machine: { providers: {} },
  })
  assert.equal(cfg.ai_policy.allow_user_choice, true)
  assert.equal(cfg.ai_policy.daily_ai_limit, DEFAULT_TRANSLATION_CONFIG.ai_policy.daily_ai_limit)
  assert.equal(cfg.meal_plan.provider, 'claude_code')
  assert.equal(cfg.meal_plan.timeout_seconds, 120)
})

test('已存储值优先，provider 的未知/新增字段保留', () => {
  const cfg = normalizeTranslationConfig({
    ai: { providers: { openai: { enabled: true, api_key: 'k' } } },
    ai_policy: { allow_byok: false },
    extra_block: { keep: 1 },
  })
  assert.equal(cfg.ai.providers.openai.enabled, true)
  assert.equal(cfg.ai.providers.openai.api_key, 'k')
  assert.equal(cfg.ai.providers.openai.model, 'gpt-4o-mini') // 缺省字段补齐
  assert.equal(cfg.ai_policy.allow_byok, false)
  assert.equal(cfg.ai_policy.show_ai_badge, true) // 同区块内未写的字段仍取默认
  assert.deepEqual(cfg.extra_block, { keep: 1 })
})

test('空/未保存过 → 返回默认结构', () => {
  assert.deepEqual(normalizeTranslationConfig(undefined), DEFAULT_TRANSLATION_CONFIG)
  assert.deepEqual(normalizeTranslationConfig(null), DEFAULT_TRANSLATION_CONFIG)
})

test('deepMergeConfig 不修改入参，数组整体替换', () => {
  const base = { a: { b: 1 }, list: [1, 2] }
  const out = deepMergeConfig(base, { a: { c: 2 }, list: [3] })
  assert.deepEqual(base, { a: { b: 1 }, list: [1, 2] })
  assert.deepEqual(out, { a: { b: 1, c: 2 }, list: [3] })
})
