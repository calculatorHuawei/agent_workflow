// OpenCalc — 本地单元测试入口（hypium local unit test）
import plotFunctionTest from './PlotFunction.test'
import tipCalculatorTest from './TipCalculator.test'

export default function testsuite(): void {
  plotFunctionTest()
  tipCalculatorTest()
}
