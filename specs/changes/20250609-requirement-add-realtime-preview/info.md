# 实时预览结果 — 代码仓理解（info.md）

## 基本信息

- **需求类别**：新增功能（在现有 CalculatorPage 内增加预览联动）
- **需求名称**：实时预览结果（Realtime Preview）
- **关联特性**：feat-calculator-core（OpenCalc HarmonyOS 移植版主计算器）
- **分析时间**：2026-06-09
- **分析范围**：`opencalc/entry/src/main/ets/` 全部源文件 + `opencalc/spec/` 设计文档

## 项目结构概览

```
opencalc/
├── AppScope/
│   └── app.json5                        # 应用基本信息
├── build-profile.json5                  # 工程构建配置
├── oh-package.json5                     # 顶层包配置（modelVersion 6.0.2）
├── entry/
│   ├── oh-package.json5                 # entry 包配置
│   ├── build-profile.json5
│   └── src/main/
│       ├── module.json5
│       └── ets/
│           ├── entryability/
│           │   └── EntryAbility.ets     # UIAbility 入口
│           ├── pages/
│           │   ├── Index.ets            # 路由入口
│           │   └── CalculatorPage.ets   # 主计算器页面（@Entry，1447 行移植自 MainActivity.kt）
│           ├── calculator/
│           │   ├── Calculator.ets       # CalcEngine：递归下降解析器（417 行移植自 Calculator.kt）
│           │   ├── Expression.ets       # 输入预处理（移植自 Expression.kt）
│           │   └── NumberFormatter.ets  # 数字格式化（移植自 NumberFormatter.kt）
│           ├── model/
│           │   ├── Models.ets           # CalculatorError / HistoryItem / CalculatorPreferences
│           │   └── ErrorFlags.ets       # 全局静态错误标志
│           └── preferences/
│               └── PreferencesStore.ets # 偏好持久化封装
└── spec/
    ├── DESIGN.md                        # 总体设计文档
    ├── ARCH_ANALYSIS.md                 # 架构分析
    └── TASK_BOARD.md                    # 任务板
```

> 注：`spec/DESIGN.md` 文档规划了 `pages/` 和 `components/` 两层目录分离（DisplayPanel/ButtonGrid/HistoryPanel/SettingsPanel），但实际代码所有面板/网格均以 `@Builder` 内联于 `CalculatorPage.ets`（共 415 行），与设计文档略有出入。本次需求继续沿用内联实现，不拆分组件。

## 架构分析

### 模块分层（ArkTS 单 HAP）

```
┌─────────────────────────────────────────────────────────┐
│ View 层                                                   │
│   pages/CalculatorPage.ets (415 行)                       │
│   - @Entry @Component                                     │
│   - 内含 DisplayPanel / ButtonGrid / HistoryPanel /       │
│     SettingsPanel / AboutPanel 等 @Builder                │
│   - 状态：@State expression / result / errorMsg /         │
│     showHistory / scientific / themeIdx ...                │
├─────────────────────────────────────────────────────────┤
│ ViewModel 层（与 View 合并，未独立拆分）                   │
│   onDigit/onOp/onFunc/onConst/onBS/onAC/onEquals/         │
│   onCopy/onHistoryTap/onHistoryDelete 等方法              │
├─────────────────────────────────────────────────────────┤
│ 计算引擎层（calculator/）                                 │
│   - CalcEngine.evaluate(equation, isDegree): number       │
│   - Expression.getCleanExpression(calc, dec, group): string│
│   - NumberFormatter.format(...): string                   │
├─────────────────────────────────────────────────────────┤
│ Model 层（model/）                                        │
│   - ErrorFlags（静态错误标志，全局共享）                   │
│   - Models.ets（HistoryItem / CalculatorPreferences /     │
│     CalculatorError 枚举）                                │
├─────────────────────────────────────────────────────────┤
│ 数据持久化层（preferences/）                              │
│   - PreferencesStore（包装 @ohos.data.preferences）       │
└─────────────────────────────────────────────────────────┘
```

### 模块依赖关系

```
CalculatorPage.ets
  ├── import { Expression } from '../calculator/Expression'
  ├── import { CalcEngine } from '../calculator/Calculator'
  ├── import { NumberFormatter } from '../calculator/NumberFormatter'
  ├── import { NumberingSystem, HistoryItem } from '../model/Models'
  ├── import { ErrorFlags } from '../model/ErrorFlags'
  ├── import { PreferencesStore } from '../preferences/PreferencesStore'
  └── import { promptAction } from '@kit.ArkUI'
                  └── { pasteboard } from '@kit.BasicServicesKit'
                  └── { common } from '@kit.AbilityKit'

CalcEngine.ets ← ErrorFlags
Expression.ets ← ErrorFlags
NumberFormatter.ets ← NumberingSystem（types only）
Models.ets ← （无依赖）
ErrorFlags.ets ← （无依赖）
PreferencesStore.ets ← （无内部依赖，包装系统 API）
```

### 扩展点

- 通过新增 `@Builder` 与 `@State` 字段在 `CalculatorPage.ets` 内扩展，无需新模块。
- 通过在现有按钮回调中插入 `updatePreview()` 调用即可触发预览刷新。

## 接口/契约识别

### 关键复用接口

| 接口 | 签名 | 说明 | 调用约束 |
| --- | --- | --- | --- |
| `CalcEngine.evaluate` | `(equation: string, isDegree: boolean) => number` | 解析并求值 | 必须先调用 `ErrorFlags.reset()`，否则会读到上一次的错误状态 |
| `Expression.getCleanExpression` | `(calc: string, dec: string, group: string) => string` | 清洗表达式（替换符号、补乘号、补括号等） | 若 `ErrorFlags.syntax_error` 在清洗过程中被置位，应放弃求值 |
| `NumberFormatter.format` | `(text: string, dec: string, group: string, sys: NumberingSystem) => string` | 数字转字符串（千分位+小数点） | 入参是 `number.toString()` 后的字符串 |
| `ErrorFlags.reset` | `() => void` | 清空所有错误标志 | 求值前必须调用 |
| `ErrorFlags.*` | `static boolean` 5 个字段 | `syntax_error` / `division_by_0` / `domain_error` / `is_infinity` / `require_real_number` | 求值后读 |

### ArkTS 限制说明

- 顶部 import 的变量是只读快照，所以 `ErrorFlags` 用类的 `static` 字段而非 `let` 全局变量。
- `Expression.getCleanExpression` 内部会修改 `ErrorFlags.syntax_error`（如 `addParenthesis` 检测到右括号多于左括号时）。
- `CalcEngine.evaluate` 解析失败时不会抛异常，而是通过 `ErrorFlags` 反馈。

## 公共组件或函数识别

### 可复用组件

| 组件/函数 | 位置 | 复用方式 | 备注 |
| --- | --- | --- | --- |
| `CalcEngine` 实例 | CalculatorPage.ets 字段 `engine: CalcEngine` | 已有实例直接复用 | 单例足够，无需每次新建 |
| `Expression` 实例 | CalculatorPage.ets 字段 `expr: Expression` | 已有实例直接复用 | 同上 |
| `NumberFormatter.format` | calculator/NumberFormatter.ets | 静态方法直接调用 | 已存在 |
| `ErrorFlags.reset` | model/ErrorFlags.ets | 静态方法直接调用 | 必须每次预览前调用 |
| 主题辅助方法 `getT1/getT2/getErr/getEq` | CalculatorPage.ets 实例方法 | 直接调用 | 用于字号/颜色 |

### 复用建议

- 不要新建计算/格式化/错误处理类，全部复用现有链路，避免重复实现。
- 预览流程 `updatePreview()` 应独立于 `onEquals()`，但共享 `getCleanExpression + evaluate + format` 三件套。

## 影响范围分析

### 需要修改的文件清单

| 文件 | 变更类型 | 变更点 |
| --- | --- | --- |
| `entry/src/main/ets/pages/CalculatorPage.ets` | modify | (1) 新增 `@State preview: string = ''`；(2) 新增私有方法 `updatePreview()`；(3) 在 `onDigit/onOp/onFunc/onConst/onBS/onAC` 内追加 `this.updatePreview()`；(4) `DisplayPanel` 中结果 Text 改为优先渲染 `this.preview`，按下 `=` 后用 `this.result`；(5) 视觉差异（字号/颜色） |

### 不需要修改的文件

- `calculator/Calculator.ets` — 复用
- `calculator/Expression.ets` — 复用
- `calculator/NumberFormatter.ets` — 复用
- `model/ErrorFlags.ets` — 复用
- `model/Models.ets` — 复用
- `preferences/PreferencesStore.ets` — 不涉及
- `entryability/EntryAbility.ets` — 不涉及
- `pages/Index.ets` — 不涉及

### 调用链影响分析

```
[按键事件]
    ↓
[onDigit/onOp/onFunc/onConst/onBS/onAC]
    ↓ (原有) expression 状态变更
    ↓ (新增) updatePreview()
        ↓
        ErrorFlags.reset()
            ↓
        expr.getCleanExpression(expression, '.', ',')
            ↓
        engine.evaluate(clean, !this.radianMode)
            ↓
        [分支]
            ├── ErrorFlags.* → preview = 错误文案
            ├── 正常结果 → NumberFormatter.format(...) → preview
            └── 异常 catch → preview = '计算错误'
    ↓
[DisplayPanel 渲染结果 Text]
    ↓
[ArkUI 单线程刷新]
```

`onEquals` 流程不变：
```
[BtnEq.onClick] → onEquals() → result = preview（或重算）→ 写历史
```

## 现有代码分析

### 关键代码片段（与本次需求直接相关）

**CalculatorPage.ets 现有 @State 字段（line 16-31）**：
```typescript
@State expression: string = ''
@State result: string = ''
@State errorMsg: string = ''
```

**现有按钮回调（line 70-75）**：
```typescript
onDigit(d: string): void { this.expression = this.expression + d; this.errorMsg = '' }
onOp(op: string): void { this.expression = this.expression + op; this.errorMsg = '' }
onFunc(f: string): void { this.expression = this.expression + f + '('; this.errorMsg = '' }
onConst(c: string): void { this.expression = this.expression + c; this.errorMsg = '' }
onBS(): void { if (this.expression.length > 0) this.expression = this.expression.substring(0, this.expression.length - 1) }
onAC(): void { this.expression = ''; this.result = ''; this.errorMsg = ''; ErrorFlags.reset() }
```

**现有 onEquals（line 77-99）**：
- 调用 `ErrorFlags.reset()` → `expr.getCleanExpression` → `engine.evaluate`
- 根据 `ErrorFlags.*` 判断错误类型并赋值 `this.errorMsg`，否则 `this.result = NumberFormatter.format(...)`
- 写入历史（preferences）

**现有 DisplayPanel（line 225-253）**：
```typescript
@Builder DisplayPanel() {
  Column() {
    // 表达式行
    Text(this.expression.length > 0 ? this.expression : ' ') ...
    // 结果行
    if (this.errorMsg.length > 0) {
      Text(this.errorMsg).fontColor(this.getErr()) ...
    } else {
      Text(this.result.length > 0 ? this.result : '0') ...
    }
  }
  ...
}
```

### 边界条件

| 边界 | 当前处理 | 预览态处理 |
| --- | --- | --- |
| expression 为空 | 表达式行显示空白；结果行显示 `0` | preview = ''（不显示 0） |
| expression 不完整（`1+`） | 只能在 `=` 后报错 | preview = ''（不显示 0） |
| expression 引发错误 | onEquals 显示错误文案 | preview 显示错误文案 |
| 长表达式 | `maxLines(3)` | 保持 `maxLines(3)` |
| 横屏 | `isLandscape` 适配字号 | 保持现有横屏字号 |
| 主题（默认/AMOLED/暗色） | getT1/getT2/getErr | 预览用 getT2，result 用 getT1 |

### 关键变量说明

| 变量 | 类型 | 作用域 | 说明 |
| --- | --- | --- | --- |
| `expression` | `@State string` | CalculatorPage | 用户输入的原始表达式（含 `×÷π√e!%` 等显示符号） |
| `result` | `@State string` | CalculatorPage | `=` 后的固化结果（格式化字符串） |
| `errorMsg` | `@State string` | CalculatorPage | 错误文案 |
| `radianMode` | `@State boolean` | CalculatorPage | 弧度模式；`evaluate` 第二参数 `= !radianMode`（即 degree 模式） |
| `engine` | `CalcEngine` 实例 | CalculatorPage 单例 | 解析器 |
| `expr` | `Expression` 实例 | CalculatorPage 单例 | 清洗器 |

## 风险识别

### 技术风险

| 风险编号 | 风险描述 | 影响 | 缓解措施 |
| --- | --- | --- | --- |
| R-01 | `getCleanExpression` 可能修改 `ErrorFlags.syntax_error`，导致预览误判 | 中 | 在 `updatePreview()` 内先调用 `ErrorFlags.reset()`，求值前再读 syntax_error 判断是否完整 |
| R-02 | 用户在极快连续按键时（如输入长表达式），每次按键重算可能浪费算力 | 低 | 当前表达式长度一般 < 100 字符，单次求值 < 1ms，按键即算可接受；后续若需要可加 debounce |
| R-03 | 预览态 `preview` 与固化态 `result` 共存导致视觉/逻辑混淆 | 中 | 通过字号/颜色差异（24-28pt + getT2() vs 36pt + getT1()）区分；不引入文字前缀 |
| R-04 | 在 `=` 触发的瞬间 `preview` 还没刷新，导致 result 与 preview 不一致 | 低 | `onEquals` 内同步重算一次并赋值 `result`；preview 在后续编辑时刷新 |
| R-05 | 长表达式或科学函数求值可能极慢（Gamma 阶乘）阻塞 UI 线程 | 中 | 复用 onEquals 现有同步逻辑；如出现可感知卡顿，列入后续优化 |

### 兼容性风险

| 风险编号 | 风险描述 | 影响 | 缓解措施 |
| --- | --- | --- | --- |
| C-01 | 修改 DisplayPanel 可能影响横竖屏布局 | 低 | 沿用现有 `isLandscape` 分支，preview 与 result 共用同一 Text 区域 |
| C-02 | 修改 onEquals 流程可能影响历史记录 | 高 | onEquals 内部逻辑不动，仅在末尾多一次 preview 状态刷新 |
| C-03 | 主题切换后预览颜色需重新渲染 | 低 | `@State` 触发响应式更新，ArkUI 自动重绘 |

## 测试验证策略

### 测试场景清单

| 场景 | 验证方法 | 验收标准 |
| --- | --- | --- |
| 合法表达式预览 | 手动 + 单测 | `12+3` → preview = `15` |
| 退格联动 | 手动回归 | 输入 `12+3` 看到 `15`，退格到 `12+` 看到空白 |
| AC 清预览 | 手动 | AC 后 preview = '' |
| 除零错误 | 手动 | `1/0` → preview = `除数不能为零`（颜色 getErr） |
| 定义域错误 | 手动 | `ln(-1)` → preview = `定义域错误` |
| 语法错误 | 手动 | `1++` → preview = `表达式错误` |
| 无穷大 | 手动 | 极大值阶乘 → preview = `结果无穷大` |
| 复数需求 | 手动 | `(-1)^0.5` → preview = `需要实数` |
| `=` 后固化 | 手动 | 输入后按 `=` result 显示，HistoryPanel 新增一条 |
| 横屏预览 | 手动 | 横屏下预览字号与 result 字号仍可区分 |
| 主题切换 | 手动 | AMOLED/暗色主题下预览颜色符合主题 |
| 性能（百字符表达式） | 单测 + 手动 | 求值 < 50ms |

### 回归测试范围

- `=` 按钮行为不变
- 历史记录写入不变
- 偏好持久化不变
- 横竖屏布局不变
- 主题切换不变
- 长按复制功能不变（DisplayPanel 的 LongPressGesture）

### 单元测试建议

| 测试目标 | 覆盖函数 | 工具 |
| --- | --- | --- |
| `updatePreview()` 正确性 | CalculatorPage.updatePreview | `@ohos/hypium`（项目已配置 devDependency） |
| 错误文案分支 | ErrorFlags → preview 文案映射 | 同上 |
| 求值异常 catch | mock evaluate 抛异常 → preview = '计算错误' | 同上 |

## 监控运维支持

### 监控指标

不涉及（新功能无外部监控指标）。

### 配置项

不涉及（默认开启，无新增配置项）。

### 日志记录点

不涉及（本次变更不引入日志；异常 catch 内也不打日志，避免信息泄露与性能损耗）。

## 关键发现

### 可复用组件或函数
- `CalcEngine.evaluate` — 解析求值
- `Expression.getCleanExpression` — 表达式清洗
- `NumberFormatter.format` — 数字格式化
- `ErrorFlags`（5 个静态字段） — 错误反馈
- `getT1/getT2/getErr/getEq` — 主题色辅助方法
- 主题颜色方法全部为实例方法（`themeIdx` 分支），无主题切换性能问题

### 风险提示
- ⚠️ `getCleanExpression` 会修改 `ErrorFlags.syntax_error`（如 `addParenthesis` 检测到右括号多于左括号时），必须在求值前重置 ErrorFlags，并在求值后**根据 ErrorFlags 实际状态**判断是否赋值 preview。
- ⚠️ 不完整表达式 `1+` 求值时，`engine.evaluate` 内部 `parseExpression` 会消化 `1` 后因无操作数进入 `parseFactor` 触发 `syntax_error = true` 并返回 0。可借此判定"不完整"。
- ⚠️ 极长阶乘（`n >= 3000`）会触发 `is_infinity`；用户可能反复输入触发，需要做好错误文案渲染。

### 建议事项
1. `updatePreview()` 内部逻辑与 `onEquals()` 的核心计算部分高度相似，建议提取为私有方法 `compute(expression: string): { value: string, error: string }` 共享，避免代码重复。
2. 预览文案字号建议 `isLandscape ? 22 : 28`（略小于 result 的 `28/36`），颜色用 `getT2()`。
3. 表达式不完整判定优先用 `ErrorFlags.syntax_error`，辅以 `ErrorFlags.*` 全清原则（保证状态机干净）。
4. `onEquals` 内可在末尾调用 `this.preview = this.result`（如果想维持预览态显示与 result 一致），或保持 preview 不动（保留上一次的"预览感"）。建议保持 preview 不动，避免 `=` 后又被立即擦除。