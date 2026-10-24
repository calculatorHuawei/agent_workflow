// OpenCalc — 本地单元测试入口（hypium local unit test）
import plotFunctionTest from './PlotFunction.test'
import voiceFeatureTest from './VoiceFeature.test'

export default function testsuite(): void {
  plotFunctionTest()
  voiceFeatureTest()
}
