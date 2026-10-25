// OpenCalc — 本地单元测试入口（hypium local unit test）
import plotFunctionTest from './PlotFunction.test'
import voiceFeatureTest from './VoiceFeature.test'
import voiceGatewayFactoryTest from './VoiceGatewayFactory.test'
import voicePageCompositionTest from './VoicePageComposition.test'
import scriptedGatewayTest from './ScriptedGateway.test'
import voiceTestCompositionTest from './VoiceTestComposition.test'
import voiceTestEvidenceTest from './VoiceTestEvidence.test'
import voiceUiMatrixContractTest from './VoiceUiMatrixContract.test'
import releaseSealTest from './ReleaseSeal.test'

export default function testsuite(): void {
  plotFunctionTest()
  voiceFeatureTest()
  voiceGatewayFactoryTest()
  voicePageCompositionTest()
  scriptedGatewayTest()
  voiceTestCompositionTest()
  voiceTestEvidenceTest()
  voiceUiMatrixContractTest()
  releaseSealTest()
}
