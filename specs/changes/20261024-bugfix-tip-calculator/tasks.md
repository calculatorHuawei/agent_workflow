# 小费计算器与多人账单分摊开发任务

## 任务概述

- 功能名称：小费计算器与多人账单分摊
- 变更类型：编排器指定 `bugfix`；产品语义为新增功能
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 规划输入：`proposal.md`、`delta-spec.md`、`acceptance-criteria.json`、`info.md`、`delta-design.md`、`design-review.md`
- 开发阶段：在既有 CalculatorPage 单页内新增无持久化的 TipPanel，并以纯 TipCalculator 提供校验、计算和格式化
- 预计任务数：7
- 范围守卫：不新增路由、权限、依赖、持久化或普通计算历史记录；不补建程序员模式

## 任务列表

### 阶段 1：测试契约

#### Task 1.1: 建立 TipCalculator RED 单元测试契约

**描述**：先按 TDD 新增并注册 TipCalculator 测试套件，以 feature-level AC 的精确 oracle 固化核心示例、零比例、货币舍入、格式/范围校验、安全上限和非法人数禁止除法。测试必须先在实现缺失或行为不满足时失败。

**涉及文件**：
- 测试：`opencalc/entry/src/test/TipCalculator.test.ets`
- 测试注册：`opencalc/entry/src/test/List.test.ets`

**依赖任务**：无

**预计用时**：1–2 小时

**输入**：`acceptance-criteria.json` 中 AC-002～AC-009 的 oracle；`delta-design.md` §3.5 的接口和算法。

**输出**：已注册、可重复执行且在实现前呈 RED 的 Hypium 测试套件。

**验收标准**：
- 精确断言 `100/15%/2 → 15.00/115.00/57.50`、`88.80/10%/3 → 8.88/97.68/32.56`、`100/0%/3 → 0.00/100.00/33.33`、`10/10%/3 → 1.00/11.00/3.67`。
- 表驱动覆盖金额空值/格式/负值/超过安全范围、人数空值/0/负数/小数/非数字、自定义比例 `0`/`100`/越界/格式错误，以及错误态三项均为 `--`。
- 测试名称或注释保留 AC ID，且不把单元测试宣称为 UI/E2E AC 已完成。

**需求追溯**：IR-002、IR-003、IR-004、IR-005 → AC-002～AC-009

**Developer 验证**：Hypium unit；RED oracle 为新增测试在实现前因模块/行为缺失失败，且失败原因指向待实现契约。

**Tester 验证请求**：后续仍须在设备 UI 重放 AC-002～AC-009；本任务仅建立逻辑层 oracle。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 2：核心业务逻辑

#### Task 2.1: 实现无副作用的 TipCalculator

**描述**：实现 ArkTS 纯逻辑模块及显式 DTO，完成点号十进制解析、basis points 比例、人数校验、安全整数保护、half-up 分值计算和固定两位格式化。任何错误返回字段级信息和全 `--` 结果，不缓存上次状态、不触碰 UI、Preferences、History 或主计算引擎。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/tip/TipCalculator.ets`
- 测试：`opencalc/entry/src/test/TipCalculator.test.ets`

**依赖任务**：Task 1.1

**预计用时**：1–2 小时

**输入**：Task 1.1 的 RED 契约；`delta-design.md` §3.5.6～§3.5.10。

**输出**：同步、确定性、无副作用的 TipCalculator API 和通过的逻辑测试。

**验收标准**：
- 账单最多两位小数、比例 `0..10000` basis points、人数为 `>=1` 安全整数；校验先于任何除法。
- 按“小费先舍入到分 → 总额相加 → 每人舍入到分”的唯一顺序计算，所有有效显示固定两位。
- 输入或中间结果超过安全整数范围时返回“金额过大”或等义错误，不产生 NaN/Infinity/部分结果。
- Task 1.1 的测试由 RED 转为 GREEN，并在不改变外部契约的前提下完成必要重构。

**需求追溯**：IR-002、IR-003、IR-004、IR-005 → AC-002、AC-003、AC-004、AC-006、AC-007、AC-008、AC-009

**Developer 验证**：Hypium unit；精确文本、错误字段、全 `--`、恢复输入和安全范围断言全部通过。

**Tester 验证请求**：在 TipPanel 接入后核对 UI 文本与逻辑 oracle 一致，特别验证 AC-006 舍入和 AC-008 非法人数。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 3：页面集成与表现层

#### Task 3.1: 接入会话状态与原子重算事件

**描述**：在 CalculatorPage 中增加独立的 Tip 源状态、错误状态和结果状态，接入 TipCalculator；实现账单、人数、预设和自定义比例事件。事件必须先更新源状态再统一重算，预设/自定义保持唯一选中，非法态原子清除旧结果，初始未触碰的空账单不显示错误。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 逻辑契约：`opencalc/entry/src/main/ets/tip/TipCalculator.ets`

**依赖任务**：Task 2.1

**预计用时**：1–2 小时

**输入**：TipCalculator API；`delta-design.md` §3.6.6～§3.6.10。

**输出**：与主计算器状态隔离的 Tip 会话状态及统一事件/重算链路。

**验收标准**：
- 默认状态为账单空、15%、1 人、结果 `--`；首次进入不显示账单错误，用户清空已触碰字段后显示错误。
- 金额、比例、人数任一变化均无需计算按钮即可更新全部派生状态。
- 自定义输入切换到 custom；点击任一预设后仅该预设选中、清除自定义错误并重算。
- 逻辑调用异常被防御性转换为可理解错误和全 `--`，不得崩溃。

**需求追溯**：IR-002、IR-003、IR-005 → AC-005、AC-007、AC-008、AC-009

**Developer 验证**：编译/静态检查 + 事件级集成检查；按 AC-005 的四个有序状态核对一次性更新结果。

**Tester 验证请求**：设备 UI 顺序执行 AC-005、AC-007～AC-009，保存每一步选中态、错误态和结果态证据。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 3.2: 构建 TipPanel 输入、错误与结果界面

**描述**：新增主题一致的 TipPanel Builder，呈现账单、四个预设、自定义比例、人数、字段级错误和三项结果。为输入、比例按钮、错误和结果提供稳定 UI 标识；错误不能只靠颜色表达，横竖屏均不得裁切关键内容。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`

**依赖任务**：Task 3.1

**预计用时**：1–2 小时

**输入**：Task 3.1 状态/事件；`delta-design.md` §3.4、§6、§8。

**输出**：可由 Tester 稳定定位和操作的 TipPanel UI。

**验收标准**：
- 面板展示标题、返回、两个基础输入、四个预设、自定义输入、三项结果和就近错误文本。
- 有效结果严格显示两位且不带币种符号；非法期间三项显示 `--`，修正后同一交互自动恢复。
- 复用现有主题派生色和间距惯例；错误文本可读，按钮命中区域满足设计下限。
- 稳定标识至少覆盖账单、自定义比例、人数、四个预设、三项结果和返回控件。

**需求追溯**：IR-002、IR-003、IR-004、IR-005、IR-007 → AC-002～AC-009、AC-011

**Developer 验证**：编译/静态检查 + 组件代码审查；对 AC-002～AC-006 精确文本和 AC-007～AC-009 错误/恢复状态做集成核对。

**Tester 验证请求**：在 HarmonyOS 模拟器/真机执行核心、边界、异常恢复 UI 用例，并使用稳定标识或状态树留证。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 3.3: 增加横竖屏入口、覆盖层切换与状态隔离

**描述**：在竖屏 ToggleRow 和横屏 DisplayPanel 操作区分别增加“小费”入口，以既有 Stack 条件渲染 TipPanel；返回仅关闭覆盖层。保持表达式、结果、历史、科学模式、绘图和其他面板状态不变，且不调用 onEquals、setHistory、Preferences 写入或 router。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`

**依赖任务**：Task 3.2

**预计用时**：1–2 小时

**输入**：完整 TipPanel；既有 ToggleRow、DisplayPanel、PlotPanel 覆盖层惯例。

**输出**：横竖屏可达、可逆退出且不污染既有功能的入口和覆盖层。

**验收标准**：
- 竖屏和横屏均有可见入口，标题为“小费计算器”，返回后仍是同一 CalculatorPage，无新路由。
- 进入前的表达式 `2+3`、结果 `5`、历史数量/内容、科学模式状态在完成一次分摊并返回后逐项相等。
- 小费计算不新增历史；普通/科学/绘图和现有面板交互保持可用。
- 当前仓库不存在程序员模式，本任务不得补建或修改其未来/外部契约。

**需求追溯**：IR-001、IR-006 → AC-001、AC-010

**Developer 验证**：编译/静态检查 + 集成代码审查；确认无 Tip → History/Preferences/router/CalcEngine 写依赖。

**Tester 验证请求**：在支持方向切换的模拟器/真机执行 AC-001 和 AC-010，记录进入前/返回后的精确状态与历史差异。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 4：验证与独立交付

#### Task 4.1: 执行 Developer 构建、单测与回归门禁

**描述**：完成实现后执行仓库规定的 ArkTS 静态检查、entry 构建和 Hypium 单元测试，复核仅预期文件变化及 AC/任务追溯。Developer 只报告实际执行结果，不以单元测试替代设备 UI/E2E 验收。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/tip/TipCalculator.ets`
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 测试：`opencalc/entry/src/test/TipCalculator.test.ets`
- 测试注册：`opencalc/entry/src/test/List.test.ets`
- 追溯：`specs/changes/20261024-bugfix-tip-calculator/tasks.md`

**依赖任务**：Task 3.3

**预计用时**：1–2 小时

**输入**：Tasks 1.1～3.3 的实现和测试。

**输出**：可复现的构建/单测/静态检查结果及未关闭的设备验证清单。

**验收标准**：
- TipCalculator 单元测试全部通过，既有测试无回归；构建和适用静态检查成功。
- 检查结果不包含 ArkTS 类型错误、NaN/Infinity 结果或新增依赖/权限/路由/Preferences key。
- 明确列出 AC-001、AC-005、AC-007～AC-011 仍需 Tester 设备证据，不提前标记完成。

**需求追溯**：IR-001～IR-007 → AC-001～AC-011

**Developer 验证**：unit / build / lint / diff review；保存命令、退出码和关键输出作为应用阶段报告输入。

**Tester 验证请求**：接收可运行产物、AC 契约、稳定 UI 标识清单和 Developer 未替代的 UI/E2E 验证项。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 4.2: 请求并完成独立 Tester 设备验证

**描述**：由独立 Tester 基于 feature-level AC 自主生成并执行核心计算、边界输入、异常恢复、即时同步、横竖屏入口和既有功能回归用例。Developer 提供契约与可运行产物，但不得替代 Tester 生成结论或删除失败证据。

**涉及文件**：
- 验收契约：`specs/changes/20261024-bugfix-tip-calculator/acceptance-criteria.json`
- 任务追溯：`specs/changes/20261024-bugfix-tip-calculator/tasks.md`
- Tester 报告与证据：由后续 Tester 工作流确定路径

**依赖任务**：Task 4.1

**预计用时**：1–2 小时（Tester 执行窗口）

**输入**：可运行 HAP、AC-001～AC-011、Developer 验证结果和稳定 UI 标识。

**输出**：逐条关联 AC 的独立测试报告、日志、截图或状态树证据索引。

**验收标准**：
- AC-002～AC-010 均有独立执行记录；AC-001 的横竖屏入口与 AC-010 的回归/历史前后相等包含设备证据。
- 每条记录含 `environment`、`actual`、`expected`、`status`、`artifact`，且可追溯到 AC ID。
- 失败用例保留原始日志和 UI 证据，不以 Developer 单测或口头结论替代。
- AC-011 只有在上述证据集合完整后才可关闭。

**需求追溯**：IR-007（并验证 IR-001～IR-006）→ AC-001～AC-011

**Developer 验证**：仅检查交付输入完整性和报告 AC ID 集合，不代签 Tester 结果。

**Tester 验证请求**：integration / ui / e2e / orientation / Preferences history；oracle 以 `acceptance-criteria.json` 为唯一机器权威。

**TDD**：不适用（独立验收任务）

## 开发顺序

```text
Task 1.1 → Task 2.1 → Task 3.1 → Task 3.2 → Task 3.3 → Task 4.1 → Task 4.2 → 完成
```

### 依赖与关键路径

| 任务 | 前置 | 可并行项 | 关键路径原因 |
|------|------|----------|--------------|
| Task 1.1 | 无 | 无 | 先固定 RED 契约 |
| Task 2.1 | 1.1 | 无 | UI 集成依赖稳定纯逻辑 API |
| Task 3.1 | 2.1 | 无 | 面板依赖完整状态/事件链路 |
| Task 3.2 | 3.1 | 无 | 入口验收依赖可操作面板 |
| Task 3.3 | 3.2 | 无 | 完成条件渲染与兼容性边界 |
| Task 4.1 | 3.3 | 无 | 汇总 Developer 门禁 |
| Task 4.2 | 4.1 | Tester 用例设计可提前准备，执行不可提前 | 设备证据是最终独立门禁 |

关键路径为全部七项顺序链；在不修改 AC 的前提下，Tester 可于 Task 1.1 后提前设计用例，但只能在 Task 4.1 提供可运行产物后执行。

## 验收计划

| 任务 | 验收方式 | 验收时点 |
|------|----------|----------|
| Task 1.1 | Hypium RED 失败原因审查 | 实现逻辑前 |
| Task 2.1 | Hypium GREEN + 纯逻辑代码审查 | 业务逻辑完成时 |
| Task 3.1 | 编译/静态检查 + 有序状态集成核对 | 状态接入完成时 |
| Task 3.2 | 编译/静态检查 + UI 标识/文本审查 | 面板完成时 |
| Task 3.3 | 集成审查 + 设备验证请求 | 入口和隔离完成时 |
| Task 4.1 | 构建、unit、lint、diff review | Developer 交付前 |
| Task 4.2 | 独立 Tester UI/E2E 和证据审计 | 可运行产物交付后 |

## AC 覆盖自检

| AC | 实现任务 | Developer 验证责任 | Tester 验证责任 | 覆盖结论 |
|----|----------|--------------------|-----------------|----------|
| AC-001 | 3.3 | 条件渲染/无路由代码审查 | 横竖屏进入、标题、返回 | 完整；设备证据不可由 unit 替代 |
| AC-002 | 1.1, 2.1, 3.2 | exact unit + 集成文本 | UI 精确三项结果 | 完整 |
| AC-003 | 1.1, 2.1, 3.2 | exact unit + 集成文本 | UI 精确三项结果 | 完整 |
| AC-004 | 1.1, 2.1, 3.2 | 0% exact unit | 0% 选中态和 UI 结果 | 完整 |
| AC-005 | 3.1, 3.2 | 有序状态集成核对 | 四步 UI/E2E 状态和无计算按钮 | 完整 |
| AC-006 | 1.1, 2.1, 3.2 | 舍入/两位 exact unit | UI 两位文本 | 完整 |
| AC-007 | 1.1, 2.1, 3.1, 3.2 | 金额错误、全 `--`、恢复 unit/integration | UI 错误/清理/恢复序列 | 完整 |
| AC-008 | 1.1, 2.1, 3.1, 3.2 | 非法人数及禁止除法 unit/integration | UI 错误/清理/恢复序列 | 完整 |
| AC-009 | 1.1, 2.1, 3.1, 3.2 | 比例边界和互斥状态 unit/integration | UI 状态表和预设恢复 | 完整 |
| AC-010 | 3.3, 4.1 | 依赖/写路径审查和既有测试回归 | 主状态、历史、模式前后相等 | 完整；须设备验证 |
| AC-011 | 3.2, 4.2 | 提供稳定标识并核对报告字段/AC 集合 | 独立生成、执行并保留证据 | 完整；归 Tester 所有 |

自检结论：IR-001～IR-007 和 AC-001～AC-011 均至少映射一个实现/交付任务；所有 unit、integration、ui、e2e 与环境层级均有明确责任方；不存在以单元测试关闭 UI/E2E AC 的情况。
