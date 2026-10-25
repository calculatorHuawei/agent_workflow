import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { VoiceGatewayProvider } from '../../../main/ets/voice/VoiceGatewayFactory'
import { ScriptedVoiceGatewayFactory } from '../voice/ScriptedVoiceGatewayFactory'
import { VoiceTestScenarioId, VoiceTestScenarioRegistry } from '../voice/VoiceTestScenarioRegistry'

export default class VoiceTestAbility extends UIAbility {
  private scenarioId: VoiceTestScenarioId = VoiceTestScenarioId.SERVICE_UNAVAILABLE

  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    const requested: string = want.parameters && want.parameters['scenarioId'] ? want.parameters['scenarioId'] as string : ''
    if (VoiceTestScenarioRegistry.resolve(requested)) this.scenarioId = requested as VoiceTestScenarioId
    VoiceGatewayProvider.bind(new ScriptedVoiceGatewayFactory(this.scenarioId))
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index')
  }

  onDestroy(): void { VoiceGatewayProvider.bindRelease() }
}
