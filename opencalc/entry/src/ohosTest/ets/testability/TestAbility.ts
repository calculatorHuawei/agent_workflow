// TestAbility.ts — hypium 测试入口 ability
import AbilityConstant from '@ohos.app.ability.AbilityConstant'
import UIAbility from '@ohos.app.ability.UIAbility'
import Want from '@ohos.app.ability.Want'
import hilog from '@ohos.hilog'

export default class TestAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'TestAbility onCreate')
  }
  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'TestAbility onDestroy')
  }
  onForeground(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'TestAbility onForeground')
  }
  onBackground(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'TestAbility onBackground')
  }
}
