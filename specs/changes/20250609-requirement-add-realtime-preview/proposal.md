# 实时预览结果 需求提案

## 1. 需求概述

### 1.1 功能名称
实时预览计算结果（Realtime Preview）

### 1.2 需求类型
新增功能

### 1.3 关联特性
feat-calculator-core（OpenCalc 鸿蒙移植版，主计算器功能）

### 1.4 需求描述
在用户输入或修改表达式的过程中，**等号上方（结果区）实时显示当前表达式的计算预览值**，无需先按 `=` 即可看到结果。预览结果随输入/退格/清空等操作即时更新。原有 `=` 按钮行为保持不变（按下仍把当前表达式固化到历史记录）。

### 1.5 使用场景
- 场景 A：用户连续输入 `12+3`，无需按 `=` 即可在下方面板看到 `15`。
- 场景 B：用户输入 `100/3` 看到 `33.333…`，回退一格变成 `10/3` 预览随之变 `3.333…`。
- 场景 C：用户输入错误（除零、定义域错误等），预览区显示对应错误文案，不留旧值。
- 场景 D：用户输入尚不完整（如 `1+`），预览区回退到默认显示（`0` 或空白），不报错。

### 1.6 预期效果
- 每次 `expression` 状态发生变化时，结果区显示最新合法预览值或对应错误文案。
- `=` 按钮行为不变：保留历史记录和原有流程。
- 计算引擎复用，不引入新依赖；输入到预览的反馈延迟肉眼不可感知（<50 ms 即可接受）。

## 2. 需求解析报告

> 本章节由 rq-parse 产出。

### 2.1 意图分类
- **类型**：新增功能
- **一句话概括**：在表达式编辑过程中实时联动结果区展示当前表达式的计算结果，省去按 `=` 这一步。

### 2.2 领域映射
- **UI/交互**：结果区需要从「只在按 `=` 后渲染」改为「每次 expression 变化都渲染」。
- **状态管理**：现有 `@State expression` / `@State result` 联动方式需扩展为派生计算 / 监听式更新。
- **计算引擎**：复用 `CalcEngine.evaluate` + `Expression.getCleanExpression`，无需新增算法。
- **错误处理**：复用 `ErrorFlags` 体系，把错误文案同时路由到预览态。

### 2.3 影响层次
| 层次 | 变更类型 | 说明 |
|------|---------|------|
| View | modify | `DisplayPanel` 中结果 Text 由单一 `@State result` 驱动改为多源驱动（result + 预览 + error） |
| ViewModel | modify | `CalculatorPage` 增加 `updatePreview()` 方法；按钮回调 `onDigit/onOp/onFunc/onConst/onBS/onAC` 调用该方法 |
| Model | 不涉及 | 复用 `CalcEngine` / `Expression` / `ErrorFlags` / `NumberFormatter` / `HistoryItem` |
| 数据层 | 不涉及 | 不涉及持久化 |
| 基础设施 | 不涉及 | 不引入新工具/常量 |

### 2.4 关键实体
- **数据实体**：无新增。复用 `HistoryItem`、`CalculatorPreferences`。
- **页面实体**：`CalculatorPage.DisplayPanel`（结果 Text 区域）。
- **接口实体**：复用 `CalcEngine.evaluate`、`Expression.getCleanExpression`、`NumberFormatter.format`。
- **事件实体**：新增内部方法 `updatePreview()`（非 UI 事件）；状态变化 `expression` 是触发源。

### 2.5 模糊点
| # | 类别 | 描述 | 严重程度 |
|---|------|------|---------|
| 1 | 行为模糊 | 表达式语法不完整（`1+`、`(2` 等）时，预览区应该：①显示 `0` ②显示空白 ③保持上一次结果不动 | important |
| 2 | 行为模糊 | 按下 `=` 后，预览态值是否需要和 result 合并（显示在 result 区），还是预览态保持当前值 | nice-to-have |
| 3 | 行为模糊 | 预览延迟是否需要 debounce？目前每次按键都重算，对大表达式可能浪费算力 | nice-to-have |
| 4 | 范围模糊 | 是否需要为「实时预览」单独提供一个开关（设置项）？ | nice-to-have |
| 5 | 交互模糊 | 预览文案是否需要在右上角加一个明显的标识（例如「预览」前缀或图标）避免与正式 result 混淆 | nice-to-have |

### 2.6 复杂度评估
- **等级**：S
- **理由**：仅涉及 ViewModel 与 View，单文件改动；复用现有计算/格式化/错误处理链路；无新数据模型、无架构变更。

## 3. 需求澄清

> 本章节由 rq-clarify 产出。本需求只包含 1 条 important 模糊点（其余 nice-to-have 由实现阶段决定），采用 **GitHub Issue 评论 + 用户确认** 的方式澄清。

### 3.1 已澄清的关键决策
| # | 问题 | 决策 | 来源 |
|---|------|------|------|
| 1 | 表达式不完整时预览区显示什么？ | 显示空白（空字符串，与 AC 后的初始状态一致）；不显示 `0`，避免误导 | 用户在 GitHub Issue 评论回复中确认 |
| 2 | 实时预览是否提供开关？ | 默认开启，不新增设置项，保持「简单快捷」的体验基调 | 用户在 GitHub Issue 评论回复中确认 |
| 3 | 是否需要 debounce？ | 不需要，单次表达式求值极轻量（<1 ms），按键即算 | 低风险自动决策，todo.md 留痕 |

### 3.2 待定假设
以下未明确之处采用合理默认值（实现阶段可调整）：
- 预览文案字号略小于正式 result（约 24–28 pt），颜色略浅，避免与按下 `=` 后的 result 视觉混淆。
- 长表达式时，表达式文本与预览文本均允许换行（maxLines ≥ 2）。
- 预览态与 `=` 后的 result 视觉差异通过字号 / 颜色 / 字体权重共同区分，无需文字前缀。

### 3.3 功能边界
- **包含**：表达式编辑过程中实时联动结果；按下 `=` 仍写入历史；表达式错误时显示对应错误文案。
- **不包含**：debounce 节流；新增设置项；预览缓存/历史快照。

## 4. 需求详述

### 4.1 功能需求

#### FR-1：表达式变化触发预览
**描述**：每次 `@State expression` 发生变化（按钮点击、AC、退格）时，自动调用预览计算，刷新结果区。
**验收条件**：
- 输入数字 / 运算符 / 函数 / 常量后，结果区立即显示最新预览值。
- 退格后，预览值随之更新。
- AC 后，预览区回到空白。

#### FR-2：表达式不完整时不渲染预览
**描述**：当表达式语法不完整（无法解析）时，预览区显示空白，不显示旧的计算结果，避免误导。
**验收条件**：
- `1+`、`(`、`sin(` 等中间态 → 预览区为空。
- 不显示 `0`，不留旧值。

#### FR-3：错误态走原错误链路
**描述**：预览态遇到除零、定义域错误、语法错误等，沿用现有 `ErrorFlags` 体系，把错误文案渲染到结果区。
**验收条件**：
- `1/0` → 预览显示 `除数不能为零`，颜色用 `getErr()`。
- `ln(-1)` → 预览显示 `定义域错误`。
- 错误清除后，下次合法输入立即恢复预览。

#### FR-4：`=` 按钮行为保持不变
**描述**：按下 `=` 时，仍执行原 `onEquals()`：写入历史、固化 result。
**验收条件**：
- 按下 `=` 后，result 区显示当前计算结果（与预览一致）。
- 历史记录新增一条 `expression → result`。
- 再次编辑 expression，预览态重新启用。

### 4.2 可靠性需求

#### REQ-DFR-001：预览计算异常隔离
**描述**：预览计算必须 try/catch 包裹，避免异常态（如算式生成过程中抛错）影响 UI 渲染或导致崩溃。
**关注点**：
- 故障检测：try/catch 捕获后显示 `计算错误` 文案。
- 故障恢复：下一次 expression 变更时再次尝试。
- 降级策略：若 `getCleanExpression` 或 `evaluate` 抛出异常，预览区显示 `计算错误`（与现有 `onEquals` catch 行为一致）。

## 5. 影响范围分析

### 5.1 涉及的模块
| 模块 | 现有功能 | 新增/修改 |
|------|---------|-----------|
| `CalculatorPage.ets` | 单一 `@State result`，仅在 `onEquals` 赋值 | 增加 `updatePreview()` 方法；按钮回调插入调用；DisplayPanel 改为多源渲染 |

### 5.2 代码依赖分析
- 复用 `CalcEngine.evaluate(equation, isDegree): number`
- 复用 `Expression.getCleanExpression(calculation, decimalSeparatorSymbol, groupingSeparatorSymbol): string`
- 复用 `NumberFormatter.format(raw, decimalSep, groupingSep, NumberingSystem): string`
- 复用 `ErrorFlags`（division_by_0 / domain_error / syntax_error / is_infinity / require_real_number）
- 复用 `getErr() / getT1() / getT2() / isLandscape` 主题/横竖屏辅助方法

无新增模块、无新增接口、无新增依赖。

## 6. 复杂度评估

### 6.1 评估结果
- **复杂度等级**：简单
- **影响模块数**：1（`CalculatorPage.ets`）
- **架构变更**：否
- **数据模型变更**：否

### 6.2 跳过策略
| 制品 | 是否产出 |
|------|---------|
| proposal.md | 必须 ✅ |
| delta-spec.md | 必须 ✅ |
| new-arch.md | 跳过（无架构变更） |
| delta-design.md | 必须 ✅ |
| tasks.md | 必须（后续阶段产出） |

## 7. 待解决问题
- 无遗留 blocker / important 问题。
- nice-to-have 项（debounce / 设置开关 / 「预览」前缀文案）已记入 todo.md，后续 Issue 单独跟踪。