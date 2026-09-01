import assert from 'node:assert/strict'
import { test } from 'node:test'
import { auditSourceText, collectTranslationKeys } from './check-i18n.mjs'

test('source checker collects direct and aliased translation calls', () => {
  const source = [
    "const direct = t('charts.average')",
    "const aliased = translate('localMessages.readingZip')",
  ].join('\n')

  assert.deepEqual(collectTranslationKeys(source), [
    'charts.average',
    'localMessages.readingZip',
  ])
})

test('source auditor reports Han, local throws, and missing local error keys', () => {
  const source = [
    '// 汉字注释不应报告',
    '/* 另一个汉字块注释 */',
    "const label = '汉字界面'",
    'export function fail() {',
    "  throw { status: 404, message: `Not found ${label}` }",
    '}',
    "export function broken() { return localError('missingLocalCode', 404, { id: 1 }) }",
    '',
  ].join('\n')
  const findings = auditSourceText(source, 'src/api/local/fixture.ts', [
    { file: 'zh-CN.json', keys: new Set(['localErrors.recipeNotFound']) },
  ])

  assert.deepEqual(findings, [
    'src/api/local/fixture.ts:3: Han text: const label = \'汉字界面\'',
    'src/api/local/fixture.ts:5: literal local throw',
    'src/api/local/fixture.ts:7: missing localErrors.missingLocalCode in zh-CN.json',
  ])
})

test('source auditor reports multiline literal local throws', () => {
  const source = [
    'export function fail() {',
    '  throw {',
    '    status: 400,',
    "    message: 'Invalid request',",
  '  }',
  '}',
  ].join('\n')

  assert.deepEqual(auditSourceText(source, 'src/api/local/fixture.ts', []), [
    'src/api/local/fixture.ts:2: literal local throw',
  ])
})

test('source auditor ignores comments around regex literals containing backticks', () => {
  const source = [
    'const fence = /```([\\w-]*)\\n?([\\s\\S]*?)```/g',
    '// 行内代码',
    'out = out.replace(/`([^`]+)`/g, value)',
    '// 粗体',
  ].join('\n')

  assert.deepEqual(auditSourceText(source, 'src/components/fixture.vue', []), [])
})

test('source auditor ignores comments after nested template literals', () => {
  const source = [
    'const html = `',
    '  ${Object.keys({ items }).length ? `<span>${items.length}</span>` : \'\'}',
    '`',
    '// 下限线',
    'const value = 1',
    '/* 样式注释 */',
  ].join('\n')

  assert.deepEqual(auditSourceText(source, 'src/components/fixture.vue', []), [])
})
