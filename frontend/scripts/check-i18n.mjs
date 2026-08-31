import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = fileURLToPath(new URL('..', import.meta.url))
const localesDir = join(root, 'src', 'locales')
const localeFiles = ['zh-CN.json', 'en-US.json', 'ar.json']

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

function collectSourceKeys() {
  const sourceRoot = join(root, 'src')
  const files = walkFiles(sourceRoot, ['.ts', '.vue', '.js'])
  const keys = new Set()
  const sourcePattern = /[^A-Za-z0-9_.]t\(\s*(['"])([^'"]+)\1\s*(?:,|\))/g

  for (const file of files) {
    const source = readFileSync(file, 'utf8')
    for (const match of source.matchAll(sourcePattern)) {
      keys.add(match[2])
    }
  }

  return keys
}

function checkSources() {
  const catalogs = localeFiles.map((file) => ({ file, keys: flattenKeys(readCatalog(file)) }))
  const sourceKeys = collectSourceKeys()
  const missing = []

  for (const key of sourceKeys) {
    if (!catalogs[0].keys.has(key)) {
      missing.push(key)
    }
  }

  if (missing.length > 0) {
    console.error('Source references translation keys missing from locale catalogs:')
    for (const key of missing) console.error(`- ${key}`)
    process.exit(1)
  }

  console.log(`Checked ${sourceKeys.size} source translation keys against all locale catalogs.`)
}

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
