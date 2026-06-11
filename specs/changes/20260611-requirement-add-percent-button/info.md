# Info — 代码仓上下文分析

## 1. 模块拓扑
```
opencalc/                              (HarmonyOS 主工程)
├── entry/src/main/ets/
│   ├── calculator/
│   │   ├── Calculator.ets             (CalcEngine 递归下降求值器)
│   │   ├── Expression.ets             (预处理器,内含 % 重写)
│   │   └── NumberFormatter.ets
│   ├── pages/
│   │   ├── CalculatorPage.ets         (主页面,含 % 按钮)
│   │   └── Index.ets
│   ├── model/ErrorFlags.ets           (全局错误标志)
│   └── preferences/PreferencesStore.ets
└── entry/src/ohosTest/                ⚠ 缺失,本次新建
```

## 2. 关键代码位置(行号锚点)

### 2.1 % 按钮(已存在)
- `opencalc/entry/src/main/ets/pages/CalculatorPage.ets:278`
  ```ets
  Row() { this.BtnActPct('AC'); this.BtnOpPct('%'); this.BtnOpPct('('); this.BtnOpPct(')'); this.BtnOpPct('÷') }
  ```
- `CalculatorPage.ets:306` 定义 `BtnOpPct(l)`,`onClick` → `this.onOp(l)` 即 `this.onOp('%')` → 表达式末尾追加 `%`

### 2.2 表达式预处理(已存在)
- `opencalc/entry/src/main/ets/calculator/Expression.ets:14-17`
  ```ets
  if (cleanCalculation.indexOf('%') !== -1) {
    cleanCalculation = this.getPercentString(cleanCalculation)
    cleanCalculation = this.replaceAll(cleanCalculation, '%', '/100')
  }
  ```
- `Expression.ets:169-255` `getPercentString(calculation)`:
  - **核心算法**:对每个 `%`,向前找最近的运算符 `+/-/×/÷`:
    - `+` `-` ⇒ 重写为 `base + base*(num/100)`(语义 = 加价/降价)
    - `*` `/` ⇒ 重写为 `op*(num/100)`(语义 = 纯比例)
    - 无运算符 ⇒ 重写为 `(num/100)`(单纯小数)
  - 处理括号嵌套、`!%`(阶乘+百分号)、`)%`(括号后百分号)

### 2.3 求值入口
- `CalculatorPage.ets:77-99` `onEquals()`:
  1. `this.expr.getCleanExpression(this.expression, '.', ',')` — 触发 % 重写
  2. `this.engine.evaluate(clean, !this.radianMode)` — 数值求值
  3. 检查 `ErrorFlags`,格式化结果

## 3. 测试基础设施

### 3.1 已有
- `oh-package.json5` 已声明 `@ohos/hypium@1.0.15` 和 `@ohos/hamock@1.0.0`

### 3.2 缺失
- `entry/src/ohosTest/` 目录及 `module.json5`、`List.test.ets`(hypium 入口)均缺失
- 本次将补齐最小可工作的测试模块

## 4. 验证算法的纯数学推演(笔算)

输入 `50+10%`:
1. `getCleanExpression("50+10%", ".", ",")`:
2. `replaceSymbols` 无变化
3. `addMultiply` 无变化(`%` 后无 `0-9π(`)
4. `indexOf('%') = 5`,进入 `getPercentString`:
   - i=5, ch='%', parenthesisLevel=0, !done[5]
   - i-1=4 ch='0' 数字 ≠ `!` ≠ `)`,走"常规数字"分支
   - start = 4, 向左:'1'→'0'→'+'(停),start=2
   - opPos = `lastIndexOfAny(result.substring(0,3))` = `lastIndexOfAny("50+")` = 2
   - result.charAt(2) = '+',走 else 分支
   - base = "50", num = result.substring(3, 5) = "10"
   - result = "50" + "+" + "50" + "*(" + "10" + "/100)" + "" = `"50+50*(10/100)"`
5. `replaceAll('%', '/100')` 无 % 已消失
6. `addParenthesis` 平衡
7. 引擎求值:`50 + 50 * (10/100)` = `50 + 5` = **`55`** ✓

## 5. 风险/边界

| 风险 | 严重度 | 缓解 |
|------|--------|------|
| `%` 与中文输入法冲突 | 低 | 按钮直接发送字符,不走输入法 |
| `getPercentString` 中 `done[500]` 硬上限 | 中 | 本 Issue 不会触发(单次表达式 % 个数极少) |
| HarmonyOS hvigorw 在 Windows + 当前签名路径下不可用 | 高 | 用 Node 镜像脚本做 CI/兼容验收,hypium 测试仅做仓库内交付 |
