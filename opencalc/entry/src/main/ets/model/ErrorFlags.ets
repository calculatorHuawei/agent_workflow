// OpenCalc — 计算错误标志（共享可变状态）
// ArkTS: 导入的变量是只读的，所以用类的静态可变字段代替

export class ErrorFlags {
  /** 语法错误 */
  static syntax_error: boolean = false
  /** 除数为零 */
  static division_by_0: boolean = false
  /** 定义域错误（如 ln(-1)） */
  static domain_error: boolean = false
  /** 结果无穷大 */
  static is_infinity: boolean = false
  /** 需要实数（负数开偶次方） */
  static require_real_number: boolean = false

  /** 重置所有错误标志 */
  static reset(): void {
    ErrorFlags.syntax_error = false
    ErrorFlags.division_by_0 = false
    ErrorFlags.domain_error = false
    ErrorFlags.is_infinity = false
    ErrorFlags.require_real_number = false
  }
}
