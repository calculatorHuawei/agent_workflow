import { SpeechRecognitionGateway, VoiceEventListener } from '../../../main/ets/voice/SpeechRecognitionGateway'
import { VoiceEvent } from '../../../main/ets/voice/VoiceModels'
import { VoiceTestScenario, VoiceScriptEvent } from './VoiceTestScenario'
import { VoiceTestScenarioId, VoiceTestScenarioRegistry } from './VoiceTestScenarioRegistry'
import { VoiceTestEventRecorder } from './VoiceTestEventRecorder'

export class ScriptedSpeechRecognitionGateway implements SpeechRecognitionGateway {
  private scenario: VoiceTestScenario
  private listener: VoiceEventListener | null = null
  private sessionId: number = 0
  private running: boolean = false
  private recorder: VoiceTestEventRecorder | null = null
  private autoRun: boolean = false
  cancelCount: number = 0
  disposeCount: number = 0

  constructor(id: VoiceTestScenarioId, autoRun: boolean = false) {
    const resolved: VoiceTestScenario | null = VoiceTestScenarioRegistry.resolve(id)
    this.scenario = resolved ? resolved : new VoiceTestScenario('', [])
    this.autoRun = autoRun
  }

  setListener(listener: VoiceEventListener): void { this.listener = listener }
  setRecorder(recorder: VoiceTestEventRecorder): void { this.recorder = recorder }
  start(sessionId: number): void {
    if (this.running) return
    this.running = true; this.sessionId = sessionId
    if (this.recorder) this.recorder.recordGatewayStart(sessionId)
    if (this.autoRun) this.schedule(0)
  }
  cancel(sessionId: number): void {
    if (sessionId === this.sessionId && this.running) {
      this.running = false
      this.cancelCount++
      if (this.recorder) {
        this.recorder.record('cancelled', sessionId)
        this.recorder.markCleanedUp(sessionId)
      }
    }
  }
  dispose(): void {
    if (this.running) this.running = false
    this.disposeCount++
    if (this.recorder) this.recorder.markCleanedUp(this.sessionId)
  }
  runToCompletion(): void {
    for (let i: number = 0; i < this.scenario.events.length; i++) this.emit(this.scenario.events[i])
    this.running = false
  }
  emitLateFinal(text: string): void {
    if (!this.listener) return
    const event: VoiceEvent = new VoiceEvent()
    event.sessionId = this.sessionId; event.type = 'final'; event.text = text
    if (this.recorder) this.recorder.record('lateFinal', this.sessionId)
    this.listener.onVoiceEvent(event)
  }
  private schedule(index: number): void {
    if (index >= this.scenario.events.length) { this.running = false; return }
    setTimeout((): void => {
      if (this.running) this.emit(this.scenario.events[index])
      else if (this.scenario.id === VoiceTestScenarioId.CANCEL_LATE_CALLBACK &&
        this.scenario.events[index].type === 'final') this.emitLateFinal(this.scenario.events[index].text)
      this.schedule(index + 1)
    }, 1500)
  }
  private emit(script: VoiceScriptEvent): void {
    if (!this.running || !this.listener) return
    const event: VoiceEvent = new VoiceEvent()
    event.sessionId = this.sessionId; event.type = script.type; event.text = script.text; event.error = script.error
    if (this.recorder) {
      if (script.type === 'listening') this.recorder.recordScriptedListening(this.sessionId)
      else this.recorder.record(script.type, this.sessionId)
    }
    this.listener.onVoiceEvent(event)
  }
}
