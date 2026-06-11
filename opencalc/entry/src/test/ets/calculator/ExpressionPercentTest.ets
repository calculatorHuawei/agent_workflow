// OpenCalc — 百分号语义单元测试
// 覆盖 REQ-7-02 ~ REQ-7-08
// 详见 specs/changes/20260611-requirement-add-percentage-btn/delta-design.md §D3.7
import { describe, beforeEach, it, expect } from '@ohos/hypium'
import { Expression } from '../../../main/ets/calculator/Expression'
import { CalcEngine } from '../../../main/ets/calculator/Calculator'
import { ErrorFlags } from '../../../main/ets/model/ErrorFlags'

export function ExpressionPercentTest(): void {
  describe('ExpressionPercent', (): void => {
    const expr: Expression = new Expression()
    const engine: CalcEngine = new CalcEngine()
    const run: (s: string) => number = (s: string): number => {
      const clean: string = expr.getCleanExpression(s, '.', ',')
      return engine.evaluate(clean, true)
    }
    beforeEach((): void => { ErrorFlags.reset() })

    // REQ-7-02 / REQ-7-07 加法基数
    it('TC-01_50_plus_10_pct_equals_55', (): void => {
      expect(run('50+10%')).assertEqual(55)
    })
    // REQ-7-03 减法基数
    it('TC-02_200_minus_10_pct_equals_180', (): void => {
      expect(run('200-10%')).assertEqual(180)
    })
    // REQ-7-04 乘后置除
    it('TC-03_100_mul_10_pct_equals_10', (): void => {
      expect(run('100*10%')).assertEqual(10)
    })
    // REQ-7-05 除后置除
    it('TC-04_100_div_10_pct_equals_1000', (): void => {
      expect(run('100/10%')).assertEqual(1000)
    })
    // REQ-7-06 裸百分比
    it('TC-05_50_pct_alone_equals_0_5', (): void => {
      expect(run('50%')).assertEqual(0.5)
    })
    // 复合表达式
    it('TC-06_100_plus_50_mul_20_pct_equals_110', (): void => {
      expect(run('100+(50*20%)')).assertEqual(110)
    })
    // 括号 + 后置 %
    it('TC-07_paren_100_plus_50_mul_10_pct_equals_15', (): void => {
      expect(run('(100+50)*10%')).assertEqual(15)
    })
    // 阶乘后 %
    it('TC-08_5_factorial_pct_equals_1_2', (): void => {
      const r: number = run('5!%')
      expect(r > 1.199 && r < 1.201).assertTrue()
    })
  })
}
