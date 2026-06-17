// OpenCalc — 模式与进制数据模型
// Issue #22 程序员模式
// 纯 ArkTS 类型，零 ArkUI 依赖，便于单元测试

import { BaseConverter } from '../calculator/BaseConverter'

/** 数字基数（对象形式，附 radix 字段；避免 ArkTS enum 限制） */
export class NumberBase {
  static readonly BIN: NumberBase = new NumberBase(2, 'BIN', '01')
  static readonly OCT: NumberBase = new NumberBase(8, 'OCT', '01234567')
  static readonly DEC: NumberBase = new NumberBase(10, 'DEC', '0123456789')
  static readonly HEX: NumberBase = new NumberBase(16, 'HEX', '0123456789ABCDEF')

  /** 静态取值列表（便于遍历） */
  static readonly ALL: NumberBase[] = [NumberBase.BIN, NumberBase.OCT, NumberBase.DEC, NumberBase.HEX]

  private constructor(radix: number, label: string, chars: string) {
    this.radix = radix
    this.label = label
    this.chars = chars
  }

  readonly radix: number
  readonly label: string
  readonly chars: string
}

/** 计算器 UI 模式 */
export enum CalculatorMode {
  STANDARD = 0,
  PROGRAMMER = 1
}

/**
 * 程序员模式下四进制实时表示
 * bin/oct/dec/hex 均为格式化字符串（带负号，不带千分位）
 * hasOverflow: true 当原值超过 Number.MAX_SAFE_INTEGER
 */
export class ProgrammerDisplayState {
  bin: string = ''
  oct: string = ''
  dec: string = ''
  hex: string = ''
  hasOverflow: boolean = false

  /** 委托给 BaseConverter */
  static fromValue(n: number): ProgrammerDisplayState {
    return BaseConverter.getRepresentations(n)
  }
}
