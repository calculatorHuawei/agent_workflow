// Basic expression preprocessor for the agent increment baseline.
import { ErrorFlags } from '../model/ErrorFlags'

export class Expression {
  getCleanExpression(calculation: string, decimalSeparatorSymbol: string, groupingSeparatorSymbol: string): string {
    let clean: string = this.replaceAll(calculation, '×', '*')
    clean = this.replaceAll(clean, '÷', '/')
    clean = this.replaceAll(clean, groupingSeparatorSymbol, '')
    if (decimalSeparatorSymbol !== '.') clean = this.replaceAll(clean, decimalSeparatorSymbol, '.')
    clean = this.addImplicitMultiplication(clean)
    return this.addParenthesis(clean)
  }

  private addImplicitMultiplication(calculation: string): string {
    let clean: string = calculation
    let i: number = 0
    while (i < clean.length) {
      const ch: string = clean.charAt(i)
      if (ch === '(' && i > 0 && '.0123456789)'.indexOf(clean.charAt(i - 1)) !== -1) {
        clean = this.insertChar(clean, '*', i)
        i = i + 1
      } else if (ch === ')' && i + 1 < clean.length && '.0123456789('.indexOf(clean.charAt(i + 1)) !== -1) {
        clean = this.insertChar(clean, '*', i + 1)
        i = i + 1
      }
      i = i + 1
    }
    return clean
  }

  addParenthesis(calculation: string): string {
    let clean: string = calculation
    let openCount: number = 0
    let closeCount: number = 0
    for (let i: number = 0; i < calculation.length; i++) {
      if (calculation.charAt(i) === '(') openCount = openCount + 1
      if (calculation.charAt(i) === ')') closeCount = closeCount + 1
    }
    if (closeCount < openCount) {
      for (let i: number = 0; i < openCount - closeCount; i++) clean = clean + ')'
    }
    if (closeCount > openCount) ErrorFlags.syntax_error = true
    return clean
  }

  private insertChar(text: string, value: string, index: number): string {
    return text.substring(0, index) + value + text.substring(index)
  }

  private replaceAll(text: string, from: string, to: string): string {
    let result: string = text
    let index: number = result.indexOf(from)
    while (index !== -1) {
      result = result.substring(0, index) + to + result.substring(index + from.length)
      index = result.indexOf(from, index + to.length)
    }
    return result
  }
}
