// OpenCalc — 测试入口（hypium 风格）
// Issue #18 单位换算 — 注册所有 test 套件
// Issue #28 记忆槽 — 注册 MemorySlots test 套件

import expressionPercentTest from './ets/calculator/Expression.test.ets'
import unitConverterTest from './ets/common/UnitConverter.test.ets'
import naturalLanguageParserTest from './ets/common/NaturalLanguageParser.test.ets'
import memorySlotsTest from './ets/calculator/MemorySlots.test.ets'

export default function testsuite() {
  expressionPercentTest()
  unitConverterTest()
  naturalLanguageParserTest()
  memorySlotsTest()
}
