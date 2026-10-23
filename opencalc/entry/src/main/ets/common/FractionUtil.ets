export interface FractionResult {
  numerator: number
  denominator: number
}

export class FractionUtil {
  static gcd(a: number, b: number): number {
    let left: number = Math.abs(Math.trunc(a))
    let right: number = Math.abs(Math.trunc(b))
    while (right !== 0) {
      const remainder: number = left % right
      left = right
      right = remainder
    }
    return left
  }

  static toFraction(
    value: number,
    maxDenominator: number = 10000,
    tolerance: number = 1e-12
  ): FractionResult | null {
    if (!Number.isFinite(value) || !Number.isSafeInteger(maxDenominator) || maxDenominator < 1 ||
      !Number.isFinite(tolerance) || tolerance <= 0) {
      return null
    }

    const sign: number = value < 0 ? -1 : 1
    const absolute: number = Math.abs(value)
    if (absolute === 0) {
      return { numerator: 0, denominator: 1 }
    }
    if (Number.isInteger(absolute)) {
      if (!Number.isSafeInteger(absolute)) {
        return null
      }
      return { numerator: sign * absolute, denominator: 1 }
    }

    let x: number = absolute
    let previousNumerator: number = 0
    let numerator: number = 1
    let previousDenominator: number = 1
    let denominator: number = 0
    let bestNumerator: number = 0
    let bestDenominator: number = 0

    for (let iteration: number = 0; iteration < 32; iteration++) {
      const coefficient: number = Math.floor(x)
      if (!Number.isSafeInteger(coefficient)) {
        return null
      }
      const nextNumerator: number = coefficient * numerator + previousNumerator
      const nextDenominator: number = coefficient * denominator + previousDenominator
      if (!Number.isSafeInteger(nextNumerator) || !Number.isSafeInteger(nextDenominator)) {
        break
      }
      if (nextDenominator > maxDenominator) {
        break
      }

      bestNumerator = nextNumerator
      bestDenominator = nextDenominator
      previousNumerator = numerator
      numerator = nextNumerator
      previousDenominator = denominator
      denominator = nextDenominator

      const fractionalPart: number = x - coefficient
      if (fractionalPart === 0) {
        break
      }
      x = 1 / fractionalPart
      if (!Number.isFinite(x)) {
        break
      }
    }

    if (bestDenominator === 0) {
      return null
    }
    const divisor: number = FractionUtil.gcd(bestNumerator, bestDenominator)
    if (divisor === 0) {
      return null
    }
    const normalizedNumerator: number = sign * (bestNumerator / divisor)
    const normalizedDenominator: number = bestDenominator / divisor
    if (!Number.isSafeInteger(normalizedNumerator) || !Number.isSafeInteger(normalizedDenominator) ||
      normalizedDenominator < 1 || normalizedDenominator > maxDenominator) {
      return null
    }

    const allowedError: number = Math.max(tolerance, absolute * tolerance)
    if (Math.abs(normalizedNumerator / normalizedDenominator - value) > allowedError) {
      return null
    }
    return { numerator: normalizedNumerator, denominator: normalizedDenominator }
  }

  static format(value: FractionResult): string {
    if (value.denominator === 1) {
      return value.numerator.toString()
    }
    return value.numerator.toString() + '/' + value.denominator.toString()
  }
}
