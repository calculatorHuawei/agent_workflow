import { SpeechRecognitionGateway } from '../../../main/ets/voice/SpeechRecognitionGateway'
import { VoiceGatewayFactory } from '../../../main/ets/voice/VoiceGatewayFactory'
import { ScriptedSpeechRecognitionGateway } from './ScriptedSpeechRecognitionGateway'
import { VoiceTestScenarioId } from './VoiceTestScenarioRegistry'

export class ScriptedVoiceGatewayFactory implements VoiceGatewayFactory {
  private scenarioId: VoiceTestScenarioId
  constructor(scenarioId: VoiceTestScenarioId) { this.scenarioId = scenarioId }
  create(): SpeechRecognitionGateway { return new ScriptedSpeechRecognitionGateway(this.scenarioId, true) }
}
