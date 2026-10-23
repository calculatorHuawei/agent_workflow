// OpenCalc — 本地单元测试入口（hypium local unit test）
import plotFunctionTest from './PlotFunction.test'
import programmerConverterTest from './ProgrammerConverter.test'

export default function testsuite(): void {
  plotFunctionTest()
  programmerConverterTest()
}
