import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { Hypium } from '@ohos/hypium'
import testsuite from '../test/Index'

export default class TestAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.log('TestAbility onCreate')
    Hypium.hypiumTest(this.context, testsuite)
  }

  onDestroy(): void {
    console.log('TestAbility onDestroy')
  }
}
