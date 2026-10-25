# 2×2 / 3×3 矩阵设备输入修复开发任务

## 任务概述

- 功能名称：2×2 / 3×3 矩阵运算（Issue #51，PR #54 Tester-feedback iteration 1）
- 变更类型：编排分类为 bugfix；产品语义为既有矩阵功能的设备输入闭环修复
- 目标基线：`6e76305e8d3df57378314d78f30f4b53b0dc4690`
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 设计输入：`proposal.md`、`delta-spec.md`、`acceptance-criteria.json`、`info.md`、`new-arch.md`、`delta-design.md`、`design-review.md`
- 开发阶段：后续 APPLYING 按 TDD 执行；本文件只定义任务，不表示任何 AC 已通过
- 预计任务数：5
- 任务颗粒度：每项以 1–2 小时为目标，并明确输入、输出、客观 oracle、依赖和验证责任

## Planning 输入核验

- Planning checkpoint 指定的 7 项制品及其引用的 `new-arch.md` 均存在、非空并已逐项阅读；`design-review.md` 结论为“通过。PLANNING 可完成”。
- `acceptance-criteria.json` 可解析，包含 12 个唯一 `IR-*`、15 个唯一 `AC-*` 和 12 份 IR 覆盖评估；不存在无效 `source_requirement_ids` 或缺失覆盖评估。
- Tester 反馈完整原子化为 `IR-012`，并由 `SC006-UC001`、`SR-05/SR-06`、`AC-015` 和 `delta-design.md` §12 追溯；原 `IR-001..011` / `AC-001..014` 未删除或弱化。
- `delta-design.md` 显式映射 `AC-001..015`；增量设计只允许在稳定 cell identity、焦点/测试可定位性、顶层文本状态所有权和必要的 MatrixSession 回写收窄范围内选择最小修复。
- Planning 记录的 AC 校验器已两次以 exit 0 完成，结果为 `VALID: 12 source requirement(s), 15 acceptance criterion/criteria`；IMPLEMENTING 不改写权威验收契约。
- 精确基线上的既有矩阵算法、本地测试、构建与 lint 已通过；失败集中在设备 TextInput 提交/保持/计算消费链路。旧任务分解已完成并由 APPLYING 实现，本轮任务只覆盖 Tester 失败后的修复增量。

## 任务列表

### 阶段 1：失败分类与回归保护

#### Task 1.1：建立精确 head 的设备输入诊断门禁

**描述**：在修改产品行为前复用 Tester handoff 59 的失败步骤，并按 `delta-design.md` §12.2 对 A[1,1] 采集输入前、输入后立即、失焦/重绘后和计算后四个时点的节点 identity、bounds、focus、文本、UI tree 与截图。将结果严格分类为：未聚焦/坐标或重布局问题、文本事件后被陈旧状态回写、或 UI 显示与 MatrixSession 计算状态不同步。命令 exit 0 不作为成功 oracle。

**输入**：
- 精确基线 `6e76305e8d3df57378314d78f30f4b53b0dc4690`
- Tester 证据 `D:\huawei\Demo\calculatorHuawei\.agent-runtime\evidence\task-56\run-106`
- `delta-design.md` §12.2、`delta-spec.md` §14、AC-015

**输出/涉及文件**：
- 后续 APPLYING 报告中的诊断记录：`specs/changes/20261024-bugfix-matrix-operations/apply-report.md`
- 设备诊断证据：后续 run evidence 目录，不写入产品源码

**依赖任务**：无

**验收标准**：
- 记录 revision、HAP hash、设备/OS、目标 cell、每个观察时点及实际结果。
- 至少以 focus + UI tree text + screenshot 三类证据确定一个主要失败类别；证据不足时保持未决并补充定位，不猜测根因。
- 明确后续最小修复分支：仅 identity/焦点，或 identity + 顶层状态同步；不得引入自定义键盘、测试后门、权限、依赖或持久化。
- 诊断步骤本身不修改产品源码，不把 `inputText` exit 0 标为成功。

**需求追溯**：IR-002、IR-004、IR-010、IR-012 → AC-015；并为 AC-014 保留失败证据

**Developer 验证**：对照 AC-015 的 `driver_and_product_failure_classified=true` 检查证据完整性；诊断结论必须能由四时点事实复核。

**Tester 验证请求**：Tester 后续在新 head 上使用同一证据结构复测，以便与失败基线进行一一比较。

**TDD**：诊断门禁，不适用代码 RED/GREEN；Tester 现有失败证据作为行为 RED

#### Task 1.2：为已分类的文本状态链补充最小失败回归

**描述**：基于 Task 1.1 的分类，先增加能在修复前失败的最小回归。若缺陷涉及文本状态所有权或 Session 回写，则在现有 MatrixSession/状态转换测试中覆盖 A[1,1] 提交、失焦等价重绘后保持以及计算消费；若缺陷仅为 ArkUI 节点 identity/聚焦，则以可重复的设备 UI 用例作为 RED，并补充静态/集成断言保证每个 A/B-row-column identity 唯一。不得添加与实际失败无关、修复前不会失败的占位单测。

**涉及文件**：
- 测试：`opencalc/entry/src/test/MatrixEngine.test.ets`（仅当状态链存在可确定性单测边界）
- 测试聚合：`opencalc/entry/src/test/List.test.ets`（仅当新增 suite/入口确有需要）
- 设备回归资产：后续 run evidence 中的 AC-015 用例/步骤

**依赖任务**：Task 1.1

**验收标准**：
- RED 精确复现被分类的失败：文本未保持、状态被空值覆盖、计算读空，或唯一节点无法可靠聚焦中的至少一种。
- 回归使用稳定的 A[1,1] 语义标识和精确文本/状态 oracle，不以“组件存在”“无崩溃”或命令退出码代替。
- 测试覆盖提交值 `1`、派生结果失效、目标 cell 错误清除，以及后续计算读取当前文本快照；不改变数字语法和算法 oracle。
- RED 命令、失败断言和证据位置记录在后续 APPLYING 报告中。

**需求追溯**：IR-002、IR-004、IR-012 → AC-007、AC-008、AC-015

**Developer 验证**：先观察预期 RED；仅接受与 Task 1.1 根因分类直接对应的失败断言。

**Tester 验证请求**：设备 UI 仍负责证明真实 IME/uitest、焦点、失焦/重绘和最终计算闭环；Developer 单测不能关闭 AC-015。

**TDD**：[x] RED（精确基线设备输入为空） / [x] GREEN（稳定 identity + 顶层状态直接绑定） / [x] REFACTOR（失焦保持、A+B 消费与 18/18 identity 复验）

### 阶段 2：最小产品修复

#### Task 2.1：修复矩阵 TextInput identity 与单一文本状态所有权

**描述**：按 Task 1.1 的证据选择最小实现。为嵌套 `ForEach` 中每个 TextInput 建立 `{matrix}-{row}-{column}` 稳定唯一 identity，并确保事件闭包与可见 cell 一致。若证据证明存在陈旧回写，则让顶层 `matrixAText` / `matrixBText` 成为唯一跨重绘文本真源：cell edit 以新 row/新矩阵引用原子更新目标 `@State`，只失效派生结果和目标错误；MatrixSession 在计算时读取当前快照，计算后只回写派生状态。若证据只证明定位/焦点问题，则不扩大到状态链重构。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 条件实现：`opencalc/entry/src/main/ets/calculator/MatrixEngine.ets`（仅在证明确需收窄 MatrixSession 文本回写职责时）
- 测试：`opencalc/entry/src/test/MatrixEngine.test.ets`（Task 1.2 建立的确定性回归）

**依赖任务**：Task 1.2

**验收标准**：
- A/B 的 2×2 与 3×3 所有 cell identity 唯一、稳定，matrix/row/column 与事件写入坐标一致。
- 标准触摸+IME 与标准 uitest 输入 `1` 后，可见文本和 UI tree 文本均为 `1`；失焦、滚动、条件重绘后仍为 `1`。
- 补齐矩阵执行 A+B 时使用已提交值，A[1,1] 不出现 empty 错误；编辑仍会使旧结果失效并只移除目标 cell 错误。
- 原数字语法、四类算法、精度、维度切换、清空、矩阵/标量互斥结果和模式隔离契约保持不变。
- 不新增自定义键盘、测试注入 API、公共业务 API、权限、OHPM 依赖、路由、Preferences key 或持久化。

**需求追溯**：IR-001、IR-002、IR-004、IR-006、IR-007、IR-008、IR-009、IR-011、IR-012 → AC-001、AC-007、AC-008、AC-010、AC-011、AC-012、AC-013、AC-015

**Developer 验证**：Task 1.2 RED 转 GREEN；代码审查确认新引用更新、单一文本真源、稳定 identity 和最小 diff；REFACTOR 后重跑相关 MatrixSession/adapter tests。

**Tester 验证请求**：在精确新 head HAP 上分别执行手工 IME 与 uitest 输入，采集四时点证据并以最终 A+B 结果证明状态被消费。

**TDD**：[x] RED（identity-only 尝试仍失败，证明需收窄状态绑定） / [x] GREEN（标准 uitest 输入显示并保持） / [x] REFACTOR（最小 diff，全量门禁保持绿色）

### 阶段 3：Developer 门禁与 Tester 交接

#### Task 3.1：执行 Developer 全量回归与范围审计

**描述**：在修复完成后运行既有 Hypium 全量测试、CodeLinter 和 HAP 构建，确认 MatrixEngine、解析/格式化、会话状态及普通/绘图既有测试无回归；审计变更范围、配置、权限、依赖和 Preferences schema。设备 UI 结果只记录 Developer 观察，不替代 Tester 独立结论。

**涉及文件**：
- 测试聚合：`opencalc/entry/src/test/List.test.ets`
- 测试：`opencalc/entry/src/test/MatrixEngine.test.ets`
- 实现审查：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 条件实现审查：`opencalc/entry/src/main/ets/calculator/MatrixEngine.ets`
- 报告：`specs/changes/20261024-bugfix-matrix-operations/apply-report.md`

**依赖任务**：Task 2.1

**验收标准**：
- 新增回归和原 68 个测试全部被发现且通过，Failure/Error 均为 0。
- CodeLinter 和 `assembleHap` 通过；若出现既有 warning，报告中区分基线与新增问题。
- AC-002..009 的算法/解析/精度 oracle、AC-010/011 的会话状态 oracle和既有标量/绘图 unit 回归保持通过。
- 未新增 build-profile/OHPM 依赖/module 权限/Preferences schema/路由；产品源码改动限于 Task 2.1 证明必要的最小文件。
- 报告逐项区分 Developer 已验证的 unit/integration 层与仍待 Tester 执行的 ui/e2e/device 层，不提前宣告 AC-014/015 通过。

**需求追溯**：IR-003、IR-004、IR-005、IR-006、IR-007、IR-008、IR-009、IR-010、IR-011、IR-012 → AC-002..AC-015

**Developer 验证**：Hypium unit + CodeLinter + assembleHap + git diff 范围审计；预期命令 exit code 均为 0，测试日志包含新增回归。

**Tester 验证请求**：不得把 Developer 日志作为独立通过结论；仅把它们作为精确构建身份、变更范围和独立用例设计输入。

**TDD**：[x] RED（首次全量测试因缺失 Hypium 依赖失败，环境原因已分类） / [x] GREEN（ohpm install 后 68/68） / [x] REFACTOR（CodeLinter []、assembleHap 成功、范围审计通过）

#### Task 3.2：提交 AC-015 优先的独立 Tester 复测请求

**描述**：基于权威 JSON 形成 Tester handoff。Tester 必须先在精确新 head 上执行 AC-015；只有输入闭环通过后，才继续执行被该缺陷阻断的 AC-002..012 输入依赖 UI 场景，并完成 AC-014 证据门禁。AC-001/013 的既有通过证据可作历史参考，但新 head 仍需最小冒烟确认入口、网格和控制集合未回归。

**涉及文件**：
- 验收契约：`specs/changes/20261024-bugfix-matrix-operations/acceptance-criteria.json`
- 任务映射：`specs/changes/20261024-bugfix-matrix-operations/tasks.md`
- Developer 报告：`specs/changes/20261024-bugfix-matrix-operations/apply-report.md`
- Tester 报告、日志、UI trees、截图和证据索引：由 Tester 在独立 run evidence 中创建

**依赖任务**：Task 3.1

**验收标准**：
- handoff 记录精确 commit/head、HAP hash、设备/OS、AC ID、步骤、预期、实际、时间、结果和证据位置。
- AC-015 同时覆盖手工触摸+系统 IME和标准 uitest；四时点均有 focus/text/UI tree/screenshot，最终 A+B 证明值被消费。
- AC-015 通过后重跑 AC-002..012 的输入依赖 UI 场景；验证 exact matrix/scalar/text/error/state/regression oracle，不以 unit 代替 UI。
- 新 head 对 AC-001 与 AC-013 做最小冒烟；所有 P0 AC 的独立证据覆盖达到 100% 后才能满足 AC-014。
- 环境不可用或任一语义断言失败时保留 failed/blocked 证据，不标记通过。

**需求追溯**：IR-001..IR-012 → AC-001..AC-015（重点 IR-010/012 → AC-014/015）

**Developer 验证**：检查 AC → Task → verification layer 覆盖率为 100%，并确认精确 head/HAP、四时点证据和失败分类字段均进入 handoff。

**Tester 验证请求**：独立生成并执行测试，先 AC-015，再 AC-002..012，最后汇总 AC-014；保留所有失败与恢复证据。

**TDD**：不适用（独立验证交接任务）；以 15/15 AC 的责任映射和 Tester 实际证据作为 oracle

## 任务依赖与开发顺序

```text
Task 1.1 失败分类
  → Task 1.2 建立行为 RED
    → Task 2.1 最小修复并 GREEN/REFACTOR
      → Task 3.1 Developer 全量门禁
        → Task 3.2 Tester 独立复测交接
```

- 关键路径：1.1 → 1.2 → 2.1 → 3.1 → 3.2。
- 排序理由：设计要求先用焦点/文本分时点证据分类失败，再选择 identity-only 或 identity+state 的最小修复；之后才允许执行全量门禁和 Tester 复测。
- 并行约束：Task 1.1 完成前不并行修改 `CalculatorPage.ets`；Task 2.1 对 `CalculatorPage.ets` 的改动串行完成以避免状态所有权冲突。Tester 可提前准备用例，但不得在新精确 head/HAP 产生前写通过结论。

## AC → Task → 验证责任覆盖自检

| AC | 实现/门禁任务 | Developer 接收层级与 oracle | Tester 必须接收层级与 oracle |
|---|---|---|---|
| AC-001 | 2.1, 3.2 | integration：稳定 cell identity、2/3 网格映射与无范围扩张审查 | ui：A/B 各 4/9 cell、单一活动维度 |
| AC-002 | 3.1, 3.2 | unit/integration：精确 add/sub 矩阵保持通过 | ui：结果网格 exact values/shape |
| AC-003 | 3.1, 3.2 | unit/integration：精确 multiply 矩阵保持通过 | ui：`[[19,22],[43,50]]` |
| AC-004 | 3.1, 3.2 | unit/integration：det=-2、scalar kind | ui：只显示标量 `-2` |
| AC-005 | 3.1, 3.2 | unit/integration：单位阵乘法与 det=1 | ui：3×3 结果逐格等于 B、标量 1 |
| AC-006 | 3.1, 3.2 | unit/integration：exact text matrix，无 -0/尾差 | ui：逐格文本一致 |
| AC-007 | 1.2, 2.1, 3.1, 3.2 | unit/integration：合法语法与提交文本状态不变 | ui：输入可见、可保持、可计算 |
| AC-008 | 1.2, 2.1, 3.1, 3.2 | unit/integration：目标错误清除、完整错误集、无陈旧结果 | ui：两 cell 标错、摘要准确、修复独立 |
| AC-009 | 3.1, 3.2 | unit/integration：B errors=[]、det=-2 | ui：B 全空仍显示 -2 |
| AC-010 | 2.1, 3.1, 3.2 | integration：输入状态修复不破坏 resize 转换 | ui：保留重叠、新格空、结果/错误空 |
| AC-011 | 2.1, 3.1, 3.2 | integration：clear 幂等状态 oracle保持通过 | ui：输入/结果/错误全空、维度不变 |
| AC-012 | 2.1, 3.1, 3.2 | integration：状态隔离、无 schema/权限变化及既有 unit 回归 | ui/e2e：1+2、sin(30)、sin(x) 与返回路径 |
| AC-013 | 2.1, 3.1, 3.2 | integration：无新公共 API/范围外能力 | ui：exact control set |
| AC-014 | 1.1, 3.1, 3.2 | integration：保留失败、handoff 覆盖和层级边界 | e2e：P0 证据 100%，字段齐全且失败留存 |
| AC-015 | 1.1, 1.2, 2.1, 3.1, 3.2 | integration：失败分类、RED→GREEN、当前文本快照被消费 | ui/e2e：手工 IME+uitest、四时点文本/焦点、A+B 消费值 |

自检结论：15/15 AC 均至少关联一个实现或门禁任务；所有 unit/integration/ui/e2e 层级均已分配责任；UI/E2E 未被 Developer unit 替代；设备环境不可用或语义失败时必须保留 pending/blocked/failed 状态。

## 验收计划

| 任务 | 验收方式 | 验收时间 |
|---|---|---|
| Task 1.1 | 精确 head 四时点设备诊断与失败分类 | APPLYING 首项，任何产品修改前 |
| Task 1.2 | 与分类根因对应的 RED 单测或设备回归 | APPLYING，修复前 |
| Task 2.1 | RED→GREEN→REFACTOR + 最小 diff 审查 | APPLYING 实现阶段 |
| Task 3.1 | Hypium、CodeLinter、assembleHap、范围审计 | APPLYING 收尾 |
| Task 3.2 | AC-015 优先的独立设备复测和 AC-014 汇总 | Tester 独立阶段 |

## APPLYING 阶段约束

- 后续代码任务逐项执行 RED → GREEN → REFACTOR；Task 1.1 的诊断门禁不得跳过。
- 不修改 `acceptance-criteria.json` 迁就实现；发现 Planning 缺口时退回 PLANNING。
- 不以 Developer unit 或命令 exit 0 关闭 UI/E2E AC，不以“组件存在”或“无崩溃”替代功能 oracle。
- 只实现 Task 1.1 证据证明必要的最小分支；禁止自定义键盘、测试后门、权限、依赖、持久化或范围外矩阵能力。
- 本 IMPLEMENTING 阶段仅更新 `tasks.md` / `todo.md` 和规定的 checkpoint candidate；不修改产品源码、不运行 APPLYING 或产品测试、不提交、不推送、不归档。
