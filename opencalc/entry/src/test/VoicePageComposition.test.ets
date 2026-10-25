import { describe, it, expect } from '@ohos/hypium'
import { SpeechRecognitionGateway } from '../main/ets/voice/SpeechRecognitionGateway'
import { VoiceGatewayFactory, VoiceGatewayProvider } from '../main/ets/voice/VoiceGatewayFactory'
import { FakeSpeechRecognitionGateway } from './FakeSpeechRecognitionGateway'

class RecordingVoiceGatewayFactory implements VoiceGatewayFactory {
  createCount: number = 0
  gateway: FakeSpeechRecognitionGateway = new FakeSpeechRecognitionGateway()
  create(): SpeechRecognitionGateway { this.createCount++; return this.gateway }
}

export default function voicePageCompositionTest(): void {
  describe('VoicePageComposition', () => {
    it('Task1_2_provider_binds_before_page_controller_creation', 0, (): void => {
      const factory: RecordingVoiceGatewayFactory = new RecordingVoiceGatewayFactory()
      VoiceGatewayProvider.bind(factory)
      const gateway: SpeechRecognitionGateway = VoiceGatewayProvider.create()
      expect(gateway === factory.gateway).assertTrue()
      expect(factory.createCount).assertEqual(1)
      VoiceGatewayProvider.bindRelease()
    })
  })
}
