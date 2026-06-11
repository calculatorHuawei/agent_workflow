// Calculator.test.ets — Issue #8 端到端集成测试
// 验证 CalcEngine + Expression 协同后,Issue #8 主验收点 "50+10%=55" 成立
import { describe, it, expect } from '@ohos/hypium'
import { Expression } from '../../../main/ets/calculator/Expression'
import { CalcEngine } from '../../../main/ets/calculator/Calculator'
import { ErrorFlags } from '../../../main/ets/model/ErrorFlags'

export default function calculatorTest() {
  describe('CalculatorIssue8E2E', () => {
    it('issue8_main_50plus10percent_equals_55', 0, () => {
      ErrorFlags.reset()
      const expr: Expression = new Expression()
      const engine: CalcEngine = new CalcEngine()
      const clean: string = expr.getCleanExpression('50+10%', '.', ',')
      const v: number = engine.evaluate(clean, true)
      expect(ErrorFlags.syntax_error).assertEqual(false)
      expect(ErrorFlags.division_by_0).assertEqual(false)
      expect(v).assertEqual(55)
    })

    it('issue8_percent_does_not_break_normal_arithmetic', 0, () => {
      ErrorFlags.reset()
      const expr: Expression = new Expression()
      const engine: CalcEngine = new CalcEngine()
      const clean: string = expr.getCleanExpression('1+2*3', '.', ',')
      const v: number = engine.evaluate(clean, true)
      expect(v).assertEqual(7)
    })
  })
}
