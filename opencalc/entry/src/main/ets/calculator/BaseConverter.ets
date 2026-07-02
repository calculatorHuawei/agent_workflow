// OpenCalc — 进制转换工具
// Issue #22 程序员模式
// 纯逻辑工具类，零 ArkUI 依赖

import { NumberBase, ProgrammerDisplayState } from '../model/ModeModel'

/**
 * 进制转换工具类
 * - toBase / fromBase: 单向转换
 * - getRepresentations: 四进制联合
 * - isValidChar: 当前基数下字符合法性
 * - maxCharsFor: 64-bit 数字在某基数下最大长度
 */
export class BaseConverter {

  // ================================================================
  // 字符表（私有常量）
  // ================================================================

  private static readonly BIN_CHARS: string = '01'
  private static readonly OCT_CHARS: string = '01234567'
  private static readonly DEC_CHARS: string = '0123456789'
  private static readonly HEX_CHARS: string = '0123456789ABCDEF'

  // ================================================================
  // toBase — number → string
  // ================================================================

  /**
   * 把十进制数转成指定基数字符串
   * @param n 输入数字
   * @param base 目标基数
   * @returns 进制字符串（带负号 / 不带千分位 / 小数部分截断）
   */
  static toBase(n: number, base: NumberBase): string {
    if (n === 0) return '0'
    const radix: number = base.radix
    const isNeg: boolean = n < 0
    let abs: number = Math.abs(Math.trunc(n))
    if (abs > Number.MAX_SAFE_INTEGER) abs = Number.MAX_SAFE_INTEGER
    let result: string = ''
    while (abs > 0) {
      const r: number = abs % radix
      const ch: string = BaseConverter.charAt(radix, r)
      result = ch + result
      abs = Math.floor(abs / radix)
    }
    return isNeg ? '-' + result : result
  }

  // ================================================================
  // fromBase — string → number
  // ================================================================

  /**
   * 把指定基数字符串解析为十进制数
   * @param s 进制字符串（不区分大小写）
   * @param base 源基数
   * @returns 十进制数；解析失败返回 NaN
   */
  static fromBase(s: string, base: NumberBase): number {
    if (s === null || s === undefined) return NaN
    const trimmed: string = s.trim()
    if (trimmed.length === 0) return NaN
    const radix: number = base.radix
    let isNeg: boolean = false
    let i: number = 0
    if (trimmed.charAt(0) === '-') { isNeg = true; i = 1 }
    else if (trimmed.charAt(0) === '+') { i = 1 }
    let result: number = 0
    const chars: string = BaseConverter.charsFor(base)
    for (; i < trimmed.length; i++) {
      const ch: string = trimmed.charAt(i).toUpperCase()
      const idx: number = chars.indexOf(ch)
      if (idx < 0) return NaN
      result = result * radix + idx
      if (result > Number.MAX_SAFE_INTEGER) return NaN
    }
    return isNeg ? -result : result
  }

  // ================================================================
  // getRepresentations — 四进制联合
  // ================================================================

  /**
   * 把一个十进制数映射到四进制字符串
   * @param n 输入
   */
  static getRepresentations(n: number): ProgrammerDisplayState {
    const state: ProgrammerDisplayState = new ProgrammerDisplayState()
    if (!Number.isFinite(n)) {
      state.bin = '—'; state.oct = '—'; state.dec = '—'; state.hex = '—'
      state.hasOverflow = false
      return state
    }
    state.hasOverflow = Math.abs(n) > Number.MAX_SAFE_INTEGER
    state.bin = BaseConverter.toBase(n, NumberBase.BIN)
    state.oct = BaseConverter.toBase(n, NumberBase.OCT)
    state.dec = BaseConverter.toBase(n, NumberBase.DEC)
    state.hex = BaseConverter.toBase(n, NumberBase.HEX)
    return state
  }

  // ================================================================
  // isValidChar — 当前基数下字符合法性
  // ================================================================

  /**
   * 判断字符在指定基数下是否合法
   * @param ch 单字符
   * @param base 基数
   */
  static isValidChar(ch: string, base: NumberBase): boolean {
    if (ch === null || ch === undefined || ch.length === 0) return false
    const chars: string = BaseConverter.charsFor(base)
    return chars.indexOf(ch.toUpperCase()) !== -1
  }

  // ================================================================
  // maxCharsFor — 64-bit 数字最大字符长度
  // ================================================================

  /**
   * 64-bit 数字在指定基数下需要的最大字符数（含负号则 +1）
   * BIN: 64, OCT: 22, DEC: 20, HEX: 16
   */
  static maxCharsFor(base: NumberBase): number {
    const radix: number = base.radix
    if (radix === 2) return 64
    if (radix === 8) return 22  // ceil(64 * log(2) / log(8))
    if (radix === 10) return 20
    if (radix === 16) return 16
    return 64
  }

  // ================================================================
  // 私有辅助
  // ================================================================

  private static charsFor(base: NumberBase): string {
    const radix: number = base.radix
    if (radix === 2) return BaseConverter.BIN_CHARS
    if (radix === 8) return BaseConverter.OCT_CHARS
    if (radix === 10) return BaseConverter.DEC_CHARS
    if (radix === 16) return BaseConverter.HEX_CHARS
    return BaseConverter.DEC_CHARS
  }

  private static charAt(radix: number, r: number): string {
    if (radix === 2) return BaseConverter.BIN_CHARS.charAt(r)
    if (radix === 8) return BaseConverter.OCT_CHARS.charAt(r)
    if (radix === 10) return BaseConverter.DEC_CHARS.charAt(r)
    if (radix === 16) return BaseConverter.HEX_CHARS.charAt(r)
    return BaseConverter.DEC_CHARS.charAt(r)
  }
}
