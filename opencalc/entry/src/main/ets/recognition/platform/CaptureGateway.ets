export class CaptureResult {
  success: boolean
  cancelled: boolean
  uri: string

  constructor(success: boolean, cancelled: boolean, uri: string) {
    this.success = success
    this.cancelled = cancelled
    this.uri = uri
  }
}

export interface CaptureGateway {
  capture(): Promise<CaptureResult>
  release(): void
}
