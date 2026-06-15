// OpenCalc — 主计算器页面（横竖屏自适应 + Android 配色）
// 移植自：MainActivity.kt（1447行）
import { promptAction } from '@kit.ArkUI'
import { pasteboard } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { Expression } from '../calculator/Expression'
import { CalcEngine } from '../calculator/Calculator'
import { NumberFormatter } from '../calculator/NumberFormatter'
import { BaseConverter } from '../calculator/BaseConverter'
import {
  BaseConversions,
  CalculatorMode,
  HistoryItem,
  NumberBase,
  NumberingSystem
} from '../model/Models'
import { ErrorFlags } from '../model/ErrorFlags'
import { PreferencesStore } from '../preferences/PreferencesStore'

@Entry
@Component
export struct CalculatorPage {
  // ==================== 显示状态 ====================
  // aid-workflow 20260612: @Watch 修饰 @State 字段，expression 变化时触发 onExpressionChange
  @State @Watch('onExpressionChange') expression: string = ''
  @State preview: string = ''   // aid-workflow 20260612: 实时预览值
  @State result: string = ''
  @State errorMsg: string = ''
  // Issue #12: 二选一 → 三选一模式（基础 / 科学 / 程序员）
  @State @Watch('onModeChange') mode: CalculatorMode = CalculatorMode.BASIC
  @State @Watch('onActiveBaseChange') activeBase: NumberBase = NumberBase.DEC
  @State baseConversions: BaseConversions = { dec: '', hex: '', oct: '', bin: '' }
  @State history: HistoryItem[] = []
  @State showHistory: boolean = false
  @State showSettings: boolean = false
  @State showAbout: boolean = false
  @State isLandscape: boolean = false
  // Issue #12: 最近一次计算结果（用于模式切换后刷新多进制显示行）
  @State lastResult: number = 0

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
    // Issue #12: 优先读取 mode 字段；缺失时回退到旧 scientificModeDefault（兼容旧版本数据）
    const savedMode: number = await this.prefs.getMode()
    if (savedMode === CalculatorMode.BASIC || savedMode === CalculatorMode.SCIENTIFIC || savedMode === CalculatorMode.PROGRAMMER) {
      this.mode = savedMode
    } else {
      const oldSci: number = await this.prefs.getScientificModeDefault()
      this.mode = oldSci === 1 ? CalculatorMode.SCIENTIFIC : CalculatorMode.BASIC
    }
    this.activeBase = await this.prefs.getActiveBase()
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
    // Issue #12: 兼容旧 scientific 写入路径
    else if (key === 'scientific') await this.prefs.setScientificModeDefault(value as number)
    else if (key === 'mode') await this.prefs.setMode(value as number)
    else if (key === 'activeBase') await this.prefs.setActiveBase(value as number)
  }

  // ==================== 按钮事件 ====================
  // aid-workflow 20260612: 实时预览触发器，expression 变化时同步计算 preview
  // 注：ArkTS 中 @Watch 装饰器必须紧跟 @State（见字段声明），此处仅为回调方法
  onExpressionChange(): void {
    this.preview = this.computePreview(this.expression, this.radianMode)
  }

  /**
   * aid-workflow 20260612: 计算表达式实时预览（纯函数，副作用隔离）
   * 对应 design.md §3.3 与 RealtimePreview.port.mjs::PreviewCalculator.computePreview
   * @param exprStr 用户当前输入的表达式字符串
   * @param radianMode true=弧度模式，false=角度模式
   * @returns 格式化后的预览字符串，错误/不完整时返回空字符串
   */
  private computePreview(exprStr: string, radianMode: boolean): string {
    // 1. 空表达式 → ""
    if (exprStr.length === 0) return ''

    // 2. 末字符白名单过滤
    const lastChar: string = exprStr.charAt(exprStr.length - 1)
    if (!this.isLastCharComputable(lastChar)) return ''

    // 3. 括号平衡过滤（未闭合左括号 → 空）
    let openP: number = 0
    let closeP: number = 0
    for (let pi: number = 0; pi < exprStr.length; pi++) {
      const ch: string = exprStr.charAt(pi)
      if (ch === '(') openP++
      else if (ch === ')') closeP++
    }
    if (openP > closeP) return ''

    // 3.5 连续运算符检测（aid-workflow 20260612 修复 1++2 BUG）
    // 不允许两个二元运算符相邻（如 ++, +-, --, *+, /+, *-, 等）
    // 允许一元负号: "(-5)" 中 - 紧跟 ( 是合法的一元负号
    // 实现: 扫描每个运算符位置，如果前一个非 ( 也非数字开头的小数点，则为不合法的连续运算符
    if (this.hasConsecutiveBinaryOperators(exprStr)) return ''

    // 4. ErrorFlags 快照（避免污染主流程）
    const snap: boolean[] = ErrorFlags.snapshot()

    try {
      // 5. 预处理
      const clean: string = this.expr.getCleanExpression(exprStr, '.', ',')
      if (ErrorFlags.syntax_error) {
        ErrorFlags.restore(snap)
        return ''
      }

      // 6. 求值
      const raw: number = this.engine.evaluate(clean, !radianMode)
      if (ErrorFlags.division_by_0 || ErrorFlags.domain_error ||
          ErrorFlags.syntax_error || ErrorFlags.is_infinity ||
          ErrorFlags.require_real_number) {
        ErrorFlags.restore(snap)
        return ''
      }

      // 7. 格式化
      const formatted: string = NumberFormatter.format(raw.toString(), '.', ',', NumberingSystem.INTERNATIONAL)
      ErrorFlags.restore(snap)
      return formatted
    } catch (_e) {
      ErrorFlags.restore(snap)
      return ''
    }
  }

  /**
   * aid-workflow 20260612: 末字符是否可参与求值
   * 可计算末字符：数字 / '.' / ')' / '%' / '!' / 'π' / 'e'
   */
  private isLastCharComputable(lastChar: string): boolean {
    if ((lastChar >= '0' && lastChar <= '9') || lastChar === '.') return true
    if (lastChar === ')') return true
    if (lastChar === '%') return true
    if (lastChar === '!') return true
    if (lastChar === 'π' || lastChar === 'e') return true
    return false
  }

  /**
   * aid-workflow 20260612 (BUG 修复): 检测连续二元运算符
   * 修复 1++2 / 2×-2 预览误显示的问题。
   * 规则：不允许两个二元运算符相邻
   * 支持的运算符：+ - * / × ÷ % ^ #（含 Unicode × ÷，用户键入的乘除号）
   * 允许的合法场景：一元负号 (-5)、一元正号 (+5) 在表达式开头或 ( 后
   * @param exprStr 表达式字符串
   * @returns true=存在不合法的连续运算符，false=合法
   */
  private hasConsecutiveBinaryOperators(exprStr: string): boolean {
    const binaryOps: string = '+-*/×÷%^#'  // 同时支持 ASCII (* /) 和 Unicode (× ÷)
    for (let i: number = 1; i < exprStr.length; i++) {
      const prev: string = exprStr.charAt(i - 1)
      const curr: string = exprStr.charAt(i)
      // 当前是二元运算符
      if (binaryOps.indexOf(curr) === -1) continue
      // 前一个是 ( → 当前是一元运算符，合法（如 (-5）、(×2)）
      if (prev === '(') continue
      // 前一个是数字/小数点/右括号/百分号/阶乘/常量 → 当前是二元运算符，合法
      if ((prev >= '0' && prev <= '9') || prev === '.' || prev === ')' ||
          prev === '%' || prev === '!' || prev === 'π' || prev === 'e') continue
      // 其他情况：两个二元运算符相邻
      if (binaryOps.indexOf(prev) !== -1) return true
    }
    return false
  }

  onDigit(d: string): void { this.expression = this.expression + d; this.errorMsg = '' }
  onOp(op: string): void {
    // aid-workflow 20260612: 错误状态恢复（SR-09）
    // 用户决策：清空 expression 和 errorMsg
    if (ErrorFlags.syntax_error || ErrorFlags.division_by_0 || ErrorFlags.domain_error ||
        ErrorFlags.is_infinity || ErrorFlags.require_real_number) {
      ErrorFlags.reset()
      this.expression = ''
      this.errorMsg = ''
      this.result = ''
    }
    this.expression = this.expression + op
    this.errorMsg = ''
  }
  onFunc(f: string): void { this.expression = this.expression + f + '('; this.errorMsg = '' }
  onConst(c: string): void { this.expression = this.expression + c; this.errorMsg = '' }
  onBS(): void { if (this.expression.length > 0) this.expression = this.expression.substring(0, this.expression.length - 1) }
  onAC(): void { this.expression = ''; this.result = ''; this.preview = ''; this.errorMsg = ''; ErrorFlags.reset() }

  onEquals(): void {
    if (this.expression.length === 0) return
    ErrorFlags.reset()
    try {
      const clean: string = this.expr.getCleanExpression(this.expression, '.', ',')
      const raw: number = this.engine.evaluate(clean, !this.radianMode)
      if (ErrorFlags.division_by_0) { this.errorMsg = '除数不能为零'; this.result = ''; this.refreshBaseConversions(NaN) }
      else if (ErrorFlags.domain_error) { this.errorMsg = '定义域错误'; this.result = ''; this.refreshBaseConversions(NaN) }
      else if (ErrorFlags.syntax_error) { this.errorMsg = '表达式错误'; this.result = ''; this.refreshBaseConversions(NaN) }
      else if (ErrorFlags.is_infinity) { this.errorMsg = '结果无穷大'; this.result = ''; this.refreshBaseConversions(NaN) }
      else if (ErrorFlags.require_real_number) { this.errorMsg = '需要实数'; this.result = ''; this.refreshBaseConversions(NaN) }
      else {
        // Issue #12: 程序员模式下主结果按 activeBase 格式化
        let displayStr: string
        if (this.mode === CalculatorMode.PROGRAMMER) {
          displayStr = BaseConverter.withPrefix(raw, this.activeBase)
        } else {
          displayStr = NumberFormatter.format(raw.toString(), '.', ',', NumberingSystem.INTERNATIONAL)
        }
        this.result = displayStr
        this.errorMsg = ''
        this.lastResult = raw
        this.refreshBaseConversions(raw)
        // 历史记录保存 DEC 显示（兼容现有行为）
        const histFmt: string = NumberFormatter.format(raw.toString(), '.', ',', NumberingSystem.INTERNATIONAL)
        const item: HistoryItem = { id: this.nextId, expression: this.expression, result: histFmt, timestamp: Date.now() }
        this.nextId = this.nextId + 1
        const nh: HistoryItem[] = [item]
        for (let i: number = 0; i < this.history.length; i++) nh.push(this.history[i])
        this.history = nh
        if (this.prefs) this.prefs.setHistory(this.history)
      }
    } catch (_e) {
      this.errorMsg = '计算错误'
      this.refreshBaseConversions(NaN)
    }
  }

  // ==================== Issue #12 程序员模式 - 状态回调 ====================

  /**
   * 模式切换回调：@Watch('onModeChange') 触发持久化 + 刷新多进制显示
   */
  onModeChange(): void {
    this.savePref('mode', this.mode)
    this.refreshBaseConversions(this.lastResult)
    // 主结果按新模式重新格式化（程序员模式按 activeBase）
    if (Number.isFinite(this.lastResult)) {
      if (this.mode === CalculatorMode.PROGRAMMER) {
        this.result = BaseConverter.withPrefix(this.lastResult, this.activeBase)
      } else if (this.result.length > 0) {
        this.result = NumberFormatter.format(this.lastResult.toString(), '.', ',', NumberingSystem.INTERNATIONAL)
      }
    }
  }

  /**
   * 主进制切换回调：@Watch('onActiveBaseChange') 触发持久化 + 刷新主结果
   */
  onActiveBaseChange(): void {
    this.savePref('activeBase', this.activeBase)
    if (this.mode === CalculatorMode.PROGRAMMER && Number.isFinite(this.lastResult)) {
      this.result = BaseConverter.withPrefix(this.lastResult, this.activeBase)
    }
  }

  /**
   * 刷新 4 行多进制显示行
   * @param value 当前计算结果（NaN 表示错误状态）
   */
  private refreshBaseConversions(value: number): void {
    if (!Number.isFinite(value)) {
      this.baseConversions = { dec: '-', hex: '-', oct: '-', bin: '-' }
    } else {
      this.baseConversions = {
        dec: BaseConverter.convert(value, NumberBase.DEC),
        hex: BaseConverter.withPrefix(value, NumberBase.HEX),
        oct: BaseConverter.withPrefix(value, NumberBase.OCT),
        bin: BaseConverter.withPrefix(value, NumberBase.BIN)
      }
    }
  }

  onCopy(): void {
    if (this.result.length === 0) return
    pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.result))
    promptAction.showToast({ message: '已复制' })
  }

  onHistoryTap(item: HistoryItem): void { this.expression = item.expression; this.showHistory = false }
  onHistoryDelete(item: HistoryItem): void {
    const keep: HistoryItem[] = []
    for (let i: number = 0; i < this.history.length; i++) { if (this.history[i].id !== item.id) keep.push(this.history[i]) }
    this.history = keep
    if (this.prefs) this.prefs.setHistory(this.history)
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
          this.ModeToggleRow()
          if (this.mode === CalculatorMode.PROGRAMMER) {
            this.ActiveBaseSegment()
            this.BaseConverterPanel()
          }
          this.ButtonGrid()
          if (this.showHistory) this.HistoryPanel()
        }
        .width('100%').height('100%').backgroundColor(this.getBg())
      }
      if (this.showSettings) this.SettingsPanel()
      if (this.showAbout) this.AboutPanel()
    }
    .width('100%').height('100%')
    .onAreaChange((_old: Area, newVal: Area): void => {
      const w: number = newVal.width as number
      const h: number = newVal.height as number
      this.isLandscape = w > h
      // Issue #12: 横屏时自动升级 BASIC → SCIENTIFIC (但不覆盖用户主动选择的 PROGRAMMER)
      if (this.isLandscape && this.mode === CalculatorMode.BASIC) {
        this.mode = CalculatorMode.SCIENTIFIC
      }
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
    // aid-workflow 20260612: 实时预览行（expression 下方、result/errorMsg 上方）
    Text(this.preview.length > 0 ? this.preview : ' ')
      .fontSize(this.isLandscape ? 12 : 14)
      .fontColor(this.getT2())
      .width('100%').textAlign(TextAlign.End)
      .padding({ right: 12, left: 12, top: 2, bottom: 2 })
      .maxLines(1)
      if (this.errorMsg.length > 0) {
        Text(this.errorMsg).fontSize(this.isLandscape ? 22 : 28).fontColor(this.getErr())
          .width('100%').textAlign(TextAlign.End).padding({ right: 12, left: 12 })
      } else {
        Text(this.result.length > 0 ? this.result : '0')
          .fontSize(this.isLandscape ? 28 : 36).fontWeight(FontWeight.Bold).fontColor(this.getT1())
          .width('100%').textAlign(TextAlign.End).padding({ right: 12, left: 12 })
      }
    }
    .width('100%').padding(this.isLandscape ? { top: 8, bottom: 2 } : { top: 24, bottom: 8 })
    .gesture(LongPressGesture().onAction((): void => { this.onCopy() }))
  }

  // ==================== 模式切换栏（仅竖屏显示） ====================
  // Issue #12: 三选一互斥 (BASIC / SCIENTIFIC / PROGRAMMER)
  @Builder ModeToggleRow() {
    Row() {
      Row() {
        this.ModeButton('基础', CalculatorMode.BASIC)
        this.ModeButton('科学', CalculatorMode.SCIENTIFIC)
        this.ModeButton('程序员', CalculatorMode.PROGRAMMER)
      }
      .border({ width: 1, color: this.getOp(), radius: 8 })
      Blank()
      Text(this.showHistory ? '▲ 历史' : '▼ 历史').fontSize(12).fontColor(this.getT2()).padding(8)
        .onClick((): void => { this.showHistory = !this.showHistory })
      Text('⚙').fontSize(16).fontColor(this.getT2()).padding(8)
        .onClick((): void => { this.showSettings = true })
    }
    .width('100%').padding({ left: 16, right: 16, bottom: 4 })
  }

  /** 模式按钮 - 当前 mode 高亮 */
  @Builder ModeButton(label: string, target: CalculatorMode) {
    Text(label)
      .fontSize(12)
      .fontColor(this.mode === target ? '#FFFFFF' : this.getOp())
      .backgroundColor(this.mode === target ? this.getOp() : 'transparent')
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .onClick((): void => { if (this.mode !== target) { this.mode = target } })
  }

  // ==================== Issue #12 主进制切换 (仅 PROGRAMMER 模式) ====================
  @Builder ActiveBaseSegment() {
    Row() {
      this.BaseButton('DEC', NumberBase.DEC)
      this.BaseButton('BIN', NumberBase.BIN)
      this.BaseButton('OCT', NumberBase.OCT)
      this.BaseButton('HEX', NumberBase.HEX)
    }
    .width('100%').padding({ left: 16, right: 16, top: 2, bottom: 2 })
    .justifyContent(FlexAlign.SpaceBetween)
  }

  /** 主进制按钮 - 当前 activeBase 高亮 */
  @Builder BaseButton(label: string, target: NumberBase) {
    Text(label)
      .fontSize(this.isLandscape ? 10 : 12)
      .fontColor(this.activeBase === target ? '#FFFFFF' : this.getT1())
      .backgroundColor(this.activeBase === target ? this.getOp() : this.getBtnBg())
      .width('22%').height(this.isLandscape ? 24 : 30)
      .textAlign(TextAlign.Center)
      .borderRadius(8)
      .onClick((): void => { if (this.activeBase !== target) { this.activeBase = target } })
  }

  // ==================== Issue #12 多进制显示面板 (仅 PROGRAMMER 模式) ====================
  @Builder BaseConverterPanel() {
    Column() {
      this.BaseConvRow('DEC', this.baseConversions.dec, NumberBase.DEC)
      this.BaseConvRow('HEX', this.baseConversions.hex, NumberBase.HEX)
      this.BaseConvRow('OCT', this.baseConversions.oct, NumberBase.OCT)
      this.BaseConvRow('BIN', this.baseConversions.bin, NumberBase.BIN)
    }
    .width('100%').padding({ left: 16, right: 16, top: 2, bottom: 4 })
  }

  /** 单行多进制显示 */
  @Builder BaseConvRow(label: string, value: string, base: NumberBase) {
    Row() {
      Text(label)
        .fontSize(this.isLandscape ? 11 : 13)
        .fontColor(this.getT2())
        .width(40)
      Text(value.length > 0 ? value : '-')
        .fontSize(this.isLandscape ? 11 : 14)
        .fontColor(this.activeBase === base ? this.getOp() : this.getT1())
        .fontWeight(this.activeBase === base ? FontWeight.Bold : FontWeight.Normal)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%').height(this.isLandscape ? 22 : 26)
  }

  // ==================== 按钮网格 - 根据 mode 渲染不同键盘 ====================
  @Builder ButtonGrid() {
    Column() {
      if (this.mode === CalculatorMode.PROGRAMMER) {
        this.ProgrammerKeypad()
      } else if (this.mode === CalculatorMode.SCIENTIFIC) {
        this.ScientificKeypad()
      } else {
        this.BasicKeypad()
      }
    }
    .width('100%').padding({ left: 8, right: 8 }).layoutWeight(this.isLandscape ? 0 : 1)
  }

  // ==================== 基础键盘 (5 列 × 6 行) ====================
  @Builder BasicKeypad() {
    Column() {
      Row() { this.BtnActPct('AC'); this.BtnOpPct('%'); this.BtnOpPct('('); this.BtnOpPct(')'); this.BtnOpPct('÷') }
      Row() { this.BtnDig('7'); this.BtnDig('8'); this.BtnDig('9'); this.BtnOp('×') }
      Row() { this.BtnDig('4'); this.BtnDig('5'); this.BtnDig('6'); this.BtnOp('-') }
      Row() { this.BtnDig('1'); this.BtnDig('2'); this.BtnDig('3'); this.BtnOp('+') }
      Row() { this.BtnDig('0'); this.BtnOp('.'); this.BtnAct('⌫'); this.BtnEq() }
    }
    .width('100%')
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 8, y: 0 }))
      .animation({ duration: 200, curve: Curve.EaseInOut }))
  }

  // ==================== 科学键盘 (5 列 × 7 行, 含 sin/cos/tan/ln/log/常量) ====================
  @Builder ScientificKeypad() {
    Column() {
      Row() { this.BtnFunc('sin'); this.BtnFunc('cos'); this.BtnFunc('tan'); this.BtnFunc('ln'); this.BtnFunc('log') }
      Row() { this.BtnFunc('arcsi'); this.BtnFunc('arcco'); this.BtnFunc('arcta'); this.BtnConst('π'); this.BtnConst('e') }
      Row() { this.BtnActPct('AC'); this.BtnOpPct('%'); this.BtnOpPct('('); this.BtnOpPct(')'); this.BtnOpPct('÷') }
      Row() { this.BtnDig('7'); this.BtnDig('8'); this.BtnDig('9'); this.BtnOp('×') }
      Row() { this.BtnDig('4'); this.BtnDig('5'); this.BtnDig('6'); this.BtnOp('-') }
      Row() { this.BtnDig('1'); this.BtnDig('2'); this.BtnDig('3'); this.BtnOp('+') }
      Row() { this.BtnDig('0'); this.BtnOp('.'); this.BtnAct('⌫'); this.BtnEq() }
    }
    .width('100%')
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 8, y: 0 }))
      .animation({ duration: 200, curve: Curve.EaseInOut }))
  }

  // ==================== 程序员键盘 (5 列 × 5 行, BIN 0/1 复用数字按钮 + HEX A-F) ====================
  // 布局 (DEC 数字按钮 0-9 对 BIN/OCT/HEX 通用, HEX 字母 A-F 用 BtnHexLetter):
  //   行 1: AC  | %   | (   | )   | ÷
  //   行 2: 7   | 8   | 9   | A   | ×
  //   行 3: 4   | 5   | 6   | B   | -
  //   行 4: 1   | 2   | 3   | C   | +
  //   行 5: 0   | D   | E   | F   | =
  @Builder ProgrammerKeypad() {
    Column() {
      Row() { this.BtnActPct('AC'); this.BtnOpPct('%'); this.BtnOpPct('('); this.BtnOpPct(')'); this.BtnOpPct('÷') }
      Row() { this.BtnDig('7'); this.BtnDig('8'); this.BtnDig('9'); this.BtnHexLetter('A'); this.BtnOp('×') }
      Row() { this.BtnDig('4'); this.BtnDig('5'); this.BtnDig('6'); this.BtnHexLetter('B'); this.BtnOp('-') }
      Row() { this.BtnDig('1'); this.BtnDig('2'); this.BtnDig('3'); this.BtnHexLetter('C'); this.BtnOp('+') }
      Row() { this.BtnDig('0'); this.BtnHexLetter('D'); this.BtnHexLetter('E'); this.BtnHexLetter('F'); this.BtnEq() }
    }
    .width('100%')
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 8, y: 0 }))
      .animation({ duration: 200, curve: Curve.EaseInOut }))
  }

  /** 数字按钮 */
  @Builder BtnDig(l: string) { Text(l).fontSize(this.isLandscape ? 16 : 22).fontColor(this.getT1()).width('17%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(this.getBtnBg()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { this.onDigit(l) }) }

  /** 运算符按钮（含 %） */
  @Builder BtnOp(l: string) { Text(l).fontSize(this.isLandscape ? 14 : 20).fontColor(this.getBtnText()).width('17%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(this.getOp()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { this.onOp(l) }) }

  /** 科学函数按钮 */
  @Builder BtnFunc(l: string) { Text(l).fontSize(this.isLandscape ? 11 : 14).fontColor(this.getT1()).width('18%').height(this.isLandscape ? 30 : 46).textAlign(TextAlign.Center).backgroundColor(this.getFuncBg()).borderRadius(50).margin(this.isLandscape ? 1 : 3).onClick((): void => { this.onFunc(l) }) }

  /** 常量按钮 */
  @Builder BtnConst(l: string) { Text(l).fontSize(this.isLandscape ? 13 : 18).fontColor(this.getOp() === '#B4D2E4' ? '#4684E3' : this.getOp()).width('18%').height(this.isLandscape ? 30 : 46).textAlign(TextAlign.Center).backgroundColor(this.getFuncBg()).borderRadius(50).margin(this.isLandscape ? 1 : 3).onClick((): void => { this.onConst(l) }) }

  /** Issue #12: HEX 字母按钮 (A-F), 复用数字按钮样式 + Func 颜色 */
  @Builder BtnHexLetter(l: string) { Text(l).fontSize(this.isLandscape ? 13 : 18).fontColor(this.getT1()).width('17%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(this.getFuncBg()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { this.onDigit(l) }) }

  /** 动作按钮（AC/退格） */
  @Builder BtnAct(l: string) { Text(l).fontSize(this.isLandscape ? 14 : 20).fontColor(this.getBtnText()).width('17%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(l === 'AC' ? this.getClr() : this.getBtnBg()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { if (l === 'AC') this.onAC(); else this.onBS() }) }

  /** 等号按钮 */
  @Builder BtnEq() { Text('=').fontSize(this.isLandscape ? 18 : 24).fontWeight(FontWeight.Bold).fontColor(this.getBtnText()).width('22%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(this.getEq()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { this.onEquals() }) }

  /** 运算符按钮 - 5列布局版 */
  @Builder BtnOpPct(l: string) { Text(l).fontSize(this.isLandscape ? 14 : 20).fontColor(this.getBtnText()).width('17%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(this.getOp()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { this.onOp(l) }) }

  /** 动作按钮 - 5列布局版 */
  @Builder BtnActPct(l: string) { Text(l).fontSize(this.isLandscape ? 14 : 20).fontColor(this.getBtnText()).width('17%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(l === 'AC' ? this.getClr() : this.getBtnBg()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { if (l === 'AC') this.onAC(); else this.onBS() }) }

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
}
