import assert from 'node:assert/strict'
import { test } from 'node:test'
import { createLatestRequestGuard } from './latestRequest.ts'

function createDeferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((resolvePromise) => {
    resolve = resolvePromise
  })
  return { promise, resolve }
}

test('latest request guard rejects an older response after a newer request begins', async () => {
  const runLatest = createLatestRequestGuard()
  const firstStarted = createDeferred<void>()
  const secondStarted = createDeferred<void>()
  const firstResponse = createDeferred<string>()
  const secondResponse = createDeferred<string>()

  const firstRequest = runLatest(async () => {
    firstStarted.resolve()
    const value = await firstResponse.promise
    return `first: ${value}`
  })
  const secondRequest = runLatest(async () => {
    secondStarted.resolve()
    const value = await secondResponse.promise
    return `second: ${value}`
  })

  await secondStarted.promise
  secondResponse.resolve('new locale')
  assert.equal(await secondRequest, 'second: new locale')

  firstResponse.resolve('old locale')
  await assert.rejects(firstRequest, /Superseded by a newer request/)
})
