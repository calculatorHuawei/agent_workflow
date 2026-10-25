import { describe, it, expect } from '@ohos/hypium'
import { HarmonySpeechRecognitionGateway } from '../main/ets/voice/HarmonySpeechRecognitionGateway'
import { ReleaseVoiceGatewayFactory } from '../main/ets/voice/VoiceGatewayFactory'
import { SpeechRecognitionGateway } from '../main/ets/voice/SpeechRecognitionGateway'

export default function voiceGatewayFactoryTest(): void {
  describe('VoiceGatewayFactory', () => {
    it('Task1_1_release_factory_creates_fresh_real_gateways', 0, (): void => {
      const factory: ReleaseVoiceGatewayFactory = new ReleaseVoiceGatewayFactory()
      const first: SpeechRecognitionGateway = factory.create()
      const second: SpeechRecognitionGateway = factory.create()
      expect(first instanceof HarmonySpeechRecognitionGateway).assertTrue()
      expect(second instanceof HarmonySpeechRecognitionGateway).assertTrue()
      expect(first === second).assertFalse()
    })
  })
}
