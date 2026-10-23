import { textRecognition } from '@kit.CoreVisionKit'
import { image } from '@kit.ImageKit'
import { HandwritingOcrProvider, OcrResult } from './HandwritingOcrProvider'

export class OnDeviceHandwritingOcrProvider implements HandwritingOcrProvider {
  private initialized: boolean = false

  async recognize(uri: string): Promise<OcrResult> {
    let source: image.ImageSource | null = null
    let pixelMap: image.PixelMap | null = null
    try {
      if (!this.initialized) this.initialized = await textRecognition.init()
      if (!this.initialized) return new OcrResult(false, '')
      source = image.createImageSource(uri)
      pixelMap = await source.createPixelMap()
      const result: textRecognition.TextRecognitionResult = await textRecognition.recognizeText({ pixelMap: pixelMap })
      return new OcrResult(true, result.value)
    } catch (_error) {
      return new OcrResult(false, '')
    } finally {
      if (pixelMap) await pixelMap.release()
      if (source) source.release()
    }
  }

  async release(): Promise<void> {
    if (!this.initialized) return
    await textRecognition.release()
    this.initialized = false
  }
}
