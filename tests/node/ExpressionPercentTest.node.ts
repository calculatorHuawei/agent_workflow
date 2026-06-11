// Node.js mirror of the Hypium ExpressionPercentTest
// 验证 ETS 逻辑在修复前是 RED、修复后是 GREEN
// 用 Node 自带 assert，不依赖 hypium
import { Expression } from './Expression.ts'
import { CalcEngine } from './Calculator.ts'
import { ErrorFlags } from './ErrorFlags.ts'
import * as assert from 'assert'

interface TC { id: string; expr: string; expected: number; tol?: number }

const TCs: TC[] = [
  { id: 'TC-01', expr: '50+10%',       expected: 55 },        // REQ-7-02, REQ-7-07
  { id: 'TC-02', expr: '200-10%',      expected: 180 },       // REQ-7-03
  { id: 'TC-03', expr: '100*10%',      expected: 10 },        // REQ-7-04
  { id: 'TC-04', expr: '100/10%',      expected: 1000 },      // REQ-7-05
  { id: 'TC-05', expr: '50%',          expected: 0.5 },       // REQ-7-06
  { id: 'TC-06', expr: '100+(50*20%)', expected: 110 },       // composite
  { id: 'TC-07', expr: '(100+50)*10%', expected: 15 },        // paren+postfix
  { id: 'TC-08', expr: '5!%',          expected: 1.2, tol: 1e-6 } // factorial+pct
]

const expr = new Expression()
const engine = new CalcEngine()
const run = (s: string): number => {
  ErrorFlags.reset()
  const clean: string = expr.getCleanExpression(s, '.', ',')
  return engine.evaluate(clean, true)
}

let passed = 0
let failed = 0
const results: { id: string; expr: string; expected: number; actual: number; ok: boolean; clean: string }[] = []
for (const tc of TCs) {
  ErrorFlags.reset()
  let clean = ''
  let actual = NaN
  let ok = false
  let err = ''
  try {
    clean = expr.getCleanExpression(tc.expr, '.', ',')
    actual = engine.evaluate(clean, true)
    const tol = tc.tol ?? 0
    if (tol > 0) ok = Math.abs(actual - tc.expected) < tol
    else ok = Math.abs(actual - tc.expected) < 1e-9
  } catch (e) { err = String(e) }
  results.push({ id: tc.id, expr: tc.expr, expected: tc.expected, actual, ok, clean })
  if (ok) passed++; else failed++
}
console.log('┌──────┬────────────────┬────────────┬────────────┬─────────┐')
console.log('│  ID  │  expression    │  expected  │  actual    │ result  │')
console.log('├──────┼────────────────┼────────────┼────────────┼─────────┤')
for (const r of results) {
  const ok = r.ok ? '   ✅   ' : '   ❌   '
  console.log(`│ ${r.id} │ ${r.expr.padEnd(14)} │ ${String(r.expected).padEnd(10)} │ ${r.actual.toFixed(4).padEnd(10)} │${ok}│`)
  if (!r.ok) console.log(`│      clean="${r.clean}"  errorFlags=${JSON.stringify(ErrorFlags)}`)
}
console.log('└──────┴────────────────┴────────────┴────────────┴─────────┘')
console.log(`\nResult: ${passed}/${TCs.length} PASS, ${failed}/${TCs.length} FAIL`)
process.exit(failed === 0 ? 0 : 1)
