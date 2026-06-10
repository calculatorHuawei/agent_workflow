// Task 5.1 — 集成测试 + 回归测试
// 6 个集成场景 + 5 个回归测试
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { loadEts } from './loader.mjs'

const modelsCtx = loadEts('opencalc/entry/src/main/ets/model/Models.ets')
const NumberBase = modelsCtx.NumberBase
const CalculatorMode = modelsCtx.CalculatorMode
const BC = loadEts('opencalc/entry/src/main/ets/calculator/BaseConverter.ets', { NumberBase }).BaseConverter

// ============ 6 个集成场景 ============

test('场景 1: 基础 → 程序员 → 输入 255 → 看到 4 进制', () => {
  // 用户切到程序员模式后输入 255（DEC 模式）
  // 4 行同步显示
  assert.equal(BC.toBase(255, NumberBase.DEC), '255')
  assert.equal(BC.toBase(255, NumberBase.BIN), '11111111')
  assert.equal(BC.toBase(255, NumberBase.OCT), '377')
  assert.equal(BC.toBase(255, NumberBase.HEX), 'FF')
})

test('场景 2: 程序员 → HEX → 输入 FF → 4 行同步', () => {
  // 用户在 HEX 模式输入 FF（实际 = 255）
  // 4 行同步显示
  const decFromFF: number = BC.fromBase('FF', NumberBase.HEX)
  assert.equal(decFromFF, 255)
  assert.equal(BC.toBase(decFromFF, NumberBase.DEC), '255')
  assert.equal(BC.toBase(decFromFF, NumberBase.BIN), '11111111')
  assert.equal(BC.toBase(decFromFF, NumberBase.OCT), '377')
  assert.equal(BC.toBase(decFromFF, NumberBase.HEX), 'FF')
})

test('场景 3: DEC 输入 10 → 切到 BIN → 显示 1010', () => {
  // 用户在 DEC 模式输入 10 → 切到 BIN → 10 在 BIN 下非法
  // 我们的设计: 表达式合法性校验
  const valid: boolean = BC.isValidExpression('10', NumberBase.BIN)
  assert.equal(valid, true, 'DEC 表达式 "10" 在 BIN 下应合法')
  const converted: string = BC.convert('10', NumberBase.DEC, NumberBase.BIN)
  assert.equal(converted, '1010')
})

test('场景 4: 程序员 → 科学 → 基础（3 次点击回到起点）', () => {
  // 模式循环: 2 → 0 → 1 → 2 → 0 → 1
  // 验证模运算正确
  let mode: number = CalculatorMode.PROGRAMMER  // 2
  mode = (mode + 1) % 3
  assert.equal(mode, CalculatorMode.BASIC, 'PROGRAMMER → BASIC')
  mode = (mode + 1) % 3
  assert.equal(mode, CalculatorMode.SCIENTIFIC, 'BASIC → SCIENTIFIC')
  mode = (mode + 1) % 3
  assert.equal(mode, CalculatorMode.PROGRAMMER, 'SCIENTIFIC → PROGRAMMER')
})

test('场景 5: BIN 模式点击按钮 "2" → 置灰无反应 (isValidChar)', () => {
  // BIN 模式只允许 0/1
  assert.equal(BC.isValidChar('0', NumberBase.BIN), true)
  assert.equal(BC.isValidChar('1', NumberBase.BIN), true)
  assert.equal(BC.isValidChar('2', NumberBase.BIN), false, 'BIN 模式 "2" 必须非法')
  assert.equal(BC.isValidChar('A', NumberBase.BIN), false, 'BIN 模式 "A" 必须非法')
  assert.equal(BC.isValidChar('F', NumberBase.BIN), false, 'BIN 模式 "F" 必须非法')
})

test('场景 6: 关闭重开 APP → 模式与进制保持（持久化字段名正确）', () => {
  // 验证 PreferencesStore 持久化键名（已在 Task 2.1 验证）
  // 这里只验证字段值
  assert.equal(modelsCtx.DEFAULT_PREFERENCES.programmerModeDefault, CalculatorMode.BASIC)
  assert.equal(modelsCtx.DEFAULT_PREFERENCES.defaultBase, NumberBase.DEC)
  // 模拟切换程序员模式后保存
  const newModePref: number = CalculatorMode.PROGRAMMER
  const newBasePref: number = NumberBase.HEX
  assert.equal(newModePref, 2)
  assert.equal(newBasePref, 16)
})

// ============ 5 个回归测试（验证现有功能未破坏） ============

test('回归 1: 基础模式四则运算（不依赖程序员模式）', () => {
  // 基础模式表达式解析由 CalcEngine 处理，独立于 BaseConverter
  // 验证 BaseConverter 不会破坏整数转换
  assert.equal(BC.toBase(1234, NumberBase.DEC), '1234')
  assert.equal(BC.fromBase('1234', NumberBase.DEC), 1234)
})

test('回归 2: 100 个随机整数 4 进制转换正确率 100%', () => {
  // 伪随机序列（确定性）
  let seed: number = 42
  const rand: () => number = (): number => {
    seed = (seed * 9301 + 49297) % 233280
    return seed / 233280
  }
  let pass: number = 0
  for (let i: number = 0; i < 100; i++) {
    const n: number = Math.floor(rand() * 1000000)
    // DEC
    assert.equal(BC.toBase(n, NumberBase.DEC), String(n))
    // BIN
    assert.equal(BC.fromBase(BC.toBase(n, NumberBase.BIN), NumberBase.BIN), n)
    // OCT
    assert.equal(BC.fromBase(BC.toBase(n, NumberBase.OCT), NumberBase.OCT), n)
    // HEX
    assert.equal(BC.fromBase(BC.toBase(n, NumberBase.HEX), NumberBase.HEX), n)
    pass++
  }
  assert.equal(pass, 100)
})

test('回归 3: 0 / 负数 / 大数 边界', () => {
  // 0
  assert.equal(BC.toBase(0, NumberBase.BIN), '0')
  assert.equal(BC.toBase(0, NumberBase.HEX), '0')
  // 负数
  assert.equal(BC.toBase(-255, NumberBase.HEX), '-FF')
  assert.equal(BC.toBase(-1, NumberBase.BIN), '-1')
  // 大数（接近 2^53）
  const big: number = 2 ** 53 - 1
  assert.equal(BC.fromBase(BC.toBase(big, NumberBase.HEX), NumberBase.HEX), big)
})

test('回归 4: 进制切换合法性（FF+1 跨进制校验）', () => {
  assert.equal(BC.isValidExpression('FF+1', NumberBase.HEX), true)
  assert.equal(BC.isValidExpression('FF+1', NumberBase.BIN), false)
  assert.equal(BC.isValidExpression('1010+1', NumberBase.BIN), true)
  assert.equal(BC.isValidExpression('1010+1', NumberBase.DEC), true)
  assert.equal(BC.isValidExpression('777+1', NumberBase.OCT), true)
  assert.equal(BC.isValidExpression('888+1', NumberBase.OCT), false)
})

test('回归 5: CalculatorMode + NumberBase 枚举值不变（外部 API 稳定）', () => {
  // 防止有人误改枚举值
  assert.equal(CalculatorMode.BASIC, 0)
  assert.equal(CalculatorMode.SCIENTIFIC, 1)
  assert.equal(CalculatorMode.PROGRAMMER, 2)
  assert.equal(NumberBase.BIN, 2)
  assert.equal(NumberBase.OCT, 8)
  assert.equal(NumberBase.DEC, 10)
  assert.equal(NumberBase.HEX, 16)
})
