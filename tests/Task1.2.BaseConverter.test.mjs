// Task 1.2 — BaseConverter.ets: toBase / fromBase
// RED: 这些断言在 BaseConverter.ets 不存在时会失败
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { loadEts } from './loader.mjs'

const modelsCtx = loadEts('opencalc/entry/src/main/ets/model/Models.ets')
const NumberBase = modelsCtx.NumberBase

// Task 1.2 阶段: BaseConverter.ets 还不存在
// 用 try-catch 包裹 loadEts, 让每个测试断言独立
function loadBaseConverter() {
  try {
    return loadEts('opencalc/entry/src/main/ets/calculator/BaseConverter.ets', { NumberBase })
  } catch (e) {
    return null
  }
}

test('Task 1.2 GREEN: BaseConverter.ets 文件存在', () => {
  const bcPath = fileURLToPath(new URL('../opencalc/entry/src/main/ets/calculator/BaseConverter.ets', import.meta.url))
  assert.ok(existsSync(bcPath), 'BaseConverter.ets 必须存在')
})

test('Task 1.2: BaseConverter.toBase(255, BIN) === "11111111"', () => {
  const ctx = loadBaseConverter()
  assert.ok(ctx, 'BaseConverter 必须存在')
  assert.equal(ctx.BaseConverter.toBase(255, NumberBase.BIN), '11111111')
})

test('Task 1.2: BaseConverter.toBase(255, OCT) === "377"', () => {
  const ctx = loadBaseConverter()
  assert.equal(ctx.BaseConverter.toBase(255, NumberBase.OCT), '377')
})

test('Task 1.2: BaseConverter.toBase(255, HEX) === "FF"（大写）', () => {
  const ctx = loadBaseConverter()
  assert.equal(ctx.BaseConverter.toBase(255, NumberBase.HEX), 'FF')
})

test('Task 1.2: BaseConverter.toBase(0, HEX) === "0"', () => {
  const ctx = loadBaseConverter()
  assert.equal(ctx.BaseConverter.toBase(0, NumberBase.HEX), '0')
})

test('Task 1.2: BaseConverter.toBase(-10, BIN) === "-1010"', () => {
  const ctx = loadBaseConverter()
  assert.equal(ctx.BaseConverter.toBase(-10, NumberBase.BIN), '-1010')
})

test('Task 1.2: BaseConverter.fromBase("FF", HEX) === 255', () => {
  const ctx = loadBaseConverter()
  assert.equal(ctx.BaseConverter.fromBase('FF', NumberBase.HEX), 255)
})

test('Task 1.2: BaseConverter.fromBase("ff", HEX) === 255（小写可解析）', () => {
  const ctx = loadBaseConverter()
  assert.equal(ctx.BaseConverter.fromBase('ff', NumberBase.HEX), 255)
})

test('Task 1.2: 0 边界 - toBase(0, BIN) === "0"', () => {
  const ctx = loadBaseConverter()
  assert.equal(ctx.BaseConverter.toBase(0, NumberBase.BIN), '0')
})

test('Task 1.2: 负数 - fromBase("-10", DEC) === -10', () => {
  const ctx = loadBaseConverter()
  assert.equal(ctx.BaseConverter.fromBase('-10', NumberBase.DEC), -10)
})

test('Task 1.2: fromBase 非法字符返回 NaN', () => {
  const ctx = loadBaseConverter()
  assert.ok(Number.isNaN(ctx.BaseConverter.fromBase('GG', NumberBase.HEX)))
})
