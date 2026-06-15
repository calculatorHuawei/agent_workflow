// OpenCalc — NaturalLanguageParser 单元测试(hypium 风格)
// aid-workflow 20260615: Issue #14 单位换算功能
// 真实跑测入口:hvigorw test 或 ohpm test(若环境不可用,降级为 Node 端口测试)

import { describe, it, expect } from '@ohos/hypium'
import { NaturalLanguageParser, ParseResult } from '../../../main/ets/common/NaturalLanguageParser'

export default function naturalLanguageParserTest() {
  describe('NaturalLanguageParser_chinese', () => {
    it('NL_CN_L01_100cm_to_inch', 0, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('100厘米转英寸')
      expect(r !== null).assertTrue()
      if (r !== null) {
        expect(r.value).assertEqual(100)
        expect(r.from).assertEqual('cm')
        expect(r.to).assertEqual('inch')
        expect(r.category).assertEqual('length')
      }
    })
    it('NL_CN_L02_1mi_to_km', 1, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('1英里转千米')
      expect(r !== null).assertTrue()
      if (r !== null) {
        expect(r.value).assertEqual(1)
        expect(r.from).assertEqual('mi')
        expect(r.to).assertEqual('km')
      }
    })
    it('NL_CN_T01_30C_to_F', 2, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('30摄氏度转华氏度')
      expect(r !== null).assertTrue()
      if (r !== null) {
        expect(r.value).assertEqual(30)
        expect(r.from).assertEqual('C')
        expect(r.to).assertEqual('F')
        expect(r.category).assertEqual('temperature')
      }
    })
    it('NL_CN_T02_0C_to_K', 3, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('0摄氏度转开尔文')
      expect(r !== null).assertTrue()
      if (r !== null) {
        expect(r.value).assertEqual(0)
        expect(r.from).assertEqual('C')
        expect(r.to).assertEqual('K')
      }
    })
    it('NL_CN_M01_5lb_to_kg', 4, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('5磅转千克')
      expect(r !== null).assertTrue()
      if (r !== null) {
        expect(r.value).assertEqual(5)
        expect(r.from).assertEqual('lb')
        expect(r.to).assertEqual('kg')
      }
    })
    it('NL_CN_V01_1gal_to_L', 5, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('1加仑转升')
      expect(r !== null).assertTrue()
      if (r !== null) {
        expect(r.value).assertEqual(1)
        expect(r.from).assertEqual('gal')
        expect(r.to).assertEqual('L')
      }
    })
  })

  describe('NaturalLanguageParser_english', () => {
    it('NL_EN_L01_100cm_to_inch', 0, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('100cm to inch')
      expect(r !== null).assertTrue()
      if (r !== null) {
        expect(r.value).assertEqual(100)
        expect(r.from).assertEqual('cm')
        expect(r.to).assertEqual('inch')
      }
    })
    it('NL_EN_T01_100F_to_C', 1, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('100F to C')
      expect(r !== null).assertTrue()
      if (r !== null) {
        expect(r.value).assertEqual(100)
        expect(r.from).assertEqual('F')
        expect(r.to).assertEqual('C')
      }
    })
    it('NL_EN_M01_1kg_to_g', 2, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('1 kg to g')
      expect(r !== null).assertTrue()
      if (r !== null) {
        expect(r.value).assertEqual(1)
        expect(r.from).assertEqual('kg')
        expect(r.to).assertEqual('g')
      }
    })
    it('NL_EN_V01_128floz_to_gal', 3, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('128 fl oz to gal')
      expect(r !== null).assertTrue()
      if (r !== null) {
        expect(r.value).assertEqual(128)
        expect(r.from).assertEqual('fl_oz')
        expect(r.to).assertEqual('gal')
      }
    })
    it('NL_EN_V02_1L_to_mL_arrow', 4, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('1L->mL')
      expect(r !== null).assertTrue()
      if (r !== null) {
        expect(r.value).assertEqual(1)
        expect(r.from).assertEqual('L')
        expect(r.to).assertEqual('mL')
      }
    })
  })

  describe('NaturalLanguageParser_aliases', () => {
    it('NL_AL_L01_gongfen_to_cm', 0, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('100公分转英寸')
      expect(r !== null).assertTrue()
      if (r !== null) expect(r.from).assertEqual('cm')
    })
    it('NL_AL_L02_gongli_to_km', 1, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('1公里转英里')
      expect(r !== null).assertTrue()
      if (r !== null) expect(r.from).assertEqual('km')
    })
    it('NL_AL_T01_huashi_to_F', 2, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('100华氏转摄氏')
      expect(r !== null).assertTrue()
      if (r !== null) expect(r.from).assertEqual('F')
    })
    it('NL_AL_M01_gongjin_to_kg', 3, () => {
      const r: ParseResult | null = NaturalLanguageParser.parse('1公斤转克')
      expect(r !== null).assertTrue()
      if (r !== null) expect(r.from).assertEqual('kg')
    })
  })

  describe('NaturalLanguageParser_errors', () => {
    it('NL_ERR_01_m_to_kg_cross', 0, () => {
      expect(NaturalLanguageParser.parse('1米转千克')).assertEqual(null)
    })
    it('NL_ERR_02_abc_no_digit', 1, () => {
      expect(NaturalLanguageParser.parse('abc 厘米 转 英寸')).assertEqual(null)
    })
    it('NL_ERR_03_unknown_unit', 2, () => {
      expect(NaturalLanguageParser.parse('1 未知单位 转 米')).assertEqual(null)
    })
    it('NL_ERR_04_no_converter', 3, () => {
      expect(NaturalLanguageParser.parse('100cm')).assertEqual(null)
    })
    it('NL_ERR_05_math_expr', 4, () => {
      expect(NaturalLanguageParser.parse('1+2')).assertEqual(null)
    })
    it('NL_ERR_06_empty', 5, () => {
      expect(NaturalLanguageParser.parse('')).assertEqual(null)
    })
  })
}
