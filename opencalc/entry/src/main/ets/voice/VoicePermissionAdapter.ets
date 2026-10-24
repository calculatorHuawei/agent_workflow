export interface PermissionChecker {
  requestMicrophone(): boolean
}

export class VoicePermissionAdapter {
  private checker: PermissionChecker
  constructor(checker: PermissionChecker) { this.checker = checker }
  ensureMicrophonePermission(): boolean { return this.checker.requestMicrophone() }
}
