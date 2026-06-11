# 百分号按钮 - 代码仓理解

## 基本信息

- **需求类别**: 新增功能（同时含一处缺陷修复 REQ-7-07）
- **需求名称**: requirement-add-percentage-btn
- **分析时间**: 2026-06-11 18:00
- **分析范围**: opencalc/entry/src/main/ets/{calculator,pages,model}
- **测试根目录**: opencalc/entry/src/test/ets（现状不存在，需新建）

## 架构分析

### 模块结构

```
opencalc/
├── entry/
│   ├── src/main/ets/
│   │   ├── calculator/
│   │   │   ├── Calculator.ets         // 计算引擎（递归下降解析器）
│   │   │   ├── Expression.ets         // 表达式预处理（%/√/!）
│   │   │   └── NumberFormatter.ets    // 数字格式化
│   │   ├── entryability/EntryAbility.ets
│   │   ├── model/
│   │   │   ├── ErrorFlags.ets         // 错误标志（静态对象）
│   │   │   └── Models.ets             // HistoryItem / NumberingSystem
│   │   ├── pages/
│   │   │   ├── CalculatorPage.ets     // 主页面
│   │   │   └── Index.ets              // 入口
│   │   └── preferences/
│   │       └── PreferencesStore.ets   // 历史/偏好持久化
│   └── src/test/  ← 不存在，需新建
└── hvigorfile.ts
```

### 核心模块职责

| 模块 | 职责 | 关键入口 |
|------|------|---------|
| `CalculatorPage` | UI 渲染、按钮事件、计算流程触发 | `onEquals()`, `onOp()` |
| `Expression` | 输入预处理（%/√/!/隐式乘/括号补齐） | `getCleanExpression()` |
| `CalcEngine` | 递归下降解析 + 数学函数 | `evaluate()` |
| `ErrorFlags` | 跨调用的错误状态 | `division_by_0`, `syntax_error` 等 |

### 关键调用链

```
用户点 %
  → onOp('%') 把字符加入 expression
  → 用户点 =
  → onEquals()
  → this.expr.getCleanExpression(expression, '.', ',')
      → replaceSymbols()
      → addMultiply()
      → getPercentString()   ← 本次变更的关注点
      → replaceAll('%', '/100')
      → formatFactorial() / formatSquare() / addParenthesis()
  → this.engine.evaluate(clean, !radianMode)
      → 递归下降解析为数字
```

## 接口/契约识别

| 接口 | 位置 | 输入 | 输出 | 副作用 |
|------|------|------|------|--------|
| `Expression.getCleanExpression` | Expression.ets:8 | `(calculation, decimalSep, groupSep)` | `string` | 设置 `ErrorFlags.syntax_error` |
| `Expression.getPercentString` | Expression.ets:169 | `calculation: string` | `string` | 设置 `ErrorFlags.syntax_error` |
| `CalcEngine.evaluate` | Calculator.ets:28 | `(equation, isDegree)` | `number` | 设置各类 `ErrorFlags` |
| `CalculatorPage.onOp` | CalculatorPage.ets:71 | `op: string` | `void` | 追加到 `this.expression` |

## 公共组件或函数识别

- `BtnOpPct` (CalculatorPage.ets:306) — 5 列布局版的运算符按钮，已被 `AC ( ) ÷` 复用，**`%` 已调用**（line 278）
- `onOp(l)` — 已处理任意运算符追加，可直接复用

## 影响范围分析

### 需要修改/新建的文件

| 文件 | 动作 | 说明 |
|------|------|------|
| `opencalc/entry/src/main/ets/calculator/Expression.ets` | modify | 修复 REQ-7-07 bug（`50+10%` 错算为 5） |
| `opencalc/entry/src/main/ets/pages/CalculatorPage.ets` | modify (可能无) | `%` 按钮已存在；如需微调颜色/位置再改 |
| `opencalc/entry/src/test/ets/.../ExpressionPercentTest.ets` | new | 单元测试 |
| `opencalc/entry/build-profile.json5` | modify | 注册 test sourceSet |
| `opencalc/entry/src/test/ets/List.test.ets` | new (可能) | Hypium 入口 |

### 调用链上下游

- 上游：`onEquals()` → `Expression.getCleanExpression()` → 涉及 REQ-7-07 的 `getPercentString()`
- 下游：`CalcEngine.evaluate()` 收到 ASCII 表达式后做四则运算

## 现有代码分析

### `Expression.getPercentString` (Expression.ets:169-255) 当前实现

3 个分支:
1. `!` 前置 → `((x!)/100)`
2. `)` 前置 → `((subExpr)/100)` 或 `base + base*((subExpr)/100)`
3. 默认（数字前置）→ `num/100` 或 `base + base*(num/100)`

### 关键 bug (REQ-7-07)

在"默认"分支：

```ts
let start: number = i - 1
while (start >= 0 && (this.isDigit(result.charAt(start)) || result.charAt(start) === '.')) {
  start = start - 1
}
const opPos: number = this.lastIndexOfAny(result.substring(0, start + 1), ['+', '-', '*', '/'])
```

输入 `"50+10%"`（i=4 指向 `%`）：
- start 回溯到 1（停在 `+`）
- `result.substring(0, start + 1)` = `"50"` — 范围过窄，找不到 `+`
- `opPos = -1` → 走"无 opPos"分支
- num = `"10"`，结果变成 `"50(10/100)"` → 计算结果 = 5

**期望**：`"50+(50*(10/100))"` = 55

### 修复方向

将 `result.substring(0, start + 1)` 改为 `result.substring(0, i)`，使 `opPos` 找到 `+`。`num` 计算用 `result.substring(opPos + 1, i)` 已正确。

### 边界条件

- 括号嵌套：已有处理 (`parenthesisLevel`)
- 多重 %：`done[]` 标志位
- 阶乘后 %：已处理
- 末尾 %：未在 `addMultiply` 加 `*`，符合"前置 num 完整"预期

## 风险识别

| 风险 | 等级 | 缓解 |
|------|------|------|
| 修复 REQ-7-07 时改坏其他百分号用例 | 中 | 先写完整单元测试 (REQ-7-02~06) 再改 |
| 单元测试入口与 hvigor test 框架不匹配 | 中 | 参考 ohpm `@ohos/hypium` 1.0.15 文档的 `Ability.test.ets` 模板 |
| `ErrorFlags` 静态状态污染测试 | 中 | 测试 `beforeEach` 调 `ErrorFlags.reset()` |
| 横屏布局 `%` 被挤变形 | 低 | 当前在第二行 5 列布局内，宽度 17%，无明显风险 |

## 测试验证策略

### 测试场景清单（REQ-7-02~07）

| ID | 表达式 | 期望值 | 类型 |
| --- | --- | --- | --- |
| TC-01 | `50+10%` | 55 | 加法基数 |
| TC-02 | `200-10%` | 180 | 减法基数 |
| TC-03 | `100*10%` | 10 | 后置乘 |
| TC-04 | `100/10%` | 1000 | 后置除 |
| TC-05 | `50%` | 0.5 | 裸百分比 |
| TC-06 | `100+(50*20%)` | 110 | 复合 |
| TC-07 | `(100+50)*10%` | 15 | 括号内加+后置% |
| TC-08 | `5!%` | 0.012 (5!/100) | 阶乘后% |

### 验证方法

- 单元测试：`hvigorw test` 或本地 Hypium 入口
- 手动：在模拟器输入 50+10%=55

### 回归范围

- `Calculator.ets` 中所有函数（不修改）
- `Expression.ets` 中 `replaceSymbols/addMultiply/formatFactorial/formatSquare/addParenthesis`（不修改）
- `CalculatorPage.ets` UI（仅当 REQ-7-01 视觉调整时）

## 监控运维支持

- 不涉及
- 无新增配置项

## 关键发现

### 可复用组件/函数
- `BtnOpPct` (CalculatorPage.ets:306) — 直接复用
- `onOp(l)` — 直接复用
- `Expression.getPercentString` — 修复后直接复用

### 风险提示
- REQ-7-07 bug 是隐藏的（如不修测试，线上用户会发现 50+10% 算错）
- 单元测试基础设施完全缺失，本次需从零搭

### 建议事项
- 本次只修 REQ-7-07 一处 bug，不动其他算子
- 单元测试放在 `entry/src/test/ets/calculator/ExpressionPercentTest.ets`
