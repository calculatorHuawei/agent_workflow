// Expression.test.ets — Issue #8 百分号按钮 (AC1-AC5)
// 测试目标:opencalc/entry/src/main/ets/calculator/Expression.ets#getPercentString
import { describe, it, expect } from '@ohos/hypium'
import { Expression } from '../../../main/ets/calculator/Expression'
import { CalcEngine } from '../../../main/ets/calculator/Calculator'
import { ErrorFlags } from '../../../main/ets/model/ErrorFlags'

export default function expressionTest() {
  describe('ExpressionPercentTest', () => {
    // 共享:每个 it() 前重置 ErrorFlags
    function compute(raw: string): number {
      ErrorFlags.reset()
      const expr: Expression = new Expression()
      const engine: CalcEngine = new CalcEngine()
      const clean: string = expr.getCleanExpression(raw, '.', ',')
      return engine.evaluate(clean, true)
    }

    it('AC1_50plus10percent_equals_55', 0, () => {
      const r: number = compute('50+10%')
      expect(r).assertEqual(55)
    })

    it('AC2_200minus15percent_equals_170', 0, () => {
      const r: number = compute('200-15%')
      expect(r).assertEqual(170)
    })

    it('AC3_30percent_equals_0p3', 0, () => {
      const r: number = compute('30%')
      // 浮点容差
      expect(Math.abs(r - 0.3) < 1e-9).assertTrue()
    })

    it('AC4_200times10percent_equals_20', 0, () => {
      const r: number = compute('200*10%')
      expect(r).assertEqual(20)
    })

    it('AC5_paren_50plus10_percent_equals_0p6', 0, () => {
      const r: number = compute('(50+10)%')
      expect(Math.abs(r - 0.6) < 1e-9).assertTrue()
    })

    it('AC_rewriting_50plus10percent_produces_expected_form', 0, () => {
      const expr: Expression = new Expression()
      const clean: string = expr.getCleanExpression('50+10%', '.', ',')
      // 期望 Expression 把 % 重写为 a + a*(b/100) 模式
      expect(clean).assertEqual('50+50*(10/100)')
    })
  })
}
