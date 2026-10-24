// Issue #50 — deterministic, side-effect-free tip calculation.
export interface TipErrors {
  bill: string
  percent: string
  people: string
}

export interface TipCalculationResult {
  valid: boolean
  errors: TipErrors
  tip: string
  total: string
  perPerson: string
}

const INVALID_DISPLAY: string = '--'
const MAX_BILL_CENTS: number = Math.floor(Number.MAX_SAFE_INTEGER / 10000)

export class TipCalculator {
  evaluate(billText: string, tipBasisPoints: number, peopleText: string): TipCalculationResult {
    const errors: TipErrors = { bill: '', percent: '', people: '' }
    const billCents: number = this.parseBillCents(billText)
    if (billText.length === 0) { errors.bill = '请输入账单金额' } else if (billCents === -2) {
      errors.bill = '账单金额过大'
    } else if (billCents < 0) {
      errors.bill = '账单金额必须为非负数字，最多两位小数'
    }

    if (!Number.isSafeInteger(tipBasisPoints) || tipBasisPoints < 0 || tipBasisPoints > 10000) {
      errors.percent = '小费比例必须为 0%–100%，最多两位小数'
    }

    const people: number = this.parsePeople(peopleText)
    if (people < 1) { errors.people = '人数必须为不小于 1 的整数' }

    if (errors.bill.length > 0 || errors.percent.length > 0 || errors.people.length > 0) {
      return this.invalid(errors)
    }

    const tipCents: number = Math.floor((billCents * tipBasisPoints + 5000) / 10000)
    const totalCents: number = billCents + tipCents
    if (!Number.isSafeInteger(tipCents) || !Number.isSafeInteger(totalCents)) {
      errors.bill = '账单金额过大'
      return this.invalid(errors)
    }
    const perPersonCents: number = Math.floor((totalCents + people / 2) / people)
    return {
      valid: true,
      errors: errors,
      tip: this.formatCents(tipCents),
      total: this.formatCents(totalCents),
      perPerson: this.formatCents(perPersonCents)
    }
  }

  parseCustomPercent(text: string): number {
    if (!this.isUnsignedDecimal(text)) { return -1 }
    const parts: string[] = text.split('.')
    const whole: number = Number(parts[0])
    if (!Number.isSafeInteger(whole)) { return -1 }
    let fraction: number = 0
    if (parts.length === 2) { fraction = Number(parts[1].length === 1 ? parts[1] + '0' : parts[1]) }
    const basisPoints: number = whole * 100 + fraction
    if (!Number.isSafeInteger(basisPoints) || basisPoints < 0 || basisPoints > 10000) { return -1 }
    return basisPoints
  }

  private parseBillCents(text: string): number {
    if (!this.isUnsignedDecimal(text)) { return -1 }
    const parts: string[] = text.split('.')
    const whole: number = Number(parts[0])
    if (!Number.isSafeInteger(whole)) { return -2 }
    let fraction: number = 0
    if (parts.length === 2) { fraction = Number(parts[1].length === 1 ? parts[1] + '0' : parts[1]) }
    const cents: number = whole * 100 + fraction
    if (!Number.isSafeInteger(cents) || cents > MAX_BILL_CENTS) { return -2 }
    return cents
  }

  private parsePeople(text: string): number {
    if (text.length === 0 || !/^[1-9][0-9]*$/.test(text)) { return -1 }
    const people: number = Number(text)
    if (!Number.isSafeInteger(people) || people < 1) { return -1 }
    return people
  }

  private isUnsignedDecimal(text: string): boolean {
    return /^(0|[1-9][0-9]*)(\.[0-9]{1,2})?$/.test(text)
  }

  private formatCents(cents: number): string {
    const whole: number = Math.floor(cents / 100)
    const fraction: number = cents % 100
    return whole.toString() + '.' + (fraction < 10 ? '0' : '') + fraction.toString()
  }

  private invalid(errors: TipErrors): TipCalculationResult {
    return {
      valid: false,
      errors: errors,
      tip: INVALID_DISPLAY,
      total: INVALID_DISPLAY,
      perPerson: INVALID_DISPLAY
    }
  }
}
