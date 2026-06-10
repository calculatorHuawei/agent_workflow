// Task 1.1 — RED: 验证 CalculatorMode 与 NumberBase 枚举值
// 验收标准：
//  - CalculatorMode.PROGRAMMER === 2
//  - NumberBase.DEC === 10
//  - 现有 4 个枚举不受影响
//  - CalculatorError / NumberingSystem / ScientificModeType 仍可访问
import { loadEts } from './loader.mjs'

const ctx = loadEts('opencalc/entry/src/main/ets/model/Models.ets')

let failures = 0
function assert(label, actual, expected) {
  const ok = actual === expected
  console.log((ok ? '✅' : '❌') + ' ' + label + ' — actual=' + JSON.stringify(actual) + ' expected=' + JSON.stringify(expected))
  if (!ok) failures++
}

console.log('=== Task 1.1: Models.ets 枚举 ===')
// 现有枚举不被破坏
assert('CalculatorError.NONE', ctx.CalculatorError?.NONE, 'none')
assert('NumberingSystem.INTERNATIONAL', ctx.NumberingSystem?.INTERNATIONAL, 0)
assert('ScientificModeType.NOT_ACTIVE', ctx.ScientificModeType?.NOT_ACTIVE, 0)

// 新增枚举
assert('CalculatorMode.BASIC', ctx.CalculatorMode?.BASIC, 0)
assert('CalculatorMode.SCIENTIFIC', ctx.CalculatorMode?.SCIENTIFIC, 1)
assert('CalculatorMode.PROGRAMMER', ctx.CalculatorMode?.PROGRAMMER, 2)

assert('NumberBase.BIN', ctx.NumberBase?.BIN, 2)
assert('NumberBase.OCT', ctx.NumberBase?.OCT, 8)
assert('NumberBase.DEC', ctx.NumberBase?.DEC, 10)
assert('NumberBase.HEX', ctx.NumberBase?.HEX, 16)

// CalculatorPreferences 字段未受影响
assert('DEFAULT_PREFERENCES.theme', ctx.DEFAULT_PREFERENCES?.theme, 0)
assert('DEFAULT_PREFERENCES.historySize', ctx.DEFAULT_PREFERENCES?.historySize, 100)

if (failures > 0) {
  console.error('\n❌ ' + failures + ' assertion(s) failed')
  process.exit(1)
}
console.log('\n✅ All Task 1.1 assertions passed')
