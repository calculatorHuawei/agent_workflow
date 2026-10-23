export class OcrResult {
  success: boolean
  text: string

  constructor(success: boolean, text: string) {
    this.success = success
    this.text = text
  }
}

export interface HandwritingOcrProvider {
  recognize(uri: string): Promise<OcrResult>
  release(): Promise<void>
}
