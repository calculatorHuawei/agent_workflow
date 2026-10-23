import { ValidationError, ValidationResult } from '../model/RecognitionModels'

export class ExpressionValidator {
  validate(raw: string): ValidationResult {
    const normalized: string = this.normalize(raw)
    if (normalized.length === 0) return new ValidationResult(false, '', ValidationError.EMPTY)
    if (normalized.length > 128) return new ValidationResult(false, normalized, ValidationError.TOO_LONG)
    for (let i: number = 0; i < normalized.length; i++) {
      const c: string = normalized.charAt(i)
      if (!this.isDigit(c) && c !== '.' && c !== '+' && c !== '-' && c !== '*' && c !== '/' && c !== '(' && c !== ')') {
        return new ValidationResult(false, normalized, ValidationError.UNSUPPORTED_CHARACTER)
      }
    }
    if (!this.hasValidGrammar(normalized)) return new ValidationResult(false, normalized, ValidationError.SYNTAX)
    return new ValidationResult(true, normalized, ValidationError.NONE)
  }

  normalize(raw: string): string {
    let result: string = ''
    for (let i: number = 0; i < raw.length; i++) {
      let c: string = raw.charAt(i)
      if (c === ' ' || c === '\t' || c === '\r' || c === '\n') continue
      if (c === '×' || c === 'x' || c === 'X') c = '*'
      else if (c === '÷') c = '/'
      else if (c === '−' || c === '–' || c === '—') c = '-'
      result = result + c
    }
    return result
  }

  private isDigit(c: string): boolean { return c >= '0' && c <= '9' }

  private hasValidGrammar(text: string): boolean {
    let expectOperand: boolean = true
    let depth: number = 0
    let i: number = 0
    while (i < text.length) {
      const c: string = text.charAt(i)
      if (expectOperand) {
        if (c === '+' || c === '-') {
          if (i !== 0 && text.charAt(i - 1) !== '(') return false
          i++
          continue
        }
        if (c === '(') { depth++; i++; continue }
        if (!this.isDigit(c) && c !== '.') return false
        let digits: number = 0
        let dots: number = 0
        while (i < text.length && (this.isDigit(text.charAt(i)) || text.charAt(i) === '.')) {
          if (text.charAt(i) === '.') dots++
          else digits++
          i++
        }
        if (digits === 0 || dots > 1) return false
        expectOperand = false
      } else {
        if (c === ')') {
          if (depth === 0) return false
          depth--
          i++
          continue
        }
        if (c !== '+' && c !== '-' && c !== '*' && c !== '/') return false
        expectOperand = true
        i++
      }
    }
    return !expectOperand && depth === 0
  }
}
