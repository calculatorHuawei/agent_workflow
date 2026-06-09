import { describe, it, expect } from '@ohos/hypium'
import { Expression } from '../../../main/ets/calculator/Expression'

describe('Expression Test', () => {
  const expr = new Expression()

  it('testPercentAddition', 0, () => {
    // 50+10% = 50 + (10% of 50) = 55
    const result = expr.getCleanExpression('50+10%', '.', ',')
    console.log('50+10% => ' + result)
    expect(result).assertEqual('50+50*(10/100)')
  })

  it('testPercentSubtraction', 0, () => {
    // 100-20% = 100 - (20% of 100) = 80
    const result = expr.getCleanExpression('100-20%', '.', ',')
    console.log('100-20% => ' + result)
    expect(result).assertEqual('100-100*(20/100)')
  })

  it('testPercentMultiplication', 0, () => {
    // 200*5% = 200 * (5/100) = 10
    const result = expr.getCleanExpression('200*5%', '.', ',')
    console.log('200*5% => ' + result)
    expect(result).assertEqual('200*(5/100)')
  })

  it('testPercentDivision', 0, () => {
    // 50/10% = 50 / (10/100) = 500
    const result = expr.getCleanExpression('50/10%', '.', ',')
    console.log('50/10% => ' + result)
    expect(result).assertEqual('50/(10/100)')
  })

  it('testPercentAlone', 0, () => {
    // 100% = 1
    const result = expr.getCleanExpression('100%', '.', ',')
    console.log('100% => ' + result)
    expect(result).assertEqual('(100/100)')
  })

  it('testPercentDecimal', 0, () => {
    // 50+12.5% = 50 + (12.5% of 50) = 56.25
    const result = expr.getCleanExpression('50+12.5%', '.', ',')
    console.log('50+12.5% => ' + result)
    expect(result).assertEqual('50+50*(12.5/100)')
  })

  it('testNoPercent', 0, () => {
    // Simple expression without %
    const result = expr.getCleanExpression('50+10', '.', ',')
    console.log('50+10 => ' + result)
    expect(result).assertEqual('50+10')
  })
})
