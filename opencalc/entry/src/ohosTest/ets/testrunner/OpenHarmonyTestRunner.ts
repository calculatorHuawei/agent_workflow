// OpenHarmonyTestRunner — hypium 标准模板
// Issue #8 百分号按钮验收测试运行器
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry'
import hilog from '@ohos.hilog'
import { Hypium } from '@ohos/hypium'
import testsuite from '../test/List.test'

let abilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator()
let abilityDelegatorArguments = AbilityDelegatorRegistry.getArguments()

export default class OpenHarmonyTestRunner {
  onPrepare() {
    hilog.info(0x0000, 'testTag', 'OpenHarmonyTestRunner OnPrepare')
  }
  onRun() {
    hilog.info(0x0000, 'testTag', 'OpenHarmonyTestRunner OnRun')
    Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite)
  }
}
