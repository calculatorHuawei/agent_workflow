// OpenCalc — 进制转换工具
// Issue #12 程序员模式 - DEC ↔ BIN/OCT/HEX 转换
// 行为契约：
//   - NaN / Infinity 返回 "-"
//   - 0 返回 "0"
//   - 非 DEC 进制截断小数（Math.trunc），负数加 "-" 前缀
//   - HEX 输出 uppercase（A-F）
//   - DEC 保留原始数值（含小数）
//   - withPrefix 为非 DEC 进制添加 0b/0o/0x 前缀
import { NumberBase } from '../model/Models'

export class BaseConverter {
  /**
   * 将数值转换为指定进制的字符串表示
   * @param value 待转换数值
   * @param base 目标进制（DEC/BIN/OCT/HEX）
   * @returns 进制字符串；NaN/Infinity 返回 "-"
   */
  static convert(value: number, base: NumberBase): string {
    // 边界处理：NaN / Infinity / -Infinity
    if (!Number.isFinite(value) || Number.isNaN(value)) {
      return '-'
    }

    // 0 / -0 特殊处理
    if (value === 0) {
      return '0'
    }

    const negative: boolean = value < 0

    if (base === NumberBase.DEC) {
      // DEC 保留小数部分
      const absStr: string = Math.abs(value).toString()
      return negative ? '-' + absStr : absStr
    }

    // 非 DEC 进制：截断小数（Math.trunc），负数加前缀
    const intPart: number = Math.trunc(Math.abs(value))
    const radix: number = base === NumberBase.BIN ? 2
      : base === NumberBase.OCT ? 8
      : 16
    const converted: string = intPart.toString(radix).toUpperCase()
    return negative ? '-' + converted : converted
  }

  /**
   * 在 convert 基础上添加进制前缀（仅非 DEC）
   * DEC:  "255"
   * BIN:  "0b11111111"
   * OCT:  "0o377"
   * HEX:  "0xFF"
   * 负数: 前缀在 - 之后（如 -0xFF，不是 0x-FF）
   * @param value 待转换数值
   * @param base 目标进制
   * @returns 带前缀的进制字符串
   */
  static withPrefix(value: number, base: NumberBase): string {
    if (!Number.isFinite(value) || Number.isNaN(value)) {
      return '-'
    }
    if (base === NumberBase.DEC) {
      return BaseConverter.convert(value, base)
    }

    const negative: boolean = value < 0
    const absVal: number = Math.abs(value)
    const radix: number = base === NumberBase.BIN ? 2
      : base === NumberBase.OCT ? 8
      : 16
    const prefix: string = base === NumberBase.BIN ? '0b'
      : base === NumberBase.OCT ? '0o'
      : '0x'
    const body: string = Math.trunc(absVal).toString(radix).toUpperCase()
    return negative ? '-' + prefix + body : prefix + body
  }
}