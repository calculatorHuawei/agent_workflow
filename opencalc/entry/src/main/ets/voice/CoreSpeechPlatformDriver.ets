import { speechRecognizer } from '@kit.CoreSpeechKit'
import { audio } from '@kit.AudioKit'
import { SpeechPlatformDriver } from './HarmonySpeechRecognitionGateway'

class CoreRecognitionListener implements speechRecognizer.RecognitionListener {
  private callback: (type: string, text: string, error: string) => void
  constructor(callback: (type: string, text: string, error: string) => void) { this.callback = callback }
  onStart(_sessionId: string, _message: string): void { this.callback('listening', '', '') }
  onEvent(_sessionId: string, eventCode: number, _message: string): void {
    if (eventCode === 3) this.callback('recognizing', '', '')
  }
  onResult(_sessionId: string, result: speechRecognizer.SpeechRecognitionResult): void {
    if (result.isFinal || result.isLast) this.callback(result.result.length > 0 ? 'final' : 'empty', result.result, result.result.length > 0 ? '' : 'EMPTY')
    else this.callback('partial', result.result, '')
  }
  onComplete(_sessionId: string, _message: string): void {}
  onError(_sessionId: string, _code: number, _message: string): void { this.callback('error', '', 'SERVICE_UNAVAILABLE') }
}

export class CoreSpeechPlatformDriver implements SpeechPlatformDriver {
  private running: boolean = false
  private engine: speechRecognizer.SpeechRecognitionEngine | null = null
  private capturer: audio.AudioCapturer | null = null
  private sessionId: string = ''

  start(listener: (type: string, text: string, error: string) => void): boolean {
    if (this.running) return false
    this.running = true
    this.sessionId = Date.now().toString()
    this.begin(listener)
    return true
  }

  stop(): void {
    if (!this.running && !this.engine && !this.capturer) return
    this.running = false
    try { if (this.engine) { this.engine.cancel(this.sessionId); this.engine.shutdown() } } catch (_e) {}
    if (this.capturer) { this.capturer.stop().then((): void => { if (this.capturer) this.capturer.release() }).catch((): void => {}) }
    this.engine = null; this.capturer = null
  }

  private async begin(listener: (type: string, text: string, error: string) => void): Promise<void> {
    try {
      this.engine = await speechRecognizer.createEngine({ language: 'zh-CN', online: 0 })
      this.engine.setListener(new CoreRecognitionListener(listener))
      const options: audio.AudioCapturerOptions = {
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        capturerInfo: { source: audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION, capturerFlags: 0 }
      }
      this.capturer = await audio.createAudioCapturer(options)
      await this.capturer.start()
      this.engine.startListening({
        sessionId: this.sessionId,
        audioInfo: { audioType: 'pcm', sampleRate: 16000, soundChannel: 1, sampleBit: 16 }
      })
      this.pump(listener)
    } catch (_e) { this.running = false; listener('error', '', 'SERVICE_UNAVAILABLE'); this.stop() }
  }

  private async pump(listener: (type: string, text: string, error: string) => void): Promise<void> {
    try {
      while (this.running && this.capturer && this.engine) {
        const data: ArrayBuffer = await this.capturer.read(1280, true)
        if (data.byteLength === 0) continue
        const bytes: Uint8Array = new Uint8Array(data)
        if (bytes.byteLength === 640 || bytes.byteLength === 1280) this.engine.writeAudio(this.sessionId, bytes)
      }
    } catch (_e) { if (this.running) listener('error', '', 'RECORDING_INTERRUPTED'); this.stop() }
  }
}
