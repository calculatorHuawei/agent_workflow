# Delta Spec — 百分号按钮

## 与基线的差异

### 基线现状
- `CalculatorPage.ets:278` 已渲染 `BtnOpPct('%')`
- `Expression.ets:14-17` 已识别 `%` 字符并调用 `getPercentString`
- `Expression.ets:169-255` 已实现完整的百分号 → 等价表达式重写
- 引擎 `CalcEngine.evaluate` 不需要改

### 本次 Delta
**仅一个能力差异**:**缺乏可执行、可回归的验收证据**。

| 模块 | 基线 | 本次 Delta |
|------|------|-----------|
| `entry/src/main/ets/calculator/Expression.ets` | 已有百分号逻辑 | 不改 |
| `entry/src/main/ets/pages/CalculatorPage.ets` | 已有 `%` 按钮 | 微调:统一 `BtnOpPct` 改名/注释,确认无回归 |
| `entry/src/ohosTest/**` | **不存在** | **新建** hypium 单元测试目录 |
| `entry/src/ohosTest/ets/test/Expression.test.ets` | - | **新建** Expression 百分号专项测试(6 个 AC) |
| `entry/src/ohosTest/ets/test/Calculator.test.ets` | - | **新建** CalcEngine 端到端测试(`50+10%` ⇒ 55) |
| `tools/percent-verify.js` | - | **新建** 纯 JS 镜像算法验证脚本(脱离 hvigor 可在 Node 跑) |

### 本次不做
- ❌ 不改引擎 `Calculator.ets`
- ❌ 不调整按钮布局
- ❌ 不引入新的依赖
- ❌ 不修改主题颜色

## 验收条款(机器可验证)

| ID | 输入 | 期望输出 | 方法 |
|----|------|---------|------|
| AC1 | `50+10%` | `55` | hypium + node 镜像 |
| AC2 | `200-15%` | `170` | hypium + node 镜像 |
| AC3 | `30%` | `0.3` | hypium + node 镜像 |
| AC4 | `200*10%` | `20` | hypium + node 镜像 |
| AC5 | `(50+10)%` | `0.6` | hypium + node 镜像 |
| AC6 | UI 点击 % | 表达式追加 `%` | 代码静态审查(CalculatorPage `BtnOpPct('%')`.onClick → `onOp('%')`) |
