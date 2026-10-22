// OpenCalc — 坐标系纯逻辑（Issue #40 补救轮 R4，SR-03）
// 职责：X 轴 π 倍数刻度生成 / Y 轴 nice-number 刻度生成 / 边缘安全标签布局 / 三主题网格与标签色
// 无 UI 依赖（SDR-04 惯例同 FunctionPlotter），可被 hypium 本地单测直接构造
// 契约：退化输入（范围无效/非有限）返回空数组，不抛异常（CM-07/CM-08/CM-09）

/** 单个坐标轴刻度（value 为数学值，label 为画布显示文本） */
export interface AxisTick {
  value: number
  label: string
}

/** 边缘安全布局结果：pos 为夹持后的锚点像素，align 为绘制对齐方式 */
export interface TickLabelLayout {
  pos: number
  align: string
}

/** 坐标系文字统一字号（px）。10px 经实测判不可接受（PR #41 审查意见），契约 ≥14 */
export const PLOT_LABEL_FONT_PX: number = 14

/** 标签与画布边缘的最小间距（px），夹持时保留 */
export const PLOT_LABEL_EDGE_MARGIN: number = 4

/**
 * X 轴刻度：π 倍数步长，产出 5~9 条（[-2π,2π] → -2π/-π/0/π/2π）。
 * 步长倍数 s = max(1, ceil(range/(8π)))；标签：0 → '0'，±1π → '±π'，其余 → '±Nπ'。
 * 退化输入返回空数组。
 */
export function xAxisTicks(xMin: number, xMax: number): AxisTick[] {
  const out: AxisTick[] = []
  if (!Number.isFinite(xMin) || !Number.isFinite(xMax) || !(xMin < xMax)) return out
  const stepUnits: number = Math.max(1, Math.ceil((xMax - xMin) / (Math.PI * 8)))
  const step: number = stepUnits * Math.PI
  const eps: number = step * 1e-6
  const firstK: number = Math.ceil(xMin / step - 1e-9)
  for (let k: number = firstK; k * step <= xMax + eps; k++) {
    const v: number = k * step
    let label: string
    if (k === 0) {
      label = '0'
    } else if (Math.abs(k) === 1) {
      label = k > 0 ? 'π' : '-π'
    } else {
      label = (k > 0 ? '' : '-') + Math.abs(k).toString() + 'π'
    }
    const t: AxisTick = { value: v, label: label }
    out.push(t)
  }
  return out
}

/**
 * Y 轴刻度：nice-number 算法，步长 ∈ {1,2,5}×10^k，保证 ≥minCount 条（minCount=5 时通常 5~8 条）。
 * [-1.2,1.2] × minCount 5 → 步长 0.5 → -1/-0.5/0/0.5/1。
 * 退化输入返回空数组。
 */
export function yTicks(yMin: number, yMax: number, minCount: number): AxisTick[] {
  const out: AxisTick[] = []
  if (!Number.isFinite(yMin) || !Number.isFinite(yMax) || !(yMin < yMax) || !(minCount >= 1)) return out
  const span: number = yMax - yMin
  const rawStep: number = span / minCount
  const mag: number = Math.pow(10, Math.floor(Math.log10(rawStep)))
  // 候选步长 {1,2,5,10}×mag，取满足条数 ≥minCount 的最大步长（条数最接近 minCount，
  // 并规避经典 nice-number 在 norm≥7.5 边界处仅产 4 条的缺陷）
  let step: number = mag
  const candidates: number[] = [mag, 2 * mag, 5 * mag, 10 * mag]
  for (let i: number = candidates.length - 1; i >= 0; i--) {
    const cand: number = candidates[i]
    if (Math.floor(span / cand + 1e-9) + 1 >= minCount) {
      step = cand
      break
    }
  }
  const decimals: number = Math.max(0, Math.ceil(-Math.log10(step) - 1e-9))
  const firstK: number = Math.ceil(yMin / step - 1e-9)
  const eps: number = step * 1e-6
  for (let k: number = firstK; k * step <= yMax + eps; k++) {
    const v: number = k * step
    const t: AxisTick = { value: v, label: formatTickLabel(v, decimals) }
    out.push(t)
  }
  return out
}

/** 刻度值 → 显示文本：toFixed 后去尾零与小数点，防 '-0'（如 0.5 步长 → '-1'/'-0.5'/'0'） */
function formatTickLabel(v: number, decimals: number): string {
  let s: string = v.toFixed(decimals)
  if (decimals > 0) {
    let end: number = s.length
    while (end > 0 && s.charAt(end - 1) === '0') end--
    if (end > 0 && s.charAt(end - 1) === '.') end--
    s = s.substring(0, end)
  }
  if (s === '-0' || s === '') return '0'
  return s
}

/**
 * 水平标签边缘安全布局：锚点±半宽超出 [0, w] 时夹持到边距并改为边缘对齐，否则居中。
 * 返回的 pos/align 保证文本完全落在画布内（CM-07）。
 */
export function hLabelLayout(anchorPx: number, canvasW: number, halfTextW: number): TickLabelLayout {
  if (anchorPx - halfTextW < 0) {
    const r: TickLabelLayout = { pos: PLOT_LABEL_EDGE_MARGIN, align: 'left' }
    return r
  }
  if (anchorPx + halfTextW > canvasW) {
    const r: TickLabelLayout = { pos: canvasW - PLOT_LABEL_EDGE_MARGIN, align: 'right' }
    return r
  }
  const r: TickLabelLayout = { pos: anchorPx, align: 'center' }
  return r
}

/**
 * 垂直标签边缘安全布局：与 hLabelLayout 对称，align ∈ 'top'/'middle'/'bottom'。
 * pos 为文本垂直锚点（配合 textBaseline 使用）。
 */
export function vLabelLayout(anchorPy: number, canvasH: number, halfTextH: number): TickLabelLayout {
  if (anchorPy - halfTextH < 0) {
    const r: TickLabelLayout = { pos: PLOT_LABEL_EDGE_MARGIN, align: 'top' }
    return r
  }
  if (anchorPy + halfTextH > canvasH) {
    const r: TickLabelLayout = { pos: canvasH - PLOT_LABEL_EDGE_MARGIN, align: 'bottom' }
    return r
  }
  const r: TickLabelLayout = { pos: anchorPy, align: 'middle' }
  return r
}

/**
 * 网格线颜色：低对比但不与面板背景混淆（CM-09/CM-10）。
 * 浅色 #E0E0E0（面板 #FFFFFF）/ AMOLED #1E1E1E（面板 #0a0a0a）/ 暗色 #474747（面板 #323232）。
 */
export function plotGridColor(themeIdx: number): string {
  if (themeIdx === 1) return '#1E1E1E'   // AMOLED
  if (themeIdx === 2) return '#474747'   // 暗色
  return '#E0E0E0'                       // 默认浅色
}

/**
 * 坐标系文字颜色：与 CalculatorPage.getT2 语义一致（次要文字）。
 * 浅色 #595959 / 深色主题 #BDBDBD。
 */
export function plotLabelColor(themeIdx: number): string {
  if (themeIdx >= 1) return '#BDBDBD'
  return '#595959'
}
