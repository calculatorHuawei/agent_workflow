// OpenCalc — 本地单元测试入口（hypium local unit test）
import plotFunctionTest from './PlotFunction.test'
import matrixEngineTest from './MatrixEngine.test'

export default function testsuite(): void {
  plotFunctionTest()
  matrixEngineTest()
}
