// OpenCalc — NaturalLanguageParser 自然语言单位换算解析器
// Issue #18 单位换算功能
// 支持格式:
//   "100厘米转英寸"  "30摄氏度转华氏度"  "5千克为克"
//   "5ft in cm"      "5 m to ft"         "5 m to ft"
// 严格匹配关键字(转/to/in/为/→),关键字不出现则返回 null(走 CalcEngine 降级)

export interface NLParseResult {
  isUnitConversion: boolean
  value: number
  fromUnit: string
  toUnit: string
}

const KEYWORDS: string[] = ['转', 'to', 'in', '为', '→']

// 已知单位 token 表(与 UnitConverter UNITS 对齐)
// 仅用于 NL 解析时分界,不是单位换算依据
const KNOWN_UNITS: string[] = [
  '米', '厘米', '毫米', '分米', '千米', '英寸', '英尺', '码', '英里',
  '克', '千克', '毫克', '吨', '磅', '盎司',
  '秒', '分钟', '小时', '天',
  '摄氏度', '华氏度', '开尔文',
  'm', 'cm', 'mm', 'dm', 'km', 'in', 'ft', 'yd', 'mi',
  'g', 'kg', 'mg', 't', 'lb', 'oz',
  's', 'h', 'd', 'min',
  'C', 'F', 'K', '°C', '°F'
]

/**
 * 查找第一个关键字在 input 中的位置
 * 返回 [keyword, position] 或 null
 */
function findFirstKeyword(input: string): [string, number] | null {
  for (let i: number = 0; i < KEYWORDS.length; i++) {
    const k: string = KEYWORDS[i]
    const pos: number = input.indexOf(k)
    if (pos !== -1) return [k, pos]
  }
  return null
}

export class NaturalLanguageParser {
  /**
   * 输入: 原始 expression 字符串
   * 输出: null = 不是 NL 模式(走 CalcEngine 降级)
   *       NLParseResult = 识别为换算模式
   */
  public static parse(input: string): NLParseResult | null {
    if (input == null) return null
    const trimmed: string = input.trim()
    if (trimmed.length === 0) return null

    const firstMatch: [string, number] | null = findFirstKeyword(trimmed)
    if (firstMatch == null) return null

    const keyword: string = firstMatch[0]
    const kwPos: number = firstMatch[1]

    // 1. 提取 head: 关键字之前的部分
    const head: string = trimmed.substring(0, kwPos).trim()
    if (head.length === 0) return null

    // 2. head 必须以数字开头(支持整数和小数,正负数)
    const valueNumMatch: RegExpMatchArray | null = head.match(/^-?\d+(\.\d+)?/)
    if (valueNumMatch == null) return null
    const value: number = parseFloat(valueNumMatch[0])
    if (isNaN(value)) return null

    // 3. head 数字之后的尾部文本,可能为 fromUnit 提示
    //    例如 "100厘米" 中数字后是 "厘米"; "5 m" 中数字后是 "m"; "5" 时为空
    const headTrailing: string = head.substring(valueNumMatch[0].length).trim()

    // 4. head 必须仅由 [数字][可选尾部文本] 组成,不允许 + - * / (等运算符(避免误判表达式)
    if (/[+\-*/(]/.test(headTrailing)) return null

    // 5. 提取 tail: 关键字之后的部分
    const tail: string = trimmed.substring(kwPos + keyword.length).trim()
    if (tail.length === 0) return null

    // 6. 切分 tail 为 [fromUnit, toUnit]
    // 优先 a: tail 中再含一个关键字 → split 该关键字
    // 优先 b: 空白 split 成 2 段
    // 优先 c: 已知单位 token 边界匹配
    // 退路:   tail 仅含一个单位 → 用 headTrailing 作为 fromUnit
    const secondMatch: [string, number] | null = findFirstKeyword(tail)
    let fromUnit: string = ''
    let toUnit: string = ''
    if (secondMatch != null) {
      const f: string = tail.substring(0, secondMatch[1]).trim()
      const t: string = tail.substring(secondMatch[1] + secondMatch[0].length).trim()
      if (f.length > 0 && t.length > 0) {
        fromUnit = f
        toUnit = t
      }
    }
    if (fromUnit.length === 0) {
      const splitPair: [string, string] | null = NaturalLanguageParser.findUnitSplit(tail)
      if (splitPair != null) {
        fromUnit = splitPair[0]
        toUnit = splitPair[1]
      }
    }
    if (fromUnit.length === 0) {
      // tail 单一单位场景: 从 head 尾部借 fromUnit
      if (headTrailing.length === 0) return null
      fromUnit = headTrailing
      toUnit = tail
    }

    if (fromUnit.length === 0 || toUnit.length === 0) return null

    return {
      isUnitConversion: true,
      value: value,
      fromUnit: fromUnit,
      toUnit: toUnit
    }
  }

  /**
   * 在 tail 中找到 [fromUnit, toUnit] 切分位置
   * 策略: 空白 split → 已知单位 token 边界匹配
   * 返回 null 表示 tail 只有一个单位(或分界失败)
   */
  private static findUnitSplit(tail: string): [string, string] | null {
    // 优先: 空白 split
    const parts: string[] = tail.split(/\s+/)
    if (parts.length === 2 && parts[0].length > 0 && parts[1].length > 0) {
      return [parts[0], parts[1]]
    }
    // 退路: 找已知单位 token 作为分界(从大到小尝试最长前缀)
    for (let i: number = tail.length; i >= 1; i--) {
      const left: string = tail.substring(0, i)
      if (KNOWN_UNITS.indexOf(left) !== -1) {
        if (i < tail.length) return [left, tail.substring(i)]
      }
    }
    return null
  }
}
