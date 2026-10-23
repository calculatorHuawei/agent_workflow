# 计算结果小数/分数切换开发任务

## 任务概述

- 功能名称：计算结果小数/最简分数切换
- 变更类型：缺陷修复（Issue #44，恢复并修正历史 Issue #27 能力）
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 设计输入：`proposal.md` / `delta-spec.md` / `delta-design.md` / `info.md` / `design-review.md`
- 开发阶段：先锁定纯算法与展示选择契约，再接入页面状态和 UI，最后执行自动化验收
- 预计任务数：6
- 任务粒度：每项预计 1–2 小时；每项均包含明确输入、输出和可验证验收标准

## 任务列表

### 阶段 1：纯逻辑基础设施

#### Task 1.1: 以 TDD 实现可靠的最简分数转换

**描述**：先用 Hypium 表驱动测试锁定 `FractionUtil` 契约，再实现无 Kit 依赖的有界连分数、GCD、符号规范、整数格式和可靠性门禁。最大分母默认 10000，迭代不超过 32 次，候选误差不超过 `max(1e-12, abs(value) * 1e-12)`；任何非法、超界或不可靠输入返回 `null`。

**输入**：`delta-spec.md` SR-00、SC001-UC001/002/003、SC002-UC001；`delta-design.md` §3.5、§3.8。

**输出**：可独立测试的 `FractionUtil` 与覆盖正常、边界和降级路径的测试套件。

**涉及文件**：
- 实现（新增）：`opencalc/entry/src/main/ets/common/FractionUtil.ets`
- 测试（新增）：`opencalc/entry/src/test/FractionUtil.test.ets`

**依赖任务**：无

**验收标准**：
- `0.5→1/2`、`0.25→1/4`、`1/3→1/3`、`2/3→2/3`、`0.1+0.2→3/10` 均通过测试。
- `-0.5` 格式为 `-1/2`，`2` 格式为 `2`，`0` 与 `-0` 均格式为 `0`，分母始终为正且结果已约分。
- NaN、±Infinity、非法最大分母、超安全整数范围、π/√2 等未通过误差门禁的输入返回 `null`，不抛异常、不产生零分母。
- 分子、分母及连分数中间项均执行安全整数检查，迭代次数与分母上限可由测试验证。
- 测试遵循 RED → GREEN → REFACTOR，并保持工具无 UI、存储和系统 Kit 依赖。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.2: 以 TDD 实现结果展示选择器

**描述**：先覆盖模式翻转、禁用门禁和降级选择，再实现 `ResultDisplayMode` 与无状态 `ResultDisplayPresenter`。选择器只根据 `mode/rawValue/decimalText` 派生文本；分数转换失败或异常时必须原样返回小数快照。

**输入**：Task 1.1 输出；`delta-spec.md` SR-01；`delta-design.md` §3.6。

**输出**：可脱离 ArkUI 验证的展示状态纯逻辑及其单元测试。

**涉及文件**：
- 实现（新增）：`opencalc/entry/src/main/ets/common/ResultDisplayPresenter.ets`
- 测试（新增）：`opencalc/entry/src/test/ResultDisplayPresenter.test.ets`
- 依赖实现：`opencalc/entry/src/main/ets/common/FractionUtil.ets`

**依赖任务**：Task 1.1

**验收标准**：
- `nextMode(DECIMAL, true)` 与 `nextMode(FRACTION, true)` 双向翻转，`canToggle=false` 时保持原模式。
- DECIMAL 模式始终原样返回 `decimalText`；FRACTION 模式对 `0.5`、`1/3`、负数和整数返回设计规定文本。
- 转换返回 `null` 或发生防御性异常时回退 `decimalText`，不修改任何输入。
- 测试能证明选择器无求值、历史、Preferences 或 ArkUI 副作用。
- 测试遵循 RED → GREEN → REFACTOR。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 2：页面状态与表现层

#### Task 2.1: 接入结果模式与页面生命周期状态

**描述**：在 `CalculatorPage` 中保存最近一次成功求值的 raw number，并维护 `displayMode` 与 `hasResult`。成功求值只执行一次并把既有格式化文本作为小数/历史快照；新成功结果重置为 DECIMAL。错误和 AC 清理 raw、模式与可切换状态，切换处理仅调用 presenter，不进入求值或历史写入路径。

**输入**：Task 1.2 输出；`delta-spec.md` §6、SC003-UC001；`delta-design.md` §3.7.5–§3.7.10。

**输出**：符合 EMPTY/DECIMAL/FRACTION/ERROR 生命周期的页面状态集成。

**涉及文件**：
- 实现（修改）：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 测试（扩展）：`opencalc/entry/src/test/ResultDisplayPresenter.test.ets`

**依赖任务**：Task 1.2

**验收标准**：
- 成功求值保存 raw result 与既有小数快照，历史仍仅写入一次小数快照；新计算从 DECIMAL 开始。
- 切换两次后表达式、raw result、小数快照及历史数组的长度、顺序和条目内容与切换前深度一致。
- 切换路径不调用 `CalcEngine.evaluate`、`PreferencesStore.setHistory`，也不反解析已格式化结果。
- AC 与所有错误分支均阻止有效切换并清除陈旧 raw result；历史保持既有行为。
- `visibleResult()` 在转换失败时稳定返回原小数快照。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 2.2: 在结果区域实现可访问的双向切换 UI

**描述**：在 `DisplayPanel` 增加紧凑的“小数/分数”入口和当前模式反馈，竖屏与横屏均可见可点，沿用现有主题色和排版。结果文本改为渲染派生可见值，长按复制当前可见文本；无成功结果或错误态时入口隐藏或禁用并保留事件门禁。

**输入**：Task 2.1 输出；`delta-design.md` §3.4、§6、§8；Issue #44 UI 验收条件。

**输出**：可在同一结果上往返切换、可访问且不遮挡结果文本的页面交互。

**涉及文件**：
- 实现（修改）：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`

**依赖任务**：Task 2.1

**验收标准**：
- `1÷2` 可在 `0.5` 与 `1/2` 间往返；`1÷3` 分数态为 `1/3`；`2÷4` 为 `1/2`；负数和整数显示符合规格。
- 切换入口在竖屏、横屏、浅色和深色主题下均可识别，触控目标至少 32vp，且不覆盖或截断既有结果文本。
- 可访问文本明确当前模式和可执行动作；模式切换不弹 Toast、不引入图片资源或新 Kit。
- 长按复制的是当前可见结果；切回小数后仍恢复原小数快照。
- 空态/错误态不可有效切换，防御性点击不会改变页面业务状态或导致崩溃。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 3：测试注册与端到端验收

#### Task 3.1: 注册并执行核心自动化回归

**描述**：将新增 Hypium 套件注册到现有测试入口，执行定向测试、全量本地测试、lint/语法检查和构建，确认没有改变 `CalcEngine`、`NumberFormatter`、History schema、Preferences schema、权限或依赖配置。

**输入**：Task 1.1–2.2 输出；`delta-spec.md` SR-02；`delta-design.md` §3.8。

**输出**：可被标准测试入口发现的自动化套件及通过的构建/静态检查证据。

**涉及文件**：
- 测试入口（修改）：`opencalc/entry/src/test/List.test.ets`
- 测试（验证）：`opencalc/entry/src/test/FractionUtil.test.ets`
- 测试（验证）：`opencalc/entry/src/test/ResultDisplayPresenter.test.ets`

**依赖任务**：Task 1.1、Task 1.2、Task 2.1、Task 2.2

**验收标准**：
- 两个新增测试套件可由 `List.test.ets` 发现并执行，Issue #44 的数学与状态 AC 均有自动断言。
- 定向测试与全量本地测试通过，无遗漏注册、异步未结束或偶发失败。
- ArkTS 语法/lint 检查与 entry 构建通过，无新增 warning/error。
- `git diff` 证明变更未扩展到设计明确排除的引擎、持久化 schema、权限、路由和构建依赖。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 3.2: 自动化验证关键 UI 交互与状态不变量

**描述**：编写并执行 HarmonyOS UI 自动化用例，覆盖小数/分数往返、降级、复制、AC/错误门禁、历史一致性以及横竖屏入口可用性；保存截图、无障碍树和执行报告作为验收证据。

**输入**：Task 3.1 的可构建包与测试结果；Issue #44 全部验收标准；`delta-spec.md` SC-001/002/003。

**输出**：可重复执行的 UI 用例与通过/失败证据，能直接追溯每条 Issue AC。

**涉及文件**：
- UI 用例（新增）：`specs/changes/20261023-bugfix-result-display-toggle/ui-tests/result-display-toggle-cases.md`
- UI 证据（新增）：`specs/changes/20261023-bugfix-result-display-toggle/ui-tests/evidence/`
- UI 报告（新增）：`specs/changes/20261023-bugfix-result-display-toggle/ui-tests/result-display-toggle-report.md`

**依赖任务**：Task 3.1

**验收标准**：
- 设备用例验证 `1÷2` 双向切换、`1÷3→1/3`、`2÷4→1/2`、`-1÷2→-1/2` 和整数不显示 `/1`。
- 连续切换前后表达式和历史条目的数量、顺序、表达式、结果文本保持一致，且不出现重复历史。
- 无结果、AC 后和错误态不可有效切换；不可可靠转换时显示原小数/错误文本且应用不崩溃。
- 分数态长按复制当前可见分数；竖屏与横屏下入口均可通过无障碍树定位并完成操作。
- 报告包含环境、步骤、预期/实际、截图/无障碍树路径和每条 AC 的结论。

**TDD**：[x] RED（无设备） / [ ] GREEN（待设备） / [ ] REFACTOR（待设备）

## 依赖关系与并行策略

| 任务 | 前置依赖 | 可并行说明 | 关键路径 |
|------|----------|------------|----------|
| Task 1.1 | 无 | 起始任务 | 是 |
| Task 1.2 | Task 1.1 | 不可提前；依赖转换契约 | 是 |
| Task 2.1 | Task 1.2 | 不可提前；依赖模式与展示接口 | 是 |
| Task 2.2 | Task 2.1 | 不可提前；依赖页面状态与事件 | 是 |
| Task 3.1 | Task 1.1–2.2 | 测试注册可预备，但完整执行需等待 UI 接入 | 是 |
| Task 3.2 | Task 3.1 | 不可提前；依赖可安装、可测试构建 | 是 |

## 开发顺序

```text
Task 1.1 → Task 1.2 → Task 2.1 → Task 2.2 → Task 3.1 → Task 3.2 → 完成
```

## 验收计划

| 任务 | 验收方式 | 验收时间 |
|------|----------|----------|
| Task 1.1 | Hypium 单元测试 + 代码审查 | 实现当日 |
| Task 1.2 | Hypium 单元测试 + 纯函数副作用审查 | 实现当日 |
| Task 2.1 | 状态不变量自动化测试 + diff 审查 | 实现当日 |
| Task 2.2 | 页面交互检查 + 可访问性/响应式检查 | 实现当日 |
| Task 3.1 | 定向/全量测试 + lint/语法检查 + 构建 | 集成当日 |
| Task 3.2 | HarmonyOS 设备 UI 自动化 + 证据审查 | 集成当日 |

## 完成定义

- 六个任务均完成各自 RED、GREEN、REFACTOR 与验收标准。
- Issue #44 全部验收标准在单元测试、状态测试或 UI 自动化中至少有一条可重复证据。
- 产品变更严格限于设计列出的两个新增 common 模块、`CalculatorPage` 和测试资产；排除项保持不变。
- APPLYING 阶段另行授权后方可修改产品源码、执行测试或生成应用报告。
