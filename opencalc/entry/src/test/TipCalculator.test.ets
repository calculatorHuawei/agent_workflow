// Issue #50 — tip calculator logic contract (AC-002..AC-009)
import { describe, it, expect } from '@ohos/hypium'
import { TipCalculator, TipCalculationResult } from '../main/ets/tip/TipCalculator'
import { TIP_UI_IDS, TIP_ENTRY_IDS, TIP_PRESENTATION } from '../main/ets/tip/TipContract'

function expectAmounts(result: TipCalculationResult, tip: string, total: string, perPerson: string): void {
  expect(result.valid).assertTrue()
  expect(result.tip).assertEqual(tip)
  expect(result.total).assertEqual(total)
  expect(result.perPerson).assertEqual(perPerson)
}

function expectInvalid(result: TipCalculationResult): void {
  expect(result.valid).assertFalse()
  expect(result.tip).assertEqual('--')
  expect(result.total).assertEqual('--')
  expect(result.perPerson).assertEqual('--')
}

export default function tipCalculatorTest(): void {
  describe('TipCalculator', () => {
    const calculator: TipCalculator = new TipCalculator()

    it('AC_002_calculates_100_at_15_percent_for_two', 0, (): void => {
      expectAmounts(calculator.evaluate('100', 1500, '2'), '15.00', '115.00', '57.50')
    })

    it('AC_011_evaluates_each_visible_input_snapshot_independently', 0, (): void => {
      const first: TipCalculationResult = calculator.evaluate('100', 1500, '2')
      const second: TipCalculationResult = calculator.evaluate('101', 1500, '2')
      expectAmounts(first, '15.00', '115.00', '57.50')
      expectAmounts(second, '15.15', '116.15', '58.08')
      expect(first.tip + '|' + first.total + '|' + first.perPerson)
        .assertEqual('15.00|115.00|57.50')
    })

    it('AC_003_calculates_88_80_at_10_percent_for_three', 0, (): void => {
      expectAmounts(calculator.evaluate('88.80', 1000, '3'), '8.88', '97.68', '32.56')
    })

    it('AC_004_supports_zero_percent', 0, (): void => {
      expectAmounts(calculator.evaluate('100', 0, '3'), '0.00', '100.00', '33.33')
    })

    it('AC_006_rounds_half_up_and_formats_two_decimals', 0, (): void => {
      expectAmounts(calculator.evaluate('10', 1000, '3'), '1.00', '11.00', '3.67')
    })

    it('AC_005_evaluates_the_ordered_event_snapshots', 0, (): void => {
      expectAmounts(calculator.evaluate('200', 1000, '2'), '20.00', '220.00', '110.00')
      expectAmounts(calculator.evaluate('200', 2000, '2'), '40.00', '240.00', '120.00')
      expectAmounts(calculator.evaluate('200', 2000, '4'), '40.00', '240.00', '60.00')
      const customBasisPoints: number = calculator.parseCustomPercent('12.5')
      expectAmounts(calculator.evaluate('200', customBasisPoints, '4'), '25.00', '225.00', '56.25')
    })

    it('AC_007_rejects_invalid_bill_values_and_recovers', 0, (): void => {
      const invalidBills: string[] = ['', 'abc', '-1', '1.234', '90071992547410.91']
      for (let i: number = 0; i < invalidBills.length; i++) {
        const result: TipCalculationResult = calculator.evaluate(invalidBills[i], 1500, '2')
        expectInvalid(result)
        expect(result.errors.bill.length > 0).assertTrue()
      }
      expectAmounts(calculator.evaluate('100', 1500, '2'), '15.00', '115.00', '57.50')
    })

    it('AC_008_rejects_invalid_people_before_division_and_recovers', 0, (): void => {
      const invalidPeople: string[] = ['', '0', '-1', '1.5', 'abc']
      for (let i: number = 0; i < invalidPeople.length; i++) {
        const result: TipCalculationResult = calculator.evaluate('100', 1500, invalidPeople[i])
        expectInvalid(result)
        expect(result.errors.people.length > 0).assertTrue()
      }
      expectAmounts(calculator.evaluate('100', 1500, '2'), '15.00', '115.00', '57.50')
    })

    it('AC_009_parses_custom_percent_boundaries', 0, (): void => {
      expect(calculator.parseCustomPercent('0')).assertEqual(0)
      expect(calculator.parseCustomPercent('12.5')).assertEqual(1250)
      expect(calculator.parseCustomPercent('100')).assertEqual(10000)
      const invalidPercents: string[] = ['', '-0.01', '100.01', 'abc', '1.234']
      for (let i: number = 0; i < invalidPercents.length; i++) {
        expect(calculator.parseCustomPercent(invalidPercents[i])).assertEqual(-1)
      }
    })

    it('AC_009_rejects_invalid_basis_points', 0, (): void => {
      const below: TipCalculationResult = calculator.evaluate('100', -1, '2')
      const above: TipCalculationResult = calculator.evaluate('100', 10001, '2')
      expectInvalid(below)
      expectInvalid(above)
      expect(below.errors.percent.length > 0).assertTrue()
      expect(above.errors.percent.length > 0).assertTrue()
    })
  })

  describe('Tip UI contract', () => {
    it('AC_011_exposes_stable_UI_identifiers', 0, (): void => {
      const required: string[] = [
        'tip-back', 'tip-bill-input', 'tip-percent-0', 'tip-percent-10',
        'tip-percent-15', 'tip-percent-20', 'tip-custom-percent-input',
        'tip-people-input', 'tip-amount-result', 'tip-total-result',
        'tip-per-person-result'
      ]
      expect(TIP_UI_IDS.length).assertEqual(required.length)
      for (let i: number = 0; i < required.length; i++) {
        expect(TIP_UI_IDS[i]).assertEqual(required[i])
      }
    })

    it('AC_001_AC_010_uses_two_entries_and_an_isolated_overlay', 0, (): void => {
      expect(TIP_ENTRY_IDS.length).assertEqual(2)
      expect(TIP_ENTRY_IDS[0]).assertEqual('tip-entry-portrait')
      expect(TIP_ENTRY_IDS[1]).assertEqual('tip-entry-landscape')
      expect(TIP_PRESENTATION).assertEqual('calculator-page-overlay')
    })
  })
}
