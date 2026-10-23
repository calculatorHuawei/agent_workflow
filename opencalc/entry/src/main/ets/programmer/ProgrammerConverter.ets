import {
  CalculatorMode, ConversionResult, ProgrammerError, ProgrammerOperationResult, ProgrammerState, Radix
} from '../model/Models'

const DIGITS: string = '0123456789ABCDEF'
const U64_MAX_DEC: string = '18446744073709551615'

export function selectCalculatorMode(_current: CalculatorMode, target: CalculatorMode): CalculatorMode {
  return target
}

export function programmerFeedback(state: ProgrammerState): string {
  if (state.error === ProgrammerError.EMPTY) return '请输入数值'
  if (state.error === ProgrammerError.INVALID_DIGIT) return '当前进制不支持该字符'
  if (state.error === ProgrammerError.OUT_OF_RANGE) return '数值超出 U64 支持范围'
  if (state.error === ProgrammerError.INTERNAL) return '转换失败，请重试'
  return ''
}

export function programmerResultRows(state: ProgrammerState): string[] {
  if (state.result === null || state.error !== ProgrammerError.NONE) return []
  return [
    'BIN  ' + state.result.bin,
    'OCT  ' + state.result.oct,
    'DEC  ' + state.result.dec,
    'HEX  ' + state.result.hex
  ]
}

export function programmerKeyEnabled(key: string, radix: Radix): boolean {
  return ProgrammerConverter.isDigitAllowed(key, radix)
}

function trimLeadingZeroes(value: string): string {
  let index: number = 0
  while (index < value.length - 1 && value.charAt(index) === '0') index++
  return value.substring(index)
}

function compareDecimal(left: string, right: string): number {
  const a: string = trimLeadingZeroes(left)
  const b: string = trimLeadingZeroes(right)
  if (a.length < b.length) return -1
  if (a.length > b.length) return 1
  if (a < b) return -1
  if (a > b) return 1
  return 0
}

function multiplyAddDecimal(decimal: string, multiplier: number, addend: number): string {
  let carry: number = addend
  let output: string = ''
  for (let index: number = decimal.length - 1; index >= 0; index--) {
    const digit: number = DIGITS.indexOf(decimal.charAt(index))
    const total: number = digit * multiplier + carry
    output = (total % 10).toString() + output
    carry = Math.floor(total / 10)
  }
  while (carry > 0) {
    output = (carry % 10).toString() + output
    carry = Math.floor(carry / 10)
  }
  return trimLeadingZeroes(output)
}

function divideDecimal(decimal: string, divisor: number): string[] {
  let quotient: string = ''
  let remainder: number = 0
  for (let index: number = 0; index < decimal.length; index++) {
    const current: number = remainder * 10 + DIGITS.indexOf(decimal.charAt(index))
    const q: number = Math.floor(current / divisor)
    if (quotient.length > 0 || q > 0) quotient = quotient + q.toString()
    remainder = current % divisor
  }
  if (quotient.length === 0) quotient = '0'
  return [quotient, remainder.toString()]
}

function decimalToBase(decimal: string, radix: number): string {
  let current: string = trimLeadingZeroes(decimal)
  if (current === '0') return '0'
  let output: string = ''
  while (current !== '0') {
    const divided: string[] = divideDecimal(current, radix)
    const remainder: number = Number(divided[1])
    output = DIGITS.charAt(remainder) + output
    current = divided[0]
  }
  return output
}

function errorResult(radix: Radix, input: string, error: ProgrammerError): ProgrammerOperationResult {
  const state: ProgrammerState = { radix: radix, input: input, result: null, error: error }
  return { state: state, error: error }
}

function maximumInputLength(radix: Radix): number {
  if (radix === Radix.BIN) return 64
  if (radix === Radix.OCT) return 22
  if (radix === Radix.DEC) return 20
  return 16
}

function isSupportedRadix(radix: Radix): boolean {
  return radix === Radix.BIN || radix === Radix.OCT || radix === Radix.DEC || radix === Radix.HEX
}

export class ProgrammerConverter {
  static initialState(): ProgrammerState {
    return { radix: Radix.DEC, input: '', result: null, error: ProgrammerError.EMPTY }
  }

  static isDigitAllowed(digit: string, radix: Radix): boolean {
    if (!isSupportedRadix(radix)) return false
    if (digit.length !== 1) return false
    const value: number = DIGITS.indexOf(digit.toUpperCase())
    return value >= 0 && value < (radix as number)
  }

  static convert(text: string, radix: Radix): ProgrammerOperationResult {
    if (!isSupportedRadix(radix)) return errorResult(radix, text, ProgrammerError.INTERNAL)
    if (text.length === 0) return errorResult(radix, '', ProgrammerError.EMPTY)
    const normalized: string = text.toUpperCase()
    if (normalized.length > maximumInputLength(radix)) {
      return errorResult(radix, normalized, ProgrammerError.OUT_OF_RANGE)
    }
    let decimal: string = '0'
    for (let index: number = 0; index < normalized.length; index++) {
      const digit: string = normalized.charAt(index)
      if (!ProgrammerConverter.isDigitAllowed(digit, radix)) {
        return errorResult(radix, normalized, ProgrammerError.INVALID_DIGIT)
      }
      decimal = multiplyAddDecimal(decimal, radix as number, DIGITS.indexOf(digit))
      if (compareDecimal(decimal, U64_MAX_DEC) > 0) {
        return errorResult(radix, normalized, ProgrammerError.OUT_OF_RANGE)
      }
    }
    decimal = trimLeadingZeroes(decimal)
    const result: ConversionResult = {
      bin: decimalToBase(decimal, 2),
      oct: decimalToBase(decimal, 8),
      dec: decimal,
      hex: decimalToBase(decimal, 16)
    }
    const canonicalInput: string = decimalToBase(decimal, radix as number)
    const state: ProgrammerState = {
      radix: radix, input: canonicalInput, result: result, error: ProgrammerError.NONE
    }
    return { state: state, error: ProgrammerError.NONE }
  }

  static appendDigit(state: ProgrammerState, digit: string): ProgrammerOperationResult {
    const normalized: string = digit.toUpperCase()
    if (!ProgrammerConverter.isDigitAllowed(normalized, state.radix)) {
      const rejected: ProgrammerState = {
        radix: state.radix, input: state.input, result: state.result, error: ProgrammerError.INVALID_DIGIT
      }
      return { state: rejected, error: ProgrammerError.INVALID_DIGIT }
    }
    const nextInput: string = state.input === '0' ? normalized : state.input + normalized
    const converted: ProgrammerOperationResult = ProgrammerConverter.convert(nextInput, state.radix)
    if (converted.error === ProgrammerError.NONE) return converted
    const rejected: ProgrammerState = {
      radix: state.radix, input: state.input, result: state.result, error: converted.error
    }
    return { state: rejected, error: converted.error }
  }

  static backspace(state: ProgrammerState): ProgrammerOperationResult {
    if (state.input.length <= 1) return ProgrammerConverter.clear(state)
    return ProgrammerConverter.convert(state.input.substring(0, state.input.length - 1), state.radix)
  }

  static clear(state: ProgrammerState): ProgrammerOperationResult {
    const cleared: ProgrammerState = {
      radix: state.radix, input: '', result: null, error: ProgrammerError.EMPTY
    }
    return { state: cleared, error: ProgrammerError.EMPTY }
  }

  static changeRadix(state: ProgrammerState, target: Radix): ProgrammerOperationResult {
    if (state.radix === target) {
      const same: ProgrammerState = {
        radix: state.radix, input: state.input, result: state.result, error: state.error
      }
      return { state: same, error: same.error }
    }
    if (state.result === null) {
      const empty: ProgrammerState = {
        radix: target, input: '', result: null, error: ProgrammerError.EMPTY
      }
      return { state: empty, error: ProgrammerError.EMPTY }
    }
    let input: string = state.result.dec
    if (target === Radix.BIN) input = state.result.bin
    else if (target === Radix.OCT) input = state.result.oct
    else if (target === Radix.HEX) input = state.result.hex
    const changed: ProgrammerState = {
      radix: target, input: input, result: state.result, error: ProgrammerError.NONE
    }
    return { state: changed, error: ProgrammerError.NONE }
  }
}
