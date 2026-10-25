export class VoiceTestEvidence {
  sourceSha: string = ''
  scenarioId: string = ''
  events: string[] = []
  historyBefore: number = 0
  historyAfter: number = 0
  historyDelta: number = 0
  cleanedUp: boolean = false
}

/** Records only allowlisted scenario metadata; never records PCM or user transcript. */
export class VoiceTestEventRecorder {
  evidence: VoiceTestEvidence = new VoiceTestEvidence()
  constructor(sourceSha: string, scenarioId: string, historyBefore: number) {
    this.evidence.sourceSha = sourceSha
    this.evidence.scenarioId = scenarioId
    this.evidence.historyBefore = historyBefore
    this.evidence.historyAfter = historyBefore
  }
  record(event: string, sessionId: number): void { this.evidence.events.push(sessionId.toString() + ':' + event) }
  finish(historyAfter: number, cleanedUp: boolean): void {
    this.evidence.historyAfter = historyAfter
    this.evidence.historyDelta = historyAfter - this.evidence.historyBefore
    this.evidence.cleanedUp = cleanedUp
  }
}
