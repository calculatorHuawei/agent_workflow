import { VoiceInputController } from '../../../main/ets/voice/VoiceInputController'
import { ScriptedSpeechRecognitionGateway } from '../voice/ScriptedSpeechRecognitionGateway'
import { VoiceTestScenarioId, VoiceTestScenarioRegistry } from '../voice/VoiceTestScenarioRegistry'

export class VoiceUiMatrixResult {
  scenarioId: string = ''
  executed: boolean = false
  state: string = ''
  expression: string = ''
  result: string = ''
  error: string = ''
  historyDelta: number = 0
}

/** Deterministic application-layer oracle used by the device UI assembly. */
export class VoiceUiMatrix {
  static runAll(): VoiceUiMatrixResult[] {
    const ids: string[] = VoiceTestScenarioRegistry.ids()
    const results: VoiceUiMatrixResult[] = []
    for (let i: number = 0; i < ids.length; i++) results.push(VoiceUiMatrix.run(ids[i]))
    return results
  }

  static run(id: string): VoiceUiMatrixResult {
    const output: VoiceUiMatrixResult = new VoiceUiMatrixResult()
    output.scenarioId = id
    if (!VoiceTestScenarioRegistry.resolve(id)) return output
    let expression: string = '7*8'; let result: string = '56'
    if (id === VoiceTestScenarioId.DIVIDE_BY_ZERO) { expression = '9+9'; result = '18' }
    else if (id === VoiceTestScenarioId.EMPTY) { expression = '42-1'; result = '41' }
    else if (id === VoiceTestScenarioId.SERVICE_UNAVAILABLE) { expression = '5+5'; result = '10' }
    else if (id === VoiceTestScenarioId.RECORDING_INTERRUPTED) { expression = '6*7'; result = '42' }
    else if (id === VoiceTestScenarioId.CANCEL_LATE_CALLBACK) { expression = '2+2'; result = '4' }
    const gateway: ScriptedSpeechRecognitionGateway = new ScriptedSpeechRecognitionGateway(id as VoiceTestScenarioId)
    const controller: VoiceInputController = new VoiceInputController(gateway)
    controller.start(expression, result, false)
    if (id === VoiceTestScenarioId.DUPLICATE_START) controller.start(expression, result, false)
    if (id === VoiceTestScenarioId.CANCEL_LATE_CALLBACK) {
      controller.cancel(); gateway.emitLateFinal('123加456')
    } else gateway.runToCompletion()
    output.executed = true; output.state = controller.snapshot.state
    output.expression = controller.snapshot.expression; output.result = controller.snapshot.result
    output.error = controller.snapshot.error; output.historyDelta = controller.commitCount
    return output
  }
}
