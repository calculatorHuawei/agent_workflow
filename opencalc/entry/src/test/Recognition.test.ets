import { describe, it, expect } from '@ohos/hypium'
import {
  RecognitionState, PermissionDecision, RecognitionError, ValidationError
} from '../main/ets/recognition/model/RecognitionModels'
import { ExpressionValidator } from '../main/ets/recognition/service/ExpressionValidator'
import { RecognitionCoordinator } from '../main/ets/recognition/service/RecognitionCoordinator'

export default function recognitionTest(): void {
  describe('ExpressionValidator', () => {
    const validator: ExpressionValidator = new ExpressionValidator()

    it('normalizes_supported_handwritten_operators', 0, (): void => {
      const result = validator.validate(' 12 + 3 × (4 − 1) ')
      expect(result.valid).assertTrue()
      expect(result.normalized).assertEqual('12+3*(4-1)')
    })

    it('enforces_whitelist_and_length', 0, (): void => {
      expect(validator.validate('sin(1)').error).assertEqual(ValidationError.UNSUPPORTED_CHARACTER)
      expect(validator.validate('').error).assertEqual(ValidationError.EMPTY)
      let longText: string = ''
      for (let i: number = 0; i < 129; i++) longText = longText + '1'
      expect(validator.validate(longText).error).assertEqual(ValidationError.TOO_LONG)
    })

    it('accepts_strict_arithmetic_grammar', 0, (): void => {
      expect(validator.validate('12.5+(3/4)-2').valid).assertTrue()
      expect(validator.validate('2(3)').error).assertEqual(ValidationError.SYNTAX)
      expect(validator.validate('1..2+3').error).assertEqual(ValidationError.SYNTAX)
      expect(validator.validate('(1+2').error).assertEqual(ValidationError.SYNTAX)
      expect(validator.validate('1++2').error).assertEqual(ValidationError.SYNTAX)
    })
  })

  describe('RecognitionCoordinator', () => {
    it('protects_original_input_across_permission_errors', 0, (): void => {
      const coordinator: RecognitionCoordinator = new RecognitionCoordinator(new ExpressionValidator())
      coordinator.begin('7+8')
      expect(coordinator.snapshot().state).assertEqual(RecognitionState.REQUESTING_PERMISSION)
      coordinator.onPermission(PermissionDecision.DENIED)
      expect(coordinator.snapshot().state).assertEqual(RecognitionState.ERROR)
      expect(coordinator.snapshot().error).assertEqual(RecognitionError.PERMISSION_DENIED)
      expect(coordinator.snapshot().originalExpression).assertEqual('7+8')
      expect(coordinator.confirm().accepted).assertFalse()
      coordinator.retry()
      expect(coordinator.snapshot().state).assertEqual(RecognitionState.REQUESTING_PERMISSION)
    })

    it('validates_edits_and_only_commits_explicit_confirmation', 0, (): void => {
      const coordinator: RecognitionCoordinator = new RecognitionCoordinator(new ExpressionValidator())
      const session: number = coordinator.begin('9+9')
      coordinator.onPermission(PermissionDecision.GRANTED)
      coordinator.onCapture(session, true)
      coordinator.onOcr(session, '12 + 3 × 4')
      expect(coordinator.snapshot().state).assertEqual(RecognitionState.REVIEWING_VALID)
      expect(coordinator.snapshot().originalExpression).assertEqual('9+9')
      coordinator.updateCandidate('12+bad')
      expect(coordinator.snapshot().state).assertEqual(RecognitionState.REVIEWING_INVALID)
      expect(coordinator.confirm().accepted).assertFalse()
      coordinator.updateCandidate('12+3*4')
      const confirmed = coordinator.confirm()
      expect(confirmed.accepted).assertTrue()
      expect(confirmed.expression).assertEqual('12+3*4')
      expect(coordinator.snapshot().state).assertEqual(RecognitionState.IDLE)
    })

    it('handles_empty_timeout_retry_cancel_and_stale_callbacks', 0, (): void => {
      const coordinator: RecognitionCoordinator = new RecognitionCoordinator(new ExpressionValidator())
      const oldSession: number = coordinator.begin('1+1')
      coordinator.onPermission(PermissionDecision.GRANTED)
      coordinator.onCapture(oldSession, true)
      coordinator.onOcr(oldSession, '')
      expect(coordinator.snapshot().error).assertEqual(RecognitionError.EMPTY_RESULT)
      coordinator.retry()
      expect(coordinator.snapshot().state).assertEqual(RecognitionState.CAPTURING)
      coordinator.onTimeout(oldSession)
      expect(coordinator.snapshot().error).assertEqual(RecognitionError.TIMEOUT)
      coordinator.cancel()
      const newSession: number = coordinator.begin('2+2')
      coordinator.onOcr(oldSession, '99+1')
      expect(coordinator.snapshot().sessionId).assertEqual(newSession)
      expect(coordinator.snapshot().state).assertEqual(RecognitionState.REQUESTING_PERMISSION)
      expect(coordinator.snapshot().candidate).assertEqual('')
      coordinator.cancel()
      expect(coordinator.snapshot().state).assertEqual(RecognitionState.IDLE)
      expect(coordinator.snapshot().originalExpression).assertEqual('')
    })
  })
}
