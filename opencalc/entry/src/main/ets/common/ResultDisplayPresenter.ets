import { FractionResult, FractionUtil } from './FractionUtil'

export enum ResultDisplayMode {
  DECIMAL = 0,
  FRACTION = 1
}

export interface ResultDisplaySnapshot {
  mode: ResultDisplayMode
  hasResult: boolean
  rawValue: number
  decimalText: string
}

export class ResultDisplayPresenter {
  static toggleLabel(mode: ResultDisplayMode): string {
    return mode === ResultDisplayMode.DECIMAL ? '小数 · 切换为分数' : '分数 · 切换为小数'
  }

  static toggleAccessibilityText(mode: ResultDisplayMode): string {
    return mode === ResultDisplayMode.DECIMAL ? '当前显示小数，切换为分数' : '当前显示分数，切换为小数'
  }

  static nextMode(current: ResultDisplayMode, canToggle: boolean): ResultDisplayMode {
    if (!canToggle) {
      return current
    }
    return current === ResultDisplayMode.DECIMAL ? ResultDisplayMode.FRACTION : ResultDisplayMode.DECIMAL
  }

  static selectText(mode: ResultDisplayMode, rawValue: number, decimalText: string): string {
    if (mode === ResultDisplayMode.DECIMAL) {
      return decimalText
    }
    try {
      const fraction: FractionResult | null = FractionUtil.toFraction(rawValue)
      return fraction === null ? decimalText : FractionUtil.format(fraction)
    } catch (_error) {
      return decimalText
    }
  }
}

export class ResultDisplayLifecycle {
  static success(rawValue: number, decimalText: string): ResultDisplaySnapshot {
    return {
      mode: ResultDisplayMode.DECIMAL,
      hasResult: true,
      rawValue: rawValue,
      decimalText: decimalText
    }
  }

  static cleared(): ResultDisplaySnapshot {
    return {
      mode: ResultDisplayMode.DECIMAL,
      hasResult: false,
      rawValue: 0,
      decimalText: ''
    }
  }

  static toggle(current: ResultDisplaySnapshot, errorText: string): ResultDisplaySnapshot {
    return {
      mode: ResultDisplayPresenter.nextMode(current.mode, current.hasResult && errorText.length === 0),
      hasResult: current.hasResult,
      rawValue: current.rawValue,
      decimalText: current.decimalText
    }
  }

  static visible(current: ResultDisplaySnapshot): string {
    return ResultDisplayPresenter.selectText(current.mode, current.rawValue, current.decimalText)
  }
}
