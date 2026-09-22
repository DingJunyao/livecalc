import assert from 'node:assert/strict'
import { test } from 'node:test'
import i18n from '../plugins/i18n.ts'
import { localError, translateLocalError } from './localErrors.ts'

test('localError uses stable codes, statuses, and interpolation params', () => {
  assert.deepEqual(localError('recipeNotFound', 404, { id: 7 }), {
    status: 404,
    code: 'recipeNotFound',
    params: { id: 7 },
  })
  assert.deepEqual(localError('blacklistGroupExists'), {
    status: 400,
    code: 'blacklistGroupExists',
    params: {},
  })
})

test('translateLocalError translates codes and preserves statuses', () => {
  i18n.global.locale.value = 'en-US'
  assert.deepEqual(translateLocalError(localError('recipeNotFound', 404, { id: 7 })), {
    status: 404,
    message: 'Recipe 7 was not found',
  })

  i18n.global.locale.value = 'zh-CN'
  assert.deepEqual(translateLocalError({ code: 'recipeNotFound', params: { id: 7 } }), {
    status: 400,
    message: '\u83dc\u8c31 7 \u672a\u627e\u5230',
  })
})

test('translateLocalError passes non-local errors through unchanged', () => {
  const error = new Error('internal detail')
  assert.equal(translateLocalError(error), error)
  assert.equal(translateLocalError(null), null)
})
