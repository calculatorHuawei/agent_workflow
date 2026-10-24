export class NumberParseResult {
  ok: boolean = false
  value: string = ''
  error: string = ''
}

export class VoiceParseResult {
  ok: boolean = false
  expression: string = ''
  error: string = ''
}

export class CalculationOutcome {
  ok: boolean = false
  expression: string = ''
  result: string = ''
  error: string = ''
}

export class VoiceEvent {
  sessionId: number = 0
  type: string = ''
  text: string = ''
  error: string = ''
}

export class VoiceSnapshot {
  state: string = 'idle'
  transcript: string = ''
  expression: string = ''
  result: string = ''
  error: string = ''
}
