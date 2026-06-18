// OpenCalc — 测试入口（hypium 风格）
// Issue #18 单位换算 — 注册所有 test 套件
// aid-workflow 20260618: Issue #29 键盘滑动 — 注册 KeyboardSwipe 套件

import expressionPercentTest from './ets/calculator/Expression.test.ets'
import unitConverterTest from './ets/common/UnitConverter.test.ets'
import naturalLanguageParserTest from './ets/common/NaturalLanguageParser.test.ets'
import keyboardSwipeTest from './ets/keyboard/KeyboardSwipe.test.ets'

export default function testsuite() {
  expressionPercentTest()
  unitConverterTest()
  naturalLanguageParserTest()
  keyboardSwipeTest()
}
