import { SpeechRecognitionGateway, VoiceEventListener } from './SpeechRecognitionGateway'
import { VoiceEvent } from './VoiceModels'

export interface SpeechPlatformDriver {
  start(listener: (type: string, text: string, error: string) => void): boolean
  stop(): void
}

export class HarmonySpeechRecognitionGateway implements SpeechRecognitionGateway {
  private driver: SpeechPlatformDriver
  private listener: VoiceEventListener | null = null
  private sessionId: number = 0
  private running: boolean = false

  constructor(driver: SpeechPlatformDriver) { this.driver = driver }
  setListener(listener: VoiceEventListener): void { this.listener = listener }
  start(sessionId: number): void {
    if (this.running) { this.emit('error', '', 'BUSY'); return }
    this.sessionId = sessionId
    this.running = true
    const started: boolean = this.driver.start((type: string, text: string, error: string): void => {
      this.onDriverEvent(type, text, error)
    })
    if (!started) { this.running = false; this.emit('error', '', 'SERVICE_UNAVAILABLE') }
  }
  cancel(sessionId: number): void { if (this.running && sessionId === this.sessionId) this.cleanup() }
  dispose(): void { this.cleanup() }
  private onDriverEvent(type: string, text: string, error: string): void {
    if (!this.running) return
    this.emit(type, text, error)
    if (type === 'final' || type === 'empty' || type === 'error') this.cleanup()
  }
  private cleanup(): void { if (!this.running) return; this.running = false; this.driver.stop() }
  private emit(type: string, text: string, error: string): void {
    if (!this.listener) return
    const event: VoiceEvent = new VoiceEvent(); event.sessionId = this.sessionId; event.type = type; event.text = text; event.error = error
    this.listener.onVoiceEvent(event)
  }
}
