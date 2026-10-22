// OpenCalc — 函数采样器（Issue #40 SR-01）
// 纯逻辑模块：表达式清洗一次 → 等距采样 → 逐点有效性判定 → 分段构建 → y 轴范围估算
// 无 UI 依赖，可被 hypium 本地单测直接构造（SDR-04）
import { ErrorFlags } from '../model/ErrorFlags'
import { Expression } from '../calculator/Expression'
import { CalcEngine } from '../calculator/Calculator'

/** 单个采样点（无效点 y 为 NaN 哨兵，不参与绘制） */
export interface PlotPoint {
  x: number
  y: number
  valid: boolean
}

/** 连续有效采样点构成的折线段（points 全部 valid，x 递增） */
export interface PlotSegment {
  points: PlotPoint[]
}

/** 采样结果 */
export interface PlotResult {
  /** 连续有效段（全无效时为空数组） */
  segments: PlotSegment[]
  /** 渲染 y 范围（有限值：仅统计有效样本，min==max → ±1，含 10% padding） */
  yMin: number
  yMax: number
  /** 有效点计数 */
  totalValid: number
}

/** 默认绘图常量：[-2π, 2π]、401 点（步长 π/100） */
export const PLOT_X_MIN: number = -2 * Math.PI
export const PLOT_X_MAX: number = 2 * Math.PI
export const PLOT_N: number = 401

/**
 * 可绘制视窗内收比例（R5，SR-04）：y 视窗向内收 span×该比例。
 * 取 0.05 = 0.5×10% padding：sin(x) 峰值 ±1.0 距裁剪线 ±1.08 有浮点安全余量，
 * 而渐近线附近的大 |y| 采样点被排除出连线（CM-11，PR #41 user_feedback）。
 */
export const PLOT_VIEW_INSET_RATIO: number = 0.05

export class FunctionPlotter {
  private engine: CalcEngine = new CalcEngine()
  private exprProc: Expression = new Expression()

  /**
   * 在 [xMin, xMax] 等距采样 n 点（含双端点），弧度制逐点求值。
   * 有效性：全部 ErrorFlags 为 false && y 有限 && |y| ≤ 1e6（夹持 tan 类近发散值）；
   * 无效点断段（CM-01）；全程 try/catch 不抛异常（CM-05）。
   * 调用约束：n ≥ 2 且 xMin < xMax，否则返回空结果。
   */
  plot(expr: string, xMin: number, xMax: number, n: number): PlotResult {
    try {
      if (n < 2 || !(xMin < xMax)) return this.emptyResult()
      ErrorFlags.reset()
      const clean: string = this.exprProc.getCleanExpression(expr, '.', ',')
      // 清洗期错误（如括号不匹配）直接短路，避免逐点重复报错
      if (ErrorFlags.syntax_error) return this.emptyResult()

      const xs: number[] = []
      const ys: number[] = []
      const valid: boolean[] = []
      let totalValid: number = 0
      for (let i: number = 0; i < n; i++) {
        const x: number = xMin + i * (xMax - xMin) / (n - 1)
        // 每点求值前 reset，防止前一点错误标志污染（CM-02）
        ErrorFlags.reset()
        let y: number = NaN
        let ok: boolean = false
        try {
          y = this.engine.evaluate(clean, false, x)
          ok = !ErrorFlags.syntax_error && !ErrorFlags.division_by_0 && !ErrorFlags.domain_error
            && !ErrorFlags.is_infinity && !ErrorFlags.require_real_number
            && Number.isFinite(y) && Math.abs(y) <= 1e6
        } catch (_e) { ok = false }
        if (!ok) y = NaN
        else totalValid = totalValid + 1
        xs.push(x)
        ys.push(y)
        valid.push(ok)
      }
      const range: number[] = this.yRange(ys, valid)
      const segments: PlotSegment[] = this.buildSegments(xs, ys, valid, range[0], range[1])
      const result: PlotResult = { segments: segments, yMin: range[0], yMax: range[1], totalValid: totalValid }
      return result
    } catch (_e) {
      return this.emptyResult()
    }
  }

  /**
   * 单遍分段（R5 收紧，SR-04）：仅"可绘制"采样点参与连线。
   * 可绘制 = 有效 ∧ y ∈ [yMin+inset, yMax−inset]（inset = span×PLOT_VIEW_INSET_RATIO）：
   * 渐近线附近的大 |y| 采样点不再把折线推到画布边缘与坐标轴粘连（CM-11），
   * 同时覆盖渐近线落在两个采样点之间、未恰好采到无效点的情况（取代旧跨零跳变断段）。
   * 断口阴影：断口（无效/窗外）后的首个可绘制点若为发散尾部（|y| > span/2），
   * 额外跳过该 1 点（每断口仅 1 点），log(x) 类贴轴尾部抬离坐标轴；
   * 平滑边界（如 sqrt 顶点 y=0）不受影响。
   * 全部不可绘制但有有效点时回退绘制全部有效点（不产生空图）。
   */
  private buildSegments(xs: number[], ys: number[], valid: boolean[], yMin: number, yMax: number): PlotSegment[] {
    const n: number = xs.length
    const span: number = yMax - yMin
    const drawable: boolean[] = []
    let drawableCount: number = 0
    if (span > 0 && Number.isFinite(span)) {
      const inset: number = span * PLOT_VIEW_INSET_RATIO
      const lo: number = yMin + inset
      const hi: number = yMax - inset
      for (let i: number = 0; i < n; i++) {
        const d: boolean = valid[i] && ys[i] >= lo && ys[i] <= hi
        drawable.push(d)
        if (d) drawableCount = drawableCount + 1
      }
      if (drawableCount === 0) {
        for (let i: number = 0; i < n; i++) {
          drawable[i] = valid[i]
          if (valid[i]) drawableCount = drawableCount + 1
        }
      } else {
        const halfSpan: number = span / 2
        for (let i: number = 1; i < n; i++) {
          if (drawable[i] && !drawable[i - 1] && Math.abs(ys[i]) > halfSpan) {
            drawable[i] = false
            drawableCount = drawableCount - 1
          }
        }
      }
    } else {
      for (let i: number = 0; i < n; i++) {
        const d: boolean = valid[i]
        drawable.push(d)
        if (d) drawableCount = drawableCount + 1
      }
    }
    const segments: PlotSegment[] = []
    let current: PlotPoint[] = []
    for (let i: number = 0; i < n; i++) {
      if (drawable[i]) {
        const pt: PlotPoint = { x: xs[i], y: ys[i], valid: true }
        current.push(pt)
      } else if (current.length > 0) {
        const seg: PlotSegment = { points: current }
        segments.push(seg)
        current = []
      }
    }
    if (current.length > 0) {
      const seg: PlotSegment = { points: current }
      segments.push(seg)
    }
    return segments
  }

  /**
   * y 范围：默认使用完整有限样本；当两端少量极值把范围扩大到主体的 3 倍以上时，
   * 使用稳健中心范围，避免渐近线附近样本把主体曲线压扁到坐标轴上。
   * R5：修剪比例按 2%→5%→10% 逐级尝试——tan 类函数在每个渐近线两侧各有一份
   * 对称极值（4 渐近线 × 2 侧），2% 修剪不足以剔除，需逐级升级才能取得主体范围。
   */
  private yRange(ys: number[], valid: boolean[]): number[] {
    const values: number[] = []
    for (let i: number = 0; i < ys.length; i++) {
      if (valid[i] && Number.isFinite(ys[i])) {
        values.push(ys[i])
      }
    }
    if (values.length === 0) return [0, 1]
    values.sort((a: number, b: number): number => a - b)
    let mn: number = values[0]
    let mx: number = values[values.length - 1]
    if (values.length >= 50) {
      const rawSpan: number = mx - mn
      const trims: number[] = [0.02, 0.05, 0.10]
      for (let t: number = 0; t < trims.length; t++) {
        const trim: number = Math.floor(values.length * trims[t])
        if (trim <= 0 || trim * 2 >= values.length) continue
        const centralMin: number = values[trim]
        const centralMax: number = values[values.length - 1 - trim]
        const centralSpan: number = centralMax - centralMin
        if (centralSpan > 0 && rawSpan > centralSpan * 3) {
          mn = centralMin
          mx = centralMax
          break
        }
      }
    }
    if (mn === mx) { mn = mn - 1; mx = mx + 1 }
    const pad: number = (mx - mn) * 0.1
    const range: number[] = [mn - pad, mx + pad]
    return range
  }

  /** 空结果（错误/无有效数据时返回） */
  private emptyResult(): PlotResult {
    const r: PlotResult = { segments: [], yMin: 0, yMax: 1, totalValid: 0 }
    return r
  }
}
