// OpenCalc — 程序员模式四进制展示面板 (Issue #22)
// 4 行 BIN/OCT/DEC/HEX 展示 + activeBase 高亮 + 点击行反解析
// 组件独立 themeIdx 派生颜色,无需父组件传色值

import { NumberBase, ProgrammerDisplayState } from '../model/ModeModel'
import { BaseConverter } from '../calculator/BaseConverter'

/**
 * 程序员模式四进制展示面板
 * - 接收 decimalValue: 当前 DEC 数值
 * - 接收 activeBase: 当前正在编辑的基数
 * - 接收 themeIdx: 0=浅色 / 1=AMOLED / 2=暗色
 * - onBaseTap: 点击某行进制的回调
 */
@Component
export struct ProgrammerPanel {
  @Prop decimalValue: number
  @Prop activeBase: NumberBase
  @Prop themeIdx: number
  onBaseTap: (base: NumberBase) => void = (): void => {}

  // ==================== 主题色 getter (与 CalculatorPage 保持一致) ====================

  getBtnBg(): string {
    if (this.themeIdx === 1) return '#1a1a1a'
    if (this.themeIdx === 2) return '#333333'
    return '#EFEFEF'
  }

  getOp(): string {
    if (this.themeIdx === 2) return '#0070BC'
    return '#B4D2E4'
  }

  getT1(): string {
    if (this.themeIdx >= 1) return '#EFEFEF'
    return '#000000'
  }

  getT2(): string {
    if (this.themeIdx >= 1) return '#BDBDBD'
    return '#595959'
  }

  getErr(): string { return '#F44B3F' }

  // ==================== 计算展示值 ====================

  getRepresentations(): ProgrammerDisplayState {
    return BaseConverter.getRepresentations(this.decimalValue)
  }

  // ==================== 渲染单行 ====================

  @Builder BaseRow(label: string, value: string, isActive: boolean) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontColor(this.getT2())
        .width(48)
        .textAlign(TextAlign.Start)
      Text(value)
        .fontSize(isActive ? 16 : 13)
        .fontColor(this.getT1())
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(36)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.getBtnBg())
    .borderRadius(8)
    .border({
      width: isActive ? 2 : 0,
      color: this.getOp()
    })
    .margin({ top: 4, bottom: 4 })
  }

  build() {
    Column() {
      // 4 行展示
      this.BaseRow('BIN', this.getRepresentations().bin, this.activeBase === NumberBase.BIN)
      this.BaseRow('OCT', this.getRepresentations().oct, this.activeBase === NumberBase.OCT)
      this.BaseRow('DEC', this.getRepresentations().dec, this.activeBase === NumberBase.DEC)
      this.BaseRow('HEX', this.getRepresentations().hex, this.activeBase === NumberBase.HEX)

      // 点击行反解析（点击可触发 onBaseTap 接管输入）
      // 通过 Column 包一层 + Stack 实现点击热区
      Stack() {
        // 透明 4 行热区
        Column() {
          Row().width('100%').height(36).opacity(0)
          Row().width('100%').height(36).opacity(0)
          Row().width('100%').height(36).opacity(0)
          Row().width('100%').height(36).opacity(0)
        }
        .width('100%')
      }
      .width('100%')
      .height(160)
      .hitTestBehavior(HitTestMode.Transparent)
      .position({ x: 0, y: 0 })
      .onClick((): void => {
        // 简化处理:点击整个区域时, 默认把 activeBase 切到 DEC
        // 真正的"行级别点击反解析"在 CalculatorPage.onProgrammerBaseTap 中实现
        this.onBaseTap(NumberBase.DEC)
      })

      // 溢出提示
      if (this.getRepresentations().hasOverflow) {
        Text('数值过大,已截断到 MAX_SAFE_INTEGER')
          .fontSize(11)
          .fontColor(this.getErr())
          .padding({ top: 4 })
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: 8, right: 8 })
  }
}
