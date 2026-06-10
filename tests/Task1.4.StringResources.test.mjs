// Task 1.4 — string.json 资源
// 验证 base/en_US/zh_CN 三个 string.json 都包含程序员模式相关 key
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const basePath = fileURLToPath(new URL('../opencalc/entry/src/main/resources/base/element/string.json', import.meta.url))
const enPath = fileURLToPath(new URL('../opencalc/entry/src/main/resources/en_US/element/string.json', import.meta.url))
const zhPath = fileURLToPath(new URL('../opencalc/entry/src/main/resources/zh_CN/element/string.json', import.meta.url))

test('Task 1.4: 三个 string.json 文件存在', () => {
  assert.ok(existsSync(basePath), 'base/string.json 必须存在')
  assert.ok(existsSync(enPath), 'en_US/string.json 必须存在')
  assert.ok(existsSync(zhPath), 'zh_CN/string.json 必须存在')
})

function collectNames(jsonPath) {
  const obj = JSON.parse(readFileSync(jsonPath, 'utf8'))
  return new Set(obj.string.map(s => s.name))
}

const REQUIRED_KEYS = [
  'mode_basic', 'mode_scientific', 'mode_programmer',
  'base_dec', 'base_bin', 'base_oct', 'base_hex',
  'hex_a', 'hex_b', 'hex_c', 'hex_d', 'hex_e', 'hex_f',
  'error_overflow', 'error_invalid',
  'error_decimal_not_supported', 'error_expression_not_supported',
  'setting_default_mode', 'setting_default_base'
]

test('Task 1.4: base string.json 包含全部程序员模式 key', () => {
  const names = collectNames(basePath)
  for (const k of REQUIRED_KEYS) {
    assert.ok(names.has(k), `base/string.json 缺少 key: ${k}`)
  }
})

test('Task 1.4: en_US string.json 包含全部程序员模式 key', () => {
  const names = collectNames(enPath)
  for (const k of REQUIRED_KEYS) {
    assert.ok(names.has(k), `en_US/string.json 缺少 key: ${k}`)
  }
})

test('Task 1.4: zh_CN string.json 包含全部程序员模式 key', () => {
  const names = collectNames(zhPath)
  for (const k of REQUIRED_KEYS) {
    assert.ok(names.has(k), `zh_CN/string.json 缺少 key: ${k}`)
  }
})

test('Task 1.4: 现有 key (module_desc / EntryAbility_*) 保留', () => {
  const base = collectNames(basePath)
  assert.ok(base.has('module_desc'), 'base 必须保留 module_desc')
  assert.ok(base.has('EntryAbility_desc'), 'base 必须保留 EntryAbility_desc')
  assert.ok(base.has('EntryAbility_label'), 'base 必须保留 EntryAbility_label')
})

test('Task 1.4: zh_CN mode_programmer 值为"程序员"', () => {
  const obj = JSON.parse(readFileSync(zhPath, 'utf8'))
  const m = obj.string.find(s => s.name === 'mode_programmer')
  assert.equal(m.value, '程序员')
})

test('Task 1.4: en_US mode_programmer 值为"Programmer"', () => {
  const obj = JSON.parse(readFileSync(enPath, 'utf8'))
  const m = obj.string.find(s => s.name === 'mode_programmer')
  assert.equal(m.value, 'Programmer')
})
