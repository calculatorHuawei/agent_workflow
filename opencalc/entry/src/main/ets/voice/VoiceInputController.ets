import { SpeechRecognitionGateway, VoiceEventListener } from './SpeechRecognitionGateway'
import { CalculationCoordinator } from './CalculationCoordinator'
import { VoiceExpressionParser } from './VoiceExpressionParser'
import { CalculationOutcome, VoiceEvent, VoiceParseResult, VoiceSnapshot } from './VoiceModels'

export class VoiceInputController implements VoiceEventListener {
  snapshot: VoiceSnapshot = new VoiceSnapshot()
  commitCount: number = 0
  private gateway: SpeechRecognitionGateway
  private evaluator: CalculationCoordinator = new CalculationCoordinator()
  private sessionId: number = 0
  private active: boolean = false
  private consumed: boolean = false
  private radianMode: boolean = false
  private observer: ((snapshot: VoiceSnapshot) => void) | null = null

  constructor(gateway: SpeechRecognitionGateway, observer?: (snapshot: VoiceSnapshot) => void) {
    this.gateway = gateway; this.observer = observer ? observer : null; gateway.setListener(this)
  }

  start(expression: string, result: string, radianMode: boolean): void {
    if (this.active) return
    this.sessionId++
    this.active = true; this.consumed = false; this.radianMode = radianMode
    this.snapshot = new VoiceSnapshot()
    this.snapshot.state = 'requestingPermission'; this.snapshot.expression = expression; this.snapshot.result = result
    this.publish()
    this.gateway.start(this.sessionId)
  }

  cancel(): void {
    if (!this.active) return
    const old: number = this.sessionId
    this.active = false; this.sessionId++; this.snapshot.state = 'idle'; this.snapshot.error = ''
    this.gateway.cancel(old)
    this.publish()
  }

  dispose(): void { this.active = false; this.sessionId++; this.gateway.dispose(); this.snapshot.state = 'idle'; this.publish() }

  onVoiceEvent(event: VoiceEvent): void {
    if (!this.active || event.sessionId !== this.sessionId) return
    if (event.type === 'listening') { this.snapshot.state = 'listening'; this.publish(); return }
    if (event.type === 'recognizing') { this.snapshot.state = 'recognizing'; this.publish(); return }
    if (event.type === 'partial') { this.snapshot.transcript = event.text; this.publish(); return }
    if (event.type === 'error' || event.type === 'empty') {
      this.snapshot.state = 'error'; this.snapshot.error = this.errorMessage(event.error); this.active = false; this.publish(); return
    }
    if (event.type !== 'final' || this.consumed) return
    this.consumed = true
    const parsed: VoiceParseResult = VoiceExpressionParser.parse(event.text)
    if (!parsed.ok) { this.snapshot.state = 'error'; this.snapshot.error = '无法理解该算式'; this.active = false; this.publish(); return }
    const calculated: CalculationOutcome = this.evaluator.evaluate(parsed.expression, this.radianMode)
    if (!calculated.ok) { this.snapshot.state = 'error'; this.snapshot.error = calculated.error; this.active = false; this.publish(); return }
    this.snapshot.transcript = event.text; this.snapshot.expression = parsed.expression; this.snapshot.result = calculated.result
    this.snapshot.state = 'success'; this.snapshot.error = ''; this.commitCount++; this.active = false; this.publish()
  }

  private errorMessage(code: string): string {
    if (code === 'PERMISSION_DENIED') return '需要麦克风权限，请授权后重试'
    if (code === 'RECORDING_INTERRUPTED') return '录音已中断，请重试'
    if (code === 'EMPTY') return '未识别到算式，请重试'
    return '语音服务暂不可用，请稍后重试'
  }

  private publish(): void { if (this.observer) this.observer(this.snapshot) }
}
