import { describe, it, expect } from '@ohos/hypium'
import { VoiceTestEventRecorder } from '../ohosTest/ets/voice/VoiceTestEventRecorder'

export default function voiceTestEvidenceTest(): void {
  describe('VoiceTestEvidence', () => {
    it('Task2_3_records_sha_scenario_cleanup_and_history_delta', 0, (): void => {
      const recorder: VoiceTestEventRecorder = new VoiceTestEventRecorder('target-sha', 'duplicateFinal', 4)
      recorder.record('listening', 7)
      recorder.finish(5, true)
      expect(recorder.evidence.sourceSha).assertEqual('target-sha')
      expect(recorder.evidence.scenarioId).assertEqual('duplicateFinal')
      expect(recorder.evidence.historyDelta).assertEqual(1)
      expect(recorder.evidence.cleanedUp).assertTrue()
      expect(recorder.evidence.events[0]).assertEqual('7:listening')
    })
    it('Task1_1_records_gateway_create_start_and_listening_order', 0, (): void => {
      const recorder: VoiceTestEventRecorder = new VoiceTestEventRecorder('target-sha', 'integerTable', 0)
      expect(recorder.evidence.gatewayCreateCount).assertEqual(0)
      expect(recorder.evidence.gatewayStartCount).assertEqual(0)
      recorder.recordGatewayCreated()
      recorder.recordGatewayStart(31)
      recorder.recordScriptedListening(31)
      expect(recorder.evidence.gatewayCreateCount).assertEqual(1)
      expect(recorder.evidence.gatewayStartCount).assertEqual(1)
      expect(recorder.evidence.activeSessionId).assertEqual(31)
      expect(recorder.evidence.events[0]).assertEqual('0:gatewayCreated')
      expect(recorder.evidence.events[1]).assertEqual('31:gatewayStartInvoked')
      expect(recorder.evidence.events[2]).assertEqual('31:scriptedListening')
    })
  })
}
