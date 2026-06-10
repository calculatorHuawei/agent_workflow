// Task 1.3 — BaseConverter.ets 扩展: isValidChar / formatHex / convert / isOverflow / isValidExpression
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { loadEts } from './loader.mjs'

const modelsCtx = loadEts('opencalc/entry/src/main/ets/model/Models.ets')
const NumberBase = modelsCtx.NumberBase
const ctx = loadEts('opencalc/entry/src/main/ets/calculator/BaseConverter.ets', { NumberBase })
const BC = ctx.BaseConverter

// isValidChar
test('Task 1.3 RED: isValidChar("0", BIN) === true', () => {
  assert.equal(BC.isValidChar('0', NumberBase.BIN), true)
})
test('Task 1.3 RED: isValidChar("2", BIN) === false', () => {
  assert.equal(BC.isValidChar('2', NumberBase.BIN), false)
})
test('Task 1.3 RED: isValidChar("7", OCT) === true', () => {
  assert.equal(BC.isValidChar('7', NumberBase.OCT), true)
})
test('Task 1.3 RED: isValidChar("8", OCT) === false', () => {
  assert.equal(BC.isValidChar('8', NumberBase.OCT), false)
})
test('Task 1.3 RED: isValidChar("9", DEC) === true', () => {
  assert.equal(BC.isValidChar('9', NumberBase.DEC), true)
})
test('Task 1.3 RED: isValidChar("A", DEC) === false', () => {
  assert.equal(BC.isValidChar('A', NumberBase.DEC), false)
})
test('Task 1.3 RED: isValidChar("F", HEX) === true', () => {
  assert.equal(BC.isValidChar('F', NumberBase.HEX), true)
})
test('Task 1.3 RED: isValidChar("G", HEX) === false', () => {
  assert.equal(BC.isValidChar('G', NumberBase.HEX), false)
})
test('Task 1.3 RED: isValidChar("a", HEX) === true（小写）', () => {
  assert.equal(BC.isValidChar('a', NumberBase.HEX), true)
})

// formatHex
test('Task 1.3 RED: formatHex("ff00ab") === "FF00AB"（大写化）', () => {
  assert.equal(BC.formatHex('ff00ab'), 'FF00AB')
})

// convert
test('Task 1.3 RED: convert("ff", HEX, BIN) === "11111111"', () => {
  assert.equal(BC.convert('ff', NumberBase.HEX, NumberBase.BIN), '11111111')
})
test('Task 1.3 RED: convert("1010", BIN, DEC) === "10"', () => {
  assert.equal(BC.convert('1010', NumberBase.BIN, NumberBase.DEC), '10')
})

// isOverflow
test('Task 1.3 RED: isOverflow(2 ** 54) === true', () => {
  assert.equal(BC.isOverflow(2 ** 54), true)
})
test('Task 1.3 RED: isOverflow(2 ** 53) === false', () => {
  assert.equal(BC.isOverflow(2 ** 53), false)
})
test('Task 1.3 RED: isOverflow(-(2 ** 54)) === true', () => {
  assert.equal(BC.isOverflow(-(2 ** 54)), true)
})

// isValidExpression
test('Task 1.3 RED: isValidExpression("FF+1", HEX) === true', () => {
  assert.equal(BC.isValidExpression('FF+1', NumberBase.HEX), true)
})
test('Task 1.3 RED: isValidExpression("FF+1", BIN) === false（含非法字符 F）', () => {
  assert.equal(BC.isValidExpression('FF+1', NumberBase.BIN), false)
})
test('Task 1.3 RED: isValidExpression("", BIN) === true（空字符串）', () => {
  assert.equal(BC.isValidExpression('', NumberBase.BIN), true)
})

// toBase 溢出
test('Task 1.3 RED: toBase(2 ** 54, BIN) === "Overflow"', () => {
  assert.equal(BC.toBase(2 ** 54, NumberBase.BIN), 'Overflow')
})
test('Task 1.3 RED: toBase(NaN, DEC) === "Invalid"', () => {
  assert.equal(BC.toBase(NaN, NumberBase.DEC), 'Invalid')
})
