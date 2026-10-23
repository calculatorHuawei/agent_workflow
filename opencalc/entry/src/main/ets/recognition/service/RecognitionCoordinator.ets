import {
  ConfirmationResult, PermissionDecision, RecognitionError, RecognitionSnapshot,
  RecognitionState, ValidationError, ValidationResult
} from '../model/RecognitionModels'
import { ExpressionValidator } from './ExpressionValidator'

export class RecognitionCoordinator {
  private validator: ExpressionValidator
  private state: RecognitionState = RecognitionState.IDLE
  private sessionId: number = 0
  private originalExpression: string = ''
  private candidate: string = ''
  private validationError: ValidationError = ValidationError.NONE
  private error: RecognitionError = RecognitionError.NONE

  constructor(validator: ExpressionValidator) { this.validator = validator }

  begin(originalExpression: string): number {
    this.sessionId++
    this.originalExpression = originalExpression
    this.candidate = ''
    this.validationError = ValidationError.NONE
    this.error = RecognitionError.NONE
    this.state = RecognitionState.REQUESTING_PERMISSION
    return this.sessionId
  }

  onPermission(decision: PermissionDecision): void {
    if (this.state !== RecognitionState.REQUESTING_PERMISSION) return
    if (decision === PermissionDecision.GRANTED) {
      this.state = RecognitionState.CAPTURING
      return
    }
    this.state = RecognitionState.ERROR
    this.error = decision === PermissionDecision.PERMANENTLY_DENIED ?
      RecognitionError.PERMISSION_PERMANENTLY_DENIED : RecognitionError.PERMISSION_DENIED
  }

  onCapture(sessionId: number, success: boolean, cancelled: boolean = false): void {
    if (!this.isCurrent(sessionId) || this.state !== RecognitionState.CAPTURING) return
    if (success) { this.state = RecognitionState.RECOGNIZING; return }
    this.state = RecognitionState.ERROR
    this.error = cancelled ? RecognitionError.CAPTURE_CANCELLED : RecognitionError.CAPTURE_FAILED
  }

  onOcr(sessionId: number, text: string, success: boolean = true): void {
    if (!this.isCurrent(sessionId) || this.state !== RecognitionState.RECOGNIZING) return
    if (!success) {
      this.state = RecognitionState.ERROR
      this.error = RecognitionError.OCR_FAILED
      return
    }
    const result: ValidationResult = this.validator.validate(text)
    this.candidate = result.normalized
    this.validationError = result.error
    this.error = result.error === ValidationError.EMPTY ? RecognitionError.EMPTY_RESULT : RecognitionError.NONE
    this.state = result.valid ? RecognitionState.REVIEWING_VALID :
      (result.error === ValidationError.EMPTY ? RecognitionState.ERROR : RecognitionState.REVIEWING_INVALID)
  }

  onTimeout(sessionId: number): void {
    if (!this.isCurrent(sessionId)) return
    this.state = RecognitionState.ERROR
    this.error = RecognitionError.TIMEOUT
  }

  updateCandidate(text: string): void {
    if (this.state !== RecognitionState.REVIEWING_VALID && this.state !== RecognitionState.REVIEWING_INVALID) return
    const result: ValidationResult = this.validator.validate(text)
    this.candidate = result.normalized
    this.validationError = result.error
    this.state = result.valid ? RecognitionState.REVIEWING_VALID : RecognitionState.REVIEWING_INVALID
  }

  confirm(): ConfirmationResult {
    if (this.state !== RecognitionState.REVIEWING_VALID) return new ConfirmationResult(false, '')
    const result: ValidationResult = this.validator.validate(this.candidate)
    if (!result.valid) return new ConfirmationResult(false, '')
    const confirmed: ConfirmationResult = new ConfirmationResult(true, result.normalized)
    this.reset()
    return confirmed
  }

  retry(): void {
    if (this.state !== RecognitionState.ERROR && this.state !== RecognitionState.REVIEWING_VALID &&
      this.state !== RecognitionState.REVIEWING_INVALID) return
    const retryPermission: boolean = this.error === RecognitionError.PERMISSION_DENIED ||
      this.error === RecognitionError.PERMISSION_PERMANENTLY_DENIED
    this.candidate = ''
    this.validationError = ValidationError.NONE
    this.error = RecognitionError.NONE
    this.state = retryPermission ? RecognitionState.REQUESTING_PERMISSION : RecognitionState.CAPTURING
  }

  cancel(): void { this.reset() }

  snapshot(): RecognitionSnapshot {
    return new RecognitionSnapshot(this.state, this.sessionId, this.originalExpression,
      this.candidate, this.validationError, this.error)
  }

  private isCurrent(sessionId: number): boolean { return sessionId === this.sessionId }

  private reset(): void {
    this.state = RecognitionState.IDLE
    this.originalExpression = ''
    this.candidate = ''
    this.validationError = ValidationError.NONE
    this.error = RecognitionError.NONE
  }
}
