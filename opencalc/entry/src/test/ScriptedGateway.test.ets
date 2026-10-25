import { describe, it, expect } from '@ohos/hypium'
import { VoiceEvent } from '../main/ets/voice/VoiceModels'
import { VoiceEventListener } from '../main/ets/voice/SpeechRecognitionGateway'
import { ScriptedSpeechRecognitionGateway } from '../ohosTest/ets/voice/ScriptedSpeechRecognitionGateway'
import { VoiceTestScenarioId, VoiceTestScenarioRegistry } from '../ohosTest/ets/voice/VoiceTestScenarioRegistry'

class ScriptEventListener implements VoiceEventListener {
  events: VoiceEvent[] = []
  onVoiceEvent(event: VoiceEvent): void { this.events.push(event) }
}

export default function scriptedGatewayTest(): void {
  describe('ScriptedGateway', () => {
    it('Task2_1_registry_is_allowlisted_and_unknown_fails_closed', 0, (): void => {
      expect(VoiceTestScenarioRegistry.ids().length).assertEqual(11)
      expect(VoiceTestScenarioRegistry.resolve('arbitraryTranscript')).assertNull()
    })
    it('Task2_1_success_script_is_ordered_and_session_scoped', 0, (): void => {
      const listener: ScriptEventListener = new ScriptEventListener()
      const gateway: ScriptedSpeechRecognitionGateway = new ScriptedSpeechRecognitionGateway(VoiceTestScenarioId.INTEGER_TABLE)
      gateway.setListener(listener); gateway.start(42); gateway.runToCompletion()
      expect(listener.events[0].type).assertEqual('listening')
      expect(listener.events[1].type).assertEqual('recognizing')
      expect(listener.events[2].type).assertEqual('final')
      expect(listener.events[2].sessionId).assertEqual(42)
      expect(listener.events[2].text).assertEqual('123加456')
    })
  })
}
