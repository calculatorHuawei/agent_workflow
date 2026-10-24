import { TipCalculator, TipCalculationResult } from './TipCalculator'

export const TIP_UI_IDS: string[] = [
  'tip-back', 'tip-bill-input', 'tip-percent-0', 'tip-percent-10',
  'tip-percent-15', 'tip-percent-20', 'tip-custom-percent-input',
  'tip-people-input', 'tip-amount-result', 'tip-total-result',
  'tip-per-person-result'
]
export const TIP_ENTRY_IDS: string[] = ['tip-entry-portrait', 'tip-entry-landscape']
export const TIP_PRESENTATION: string = 'calculator-page-overlay'

/** UI-independent source/derived state used by CalculatorPage and local tests. */
export class TipSession {
  billText: string = ''
  peopleText: string = '1'
  presetBasisPoints: number = 1500
  usingCustom: boolean = false
  customPercentText: string = ''
  billTouched: boolean = false
  valid: boolean = false
  billError: string = ''
  percentError: string = ''
  peopleError: string = ''
  tip: string = '--'
  total: string = '--'
  perPerson: string = '--'

  private calculator: TipCalculator = new TipCalculator()

  changeBill(value: string): void {
    this.billText = value
    this.billTouched = true
    this.recalculate()
  }

  changePeople(value: string): void {
    this.peopleText = value
    this.recalculate()
  }

  selectPreset(basisPoints: number): void {
    this.presetBasisPoints = basisPoints
    this.usingCustom = false
    this.customPercentText = ''
    this.recalculate()
  }

  changeCustomPercent(value: string): void {
    this.customPercentText = value
    this.usingCustom = true
    this.recalculate()
  }

  recalculate(): void {
    const basisPoints: number = this.usingCustom ?
      this.calculator.parseCustomPercent(this.customPercentText) :
      this.presetBasisPoints
    const result: TipCalculationResult = this.calculator.evaluate(this.billText, basisPoints, this.peopleText)
    this.valid = result.valid
    this.billError = this.billTouched ? result.errors.bill : ''
    this.percentError = result.errors.percent
    this.peopleError = result.errors.people
    this.tip = result.tip
    this.total = result.total
    this.perPerson = result.perPerson
  }
}
