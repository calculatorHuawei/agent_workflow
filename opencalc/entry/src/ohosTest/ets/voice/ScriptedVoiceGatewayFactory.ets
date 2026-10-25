import { SpeechRecognitionGateway } from '../../../main/ets/voice/SpeechRecognitionGateway'
import { VoiceGatewayFactory } from '../../../main/ets/voice/VoiceGatewayFactory'
import { ScriptedSpeechRecognitionGateway } from './ScriptedSpeechRecognitionGateway'
import { VoiceTestScenarioId } from './VoiceTestScenarioRegistry'
import { VoiceTestEventRecorder } from './VoiceTestEventRecorder'

export class ScriptedVoiceGatewayFactory implements VoiceGatewayFactory {
  private scenarioId: VoiceTestScenarioId
  private recorder: VoiceTestEventRecorder | null = null
  constructor(scenarioId: VoiceTestScenarioId, recorder: VoiceTestEventRecorder | null = null) {
    this.scenarioId = scenarioId
    this.recorder = recorder
  }
  create(): SpeechRecognitionGateway {
    const gateway: ScriptedSpeechRecognitionGateway = new ScriptedSpeechRecognitionGateway(this.scenarioId, true)
    if (this.recorder) {
      this.recorder.recordPermissionGranted()
      this.recorder.recordGatewayCreated()
      gateway.setRecorder(this.recorder)
    }
    return gateway
  }
}
