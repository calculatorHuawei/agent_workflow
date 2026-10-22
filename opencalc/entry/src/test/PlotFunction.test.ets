// OpenCalc — 函数绘图本地单元测试（Issue #40）
// 覆盖：SR-00 变量求值 / SR-01 采样分段（delta-spec §8）
import { describe, it, expect } from '@ohos/hypium'
import { ErrorFlags } from '../main/ets/model/ErrorFlags'
import { CalcEngine } from '../main/ets/calculator/Calculator'
import { Expression } from '../main/ets/calculator/Expression'
import { FunctionPlotter, PlotResult, PlotPoint } from '../main/ets/plot/FunctionPlotter'

export default function plotFunctionTest(): void {
  describe('scaffold', () => {
    it('scaffold_passes', 0, (): void => {
      expect(true).assertTrue()
    })
  })

  // ==================== SR-00：CalcEngine 变量 x 绑定 ====================
  describe('CalcEngineVarX', () => {
    const engine: CalcEngine = new CalcEngine()

    it('varx_sin_at_1', 0, (): void => {
      ErrorFlags.reset()
      const y: number = engine.evaluate('sin(x)', false, 1)
      expect(ErrorFlags.syntax_error).assertFalse()
      expect(Math.abs(y - 0.8414709848078965) < 1e-9).assertTrue()
    })

    it('varx_pow_at_2', 0, (): void => {
      ErrorFlags.reset()
      const y: number = engine.evaluate('x^2', false, 2)
      expect(ErrorFlags.syntax_error).assertFalse()
      expect(Math.abs(y - 4) < 1e-9).assertTrue()
    })

    it('varx_pow_negative_base', 0, (): void => {
      ErrorFlags.reset()
      const y: number = engine.evaluate('x^2', false, -3)
      expect(ErrorFlags.syntax_error).assertFalse()
      expect(Math.abs(y - 9) < 1e-9).assertTrue()
    })

    it('varx_linear_explicit_mult', 0, (): void => {
      ErrorFlags.reset()
      const y: number = engine.evaluate('2*x+1', false, 2)
      expect(ErrorFlags.syntax_error).assertFalse()
      expect(Math.abs(y - 5) < 1e-9).assertTrue()
    })

    it('varx_zero_is_bound', 0, (): void => {
      ErrorFlags.reset()
      const y: number = engine.evaluate('x+1', false, 0)
      expect(ErrorFlags.syntax_error).assertFalse()
      expect(Math.abs(y - 1) < 1e-9).assertTrue()
    })

    it('varx_unbound_syntax_error', 0, (): void => {
      ErrorFlags.reset()
      engine.evaluate('sin(x)', false)
      expect(ErrorFlags.syntax_error).assertTrue()
    })

    it('varx_xp_untouched_by_binding', 0, (): void => {
      ErrorFlags.reset()
      const y: number = engine.evaluate('xp(1)', false, 5)
      expect(ErrorFlags.syntax_error).assertFalse()
      expect(Math.abs(y - Math.E) < 1e-9).assertTrue()
    })

    it('varx_constant_exprs_unchanged', 0, (): void => {
      ErrorFlags.reset()
      const y1: number = engine.evaluate('sin(0)', false)
      expect(ErrorFlags.syntax_error).assertFalse()
      expect(Math.abs(y1 - 0) < 1e-9).assertTrue()
      ErrorFlags.reset()
      const y2: number = engine.evaluate('2+3*4', false)
      expect(ErrorFlags.syntax_error).assertFalse()
      expect(Math.abs(y2 - 14) < 1e-9).assertTrue()
    })
  })

  // ==================== SR-00：Expression 隐式乘法 x 规则 ====================
  describe('ExpressionVarX', () => {
    const exprProc: Expression = new Expression()

    it('exprx_2x', 0, (): void => {
      ErrorFlags.reset()
      expect(exprProc.getCleanExpression('2x', '.', ',')).assertEqual('2*x')
    })

    it('exprx_x2', 0, (): void => {
      ErrorFlags.reset()
      expect(exprProc.getCleanExpression('x2', '.', ',')).assertEqual('x*2')
    })

    it('exprx_x_paren', 0, (): void => {
      ErrorFlags.reset()
      expect(exprProc.getCleanExpression('x(x+1)', '.', ',')).assertEqual('x*(x+1)')
    })

    it('exprx_pi_x', 0, (): void => {
      ErrorFlags.reset()
      expect(exprProc.getCleanExpression('πx', '.', ',')).assertEqual('π*x')
    })

    it('exprx_e_x', 0, (): void => {
      ErrorFlags.reset()
      expect(exprProc.getCleanExpression('ex', '.', ',')).assertEqual('e*x')
    })

    it('exprx_xx', 0, (): void => {
      ErrorFlags.reset()
      expect(exprProc.getCleanExpression('xx', '.', ',')).assertEqual('x*x')
    })

    it('exprx_x_func', 0, (): void => {
      ErrorFlags.reset()
      expect(exprProc.getCleanExpression('xln(2)', '.', ',')).assertEqual('x*ln(2)')
    })

    it('exprx_digit_both_sides', 0, (): void => {
      ErrorFlags.reset()
      expect(exprProc.getCleanExpression('2x2', '.', ',')).assertEqual('2*x*2')
    })

    it('exprx_xp_protected', 0, (): void => {
      ErrorFlags.reset()
      expect(exprProc.getCleanExpression('2xp3', '.', ',')).assertEqual('2*xp3')
    })

    it('exprx_no_x_baseline_unchanged', 0, (): void => {
      ErrorFlags.reset()
      expect(exprProc.getCleanExpression('2(3)', '.', ',')).assertEqual('2*(3)')
      ErrorFlags.reset()
      expect(exprProc.getCleanExpression('2π', '.', ',')).assertEqual('2*π')
    })

    it('exprx_semantic_2x_plus_1', 0, (): void => {
      ErrorFlags.reset()
      const clean: string = exprProc.getCleanExpression('2x+1', '.', ',')
      expect(clean).assertEqual('2*x+1')
      const engine: CalcEngine = new CalcEngine()
      const y: number = engine.evaluate(clean, false, 2)
      expect(ErrorFlags.syntax_error).assertFalse()
      expect(Math.abs(y - 5) < 1e-9).assertTrue()
    })

    it('exprx_semantic_x_paren_x_plus_1', 0, (): void => {
      ErrorFlags.reset()
      const clean: string = exprProc.getCleanExpression('x(x+1)', '.', ',')
      expect(clean).assertEqual('x*(x+1)')
      const engine: CalcEngine = new CalcEngine()
      const y: number = engine.evaluate(clean, false, 2)
      expect(ErrorFlags.syntax_error).assertFalse()
      expect(Math.abs(y - 6) < 1e-9).assertTrue()
    })

    it('exprx_semantic_xp_still_e_pow', 0, (): void => {
      ErrorFlags.reset()
      const clean: string = exprProc.getCleanExpression('2xp3', '.', ',')
      expect(clean).assertEqual('2*xp3')
      const engine: CalcEngine = new CalcEngine()
      const y: number = engine.evaluate(clean, false, 7)
      expect(ErrorFlags.syntax_error).assertFalse()
      expect(Math.abs(y - 2 * Math.pow(Math.E, 3)) < 1e-6).assertTrue()
    })
  })

  // ==================== SR-01：FunctionPlotter 采样与分段 ====================
  describe('FunctionPlotterTest', () => {
    const plotter: FunctionPlotter = new FunctionPlotter()
    const TWO_PI: number = 2 * Math.PI

    it('plot_sin_single_segment', 0, (): void => {
      const r: PlotResult = plotter.plot('sin(x)', -TWO_PI, TWO_PI, 401)
      expect(r.totalValid).assertEqual(401)
      expect(r.segments.length).assertEqual(1)
      // 全部样本 |y| ≤ 1 + ε
      const pts: PlotPoint[] = r.segments[0].points
      expect(pts.length).assertEqual(401)
      for (let i: number = 0; i < pts.length; i++) {
        if (Math.abs(pts[i].y) > 1 + 1e-9) { expect(false).assertTrue() }
      }
      // 峰值/谷值：x_i = -2π + i·(π/100) → i=250: x≈π/2 y≈1；i=50: x≈-3π/2 y≈1；
      // i=150: x≈-π/2 y≈-1；i=350: x≈3π/2 y≈-1
      expect(Math.abs(pts[250].y - 1) < 1e-9).assertTrue()
      expect(Math.abs(pts[50].y - 1) < 1e-9).assertTrue()
      expect(Math.abs(pts[150].y + 1) < 1e-9).assertTrue()
      expect(Math.abs(pts[350].y + 1) < 1e-9).assertTrue()
    })

    it('plot_sin_yrange_padding', 0, (): void => {
      const r: PlotResult = plotter.plot('sin(x)', -TWO_PI, TWO_PI, 401)
      expect(Math.abs(r.yMin - (-1.2)) < 1e-9).assertTrue()
      expect(Math.abs(r.yMax - 1.2) < 1e-9).assertTrue()
    })

    it('plot_reciprocal_two_segments', 0, (): void => {
      const r: PlotResult = plotter.plot('1/x', -TWO_PI, TWO_PI, 401)
      expect(r.totalValid).assertEqual(400)
      expect(r.segments.length).assertEqual(2)
      const neg: PlotPoint[] = r.segments[0].points
      const pos: PlotPoint[] = r.segments[1].points
      // 断点在 x=0 两侧：负段全 x<0，正段全 x>0，互不相连
      expect(neg[neg.length - 1].x < 0).assertTrue()
      expect(pos[0].x > 0).assertTrue()
      // y 值正确性：y·x ≈ 1
      expect(Math.abs(pos[10].y * pos[10].x - 1) < 1e-12).assertTrue()
      expect(Math.abs(neg[10].y * neg[10].x - 1) < 1e-12).assertTrue()
    })

    it('plot_sqrt_domain_only_nonneg', 0, (): void => {
      const r: PlotResult = plotter.plot('sqrt(x)', -TWO_PI, TWO_PI, 401)
      // x=0 采样点受浮点表示影响（±1e-15），可能有效或无效
      expect(r.totalValid >= 200 && r.totalValid <= 201).assertTrue()
      expect(r.segments.length).assertEqual(1)
      const pts: PlotPoint[] = r.segments[0].points
      for (let i: number = 0; i < pts.length; i++) {
        if (pts[i].x < -1e-12) { expect(false).assertTrue() }
      }
      expect(pts[0].x < 1e-6).assertTrue()
    })

    it('plot_tan_breaks_at_asymptotes', 0, (): void => {
      const r: PlotResult = plotter.plot('tan(x)', -TWO_PI, TWO_PI, 401)
      // ±π/2、±3π/2 附近断段（AC：段数>1）
      expect(r.segments.length > 1).assertTrue()
      expect(r.segments.length <= 6).assertTrue()
      expect(r.totalValid >= 390 && r.totalValid <= 400).assertTrue()
    })

    it('plot_parabola_symmetry_vertex', 0, (): void => {
      const r: PlotResult = plotter.plot('x^2', -TWO_PI, TWO_PI, 401)
      expect(r.totalValid).assertEqual(401)
      expect(r.segments.length).assertEqual(1)
      const pts: PlotPoint[] = r.segments[0].points
      // 顶点 (0,0)：中点 i=200
      expect(Math.abs(pts[200].x) < 1e-12).assertTrue()
      expect(Math.abs(pts[200].y) < 1e-9).assertTrue()
      // 对称性 y(x)=y(-x)
      for (let i: number = 0; i <= 200; i++) {
        if (Math.abs(pts[i].y - pts[400 - i].y) > 1e-9) { expect(false).assertTrue() }
      }
      // 单调性：|x| 越大 y 越大
      expect(pts[300].y > pts[250].y && pts[250].y > pts[200].y).assertTrue()
    })

    it('plot_constant_yrange_fallback', 0, (): void => {
      const r: PlotResult = plotter.plot('2', -TWO_PI, TWO_PI, 401)
      expect(r.totalValid).assertEqual(401)
      expect(r.segments.length).assertEqual(1)
      // min==max=2 → ±1 → [1,3] → +10% padding → [0.8, 3.2]
      expect(Math.abs(r.yMin - 0.8) < 1e-9).assertTrue()
      expect(Math.abs(r.yMax - 3.2) < 1e-9).assertTrue()
    })

    it('plot_all_invalid_empty_result', 0, (): void => {
      const r: PlotResult = plotter.plot('qq(x)', -TWO_PI, TWO_PI, 401)
      expect(r.totalValid).assertEqual(0)
      expect(r.segments.length).assertEqual(0)
    })
  })
}
