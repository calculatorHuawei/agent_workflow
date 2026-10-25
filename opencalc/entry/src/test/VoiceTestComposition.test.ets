import { describe, it, expect } from '@ohos/hypium'
import { ScriptedSpeechRecognitionGateway } from '../ohosTest/ets/voice/ScriptedSpeechRecognitionGateway'
import { ScriptedVoiceGatewayFactory } from '../ohosTest/ets/voice/ScriptedVoiceGatewayFactory'
import { VoiceTestScenarioId } from '../ohosTest/ets/voice/VoiceTestScenarioRegistry'
import { VoiceTestEventRecorder } from '../ohosTest/ets/voice/VoiceTestEventRecorder'
import { VoiceEventListener } from '../main/ets/voice/SpeechRecognitionGateway'
import { VoiceEvent } from '../main/ets/voice/VoiceModels'

class CompositionEventListener implements VoiceEventListener {
  onVoiceEvent(_event: VoiceEvent): void {}
}

export default function voiceTestCompositionTest(): void {
  describe('VoiceTestComposition', () => {
    it('Task2_2_test_factory_accepts_only_enum_scenario', 0, (): void => {
      const factory: ScriptedVoiceGatewayFactory = new ScriptedVoiceGatewayFactory(VoiceTestScenarioId.DECIMAL)
      expect(factory.create() instanceof ScriptedSpeechRecognitionGateway).assertTrue()
    })
    it('Task1_1_factory_shares_recorder_and_counts_creations', 0, (): void => {
      const recorder: VoiceTestEventRecorder = new VoiceTestEventRecorder('target-sha', 'integerTable', 0)
      const factory: ScriptedVoiceGatewayFactory = new ScriptedVoiceGatewayFactory(VoiceTestScenarioId.INTEGER_TABLE, recorder)
      const gateway: ScriptedSpeechRecognitionGateway = factory.create() as ScriptedSpeechRecognitionGateway
      expect(recorder.evidence.gatewayCreateCount).assertEqual(1)
      gateway.start(5); gateway.runToCompletion()
      expect(recorder.evidence.gatewayStartCount).assertEqual(1)
    })
    it('Task2_1_factory_marks_permission_return_before_gateway_start', 0, (): void => {
      const recorder: VoiceTestEventRecorder = new VoiceTestEventRecorder('external-manifest', 'integerTable', 0)
      const factory: ScriptedVoiceGatewayFactory = new ScriptedVoiceGatewayFactory(VoiceTestScenarioId.INTEGER_TABLE, recorder)
      expect(recorder.evidence.gatewayStartCount).assertEqual(0)
      const gateway: ScriptedSpeechRecognitionGateway = factory.create() as ScriptedSpeechRecognitionGateway
      gateway.setListener(new CompositionEventListener())
      gateway.start(44); gateway.runToCompletion()
      expect(recorder.evidence.events[0]).assertEqual('0:permissionGranted')
      expect(recorder.evidence.events[1]).assertEqual('0:gatewayCreated')
      expect(recorder.evidence.events[2]).assertEqual('44:gatewayStartInvoked')
      expect(recorder.evidence.events[3]).assertEqual('44:scriptedListening')
    })
  })
}
