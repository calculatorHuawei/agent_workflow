// OpenCalc — 测试入口（hypium 风格）
// Issue #22 程序员模式 — 注册所有 test 套件
// Issue #26 函数图像 — 注册 PlotUtils + evaluateAt test 套件

import expressionPercentTest from './ets/calculator/Expression.test.ets'
import unitConverterTest from './ets/common/UnitConverter.test.ets'
import naturalLanguageParserTest from './ets/common/NaturalLanguageParser.test.ets'
import baseConverterTest from './ets/calculator/BaseConverter.test.ets'
import plotUtilsTest from './ets/common/PlotUtils.test.ets'
import calculatorEvaluateAtTest from './ets/calculator/Calculator.test.ets'

export default function testsuite() {
  expressionPercentTest()
  unitConverterTest()
  naturalLanguageParserTest()
  baseConverterTest()
  plotUtilsTest()
  calculatorEvaluateAtTest()
}
