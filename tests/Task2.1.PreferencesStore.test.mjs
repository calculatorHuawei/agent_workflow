// Task 2.1 — PreferencesStore.ets: 4 个新偏好方法
// 测试: 验证源代码包含 4 个方法 + DEFAULT_PREFERENCES 包含新字段
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { loadEts } from './loader.mjs'

const modelsCtx = loadEts('opencalc/entry/src/main/ets/model/Models.ets')

test('Task 2.1: PreferencesStore.ets 存在', () => {
  const p = fileURLToPath(new URL('../opencalc/entry/src/main/ets/preferences/PreferencesStore.ets', import.meta.url))
  assert.ok(existsSync(p), 'PreferencesStore.ets 必须存在')
})

test('Task 2.1: PreferencesStore.ets 包含 4 个新方法', () => {
  const p = fileURLToPath(new URL('../opencalc/entry/src/main/ets/preferences/PreferencesStore.ets', import.meta.url))
  const src = readFileSync(p, 'utf8')
  assert.ok(src.includes('getProgrammerModeDefault'), '必须包含 getProgrammerModeDefault')
  assert.ok(src.includes('setProgrammerModeDefault'), '必须包含 setProgrammerModeDefault')
  assert.ok(src.includes('getDefaultBase'), '必须包含 getDefaultBase')
  assert.ok(src.includes('setDefaultBase'), '必须包含 setDefaultBase')
})

test('Task 2.1: 4 个新方法签名与设计一致', () => {
  const p = fileURLToPath(new URL('../opencalc/entry/src/main/ets/preferences/PreferencesStore.ets', import.meta.url))
  const src = readFileSync(p, 'utf8')
  // 检查键名
  assert.ok(src.includes("'programmerModeDefault'"), '必须使用键名 programmerModeDefault')
  assert.ok(src.includes("'defaultBase'"), '必须使用键名 defaultBase')
  // 检查默认值引用
  assert.ok(src.includes('DEFAULT_PREFERENCES.programmerModeDefault'), '必须引用 DEFAULT_PREFERENCES.programmerModeDefault')
  assert.ok(src.includes('DEFAULT_PREFERENCES.defaultBase'), '必须引用 DEFAULT_PREFERENCES.defaultBase')
  // 检查 store===null 兜底
  assert.ok(/if\s*\(\s*!this\.store\s*\)/.test(src), '必须有 store===null 兜底')
})

test('Task 2.1: set 方法包含 flush', () => {
  const p = fileURLToPath(new URL('../opencalc/entry/src/main/ets/preferences/PreferencesStore.ets', import.meta.url))
  const src = readFileSync(p, 'utf8')
  // 提取 setProgrammerModeDefault 和 setDefaultBase 方法体
  const setProgMatch = src.match(/async\s+setProgrammerModeDefault[\s\S]*?\n\s*}/m)
  const setBaseMatch = src.match(/async\s+setDefaultBase[\s\S]*?\n\s*}/m)
  assert.ok(setProgMatch, 'setProgrammerModeDefault 必须存在')
  assert.ok(setBaseMatch, 'setDefaultBase 必须存在')
  assert.ok(setProgMatch[0].includes('flush'), 'setProgrammerModeDefault 必须 flush')
  assert.ok(setBaseMatch[0].includes('flush'), 'setDefaultBase 必须 flush')
})

test('Task 2.1: DEFAULT_PREFERENCES 包含新字段', () => {
  assert.equal(modelsCtx.DEFAULT_PREFERENCES.programmerModeDefault, 0, 'programmerModeDefault 默认值应为 0 (BASIC)')
  assert.equal(modelsCtx.DEFAULT_PREFERENCES.defaultBase, 10, 'defaultBase 默认值应为 10 (DEC)')
})
