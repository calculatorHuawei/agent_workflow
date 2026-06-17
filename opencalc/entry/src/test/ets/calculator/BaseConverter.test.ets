// OpenCalc — BaseConverter 单元测试（hypium 风格）
// Issue #22 程序员模式：BIN/OCT/DEC/HEX 实时转换

import { describe, it, expect } from '@ohos/hypium'
import { BaseConverter } from '../../../main/ets/calculator/BaseConverter'
import { NumberBase, ProgrammerDisplayState } from '../../../main/ets/model/ModeModel'

export default function baseConverterTest() {

  // ================================================================
  // toBase — 数字转进制字符串
  // ================================================================

  describe('toBase_decimal_to_base_string', () => {

    it('AC-1_toBase_0_BIN_should_return_0', 0, () => {
      const got = BaseConverter.toBase(0, NumberBase.BIN)
      expect(got).assertEqual('0')
    })

    it('AC-2_toBase_10_BIN_should_return_1010', 1, () => {
      const got = BaseConverter.toBase(10, NumberBase.BIN)
      expect(got).assertEqual('1010')
    })

    it('AC-3_toBase_8_OCT_should_return_10', 2, () => {
      const got = BaseConverter.toBase(8, NumberBase.OCT)
      expect(got).assertEqual('10')
    })

    it('AC-4_toBase_255_HEX_should_return_FF', 3, () => {
      const got = BaseConverter.toBase(255, NumberBase.HEX)
      expect(got).assertEqual('FF')
    })

    it('AC-5_toBase_neg10_BIN_should_return_neg_1010', 4, () => {
      const got = BaseConverter.toBase(-10, NumberBase.BIN)
      expect(got).assertEqual('-1010')
    })

    it('AC-6_toBase_10_7_BIN_should_floor_to_1010', 5, () => {
      // 小数部分截断为整数
      const got = BaseConverter.toBase(10.7, NumberBase.BIN)
      expect(got).assertEqual('1010')
    })
  })

  // ================================================================
  // fromBase — 进制字符串转数字
  // ================================================================

  describe('fromBase_base_string_to_decimal', () => {

    it('AC-7_fromBase_FF_HEX_should_return_255', 6, () => {
      const got = BaseConverter.fromBase('FF', NumberBase.HEX)
      expect(got).assertEqual(255)
    })

    it('AC-8_fromBase_1010_BIN_should_return_10', 7, () => {
      const got = BaseConverter.fromBase('1010', NumberBase.BIN)
      expect(got).assertEqual(10)
    })

    it('AC-9_fromBase_XYZ_BIN_should_return_NaN', 8, () => {
      const got = BaseConverter.fromBase('XYZ', NumberBase.BIN)
      // NaN 的特征是 !== 自身
      expect(got !== got).assertTrue()
    })

    it('AC-10_fromBase_lowercase_hex_should_work', 9, () => {
      const got = BaseConverter.fromBase('ff', NumberBase.HEX)
      expect(got).assertEqual(255)
    })
  })

  // ================================================================
  // getRepresentations — 四进制联合表示
  // ================================================================

  describe('getRepresentations_all_bases', () => {

    it('AC-11_getRepresentations_10_should_match_4_bases', 10, () => {
      const got = BaseConverter.getRepresentations(10)
      expect(got.bin).assertEqual('1010')
      expect(got.oct).assertEqual('12')
      expect(got.dec).assertEqual('10')
      expect(got.hex).assertEqual('A')
      expect(got.hasOverflow).assertEqual(false)
    })

    it('AC-12_getRepresentations_0_should_return_all_zero', 11, () => {
      const got = BaseConverter.getRepresentations(0)
      expect(got.bin).assertEqual('0')
      expect(got.oct).assertEqual('0')
      expect(got.dec).assertEqual('0')
      expect(got.hex).assertEqual('0')
    })

    it('AC-13_getRepresentations_neg_255_should_have_sign_in_all', 12, () => {
      const got = BaseConverter.getRepresentations(-255)
      expect(got.bin.indexOf('-') === 0).assertTrue()
      expect(got.oct.indexOf('-') === 0).assertTrue()
      expect(got.dec.indexOf('-') === 0).assertTrue()
      expect(got.hex.indexOf('-') === 0).assertTrue()
    })
  })

  // ================================================================
  // isValidChar — 当前基数下字符是否合法
  // ================================================================

  describe('isValidChar_check_char_for_base', () => {

    it('AC-14_isValidChar_0_BIN_should_be_true', 13, () => {
      const got = BaseConverter.isValidChar('0', NumberBase.BIN)
      expect(got).assertTrue()
    })

    it('AC-15_isValidChar_2_BIN_should_be_false', 14, () => {
      const got = BaseConverter.isValidChar('2', NumberBase.BIN)
      expect(got).assertFalse()
    })

    it('AC-16_isValidChar_A_HEX_should_be_true', 15, () => {
      const got = BaseConverter.isValidChar('A', NumberBase.HEX)
      expect(got).assertTrue()
    })

    it('AC-17_isValidChar_a_HEX_should_be_true_lowercase', 16, () => {
      const got = BaseConverter.isValidChar('a', NumberBase.HEX)
      expect(got).assertTrue()
    })

    it('AC-18_isValidChar_G_HEX_should_be_false', 17, () => {
      const got = BaseConverter.isValidChar('G', NumberBase.HEX)
      expect(got).assertFalse()
    })
  })

  // ================================================================
  // maxCharsFor — 64-bit 数字在某基数下最大长度
  // ================================================================

  describe('maxCharsFor_compute_bit_length', () => {

    it('AC-19_maxCharsFor_BIN_should_be_64', 18, () => {
      const got = BaseConverter.maxCharsFor(NumberBase.BIN)
      expect(got).assertEqual(64)
    })

    it('AC-20_maxCharsFor_HEX_should_be_16', 19, () => {
      const got = BaseConverter.maxCharsFor(NumberBase.HEX)
      expect(got).assertEqual(16)
    })
  })

  // ================================================================
  // NumberBase 枚举与 fromValue 静态构造
  // ================================================================

  describe('NumberBase_and_ProgrammerDisplayState', () => {

    it('AC-21_NumberBase_radix_field_should_match', 20, () => {
      expect(NumberBase.BIN.radix).assertEqual(2)
      expect(NumberBase.OCT.radix).assertEqual(8)
      expect(NumberBase.DEC.radix).assertEqual(10)
      expect(NumberBase.HEX.radix).assertEqual(16)
    })

    it('AC-22_ProgrammerDisplayState_fromValue_should_compute', 21, () => {
      const got = ProgrammerDisplayState.fromValue(255)
      expect(got.bin).assertEqual('11111111')
      expect(got.oct).assertEqual('377')
      expect(got.dec).assertEqual('255')
      expect(got.hex).assertEqual('FF')
    })
  })
}
