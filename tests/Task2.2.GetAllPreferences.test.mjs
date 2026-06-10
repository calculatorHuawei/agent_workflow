// Task 2.2 — getAllPreferences 扩展
// 验证 getAllPreferences 返回 12 字段（10 旧 + 2 新）
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const p = fileURLToPath(new URL('../opencalc/entry/src/main/ets/preferences/PreferencesStore.ets', import.meta.url))
const src = readFileSync(p, 'utf8')

test('Task 2.2: CalculatorPreferences 接口新增 programmerModeDefault + defaultBase 字段', () => {
  // 接口定义在 Models.ets
  const models = fileURLToPath(new URL('../opencalc/entry/src/main/ets/model/Models.ets', import.meta.url))
  const modelsSrc = readFileSync(models, 'utf8')
  assert.ok(modelsSrc.includes('programmerModeDefault'), 'CalculatorPreferences 必须包含 programmerModeDefault')
  assert.ok(modelsSrc.includes('defaultBase'), 'CalculatorPreferences 必须包含 defaultBase')
})

test('Task 2.2: DEFAULT_PREFERENCES 同步填入新字段默认值', () => {
  const models = fileURLToPath(new URL('../opencalc/entry/src/main/ets/model/Models.ets', import.meta.url))
  const modelsSrc = readFileSync(models, 'utf8')
  // 解析 DEFAULT_PREFERENCES 块
  const match = modelsSrc.match(/DEFAULT_PREFERENCES:\s*CalculatorPreferences\s*=\s*\{([\s\S]*?)\n\}/)
  assert.ok(match, 'DEFAULT_PREFERENCES 块必须存在')
  const body = match[1]
  // 接受字面值 0/10 或枚举引用 CalculatorMode.BASIC(=0) / NumberBase.DEC(=10)
  assert.ok(/programmerModeDefault:\s*(0|CalculatorMode\.BASIC)/.test(body), 'programmerModeDefault 默认 0 (BASIC)')
  assert.ok(/defaultBase:\s*(10|NumberBase\.DEC)/.test(body), 'defaultBase 默认 10 (DEC)')
})

test('Task 2.2: getAllPreferences 返回 12 字段（10 旧 + 2 新）', () => {
  const match = src.match(/async\s+getAllPreferences[\s\S]*?return\s*\{([\s\S]*?)\n\s*\}/m)
  assert.ok(match, 'getAllPreferences 必须存在')
  const fields = [
    'theme', 'forceDayNight', 'vibrationEnabled', 'preventSleep', 'historySize',
    'scientificModeDefault', 'radiansDefault', 'numberPrecision',
    'decimalSeparatorSymbol', 'groupingSeparatorSymbol',
    'programmerModeDefault', 'defaultBase'
  ]
  for (const f of fields) {
    assert.ok(match[1].includes(f), `getAllPreferences 返回值必须包含字段: ${f}`)
  }
})
