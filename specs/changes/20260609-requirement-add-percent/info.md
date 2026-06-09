# 增加%按钮 - 代码仓理解

## 基本信息

- **需求类别**: 新增功能（实质是修正 `%` 语义并补全缺失的工程语义实现）
- **需求名称**: 增加%按钮
- **分析时间**: 2026-06-09
- **分析范围**: `opencalc/entry/src/main/ets/calculator/Expression.ets`、`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`、`opencalc/entry/src/main/ets/calculator/Calculator.ets`、`opencalc/entry/src/main/ets/calculator/NumberFormatter.ets`、`opencalc/entry/src/main/ets/model/ErrorFlags.ets`

## 架构分析

### 模块结构
```
entry/src/main/ets/
├── pages/
│   └── CalculatorPage.ets       ← @Entry 主页（含 % 按钮）
├── calculator/
│   ├── Calculator.ets           ← CalcEngine.evaluate(): 解析+求值
│   ├── Expression.ets           ← Expression.getCleanExpression(): 输入预处理（含 %）
│   └── NumberFormatter.ets      ← 结果格式化
├── model/
│   ├── ErrorFlags.ets           ← 错误标志全局状态
│   └── Models.ets               ← 数据模型 (HistoryItem, Preferences 等)
├── preferences/
│   └── PreferencesStore.ets     ← 偏好 + 历史持久化
└── entryability/
    └── EntryAbility.ets         ← UIAbility 入口
```

### 核心模块职责
- **CalculatorPage.ets**: UI 状态管理、按钮事件、调用 Expression 与 CalcEngine；含 `%` 按钮（`BtnOpPct('%')`，第 278、306 行）。
- **Expression.ets**: 字符串级预处理：符号替换 → `addMultiply` → `formatSquare` → `formatFactorial` → `getPercentString` → 补 `/100` → `addParenthesis`。
- **Calculator.ets**: 递归下降解析器（`parseExpression → parseTerm → parseFactor`）与求值；与 `%` 无直接耦合，仅消费预处理后的字符串。
- **ErrorFlags.ets**: 静态字段共享的"全局"错误状态；`getPercentString` 会写入 `syntax_error`。

### 模块依赖关系
```
CalculatorPage
    ↓ onOp('%')
    ↓ (字符串拼接)
    ↓ onEquals
    ↓ Expression.getCleanExpression()
    ↓   └─ getPercentString()  ← 修改焦点
    ↓   └─ addMultiply()        ← 受顺序影响
    ↓ CalcEngine.evaluate()      ← 与 % 解耦
    ↓ ErrorFlags 静态状态
```

## 接口/契约识别

| 接口 | 文件 | 签名 | 说明 |
| --- | --- | --- | --- |
| `Expression.getCleanExpression` | Expression.ets:8 | `(calculation: string, decimalSeparatorSymbol: string, groupingSeparatorSymbol: string): string` | 入口；当前 `%` 处理已先于 `addMultiply` 调用 |
| `Expression.getPercentString` | Expression.ets:170 | `(calculation: string): string` | 私有；处理数字/阶乘/括号三种 `%` 前缀场景 |
| `Expression.addMultiply` | Expression.ets:44 | `(calculation: string): string` | 私有；在数字/括号/函数间补 `*`；若先于 `%` 处理，会把 `10%` 改成 `10*%` |
| `Expression.addParenthesis` | Expression.ets:258 | `(calculation: string): string` | 私有；闭合括号补全；会写 `syntax_error` |
| `CalcEngine.evaluate` | Calculator.ets | `(expression: string, degreeMode: boolean): number` | 入口；接收已清理字符串求值 |
| `CalculatorPage.onOp` | CalculatorPage.ets:71 | `(op: string): void` | 处理运算符点击 |
| `CalculatorPage.onEquals` | CalculatorPage.ets:77 | `(): void` | 触发 `getCleanExpression` + `evaluate` |

## 公共组件或函数识别

| 名称 | 位置 | 复用建议 |
| --- | --- | --- |
| `Expression.replaceAll` | Expression.ets:281 | 字符替换；当前用于 `% → /100` 兜底 |
| `Expression.insertChar` | Expression.ets:273 | 字符插入；`getPercentString` 多次复用 |
| `Expression.lastIndexOfAny` | Expression.ets:291 | 寻找最近运算符；`getPercentString` 复用 |
| `Expression.isDigit` | Expression.ets:277 | 数字判定；多个预处理方法复用 |
| `ErrorFlags` | ErrorFlags.ets | 错误状态；`onEquals` 集中读取并显示提示 |
| `NumberFormatter.format` | NumberFormatter.ets | 结果格式化；`onEquals` 调用 |

## 影响范围分析

### 需要修改的文件
| 文件 | 改动类型 | 说明 |
| --- | --- | --- |
| `opencalc/entry/src/main/ets/calculator/Expression.ets` | 顺序 + 三分支补全 | 保留分支已存在未提交修改 `%` 早于 `addMultiply`；需进一步确认 `getPercentString` 三分支逻辑无回归 |

### 调用链
```
onEquals
  → Expression.getCleanExpression
       → replaceSymbols
       → getPercentString           ← 关键
       → replaceAll('%', '/100')    ← 兜底
       → addMultiply                ← 受顺序约束
       → formatSquare
       → formatFactorial
       → addParenthesis
  → CalcEngine.evaluate
       → parseExpression / parseTerm / parseFactor
       → 副作用：写 ErrorFlags
```

### 影响评估
- **对 `%` 用户体验**: 当前 `feat/issue-1-pct` 分支的修改使 `50+10%` 解析顺序正确，验证 Issue #1 验收。
- **对其他运算符**: `getPercentString` 在 `addMultiply` 之前，理论上 `√` 与 `!` 也会被前置处理 — `getPercentString` 内已递归处理 `(...)%` 与 `(...)!%`，未观测到冲突。
- **错误处理**: 任意 `%` 解析失败都应设置 `ErrorFlags.syntax_error`，UI 通过 `onEquals` 显示"表达式错误"。

## 现有代码分析

### `Expression.getPercentString` 三分支（行 199-248）
1. **`!` 前缀**: 形如 `n!%` → `((n!)/100)`，通过向后搜索数字/小数点边界。
2. **`)` 前缀**: 形如 `(expr)%`，向后匹配括号配对，按前一运算符类型改写：
   - `*` 或 `/` 前缀：`(expr)/100`
   - `+` 或 `-` 前缀：`(base)*(expr)/100`（base 来自括号前最近 `+/-` 之前）
   - 无前缀：`(expr)/100`
3. **数字前缀**: 形如 `n%`，按前一运算符类型改写（同 2，但 `expr = n`）。
   - **关键工程语义点**: `+`/`-` 前缀时改写为 `A + A*(B/100)` — 这就是 Issue #1 验收的核心。

### `getCleanExpression` 顺序（行 8-24）
当前 `feat/issue-1-pct` 分支版本（已修改）：
```
replaceSymbols
  → getPercentString           // % 改写
  → replaceAll('%', '/100')   // 残余 % 兜底
  → addMultiply                // 数字/括号/函数间补 *
  → formatSquare               // √(expr) → sqrt(expr)
  → formatFactorial            // n! → factorial(n)
  → addParenthesis             // 补齐右括号
```
与 main 分支（旧顺序）的差异：把 `addMultiply` 移到了 `%` 处理之后，避免 `10%` 被错误变成 `10*%`。

### 关键变量
- `parenthesisLevel` (Expression.ets:173): 括号层级，区分 `(%` 在表达式顶部还是嵌套中。
- `subStart` (Expression.ets:174): 当前括号子表达式的起点。
- `done: boolean[500]` (Expression.ets:175-176): `%` 位置处理标志位，限制表达式长度 ≤ 500。
- `ErrorFlags.syntax_error`: 错误传播唯一通道。

### 边界条件
- 空 `num`（如 `+%`）→ 立即设置 `syntax_error`
- `lvl !== 0`（括号未闭合）→ 立即设置 `syntax_error`
- 表达式长度 > 500 → `done[]` 数组访问越界（潜在 bug，FM-05）

## 风险识别

| 风险 | 等级 | 缓解 |
| --- | --- | --- |
| FM-04: `%` 处理晚于 `addMultiply` 产生 `10*%` | 高 | 已通过当前 `feat/issue-1-pct` 未提交修改缓解，需保持顺序 |
| FM-05: `done[500]` 数组硬编码上限 | 中 | 当前未触发；可在 spec 标注为 nice-to-have（截断或扩容） |
| FM-03: `%` 在科学函数内（`sin(30%)`） | 低 | 按语法错误处理（Issue 范围外） |
| FM-01/02: 非法 `%` 用法 | 低 | 已有 `ErrorFlags.syntax_error` 兜底 |
| `%` 按钮在主屏首行已存在；无 UI 改动 | — | — |
| 无单元测试覆盖 | 高 | 需新增 `%` 相关单元测试（IMPLEMENTING 阶段） |
| 与 Android 3.2.1 行为差异（不同 OS 计算器对 `5%+5%` 处理不同） | 中 | 与 Android 版本对齐（D1 决策） |

## 测试验证策略

### 测试场景（参考 delta-spec）
- `50+10% → 55`（Issue 验收）
- `100-20% → 80`
- `12.5+3.5% → 12.9375`
- `100*5% → 5`
- `50/200% → 250`
- `50% → 0.5`
- `(2+3)+10% → 5.5`
- `(2+3)*10% → 0.5`
- `5!% → 120`
- `(1+2)!% → 6`
- 错误用例：`+%`、`++%`、`sin(30%)`

### 验证方法
- 单元测试（ArkTS `ohosTest`/`unittest`）：`Expression.getCleanExpression` 输入输出断言
- 手动 UI 验证：在模拟器/真机按 `%` 按钮
- 回归：现有四则运算、科学函数、阶乘、对数测试不变绿

### 回归范围
- `Expression` 全部私有方法（`replaceSymbols`/`addMultiply`/`formatSquare`/`formatFactorial`/`addParenthesis`）
- `Calculator.parseExpression`/`parseTerm`/`parseFactor`
- `CalculatorPage` 全部按钮事件

## 监控运维支持

- 无新增外部依赖
- 无新增持久化字段
- 无新增权限
- 无新增后台任务
- 监控指标：可通过 `ErrorFlags.syntax_error` 触发频次间接度量 `%` 解析错误（本地埋点，IMPLEMENTING 阶段可选）

## 关键发现

### 可复用组件或函数
- `Expression.replaceAll` / `insertChar` / `lastIndexOfAny` / `isDigit` 已是工具方法
- `ErrorFlags` 机制完善，可直接复用

### 风险提示
- `feat/issue-1-pct` 分支当前未提交改动已修复 `%` 处理顺序，但未在 PR 描述或 commit 中说明；IMPLEMENTING 阶段需将其作为基线收编
- `done[500]` 数组是隐式约束（FM-05），应考虑软上限
- 缺少 ArkTS 单元测试基线，需新建

### 建议事项
- IMPLEMENTING 阶段首先确认/收编 `feat/issue-1-pct` 的未提交修改
- 建立 ArkTS 单元测试基础设施（`ohosTest`）
- `%` 测试覆盖优先级：SC-001 > SC-002 > SC-003/004 > SC-005/006
