// OpenCalc — Hypium 测试入口
// 详见 specs/changes/20260611-requirement-add-percentage-btn/delta-design.md §D3.7
import { abilityDelegatorRegistry, Hypium } from '@kit.TestKit'
import { ExpressionPercentTest } from './calculator/ExpressionPercentTest'

export default function abilityInit(): void {
  Hypium.hypiumTest(abilityDelegatorRegistry.getAbilityDelegator(), (): void => {
    ExpressionPercentTest()
  })
}
