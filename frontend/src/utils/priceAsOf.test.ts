import assert from 'node:assert/strict'
import { test } from 'node:test'
import { buildWeightedAsOfDailySeries } from './priceAsOf.ts'

const END = '2026-10-12'

test('每商品的最近一次价格向前携带到后续每一天', () => {
  const series = buildWeightedAsOfDailySeries(
    [
      { product_id: 1, date: '2026-10-10T09:00:00+08:00', value: 10 },
      { product_id: 2, date: '2026-10-12T09:00:00+08:00', value: 20 },
    ],
    () => 50,
    { endDay: END },
  )
  assert.deepEqual(series.map((d) => d.date), ['2026-10-10', '2026-10-11', '2026-10-12'])
  // P2 还没有记录时只有 P1 参与（不再退化成「当天有记录的商品才计入」）
  assert.equal(series[0].avg, 10)
  assert.equal(series[0].count, 1)
  assert.equal(series[1].avg, 10)
  // P2 出现后等权加权
  assert.equal(series[2].avg, 15)
  assert.equal(series[2].min, 10)
  assert.equal(series[2].max, 20)
  assert.equal(series[2].count, 2)
})

test('同一商品同日多条取当日均价', () => {
  const series = buildWeightedAsOfDailySeries(
    [
      { product_id: 1, date: '2026-10-12T08:00:00+08:00', value: 10 },
      { product_id: 1, date: '2026-10-12T20:00:00+08:00', value: 30 },
    ],
    () => 50,
    { endDay: END },
  )
  assert.equal(series.length, 1)
  assert.equal(series[0].avg, 20)
})

test('权重 0 的商品整段排除', () => {
  const series = buildWeightedAsOfDailySeries(
    [
      { product_id: 1, date: '2026-10-12T08:00:00+08:00', value: 10 },
      { product_id: 2, date: '2026-10-12T08:00:00+08:00', value: 90 },
    ],
    (pid) => (pid === 2 ? 0 : 50),
    { endDay: END },
  )
  assert.equal(series[0].avg, 10)
  assert.equal(series[0].count, 1)
  assert.equal(series[0].max, 10)
})

test('超过 30 天的价格过期，不再参与综合价', () => {
  const series = buildWeightedAsOfDailySeries(
    [
      { product_id: 1, date: '2026-09-10T08:00:00+08:00', value: 10 },
      { product_id: 2, date: '2026-10-12T08:00:00+08:00', value: 20 },
    ],
    () => 50,
    { endDay: END },
  )
  // P1 参与到「记录后 30 天」（10-10）；10-11 无参与者不产出点；10-12 只剩 P2
  assert.equal(series.length, 32)
  assert.equal(series[30].date, '2026-10-10')
  assert.equal(series[30].avg, 10)
  assert.equal(series[31].date, '2026-10-12')
  assert.equal(series[31].avg, 20)
  assert.equal(series[31].count, 1)
})

test('按商品权重加权并支持区间截断', () => {
  const series = buildWeightedAsOfDailySeries(
    [
      { product_id: 1, date: '2026-10-01T08:00:00+08:00', value: 10 },
      { product_id: 2, date: '2026-10-01T08:00:00+08:00', value: 30 },
    ],
    (pid) => (pid === 1 ? 30 : 10),
    { startDay: '2026-10-11', endDay: END },
  )
  assert.deepEqual(series.map((d) => d.date), ['2026-10-11', '2026-10-12'])
  assert.equal(series[0].avg, 15)
})

test('无有效点时返回空序列', () => {
  assert.deepEqual(buildWeightedAsOfDailySeries([], () => 50), [])
  assert.deepEqual(
    buildWeightedAsOfDailySeries([{ product_id: 1, date: 'bad-date', value: 10 }], () => 50),
    [],
  )
})
