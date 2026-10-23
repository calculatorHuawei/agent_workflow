// OpenCalc — 主计算器页面（横竖屏自适应 + Android 配色）
// 移植自：MainActivity.kt（1447行）
import { promptAction } from '@kit.ArkUI'
import { pasteboard } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { Expression } from '../calculator/Expression'
import { CalcEngine } from '../calculator/Calculator'
import { NumberFormatter } from '../calculator/NumberFormatter'
import { NumberingSystem, HistoryItem } from '../model/Models'
import { ErrorFlags } from '../model/ErrorFlags'
import { PreferencesStore } from '../preferences/PreferencesStore'
import { FunctionPlotter, PlotResult, PlotSegment, PLOT_X_MIN, PLOT_X_MAX, PLOT_N } from '../plot/FunctionPlotter'
import {
  AxisTick, TickLabelLayout, PLOT_LABEL_FONT_PX,
  xAxisTicks, yTicks, hLabelLayout, vLabelLayout, plotGridColor, plotLabelColor
} from '../plot/PlotAxis'
import { buildQrPayload, isShareable, QrPayloadResult } from '../qrcode/QrPayload'
import { encodeQr, QrEncodeResult, QrMatrix } from '../qrcode/QrEncoder'
import { qrModulePixels } from '../qrcode/QrLayout'

@Entry
@Component
export struct CalculatorPage {
  // ==================== 显示状态 ====================
  @State expression: string = ''
  @State result: string = ''
  @State errorMsg: string = ''
  @State scientific: boolean = false
  @State history: HistoryItem[] = []
  @State showHistory: boolean = false
  @State showSettings: boolean = false
  @State showAbout: boolean = false
  @State isLandscape: boolean = false
  @State showQrShare: boolean = false
  @State qrPayloadOk: boolean = false
  @State qrErrorText: string = ''

  // ==================== 绘图状态（Issue #40） ====================
  @State showPlot: boolean = false
  @State plotInput: string = ''
  @State plotError: string = ''
  @State plotSegments: PlotSegment[] = []
  @State plotYMin: number = -1.2
  @State plotYMax: number = 1.2
  @State canvasW: number = 0
  @State canvasH: number = 0

  // ==================== 偏好设置状态 ====================
  @State vibrateOn: boolean = true
  @State preventSleep: boolean = false
  @State radianMode: boolean = false
  @State themeIdx: number = 0

  // ==================== 内部状态 ====================
  private nextId: number = 0
  private engine: CalcEngine = new CalcEngine()
  private expr: Expression = new Expression()
  private prefs: PreferencesStore | null = null
  private plotter: FunctionPlotter = new FunctionPlotter()
  private canvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private qrCanvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(false))
  private qrMatrix: QrMatrix | null = null
  private qrCanvasW: number = 0
  private qrCanvasH: number = 0

  aboutToAppear(): void {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
    this.prefs = new PreferencesStore(ctx)
    this.prefs.init().then((): void => { this.loadPrefs(); this.loadHistory() })
  }

  async loadPrefs(): Promise<void> {
    if (!this.prefs) return
    this.vibrateOn = await this.prefs.getVibrationEnabled()
    this.preventSleep = await this.prefs.getPreventSleep()
    this.radianMode = await this.prefs.getRadiansDefault()
    this.themeIdx = await this.prefs.getTheme()
    this.scientific = (await this.prefs.getScientificModeDefault()) === 1
  }

  async loadHistory(): Promise<void> {
    if (!this.prefs) return
    this.history = await this.prefs.getHistory()
    if (this.history.length > 0) this.nextId = this.history[0].id + 1
  }

  async savePref(key: string, value: boolean | number): Promise<void> {
    if (!this.prefs) return
    if (key === 'vibrateOn') await this.prefs.setVibrationEnabled(value as boolean)
    else if (key === 'preventSleep') await this.prefs.setPreventSleep(value as boolean)
    else if (key === 'radianMode') await this.prefs.setRadiansDefault(value as boolean)
    else if (key === 'themeIdx') await this.prefs.setTheme(value as number)
    else if (key === 'scientific') await this.prefs.setScientificModeDefault(value as number)
  }

  // ==================== 按钮事件 ====================
  onDigit(d: string): void { this.expression = this.expression + d; this.errorMsg = '' }
  onOp(op: string): void { this.expression = this.expression + op; this.errorMsg = '' }
  onFunc(f: string): void { this.expression = this.expression + f + '('; this.errorMsg = '' }
  onConst(c: string): void { this.expression = this.expression + c; this.errorMsg = '' }
  onBS(): void { if (this.expression.length > 0) this.expression = this.expression.substring(0, this.expression.length - 1) }
  onAC(): void { this.expression = ''; this.result = ''; this.errorMsg = ''; ErrorFlags.reset() }

  onEquals(): void {
    if (this.expression.length === 0) return
    ErrorFlags.reset()
    try {
      const clean: string = this.expr.getCleanExpression(this.expression, '.', ',')
      const raw: number = this.engine.evaluate(clean, !this.radianMode)
      if (ErrorFlags.division_by_0) { this.errorMsg = '除数不能为零'; this.result = '' }
      else if (ErrorFlags.domain_error) { this.errorMsg = '定义域错误'; this.result = '' }
      else if (ErrorFlags.syntax_error) { this.errorMsg = '表达式错误'; this.result = '' }
      else if (ErrorFlags.is_infinity) { this.errorMsg = '结果无穷大'; this.result = '' }
      else if (ErrorFlags.require_real_number) { this.errorMsg = '需要实数'; this.result = '' }
      else {
        const fmt: string = NumberFormatter.format(raw.toString(), '.', ',', NumberingSystem.INTERNATIONAL)
        this.result = fmt; this.errorMsg = ''
        const item: HistoryItem = { id: this.nextId, expression: this.expression, result: fmt, timestamp: Date.now() }
        this.nextId = this.nextId + 1
        const nh: HistoryItem[] = [item]
        for (let i: number = 0; i < this.history.length; i++) nh.push(this.history[i])
        this.history = nh
        if (this.prefs) this.prefs.setHistory(this.history)
      }
    } catch (_e) { this.errorMsg = '计算错误' }
  }

  onCopy(): void {
    if (this.result.length === 0) return
    pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.result))
    promptAction.showToast({ message: '已复制' })
  }

  private resetQrShareState(): void {
    this.qrMatrix = null
    this.qrPayloadOk = false
    this.qrErrorText = ''
  }

  /** Open-time QR generation prevents stale payloads while preserving calculator state. */
  onOpenQrShare(): void {
    if (!isShareable(this.expression, this.result, this.errorMsg)) {
      promptAction.showToast({ message: '请先完成一次有效计算' })
      return
    }
    this.resetQrShareState()
    try {
      const payload: QrPayloadResult = buildQrPayload(this.expression, this.result)
      if (!payload.ok) {
        this.qrErrorText = payload.reason
      } else {
        const encoded: QrEncodeResult = encodeQr(payload.payload)
        if (encoded.ok && encoded.matrix !== null) {
          this.qrMatrix = encoded.matrix
          this.qrPayloadOk = true
        } else {
          this.qrErrorText = encoded.reason.length > 0 ? encoded.reason : '二维码生成失败'
        }
      }
    } catch (_e) {
      this.qrErrorText = '二维码生成失败'
    }
    this.showQrShare = true
  }

  private failQrDrawing(message: string): void {
    this.resetQrShareState()
    this.qrErrorText = message
  }

  /** Draw constant black-on-white modules with a four-module quiet zone. */
  private drawQr(): void {
    const matrix: QrMatrix | null = this.qrMatrix
    if (matrix === null || this.qrCanvasW <= 0 || this.qrCanvasH <= 0) return
    const quiet: number = 4
    const modulePx: number = qrModulePixels(this.qrCanvasW, this.qrCanvasH,
      matrix.size, quiet)
    if (modulePx < 4) {
      this.failQrDrawing('二维码显示空间不足')
      return
    }
    const side: number = (matrix.size + quiet * 2) * modulePx
    const offsetX: number = Math.floor((this.qrCanvasW - side) / 2)
    const offsetY: number = Math.floor((this.qrCanvasH - side) / 2)
    try {
      this.qrCanvasCtx.clearRect(0, 0, this.qrCanvasW, this.qrCanvasH)
      this.qrCanvasCtx.fillStyle = '#FFFFFF'
      this.qrCanvasCtx.fillRect(0, 0, this.qrCanvasW, this.qrCanvasH)
      this.qrCanvasCtx.fillStyle = '#000000'
      for (let r: number = 0; r < matrix.size; r++) {
        for (let c: number = 0; c < matrix.size; c++) {
          if (matrix.modules[r][c]) {
            this.qrCanvasCtx.fillRect(
              offsetX + (c + quiet) * modulePx,
              offsetY + (r + quiet) * modulePx,
              modulePx,
              modulePx
            )
          }
        }
      }
    } catch (_e) {
      this.failQrDrawing('二维码生成失败')
    }
  }

  onHistoryTap(item: HistoryItem): void { this.expression = item.expression; this.showHistory = false }
  onHistoryDelete(item: HistoryItem): void {
    const keep: HistoryItem[] = []
    for (let i: number = 0; i < this.history.length; i++) { if (this.history[i].id !== item.id) keep.push(this.history[i]) }
    this.history = keep
    if (this.prefs) this.prefs.setHistory(this.history)
  }

  // ==================== 绘图（Issue #40 SR-02） ====================

  /** 进入绘图面板：预填主界面表达式，清空错误提示 */
  onOpenPlot(): void {
    this.showPlot = true
    this.plotInput = this.expression
    this.plotError = ''
  }

  /** 触发绘制：空值拦截 → 采样分段 → 更新状态（全程 try/catch，CM-05） */
  onPlot(): void {
    const expr: string = this.plotInput.trim()
    if (expr.length === 0) { this.plotError = '请输入表达式'; return }
    try {
      ErrorFlags.reset()
      const res: PlotResult = this.plotter.plot(expr, PLOT_X_MIN, PLOT_X_MAX, PLOT_N)
      if (res.totalValid === 0 || res.segments.length === 0) {
        this.plotError = '无可绘制的有效数据点'
        this.plotSegments = []
        return
      }
      this.plotError = ''
      this.plotSegments = res.segments
      this.plotYMin = res.yMin
      this.plotYMax = res.yMax
      this.drawPlot()
    } catch (_e) { this.plotError = '计算错误' }
  }

  /** 数学坐标 → Canvas 像素坐标（x∈[PLOT_X_MIN,PLOT_X_MAX]→[0,w]，y∈[plotYMin,plotYMax]→[h,0]） */
  private mathToPx(x: number, y: number, w: number, h: number): number[] {
    const px: number = (x - PLOT_X_MIN) / (PLOT_X_MAX - PLOT_X_MIN) * w
    const py: number = h - (y - this.plotYMin) / (this.plotYMax - this.plotYMin) * h
    const xy: number[] = [px, py]
    return xy
  }

  /** 曲线色：浅色主题用强调蓝，暗色沿用 getOp()（与 BtnConst 既有取色惯例一致） */
  private getCurveColor(): string {
    return this.getOp() === '#B4D2E4' ? '#4684E3' : this.getOp()
  }

  /** 清屏并重绘坐标系与曲线；坐标轴最后覆盖曲线，保证渐近线不会遮住 Y 轴。 */
  private drawPlot(): void {
    if (this.canvasW <= 0 || this.canvasH <= 0) return
    const w: number = this.canvasW
    const h: number = this.canvasH
    const xTks: AxisTick[] = xAxisTicks(PLOT_X_MIN, PLOT_X_MAX)
    const yTks: AxisTick[] = yTicks(this.plotYMin, this.plotYMax, 5)
    this.canvasCtx.clearRect(0, 0, w, h)
    this.drawGrid(xTks, yTks, w, h)
    this.drawCurve(w, h)
    this.drawAxes(w, h)
    this.drawTickLabels(xTks, yTks, w, h)
    this.drawAxisNames(w, h)
    this.drawRangeText()
  }

  /** 网格线：每个 X/Y 刻度一条 1px 低对比线，先于轴与曲线绘制（CM-09/CM-10） */
  private drawGrid(xTks: AxisTick[], yTks: AxisTick[], w: number, h: number): void {
    const ctx: CanvasRenderingContext2D = this.canvasCtx
    ctx.strokeStyle = plotGridColor(this.themeIdx)
    ctx.lineWidth = 1
    ctx.beginPath()
    for (let i: number = 0; i < xTks.length; i++) {
      const px: number[] = this.mathToPx(xTks[i].value, 0, w, h)
      const cx: number = Math.min(Math.max(px[0], 0), w)
      ctx.moveTo(cx, 0)
      ctx.lineTo(cx, h)
    }
    for (let i: number = 0; i < yTks.length; i++) {
      const py: number[] = this.mathToPx(0, yTks[i].value, w, h)
      if (py[1] < 0 || py[1] > h) continue
      ctx.moveTo(0, py[1])
      ctx.lineTo(w, py[1])
    }
    ctx.stroke()
  }

  /**
   * 坐标轴线：x 轴（y=0）与 y 轴（x=0），夹持到画布内。
   * R5（CM-13）：主文字色 getT1 + 2px（曲线同宽），绘制于曲线之后——
   * 轴/曲线/网格三方在三主题下两两可辨（原 plotLabelColor 1px 过弱）。
   */
  private drawAxes(w: number, h: number): void {
    const ctx: CanvasRenderingContext2D = this.canvasCtx
    const range: number = this.plotYMax - this.plotYMin
    if (range <= 0) return
    const xy0: number[] = this.mathToPx(0, 0, w, h)
    const axisY: number = Math.min(Math.max(xy0[1], 0), h)
    const axisX: number = Math.min(Math.max(xy0[0], 0), w)
    ctx.strokeStyle = this.getT1()
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.moveTo(0, axisY)
    ctx.lineTo(w, axisY)
    ctx.moveTo(axisX, 0)
    ctx.lineTo(axisX, h)
    ctx.stroke()
  }

  /** 刻度标签：14px 主题色文字；X 标签经 hLabelLayout 水平夹持、vLabelLayout 垂直夹持（CM-07），Y 标签画在 y 轴近侧 */
  private drawTickLabels(xTks: AxisTick[], yTks: AxisTick[], w: number, h: number): void {
    const ctx: CanvasRenderingContext2D = this.canvasCtx
    const range: number = this.plotYMax - this.plotYMin
    if (range <= 0) return
    const xy0: number[] = this.mathToPx(0, 0, w, h)
    const axisY: number = Math.min(Math.max(xy0[1], 0), h)
    const axisX: number = Math.min(Math.max(xy0[0], 0), w)
    ctx.font = PLOT_LABEL_FONT_PX + 'px sans-serif'
    ctx.fillStyle = plotLabelColor(this.themeIdx)
    // X 刻度标签：锚在轴下方（贴近底边时由布局函数夹持回画布内）
    for (let i: number = 0; i < xTks.length; i++) {
      const tx: number[] = this.mathToPx(xTks[i].value, 0, w, h)
      if (tx[0] < 0 || tx[0] > w) continue
      const halfW: number = xTks[i].label.length * PLOT_LABEL_FONT_PX * 0.6 / 2
      const hl: TickLabelLayout = hLabelLayout(tx[0], w, halfW)
      const vl: TickLabelLayout = vLabelLayout(axisY + 20, h, 5)
      this.applyHAlign(hl.align)
      this.applyVBaseline(vl.align)
      ctx.fillText(xTks[i].label, hl.pos, vl.pos)
    }
    // Y 刻度标签：默认画在 y 轴左侧（右对齐），轴线贴近左缘时改画右侧
    for (let i: number = 0; i < yTks.length; i++) {
      const ty: number[] = this.mathToPx(0, yTks[i].value, w, h)
      if (ty[1] < 0 || ty[1] > h) continue
      const vl: TickLabelLayout = vLabelLayout(ty[1], h, 8)
      this.applyVBaseline(vl.align)
      if (axisX >= 46) {
        ctx.textAlign = 'right'
        ctx.fillText(yTks[i].label, axisX - 6, vl.pos)
      } else {
        ctx.textAlign = 'left'
        ctx.fillText(yTks[i].label, axisX + 6, vl.pos)
      }
    }
  }

  /** 轴名标签：'x' 在 x 轴右端上方，'y' 在 y 轴顶端右侧（均经边缘安全布局，CM-07） */
  private drawAxisNames(w: number, h: number): void {
    const ctx: CanvasRenderingContext2D = this.canvasCtx
    const range: number = this.plotYMax - this.plotYMin
    if (range <= 0) return
    const xy0: number[] = this.mathToPx(0, 0, w, h)
    const axisY: number = Math.min(Math.max(xy0[1], 0), h)
    const axisX: number = Math.min(Math.max(xy0[0], 0), w)
    ctx.font = PLOT_LABEL_FONT_PX + 'px sans-serif'
    ctx.fillStyle = plotLabelColor(this.themeIdx)
    const xl: TickLabelLayout = hLabelLayout(w - 2, w, 7)
    const xv: TickLabelLayout = vLabelLayout(axisY - 12, h, 8)
    this.applyHAlign(xl.align)
    this.applyVBaseline(xv.align)
    ctx.fillText('x', xl.pos, xv.pos)
    const yv: TickLabelLayout = vLabelLayout(4, h, 8)
    this.applyHAlign('left')
    this.applyVBaseline(yv.align)
    ctx.fillText('y', axisX + 8, yv.pos)
  }

  /** 范围文本：画布左上角显示当前 X/Y 范围（主文字色，三主题最可读） */
  private drawRangeText(): void {
    const ctx: CanvasRenderingContext2D = this.canvasCtx
    ctx.font = PLOT_LABEL_FONT_PX + 'px sans-serif'
    ctx.fillStyle = this.getT1()
    ctx.textAlign = 'left'
    ctx.textBaseline = 'top'
    const text: string = 'x∈[' + this.formatPi(PLOT_X_MIN) + ', ' + this.formatPi(PLOT_X_MAX) + ']'
      + '  y∈[' + this.plotYMin.toFixed(1) + ', ' + this.plotYMax.toFixed(1) + ']'
    ctx.fillText(text, 8, 6)
  }

  /** π 倍数格式化（范围文本用）：-2π/-π/0/π/2π */
  private formatPi(v: number): string {
    const k: number = Math.round(v / Math.PI)
    if (k === 0) return '0'
    if (Math.abs(k) === 1) return k > 0 ? 'π' : '-π'
    return k.toString() + 'π'
  }

  /** 布局水平对齐 → 画布 textAlign（字面量分支赋值，规避 CanvasTextAlign 类型收窄） */
  private applyHAlign(a: string): void {
    const ctx: CanvasRenderingContext2D = this.canvasCtx
    if (a === 'left') { ctx.textAlign = 'left' }
    else if (a === 'right') { ctx.textAlign = 'right' }
    else { ctx.textAlign = 'center' }
  }

  /** 布局垂直对齐 → 画布 textBaseline（同上） */
  private applyVBaseline(a: string): void {
    const ctx: CanvasRenderingContext2D = this.canvasCtx
    if (a === 'top') { ctx.textBaseline = 'top' }
    else if (a === 'bottom') { ctx.textBaseline = 'bottom' }
    else { ctx.textBaseline = 'middle' }
  }

  /**
   * 分段曲线：仅绘制 PlotSegment 可绘制点（R5 视窗裁剪+断口阴影后各点均落在画布内，
   * CM-01/SDR-02/CM-11）；像素坐标再经 [−2, w+2]×[−2, h+2] 超扫夹持（纵深防御，
   * 防映射漂移导致折线重新冲出画布与轴线粘连）。
   */
  private drawCurve(w: number, h: number): void {
    const ctx: CanvasRenderingContext2D = this.canvasCtx
    ctx.strokeStyle = this.getCurveColor()
    ctx.lineWidth = 2
    for (let s: number = 0; s < this.plotSegments.length; s++) {
      const pts: PlotSegment = this.plotSegments[s]
      if (pts.points.length === 0) continue
      const p0: number[] = this.mathToPx(pts.points[0].x, pts.points[0].y, w, h)
      ctx.beginPath()
      ctx.moveTo(this.clampPx(p0[0], w), this.clampPx(p0[1], h))
      for (let i: number = 1; i < pts.points.length; i++) {
        const p: number[] = this.mathToPx(pts.points[i].x, pts.points[i].y, w, h)
        ctx.lineTo(this.clampPx(p[0], w), this.clampPx(p[1], h))
      }
      ctx.stroke()
    }
  }

  /** 像素坐标夹持到 [−2, max+2] 超扫矩形（drawCurve 纵深防御） */
  private clampPx(v: number, max: number): number {
    if (v < -2) return -2
    if (v > max + 2) return max + 2
    return v
  }

  // ==================== 主题颜色（对齐 Android 原版） ====================
  // themeIdx: 0=默认浅色  1=AMOLED纯黑  2=暗色
  // 默认：Android values/colors.xml 浅色主题
  // 暗色：Android values-night/colors.xml 暗色主题

  /** 背景色（默认白 #FFFFFF） */
  getBg(): string {
    if (this.themeIdx === 1) return '#000000'   // AMOLED
    if (this.themeIdx === 2) return '#121212'   // 暗色
    return '#FFFFFF'                              // 默认浅色
  }

  /** 按钮背景色 */
  getBtnBg(): string {
    if (this.themeIdx === 1) return '#1a1a1a'   // AMOLED: 微亮于纯黑背景
    if (this.themeIdx === 2) return '#333333'
    return '#EFEFEF'
  }

  /** 面板背景色 */
  getPanelBg(): string {
    if (this.themeIdx === 1) return '#0a0a0a'   // AMOLED: 稍亮于纯黑
    if (this.themeIdx === 2) return '#323232'
    return '#FFFFFF'
  }

  /** 功能/常量按钮背景（比普通按钮稍暗以区分层级） */
  getFuncBg(): string {
    if (this.themeIdx === 1) return '#111111'
    if (this.themeIdx === 2) return '#333333'
    return '#E8E8E8'
  }

  /** 运算符按钮色（默认浅蓝 #B4D2E4） */
  getOp(): string {
    if (this.themeIdx === 2) return '#0070BC'
    return '#B4D2E4'
  }

  /** 等号按钮色（默认浅粉 #DCB5C5） */
  getEq(): string {
    if (this.themeIdx === 2) return '#B3004D'
    return '#DCB5C5'
  }

  /** 清除按钮色（默认浅绿 #B7DABD） */
  getClr(): string {
    if (this.themeIdx === 2) return '#00BA20'
    return '#B7DABD'
  }

  /** 错误文字色 */
  getErr(): string { return '#F44B3F' }

  /** 主文字色（默认黑 #000000） */
  getT1(): string {
    if (this.themeIdx >= 1) return '#EFEFEF'
    return '#000000'
  }

  /** 次要文字色（默认深灰 #595959） */
  getT2(): string {
    if (this.themeIdx >= 1) return '#BDBDBD'
    return '#595959'
  }

  /** 运算符文字色（白字在有色按钮上） */
  getBtnText(): string {
    if (this.themeIdx >= 1) return '#EFEFEF'
    return '#000000'
  }

  // ==================== 主布局 ====================
  build() {
    Stack() {
      if (this.isLandscape) {
        // 横屏：左边按钮 + 可选右侧历史（有折叠按钮）
        Row() {
          Column() {
            this.DisplayPanel()
            this.ButtonGrid()
          }
          .layoutWeight(this.showHistory ? 3 : 1).height('100%')
          if (this.showHistory) this.HistoryPanel()
        }
        .width('100%').height('100%').backgroundColor(this.getBg())
      } else {
        // 竖屏：原有布局
        Column() {
          this.DisplayPanel()
          this.ToggleRow()
          this.ButtonGrid()
          if (this.showHistory) this.HistoryPanel()
        }
        .width('100%').height('100%').backgroundColor(this.getBg())
      }
      if (this.showSettings) this.SettingsPanel()
      if (this.showAbout) this.AboutPanel()
      if (this.showPlot) this.PlotPanel()
      if (this.showQrShare) this.QrSharePanel()
    }
    .width('100%').height('100%')
    .onAreaChange((_old: Area, newVal: Area): void => {
      const w: number = newVal.width as number
      const h: number = newVal.height as number
      this.isLandscape = w > h
      // 横屏时自动开启科学模式（但不强制显示历史）
      if (this.isLandscape) this.scientific = true
    })
  }

  // ==================== 显示屏 ====================
  @Builder DisplayPanel() {
    Column() {
    // 横屏时在显示屏右侧加历史切换按钮
    if (this.isLandscape) {
      Row() {
        Text(this.expression.length > 0 ? this.expression : ' ')
          .fontSize(14).fontColor(this.getT2()).textAlign(TextAlign.End).maxLines(3).layoutWeight(1)
        Text(this.showHistory ? '◀' : '▶')
          .fontSize(14).fontColor(this.getOp()).padding({ left: 8 })
          .onClick((): void => { this.showHistory = !this.showHistory })
      }
      .width('100%').padding({ right: 8, left: 8 })
    } else {
      Text(this.expression.length > 0 ? this.expression : ' ')
        .fontSize(18).fontColor(this.getT2()).width('100%').textAlign(TextAlign.End)
        .padding({ right: 12, left: 12 }).maxLines(3)
    }
      if (this.errorMsg.length > 0) {
        Text(this.errorMsg).fontSize(this.isLandscape ? 22 : 28).fontColor(this.getErr())
          .width('100%').textAlign(TextAlign.End).padding({ right: 12, left: 12 })
      } else {
        Text(this.result.length > 0 ? this.result : '0')
          .fontSize(this.isLandscape ? 28 : 36).fontWeight(FontWeight.Bold).fontColor(this.getT1())
          .width('100%').textAlign(TextAlign.End).padding({ right: 12, left: 12 })
      }
      Text('二维码分享').fontSize(12).fontColor(this.getOp()).padding(8)
        .onClick((): void => { this.onOpenQrShare() })
    }
    .width('100%').padding(this.isLandscape ? { top: 8, bottom: 2 } : { top: 24, bottom: 8 })
    .gesture(LongPressGesture().onAction((): void => { this.onCopy() }))
  }

  // ==================== 模式切换栏（仅竖屏显示） ====================
  @Builder ToggleRow() {
    Row() {
      Text(this.scientific ? '科学' : '基础').fontSize(12).fontColor(this.getOp())
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .border({ width: 1, color: this.getOp(), radius: 8 })
        .onClick((): void => { this.scientific = !this.scientific })
      Blank()
      Text('绘图').fontSize(12).fontColor(this.getT2()).padding(8)
        .onClick((): void => { this.onOpenPlot() })
      Text(this.showHistory ? '▲ 历史' : '▼ 历史').fontSize(12).fontColor(this.getT2()).padding(8)
        .onClick((): void => { this.showHistory = !this.showHistory })
      Text('⚙').fontSize(16).fontColor(this.getT2()).padding(8)
        .onClick((): void => { this.showSettings = true })
    }
    .width('100%').padding({ left: 16, right: 16, bottom: 4 })
  }

  // ==================== 按钮网格 ====================
  @Builder ButtonGrid() {
    Column() {
      if (this.scientific) {
        Row() { this.BtnFunc('sin'); this.BtnFunc('cos'); this.BtnFunc('tan'); this.BtnFunc('ln'); this.BtnFunc('log') }
        Row() { this.BtnFunc('arcsi'); this.BtnFunc('arcco'); this.BtnFunc('arcta'); this.BtnConst('π'); this.BtnConst('e') }
        Row() { this.BtnConst('x') }
      }
      Row() { this.BtnAct('AC'); this.BtnOp('('); this.BtnOp(')'); this.BtnOp('÷') }
      Row() { this.BtnDig('7'); this.BtnDig('8'); this.BtnDig('9'); this.BtnOp('×') }
      Row() { this.BtnDig('4'); this.BtnDig('5'); this.BtnDig('6'); this.BtnOp('-') }
      Row() { this.BtnDig('1'); this.BtnDig('2'); this.BtnDig('3'); this.BtnOp('+') }
      Row() { this.BtnDig('0'); this.BtnOp('.'); this.BtnAct('⌫'); this.BtnEq() }
    }
    .width('100%').padding({ left: 8, right: 8 }).layoutWeight(this.isLandscape ? 0 : 1)
  }

  /** 数字按钮 */
  @Builder BtnDig(l: string) { Text(l).fontSize(this.isLandscape ? 16 : 22).fontColor(this.getT1()).width('22%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(this.getBtnBg()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { this.onDigit(l) }) }

  /** 运算符按钮 */
  @Builder BtnOp(l: string) { Text(l).fontSize(this.isLandscape ? 14 : 20).fontColor(this.getBtnText()).width('22%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(this.getOp()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { this.onOp(l) }) }

  /** 科学函数按钮 */
  @Builder BtnFunc(l: string) { Text(l).fontSize(this.isLandscape ? 11 : 14).fontColor(this.getT1()).width('18%').height(this.isLandscape ? 30 : 46).textAlign(TextAlign.Center).backgroundColor(this.getFuncBg()).borderRadius(50).margin(this.isLandscape ? 1 : 3).onClick((): void => { this.onFunc(l) }) }

  /** 常量按钮 */
  @Builder BtnConst(l: string) { Text(l).fontSize(this.isLandscape ? 13 : 18).fontColor(this.getOp() === '#B4D2E4' ? '#4684E3' : this.getOp()).width('18%').height(this.isLandscape ? 30 : 46).textAlign(TextAlign.Center).backgroundColor(this.getFuncBg()).borderRadius(50).margin(this.isLandscape ? 1 : 3).onClick((): void => { this.onConst(l) }) }

  /** 动作按钮（AC/退格） */
  @Builder BtnAct(l: string) { Text(l).fontSize(this.isLandscape ? 14 : 20).fontColor(this.getBtnText()).width('22%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(l === 'AC' ? this.getClr() : this.getBtnBg()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { if (l === 'AC') this.onAC(); else this.onBS() }) }

  /** 等号按钮 */
  @Builder BtnEq() { Text('=').fontSize(this.isLandscape ? 18 : 24).fontWeight(FontWeight.Bold).fontColor(this.getBtnText()).width('22%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(this.getEq()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { this.onEquals() }) }

  // ==================== 历史面板（仿 Android SlidingUpPanelLayout） ====================

  @Builder HistoryPanel() {
    Column() {
      // 拖拽手柄 / 折叠按钮（始终可见，仿 Android sliding_layout_button）
      Row() {
        // 手柄横条
        Text('').width(40).height(4).backgroundColor(this.getT2()).borderRadius(2)
      }
      .width('100%').height(24).justifyContent(FlexAlign.Center)
      .onClick((): void => { this.showHistory = false })

      if (this.history.length === 0) {
        Text('暂无计算记录').fontSize(13).fontColor(this.getT2()).width('100%').textAlign(TextAlign.Center).padding(20)
      } else {
        List() {
          ForEach(this.history, (item: HistoryItem) => {
            ListItem() {
              Column() {
                Text(item.expression).fontSize(12).fontColor(this.getT2()).maxLines(1)
                Text(item.result).fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.getOp())
              }
              .alignItems(HorizontalAlign.Start).width('100%').padding(this.isLandscape ? 8 : 12)
              .onClick((): void => { this.onHistoryTap(item) })
            }
            .swipeAction({ end: { builder: (): void => { this.DelBtn(item) } } })
          })
        }
        .layoutWeight(1)
      }
    }
    .layoutWeight(this.isLandscape ? 1 : 0)
    .width('100%').height(this.isLandscape ? '100%' : 'auto')
    .backgroundColor(this.getPanelBg())
    .borderRadius(this.isLandscape ? 0 : { topLeft: 16, topRight: 16 })
  }

  @Builder DelBtn(item: HistoryItem) {
    Text('删除').fontSize(14).fontColor(this.getT1()).padding(16).backgroundColor(this.getErr()).height('100%')
      .onClick((): void => { this.onHistoryDelete(item) })
  }

  // ==================== 设置面板 ====================
  @Builder SettingsPanel() {
    Column() {
      Row() {
        Text('设置').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.getT1())
        Blank()
        Text('✕').fontSize(20).fontColor(this.getT2()).onClick((): void => { this.showSettings = false })
      }.width('100%').padding(16)
      List() {
        ListItem() { this.ToggleItem('振动反馈', this.vibrateOn, (v: boolean): void => { this.vibrateOn = v; this.savePref('vibrateOn', v) }) }
        ListItem() { this.ToggleItem('防休眠', this.preventSleep, (v: boolean): void => { this.preventSleep = v; this.savePref('preventSleep', v) }) }
        ListItem() { this.ToggleItem('弧度模式', this.radianMode, (v: boolean): void => { this.radianMode = v; this.savePref('radianMode', v) }) }
        ListItem() { this.ThemeItem() }
        ListItem() {
          Row() { Text('关于 OpenCalc').fontSize(15).fontColor(this.getT2()); Blank(); Text('>').fontColor(this.getT2()) }
          .width('100%').padding(12).onClick((): void => { this.showSettings = false; this.showAbout = true })
        }
      }
    }
    .width('85%').backgroundColor(this.getPanelBg()).borderRadius(16)
  }

  @Builder ToggleItem(title: string, val: boolean, cb: (v: boolean) => void) {
    Row() {
      Text(title).fontSize(15).fontColor(this.getT1()).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: val }).onChange((on: boolean): void => { cb(on) })
    }.width('100%').padding(12)
  }

  @Builder ThemeItem() {
    Row() {
      Text('主题').fontSize(15).fontColor(this.getT1()).layoutWeight(1)
      Row() {
        Text('浅色').fontSize(11).fontColor(this.themeIdx === 0 ? '#000' : this.getT2())
          .backgroundColor(this.themeIdx === 0 ? this.getOp() : (this.themeIdx >= 1 ? '#555' : '#DDD'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(8).margin({ left: 2 })
          .onClick((): void => { this.themeIdx = 0; this.savePref('themeIdx', 0) })
        Text('暗色').fontSize(11).fontColor(this.themeIdx === 2 ? '#EFEFEF' : this.getT2())
          .backgroundColor(this.themeIdx === 2 ? '#0070BC' : (this.themeIdx >= 1 ? '#555' : '#DDD'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(8).margin({ left: 2 })
          .onClick((): void => { this.themeIdx = 2; this.savePref('themeIdx', 2) })
        Text('AMOLED').fontSize(11).fontColor(this.themeIdx === 1 ? '#EFEFEF' : this.getT2())
          .backgroundColor(this.themeIdx === 1 ? '#B3004D' : (this.themeIdx >= 1 ? '#555' : '#DDD'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(8).margin({ left: 2 })
          .onClick((): void => { this.themeIdx = 1; this.savePref('themeIdx', 1) })
      }
    }.width('100%').padding(12)
  }

  // ==================== 关于面板 ====================
  @Builder AboutPanel() {
    Column() {
      Text('关于 OpenCalc').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.getT1()).padding({ bottom: 12 })
      Text('OpenCalc HarmonyOS').fontSize(14).fontColor(this.getT2())
      Text('版本 1.0.0').fontSize(14).fontColor(this.getT2()).padding({ top: 4 })
      Text('原项目: github.com/clementwzk/OpenCalc').fontSize(11).fontColor(this.getT2()).padding({ top: 8 })
      Text('Android 3.2.1 → HarmonyOS').fontSize(11).fontColor(this.getT2()).padding({ top: 2 })
      Text('迁移: github.com/JungleTestLabs/opencalc-harmonyos').fontSize(11).fontColor(this.getOp()).padding({ top: 4 })
      Button('关闭').margin({ top: 16 }).onClick((): void => { this.showAbout = false })
    }
    .width('80%').padding(24).backgroundColor(this.getPanelBg()).borderRadius(16)
  }

  // ==================== 绘图面板（Issue #40，全屏覆盖层，非新路由页） ====================
  @Builder PlotPanel() {
    Column() {
      // 标题行：返回按钮始终可点（CM-05）
      Row() {
        Text('函数绘图').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.getT1())
        Blank()
        Text('✕ 返回').fontSize(16).fontColor(this.getT2()).padding(8)
          .onClick((): void => { this.showPlot = false })
      }
      .width('100%').padding(16)

      TextInput({ text: this.plotInput, placeholder: '输入含 x 的表达式，如 sin(x)' })
        .width('100%').height(40).fontSize(14)
        .onChange((value: string): void => { this.plotInput = value })

      Row() {
        Button('插入 x').fontSize(14).height(40).layoutWeight(1).margin({ right: 6 })
          .backgroundColor(this.getBtnBg()).fontColor(this.getT1())
          .onClick((): void => { this.plotInput = this.plotInput + 'x' })
        Button('AC').fontSize(14).height(40).layoutWeight(1).margin({ right: 6 })
          .backgroundColor(this.getClr()).fontColor(this.getBtnText())
          .onClick((): void => { this.plotInput = ''; this.plotError = '' })
        Button('绘制').fontSize(14).height(40).layoutWeight(1)
          .backgroundColor(this.getOp()).fontColor(this.getBtnText())
          .onClick((): void => { this.onPlot() })
      }
      .width('100%').margin({ top: 8 })

      if (this.plotError.length > 0) {
        Text(this.plotError).fontSize(14).fontColor(this.getErr()).width('100%').padding({ top: 8 })
      }

      Canvas(this.canvasCtx)
        .width('100%').layoutWeight(1).margin({ top: 8 })
        .backgroundColor(this.getPanelBg())
        .onReady((): void => { this.drawPlot() })
        .onAreaChange((_old: Area, newVal: Area): void => {
          this.canvasW = newVal.width as number
          this.canvasH = newVal.height as number
          this.drawPlot()
        })
    }
    .width('100%').height('100%').padding(16).backgroundColor(this.getPanelBg())
  }

  // ==================== 二维码分享面板（Issue #42） ====================
  @Builder QrSharePanel() {
    Column() {
      Row() {
        Text('二维码分享').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.getT1())
        Blank()
        Text('✕ 返回').fontSize(16).fontColor(this.getT2()).padding(8)
          .onClick((): void => { this.showQrShare = false })
      }
      .width('100%').padding(16)

      if (this.qrPayloadOk) {
        Canvas(this.qrCanvasCtx)
          .width('100%').layoutWeight(1).margin({ left: 16, right: 16 })
          .backgroundColor('#FFFFFF')
          .onReady((): void => { this.drawQr() })
          .onAreaChange((_old: Area, newVal: Area): void => {
            this.qrCanvasW = newVal.width as number
            this.qrCanvasH = newVal.height as number
            this.drawQr()
          })
      } else {
        Text(this.qrErrorText.length > 0 ? this.qrErrorText : '二维码生成失败')
          .fontSize(16).fontColor(this.getErr()).layoutWeight(1)
      }

      Column() {
        Text('算式: ' + this.expression).fontSize(15).fontColor(this.getT1())
          .width('100%').maxLines(3)
        Text('结果: ' + this.result).fontSize(15).fontColor(this.getT1())
          .width('100%').margin({ top: 8 }).maxLines(2)
      }
      .width('100%').padding(16)
    }
    .width('100%').height('100%').backgroundColor(this.getPanelBg())
  }
}
