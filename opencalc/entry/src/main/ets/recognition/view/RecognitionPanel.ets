import { RecognitionError, RecognitionState, ValidationError } from '../model/RecognitionModels'

@Component
export struct RecognitionPanel {
  @Prop state: RecognitionState
  @Prop candidate: string
  @Prop validationError: ValidationError
  @Prop error: RecognitionError
  @Prop panelBackground: string
  @Prop primaryText: string
  @Prop secondaryText: string
  @Prop accentColor: string
  onCandidateChange: (value: string) => void = (_value: string): void => {}
  onConfirm: () => void = (): void => {}
  onRetry: () => void = (): void => {}
  onClose: () => void = (): void => {}

  private title(): string {
    if (this.state === RecognitionState.REQUESTING_PERMISSION) return '正在申请相机权限'
    if (this.state === RecognitionState.CAPTURING) return '准备拍照'
    if (this.state === RecognitionState.RECOGNIZING) return '正在离线识别'
    if (this.state === RecognitionState.REVIEWING_VALID || this.state === RecognitionState.REVIEWING_INVALID) return '确认手写算式'
    return '无法完成识别'
  }

  private message(): string {
    if (this.error === RecognitionError.PERMISSION_DENIED) return '相机权限被拒绝，可重试授权或继续手工输入。'
    if (this.error === RecognitionError.PERMISSION_PERMANENTLY_DENIED) return '相机权限已被永久拒绝，请在系统设置中授权。'
    if (this.error === RecognitionError.EMPTY_RESULT) return '没有识别到算式，请重拍。'
    if (this.error === RecognitionError.TIMEOUT) return '识别超过 5 秒，请重拍。'
    if (this.error !== RecognitionError.NONE) return '拍照或识别失败，请重拍。'
    if (this.validationError === ValidationError.TOO_LONG) return '算式过长，最多 128 个字符。'
    if (this.validationError === ValidationError.UNSUPPORTED_CHARACTER) return '包含不支持字符，仅支持数字、四则运算和括号。'
    if (this.validationError === ValidationError.SYNTAX) return '算式语法不完整，请修改后确认。'
    return '识别结果不会自动计算，请检查并确认填入。'
  }

  build() {
    Column() {
      Row() {
        Text(this.title()).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.primaryText)
        Blank()
        Text('✕').fontSize(20).fontColor(this.secondaryText).accessibilityText('关闭拍照识别')
          .onClick((): void => { this.onClose() })
      }.width('100%')
      Text(this.message()).fontSize(14).fontColor(this.secondaryText).width('100%').margin({ top: 12 })
      if (this.state === RecognitionState.REVIEWING_VALID || this.state === RecognitionState.REVIEWING_INVALID) {
        TextInput({ text: this.candidate, placeholder: '请编辑识别结果' })
          .width('100%').margin({ top: 16 }).fontSize(18)
          .onChange((value: string): void => { this.onCandidateChange(value) })
      }
      if (this.state === RecognitionState.ERROR || this.state === RecognitionState.REVIEWING_VALID ||
        this.state === RecognitionState.REVIEWING_INVALID) {
        Row() {
          Button('重拍').layoutWeight(1).margin({ right: 8 }).accessibilityText('重新拍照')
            .onClick((): void => { this.onRetry() })
          if (this.state === RecognitionState.REVIEWING_VALID) {
            Button('确认填入').layoutWeight(1).backgroundColor(this.accentColor).accessibilityText('确认填入算式')
              .onClick((): void => { this.onConfirm() })
          }
        }.width('100%').margin({ top: 16 })
      }
    }
    .width('88%').padding(20).backgroundColor(this.panelBackground).borderRadius(16)
  }
}
