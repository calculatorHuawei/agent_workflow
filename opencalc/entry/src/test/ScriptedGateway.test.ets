import { describe, it, expect } from '@ohos/hypium'
import { VoiceEvent } from '../main/ets/voice/VoiceModels'
import { VoiceEventListener } from '../main/ets/voice/SpeechRecognitionGateway'
import { ScriptedSpeechRecognitionGateway } from '../ohosTest/ets/voice/ScriptedSpeechRecognitionGateway'
import { VoiceTestScenarioId, VoiceTestScenarioRegistry } from '../ohosTest/ets/voice/VoiceTestScenarioRegistry'
import { VoiceTestEventRecorder } from '../ohosTest/ets/voice/VoiceTestEventRecorder'

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
    it('Task1_1_duplicate_start_keeps_one_session_and_one_start_record', 0, (): void => {
      const listener: ScriptEventListener = new ScriptEventListener()
      const recorder: VoiceTestEventRecorder = new VoiceTestEventRecorder('target-sha', 'duplicateStart', 0)
      const gateway: ScriptedSpeechRecognitionGateway = new ScriptedSpeechRecognitionGateway(VoiceTestScenarioId.DUPLICATE_START)
      gateway.setListener(listener); gateway.setRecorder(recorder)
      gateway.start(9); gateway.start(10); gateway.runToCompletion(); gateway.dispose()
      expect(recorder.evidence.gatewayStartCount).assertEqual(1)
      expect(recorder.evidence.activeSessionId).assertEqual(9)
      expect(recorder.evidence.events[0]).assertEqual('9:gatewayStartInvoked')
      expect(recorder.evidence.events[1]).assertEqual('9:scriptedListening')
      expect(recorder.evidence.cleanedUp).assertTrue()
    })
    it('Task1_1_cancel_cleans_up_and_late_final_keeps_start_count', 0, (): void => {
      const listener: ScriptEventListener = new ScriptEventListener()
      const recorder: VoiceTestEventRecorder = new VoiceTestEventRecorder('target-sha', 'cancelLateCallback', 0)
      const gateway: ScriptedSpeechRecognitionGateway = new ScriptedSpeechRecognitionGateway(VoiceTestScenarioId.CANCEL_LATE_CALLBACK)
      gateway.setListener(listener); gateway.setRecorder(recorder)
      gateway.start(18); gateway.cancel(18); gateway.emitLateFinal('allowlisted-fixture')
      expect(recorder.evidence.cleanedUp).assertTrue()
      expect(recorder.evidence.gatewayStartCount).assertEqual(1)
    })
  })
}
