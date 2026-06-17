// OpenCalc — NaturalLanguageParser 单元测试（hypium 风格）
// Issue #18 单位换算功能

import { describe, it, expect } from '@ohos/hypium'
import { NaturalLanguageParser } from '../../../main/ets/common/NaturalLanguageParser'

export default function naturalLanguageParserTest() {
  describe('NaturalLanguageParser_positive', () => {
    it('AC_NL1_100cm_to_in_compact', 0, () => {
      const r = NaturalLanguageParser.parse('100厘米转英寸')
      expect(r != null).assertEqual(true)
      if (r == null) return
      expect(r.isUnitConversion).assertEqual(true)
      expect(r.value).assertEqual(100)
      expect(r.fromUnit).assertEqual('厘米')
      expect(r.toUnit).assertEqual('英寸')
    })
    it('AC_NL2_30C_to_F_compact', 1, () => {
      const r = NaturalLanguageParser.parse('30摄氏度转华氏度')
      expect(r != null).assertEqual(true)
      if (r == null) return
      expect(r.value).assertEqual(30)
      expect(r.fromUnit).assertEqual('摄氏度')
      expect(r.toUnit).assertEqual('华氏度')
    })
    it('AC_NL3_5ft_in_cm_english', 2, () => {
      const r = NaturalLanguageParser.parse('5ft in cm')
      expect(r != null).assertEqual(true)
      if (r == null) return
      expect(r.value).assertEqual(5)
      expect(r.fromUnit).assertEqual('ft')
      expect(r.toUnit).assertEqual('cm')
    })
    it('AC_NL4_5m_to_ft_english', 3, () => {
      const r = NaturalLanguageParser.parse('5 m to ft')
      expect(r != null).assertEqual(true)
      if (r == null) return
      expect(r.value).assertEqual(5)
      expect(r.fromUnit).assertEqual('m')
      expect(r.toUnit).assertEqual('ft')
    })
    it('AC_NL5_5kgwei_zhong_chinese', 4, () => {
      const r = NaturalLanguageParser.parse('5千克为克')
      expect(r != null).assertEqual(true)
      if (r == null) return
      expect(r.value).assertEqual(5)
      expect(r.fromUnit).assertEqual('千克')
      expect(r.toUnit).assertEqual('克')
    })
    it('AC_NL6_decimal_value', 5, () => {
      const r = NaturalLanguageParser.parse('1.5米转英尺')
      expect(r != null).assertEqual(true)
      if (r == null) return
      expect(Math.abs(r.value - 1.5) < 1e-9).assertEqual(true)
      expect(r.fromUnit).assertEqual('米')
      expect(r.toUnit).assertEqual('英尺')
    })
  })

  describe('NaturalLanguageParser_negative', () => {
    it('AC_NN1_1_plus_2_should_be_null', 0, () => {
      const r = NaturalLanguageParser.parse('1+2')
      expect(r).assertEqual(null)
    })
    it('AC_NN2_sin_func_should_be_null', 1, () => {
      const r = NaturalLanguageParser.parse('sin(0)')
      expect(r).assertEqual(null)
    })
    it('AC_NN3_empty_should_be_null', 2, () => {
      const r = NaturalLanguageParser.parse('')
      expect(r).assertEqual(null)
    })
    it('AC_NN4_pure_number_should_be_null', 3, () => {
      const r = NaturalLanguageParser.parse('100')
      expect(r).assertEqual(null)
    })
  })
}
