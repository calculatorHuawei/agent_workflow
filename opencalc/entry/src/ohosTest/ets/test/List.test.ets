import { Hypium } from '@ohos/hypium'
import expressionTest from './Expression.test'
import calculatorTest from './Calculator.test'

export default function testsuite() {
  expressionTest()
  calculatorTest()
}
