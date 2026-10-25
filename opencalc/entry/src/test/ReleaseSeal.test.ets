import { describe, it, expect } from '@ohos/hypium'
import { HarmonySpeechRecognitionGateway } from '../main/ets/voice/HarmonySpeechRecognitionGateway'
import { VoiceGatewayProvider } from '../main/ets/voice/VoiceGatewayFactory'

export default function releaseSealTest(): void {
  describe('ReleaseSeal', () => {
    it('Task3_2_release_binding_has_no_script_activation_route', 0, (): void => {
      VoiceGatewayProvider.bindRelease()
      expect(VoiceGatewayProvider.releaseInjectionReachable()).assertFalse()
      expect(VoiceGatewayProvider.create() instanceof HarmonySpeechRecognitionGateway).assertTrue()
    })
  })
}
