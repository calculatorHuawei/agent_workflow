// OpenCalc — UnitConverter 单位换算引擎
// Issue #18 单位换算功能
// 支持长度/质量/时间/温度四个维度,温度使用 affine 公式独立处理

/**
 * 单位定义
 * dimension: 物理量类别
 * aliases: 中英文别名列表
 * toBase: 任意单位值 → 基准单位值
 * fromBase: 基准单位值 → 任意单位值
 */
interface UnitDef {
  dimension: string
  aliases: string[]
  toBase: (v: number) => number
  fromBase: (v: number) => number
}

const UNITS: UnitDef[] = [
  // ============== 长度 (base: m) ==============
  { dimension: 'length', aliases: ['毫米', 'mm'], toBase: (v: number): number => v / 1000, fromBase: (v: number): number => v * 1000 },
  { dimension: 'length', aliases: ['厘米', 'cm'], toBase: (v: number): number => v / 100, fromBase: (v: number): number => v * 100 },
  { dimension: 'length', aliases: ['分米', 'dm'], toBase: (v: number): number => v / 10, fromBase: (v: number): number => v * 10 },
  { dimension: 'length', aliases: ['米', 'm'], toBase: (v: number): number => v, fromBase: (v: number): number => v },
  { dimension: 'length', aliases: ['千米', 'km'], toBase: (v: number): number => v * 1000, fromBase: (v: number): number => v / 1000 },
  { dimension: 'length', aliases: ['英寸', 'in'], toBase: (v: number): number => v * 0.0254, fromBase: (v: number): number => v / 0.0254 },
  { dimension: 'length', aliases: ['英尺', 'ft'], toBase: (v: number): number => v * 0.3048, fromBase: (v: number): number => v / 0.3048 },
  { dimension: 'length', aliases: ['码', 'yd'], toBase: (v: number): number => v * 0.9144, fromBase: (v: number): number => v / 0.9144 },
  { dimension: 'length', aliases: ['英里', 'mi'], toBase: (v: number): number => v * 1609.344, fromBase: (v: number): number => v / 1609.344 },

  // ============== 质量 (base: g) ==============
  { dimension: 'mass', aliases: ['毫克', 'mg'], toBase: (v: number): number => v / 1000, fromBase: (v: number): number => v * 1000 },
  { dimension: 'mass', aliases: ['克', 'g'], toBase: (v: number): number => v, fromBase: (v: number): number => v },
  { dimension: 'mass', aliases: ['千克', 'kg'], toBase: (v: number): number => v * 1000, fromBase: (v: number): number => v / 1000 },
  { dimension: 'mass', aliases: ['吨', 't'], toBase: (v: number): number => v * 1e6, fromBase: (v: number): number => v / 1e6 },
  { dimension: 'mass', aliases: ['磅', 'lb'], toBase: (v: number): number => v * 453.592, fromBase: (v: number): number => v / 453.592 },
  { dimension: 'mass', aliases: ['盎司', 'oz'], toBase: (v: number): number => v * 28.3495, fromBase: (v: number): number => v / 28.3495 },

  // ============== 时间 (base: s) ==============
  { dimension: 'time', aliases: ['秒', 's'], toBase: (v: number): number => v, fromBase: (v: number): number => v },
  { dimension: 'time', aliases: ['分钟', 'min'], toBase: (v: number): number => v * 60, fromBase: (v: number): number => v / 60 },
  { dimension: 'time', aliases: ['小时', 'h'], toBase: (v: number): number => v * 3600, fromBase: (v: number): number => v / 3600 },
  { dimension: 'time', aliases: ['天', 'day', 'd'], toBase: (v: number): number => v * 86400, fromBase: (v: number): number => v / 86400 },

  // ============== 温度 (base: K, affine) ==============
  // 摄氏度 → K: C + 273.15
  { dimension: 'temperature', aliases: ['摄氏度', '°C', 'C'], toBase: (v: number): number => v + 273.15, fromBase: (v: number): number => v - 273.15 },
  // 华氏度 → K: (F - 32) * 5/9 + 273.15
  { dimension: 'temperature', aliases: ['华氏度', '°F', 'F'], toBase: (v: number): number => (v - 32) * 5 / 9 + 273.15, fromBase: (v: number): number => (v - 273.15) * 9 / 5 + 32 },
  // 开尔文: identity
  { dimension: 'temperature', aliases: ['开尔文', 'K'], toBase: (v: number): number => v, fromBase: (v: number): number => v }
]

/**
 * 按 alias 查表找单位定义
 */
function findUnit(name: string): UnitDef | null {
  const trimmed: string = name.trim()
  for (let i: number = 0; i < UNITS.length; i++) {
    const u: UnitDef = UNITS[i]
    for (let j: number = 0; j < u.aliases.length; j++) {
      if (u.aliases[j] === trimmed) return u
    }
  }
  return null
}

export class UnitConverter {
  /**
   * 跨维度 / 未知单位返回 NaN
   * 温度使用 toBase→fromBase 流程（实际等价于 affine）
   * 其他维度: fromDef.fromBase(toDef.toBase(value))
   */
  public static convert(value: number, from: string, to: string): number {
    const fromDef: UnitDef | null = findUnit(from)
    const toDef: UnitDef | null = findUnit(to)
    if (fromDef == null || toDef == null) return NaN
    if (fromDef.dimension !== toDef.dimension) return NaN
    const inBase: number = fromDef.toBase(value)
    return toDef.fromBase(inBase)
  }

  public static listDimensions(): string[] {
    const dims: string[] = []
    for (let i: number = 0; i < UNITS.length; i++) {
      const d: string = UNITS[i].dimension
      if (dims.indexOf(d) === -1) dims.push(d)
    }
    return dims
  }

  public static listUnits(dimension: string): string[] {
    const result: string[] = []
    for (let i: number = 0; i < UNITS.length; i++) {
      if (UNITS[i].dimension === dimension) {
        for (let j: number = 0; j < UNITS[i].aliases.length; j++) {
          result.push(UNITS[i].aliases[j])
        }
      }
    }
    return result
  }
}
