// OpenCalc — 本地单元测试入口（hypium local unit test）
import plotFunctionTest from './PlotFunction.test'
import fractionUtilTest from './FractionUtil.test'
import resultDisplayPresenterTest from './ResultDisplayPresenter.test'

export default function testsuite(): void {
  plotFunctionTest()
  fractionUtilTest()
  resultDisplayPresenterTest()
}
