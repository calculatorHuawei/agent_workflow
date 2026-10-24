import { describe, it, expect } from '@ohos/hypium'
import {
  CellError, Matrix, MatrixDisplayResult, MatrixEngine, MatrixFormatter, MatrixInputAdapter, MatrixSession,
  MatrixOperation, ParseResult
} from '../main/ets/calculator/MatrixEngine'

function expectMatrix(actual: Matrix, expected: Matrix): void {
  expect(actual.length).assertEqual(expected.length)
  for (let row: number = 0; row < expected.length; row++) {
    expect(actual[row].length).assertEqual(expected[row].length)
    for (let column: number = 0; column < expected[row].length; column++) {
      expect(actual[row][column]).assertEqual(expected[row][column])
    }
  }
}

export default function matrixEngineTest(): void {
  describe('MatrixEngineAlgorithms', () => {
    const engine: MatrixEngine = new MatrixEngine()
    const a: Matrix = [[1, 2], [3, 4]]
    const b: Matrix = [[5, 6], [7, 8]]

    it('calculates_the_2x2_acceptance_examples', 0, (): void => {
      expectMatrix(engine.add(a, b), [[6, 8], [10, 12]])
      expectMatrix(engine.subtract(a, b), [[-4, -4], [-4, -4]])
      expectMatrix(engine.multiply(a, b), [[19, 22], [43, 50]])
      expect(engine.determinant(a)).assertEqual(-2)
    })

    it('preserves_a_3x3_matrix_when_left_multiplied_by_identity', 0, (): void => {
      const identity: Matrix = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
      const value: Matrix = [[-1, 2.5, 3], [4, 0, 6], [7, 8, 9]]
      expectMatrix(engine.multiply(identity, value), value)
      expect(engine.determinant(identity)).assertEqual(1)
    })

    it('rejects_invalid_matrix_shapes_and_non_finite_values', 0, (): void => {
      let nonSquareRejected: boolean = false
      let wrongSizeRejected: boolean = false
      let mismatchedRejected: boolean = false
      let nonFiniteRejected: boolean = false
      try { engine.determinant([[1, 2, 3], [4, 5, 6]]) } catch (_error) { nonSquareRejected = true }
      try { engine.add([[1]], [[1]]) } catch (_error) { wrongSizeRejected = true }
      try { engine.add(a, [[1, 2, 3], [4, 5, 6], [7, 8, 9]]) } catch (_error) { mismatchedRejected = true }
      try { engine.determinant([[1, Infinity], [3, 4]]) } catch (_error) { nonFiniteRejected = true }
      expect(nonSquareRejected).assertTrue()
      expect(wrongSizeRejected).assertTrue()
      expect(mismatchedRejected).assertTrue()
      expect(nonFiniteRejected).assertTrue()
    })
  })

  describe('MatrixInputAdapter', () => {
    const adapter: MatrixInputAdapter = new MatrixInputAdapter()

    it('accepts_the_supported_decimal_forms', 0, (): void => {
      const a: string[][] = [['2', '-2', '+2'], ['.5', '-.5', '1.'], [' 1.5 ', '0', '-0']]
      const b: string[][] = [['1', '0', '0'], ['0', '1', '0'], ['0', '0', '1']]
      const parsed: ParseResult = adapter.parseRequired(a, b, 3, MatrixOperation.ADD)
      expect(parsed.valid).assertTrue()
      expect(parsed.errors.length).assertEqual(0)
      expect(parsed.a[0][0]).assertEqual(2)
      expect(parsed.a[0][1]).assertEqual(-2)
      expect(parsed.a[0][2]).assertEqual(2)
      expect(parsed.a[1][0]).assertEqual(0.5)
      expect(parsed.a[1][1]).assertEqual(-0.5)
      expect(parsed.a[1][2]).assertEqual(1)
      expect(parsed.a[2][0]).assertEqual(1.5)
    })

    it('returns_all_stable_cell_errors_for_invalid_input', 0, (): void => {
      const a: string[][] = [['1', ''], ['3', '4']]
      const b: string[][] = [['5', '6'], ['1x', '8']]
      const parsed: ParseResult = adapter.parseRequired(a, b, 2, MatrixOperation.MULTIPLY)
      expect(parsed.valid).assertFalse()
      expect(parsed.errors.length).assertEqual(2)
      const first: CellError = parsed.errors[0]
      const second: CellError = parsed.errors[1]
      expect(first.key).assertEqual('A-0-1')
      expect(first.reason).assertEqual('empty')
      expect(second.key).assertEqual('B-1-0')
      expect(second.reason).assertEqual('invalid')
    })

    it('rejects_partial_exponent_and_non_finite_text', 0, (): void => {
      const invalid: string[] = ['1 2', '1x', '1e2', 'NaN', 'Infinity', '--1', '+-1', '.']
      for (let index: number = 0; index < invalid.length; index++) {
        const a: string[][] = [[invalid[index], '2'], ['3', '4']]
        const parsed: ParseResult = adapter.parseRequired(a, [['5', '6'], ['7', '8']], 2, MatrixOperation.ADD)
        expect(parsed.valid).assertFalse()
        expect(parsed.errors[0].key).assertEqual('A-0-0')
      }
    })

    it('determinant_does_not_require_matrix_b', 0, (): void => {
      const parsed: ParseResult = adapter.parseRequired(
        [['1', '2'], ['3', '4']], [['', ''], ['', '']], 2, MatrixOperation.DETERMINANT)
      expect(parsed.valid).assertTrue()
      expect(parsed.errors.length).assertEqual(0)
      expect(parsed.b.length).assertEqual(0)
    })
  })

  describe('MatrixFormatter', () => {
    const formatter: MatrixFormatter = new MatrixFormatter()

    it('removes_floating_point_noise_negative_zero_and_integer_suffixes', 0, (): void => {
      const result: MatrixDisplayResult = formatter.formatMatrix([[0.1, 0.1 + 0.2], [-0, 0.00000000000001]])
      expect(result.kind).assertEqual('matrix')
      expect(result.matrix[0][0]).assertEqual('0.1')
      expect(result.matrix[0][1]).assertEqual('0.3')
      expect(result.matrix[1][0]).assertEqual('0')
      expect(result.matrix[1][1]).assertEqual('0')
      expect(formatter.formatScalar(2).scalar).assertEqual('2')
    })

    it('uses_the_same_normalization_for_scalar_and_matrix_results', 0, (): void => {
      expect(formatter.formatScalar(0.1 + 0.2).scalar).assertEqual('0.3')
      expect(formatter.formatMatrix([[0.1 + 0.2, 1]]) .matrix[0][0]).assertEqual('0.3')
    })

    it('rejects_non_finite_display_values', 0, (): void => {
      let scalarRejected: boolean = false
      let matrixRejected: boolean = false
      try { formatter.formatScalar(Infinity) } catch (_error) { scalarRejected = true }
      try { formatter.formatMatrix([[NaN, 1], [2, 3]]) } catch (_error) { matrixRejected = true }
      expect(scalarRejected).assertTrue()
      expect(matrixRejected).assertTrue()
    })
  })

  describe('MatrixSession', () => {
    it('starts_as_an_isolated_2x2_matrix_workspace', 0, (): void => {
      const session: MatrixSession = new MatrixSession()
      expect(session.size).assertEqual(2)
      expect(session.aText.length).assertEqual(3)
      expect(session.bText.length).assertEqual(3)
      expect(session.resultKind).assertEqual('none')
      expect(session.errorKeys.length).assertEqual(0)
    })

    it('updates_one_cell_and_applies_the_dimension_transition_contract', 0, (): void => {
      const session: MatrixSession = new MatrixSession()
      session.setCell('A', 0, 1, '7')
      session.setCell('B', 1, 0, '-2.5')
      session.resultKind = 'matrix'
      session.resultMatrix = [['old']]
      session.errorKeys = ['A-0-1', 'B-1-0']
      session.setSize(3)
      expect(session.aText[0][1]).assertEqual('7')
      expect(session.bText[1][0]).assertEqual('-2.5')
      expect(session.aText[2][2]).assertEqual('')
      expect(session.resultKind).assertEqual('none')
      expect(session.errorKeys.length).assertEqual(0)
      session.setCell('A', 2, 2, '9')
      session.setSize(2)
      session.setSize(3)
      expect(session.aText[2][2]).assertEqual('')
    })

    it('editing_a_cell_only_removes_that_cells_error_and_invalidates_result', 0, (): void => {
      const session: MatrixSession = new MatrixSession()
      session.errorKeys = ['A-0-1', 'B-1-0']
      session.resultKind = 'scalar'
      session.resultScalar = '5'
      session.setCell('A', 0, 1, '2')
      expect(session.errorKeys.length).assertEqual(1)
      expect(session.errorKeys[0]).assertEqual('B-1-0')
      expect(session.resultKind).assertEqual('none')
    })

    it('editing_one_invalid_cell_keeps_the_other_error_summary_accurate', 0, (): void => {
      const session: MatrixSession = new MatrixSession()
      const valid: string[] = ['1', '2', '3', '4']
      for (let index: number = 0; index < 4; index++) {
        session.setCell('A', Math.floor(index / 2), index % 2, valid[index])
        session.setCell('B', Math.floor(index / 2), index % 2, valid[index])
      }
      session.setCell('A', 0, 1, '')
      session.setCell('B', 1, 0, 'bad')
      session.calculate(MatrixOperation.ADD)
      session.setCell('A', 0, 1, '2')
      expect(session.errorKeys.length).assertEqual(1)
      expect(session.errorSummary.indexOf('A[1,2]') < 0).assertTrue()
      expect(session.errorSummary.indexOf('B[2,1]') >= 0).assertTrue()
    })

    it('calculates_matrix_and_scalar_results_with_mutually_exclusive_state', 0, (): void => {
      const session: MatrixSession = new MatrixSession()
      const a: string[] = ['1', '2', '3', '4']
      const b: string[] = ['5', '6', '7', '8']
      for (let index: number = 0; index < 4; index++) {
        session.setCell('A', Math.floor(index / 2), index % 2, a[index])
        session.setCell('B', Math.floor(index / 2), index % 2, b[index])
      }
      session.calculate(MatrixOperation.ADD)
      expect(session.resultKind).assertEqual('matrix')
      expect(session.resultMatrix[0][0]).assertEqual('6')
      expect(session.resultMatrix[1][1]).assertEqual('12')
      expect(session.resultScalar).assertEqual('')
      session.calculate(MatrixOperation.DETERMINANT)
      expect(session.resultKind).assertEqual('scalar')
      expect(session.resultScalar).assertEqual('-2')
      expect(session.resultMatrix.length).assertEqual(0)
    })

    it('collects_all_input_errors_and_does_not_publish_a_result', 0, (): void => {
      const session: MatrixSession = new MatrixSession()
      session.setCell('A', 0, 0, '1')
      session.setCell('A', 0, 1, '')
      session.setCell('A', 1, 0, '3')
      session.setCell('A', 1, 1, '4')
      session.setCell('B', 0, 0, '5')
      session.setCell('B', 0, 1, '6')
      session.setCell('B', 1, 0, '1x')
      session.setCell('B', 1, 1, '8')
      session.calculate(MatrixOperation.MULTIPLY)
      expect(session.resultKind).assertEqual('none')
      expect(session.errorKeys.length).assertEqual(2)
      expect(session.errorKeys[0]).assertEqual('A-0-1')
      expect(session.errorKeys[1]).assertEqual('B-1-0')
      expect(session.errorSummary.indexOf('A[1,2]') >= 0).assertTrue()
      expect(session.errorSummary.indexOf('B[2,1]') >= 0).assertTrue()
    })

    it('clear_is_idempotent_and_preserves_the_selected_dimension', 0, (): void => {
      const session: MatrixSession = new MatrixSession()
      session.setSize(3)
      session.setCell('A', 2, 2, '9')
      session.errorKeys = ['A-0-0']
      session.errorSummary = 'error'
      session.resultKind = 'scalar'
      session.resultScalar = '9'
      session.clear()
      session.clear()
      expect(session.size).assertEqual(3)
      expect(session.aText[2][2]).assertEqual('')
      expect(session.bText[0][0]).assertEqual('')
      expect(session.errorKeys.length).assertEqual(0)
      expect(session.errorSummary).assertEqual('')
      expect(session.resultKind).assertEqual('none')
    })
  })
}
