import { describe, it, expect } from '@ohos/hypium'
import { VoiceUiMatrix, VoiceUiMatrixResult } from './VoiceUiMatrix'

export default function voiceUiMatrixTest(): void {
  describe('VoiceUiDeviceMatrix', () => {
    it('executes_all_allowlisted_scenarios', 0, (): void => {
      const results: VoiceUiMatrixResult[] = VoiceUiMatrix.runAll()
      expect(results.length).assertEqual(11)
      for (let i: number = 0; i < results.length; i++) expect(results[i].executed).assertTrue()
    })
  })
}
