// OpenCalc — 测试入口（hypium 风格）
// Issue #18 单位换算 — 注册所有 test 套件
// aid-workflow 20260617: Issue #27 分数/小数显示切换 — 注册 FractionUtil 套件

import expressionPercentTest from './ets/calculator/Expression.test.ets'
import unitConverterTest from './ets/common/UnitConverter.test.ets'
import naturalLanguageParserTest from './ets/common/NaturalLanguageParser.test.ets'
import fractionUtilTest from './ets/common/FractionUtil.test.ets'

export default function testsuite() {
  expressionPercentTest()
  unitConverterTest()
  naturalLanguageParserTest()
  fractionUtilTest()
}
