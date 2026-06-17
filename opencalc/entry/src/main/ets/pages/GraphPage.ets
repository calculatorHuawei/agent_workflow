// OpenCalc — 函数图像绘制页面
// aid-workflow 20260617: Issue #26 函数图像
// 设计参考: specs/changes/20260617-requirement-add-plot-graph/delta-design.md §3.5

import { router } from '@kit.ArkUI'
import { GraphViewModel } from '../viewmodels/GraphViewModel'
import { PlotUtils, PlotPoint, PlotBounds, PlotSeries } from '../common/PlotUtils'
import { PreferencesStore } from '../preferences/PreferencesStore'
import { common } from '@kit.AbilityKit'

/** 主题色(themeIdx 0/1/2 → 颜色字符串) */
const THEME_COLORS: string[] = ['#4684E3', '#4FC3F7', '#7E57C2']

/** 文本输入最大长度(防路由参数溢出) */
const MAX_INPUT_LENGTH: number = 256

/** Canvas 内边距(像素,vp 单位) */
const PAD_L: number = 40
const PAD_R: number = 20
const PAD_T: number = 20
const PAD_B: number = 30

@Entry
@Component
struct GraphPage {
  @State vm: GraphViewModel = new GraphViewModel()
  @State curveColor: string = THEME_COLORS[0]
  @State expressionInput: string = 'sin(x)'
  @State xMinInput: string = '-2'
  @State xMaxInput: string = '2'
  @State samplesInput: string = '200'
  @State isLandscape: boolean = false
  @State canvasReady: boolean = false
  @State canvasWidth: number = 0
  @State canvasHeight: number = 0

  private canvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private prefs: PreferencesStore | null = null

  aboutToAppear(): void {
    // 读取路由参数(可选)
    const params = router.getParams() as Record<string, Object> | undefined
    if (params !== undefined && params !== null) {
      const expr = params['expression'] as string | undefined
      if (expr !== undefined && expr.length > 0 && expr.length <= MAX_INPUT_LENGTH) {
        this.vm.expression = expr
        this.expressionInput = expr
      }
    }
    // 读取偏好
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
    this.prefs = new PreferencesStore(ctx)
    this.prefs.init().then((): void => { this.loadPrefs() })
    // 首次计算
    setTimeout((): void => { this.vm.compute() }, 0)
  }

  onPageShow(): void {
    // 页面显示时强制重绘(防止 Canvas 状态丢失)
    if (this.canvasReady) {
      this.drawCanvas()
    }
  }

  async loadPrefs(): Promise<void> {
    if (!this.prefs) return
    const radianMode = await this.prefs.getRadiansDefault()
    this.vm.setRadianMode(!radianMode)  // radianMode=true → 弧度 → isDegree=false
    const themeIdx = await this.prefs.getTheme()
    if (themeIdx >= 0 && themeIdx < THEME_COLORS.length) {
      this.curveColor = THEME_COLORS[themeIdx]
    }
  }

  onBackPress(): boolean {
    router.back()
    return true
  }

  build() {
    Stack() {
      Column() {
        // 工具栏
        this.Toolbar()
        // Canvas 画布
        Canvas(this.canvasCtx)
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#FFFFFF')
          .onReady((): void => {
            this.canvasReady = true
            // 读取实际画布尺寸
            this.canvasWidth = this.canvasCtx.width
            this.canvasHeight = this.canvasCtx.height
            this.drawCanvas()
          })
          .onAreaChange((_old: Area, newVal: Area): void => {
            const w = newVal.width as number
            const h = newVal.height as number
            this.canvasWidth = w
            this.canvasHeight = h
            this.isLandscape = w > h
            if (this.canvasReady) {
              this.drawCanvas()
            }
          })
        // 错误条
        if (this.vm.errorMessage.length > 0) {
          Text(this.vm.errorMessage)
            .fontSize(12)
            .fontColor('#FF3B30')
            .width('100%')
            .padding(8)
            .backgroundColor('#FFEEEE')
            .textAlign(TextAlign.Center)
        }
        // 输入栏
        this.InputPanel()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FAFAFA')
    }
    .width('100%')
    .height('100%')
  }

  // ==================== 工具栏 ====================
  @Builder Toolbar() {
    Row() {
      Text('←')
        .fontSize(20)
        .fontColor('#333333')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .onClick((): void => { router.back() })
      Text('函数图像')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .layoutWeight(1)
        .padding({ left: 8 })
      Blank()
      Text('📈')
        .fontSize(20)
        .padding({ right: 16 })
    }
    .width('100%')
    .height(48)
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 1 }, color: '#EEEEEE' })
  }

  // ==================== 输入栏 ====================
  @Builder InputPanel() {
    Column() {
      Row() {
        Text('f(x)=')
          .fontSize(14)
          .fontColor('#333333')
          .width(50)
          .height(36)
        TextInput({ text: this.expressionInput, placeholder: 'sin(x)' })
          .layoutWeight(1)
          .height(36)
          .fontSize(14)
          .onChange((value: string): void => {
            this.expressionInput = value
            this.vm.expression = value
          })
        Button('绘制')
          .fontSize(13)
          .height(36)
          .margin({ left: 8 })
          .backgroundColor(this.curveColor)
          .onClick((): void => {
            this.vm.compute()
            this.drawCanvas()
          })
      }
      .width('100%')
      .padding(8)

      Row() {
        Column() {
          Text('xMin').fontSize(10).fontColor('#888888').width('100%')
          TextInput({ text: this.xMinInput })
            .width('100%')
            .height(32)
            .fontSize(13)
            .onChange((value: string): void => {
              this.xMinInput = value
              const v = PlotUtils.parseRange(value)
              if (v !== null) this.vm.xMin = v
            })
        }
        .layoutWeight(1)
        .padding({ right: 4 })

        Column() {
          Text('xMax').fontSize(10).fontColor('#888888').width('100%')
          TextInput({ text: this.xMaxInput })
            .width('100%')
            .height(32)
            .fontSize(13)
            .onChange((value: string): void => {
              this.xMaxInput = value
              const v = PlotUtils.parseRange(value)
              if (v !== null) this.vm.xMax = v
            })
        }
        .layoutWeight(1)
        .padding({ left: 4, right: 4 })

        Column() {
          Text('samples').fontSize(10).fontColor('#888888').width('100%')
          TextInput({ text: this.samplesInput })
            .width('100%')
            .height(32)
            .fontSize(13)
            .onChange((value: string): void => {
              this.samplesInput = value
              const v = parseInt(value)
              if (!isNaN(v)) this.vm.samples = v
            })
        }
        .layoutWeight(1)
        .padding({ left: 4 })
      }
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 8 })
    }
    .width('100%')
    .height(116)
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#EEEEEE' })
  }

  // ==================== 绘制 ====================
  private drawCanvas(): void {
    const ctx = this.canvasCtx
    if (this.canvasWidth <= 0 || this.canvasHeight <= 0) return
    // 清空
    ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight)
    ctx.fillStyle = '#FFFFFF'
    ctx.fillRect(0, 0, this.canvasWidth, this.canvasHeight)

    const bounds: PlotBounds = {
      width: this.canvasWidth,
      height: this.canvasHeight,
      paddingLeft: PAD_L,
      paddingRight: PAD_R,
      paddingTop: PAD_T,
      paddingBottom: PAD_B
    }

    const series = this.vm.series
    if (series === null) {
      this.drawPlaceholder(bounds, this.vm.errorMessage.length > 0 ? this.vm.errorMessage : '点击"绘制"按钮开始')
      return
    }

    // 网格
    this.drawGrid(bounds, series)
    // 坐标轴
    this.drawAxes(bounds, series)
    // 曲线
    this.drawCurve(bounds, series)
  }

  private drawGrid(bounds: PlotBounds, series: PlotSeries): void {
    const ctx = this.canvasCtx
    ctx.strokeStyle = '#22000000'
    ctx.lineWidth = 1
    const step = 1
    const startX = Math.floor(series.xMin / step)
    const endX = Math.ceil(series.xMax / step)
    // 垂直网格线
    for (let i = startX; i <= endX; i++) {
      const p = PlotUtils.mapToCanvas({ x: i, y: 0 } as PlotPoint, bounds, series.xMin, series.xMax, series.yMin, series.yMax)
      if (p === null) continue
      ctx.beginPath()
      ctx.moveTo(p.px, bounds.paddingTop)
      ctx.lineTo(p.px, bounds.height - bounds.paddingBottom)
      ctx.stroke()
    }
    // 水平网格线
    const startY = Math.floor(series.yMin / step)
    const endY = Math.ceil(series.yMax / step)
    for (let i = startY; i <= endY; i++) {
      const p = PlotUtils.mapToCanvas({ x: 0, y: i } as PlotPoint, bounds, series.xMin, series.xMax, series.yMin, series.yMax)
      if (p === null) continue
      ctx.beginPath()
      ctx.moveTo(bounds.paddingLeft, p.py)
      ctx.lineTo(bounds.width - bounds.paddingRight, p.py)
      ctx.stroke()
    }
  }

  private drawAxes(bounds: PlotBounds, series: PlotSeries): void {
    const ctx = this.canvasCtx
    ctx.strokeStyle = '#FF000000'
    ctx.lineWidth = 2
    ctx.fillStyle = '#FF333333'
    ctx.font = '10px sans-serif'
    // x 轴 (y=0)
    const xAxisP = PlotUtils.mapToCanvas({ x: 0, y: 0 } as PlotPoint, bounds, series.xMin, series.xMax, series.yMin, series.yMax)
    if (xAxisP !== null && xAxisP.py >= bounds.paddingTop && xAxisP.py <= bounds.height - bounds.paddingBottom) {
      ctx.beginPath()
      ctx.moveTo(bounds.paddingLeft, xAxisP.py)
      ctx.lineTo(bounds.width - bounds.paddingRight, xAxisP.py)
      ctx.stroke()
    }
    // y 轴 (x=0)
    const yAxisP = PlotUtils.mapToCanvas({ x: 0, y: 0 } as PlotPoint, bounds, series.xMin, series.xMax, series.yMin, series.yMax)
    if (yAxisP !== null && yAxisP.px >= bounds.paddingLeft && yAxisP.px <= bounds.width - bounds.paddingRight) {
      ctx.beginPath()
      ctx.moveTo(yAxisP.px, bounds.paddingTop)
      ctx.lineTo(yAxisP.px, bounds.height - bounds.paddingBottom)
      ctx.stroke()
    }
    // 刻度标签
    const labelStep = 1
    const startX = Math.floor(series.xMin / labelStep)
    const endX = Math.ceil(series.xMax / labelStep)
    for (let i = startX; i <= endX; i++) {
      if (i === 0) continue
      const p = PlotUtils.mapToCanvas({ x: i, y: 0 } as PlotPoint, bounds, series.xMin, series.xMax, series.yMin, series.yMax)
      if (p === null) continue
      ctx.fillText(String(i), p.px - 5, (xAxisP !== null ? xAxisP.py : bounds.height / 2) + 12)
    }
  }

  private drawCurve(bounds: PlotBounds, series: PlotSeries): void {
    const ctx = this.canvasCtx
    ctx.strokeStyle = this.curveColor
    ctx.lineWidth = 2
    ctx.beginPath()
    let started = false
    for (let i = 0; i < series.points.length; i++) {
      const p = series.points[i]
      const cp = PlotUtils.mapToCanvas(p, bounds, series.xMin, series.xMax, series.yMin, series.yMax)
      if (cp === null) {
        started = false
        continue
      }
      if (!started) {
        ctx.moveTo(cp.px, cp.py)
        started = true
      } else {
        ctx.lineTo(cp.px, cp.py)
      }
    }
    ctx.stroke()
  }

  private drawPlaceholder(bounds: PlotBounds, text: string): void {
    const ctx = this.canvasCtx
    ctx.fillStyle = '#FF999999'
    ctx.font = '14px sans-serif'
    const w = ctx.measureText(text).width
    ctx.fillText(text, (bounds.width - w) / 2, bounds.height / 2)
  }
}
