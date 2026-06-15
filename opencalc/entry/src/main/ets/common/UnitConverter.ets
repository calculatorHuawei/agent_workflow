// OpenCalc — 单位换算核心
// aid-workflow 20260615: Issue #14 单位换算功能
// 支持 length / temperature / mass / volume 4 大类,共 19 个基准单位
// 端口:与 specs/changes/20260615-requirement-add-unit-conversion/tests/UnitConverter.port.mjs 1:1 对应

const CATEGORY_LENGTH: string = 'length'
const CATEGORY_TEMPERATURE: string = 'temperature'
const CATEGORY_MASS: string = 'mass'
const CATEGORY_VOLUME: string = 'volume'

// 长度:以"米"为基准的换算因子(1 单位 = ? 米)
// aid-workflow 20260615: 使用 Map 满足 ArkTS arkts-no-untyped-obj-literals
function buildLengthFactors(): Map<string, number> {
  const m: Map<string, number> = new Map()
  m.set('m', 1.0)
  m.set('cm', 0.01)
  m.set('mm', 0.001)
  m.set('km', 1000.0)
  m.set('inch', 0.0254)
  m.set('ft', 0.3048)
  m.set('yd', 0.9144)
  m.set('mi', 1609.344)
  return m
}

// 质量:以"千克"为基准
function buildMassFactors(): Map<string, number> {
  const m: Map<string, number> = new Map()
  m.set('kg', 1.0)
  m.set('g', 0.001)
  m.set('lb', 0.45359237)
  m.set('oz', 0.028349523125)
  return m
}

// 体积:以"升"为基准
function buildVolumeFactors(): Map<string, number> {
  const m: Map<string, number> = new Map()
  m.set('L', 1.0)
  m.set('mL', 0.001)
  m.set('gal', 3.785411784)
  m.set('fl_oz', 0.0295735295625)
  return m
}

const LENGTH_FACTORS: Map<string, number> = buildLengthFactors()
const MASS_FACTORS: Map<string, number> = buildMassFactors()
const VOLUME_FACTORS: Map<string, number> = buildVolumeFactors()

export class UnitConverter {
  /**
   * aid-workflow 20260615: 单位换算
   * @param value 输入数值
   * @param from 源单位 canonical key(如 "cm" / "C" / "kg" / "L")
   * @param to 目标单位 canonical key
   * @param category 单位类别("length" | "temperature" | "mass" | "volume")
   * @returns 换算结果;from/to 类别不匹配或单位未注册 → null
   */
  static convert(value: number, from: string, to: string, category: string): number | null {
    if (from === to) return value
    if (category === CATEGORY_TEMPERATURE) return UnitConverter.convertTemperature(value, from, to)
    const factors: Map<string, number> | null = UnitConverter.getFactors(category)
    if (factors === null) return null
    const fromFactor: number | undefined = factors.get(from)
    const toFactor: number | undefined = factors.get(to)
    if (fromFactor === undefined || toFactor === undefined) return null
    const valueInBase: number = value * fromFactor
    return valueInBase / toFactor
  }

  /**
   * aid-workflow 20260615: 温度换算(非线性,通过摄氏度中转)
   * @returns 换算结果;单位未注册 → null
   */
  private static convertTemperature(value: number, from: string, to: string): number | null {
    let celsius: number
    if (from === 'C') celsius = value
    else if (from === 'F') celsius = (value - 32) * 5 / 9
    else if (from === 'K') celsius = value - 273.15
    else return null

    if (to === 'C') return celsius
    if (to === 'F') return celsius * 9 / 5 + 32
    if (to === 'K') return celsius + 273.15
    return null
  }

  /**
   * aid-workflow 20260615: 获取类别对应的换算因子表
   */
  private static getFactors(category: string): Map<string, number> | null {
    if (category === CATEGORY_LENGTH) return LENGTH_FACTORS
    if (category === CATEGORY_MASS) return MASS_FACTORS
    if (category === CATEGORY_VOLUME) return VOLUME_FACTORS
    return null
  }
}
