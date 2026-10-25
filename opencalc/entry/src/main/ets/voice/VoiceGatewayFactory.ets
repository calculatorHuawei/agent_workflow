import { CoreSpeechPlatformDriver } from './CoreSpeechPlatformDriver'
import { HarmonySpeechRecognitionGateway } from './HarmonySpeechRecognitionGateway'
import { SpeechRecognitionGateway } from './SpeechRecognitionGateway'

export interface VoiceGatewayFactory {
  create(): SpeechRecognitionGateway
}

/** Release composition: no scenario, Want, URI, environment, or transcript input. */
export class ReleaseVoiceGatewayFactory implements VoiceGatewayFactory {
  create(): SpeechRecognitionGateway {
    return new HarmonySpeechRecognitionGateway(new CoreSpeechPlatformDriver())
  }
}

/** Composition slot. Release startup always seals it back to the release factory. */
export class VoiceGatewayProvider {
  private static factory: VoiceGatewayFactory = new ReleaseVoiceGatewayFactory()

  static bind(factory: VoiceGatewayFactory): void { VoiceGatewayProvider.factory = factory }
  static bindRelease(): void { VoiceGatewayProvider.factory = new ReleaseVoiceGatewayFactory() }
  static create(): SpeechRecognitionGateway { return VoiceGatewayProvider.factory.create() }
  static releaseInjectionReachable(): boolean { return false }
}
