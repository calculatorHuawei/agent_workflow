// OpenCalc — UnitConverter 单元测试（hypium 风格）
// Issue #18 单位换算功能

import { describe, it, expect } from '@ohos/hypium'
import { UnitConverter } from '../../../main/ets/common/UnitConverter'

export default function unitConverterTest() {
  describe('UnitConverter_length', () => {
    it('AC_L1_1m_to_cm_should_equal_100', 0, () => {
      expect(UnitConverter.convert(1, '米', '厘米')).assertEqual(100)
    })
    it('AC_L2_100cm_to_m_should_equal_1', 1, () => {
      expect(UnitConverter.convert(100, '厘米', '米')).assertEqual(1)
    })
    it('AC_L3_100cm_to_in_should_approx_39_3701', 2, () => {
      const r: number = UnitConverter.convert(100, '厘米', '英寸')
      expect(Math.abs(r - 39.3700787) < 1e-4).assertEqual(true)
    })
    it('AC_L4_1km_to_mi_should_approx_0_621371', 3, () => {
      const r: number = UnitConverter.convert(1, '千米', '英里')
      expect(Math.abs(r - 0.621371) < 1e-4).assertEqual(true)
    })
    it('AC_L5_1ft_to_m_should_equal_0_3048', 4, () => {
      const r: number = UnitConverter.convert(1, '英尺', '米')
      expect(Math.abs(r - 0.3048) < 1e-6).assertEqual(true)
    })
    it('AC_L6_alias_m_should_work', 5, () => {
      expect(UnitConverter.convert(1, 'm', 'cm')).assertEqual(100)
    })
  })

  describe('UnitConverter_mass', () => {
    it('AC_M1_1kg_to_g_should_equal_1000', 0, () => {
      expect(UnitConverter.convert(1, '千克', '克')).assertEqual(1000)
    })
    it('AC_M2_1kg_to_lb_should_approx_2_20462', 1, () => {
      const r: number = UnitConverter.convert(1, '千克', '磅')
      expect(Math.abs(r - 2.20462) < 1e-4).assertEqual(true)
    })
    it('AC_M3_1oz_to_g_should_approx_28_3495', 2, () => {
      const r: number = UnitConverter.convert(1, '盎司', '克')
      expect(Math.abs(r - 28.3495) < 1e-4).assertEqual(true)
    })
  })

  describe('UnitConverter_time', () => {
    it('AC_T1_1h_to_s_should_equal_3600', 0, () => {
      expect(UnitConverter.convert(1, '小时', '秒')).assertEqual(3600)
    })
    it('AC_T2_1day_to_h_should_equal_24', 1, () => {
      expect(UnitConverter.convert(1, '天', '小时')).assertEqual(24)
    })
    it('AC_T3_60s_to_min_should_equal_1', 2, () => {
      expect(UnitConverter.convert(60, '秒', '分钟')).assertEqual(1)
    })
  })

  describe('UnitConverter_temperature', () => {
    it('AC_TMP1_30C_to_F_should_equal_86', 0, () => {
      expect(UnitConverter.convert(30, '摄氏度', '华氏度')).assertEqual(86)
    })
    it('AC_TMP2_32F_to_C_should_equal_0', 1, () => {
      expect(UnitConverter.convert(32, '华氏度', '摄氏度')).assertEqual(0)
    })
    it('AC_TMP3_0C_to_K_should_equal_273_15', 2, () => {
      const r: number = UnitConverter.convert(0, '摄氏度', '开尔文')
      expect(Math.abs(r - 273.15) < 1e-6).assertEqual(true)
    })
    it('AC_TMP4_273_15K_to_C_should_equal_0', 3, () => {
      const r: number = UnitConverter.convert(273.15, '开尔文', '摄氏度')
      expect(Math.abs(r - 0) < 1e-6).assertEqual(true)
    })
  })

  describe('UnitConverter_errors', () => {
    it('AC_E1_cross_dimension_m_to_kg_should_be_NaN', 0, () => {
      const r: number = UnitConverter.convert(1, '米', '千克')
      expect(isNaN(r)).assertEqual(true)
    })
    it('AC_E2_unknown_unit_xyz_should_be_NaN', 1, () => {
      const r: number = UnitConverter.convert(1, '米', 'xyz')
      expect(isNaN(r)).assertEqual(true)
    })
    it('AC_E3_unknown_from_unit_should_be_NaN', 2, () => {
      const r: number = UnitConverter.convert(1, 'foo', '米')
      expect(isNaN(r)).assertEqual(true)
    })
  })
}
