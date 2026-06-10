// OpenCalc — 进制转换工具类
// 实现 toBase / fromBase / isValidChar / formatHex / convert / isOverflow / isValidExpression
// 纯逻辑无 UI 依赖，便于单元测试
import { NumberBase } from '../model/Models'

/**
 * 进制转换工具类
 * 提供 toBase / fromBase / isValidChar / formatHex / convert / isOverflow / isValidExpression
 * 所有方法为 static，无状态依赖，无 UI 依赖
 */
export class BaseConverter {
  /** 安全整数上限（IEEE 754） */
  private static readonly SAFE_MAX: number = 9007199254740992  // 2^53

  /**
   * 十进制数转任意进制字符串
   * @param value 十进制数
   * @param base 目标基数（NumberBase）
   * @returns 进制字符串（HEX 大写），溢出返回 "Overflow"，NaN 返回 "Invalid"
   */
  static toBase(value: number, base: NumberBase): string {
    if (Number.isNaN(value)) return 'Invalid'
    if (BaseConverter.isOverflow(value)) return 'Overflow'
    const negative: boolean = value < 0
    const absValue: number = Math.abs(value)
    if (absValue === 0) return '0'
    let result: string = absValue.toString(base)
    if (base === NumberBase.HEX) {
      result = BaseConverter.formatHex(result)
    }
    return negative ? '-' + result : result
  }

  /**
   * 任意进制字符串转十进制数
   * @param str 源进制字符串
   * @param base 源基数
   * @returns 十进制数（解析失败返回 NaN）
   */
  static fromBase(str: string, base: NumberBase): number {
    return parseInt(str, base)
  }

  /**
   * 判断字符是否对当前进制合法
   * @param ch 单字符
   * @param base 当前基数
   * @returns 是否合法
   */
  static isValidChar(ch: string, base: NumberBase): boolean {
    if (base === NumberBase.BIN) return ch === '0' || ch === '1'
    if (base === NumberBase.OCT) return ch >= '0' && ch <= '7'
    if (base === NumberBase.DEC) return ch >= '0' && ch <= '9'
    if (base === NumberBase.HEX) {
      return (ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f')
    }
    return false
  }

  /**
   * 十六进制字符串大写化
   * @param str 含 a-f 的字符串
   * @returns 大写化结果
   */
  static formatHex(str: string): string {
    return str.toUpperCase()
  }

  /**
   * 跨进制转换
   * @param str 源字符串
   * @param fromBase 源基数
   * @param toBase 目标基数
   * @returns 目标进制字符串
   */
  static convert(str: string, fromBase: NumberBase, toBase: NumberBase): string {
    const dec: number = BaseConverter.fromBase(str, fromBase)
    if (Number.isNaN(dec)) return 'Invalid'
    return BaseConverter.toBase(dec, toBase)
  }

  /**
   * 判断数值是否超出安全整数范围（绝对值 > 2^53）
   * @param value 待检测数值
   * @returns true/false
   */
  static isOverflow(value: number): boolean {
    if (!Number.isFinite(value)) return true
    return Math.abs(value) > BaseConverter.SAFE_MAX
  }

  /**
   * 表达式整体合法性校验（仅检查字符是否对当前进制合法）
   * @param str 表达式
   * @param base 当前基数
   * @returns true/false（空字符串视为合法）
   */
  static isValidExpression(str: string, base: NumberBase): boolean {
    if (str.length === 0) return true
    for (let i: number = 0; i < str.length; i++) {
      const ch: string = str.charAt(i)
      // 操作符 + - × ÷ ( ) . 都允许
      if ('+-×÷(). '.indexOf(ch) >= 0) continue
      if (!BaseConverter.isValidChar(ch, base)) return false
    }
    return true
  }
}

