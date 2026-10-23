import { PermissionDecision } from '../model/RecognitionModels'

export interface CameraPermissionGateway {
  request(): Promise<PermissionDecision>
  openSettings(): Promise<boolean>
}
