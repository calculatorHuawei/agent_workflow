# 程序员模式 + 进制转换 需求提案

> **Issue**: #4
> **类型**: 新增功能（type:feature）
> **优先级**: ⭐⭐
> **关联特性**: feat-calculator
> **分支**: feat/issue-4-programmer-mode
> **生成时间**: 2026-06-10

---

## 1. 需求概述

### 1.1 功能名称

程序员模式 + 进制转换（Programmer Mode + Base Conversion）

### 1.2 需求类型

**新增功能**

### 1.3 关联特性

feat-calculator

### 1.4 需求描述

在 OpenCalc HarmonyOS 计算器中新增"程序员模式"，与现有的"基础模式/科学模式"并列。程序员模式下：

- **进制切换**：支持 DEC（十进制）/ BIN（二进制）/ OCT（八进制）/ HEX（十六进制）四种进制的实时切换与显示
- **进制转换**：当前输入或计算结果可同时以 4 种进制呈现
- **模式切换动画**：在基础/科学/程序员三模式间切换时有平滑过渡动画
- **适配键盘**：键盘按当前进制显示合法字符（BIN 仅 0/1，OCT 0-7，HEX 含 A-F）

### 1.5 使用场景

| # | 场景 | 用户行为 | 期望结果 |
|---|------|---------|----------|
| UC-01 | 程序员的位地址计算 | 切换到程序员模式，输入十进制 255 | 显示屏同时显示 `DEC: 255  BIN: 11111111  OCT: 377  HEX: FF` |
| UC-02 | 网络工程师子网掩码换算 | 输入十六进制 `FFFFFF00` | 自动换算为 `4294967040`（DEC）/ `11111111111111111111111100000000`（BIN） |
| UC-03 | 学生学习进制转换 | 输入二进制 `1010`，切换到 OCT 进制 | 表达式同步显示为 `12` |
| UC-04 | 普通用户偶然误入 | 从基础模式切换三次回到基础模式 | 关闭程序员功能，恢复纯计算器体验 |

### 1.6 预期效果

1. 用户通过顶部"基础 / 科学 / 程序员"三态切换按钮自由切换
2. 程序员模式下显示区扩展为 4 行（DEC/BIN/OCT/HEX 同时可见）
3. 切换时按钮网格与显示区有淡入淡出 + 平移过渡动画（≤300ms）
4. 所有进制数据基于 IEEE 754 number 类型的整数部分（≤2^53 安全整数）

---

## 2. 需求解析报告（rq-parse 产出）

### 2.1 意图分类

- **类型**：新增功能
- **一句话概括**：在 OpenCalc 计算器中新增"程序员模式"第三种工作模式，支持 DEC/BIN/OCT/HEX 四进制实时切换、同时显示和相互转换。

### 2.2 领域映射

| 领域 | 说明 |
|------|------|
| **UI/交互** | 模式切换栏扩展为三态、按钮网格按进制过滤、显示区扩展为多进制并行显示、模式切换动画 |
| **状态管理** | 当前模式（基础/科学/程序员）+ 当前进制（DEC/BIN/OCT/HEX）状态机的双向管理 |
| **数据管理** | 新增 `programmerModeDefault` / `defaultBase` 两个偏好项，写入 PreferencesStore |
| **基础计算** | 复用现有 Calculator 引擎的 `parseInt` / `toString(radix)` 实现转换逻辑 |

### 2.3 影响层次

| 层次 | 变更类型 | 说明 |
|------|---------|------|
| View | modify | CalculatorPage 扩展 ToggleRow（三态）、DisplayPanel（4 行）、ButtonGrid（按进制过滤） |
| View | new | 新增 `@Builder BaseConversionPanel` 组件（4 行进制显示） |
| View | new | 新增 `@Builder ProgrammerKeypad` 组件（程序员键盘，含 A-F） |
| ViewModel | modify | CalculatorPage 新增 `@State currentMode`、`@State currentBase` 字段 |
| Model | new | 新增 `CalculatorMode` 枚举、`NumberBase` 枚举 |
| 数据层 | extend | PreferencesStore 扩展 `getProgrammerModeDefault()`、`getDefaultBase()` |
| 基础设施 | new | 新增 `BaseConverter.ets` 工具类（toBase/fromBase/formatBase） |

### 2.4 关键实体

- **数据实体**：
  - `CalculatorMode`：枚举（BASIC / SCIENTIFIC / PROGRAMMER），状态机切换
  - `NumberBase`：枚举（DEC=10 / BIN=2 / OCT=8 / HEX=16）
  - `BaseDisplayItem`：结构 `{ base: NumberBase, value: string, label: string }`
  - `ProgrammerPreferences`：扩展 `CalculatorPreferences`，新增 `programmerModeDefault` + `defaultBase`
- **页面实体**：
  - `ModeToggleRow`（扩展现有 ToggleRow，支持三态点击循环）
  - `BaseConversionPanel`（新增，4 行实时显示）
  - `ProgrammerKeypad`（新增，数字 + A-F + 模式专属按钮）
  - `ModeSwitchAnimation`（.animation() 属性封装）
- **接口实体**：
  - `BaseConverter.toBase(value: number, base: NumberBase): string`
  - `BaseConverter.fromBase(str: string, base: NumberBase): number`
  - `BaseConverter.isValidChar(ch: string, base: NumberBase): boolean`
- **事件实体**：
  - `modeChanged：CalculatorMode`（切换工作模式）
  - `baseChanged：NumberBase`（切换当前进制）
  - `expressionCleared`（AC 触发后所有进制同步清空）

### 2.5 模糊点

| # | 类别 | 描述 | 严重程度 | 默认决策（自动化） |
|---|------|------|:--------:|---------------------|
| 1 | 行为模糊 | 三种模式共存还是三态循环？ | important | 三态循环：基础 → 科学 → 程序员 → 基础 |
| 2 | 行为模糊 | 进制显示是 4 行同时显示，还是只显示当前进制？ | important | 程序员模式下 4 行同时显示；其他模式维持单行 |
| 3 | 行为模糊 | 程序员模式下输入字符是否按当前进制过滤？ | important | 是，非当前进制合法字符的按钮置灰不可点击 |
| 4 | 行为模糊 | 切换动画具体形式？淡入/滑入/翻转？ | important | 淡入淡出 + 8dp 垂直位移，时长 200ms，curve EaseInOut |
| 5 | 范围模糊 | 是否包含位运算（AND/OR/XOR/<<>>）？ | important | **不包含**（Issue 标题仅说"进制转换"，位运算另立 Issue） |
| 6 | 数据模糊 | 进制显示范围（整数/小数）？ | important | 仅整数部分（程序员模式典型用途）；小数提示"不支持" |
| 7 | nice-to-have | 16 进制颜色编码（#FF0000） | nice-to-have | 不实现，纯数字显示 |

### 2.6 复杂度评估

- **等级**：M（中等）
- **理由**：
  - 影响 4 个模块（View、ViewModel、Model、数据层）
  - 新增 1 个工具类 + 2 个枚举 + 2 个组件 + 扩展 1 个偏好类
  - 涉及 UI 重排（4 行显示）和状态机设计
  - 不涉及架构变更（仍单页面 @Entry + 现有面板机制）

---

## 3. 需求澄清（rq-clarify 产出）

> **说明**：本项目采用"自动化模式：低风险决策自行决定 + todo.md 留痕"。所有 `important` 模糊点已基于行业最佳实践给出默认决策，详见下表"决策"列。无需启动 rq-clarify 交互问答。

### 3.1 已澄清的关键决策

| # | 问题 | 决策 | 来源 | 理由 |
|---|------|------|------|------|
| 1 | 三模式如何切换？ | **三态循环**（基础→科学→程序员→基础） | 默认决策 | 复用 ToggleRow 现有模式切换结构，最小改动 |
| 2 | 进制显示形式？ | **程序员模式 4 行同时显示**；其他模式单行 | 默认决策 | Issue 标题"进制转换"暗示同时查看 |
| 3 | 字符过滤策略？ | **当前进制非法字符置灰** | 默认决策 | 符合 iOS/Android 程序员计算器惯例 |
| 4 | 切换动画形式？ | **淡入 + 8dp 上移**，200ms EaseInOut | 默认决策 | ArkTS `.animation()` 原生支持，性能开销小 |
| 5 | 位运算包含吗？ | **不包含**（AND/OR/XOR/<< >> 留待后续 Issue） | 默认决策 | Issue 标题未提及；范围控制 |
| 6 | 小数支持？ | **仅整数**（小数提示"程序员模式仅支持整数"） | 默认决策 | 进制转换数学定义仅适用整数 |
| 7 | 进制范围？ | **≤2^53 整数**（IEEE 754 安全整数范围） | 默认决策 | ArkTS number 类型精度限制 |

### 3.2 待定假设

以下未明确之处采用合理默认值（实现阶段可调整，无需用户重新确认）：

- **默认进入模式**：基础模式（首次启动仍为 BASIC，programmerModeDefault=false）
- **默认进制**：DEC（即使进入程序员模式，默认 DEC）
- **HEX 大小写**：大写（A-F，符合程序员惯例）
- **动画触发**：模式切换时，新组件用 `.animation({ duration: 200, curve: Curve.EaseInOut })`
- **持久化时机**：modeChanged 后立即 flush 到 PreferencesStore
- **错误提示**：程序员模式下小数输入 → 中文 Toast "程序员模式仅支持整数"

### 3.3 功能边界

- **包含**：
  - 三模式循环切换（基础/科学/程序员）
  - 程序员模式 4 进制并行显示（DEC/BIN/OCT/HEX）
  - 实时进制转换（输入即转换，结果即转换）
  - 按进制过滤的键盘（BIN 仅 0-1，OCT 0-7，HEX 含 A-F）
  - 模式切换淡入淡出 + 上移动画
  - 偏好持久化（programmerModeDefault + defaultBase）
- **不包含**（后续 Issue）：
  - 位运算（AND / OR / XOR / NOT / 左移 / 右移）
  - 字节查看器（Byte/Word/Dword/Qword 切换）
  - 进制历史记录
  - 16 进制颜色编码显示
  - ASCII 字符对照表

---

## 4. 需求详述

### 4.1 功能需求

#### FR-1: 三模式切换

**描述**：在 ToggleRow 中将现有的"基础/科学"二态切换升级为"基础/科学/程序员"三态循环。

**验收条件**：
- 点击模式按钮在 `BASIC → SCIENTIFIC → PROGRAMMER → BASIC` 之间循环
- 横屏自动开启科学模式行为不变（横屏不强制开启程序员模式）
- 默认进入模式为 BASIC（由 `programmerModeDefault` 偏好决定）
- 当前模式显示在按钮文字上（"基础"/"科学"/"程序员"）

#### FR-2: 程序员模式 4 进制并行显示

**描述**：进入程序员模式后，DisplayPanel 替换为 4 行进制显示区域（DEC / BIN / OCT / HEX），每行格式 `LABEL: value`。

**验收条件**：
- 4 行按固定顺序：DEC → BIN → OCT → HEX（程序员惯例）
- 当前进制行高亮（背景色 `getOp()`）
- 输入数字后所有 4 行实时同步更新
- 整数部分转换正确（255 → 11111111 / 377 / FF）
- 超出 2^53 时该进制行显示 `Overflow`，其他行正常显示
- 小数结果在所有行后追加 `(整数)` 标识并提示"不支持小数"

#### FR-3: 按进制过滤键盘

**描述**：程序员模式下，ButtonGrid 替换为 ProgrammerKeypad，按当前进制过滤可输入字符。

**验收条件**：
- BIN 模式：仅 0/1 可点击，其他数字按钮置灰（透明度 0.3）
- OCT 模式：0-7 可点击，8/9 置灰
- DEC 模式：0-9 可点击，无字母
- HEX 模式：0-9 + A/B/C/D/E/F 可点击，共 16 个字符按钮
- DEC/BIN/OCT 模式下字母按钮（A-F）隐藏
- 当前进制切换不影响表达式计算结果（始终以 DEC 存储）

#### FR-4: 模式切换动画

**描述**：三模式切换时 DisplayPanel + ButtonGrid 有淡入淡出 + 8dp 垂直位移过渡。

**验收条件**：
- 切换触发后 200ms 内完成
- 旧组件淡出（透明度 1 → 0）+ 上移 8dp
- 新组件淡入（透明度 0 → 1）+ 上移 8dp → 0
- 动画曲线 EaseInOut
- 切换过程中按钮仍可点击（不阻塞交互，但视觉切换明显）
- 横竖屏切换不触发该动画（仅模式切换触发）

#### FR-5: 进制转换工具

**描述**：新增 BaseConverter.ets，提供 toBase / fromBase / isValidChar / formatHex 工具方法。

**验收条件**：
- `BaseConverter.toBase(255, NumberBase.BIN) === "11111111"`
- `BaseConverter.toBase(255, NumberBase.HEX) === "FF"`
- `BaseConverter.fromBase("FF", NumberBase.HEX) === 255`
- `BaseConverter.isValidChar("A", NumberBase.HEX) === true`
- `BaseConverter.isValidChar("2", NumberBase.BIN) === false`
- 负数：toBase 返回 `-<digits>`，fromBase 识别前缀 `-`
- 0 → `"0"`

#### FR-6: 偏好持久化

**描述**：将 `programmerModeDefault` 和 `defaultBase` 持久化到 PreferencesStore。

**验收条件**：
- `getProgrammerModeDefault()` 返回 0/1/2（BASIC/SCI/PROG）
- `setProgrammerModeDefault(value)` 立即 flush
- `getDefaultBase()` 返回 NumberBase 数值（2/8/10/16）
- `setDefaultBase(value)` 立即 flush
- 关闭重开 APP 后偏好保持
- 默认值：`programmerModeDefault = 0 (BASIC)`, `defaultBase = 10 (DEC)`

### 4.2 可靠性需求

#### REQ-DFR-001: 进制溢出与非法输入容错

**描述**：程序员模式下输入超出 2^53、负数、小数、非法字符等情况需有降级策略。

**关注点**：
- **故障检测**：
  - 输入值 > 2^53 或 < -2^53 → 标记 `Overflow`
  - 输入包含小数点 → 显示"不支持小数"Toast
  - 输入非法字符（按当前进制）→ 按钮置灰，根本无法输入
- **故障恢复**：
  - 溢出时该进制行显示 `Overflow`，其他进制行正常显示
  - 表达式清空（AC）后所有进制行同步清空
- **降级策略**：
  - DEC 行（主行）始终显示原始表达式/结果，不受溢出影响
  - Toast 提示用 promptAction.showToast，3s 自动消失
  - 不阻塞输入流程（允许继续输入合法字符）

---

## 5. 影响范围分析

### 5.1 涉及的模块

| 模块 | 现有功能 | 新增/修改 |
|------|---------|-----------|
| `pages/CalculatorPage.ets` | 二态模式切换 + 单行显示 + 5×N 按钮 | 修改：ToggleRow 三态化 / DisplayPanel 按模式分支 / ButtonGrid 引入 ProgrammerKeypad |
| `calculator/BaseConverter.ets` | （无） | **新增**：toBase / fromBase / isValidChar / formatHex |
| `model/Models.ets` | CalculatorError / HistoryItem / Preferences | 修改：新增 CalculatorMode + NumberBase 枚举，扩展 Preferences 接口 |
| `preferences/PreferencesStore.ets` | 8 个偏好读写 | 修改：新增 getProgrammerModeDefault / setProgrammerModeDefault / getDefaultBase / setDefaultBase |
| `resources/base/element/string.json` | （待查） | 修改：新增 "基础"/"科学"/"程序员"/"DEC"/"BIN"/"OCT"/"HEX" 等字符串资源 |

### 5.2 代码依赖分析

```
CalculatorPage
  ├── ToggleRow         [modify] → 三态循环
  ├── DisplayPanel      [modify] → 按 mode 分支（基础/科学 单行 / 程序员 4 行）
  ├── ButtonGrid        [modify] → 按 mode 分支（基础/科学 5×N / 程序员 ProgrammerKeypad）
  ├── BaseConversionPanel  [new]  → 程序员模式专属 4 行显示
  ├── ProgrammerKeypad     [new]  → 程序员模式专属键盘（含 A-F + 进制切换）
  ├── SettingsPanel     [modify] → 新增 "默认模式" / "默认进制" 设置项
  └── BaseConverter     [new]  → 复用 parseInt/toString 实现进制转换
       ↓
       Models.ets        [modify] → CalculatorMode + NumberBase 枚举
       PreferencesStore  [modify] → 2 个新偏好方法
```

**关键依赖**：
- BaseConverter 必须无 UI 依赖（纯逻辑，便于单元测试）
- CalculatorMode 切换驱动 DisplayPanel / ButtonGrid 重渲染
- NumberBase 切换驱动键盘字符可用性 + 显示行高亮
- PreferencesStore 新增 2 个键值，与现有偏好体系一致

---

## 6. 复杂度评估

### 6.1 评估结果

- **复杂度等级**：**复杂**（虽然单功能点，但跨 View+ViewModel+Model+数据层 4 层 + 新增组件 3 个）
- **影响模块数**：5（CalculatorPage、Models、PreferencesStore、string.json、BaseConverter）
- **架构变更**：否（仍单页面 @Entry + 现有面板机制）
- **数据模型变更**：是（新增 2 个枚举 + 2 个偏好键 + 1 个工具类）

### 6.2 跳过策略

| 制品 | 是否产出 | 说明 |
|------|:--------:|------|
| proposal.md | ✅ 必须 | 本文件 |
| delta-spec.md | ✅ 必须 | 增量 spec |
| new-arch.md | ⏭️ 跳过 | 无架构变更 |
| delta-design.md | ✅ 必须 | 增量设计 |
| tasks.md | ✅ 必须 | 实现任务分解（IMPLEMENTING 阶段产出） |
| info.md | ✅ 必须 | 代码仓理解 |

---

## 7. 待解决问题

| # | 问题 | 状态 | 解决方式 |
|---|------|:----:|----------|
| 1 | 位运算是否后续 Issue？ | 已决策 | 不包含，留待后续 Issue |
| 2 | 进制颜色编码？ | 已决策 | 不实现 |
| 3 | 动画时长是否可调？ | 已决策 | 200ms 固定（用户可在设置中调整？→ 否，固定） |

**所有重要问题已通过"低风险默认决策 + todo.md 留痕"机制处理，无需 GitHub Issue 评论 @littleleafccccc 提问。**