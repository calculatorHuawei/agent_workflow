export type Matrix = number[][]

export enum MatrixOperation {
  ADD = 'add',
  SUBTRACT = 'subtract',
  MULTIPLY = 'multiply',
  DETERMINANT = 'determinant'
}

export interface CellError {
  matrix: string
  row: number
  column: number
  reason: string
  key: string
}

export interface ParseResult {
  valid: boolean
  a: Matrix
  b: Matrix
  errors: CellError[]
}

export interface MatrixDisplayResult {
  kind: string
  matrix: string[][]
  scalar: string
}

export function emptyMatrixText(): string[][] {
  return [['', '', ''], ['', '', ''], ['', '', '']]
}

export class MatrixSession {
  private engine: MatrixEngine = new MatrixEngine()
  private adapter: MatrixInputAdapter = new MatrixInputAdapter()
  private formatter: MatrixFormatter = new MatrixFormatter()
  size: number = 2
  aText: string[][] = emptyMatrixText()
  bText: string[][] = emptyMatrixText()
  errorKeys: string[] = []
  errorSummary: string = ''
  resultKind: string = 'none'
  resultMatrix: string[][] = []
  resultScalar: string = ''

  setCell(matrix: string, row: number, column: number, value: string): void {
    if (matrix === 'A') this.aText = this.replaceCell(this.aText, row, column, value)
    else this.bText = this.replaceCell(this.bText, row, column, value)
    const key: string = matrix + '-' + row.toString() + '-' + column.toString()
    const remaining: string[] = []
    for (let index: number = 0; index < this.errorKeys.length; index++) {
      if (this.errorKeys[index] !== key) remaining.push(this.errorKeys[index])
    }
    this.errorKeys = remaining
    const label: string = matrix + '[' + (row + 1).toString() + ',' + (column + 1).toString() + ']'
    const oldMessages: string[] = this.errorSummary.length === 0 ? [] : this.errorSummary.split('；')
    const messages: string[] = []
    for (let index: number = 0; index < oldMessages.length; index++) {
      if (oldMessages[index].indexOf(label) !== 0) messages.push(oldMessages[index])
    }
    this.errorSummary = messages.join('；')
    this.invalidateResult()
  }

  setSize(size: number): void {
    if (size !== 2 && size !== 3) throw new Error('Only 2x2 and 3x3 matrices are supported')
    if (size === this.size) return
    if (size === 2) {
      this.aText = this.clearOuterCells(this.aText)
      this.bText = this.clearOuterCells(this.bText)
    }
    this.size = size
    this.errorKeys = []
    this.errorSummary = ''
    this.invalidateResult()
  }

  calculate(operation: MatrixOperation): void {
    this.invalidateResult()
    this.errorKeys = []
    this.errorSummary = ''
    const parsed: ParseResult = this.adapter.parseRequired(this.aText, this.bText, this.size, operation)
    if (!parsed.valid) {
      this.applyErrors(parsed.errors)
      return
    }
    try {
      let display: MatrixDisplayResult
      if (operation === MatrixOperation.DETERMINANT) {
        display = this.formatter.formatScalar(this.engine.determinant(parsed.a))
      } else if (operation === MatrixOperation.ADD) {
        display = this.formatter.formatMatrix(this.engine.add(parsed.a, parsed.b))
      } else if (operation === MatrixOperation.SUBTRACT) {
        display = this.formatter.formatMatrix(this.engine.subtract(parsed.a, parsed.b))
      } else {
        display = this.formatter.formatMatrix(this.engine.multiply(parsed.a, parsed.b))
      }
      this.resultKind = display.kind
      this.resultMatrix = display.matrix
      this.resultScalar = display.scalar
    } catch (_error) {
      this.errorSummary = '矩阵计算错误'
    }
  }

  clear(): void {
    this.aText = emptyMatrixText()
    this.bText = emptyMatrixText()
    this.errorKeys = []
    this.errorSummary = ''
    this.invalidateResult()
  }

  private applyErrors(errors: CellError[]): void {
    const keys: string[] = []
    const messages: string[] = []
    for (let index: number = 0; index < errors.length; index++) {
      const error: CellError = errors[index]
      keys.push(error.key)
      const reason: string = error.reason === 'empty' ? '不能为空' : '不是合法数字'
      messages.push(error.matrix + '[' + (error.row + 1).toString() + ',' +
        (error.column + 1).toString() + '] ' + reason)
    }
    this.errorKeys = keys
    this.errorSummary = messages.join('；')
  }

  private replaceCell(source: string[][], row: number, column: number, value: string): string[][] {
    const result: string[][] = []
    for (let rowIndex: number = 0; rowIndex < source.length; rowIndex++) {
      const values: string[] = []
      for (let columnIndex: number = 0; columnIndex < source[rowIndex].length; columnIndex++) {
        values.push(rowIndex === row && columnIndex === column ? value : source[rowIndex][columnIndex])
      }
      result.push(values)
    }
    return result
  }

  private clearOuterCells(source: string[][]): string[][] {
    const result: string[][] = []
    for (let row: number = 0; row < 3; row++) {
      const values: string[] = []
      for (let column: number = 0; column < 3; column++) {
        values.push(row >= 2 || column >= 2 ? '' : source[row][column])
      }
      result.push(values)
    }
    return result
  }

  private invalidateResult(): void {
    this.resultKind = 'none'
    this.resultMatrix = []
    this.resultScalar = ''
  }
}

export class MatrixFormatter {
  formatMatrix(matrix: Matrix): MatrixDisplayResult {
    const display: string[][] = []
    for (let row: number = 0; row < matrix.length; row++) {
      const values: string[] = []
      for (let column: number = 0; column < matrix[row].length; column++) {
        values.push(this.formatValue(matrix[row][column]))
      }
      display.push(values)
    }
    return { kind: 'matrix', matrix: display, scalar: '' }
  }

  formatScalar(value: number): MatrixDisplayResult {
    return { kind: 'scalar', matrix: [], scalar: this.formatValue(value) }
  }

  private formatValue(value: number): string {
    if (!Number.isFinite(value)) throw new Error('Matrix result must be finite')
    let normalized: number = Number(value.toPrecision(12))
    if (Math.abs(normalized) < 0.000000000001 || normalized === 0) normalized = 0
    return normalized.toString()
  }
}

export class MatrixInputAdapter {
  parseRequired(aText: string[][], bText: string[][], size: number, operation: MatrixOperation): ParseResult {
    const errors: CellError[] = []
    const a: Matrix = this.parseMatrix(aText, size, 'A', errors)
    let b: Matrix = []
    if (operation !== MatrixOperation.DETERMINANT) {
      b = this.parseMatrix(bText, size, 'B', errors)
    }
    return { valid: errors.length === 0, a: a, b: b, errors: errors }
  }

  private parseMatrix(text: string[][], size: number, name: string, errors: CellError[]): Matrix {
    const matrix: Matrix = []
    for (let row: number = 0; row < size; row++) {
      const values: number[] = []
      for (let column: number = 0; column < size; column++) {
        const raw: string = row < text.length && column < text[row].length ? text[row][column].trim() : ''
        if (raw.length === 0) {
          errors.push(this.cellError(name, row, column, 'empty'))
          values.push(0)
        } else if (!this.isDecimal(raw)) {
          errors.push(this.cellError(name, row, column, 'invalid'))
          values.push(0)
        } else {
          const value: number = Number(raw)
          if (!Number.isFinite(value)) {
            errors.push(this.cellError(name, row, column, 'invalid'))
            values.push(0)
          } else {
            values.push(value)
          }
        }
      }
      matrix.push(values)
    }
    return matrix
  }

  private isDecimal(value: string): boolean {
    return /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/.test(value)
  }

  private cellError(matrix: string, row: number, column: number, reason: string): CellError {
    return { matrix: matrix, row: row, column: column, reason: reason,
      key: matrix + '-' + row.toString() + '-' + column.toString() }
  }
}

export class MatrixEngine {
  add(a: Matrix, b: Matrix): Matrix {
    return this.combine(a, b, false)
  }

  subtract(a: Matrix, b: Matrix): Matrix {
    return this.combine(a, b, true)
  }

  private combine(a: Matrix, b: Matrix, subtract: boolean): Matrix {
    const size: number = this.assertPair(a, b)
    const result: Matrix = []
    for (let row: number = 0; row < size; row++) {
      const values: number[] = []
      for (let column: number = 0; column < size; column++) {
        const value: number = subtract ? a[row][column] - b[row][column] : a[row][column] + b[row][column]
        values.push(value)
      }
      result.push(values)
    }
    return result
  }

  multiply(a: Matrix, b: Matrix): Matrix {
    const size: number = this.assertPair(a, b)
    const result: Matrix = []
    for (let row: number = 0; row < size; row++) {
      const values: number[] = []
      for (let column: number = 0; column < size; column++) {
        let value: number = 0
        for (let index: number = 0; index < size; index++) {
          value += a[row][index] * b[index][column]
        }
        values.push(value)
      }
      result.push(values)
    }
    return result
  }

  determinant(a: Matrix): number {
    const size: number = this.assertMatrix(a)
    if (size === 2) {
      return a[0][0] * a[1][1] - a[0][1] * a[1][0]
    }
    return a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1])
      - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0])
      + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0])
  }

  private assertPair(a: Matrix, b: Matrix): number {
    const aSize: number = this.assertMatrix(a)
    const bSize: number = this.assertMatrix(b)
    if (aSize !== bSize) throw new Error('Matrix dimensions must match')
    return aSize
  }

  private assertMatrix(matrix: Matrix): number {
    const size: number = matrix.length
    if (size !== 2 && size !== 3) throw new Error('Only 2x2 and 3x3 matrices are supported')
    for (let row: number = 0; row < size; row++) {
      if (matrix[row].length !== size) throw new Error('Matrix must be square')
      for (let column: number = 0; column < size; column++) {
        if (!Number.isFinite(matrix[row][column])) throw new Error('Matrix values must be finite')
      }
    }
    return size
  }
}
