// OpenCalc — UnitConverter 单元测试(hypium 风格)
// aid-workflow 20260615: Issue #14 单位换算功能
// 真实跑测入口:hvigorw test 或 ohpm test(若环境不可用,降级为 Node 端口测试)

import { describe, it, expect } from '@ohos/hypium'
import { UnitConverter } from '../../../main/ets/common/UnitConverter'

const EPS: number = 1e-6

export default function unitConverterTest() {
  describe('UnitConverter_length', () => {
    it('UC_L_01_100cm_to_inch', 0, () => {
      const got: number | null = UnitConverter.convert(100, 'cm', 'inch', 'length')
      expect(got !== null && Math.abs(got - 39.3700787) < EPS).assertTrue()
    })
    it('UC_L_02_1km_to_mi', 1, () => {
      const got: number | null = UnitConverter.convert(1, 'km', 'mi', 'length')
      expect(got !== null && Math.abs(got - 0.621371192) < EPS).assertTrue()
    })
    it('UC_L_03_1mi_to_km', 2, () => {
      const got: number | null = UnitConverter.convert(1, 'mi', 'km', 'length')
      expect(got !== null && Math.abs(got - 1.609344) < EPS).assertTrue()
    })
    it('UC_L_04_1m_to_cm', 3, () => {
      const got: number | null = UnitConverter.convert(1, 'm', 'cm', 'length')
      expect(got !== null && Math.abs(got - 100) < EPS).assertTrue()
    })
    it('UC_L_05_1m_to_mm', 4, () => {
      const got: number | null = UnitConverter.convert(1, 'm', 'mm', 'length')
      expect(got !== null && Math.abs(got - 1000) < EPS).assertTrue()
    })
    it('UC_L_06_1ft_to_m', 5, () => {
      const got: number | null = UnitConverter.convert(1, 'ft', 'm', 'length')
      expect(got !== null && Math.abs(got - 0.3048) < EPS).assertTrue()
    })
    it('UC_L_07_1yd_to_m', 6, () => {
      const got: number | null = UnitConverter.convert(1, 'yd', 'm', 'length')
      expect(got !== null && Math.abs(got - 0.9144) < EPS).assertTrue()
    })
    it('UC_L_08_1inch_to_mm', 7, () => {
      const got: number | null = UnitConverter.convert(1, 'inch', 'mm', 'length')
      expect(got !== null && Math.abs(got - 25.4) < EPS).assertTrue()
    })
    it('UC_L_11_1mi_to_ft', 8, () => {
      const got: number | null = UnitConverter.convert(1, 'mi', 'ft', 'length')
      expect(got !== null && Math.abs(got - 5280) < EPS).assertTrue()
    })
    it('UC_L_12_1000mm_to_m', 9, () => {
      const got: number | null = UnitConverter.convert(1000, 'mm', 'm', 'length')
      expect(got !== null && Math.abs(got - 1) < EPS).assertTrue()
    })
  })

  describe('UnitConverter_temperature', () => {
    it('UC_T_01_0C_to_K', 0, () => {
      const got: number | null = UnitConverter.convert(0, 'C', 'K', 'temperature')
      expect(got !== null && Math.abs(got - 273.15) < EPS).assertTrue()
    })
    it('UC_T_02_0C_to_F', 1, () => {
      const got: number | null = UnitConverter.convert(0, 'C', 'F', 'temperature')
      expect(got !== null && Math.abs(got - 32) < EPS).assertTrue()
    })
    it('UC_T_03_100C_to_F', 2, () => {
      const got: number | null = UnitConverter.convert(100, 'C', 'F', 'temperature')
      expect(got !== null && Math.abs(got - 212) < EPS).assertTrue()
    })
    it('UC_T_04_32F_to_C', 3, () => {
      const got: number | null = UnitConverter.convert(32, 'F', 'C', 'temperature')
      expect(got !== null && Math.abs(got - 0) < EPS).assertTrue()
    })
    it('UC_T_05_100F_to_C', 4, () => {
      const got: number | null = UnitConverter.convert(100, 'F', 'C', 'temperature')
      expect(got !== null && Math.abs(got - 37.77777777777778) < 1e-10).assertTrue()
    })
    it('UC_T_06_273_15K_to_C', 5, () => {
      const got: number | null = UnitConverter.convert(273.15, 'K', 'C', 'temperature')
      expect(got !== null && Math.abs(got - 0) < EPS).assertTrue()
    })
    it('UC_T_07_minus_40C_to_F', 6, () => {
      const got: number | null = UnitConverter.convert(-40, 'C', 'F', 'temperature')
      expect(got !== null && Math.abs(got - -40) < EPS).assertTrue()
    })
    it('UC_T_08_0K_to_C', 7, () => {
      const got: number | null = UnitConverter.convert(0, 'K', 'C', 'temperature')
      expect(got !== null && Math.abs(got - -273.15) < EPS).assertTrue()
    })
  })

  describe('UnitConverter_mass', () => {
    it('UC_M_01_1kg_to_g', 0, () => {
      const got: number | null = UnitConverter.convert(1, 'kg', 'g', 'mass')
      expect(got !== null && Math.abs(got - 1000) < EPS).assertTrue()
    })
    it('UC_M_02_1lb_to_kg', 1, () => {
      const got: number | null = UnitConverter.convert(1, 'lb', 'kg', 'mass')
      expect(got !== null && Math.abs(got - 0.45359237) < EPS).assertTrue()
    })
    it('UC_M_03_5lb_to_kg', 2, () => {
      const got: number | null = UnitConverter.convert(5, 'lb', 'kg', 'mass')
      expect(got !== null && Math.abs(got - 2.26796185) < EPS).assertTrue()
    })
    it('UC_M_04_16oz_to_lb', 3, () => {
      const got: number | null = UnitConverter.convert(16, 'oz', 'lb', 'mass')
      expect(got !== null && Math.abs(got - 1) < EPS).assertTrue()
    })
    it('UC_M_05_1kg_to_oz', 4, () => {
      const got: number | null = UnitConverter.convert(1, 'kg', 'oz', 'mass')
      expect(got !== null && Math.abs(got - 35.27396194958) < 1e-4).assertTrue()
    })
    it('UC_M_07_1000g_to_kg', 5, () => {
      const got: number | null = UnitConverter.convert(1000, 'g', 'kg', 'mass')
      expect(got !== null && Math.abs(got - 1) < EPS).assertTrue()
    })
  })

  describe('UnitConverter_volume', () => {
    it('UC_V_01_1L_to_mL', 0, () => {
      const got: number | null = UnitConverter.convert(1, 'L', 'mL', 'volume')
      expect(got !== null && Math.abs(got - 1000) < EPS).assertTrue()
    })
    it('UC_V_02_1gal_to_L', 1, () => {
      const got: number | null = UnitConverter.convert(1, 'gal', 'L', 'volume')
      expect(got !== null && Math.abs(got - 3.785411784) < EPS).assertTrue()
    })
    it('UC_V_03_128floz_to_gal', 2, () => {
      const got: number | null = UnitConverter.convert(128, 'fl_oz', 'gal', 'volume')
      expect(got !== null && Math.abs(got - 1) < EPS).assertTrue()
    })
    it('UC_V_04_1000mL_to_L', 3, () => {
      const got: number | null = UnitConverter.convert(1000, 'mL', 'L', 'volume')
      expect(got !== null && Math.abs(got - 1) < EPS).assertTrue()
    })
    it('UC_V_05_1L_to_floz', 4, () => {
      const got: number | null = UnitConverter.convert(1, 'L', 'fl_oz', 'volume')
      expect(got !== null && Math.abs(got - 33.814022701) < 1e-4).assertTrue()
    })
  })

  describe('UnitConverter_errors', () => {
    it('UC_ERR_01_m_to_kg_cross_category', 0, () => {
      const got: number | null = UnitConverter.convert(1, 'm', 'kg', 'length')
      expect(got).assertEqual(null)
    })
    it('UC_ERR_02_C_to_cm_cross_category', 1, () => {
      const got: number | null = UnitConverter.convert(1, 'C', 'cm', 'temperature')
      expect(got).assertEqual(null)
    })
    it('UC_ERR_03_m_to_xyz_unknown_unit', 2, () => {
      const got: number | null = UnitConverter.convert(1, 'm', 'xyz', 'length')
      expect(got).assertEqual(null)
    })
    it('UC_ERR_04_xyz_to_m_unknown_unit', 3, () => {
      const got: number | null = UnitConverter.convert(1, 'xyz', 'm', 'length')
      expect(got).assertEqual(null)
    })
    it('UC_ERR_05_invalid_category', 4, () => {
      const got: number | null = UnitConverter.convert(1, 'm', 'kg', 'invalid')
      expect(got).assertEqual(null)
    })
  })
}
