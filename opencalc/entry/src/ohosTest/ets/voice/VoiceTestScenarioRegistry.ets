import { VoiceScriptEvent, VoiceTestScenario } from './VoiceTestScenario'

export enum VoiceTestScenarioId {
  OPERATOR_TABLE = 'operatorTable',
  INTEGER_TABLE = 'integerTable',
  DECIMAL = 'decimal',
  AMBIGUOUS = 'ambiguous',
  EMPTY = 'empty',
  DIVIDE_BY_ZERO = 'divideByZero',
  SERVICE_UNAVAILABLE = 'serviceUnavailable',
  RECORDING_INTERRUPTED = 'recordingInterrupted',
  CANCEL_LATE_CALLBACK = 'cancelLateCallback',
  DUPLICATE_START = 'duplicateStart',
  DUPLICATE_FINAL = 'duplicateFinal'
}

export class VoiceTestScenarioRegistry {
  static ids(): string[] {
    return [VoiceTestScenarioId.OPERATOR_TABLE, VoiceTestScenarioId.INTEGER_TABLE, VoiceTestScenarioId.DECIMAL,
      VoiceTestScenarioId.AMBIGUOUS, VoiceTestScenarioId.EMPTY, VoiceTestScenarioId.DIVIDE_BY_ZERO,
      VoiceTestScenarioId.SERVICE_UNAVAILABLE, VoiceTestScenarioId.RECORDING_INTERRUPTED,
      VoiceTestScenarioId.CANCEL_LATE_CALLBACK, VoiceTestScenarioId.DUPLICATE_START, VoiceTestScenarioId.DUPLICATE_FINAL]
  }

  static resolve(id: string): VoiceTestScenario | null {
    if (VoiceTestScenarioRegistry.ids().indexOf(id) < 0) return null
    const events: VoiceScriptEvent[] = [new VoiceScriptEvent('listening'), new VoiceScriptEvent('recognizing')]
    if (id === VoiceTestScenarioId.OPERATOR_TABLE) events.push(new VoiceScriptEvent('final', '一加二'))
    else if (id === VoiceTestScenarioId.INTEGER_TABLE) events.push(new VoiceScriptEvent('final', '123加456'))
    else if (id === VoiceTestScenarioId.DECIMAL) events.push(new VoiceScriptEvent('final', '十点五减二点五'))
    else if (id === VoiceTestScenarioId.AMBIGUOUS) events.push(new VoiceScriptEvent('final', '一加二乘三'))
    else if (id === VoiceTestScenarioId.EMPTY) events.push(new VoiceScriptEvent('empty', '', 'EMPTY'))
    else if (id === VoiceTestScenarioId.DIVIDE_BY_ZERO) events.push(new VoiceScriptEvent('final', '十除零'))
    else if (id === VoiceTestScenarioId.SERVICE_UNAVAILABLE) events.push(new VoiceScriptEvent('error', '', 'SERVICE_UNAVAILABLE'))
    else if (id === VoiceTestScenarioId.RECORDING_INTERRUPTED) events.push(new VoiceScriptEvent('error', '', 'RECORDING_INTERRUPTED'))
    else if (id === VoiceTestScenarioId.CANCEL_LATE_CALLBACK) events.push(new VoiceScriptEvent('final', '123加456'))
    else if (id === VoiceTestScenarioId.DUPLICATE_START) events.push(new VoiceScriptEvent('final', '二十乘三'))
    else { events.push(new VoiceScriptEvent('final', '123加456')); events.push(new VoiceScriptEvent('final', '123加456')) }
    return new VoiceTestScenario(id, events)
  }
}
