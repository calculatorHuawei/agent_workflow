import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit'
import { CameraPermissionGateway } from './CameraPermissionGateway'
import { PermissionDecision } from '../model/RecognitionModels'

export class HarmonyCameraPermissionGateway implements CameraPermissionGateway {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) { this.context = context }

  async request(): Promise<PermissionDecision> {
    try {
      const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager()
      const permissions: Permissions[] = ['ohos.permission.CAMERA']
      const result: PermissionRequestResult =
        await manager.requestPermissionsFromUser(this.context, permissions)
      if (result.authResults.length > 0 && result.authResults[0] === 0) return PermissionDecision.GRANTED
      if (result.dialogShownResults && result.dialogShownResults.length > 0 && !result.dialogShownResults[0]) {
        return PermissionDecision.PERMANENTLY_DENIED
      }
      return PermissionDecision.DENIED
    } catch (_error) {
      return PermissionDecision.DENIED
    }
  }

  async openSettings(): Promise<boolean> { return false }
}
