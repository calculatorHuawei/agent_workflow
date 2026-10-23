import { camera, cameraPicker } from '@kit.CameraKit'
import { common } from '@kit.AbilityKit'
import { CaptureGateway, CaptureResult } from './CaptureGateway'

export class HarmonyCaptureGateway implements CaptureGateway {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) { this.context = context }

  async capture(): Promise<CaptureResult> {
    try {
      const profile: cameraPicker.PickerProfile = new cameraPicker.PickerProfile()
      profile.cameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK
      const result: cameraPicker.PickerResult = await cameraPicker.pick(
        this.context, [cameraPicker.PickerMediaType.PHOTO], profile)
      if (result.resultCode !== 0 || result.resultUri.length === 0) return new CaptureResult(false, true, '')
      return new CaptureResult(true, false, result.resultUri)
    } catch (_error) {
      return new CaptureResult(false, true, '')
    }
  }

  release(): void {}
}
