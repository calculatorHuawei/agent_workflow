import { describe, it, expect } from '@ohos/hypium'
import { VoiceUiMatrix, VoiceUiMatrixResult } from '../ohosTest/ets/test/VoiceUiMatrix'

export default function voiceUiMatrixContractTest(): void {
  describe('VoiceUiMatrix', () => {
    it('Task3_1_runs_all_allowlisted_scenarios_without_skips', 0, (): void => {
      const results: VoiceUiMatrixResult[] = VoiceUiMatrix.runAll()
      expect(results.length).assertEqual(11)
      for (let i: number = 0; i < results.length; i++) expect(results[i].executed).assertTrue()
    })
    it('Task3_1_exposes_exact_success_and_failure_oracles', 0, (): void => {
      const integer: VoiceUiMatrixResult = VoiceUiMatrix.run('integerTable')
      expect(integer.expression).assertEqual('123+456')
      expect(integer.result).assertEqual('579')
      expect(integer.historyDelta).assertEqual(1)
      const divide: VoiceUiMatrixResult = VoiceUiMatrix.run('divideByZero')
      expect(divide.expression).assertEqual('9+9')
      expect(divide.result).assertEqual('18')
      expect(divide.historyDelta).assertEqual(0)
    })
    it('Task3_1_all_scenarios_keep_single_start_and_cleanup_invariants', 0, (): void => {
      const results: VoiceUiMatrixResult[] = VoiceUiMatrix.runAll()
      for (let i: number = 0; i < results.length; i++) {
        expect(results[i].gatewayStartCount).assertEqual(1)
        expect(results[i].activeSessionId).assertEqual(1)
        expect(results[i].cleanedUp).assertTrue()
      }
    })
  })
}
