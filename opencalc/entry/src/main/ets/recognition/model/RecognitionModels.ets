export enum RecognitionState {
  IDLE = 'IDLE',
  REQUESTING_PERMISSION = 'REQUESTING_PERMISSION',
  CAPTURING = 'CAPTURING',
  RECOGNIZING = 'RECOGNIZING',
  REVIEWING_VALID = 'REVIEWING_VALID',
  REVIEWING_INVALID = 'REVIEWING_INVALID',
  ERROR = 'ERROR'
}

export enum PermissionDecision {
  GRANTED = 'granted',
  DENIED = 'denied',
  PERMANENTLY_DENIED = 'permanentlyDenied'
}

export enum RecognitionError {
  NONE = 'none',
  PERMISSION_DENIED = 'permissionDenied',
  PERMISSION_PERMANENTLY_DENIED = 'permissionPermanentlyDenied',
  CAPTURE_CANCELLED = 'captureCancelled',
  CAPTURE_FAILED = 'captureFailed',
  EMPTY_RESULT = 'emptyResult',
  OCR_FAILED = 'ocrFailed',
  TIMEOUT = 'timeout'
}

export enum ValidationError {
  NONE = 'none',
  EMPTY = 'empty',
  TOO_LONG = 'tooLong',
  UNSUPPORTED_CHARACTER = 'unsupportedCharacter',
  SYNTAX = 'syntax'
}

export class ValidationResult {
  valid: boolean
  normalized: string
  error: ValidationError

  constructor(valid: boolean, normalized: string, error: ValidationError) {
    this.valid = valid
    this.normalized = normalized
    this.error = error
  }
}

export class ConfirmationResult {
  accepted: boolean
  expression: string

  constructor(accepted: boolean, expression: string) {
    this.accepted = accepted
    this.expression = expression
  }
}

export class RecognitionSnapshot {
  state: RecognitionState
  sessionId: number
  originalExpression: string
  candidate: string
  validationError: ValidationError
  error: RecognitionError

  constructor(state: RecognitionState, sessionId: number, originalExpression: string,
    candidate: string, validationError: ValidationError, error: RecognitionError) {
    this.state = state
    this.sessionId = sessionId
    this.originalExpression = originalExpression
    this.candidate = candidate
    this.validationError = validationError
    this.error = error
  }
}
