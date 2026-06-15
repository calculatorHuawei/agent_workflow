// OpenCalc — BaseConverter 单元测试（hypium 风格）
// Issue #12 程序员模式 - 进制转换工具测试
// 真实跑测：hvigorw test
// 本地验证：specs/changes/20260615-requirement-add-简单需求/tests/BaseConverter.test.mjs（Node 端口）

import { describe, it, expect } from '@ohos/hypium'
import { BaseConverter } from '../../../main/ets/calculator/BaseConverter'
import { NumberBase } from '../../../main/ets/model/Models'

export default function baseConverterTest() {
  describe('BaseConverter_convert_to_BIN', () => {
    it('AC_BC_01_255_to_BIN_is_11111111', 0, () => {
      const got: string = BaseConverter.convert(255, NumberBase.BIN)
      expect(got).assertEqual('11111111')
    })

    it('AC_BC_02_zero_to_BIN_is_0', 1, () => {
      const got: string = BaseConverter.convert(0, NumberBase.BIN)
      expect(got).assertEqual('0')
    })

    it('AC_BC_03_negative_1_to_BIN_is_negative_1', 2, () => {
      const got: string = BaseConverter.convert(-1, NumberBase.BIN)
      expect(got).assertEqual('-1')
    })

    it('AC_BC_04_negative_255_to_BIN_is_negative_11111111', 3, () => {
      const got: string = BaseConverter.convert(-255, NumberBase.BIN)
      expect(got).assertEqual('-11111111')
    })

    it('AC_BC_05_3_14_truncated_to_BIN_is_11', 4, () => {
      const got: string = BaseConverter.convert(3.14, NumberBase.BIN)
      expect(got).assertEqual('11')
    })

    it('AC_BC_06_NaN_to_BIN_is_dash', 5, () => {
      const got: string = BaseConverter.convert(Number.NaN, NumberBase.BIN)
      expect(got).assertEqual('-')
    })

    it('AC_BC_07_Infinity_to_BIN_is_dash', 6, () => {
      const got: string = BaseConverter.convert(Number.POSITIVE_INFINITY, NumberBase.BIN)
      expect(got).assertEqual('-')
    })

    it('AC_BC_08_NegInfinity_to_BIN_is_dash', 7, () => {
      const got: string = BaseConverter.convert(Number.NEGATIVE_INFINITY, NumberBase.BIN)
      expect(got).assertEqual('-')
    })
  })

  describe('BaseConverter_convert_to_OCT', () => {
    it('AC_BC_10_255_to_OCT_is_377', 8, () => {
      const got: string = BaseConverter.convert(255, NumberBase.OCT)
      expect(got).assertEqual('377')
    })

    it('AC_BC_11_8_to_OCT_is_10', 9, () => {
      const got: string = BaseConverter.convert(8, NumberBase.OCT)
      expect(got).assertEqual('10')
    })

    it('AC_BC_12_negative_8_to_OCT_is_negative_10', 10, () => {
      const got: string = BaseConverter.convert(-8, NumberBase.OCT)
      expect(got).assertEqual('-10')
    })

    it('AC_BC_13_NaN_to_OCT_is_dash', 11, () => {
      const got: string = BaseConverter.convert(Number.NaN, NumberBase.OCT)
      expect(got).assertEqual('-')
    })
  })

  describe('BaseConverter_convert_to_HEX', () => {
    it('AC_BC_20_255_to_HEX_is_FF', 12, () => {
      const got: string = BaseConverter.convert(255, NumberBase.HEX)
      expect(got).assertEqual('FF')
    })

    it('AC_BC_21_16_to_HEX_is_10', 13, () => {
      const got: string = BaseConverter.convert(16, NumberBase.HEX)
      expect(got).assertEqual('10')
    })

    it('AC_BC_22_4096_to_HEX_is_1000', 14, () => {
      const got: string = BaseConverter.convert(4096, NumberBase.HEX)
      expect(got).assertEqual('1000')
    })

    it('AC_BC_23_ABC_to_HEX_is_10A', 15, () => {
      // 0x10A = 266
      const got: string = BaseConverter.convert(266, NumberBase.HEX)
      expect(got).assertEqual('10A')
    })

    it('AC_BC_24_lowercase_HEX_works', 16, () => {
      // 10 = A
      const got: string = BaseConverter.convert(10, NumberBase.HEX)
      expect(got).assertEqual('A')
    })

    it('AC_BC_25_negative_255_to_HEX_is_negative_FF', 17, () => {
      const got: string = BaseConverter.convert(-255, NumberBase.HEX)
      expect(got).assertEqual('-FF')
    })
  })

  describe('BaseConverter_convert_to_DEC', () => {
    it('AC_BC_30_255_to_DEC_is_255', 18, () => {
      const got: string = BaseConverter.convert(255, NumberBase.DEC)
      expect(got).assertEqual('255')
    })

    it('AC_BC_31_3_14_to_DEC_keeps_fraction', 19, () => {
      const got: string = BaseConverter.convert(3.14, NumberBase.DEC)
      expect(got).assertEqual('3.14')
    })

    it('AC_BC_32_negative_255_to_DEC_is_negative_255', 20, () => {
      const got: string = BaseConverter.convert(-255, NumberBase.DEC)
      expect(got).assertEqual('-255')
    })

    it('AC_BC_33_zero_to_DEC_is_0', 21, () => {
      const got: string = BaseConverter.convert(0, NumberBase.DEC)
      expect(got).assertEqual('0')
    })

    it('AC_BC_34_NaN_to_DEC_is_dash', 22, () => {
      const got: string = BaseConverter.convert(Number.NaN, NumberBase.DEC)
      expect(got).assertEqual('-')
    })
  })

  describe('BaseConverter_withPrefix', () => {
    it('AC_BC_40_255_with_BIN_prefix', 23, () => {
      const got: string = BaseConverter.withPrefix(255, NumberBase.BIN)
      expect(got).assertEqual('0b11111111')
    })

    it('AC_BC_41_255_with_OCT_prefix', 24, () => {
      const got: string = BaseConverter.withPrefix(255, NumberBase.OCT)
      expect(got).assertEqual('0o377')
    })

    it('AC_BC_42_255_with_HEX_prefix', 25, () => {
      const got: string = BaseConverter.withPrefix(255, NumberBase.HEX)
      expect(got).assertEqual('0xFF')
    })

    it('AC_BC_43_255_with_DEC_no_prefix', 26, () => {
      const got: string = BaseConverter.withPrefix(255, NumberBase.DEC)
      expect(got).assertEqual('255')
    })

    it('AC_BC_44_negative_with_BIN_prefix', 27, () => {
      const got: string = BaseConverter.withPrefix(-1, NumberBase.BIN)
      expect(got).assertEqual('-0b1')
    })

    it('AC_BC_45_negative_with_HEX_prefix', 28, () => {
      const got: string = BaseConverter.withPrefix(-255, NumberBase.HEX)
      expect(got).assertEqual('-0xFF')
    })

    it('AC_BC_46_zero_with_HEX_prefix', 29, () => {
      const got: string = BaseConverter.withPrefix(0, NumberBase.HEX)
      expect(got).assertEqual('0x0')
    })

    it('AC_BC_47_NaN_with_prefix_is_dash', 30, () => {
      const got: string = BaseConverter.withPrefix(Number.NaN, NumberBase.BIN)
      expect(got).assertEqual('-')
    })
  })

  describe('BaseConverter_edge_cases', () => {
    it('AC_BC_50_Number_MAX_SAFE_INTEGER', 31, () => {
      // 2^53 - 1 = 9007199254740991
      // BIN: 53 bits all 1
      const got: string = BaseConverter.convert(Number.MAX_SAFE_INTEGER, NumberBase.BIN)
      expect(got.length).assertEqual(53)
      expect(got.indexOf('0')).assertEqual(-1)
    })

    it('AC_BC_51_one_to_BIN', 32, () => {
      const got: string = BaseConverter.convert(1, NumberBase.BIN)
      expect(got).assertEqual('1')
    })

    it('AC_BC_52_negative_zero_treated_as_zero', 33, () => {
      const got: string = BaseConverter.convert(-0, NumberBase.BIN)
      expect(got).assertEqual('0')
    })
  })
}