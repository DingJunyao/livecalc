import assert from 'node:assert/strict'
import { test } from 'node:test'
import i18n from '../plugins/i18n.ts'
import { agentErrorMessage, agentToolError } from './localAgentErrors.ts'

test('agentErrorMessage translates stable agent error keys', () => {
  i18n.global.locale.value = 'en-US'
  assert.equal(agentErrorMessage('agentCancelled'), 'Task cancelled by the user')
  assert.equal(
    agentErrorMessage('agentMaxIterations', { max: 30 }),
    'Maximum iterations reached (30)',
  )
  assert.equal(
    agentErrorMessage('agentUnknownTool', { name: 'read_products' }),
    'Unknown tool: read_products',
  )

  i18n.global.locale.value = 'zh-CN'
  assert.equal(agentErrorMessage('agentCancelled'), '\u4efb\u52a1\u5df2\u88ab\u7528\u6237\u53d6\u6d88')
})

test('agentToolError returns a stable translated tool result', () => {
  i18n.global.locale.value = 'ar'
  assert.deepEqual(
    agentToolError('agentUpdateLimit', { count: 51 }),
    { error: '51 تحديثًا يتجاوز الحد الأقصى 50' },
  )
})
