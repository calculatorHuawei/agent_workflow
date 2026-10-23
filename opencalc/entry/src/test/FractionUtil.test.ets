import { describe, it, expect } from '@ohos/hypium'
import { FractionResult, FractionUtil } from '../main/ets/common/FractionUtil'

function expectFraction(value: number, numerator: number, denominator: number): void {
  const fraction: FractionResult | null = FractionUtil.toFraction(value)
  expect(fraction !== null).assertTrue()
  if (fraction !== null) {
    expect(fraction.numerator).assertEqual(numerator)
    expect(fraction.denominator).assertEqual(denominator)
  }
}

export default function fractionUtilTest(): void {
  describe('FractionUtil', () => {
    it('converts common rational values to reduced fractions', 0, (): void => {
      expectFraction(0.5, 1, 2)
      expectFraction(0.25, 1, 4)
      expectFraction(1 / 3, 1, 3)
      expectFraction(2 / 3, 2, 3)
      expectFraction(0.1 + 0.2, 3, 10)
    })

    it('normalizes sign zero and integer formatting', 0, (): void => {
      expectFraction(-0.5, -1, 2)
      expectFraction(2, 2, 1)
      expect(FractionUtil.format({ numerator: -1, denominator: 2 })).assertEqual('-1/2')
      expect(FractionUtil.format({ numerator: 2, denominator: 1 })).assertEqual('2')
      expect(FractionUtil.format({ numerator: 0, denominator: 1 })).assertEqual('0')
      expect(FractionUtil.format(FractionUtil.toFraction(-0) as FractionResult)).assertEqual('0')
    })

    it('rejects invalid unsafe and unreliable inputs', 0, (): void => {
      expect(FractionUtil.toFraction(NaN) === null).assertTrue()
      expect(FractionUtil.toFraction(Infinity) === null).assertTrue()
      expect(FractionUtil.toFraction(-Infinity) === null).assertTrue()
      expect(FractionUtil.toFraction(0.5, 0) === null).assertTrue()
      expect(FractionUtil.toFraction(Number.MAX_SAFE_INTEGER + 1) === null).assertTrue()
      expect(FractionUtil.toFraction(Math.PI) === null).assertTrue()
      expect(FractionUtil.toFraction(Math.SQRT2) === null).assertTrue()
    })

    it('honors denominator and tolerance gates', 0, (): void => {
      expect(FractionUtil.toFraction(1 / 3, 2) === null).assertTrue()
      expect(FractionUtil.toFraction(1 / 3, 3) !== null).assertTrue()
      expect(FractionUtil.toFraction(0.5, 10000, -1) === null).assertTrue()
    })
  })
}
