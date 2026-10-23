import { describe, it, expect } from '@ohos/hypium'
import { CalculatorMode, Radix, ProgrammerError, ProgrammerState, ProgrammerOperationResult } from '../main/ets/model/Models'
import {
  ProgrammerConverter, programmerFeedback, programmerKeyEnabled, programmerResultRows, selectCalculatorMode
} from '../main/ets/programmer/ProgrammerConverter'

export default function programmerConverterTest(): void {
  describe('ProgrammerConverterTypicalValues', () => {
    it('converts_decimal_10_to_all_radices', 0, (): void => {
      const op: ProgrammerOperationResult = ProgrammerConverter.convert('10', Radix.DEC)
      expect(op.error).assertEqual(ProgrammerError.NONE)
      expect(op.state.result?.bin).assertEqual('1010')
      expect(op.state.result?.oct).assertEqual('12')
      expect(op.state.result?.dec).assertEqual('10')
      expect(op.state.result?.hex).assertEqual('A')
    })

    it('converts_hex_ff_and_normalizes_case', 0, (): void => {
      const op: ProgrammerOperationResult = ProgrammerConverter.convert('ff', Radix.HEX)
      expect(op.error).assertEqual(ProgrammerError.NONE)
      expect(op.state.input).assertEqual('FF')
      expect(op.state.result?.dec).assertEqual('255')
      expect(op.state.result?.hex).assertEqual('FF')
    })

    it('enforces_digit_matrix', 0, (): void => {
      expect(ProgrammerConverter.isDigitAllowed('1', Radix.BIN)).assertTrue()
      expect(ProgrammerConverter.isDigitAllowed('2', Radix.BIN)).assertFalse()
      expect(ProgrammerConverter.isDigitAllowed('7', Radix.OCT)).assertTrue()
      expect(ProgrammerConverter.isDigitAllowed('8', Radix.OCT)).assertFalse()
      expect(ProgrammerConverter.isDigitAllowed('9', Radix.DEC)).assertTrue()
      expect(ProgrammerConverter.isDigitAllowed('A', Radix.DEC)).assertFalse()
      expect(ProgrammerConverter.isDigitAllowed('f', Radix.HEX)).assertTrue()
    })
  })

  describe('ProgrammerConverterU64Boundary', () => {
    it('accepts_zero_and_u64_max', 0, (): void => {
      const zero: ProgrammerOperationResult = ProgrammerConverter.convert('000', Radix.DEC)
      expect(zero.error).assertEqual(ProgrammerError.NONE)
      expect(zero.state.input).assertEqual('0')
      expect(zero.state.result?.hex).assertEqual('0')
      const max: ProgrammerOperationResult = ProgrammerConverter.convert('18446744073709551615', Radix.DEC)
      expect(max.error).assertEqual(ProgrammerError.NONE)
      expect(max.state.result?.hex).assertEqual('FFFFFFFFFFFFFFFF')
      expect(max.state.result?.bin.length).assertEqual(64)
    })

    it('rejects_u64_overflow_without_partial_result', 0, (): void => {
      const overflow: ProgrammerOperationResult = ProgrammerConverter.convert('18446744073709551616', Radix.DEC)
      expect(overflow.error).assertEqual(ProgrammerError.OUT_OF_RANGE)
      expect(overflow.state.result === null).assertTrue()
    })

    it('classifies_empty_and_invalid_input', 0, (): void => {
      expect(ProgrammerConverter.convert('', Radix.HEX).error).assertEqual(ProgrammerError.EMPTY)
      expect(ProgrammerConverter.convert('-1', Radix.DEC).error).assertEqual(ProgrammerError.INVALID_DIGIT)
      expect(ProgrammerConverter.convert('0xFF', Radix.HEX).error).assertEqual(ProgrammerError.INVALID_DIGIT)
      expect(ProgrammerConverter.convert('1 0', Radix.DEC).error).assertEqual(ProgrammerError.INVALID_DIGIT)
      expect(ProgrammerConverter.convert('2', Radix.BIN).error).assertEqual(ProgrammerError.INVALID_DIGIT)
    })

    it('accepts_maximum_values_in_each_radix', 0, (): void => {
      expect(ProgrammerConverter.convert('1111111111111111111111111111111111111111111111111111111111111111', Radix.BIN).error).assertEqual(ProgrammerError.NONE)
      expect(ProgrammerConverter.convert('1777777777777777777777', Radix.OCT).error).assertEqual(ProgrammerError.NONE)
      expect(ProgrammerConverter.convert('FFFFFFFFFFFFFFFF', Radix.HEX).error).assertEqual(ProgrammerError.NONE)
      expect(ProgrammerConverter.convert('10000000000000000', Radix.HEX).error).assertEqual(ProgrammerError.OUT_OF_RANGE)
    })

    it('rejects_obviously_overlong_input_before_conversion', 0, (): void => {
      const overlong: string = '00000000000000000000000000000000000000000000000000000000000000000'
      expect(ProgrammerConverter.convert(overlong, Radix.BIN).error).assertEqual(ProgrammerError.OUT_OF_RANGE)
    })
  })

  describe('ProgrammerStateOperations', () => {
    it('rejects_invalid_append_atomically', 0, (): void => {
      const original: ProgrammerState = ProgrammerConverter.convert('1', Radix.BIN).state
      const rejected: ProgrammerOperationResult = ProgrammerConverter.appendDigit(original, '2')
      expect(rejected.error).assertEqual(ProgrammerError.INVALID_DIGIT)
      expect(rejected.state.radix).assertEqual(Radix.BIN)
      expect(rejected.state.input).assertEqual('1')
      expect(rejected.state.result?.dec).assertEqual('1')
      expect(rejected.state === original).assertFalse()
    })

    it('changes_radix_while_preserving_value', 0, (): void => {
      const decimal: ProgrammerState = ProgrammerConverter.convert('10', Radix.DEC).state
      const binary: ProgrammerOperationResult = ProgrammerConverter.changeRadix(decimal, Radix.BIN)
      expect(binary.error).assertEqual(ProgrammerError.NONE)
      expect(binary.state.radix).assertEqual(Radix.BIN)
      expect(binary.state.input).assertEqual('1010')
      expect(binary.state.result?.dec).assertEqual('10')
    })

    it('supports_backspace_clear_and_recovery', 0, (): void => {
      let state: ProgrammerState = ProgrammerConverter.convert('10', Radix.DEC).state
      state = ProgrammerConverter.backspace(state).state
      expect(state.input).assertEqual('1')
      expect(state.result?.dec).assertEqual('1')
      state = ProgrammerConverter.backspace(state).state
      expect(state.error).assertEqual(ProgrammerError.EMPTY)
      expect(state.result === null).assertTrue()
      state = ProgrammerConverter.appendDigit(state, 'F').state
      expect(state.error).assertEqual(ProgrammerError.INVALID_DIGIT)
      state = ProgrammerConverter.appendDigit(state, '9').state
      expect(state.error).assertEqual(ProgrammerError.NONE)
      expect(state.input).assertEqual('9')
      const cleared: ProgrammerState = ProgrammerConverter.clear(state).state
      const clearedAgain: ProgrammerState = ProgrammerConverter.clear(cleared).state
      expect(clearedAgain.error).assertEqual(ProgrammerError.EMPTY)
      expect(clearedAgain.input).assertEqual('')
    })

    it('creates_default_decimal_empty_state', 0, (): void => {
      const state: ProgrammerState = ProgrammerConverter.initialState()
      expect(state.radix).assertEqual(Radix.DEC)
      expect(state.error).assertEqual(ProgrammerError.EMPTY)
      expect(state.input).assertEqual('')
    })
  })

  describe('ProgrammerModeContract', () => {
    it('defaults_to_normal_and_switches_bidirectionally', 0, (): void => {
      let mode: CalculatorMode = CalculatorMode.NORMAL
      mode = selectCalculatorMode(mode, CalculatorMode.PROGRAMMER)
      expect(mode).assertEqual(CalculatorMode.PROGRAMMER)
      mode = selectCalculatorMode(mode, CalculatorMode.NORMAL)
      expect(mode).assertEqual(CalculatorMode.NORMAL)
    })

    it('is_idempotent_and_last_selection_wins', 0, (): void => {
      let mode: CalculatorMode = selectCalculatorMode(CalculatorMode.NORMAL, CalculatorMode.NORMAL)
      expect(mode).assertEqual(CalculatorMode.NORMAL)
      mode = selectCalculatorMode(mode, CalculatorMode.PROGRAMMER)
      mode = selectCalculatorMode(mode, CalculatorMode.NORMAL)
      mode = selectCalculatorMode(mode, CalculatorMode.PROGRAMMER)
      expect(mode).assertEqual(CalculatorMode.PROGRAMMER)
    })
  })

  describe('ProgrammerPresentationContract', () => {
    it('maps_one_conversion_to_four_result_rows', 0, (): void => {
      const state: ProgrammerState = ProgrammerConverter.convert('10', Radix.DEC).state
      const rows: string[] = programmerResultRows(state)
      expect(rows.length).assertEqual(4)
      expect(rows[0]).assertEqual('BIN  1010')
      expect(rows[1]).assertEqual('OCT  12')
      expect(rows[2]).assertEqual('DEC  10')
      expect(rows[3]).assertEqual('HEX  A')
    })

    it('maps_empty_invalid_and_range_feedback', 0, (): void => {
      expect(programmerFeedback(ProgrammerConverter.initialState())).assertEqual('请输入数值')
      const invalid: ProgrammerState = ProgrammerConverter.appendDigit(ProgrammerConverter.initialState(), 'F').state
      expect(programmerFeedback(invalid)).assertEqual('当前进制不支持该字符')
      const overflow: ProgrammerState = ProgrammerConverter.convert('18446744073709551616', Radix.DEC).state
      expect(programmerFeedback(overflow)).assertEqual('数值超出 U64 支持范围')
      expect(programmerResultRows(overflow).length).assertEqual(0)
    })
  })

  describe('ProgrammerKeyboardContract', () => {
    it('uses_converter_rules_for_keyboard_enablement', 0, (): void => {
      expect(programmerKeyEnabled('2', Radix.BIN)).assertFalse()
      expect(programmerKeyEnabled('7', Radix.OCT)).assertTrue()
      expect(programmerKeyEnabled('8', Radix.OCT)).assertFalse()
      expect(programmerKeyEnabled('F', Radix.DEC)).assertFalse()
      expect(programmerKeyEnabled('F', Radix.HEX)).assertTrue()
    })

    it('disabled_key_submission_keeps_last_valid_value', 0, (): void => {
      const state: ProgrammerState = ProgrammerConverter.convert('1010', Radix.BIN).state
      const result: ProgrammerOperationResult = ProgrammerConverter.appendDigit(state, '9')
      expect(result.error).assertEqual(ProgrammerError.INVALID_DIGIT)
      expect(result.state.input).assertEqual('1010')
      expect(result.state.result?.dec).assertEqual('10')
    })
  })

  describe('ProgrammerRegressionGate', () => {
    it('rejects_unsupported_radix_as_internal_error', 0, (): void => {
      const unsupported: Radix = 3 as Radix
      const result: ProgrammerOperationResult = ProgrammerConverter.convert('10', unsupported)
      expect(result.error).assertEqual(ProgrammerError.INTERNAL)
      expect(result.state.result === null).assertTrue()
    })

    it('round_trips_u64_max_across_all_supported_radices', 0, (): void => {
      let state: ProgrammerState = ProgrammerConverter.convert('18446744073709551615', Radix.DEC).state
      state = ProgrammerConverter.changeRadix(state, Radix.BIN).state
      expect(state.input.length).assertEqual(64)
      state = ProgrammerConverter.changeRadix(state, Radix.OCT).state
      expect(state.input).assertEqual('1777777777777777777777')
      state = ProgrammerConverter.changeRadix(state, Radix.HEX).state
      expect(state.input).assertEqual('FFFFFFFFFFFFFFFF')
      state = ProgrammerConverter.changeRadix(state, Radix.DEC).state
      expect(state.input).assertEqual('18446744073709551615')
    })
  })
}
