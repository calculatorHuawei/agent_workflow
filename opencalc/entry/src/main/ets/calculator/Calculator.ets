// Basic calculator engine for the agent increment baseline.
import { ErrorFlags } from '../model/ErrorFlags'

/**
 * Recursive-descent parser limited to decimal numbers, parentheses,
 * unary signs, and the four arithmetic operations.
 */
export class CalcEngine {
  private eq: string = ''
  private p: number = -1
  private c: number = 0

  evaluate(equation: string): number {
    this.eq = equation
    this.p = -1
    this.c = 0
    this.nx()
    const result: number = this.parseExpression()
    if (this.c !== -1) ErrorFlags.syntax_error = true
    return result
  }

  private nx(): void {
    this.p = this.p + 1
    this.c = this.p < this.eq.length ? this.eq.charCodeAt(this.p) : -1
  }

  private eat(ch: number): boolean {
    while (this.c === 32) this.nx()
    if (this.c !== ch) return false
    this.nx()
    return true
  }

  private parseExpression(): number {
    let value: number = this.parseTerm()
    while (true) {
      if (this.eat(43)) value = value + this.parseTerm()
      else if (this.eat(45)) value = value - this.parseTerm()
      else return value
    }
  }

  private parseTerm(): number {
    let value: number = this.parseFactor()
    while (true) {
      if (this.eat(42)) value = value * this.parseFactor()
      else if (this.eat(47)) {
        const divisor: number = this.parseFactor()
        if (divisor === 0) {
          ErrorFlags.division_by_0 = true
          value = 0
        } else {
          value = value / divisor
        }
      } else return value
    }
  }

  private parseFactor(): number {
    if (this.eat(43)) return this.parseFactor()
    if (this.eat(45)) return -this.parseFactor()

    if (this.eat(40)) {
      const nested: number = this.parseExpression()
      if (!this.eat(41)) ErrorFlags.syntax_error = true
      return nested
    }

    if ((this.c >= 48 && this.c <= 57) || this.c === 46) {
      const start: number = this.p
      while ((this.c >= 48 && this.c <= 57) || this.c === 46) this.nx()
      const numberText: string = this.eq.substring(start, this.p)
      if (numberText.split('.').length - 1 > 1 || numberText === '.') {
        ErrorFlags.syntax_error = true
        return 0
      }
      return parseFloat(numberText)
    }

    ErrorFlags.syntax_error = true
    if (this.c !== -1) this.nx()
    return 0
  }
}
