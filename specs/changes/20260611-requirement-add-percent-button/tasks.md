# Tasks — 百分号按钮交付任务分解

## 任务列表(按 TDD RED-GREEN-REFACTOR 排序)

| # | 任务 | 类型 | 依赖 | 验证方法 | 产出物 |
|---|------|------|------|---------|--------|
| T1 | 编写 Node 镜像验证脚本骨架(故意 fail)— **RED** | TEST | - | `node tools/percent-verify.js` 退出码非 0 | `tools/percent-verify.js` |
| T2 | 镜像 `Expression.getPercentString` 算法到 JS,跑通 6 AC — **GREEN** | IMPL | T1 | 退出码 0,6/6 PASS | 同上 |
| T3 | 重构 — 抽取测试用例数组,清理注释 — **REFACTOR** | REFACTOR | T2 | 重跑仍 6/6 PASS | 同上 |
| T4 | 新建 `entry/src/ohosTest/module.json5` | INFRA | - | 文件存在,JSON5 语法正确 | `module.json5` |
| T5 | 新建 hypium 测试入口 `List.test.ets`、`OpenHarmonyTestRunner.ts`、`testability/pages/Index.ets` | INFRA | T4 | 文件结构匹配 hypium 规范 | 3 个文件 |
| T6 | 新建 `Expression.test.ets` 写 5 个单元测试覆盖 AC1-AC5 | TEST | T5 | 代码静态审查通过 | `Expression.test.ets` |
| T7 | 新建 `Calculator.test.ets` 写端到端测试 `50+10%=55` | TEST | T5 | 代码静态审查通过 | `Calculator.test.ets` |
| T8 | 微调 `CalculatorPage.ets`:在 `BtnOpPct('%')` 行上加注释引用 Issue #8 | DOCS | - | grep 找到 `Issue #8` | `CalculatorPage.ets` |
| T9 | 静态审查 `BtnOpPct('%')` → `onOp('%')` → `expression += '%'`(AC6) | VERIFY | T8 | grep 全链路 | apply-report 章节 |

## 任务依赖图
```
T1 ─▶ T2 ─▶ T3
T4 ─▶ T5 ─▶ T6
                  └─▶ T7
T8 ─▶ T9
```

T1-T3 与 T4-T7 与 T8-T9 **三组互不依赖**,但 RED-GREEN-REFACTOR 必须串行。

## 执行顺序(线性)
1. **T1** (RED)
2. **T2** (GREEN)
3. **T3** (REFACTOR)
4. T4 → T5 → T6 → T7
5. T8 → T9
6. 汇总 apply-report.md

## 各任务的"完成定义"(DoD)

### T1 RED
- 创建 `tools/percent-verify.js`,内含 6 个 AC 用例
- 故意 **未实现** `simulatePercent()`,使其返回 `null`
- `node tools/percent-verify.js` 输出 6/6 FAIL,退出码 1

### T2 GREEN
- 将 `getPercentString` 算法翻译为 JS 并填入 `simulatePercent()`
- 再加上简易求值器(纯数学表达式 `+-*/()`,无需支持函数)
- 重跑 `node tools/percent-verify.js` 输出 6/6 PASS,退出码 0

### T3 REFACTOR
- 抽取 `CASES` 数组到顶部
- 去掉调试 console.log
- 函数 JSDoc 注释完整
- 重跑仍 6/6 PASS

### T4-T5 ohosTest 模块骨架
- `module.json5` 包含 `"type":"feature"` 和 `"deviceTypes"`
- `List.test.ets` 调用 `expressionTest()` 和 `calculatorTest()`
- `OpenHarmonyTestRunner.ts` 标准模板

### T6-T7 hypium 用例
- 用 `describe/it/expect` 包装
- 至少包含 6 个 `it()`

### T8 文档微调
- 在 `Row() { this.BtnActPct('AC'); this.BtnOpPct('%'); ...` 行上一行加 `// Issue #8: 百分号按钮 — AC1 50+10%=55`

### T9 静态验证
- grep `BtnOpPct\('%'\)` 命中 1 处
- grep `onOp` 在 BtnOpPct Builder 内命中
- grep `expression = this.expression + op` 在 onOp 命中
