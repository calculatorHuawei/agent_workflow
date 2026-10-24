import { VoiceEvent } from './VoiceModels'

export interface VoiceEventListener {
  onVoiceEvent(event: VoiceEvent): void
}

export interface SpeechRecognitionGateway {
  setListener(listener: VoiceEventListener): void
  start(sessionId: number): void
  cancel(sessionId: number): void
  dispose(): void
}
