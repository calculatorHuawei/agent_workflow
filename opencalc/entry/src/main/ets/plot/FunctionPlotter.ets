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
   * 单遍分段：无效点或相对当前可视范围的巨大跳变都会断段。
   * 后者覆盖渐近线落在两个采样点之间、未恰好采到无效点的情况。
   */
  private buildSegments(xs: number[], ys: number[], valid: boolean[], yMin: number, yMax: number): PlotSegment[] {
    const segments: PlotSegment[] = []
    let current: PlotPoint[] = []
    const visibleSpan: number = yMax - yMin
    for (let i: number = 0; i < xs.length; i++) {
      if (valid[i]) {
        const pt: PlotPoint = { x: xs[i], y: ys[i], valid: true }
        if (current.length > 0 && visibleSpan > 0) {
          const previous: PlotPoint = current[current.length - 1]
          const crossesZero: boolean = pt.y * previous.y < 0
          if (crossesZero && Math.abs(pt.y - previous.y) > visibleSpan * 1.5) {
            const completed: PlotSegment = { points: current }
            segments.push(completed)
            current = []
          }
        }
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
   * 使用 2%~98% 的稳健范围，避免渐近线附近样本把主体曲线压扁到坐标轴上。
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
      const trim: number = Math.floor(values.length * 0.02)
      const centralMin: number = values[trim]
      const centralMax: number = values[values.length - 1 - trim]
      const rawSpan: number = mx - mn
      const centralSpan: number = centralMax - centralMin
      if (centralSpan > 0 && rawSpan > centralSpan * 3) {
        mn = centralMin
        mx = centralMax
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
