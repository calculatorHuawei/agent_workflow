// OpenCalc — 主计算器页面（横竖屏自适应 + Android 配色 + 程序员模式 Issue #4）
// 移植自：MainActivity.kt（1447行）
import { promptAction } from '@kit.ArkUI'
import { pasteboard } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { Expression } from '../calculator/Expression'
import { CalcEngine } from '../calculator/Calculator'
import { NumberFormatter } from '../calculator/NumberFormatter'
import { BaseConverter } from '../calculator/BaseConverter'
import { NumberingSystem, HistoryItem, CalculatorMode, NumberBase } from '../model/Models'
import { ErrorFlags } from '../model/ErrorFlags'
import { PreferencesStore } from '../preferences/PreferencesStore'

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

  // ==================== Issue #4 程序员模式状态 ====================
  @State currentMode: CalculatorMode = CalculatorMode.BASIC
  @State currentBase: NumberBase = NumberBase.DEC
  private lastModeChangeTime: number = 0  // 模式切换节流

  // ==================== 偏好设置状态 ====================
  @State vibrateOn: boolean = true
  @State preventSleep: boolean = false
  @State radianMode: boolean = false
  @State themeIdx: number = 0
  @State defaultModePref: number = 0  // 默认模式偏好
  @State defaultBasePref: number = 10 // 默认进制偏好

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
    this.scientific = (await this.prefs.getScientificModeDefault()) === 1
    // Issue #4: 读取程序员模式 + 默认进制
    this.defaultModePref = await this.prefs.getProgrammerModeDefault()
    this.currentMode = this.defaultModePref as CalculatorMode
    this.defaultBasePref = await this.prefs.getDefaultBase()
    this.currentBase = this.defaultBasePref as NumberBase
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
    else if (key === 'programmerMode') await this.prefs.setProgrammerModeDefault(value as number)
    else if (key === 'defaultBase') await this.prefs.setDefaultBase(value as number)
  }

  // ==================== 按钮事件 ====================
  onDigit(d: string): void {
    // Issue #4: 程序员模式下校验字符合法性
    if (this.currentMode === CalculatorMode.PROGRAMMER && !this.isCharValid(d)) {
      return
    }
    this.expression = this.expression + d
    this.errorMsg = ''
  }
  onOp(op: string): void { this.expression = this.expression + op; this.errorMsg = '' }
  onFunc(f: string): void { this.expression = this.expression + f + '('; this.errorMsg = '' }
  onConst(c: string): void { this.expression = this.expression + c; this.errorMsg = '' }
  onBS(): void { if (this.expression.length > 0) this.expression = this.expression.substring(0, this.expression.length - 1) }
  onAC(): void { this.expression = ''; this.result = ''; this.errorMsg = ''; ErrorFlags.reset() }

  // ==================== Issue #4 程序员模式事件 ====================

  /** HEX 字母按钮（A-F） */
  onLetter(ch: string): void {
    if (this.currentMode !== CalculatorMode.PROGRAMMER) return
    if (this.currentBase !== NumberBase.HEX) return
    if (!BaseConverter.isValidChar(ch, NumberBase.HEX)) return
    this.expression = this.expression + ch
    this.errorMsg = ''
  }

  /**
   * 字符合法性校验（程序员模式专用）
   * 非程序员模式一律返回 true（基础/科学模式不做限制）
   */
  isCharValid(ch: string): boolean {
    if (this.currentMode !== CalculatorMode.PROGRAMMER) return true
    // 操作符和括号始终合法
    if ('+-×÷().'.indexOf(ch) >= 0) return true
    return BaseConverter.isValidChar(ch, this.currentBase)
  }

  /**
   * 模式切换（三态循环 + 200ms 节流 + 动画 + 持久化）
   */
  onModeChange(): void {
    const now: number = Date.now()
    if (now - this.lastModeChangeTime < 200) return
    this.lastModeChangeTime = now
    const newMode: number = (this.currentMode + 1) % 3
    this.currentMode = newMode as CalculatorMode
    console.log(`modeChanged: ${(newMode + 2) % 3} → ${newMode}`)
    // 持久化（失败静默）
    this.savePref('programmerMode', newMode).catch((e: Error): void => {
      console.warn('save programmerMode failed: ' + e.message)
    })
  }

  /**
   * 进制切换（DEC/BIN/OCT/HEX）+ 表达式合法性校验 + 持久化
   */
  onBaseChange(newBase: NumberBase): void {
    // 校验当前表达式在 newBase 下是否合法
    if (this.expression.length > 0 && !BaseConverter.isValidExpression(this.expression, newBase)) {
      promptAction.showToast({ message: '当前进制不支持该表达式' })
      return
    }
    const oldBase: NumberBase = this.currentBase
    this.currentBase = newBase
    console.log(`baseChanged: ${oldBase} → ${newBase}`)
    this.savePref('defaultBase', newBase).catch((e: Error): void => {
      console.warn('save defaultBase failed: ' + e.message)
    })
  }

  /**
   * 当前进制行高亮判断
   */
  isCurrentBase(base: NumberBase): boolean {
    return this.currentBase === base
  }

  /**
   * 当前进制行高亮背景色（复用 getOp）
   */
  getBaseHighlightBg(): string {
    return this.getOp()
  }

  // ==================== 4 行进制显示数据源 ====================

  /**
   * 按当前表达式计算 DEC 数值（程序员模式专用）
   * 表达式为空时返回 0
   */
  getDecValue(): number {
    if (this.expression.length === 0) return 0
    const v: number = BaseConverter.fromBase(this.expression, this.currentBase)
    return Number.isNaN(v) ? 0 : v
  }

  getDecDisplay(): string {
    if (this.expression.length === 0) return '0'
    return BaseConverter.toBase(this.getDecValue(), NumberBase.DEC)
  }

  getBinDisplay(): string {
    if (this.expression.length === 0) return '0'
    const v: number = this.getDecValue()
    return BaseConverter.toBase(v, NumberBase.BIN)
  }

  getOctDisplay(): string {
    if (this.expression.length === 0) return '0'
    const v: number = this.getDecValue()
    return BaseConverter.toBase(v, NumberBase.OCT)
  }

  getHexDisplay(): string {
    if (this.expression.length === 0) return '0'
    const v: number = this.getDecValue()
    return BaseConverter.toBase(v, NumberBase.HEX)
  }

  onEquals(): void {
    if (this.expression.length === 0) return
    // Issue #4: 程序员模式按 currentBase 解读表达式，结果仅显示 DEC
    if (this.currentMode === CalculatorMode.PROGRAMMER) {
      const decValue: number = BaseConverter.fromBase(this.expression, this.currentBase)
      if (Number.isNaN(decValue)) {
        this.errorMsg = '表达式无法解读'
        return
      }
      const fmt: string = NumberFormatter.format(decValue.toString(), '.', ',', NumberingSystem.INTERNATIONAL)
      this.result = fmt
      this.errorMsg = ''
      const item: HistoryItem = { id: this.nextId, expression: this.expression, result: fmt, timestamp: Date.now() }
      this.nextId = this.nextId + 1
      const nh: HistoryItem[] = [item]
      for (let i: number = 0; i < this.history.length; i++) nh.push(this.history[i])
      this.history = nh
      if (this.prefs) this.prefs.setHistory(this.history)
      return
    }
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
          .animation({ duration: 200, curve: Curve.EaseInOut })
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
        .animation({ duration: 200, curve: Curve.EaseInOut })
      }
      if (this.showSettings) this.SettingsPanel()
      if (this.showAbout) this.AboutPanel()
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
      // Issue #4: 程序员模式渲染 BaseConversionPanel（4 行）
      if (this.currentMode === CalculatorMode.PROGRAMMER) {
        this.BaseConversionPanel()
      } else {
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
      }
    }
    .width('100%').padding(this.isLandscape ? { top: 8, bottom: 2 } : { top: 24, bottom: 8 })
    .gesture(LongPressGesture().onAction((): void => { this.onCopy() }))
  }

  // ==================== Issue #4 BaseConversionPanel（4 行进制显示） ====================
  @Builder BaseConversionPanel() {
    Column() {
      // DEC 行
      Row() {
        Text('DEC').fontSize(12).fontColor(this.getT2()).width(40)
        Text(this.getDecDisplay()).fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.getT1())
          .layoutWeight(1).textAlign(TextAlign.End)
      }
      .width('100%').height(40).padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .backgroundColor(this.isCurrentBase(NumberBase.DEC) ? this.getBaseHighlightBg() : Color.Transparent)
      .borderRadius(8)

      // BIN 行
      Row() {
        Text('BIN').fontSize(12).fontColor(this.getT2()).width(40)
        Text(this.getBinDisplay()).fontSize(18).fontColor(this.getT2())
          .layoutWeight(1).textAlign(TextAlign.End)
      }
      .width('100%').height(32).padding({ left: 12, right: 12, top: 2, bottom: 2 })
      .backgroundColor(this.isCurrentBase(NumberBase.BIN) ? this.getBaseHighlightBg() : Color.Transparent)
      .borderRadius(8)

      // OCT 行
      Row() {
        Text('OCT').fontSize(12).fontColor(this.getT2()).width(40)
        Text(this.getOctDisplay()).fontSize(18).fontColor(this.getT2())
          .layoutWeight(1).textAlign(TextAlign.End)
      }
      .width('100%').height(32).padding({ left: 12, right: 12, top: 2, bottom: 2 })
      .backgroundColor(this.isCurrentBase(NumberBase.OCT) ? this.getBaseHighlightBg() : Color.Transparent)
      .borderRadius(8)

      // HEX 行
      Row() {
        Text('HEX').fontSize(12).fontColor(this.getT2()).width(40)
        Text(this.getHexDisplay()).fontSize(18).fontColor(this.getT2())
          .layoutWeight(1).textAlign(TextAlign.End)
      }
      .width('100%').height(32).padding({ left: 12, right: 12, top: 2, bottom: 2 })
      .backgroundColor(this.isCurrentBase(NumberBase.HEX) ? this.getBaseHighlightBg() : Color.Transparent)
      .borderRadius(8)
    }
    .width('100%').padding({ top: 8, bottom: 8 })
  }

  // ==================== 模式切换栏（仅竖屏显示） ====================
  @Builder ToggleRow() {
    Row() {
      // Issue #4: 三态循环 基础/科学/程序员
      Text(this.getModeLabel()).fontSize(12).fontColor(this.getOp())
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .border({ width: 1, color: this.getOp(), radius: 8 })
        .onClick((): void => { this.onModeChange() })
      Blank()
      Text(this.showHistory ? '▲ 历史' : '▼ 历史').fontSize(12).fontColor(this.getT2()).padding(8)
        .onClick((): void => { this.showHistory = !this.showHistory })
      Text('⚙').fontSize(16).fontColor(this.getT2()).padding(8)
        .onClick((): void => { this.showSettings = true })
    }
    .width('100%').padding({ left: 16, right: 16, bottom: 4 })
  }

  /** Issue #4: 当前模式文字（基础/科学/程序员） */
  getModeLabel(): string {
    if (this.currentMode === CalculatorMode.BASIC) return '基础'
    if (this.currentMode === CalculatorMode.SCIENTIFIC) return '科学'
    return '程序员'
  }

  // ==================== Issue #4 BaseSwitcher（DEC/BIN/OCT/HEX 切换器） ====================
  @Builder BaseSwitcher() {
    Row() {
      this.BtnBase('DEC', NumberBase.DEC)
      this.BtnBase('BIN', NumberBase.BIN)
      this.BtnBase('OCT', NumberBase.OCT)
      this.BtnBase('HEX', NumberBase.HEX)
    }
    .width('100%').padding({ left: 8, right: 8, top: 4, bottom: 4 })
  }

  /** 进制切换按钮 */
  @Builder BtnBase(label: string, base: NumberBase) {
    Text(label).fontSize(14).fontWeight(FontWeight.Bold)
      .fontColor(this.isCurrentBase(base) ? this.getBtnText() : this.getT1())
      .width('23%').height(32).textAlign(TextAlign.Center)
      .backgroundColor(this.isCurrentBase(base) ? this.getOp() : this.getBtnBg())
      .borderRadius(20).margin(2)
      .onClick((): void => { this.onBaseChange(base) })
  }

  // ==================== 按钮网格 ====================
  @Builder ButtonGrid() {
    Column() {
      // Issue #4: 程序员模式渲染 ProgrammerKeypad
      if (this.currentMode === CalculatorMode.PROGRAMMER) {
        this.ProgrammerKeypad()
      } else {
        if (this.scientific) {
          Row() { this.BtnFunc('sin'); this.BtnFunc('cos'); this.BtnFunc('tan'); this.BtnFunc('ln'); this.BtnFunc('log') }
          Row() { this.BtnFunc('arcsi'); this.BtnFunc('arcco'); this.BtnFunc('arcta'); this.BtnConst('π'); this.BtnConst('e') }
        }
        Row() { this.BtnActPct('AC'); this.BtnOpPct('%'); this.BtnOpPct('('); this.BtnOpPct(')'); this.BtnOpPct('÷') }
        Row() { this.BtnDig('7'); this.BtnDig('8'); this.BtnDig('9'); this.BtnOp('×') }
        Row() { this.BtnDig('4'); this.BtnDig('5'); this.BtnDig('6'); this.BtnOp('-') }
        Row() { this.BtnDig('1'); this.BtnDig('2'); this.BtnDig('3'); this.BtnOp('+') }
        Row() { this.BtnDig('0'); this.BtnOp('.'); this.BtnAct('⌫'); this.BtnEq() }
      }
    }
    .width('100%').padding({ left: 8, right: 8 }).layoutWeight(this.isLandscape ? 0 : 1)
  }

  // ==================== Issue #4 ProgrammerKeypad（程序员键盘） ====================
  @Builder ProgrammerKeypad() {
    Column() {
      // 行 1: 进制切换器
      this.BaseSwitcher()
      // 行 2: HEX 字母按钮（A-F 仅 HEX 显示；其他进制隐藏）
      if (this.currentBase === NumberBase.HEX) {
        Row() {
          this.BtnAlpha('A')
          this.BtnAlpha('B')
          this.BtnAlpha('C')
          this.BtnAlpha('D')
          this.BtnAlpha('E')
          this.BtnAlpha('F')
        }
        .width('100%').padding({ left: 8, right: 8 })
      }
      // 行 3-6: 数字 + 运算符（按当前进制过滤字符可用性）
      Row() { this.BtnDigFiltered('7'); this.BtnDigFiltered('8'); this.BtnDigFiltered('9'); this.BtnOp('÷') }
      Row() { this.BtnDigFiltered('4'); this.BtnDigFiltered('5'); this.BtnDigFiltered('6'); this.BtnOp('×') }
      Row() { this.BtnDigFiltered('1'); this.BtnDigFiltered('2'); this.BtnDigFiltered('3'); this.BtnOp('-') }
      Row() { this.BtnDigFiltered('0'); this.BtnOpPct('.'); this.BtnAct('⌫'); this.BtnEq() }
    }
    .width('100%')
  }

  /** 程序员模式数字按钮（按 currentBase 过滤） */
  @Builder BtnDigFiltered(d: string) {
    Text(d).fontSize(this.isLandscape ? 16 : 22)
      .fontColor(this.isCharValid(d) ? this.getT1() : this.getT2())
      .opacity(this.isCharValid(d) ? 1.0 : 0.3)
      .width('23%').height(this.isLandscape ? 36 : 50).textAlign(TextAlign.Center)
      .backgroundColor(this.getBtnBg()).borderRadius(50).margin(this.isLandscape ? 1 : 3)
      .onClick((): void => { this.onDigit(d) })
  }

  /** HEX 字母按钮 */
  @Builder BtnAlpha(ch: string) {
    Text(ch).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.getOp())
      .width('15%').height(this.isLandscape ? 36 : 50).textAlign(TextAlign.Center)
      .backgroundColor(this.getFuncBg()).borderRadius(50).margin(this.isLandscape ? 1 : 3)
      .onClick((): void => { this.onLetter(ch) })
  }

  /** 数字按钮 */
  @Builder BtnDig(l: string) { Text(l).fontSize(this.isLandscape ? 16 : 22).fontColor(this.getT1()).width('17%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(this.getBtnBg()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { this.onDigit(l) }) }

  /** 运算符按钮（含 %） */
  @Builder BtnOp(l: string) { Text(l).fontSize(this.isLandscape ? 14 : 20).fontColor(this.getBtnText()).width('17%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(this.getOp()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { this.onOp(l) }) }

  /** 科学函数按钮 */
  @Builder BtnFunc(l: string) { Text(l).fontSize(this.isLandscape ? 11 : 14).fontColor(this.getT1()).width('18%').height(this.isLandscape ? 30 : 46).textAlign(TextAlign.Center).backgroundColor(this.getFuncBg()).borderRadius(50).margin(this.isLandscape ? 1 : 3).onClick((): void => { this.onFunc(l) }) }

  /** 常量按钮 */
  @Builder BtnConst(l: string) { Text(l).fontSize(this.isLandscape ? 13 : 18).fontColor(this.getOp() === '#B4D2E4' ? '#4684E3' : this.getOp()).width('18%').height(this.isLandscape ? 30 : 46).textAlign(TextAlign.Center).backgroundColor(this.getFuncBg()).borderRadius(50).margin(this.isLandscape ? 1 : 3).onClick((): void => { this.onConst(l) }) }

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
        // Issue #4: 默认模式 + 默认进制
        ListItem() { this.DefaultModeItem() }
        ListItem() { this.DefaultBaseItem() }
        ListItem() {
          Row() { Text('关于 OpenCalc').fontSize(15).fontColor(this.getT2()); Blank(); Text('>').fontColor(this.getT2()) }
          .width('100%').padding(12).onClick((): void => { this.showSettings = false; this.showAbout = true })
        }
      }
    }
    .width('85%').backgroundColor(this.getPanelBg()).borderRadius(16)
  }

  // ==================== Issue #4 SettingsPanel 项：默认模式 ====================
  @Builder DefaultModeItem() {
    Row() {
      Text('默认模式').fontSize(15).fontColor(this.getT1()).layoutWeight(1)
      Row() {
        this.RadioItem('基础', CalculatorMode.BASIC, this.defaultModePref)
        this.RadioItem('科学', CalculatorMode.SCIENTIFIC, this.defaultModePref)
        this.RadioItem('程序员', CalculatorMode.PROGRAMMER, this.defaultModePref)
      }
    }.width('100%').padding(12)
  }

  // ==================== Issue #4 SettingsPanel 项：默认进制 ====================
  @Builder DefaultBaseItem() {
    Row() {
      Text('默认进制').fontSize(15).fontColor(this.getT1()).layoutWeight(1)
      Row() {
        this.RadioBaseItem('DEC', NumberBase.DEC, this.defaultBasePref)
        this.RadioBaseItem('BIN', NumberBase.BIN, this.defaultBasePref)
        this.RadioBaseItem('OCT', NumberBase.OCT, this.defaultBasePref)
        this.RadioBaseItem('HEX', NumberBase.HEX, this.defaultBasePref)
      }
    }.width('100%').padding(12)
  }

  /** 单选按钮（模式） */
  @Builder RadioItem(label: string, value: number, current: number) {
    Text(label).fontSize(11).fontColor(current === value ? '#000' : this.getT2())
      .backgroundColor(current === value ? this.getOp() : (this.themeIdx >= 1 ? '#555' : '#DDD'))
      .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(8).margin({ left: 2 })
      .onClick((): void => {
        this.defaultModePref = value
        this.savePref('programmerMode', value)
      })
  }

  /** 单选按钮（进制） */
  @Builder RadioBaseItem(label: string, value: number, current: number) {
    Text(label).fontSize(11).fontColor(current === value ? '#000' : this.getT2())
      .backgroundColor(current === value ? this.getOp() : (this.themeIdx >= 1 ? '#555' : '#DDD'))
      .padding({ left: 6, right: 6, top: 4, bottom: 4 }).borderRadius(8).margin({ left: 2 })
      .onClick((): void => {
        this.defaultBasePref = value
        this.savePref('defaultBase', value)
      })
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
