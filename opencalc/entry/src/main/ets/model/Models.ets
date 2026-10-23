// OpenCalc — 数据模型
// 移植自：Android Models.kt

/** 计算错误类型枚举 */
export enum CalculatorError {
  NONE = 'none',                   // 无错误
  DIVISION_BY_ZERO = 'division_by_zero',  // 除零
  DOMAIN_ERROR = 'domain_error',          // 定义域错误
  SYNTAX_ERROR = 'syntax_error',          // 语法错误
  INFINITY = 'infinity',                  // 无穷大
  REQUIRE_REAL = 'require_real_number'    // 需要实数
}

/** 数字分组编号体系 */
export enum NumberingSystem {
  INTERNATIONAL = 0,  // 国际制（每3位分组）
  INDIAN = 1          // 印度制
}

/** 科学模式切换状态 */
export enum ScientificModeType {
  NOT_ACTIVE = 0,  // 默认关闭
  ACTIVE = 1,      // 默认开启
  OFF = 2          // 强制关闭
}

/** 顶层计算器模式。程序员模式状态与普通计算状态相互隔离。 */
export enum CalculatorMode {
  NORMAL = 'normal',
  PROGRAMMER = 'programmer'
}

/** 程序员模式支持的输入进制。 */
export enum Radix {
  BIN = 2,
  OCT = 8,
  DEC = 10,
  HEX = 16
}

/** 程序员转换的结构化反馈。 */
export enum ProgrammerError {
  NONE = 'none',
  EMPTY = 'empty',
  INVALID_DIGIT = 'invalid_digit',
  OUT_OF_RANGE = 'out_of_range',
  INTERNAL = 'internal'
}

/** 同一精确值的四种规范表示。 */
export interface ConversionResult {
  bin: string
  oct: string
  dec: string
  hex: string
}

/** 程序员面板的完整、可整体替换状态。 */
export interface ProgrammerState {
  radix: Radix
  input: string
  result: ConversionResult | null
  error: ProgrammerError
}

/** 原子操作结果；error 与 state.error 一致，便于调用方分支。 */
export interface ProgrammerOperationResult {
  state: ProgrammerState
  error: ProgrammerError
}

/** 历史记录条目 */
export interface HistoryItem {
  id: number           // 唯一标识
  expression: string   // 计算表达式
  result: string       // 计算结果
  timestamp: number    // 时间戳
}

/** 计算器偏好设置（存储于 @ohos.data.preferences） */
export interface CalculatorPreferences {
  theme: number                    // 主题（0=默认 1=AMOLED 2=Material）
  forceDayNight: number            // 日夜模式（0=系统 1=浅色 2=深色 3=AMOLED）
  vibrationEnabled: boolean        // 振动反馈开关
  preventSleep: boolean            // 防休眠开关
  historySize: number              // 历史记录最大条数
  scientificModeDefault: number    // 默认科学模式状态
  radiansDefault: boolean          // 默认弧度模式
  numberPrecision: number          // 数字精度
  decimalSeparatorSymbol: string   // 小数点符号
  groupingSeparatorSymbol: string  // 千分位符号
}

/** 默认偏好设置 */
export const DEFAULT_PREFERENCES: CalculatorPreferences = {
  theme: 0,
  forceDayNight: 0,
  vibrationEnabled: true,
  preventSleep: false,
  historySize: 100,
  scientificModeDefault: ScientificModeType.NOT_ACTIVE,
  radiansDefault: false,
  numberPrecision: 12,
  decimalSeparatorSymbol: '.',
  groupingSeparatorSymbol: ','
}
