// OpenCalc — 函数绘图本地单元测试（Issue #40）
// 覆盖：SR-00 变量求值 / SR-01 采样分段 / SR-03 可读坐标系逻辑（补救轮 R4，delta-spec §8）
//       / SR-04 渐近线视觉分离（补救轮 R5，delta-spec §8，PR #41 user_feedback）
import { describe, it, expect } from '@ohos/hypium'
import { ErrorFlags } from '../main/ets/model/ErrorFlags'
import { CalcEngine } from '../main/ets/calculator/Calculator'
import { Expression } from '../main/ets/calculator/Expression'
import { FunctionPlotter, PlotResult, PlotPoint, PLOT_VIEW_INSET_RATIO } from '../main/ets/plot/FunctionPlotter'
import {
  AxisTick, TickLabelLayout, PLOT_LABEL_FONT_PX,
  xAxisTicks, yTicks, hLabelLayout, vLabelLayout, plotGridColor, plotLabelColor
} from '../main/ets/plot/PlotAxis'

/** 收集全部绘制点（模块级函数——ArkTS 禁止嵌套函数） */
function collectDrawn(r: PlotResult): PlotPoint[] {
  const out: PlotPoint[] = []
  for (let s: number = 0; s < r.segments.length; s++) {
    const pts: PlotPoint[] = r.segments[s].points
    for (let i: number = 0; i < pts.length; i++) out.push(pts[i])
  }
  return out
}

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

    it('plot_reciprocal_breaks_when_zero_is_between_samples', 0, (): void => {
      // 偶数采样不会命中 x=0；仍不得把渐近线两侧连成一条折线。
      const r: PlotResult = plotter.plot('1/x', -TWO_PI, TWO_PI, 400)
      expect(r.segments.length).assertEqual(2)
      for (let s: number = 0; s < r.segments.length; s++) {
        const pts: PlotPoint[] = r.segments[s].points
        let hasNegative: boolean = false
        let hasPositive: boolean = false
        for (let i: number = 0; i < pts.length; i++) {
          if (pts[i].x < 0) hasNegative = true
          if (pts[i].x > 0) hasPositive = true
        }
        expect(hasNegative && hasPositive).assertFalse()
      }
    })

    it('plot_reciprocal_uses_robust_visible_range', 0, (): void => {
      const r: PlotResult = plotter.plot('1/x', -TWO_PI, TWO_PI, 401)
      // 靠近 x=0 的少数极端点不能把主体曲线压扁到坐标轴上。
      expect(r.yMin > -10).assertTrue()
      expect(r.yMax < 10).assertTrue()
    })

    it('plot_log_keeps_domain_on_positive_side', 0, (): void => {
      const r: PlotResult = plotter.plot('log(x)', -TWO_PI, TWO_PI, 401)
      expect(r.segments.length).assertEqual(1)
      const pts: PlotPoint[] = r.segments[0].points
      for (let i: number = 0; i < pts.length; i++) {
        expect(pts[i].x > 0).assertTrue()
      }
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

  // ==================== SR-03：可读坐标系逻辑（补救轮 R4） ====================
  describe('PlotAxisTest', () => {
    const PI: number = Math.PI
    const TWO_PI: number = 2 * Math.PI

    it('xaxis_default_range_five_pi_ticks', 0, (): void => {
      const ticks: AxisTick[] = xAxisTicks(-TWO_PI, TWO_PI)
      expect(ticks.length).assertEqual(5)
      const vals: number[] = [-TWO_PI, -PI, 0, PI, TWO_PI]
      const labels: string[] = ['-2π', '-π', '0', 'π', '2π']
      for (let i: number = 0; i < 5; i++) {
        expect(Math.abs(ticks[i].value - vals[i]) < 1e-9).assertTrue()
        expect(ticks[i].label).assertEqual(labels[i])
      }
    })

    it('xaxis_generic_range_pi_multiples_ordered', 0, (): void => {
      const ticks: AxisTick[] = xAxisTicks(-PI, PI)
      expect(ticks.length >= 3).assertTrue()
      for (let i: number = 1; i < ticks.length; i++) {
        expect(ticks[i].value > ticks[i - 1].value).assertTrue()
        const k1: number = ticks[i - 1].value / PI
        const k2: number = ticks[i].value / PI
        expect(Math.abs(k1 - Math.round(k1)) < 1e-9).assertTrue()
        expect(Math.abs(k2 - Math.round(k2)) < 1e-9).assertTrue()
      }
    })

    it('yaxis_sin_range_five_ticks_include_half_steps', 0, (): void => {
      const ticks: AxisTick[] = yTicks(-1.2, 1.2, 5)
      expect(ticks.length >= 5).assertTrue()
      const vals: number[] = [-1, -0.5, 0, 0.5, 1]
      const labels: string[] = ['-1', '-0.5', '0', '0.5', '1']
      for (let i: number = 0; i < 5; i++) {
        expect(Math.abs(ticks[i].value - vals[i]) < 1e-9).assertTrue()
        expect(ticks[i].label).assertEqual(labels[i])
      }
    })

    it('yaxis_constant_expr_range_still_five', 0, (): void => {
      const ticks: AxisTick[] = yTicks(0.8, 3.2, 5)
      expect(ticks.length >= 5).assertTrue()
      expect(ticks[0].value >= 0.8).assertTrue()
      expect(ticks[ticks.length - 1].value <= 3.2).assertTrue()
      for (let i: number = 1; i < ticks.length; i++) {
        expect(ticks[i].value > ticks[i - 1].value).assertTrue()
      }
    })

    it('yaxis_degenerate_range_empty', 0, (): void => {
      expect(yTicks(1.2, -1.2, 5).length).assertEqual(0)
      expect(yTicks(0, 0, 5).length).assertEqual(0)
      expect(yTicks(NaN, 1.2, 5).length).assertEqual(0)
      expect(yTicks(-1.2, 1.2, 0).length).assertEqual(0)
      expect(xAxisTicks(TWO_PI, -TWO_PI).length).assertEqual(0)
      expect(xAxisTicks(NaN, TWO_PI).length).assertEqual(0)
    })

    it('hlabel_left_edge_clamped', 0, (): void => {
      const l: TickLabelLayout = hLabelLayout(0, 500, 13)
      expect(l.align).assertEqual('left')
      expect(l.pos >= 4).assertTrue()
    })

    it('hlabel_right_edge_clamped', 0, (): void => {
      const l: TickLabelLayout = hLabelLayout(500, 500, 13)
      expect(l.align).assertEqual('right')
      expect(l.pos <= 496).assertTrue()
    })

    it('hlabel_middle_centered', 0, (): void => {
      const l: TickLabelLayout = hLabelLayout(250, 500, 13)
      expect(l.align).assertEqual('center')
      expect(l.pos).assertEqual(250)
    })

    it('vlabel_edges_clamped', 0, (): void => {
      const top: TickLabelLayout = vLabelLayout(0, 400, 7)
      expect(top.align).assertEqual('top')
      expect(top.pos >= 4).assertTrue()
      const bottom: TickLabelLayout = vLabelLayout(400, 400, 7)
      expect(bottom.align).assertEqual('bottom')
      expect(bottom.pos <= 396).assertTrue()
      const mid: TickLabelLayout = vLabelLayout(200, 400, 7)
      expect(mid.align).assertEqual('middle')
      expect(mid.pos).assertEqual(200)
    })

    it('theme_colors_and_font_contract', 0, (): void => {
      // 字号契约：≥14px（10px 判不可接受，PR #41 审查意见）
      expect(PLOT_LABEL_FONT_PX >= 14).assertTrue()
      // 浅色精确值
      expect(plotGridColor(0)).assertEqual('#E0E0E0')
      expect(plotLabelColor(0)).assertEqual('#595959')
      // 三主题下 网格/标签/面板背景 两两不同
      const panelBgs: string[] = ['#FFFFFF', '#0a0a0a', '#323232']
      for (let t: number = 0; t < 3; t++) {
        const g: string = plotGridColor(t)
        const c: string = plotLabelColor(t)
        expect(g !== c).assertTrue()
        expect(g !== panelBgs[t]).assertTrue()
        expect(c !== panelBgs[t]).assertTrue()
      }
    })
  })

  // ==================== SR-04：渐近线视觉分离（补救轮 R5） ====================
  describe('AsymptoteSeparationTest', () => {
    const plotter: FunctionPlotter = new FunctionPlotter()
    const PI: number = Math.PI
    const TWO_PI: number = 2 * Math.PI
    const STEP: number = (2 * TWO_PI) / 400   // 401 点采样步长
    const EPS: number = 1e-9

    /** 收集全部绘制点 */
    it('inset_ratio_contract', 0, (): void => {
      // 视窗内收比例 = 0.5×padding（span/20）：sin 峰值 ±1.0 距裁剪线 ±1.08 有浮点余量
      expect(PLOT_VIEW_INSET_RATIO > 0 && PLOT_VIEW_INSET_RATIO <= 0.1).assertTrue()
    })

    it('asym_one_over_x_separated_from_y_axis', 0, (): void => {
      const r: PlotResult = plotter.plot('1/x', -TWO_PI, TWO_PI, 401)
      expect(r.totalValid).assertEqual(400)
      expect(r.segments.length >= 2).assertTrue()
      const inset: number = (r.yMax - r.yMin) * PLOT_VIEW_INSET_RATIO
      const lo: number = r.yMin + inset - EPS
      const hi: number = r.yMax - inset + EPS
      const drawn: PlotPoint[] = collectDrawn(r)
      expect(drawn.length > 0).assertTrue()
      let minAbsX: number = Infinity
      for (let i: number = 0; i < drawn.length; i++) {
        // AC1：绘制点全部在内收视窗中（不再冲出画布边缘）
        if (drawn[i].y < lo || drawn[i].y > hi) { expect(false).assertTrue() }
        if (Math.abs(drawn[i].x) < minAbsX) minAbsX = Math.abs(drawn[i].x)
      }
      // AC1：曲线与 Y 轴留出可见走廊（≥2 采样步长）
      expect(minAbsX >= 2 * STEP - EPS).assertTrue()
    })

    it('asym_one_over_x_no_cross_sign_segment', 0, (): void => {
      const r: PlotResult = plotter.plot('1/x', -TWO_PI, TWO_PI, 401)
      for (let s: number = 0; s < r.segments.length; s++) {
        const pts: PlotPoint[] = r.segments[s].points
        let hasNegative: boolean = false
        let hasPositive: boolean = false
        for (let i: number = 0; i < pts.length; i++) {
          if (pts[i].x < 0) hasNegative = true
          if (pts[i].x > 0) hasPositive = true
        }
        expect(hasNegative && hasPositive).assertFalse()
      }
    })

    it('asym_logx_tail_lifted_from_axis_and_bottom', 0, (): void => {
      const r: PlotResult = plotter.plot('log(x)', -TWO_PI, TWO_PI, 401)
      expect(r.segments.length).assertEqual(1)
      const inset: number = (r.yMax - r.yMin) * PLOT_VIEW_INSET_RATIO
      const drawn: PlotPoint[] = collectDrawn(r)
      expect(drawn.length > 0).assertTrue()
      let minX: number = Infinity
      let minY: number = Infinity
      for (let i: number = 0; i < drawn.length; i++) {
        // AC2：仅绘制 x>0 定义域
        if (drawn[i].x <= 0) { expect(false).assertTrue() }
        if (drawn[i].x < minX) minX = drawn[i].x
        if (drawn[i].y < minY) minY = drawn[i].y
        if (drawn[i].y < r.yMin + inset - EPS) { expect(false).assertTrue() }
      }
      // AC2：发散尾部抬离 Y 轴（≥2 采样步长）且不贴 y 下边
      expect(minX >= 2 * STEP - EPS).assertTrue()
      expect(minY >= r.yMin + inset - EPS).assertTrue()
    })

    it('asym_tanx_segments_within_pi_half_intervals', 0, (): void => {
      const r: PlotResult = plotter.plot('tan(x)', -TWO_PI, TWO_PI, 401)
      // 渐近线 ±π/2、±3π/2 → 5 个连续分支
      expect(r.segments.length).assertEqual(5)
      const inset: number = (r.yMax - r.yMin) * PLOT_VIEW_INSET_RATIO
      const halfPi: number = PI / 2
      for (let s: number = 0; s < r.segments.length; s++) {
        const pts: PlotPoint[] = r.segments[s].points
        expect(pts.length > 0).assertTrue()
        // AC3：每段所有点位于同一渐近线区间（区间以奇数倍 π/2 为界：floor((t+1)/2)，
        // floor(x/halfPi) 会在非渐近线的 t=0 处误分段）
        const k0: number = Math.floor((pts[0].x / halfPi + 1) / 2)
        let minDist: number = Infinity
        for (let i: number = 0; i < pts.length; i++) {
          const k: number = Math.floor((pts[i].x / halfPi + 1) / 2)
          if (k !== k0) { expect(false).assertTrue() }
          // 最近渐近线 = 奇数倍 π/2（Math.round 取最近 π/2 倍数会把 x≈0 误判为距渐近线 0）
          const t: number = pts[i].x / halfPi
          const nearestOdd: number = Math.round((t - 1) / 2) * 2 + 1
          const d: number = Math.abs(t - nearestOdd) * halfPi
          if (d < minDist) minDist = d
          if (pts[i].y < r.yMin + inset - EPS || pts[i].y > r.yMax - inset + EPS) { expect(false).assertTrue() }
        }
        // AC3：绘制点距最近渐近线 ≥2 采样步长
        expect(minDist >= 2 * STEP - EPS).assertTrue()
      }
    })

    it('asym_sinx_zero_regression_full_curve', 0, (): void => {
      // AC4：视窗裁剪/断口阴影不得误伤连续函数（sin 峰值保留）
      const r: PlotResult = plotter.plot('sin(x)', -TWO_PI, TWO_PI, 401)
      expect(r.totalValid).assertEqual(401)
      expect(r.segments.length).assertEqual(1)
      expect(r.segments[0].points.length).assertEqual(401)
      let maxY: number = -Infinity
      let minY: number = Infinity
      const pts: PlotPoint[] = r.segments[0].points
      for (let i: number = 0; i < pts.length; i++) {
        if (pts[i].y > maxY) maxY = pts[i].y
        if (pts[i].y < minY) minY = pts[i].y
      }
      expect(maxY >= 0.999).assertTrue()
      expect(minY <= -0.999).assertTrue()
    })

    it('asym_x2_zero_regression_vertex_kept', 0, (): void => {
      // AC4：x² 单段全点绘制、顶点 (0,0) 保留
      const r: PlotResult = plotter.plot('x^2', -TWO_PI, TWO_PI, 401)
      expect(r.totalValid).assertEqual(401)
      expect(r.segments.length).assertEqual(1)
      expect(r.segments[0].points.length).assertEqual(401)
      const pts: PlotPoint[] = r.segments[0].points
      expect(Math.abs(pts[200].x) < 1e-12).assertTrue()
      expect(Math.abs(pts[200].y) < 1e-9).assertTrue()
    })

    it('asym_sqrtx_vertex_still_drawn_at_domain_edge', 0, (): void => {
      // 已裁决（proposal §12.2）：非发散的平滑边界（sqrt 顶点 y=0）不阴影化
      const r: PlotResult = plotter.plot('sqrt(x)', -TWO_PI, TWO_PI, 401)
      expect(r.segments.length).assertEqual(1)
      const pts: PlotPoint[] = r.segments[0].points
      expect(pts[0].x < 1e-6).assertTrue()
      for (let i: number = 0; i < pts.length; i++) {
        if (pts[i].x < -1e-12) { expect(false).assertTrue() }
      }
    })
  })
}
