import assert from 'node:assert/strict'
import { test } from 'node:test'
import {
  formatDate,
  formatDateTime,
  formatMoney,
  formatNumber,
  formatPercent,
  formatTime,
  resolveFormatLocale,
} from './format.ts'

const localDate = new Date(2026, 7, 31, 9, 46, 5)

test('resolveFormatLocale prefers an explicit format locale', () => {
  assert.equal(resolveFormatLocale('zh-CN', 'de-DE'), 'de-DE')
  assert.equal(resolveFormatLocale('ar', 'ar-EG'), 'ar-EG')
})

test('resolveFormatLocale maps UI locale defaults', () => {
  assert.equal(resolveFormatLocale('zh-CN', null), 'zh-CN')
  assert.equal(resolveFormatLocale('en-US', null), 'en-US')
  assert.equal(resolveFormatLocale('ar', null), 'ar-EG')
})

test('resolveFormatLocale falls back for unknown locales', () => {
  assert.equal(resolveFormatLocale('fr-FR', null), 'zh-CN')
  assert.equal(resolveFormatLocale('ar-SA', null), 'ar-EG')
  assert.equal(resolveFormatLocale('zh-TW', null), 'zh-TW')
})

test('representative format locales', () => {
  assert.equal(formatNumber(1234.5, 'de-DE'), '1.234,5')
  assert.equal(formatNumber(1234.5, 'en-US'), '1,234.5')
  assert.equal(formatPercent(0.25, 'en-US'), '25%')
  assert.equal(formatMoney(1234.5, 'USD', 'en-US'), '1,234.50 USD')
  assert.equal(formatDate('2026-08-31', 'ja-JP'), '2026/08/31')
})

test('en-GB and ar-EG use locale-native date, time, number, and money formatting', () => {
  assert.equal(formatDate(localDate, 'en-GB'), '31/08/2026')
  assert.equal(formatTime(localDate, 'en-GB'), '09:46')
  assert.equal(formatDateTime(localDate, 'en-GB'), '31/08/2026, 09:46')
  assert.equal(formatNumber(1234.5, 'en-GB'), '1,234.5')
  assert.equal(formatPercent(0.25, 'en-GB'), '25%')
  assert.equal(formatMoney(1234.5, 'USD', 'en-GB'), '1,234.50 USD')

  assert.equal(formatDate(localDate, 'ar-EG'), '٣١‏/٠٨‏/٢٠٢٦')
  assert.equal(formatTime(localDate, 'ar-EG'), '٠٩:٤٦ ص')
  assert.equal(formatDateTime(localDate, 'ar-EG'), '٣١‏/٠٨‏/٢٠٢٦، ٠٩:٤٦ ص')
  assert.equal(formatNumber(1234.5, 'ar-EG'), '١٬٢٣٤٫٥')
  assert.equal(formatPercent(0.25, 'ar-EG'), '٢٥٪؜')
  assert.equal(formatMoney(1234.5, 'USD', 'ar-EG'), '‏١٬٢٣٤٫٥٠ USD')
})

test('date, time, and date-time defaults use two-digit components', () => {
  assert.equal(formatDate(localDate, 'en-US'), '08/31/2026')
  assert.equal(formatTime(localDate, 'en-US'), '09:46 AM')
  assert.equal(formatDateTime(localDate, 'en-US'), '08/31/2026, 09:46 AM')

  assert.equal(formatDate(localDate, 'de-DE'), '31.08.2026')
  assert.equal(formatTime(localDate, 'de-DE'), '09:46')
  assert.equal(formatDateTime(localDate, 'de-DE'), '31.08.2026, 09:46')

  assert.equal(formatDate(localDate, 'ja-JP'), '2026/08/31')
  assert.equal(formatTime(localDate, 'ja-JP'), '09:46')
  assert.equal(formatDateTime(localDate, 'ja-JP'), '2026/08/31 09:46')
})

test('number, percent, and money honor explicit options', () => {
  assert.equal(formatNumber('1234.5', 'en-US', { maximumFractionDigits: 1 }), '1,234.5')
  assert.equal(formatPercent('0.256', 'en-US', { maximumFractionDigits: 1 }), '25.6%')
  assert.equal(formatMoney('1234.5', 'JPY', 'ja-JP'), '1,235 JPY')
})

test('invalid inputs return -', () => {
  assert.equal(formatDate('not-a-date', 'en-US'), '-')
  assert.equal(formatTime(null, 'en-US'), '-')
  assert.equal(formatDateTime(undefined, 'en-US'), '-')
  assert.equal(formatNumber('abc', 'en-US'), '-')
  assert.equal(formatNumber('Infinity', 'en-US'), '-')
  assert.equal(formatPercent(null, 'en-US'), '-')
  assert.equal(formatMoney('abc', 'USD', 'en-US'), '-')
})
