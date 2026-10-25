import { describe, it, expect } from '@ohos/hypium'
import { ScriptedSpeechRecognitionGateway } from '../ohosTest/ets/voice/ScriptedSpeechRecognitionGateway'
import { ScriptedVoiceGatewayFactory } from '../ohosTest/ets/voice/ScriptedVoiceGatewayFactory'
import { VoiceTestScenarioId } from '../ohosTest/ets/voice/VoiceTestScenarioRegistry'

export default function voiceTestCompositionTest(): void {
  describe('VoiceTestComposition', () => {
    it('Task2_2_test_factory_accepts_only_enum_scenario', 0, (): void => {
      const factory: ScriptedVoiceGatewayFactory = new ScriptedVoiceGatewayFactory(VoiceTestScenarioId.DECIMAL)
      expect(factory.create() instanceof ScriptedSpeechRecognitionGateway).assertTrue()
    })
  })
}
