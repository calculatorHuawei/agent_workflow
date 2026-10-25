export class VoiceTestEvidence {
  sourceSha: string = ''
  scenarioId: string = ''
  events: string[] = []
  historyBefore: number = 0
  historyAfter: number = 0
  historyDelta: number = 0
  cleanedUp: boolean = false
  gatewayCreateCount: number = 0
  gatewayStartCount: number = 0
  activeSessionId: number = 0
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
  record(event: string, sessionId: number): void {
    this.evidence.events.push(sessionId.toString() + ':' + event)
    console.info('VOICE_TEST_EVIDENCE scenario=' + this.evidence.scenarioId +
      ' event=' + event + ' sessionId=' + sessionId.toString() +
      ' gatewayStartCount=' + this.evidence.gatewayStartCount.toString())
  }
  recordPermissionGranted(): void { this.record('permissionGranted', 0) }
  recordGatewayCreated(): void {
    this.evidence.gatewayCreateCount++
    this.record('gatewayCreated', 0)
  }
  recordGatewayStart(sessionId: number): void {
    this.evidence.gatewayStartCount++
    this.evidence.activeSessionId = sessionId
    this.record('gatewayStartInvoked', sessionId)
  }
  recordScriptedListening(sessionId: number): void { this.record('scriptedListening', sessionId) }
  markCleanedUp(sessionId: number): void {
    this.evidence.cleanedUp = true
    this.record('cleanup', sessionId)
  }
  finish(historyAfter: number, cleanedUp: boolean): void {
    this.evidence.historyAfter = historyAfter
    this.evidence.historyDelta = historyAfter - this.evidence.historyBefore
    this.evidence.cleanedUp = cleanedUp
  }
}
