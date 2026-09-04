import assert from 'node:assert/strict'
import { test } from 'node:test'
import i18n from '../plugins/i18n.ts'
import { importTaskErrorLabel, toStableTaskError } from './importTaskErrors.ts'

test('toStableTaskError maps known S3 migration failures to stable codes', () => {
  assert.deepEqual(toStableTaskError(new Error('S3 endpoint is required')), {
    status: 400,
    code: 's3EndpointRequired',
    params: {},
  })
  assert.deepEqual(toStableTaskError(new Error('S3 bucket is required')), {
    status: 400,
    code: 's3BucketRequired',
    params: {},
  })
  assert.deepEqual(toStableTaskError(new Error('S3 access key and secret key are required')), {
    status: 400,
    code: 's3CredentialsRequired',
    params: {},
  })
  assert.deepEqual(toStableTaskError(new Error('Current storage is not a valid S3 configuration')), {
    status: 400,
    code: 's3CurrentConfigInvalid',
    params: {},
  })
})

test('toStableTaskError hides raw diagnostics from unknown failures', () => {
  const stable = toStableTaskError(new Error('secret network detail'))
  assert.equal(stable.code, 'storageMigrationFailed')
  assert.equal(JSON.stringify(stable).includes('secret network detail'), false)
})

test('importTaskErrorLabel translates structured errors and preserves legacy strings', () => {
  i18n.global.locale.value = 'en-US'
  assert.equal(importTaskErrorLabel({ code: 's3EndpointRequired', params: {} }), 'S3 endpoint is required')

  i18n.global.locale.value = 'zh-CN'
  assert.equal(importTaskErrorLabel({ code: 's3EndpointRequired', params: {} }), 'endpoint \u4e0d\u80fd\u4e3a\u7a7a')
  assert.equal(importTaskErrorLabel('legacy raw error'), 'legacy raw error')
})
