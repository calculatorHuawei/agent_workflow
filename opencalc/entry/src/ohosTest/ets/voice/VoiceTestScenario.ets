export class VoiceScriptEvent {
  type: string
  text: string
  error: string
  constructor(type: string, text: string = '', error: string = '') {
    this.type = type; this.text = text; this.error = error
  }
}

export class VoiceTestScenario {
  id: string
  events: VoiceScriptEvent[]
  constructor(id: string, events: VoiceScriptEvent[]) { this.id = id; this.events = events }
}
