import { SpeechRecognitionGateway, VoiceEventListener } from '../main/ets/voice/SpeechRecognitionGateway'
import { VoiceEvent } from '../main/ets/voice/VoiceModels'

export class FakeSpeechRecognitionGateway implements SpeechRecognitionGateway {
  cancelCount: number = 0
  disposeCount: number = 0
  startCount: number = 0
  private sessionId: number = 0
  private listener: VoiceEventListener | null = null

  setListener(listener: VoiceEventListener): void { this.listener = listener }
  start(sessionId: number): void { this.sessionId = sessionId; this.startCount++ }
  cancel(_sessionId: number): void { this.cancelCount++ }
  dispose(): void { this.disposeCount++ }
  listening(): void { this.emit('listening', '', '') }
  recognizing(): void { this.emit('recognizing', '', '') }
  partial(text: string): void { this.emit('partial', text, '') }
  finalResult(text: string): void { this.emit('final', text, '') }
  empty(): void { this.emit('empty', '', 'EMPTY') }
  error(code: string): void { this.emit('error', '', code) }
  delayedFinal(sessionId: number, text: string): void {
    const event: VoiceEvent = new VoiceEvent(); event.sessionId = sessionId; event.type = 'final'; event.text = text
    if (this.listener) this.listener.onVoiceEvent(event)
  }
  private emit(type: string, text: string, error: string): void {
    const event: VoiceEvent = new VoiceEvent(); event.sessionId = this.sessionId; event.type = type; event.text = text; event.error = error
    if (this.listener) this.listener.onVoiceEvent(event)
  }
}
