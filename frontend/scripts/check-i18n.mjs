import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = fileURLToPath(new URL('..', import.meta.url))
const localesDir = join(root, 'src', 'locales')
const localeFiles = ['zh-CN.json', 'en-US.json', 'ar.json']
const sourceIgnorePaths = [
  'src/data',
  'src/locales',
  'src/api/local/seed.ts',
  'src/api/agent.ts',
  'src/api/local/agent',
  'src/utils/currencyNames.ts',
  'src/utils/catalogLabels.ts',
  'src/utils/pastePriceParser.ts',
  'src/utils/coordinateTransform.ts',
  'src/utils/coordTransform.ts',
  'src/utils/map*',
]

function flattenKeys(value, prefix = '', out = new Set()) {
  if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
    for (const [key, child] of Object.entries(value)) {
      flattenKeys(child, prefix ? `${prefix}.${key}` : key, out)
    }
  } else {
    out.add(prefix)
  }
  return out
}

function readCatalog(file) {
  const path = join(localesDir, file)
  if (!existsSync(path)) {
    throw new Error(`Missing locale catalog: ${file}`)
  }
  try {
    return JSON.parse(readFileSync(path, 'utf8'))
  } catch (error) {
    throw new Error(`Invalid JSON in ${file}: ${error instanceof Error ? error.message : String(error)}`)
  }
}

function checkKeys() {
  const catalogs = localeFiles.map((file) => {
    const catalog = readCatalog(file)
    return { file, keys: flattenKeys(catalog) }
  })

  const baseline = catalogs[0]
  const missingByCatalog = []

  for (let i = 1; i < catalogs.length; i += 1) {
    const missingInCurrent = [...baseline.keys].filter((key) => !catalogs[i].keys.has(key))
    if (missingInCurrent.length > 0) {
      missingByCatalog.push(`${catalogs[i].file}: missing ${missingInCurrent.join(', ')}`)
    }
  }

  for (let i = 1; i < catalogs.length; i += 1) {
    const extraInCurrent = [...catalogs[i].keys].filter((key) => !baseline.keys.has(key))
    if (extraInCurrent.length > 0) {
      missingByCatalog.push(`${catalogs[i].file}: extra ${extraInCurrent.join(', ')}`)
    }
  }

  if (missingByCatalog.length > 0) {
    console.error('Locale catalogs are not identical:')
    for (const line of missingByCatalog) console.error(`- ${line}`)
    process.exit(1)
  }

  console.log(`Checked ${localeFiles.length} locale catalogs; all key trees match.`)
}

function walkFiles(dir, extensions) {
  const files = []
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry)
    const stat = statSync(path)
    if (stat.isDirectory()) {
      files.push(...walkFiles(path, extensions))
    } else if (extensions.some((ext) => entry.endsWith(ext))) {
      files.push(path)
    }
  }
  return files
}

function toRelativePath(file) {
  return relative(root, file).replaceAll('\\', '/')
}

function isIgnoredSource(relativePath) {
  if (relativePath.startsWith('src/utils/')) {
    const firstSegment = relativePath.slice('src/utils/'.length).split('/')[0]
    if (firstSegment.startsWith('map')) return true
  }
  return sourceIgnorePaths.some((ignored) => (
    relativePath === ignored || relativePath.startsWith(`${ignored}/`)
  ))
}

export function stripSourceComments(source) {
  let result = ''
  let cursor = 0
  const contextStack = []
  let mode = 'code'
  const canStartRegex = (index) => {
    let previous = index - 1
    while (previous >= 0 && /\s/.test(source[previous])) previous -= 1
    if (previous < 0) return true

    const char = source[previous]
    if ('=([{,;:!&|?+-%<>'.includes(char)) return true

    const beforeChar = source.slice(0, previous + 1).match(/[\w$]+$/)?.[0]
    return ['case', 'delete', 'in', 'instanceof', 'new', 'return', 'typeof', 'void'].includes(beforeChar ?? '')
  }

  while (cursor < source.length) {
    if (mode === 'templateText') {
      if (source.startsWith('${', cursor)) {
        result += '${'
        cursor += 2
        contextStack.push({ type: 'expression', braceDepth: 0 })
        mode = 'expression'
        continue
      }

      result += source[cursor]
      if (source[cursor] === '\\') {
        cursor += 1
        if (cursor < source.length) {
          result += source[cursor]
          cursor += 1
        }
        continue
      }
      if (source[cursor] === '`') {
        cursor += 1
        contextStack.pop()
        const parent = contextStack.at(-1)
        mode = parent?.type === 'expression' ? 'expression' : 'code'
      } else {
        cursor += 1
      }
      continue
    }

    if (mode === 'expression' && source[cursor] === '}') {
      const expression = contextStack.at(-1)
      if (expression?.braceDepth === 0) {
        result += source[cursor]
        cursor += 1
        contextStack.pop()
        const parent = contextStack.at(-1)
        mode = parent?.type === 'template' ? 'templateText' : 'expression'
        continue
      }
      expression.braceDepth -= 1
    }

    if (mode === 'expression' && source[cursor] === '{') {
      const expression = contextStack.at(-1)
      if (expression) expression.braceDepth += 1
    }

    if (source.startsWith('//', cursor)) {
      while (cursor < source.length && source[cursor] !== '\n') {
        result += ' '
        cursor += 1
      }
      continue
    }

    if (source.startsWith('/*', cursor)) {
      while (cursor < source.length && !source.startsWith('*/', cursor)) {
        result += source[cursor] === '\n' ? '\n' : ' '
        cursor += 1
      }
      if (cursor < source.length) {
        result += '  '
        cursor += 2
      }
      continue
    }

    if (source.startsWith('<!--', cursor)) {
      while (cursor < source.length && !source.startsWith('-->', cursor)) {
        result += source[cursor] === '\n' ? '\n' : ' '
        cursor += 1
      }
      if (cursor < source.length) {
        result += '   '
        cursor += 3
      }
      continue
    }

    if (source[cursor] === '/' && canStartRegex(cursor)) {
      result += source[cursor]
      cursor += 1
      let inCharacterClass = false
      while (cursor < source.length) {
        result += source[cursor]
        if (source[cursor] === '\\') {
          cursor += 1
          if (cursor < source.length) {
            result += source[cursor]
            cursor += 1
          }
          continue
        }
        if (source[cursor] === '\n') break
        if (source[cursor] === '[') inCharacterClass = true
        else if (source[cursor] === ']' && inCharacterClass) inCharacterClass = false
        else if (source[cursor] === '/' && !inCharacterClass) {
          cursor += 1
          break
        }
        cursor += 1
      }
      continue
    }

    if (source[cursor] === '`') {
      result += source[cursor]
      cursor += 1
      contextStack.push({ type: 'template' })
      mode = 'templateText'
      continue
    }

    const quote = source[cursor]
    if (quote === '\'' || quote === '"') {
      result += quote
      cursor += 1
      while (cursor < source.length) {
        result += source[cursor]
        if (source[cursor] === '\\') {
          cursor += 1
          if (cursor < source.length) {
            result += source[cursor]
            cursor += 1
          }
          continue
        }
        if (source[cursor] === quote) {
          cursor += 1
          break
        }
        if (source[cursor] === '\n' && quote !== '`') break
        cursor += 1
      }
      continue
    }

    result += source[cursor]
    cursor += 1
  }

  return result
}

function collectSourceFiles() {
  const sourceRoot = join(root, 'src')
  return walkFiles(sourceRoot, ['.ts', '.vue', '.js'])
    .map((file) => ({ file, relativePath: toRelativePath(file) }))
    .filter(({ relativePath }) => !isIgnoredSource(relativePath))
}

export function collectTranslationKeys(source) {
  const keys = new Set()
  const sourcePattern = /\b(?:t|translate)\(\s*(['"])([^'"]+)\1\s*(?:,|\))/g

  for (const match of stripSourceComments(source).matchAll(sourcePattern)) {
    keys.add(match[2])
  }

  return [...keys].sort()
}

function collectSourceKeys(sourceFiles) {
  const keys = new Set()

  for (const { file } of sourceFiles) {
    for (const key of collectTranslationKeys(readFileSync(file, 'utf8'))) {
      keys.add(key)
    }
  }

  return keys
}

function lineForIndex(source, index) {
  return source.slice(0, index).split('\n').length
}

export function auditSourceText(source, relativePath, catalogs) {
  const findings = []
  const stripped = stripSourceComments(source)
  const lines = stripped.split('\n')
  const hanPattern = /[\u3400-\u9fff]/
  const throwPattern = /\bthrow\s*\{[\s\S]*?\bmessage\s*:\s*['"`]/g
  const localErrorPattern = /\blocalError\(\s*(['"])([A-Za-z0-9_.-]+)\1/g

  lines.forEach((line, index) => {
    if (hanPattern.test(line)) {
      findings.push(`${relativePath}:${index + 1}: Han text: ${line.trim()}`)
    }
  })

  if (relativePath.startsWith('src/api/local/')) {
    for (const match of stripped.matchAll(throwPattern)) {
      findings.push(`${relativePath}:${lineForIndex(stripped, match.index)}: literal local throw`)
    }
  }

  for (const match of stripped.matchAll(new RegExp(localErrorPattern.source, 'g'))) {
    const key = `localErrors.${match[2]}`
    const missing = catalogs.filter(({ keys }) => !keys.has(key)).map(({ file }) => file)
    if (missing.length > 0) {
      findings.push(
        `${relativePath}:${lineForIndex(stripped, match.index)}: missing ${key} in ${missing.join(', ')}`,
      )
    }
  }

  return findings
}

function collectSourceFindings(sourceFiles, catalogs) {
  return sourceFiles.flatMap(({ file, relativePath }) => (
    auditSourceText(readFileSync(file, 'utf8'), relativePath, catalogs)
  ))
}

function checkSources() {
  const catalogs = localeFiles.map((file) => ({ file, keys: flattenKeys(readCatalog(file)) }))
  const sourceFiles = collectSourceFiles()
  const sourceKeys = collectSourceKeys(sourceFiles)
  const missing = []

  for (const key of sourceKeys) {
    const missingIn = catalogs.filter(({ keys }) => !keys.has(key)).map(({ file }) => file)
    if (missingIn.length > 0) missing.push(`${key} (${missingIn.join(', ')})`)
  }

  const findings = [...missing.map((key) => `missing source key: ${key}`), ...collectSourceFindings(sourceFiles, catalogs)]
  if (findings.length > 0) {
    console.error('Source i18n audit failed:')
    for (const finding of findings) console.error(`- ${finding}`)
    process.exit(1)
  }

  console.log(
    `Checked ${sourceKeys.size} source translation keys and localized source rules across all locale catalogs.`,
  )
}

const isCli = process.argv[1] === fileURLToPath(import.meta.url)

if (isCli) {
  const mode = process.argv[2]

  try {
    if (mode === 'keys') {
      checkKeys()
    } else if (mode === 'sources') {
      checkSources()
    } else {
      console.error('Usage: node scripts/check-i18n.mjs <keys|sources>')
      process.exit(1)
    }
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  }
}
