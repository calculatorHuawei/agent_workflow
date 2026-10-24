# 2×2 / 3×3 矩阵运算开发任务

## 任务概述

- 功能名称：2×2 / 3×3 矩阵运算（Issue #51）
- 变更类型：编排分类为 bugfix；产品语义为新增功能
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 设计输入：`proposal.md`、`acceptance-criteria.json`、`delta-spec.md`、`info.md`、`new-arch.md`、`delta-design.md`、`design-review.md`
- 开发阶段：后续 APPLYING 按 TDD 实现；本文件仅定义任务，不表示任何 AC 已通过
- 预计任务数：9
- 任务颗粒度：每项以 1–2 小时为目标；每项均给出可观察 oracle 和 Developer/Tester 验证责任

## Planning 输入核验

- 8 项 Planning 制品均存在且非空；`design-review.md` 结论为“通过”。
- `acceptance-criteria.json` 可解析，包含 11 个唯一 `IR-*`、14 个唯一 `AC-*` 和 11 份 IR 覆盖评估；AC 的 `source_requirement_ids` 均有效。
- `delta-design.md` 显式追溯 AC-001..AC-014；任务分解不新增、删除或弱化需求级 AC。
- Planning 记录的 AC 校验器结果为 exit 0；IMPLEMENTING 不改写权威验收契约。

## 任务列表

### 阶段 1：纯逻辑与输入边界

#### Task 1.1：以 TDD 实现矩阵领域模型、结构防御和四类算法

**描述**：先为 2×2/3×3 方阵结构、加法、减法、乘法和行列式编写失败测试，再实现无状态 `MatrixEngine`，最后消除重复循环并保持 ArkTS 显式类型。算法不得在中间步骤舍入，也不得接入标量 `CalcEngine`/`ErrorFlags`。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/calculator/MatrixEngine.ets`（新增）
- 测试：`opencalc/entry/src/test/MatrixEngine.test.ets`（新增）

**依赖任务**：无

**验收标准**：
- 2×2 标准算例精确得到加 `[[6,8],[10,12]]`、减 `[[-4,-4],[-4,-4]]`、乘 `[[19,22],[43,50]]`、行列式 `-2`。
- 3×3 单位阵左乘任意合法矩阵保持原矩阵，单位阵行列式为 `1`；补充奇异阵、负数矩阵和非对称矩阵用例。
- 仅接受完整、有限数值的 2 阶或 3 阶方阵；双矩阵运算拒绝不同维度、非方阵和非 finite 元素。
- API 仅暴露本设计所需 add/subtract/multiply/determinant，不提供逆、转置、特征值或 4×4+ 能力。

**需求追溯**：IR-003、IR-011 → AC-002、AC-003、AC-004、AC-005、AC-013

**Developer 验证**：Hypium unit；以 AC 精确矩阵/标量及非法结构抛错或明确失败为 oracle。执行时记录 RED 失败、GREEN 通过、REFACTOR 后复跑结果。

**Tester 验证请求**：独立生成算法单元测试，不复制 Developer 结论；覆盖标准算例、单位阵、奇异阵、负数和范围边界，并记录 AC ID、命令、环境、预期与实际。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.2：以 TDD 实现操作感知的文本解析与全量错误定位

**描述**：为矩阵输入 adapter 编写失败测试，再实现 trim 后的完整十进制匹配、finite 检查、操作感知必填范围和 `CellError[]`。加减乘校验 A+B；det(A) 只校验 A；单次校验必须收集全部错误而非遇首错返回。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/calculator/MatrixEngine.ets`
- 测试：`opencalc/entry/src/test/MatrixEngine.test.ets`

**依赖任务**：Task 1.1

**验收标准**：
- 接受 `2`、`-2`、`+2`、`.5`、`-.5`、`1.` 和前后空白包围的 `1.5`，数值分别与 AC-007 oracle 一致。
- 拒绝空值、内部空白、`1x`、指数、`NaN`、`Infinity`、重复符号及其他非完整十进制文本。
- AC-008 输入一次返回 `A[0,1]` empty 与 `B[1,0]` invalid 两个稳定坐标错误，且无可供 Engine 调用的成功结果。
- det(A) 在 B 全空时不产生 B 错误并返回可计算的 A。

**需求追溯**：IR-002、IR-004、IR-008、IR-003 → AC-007、AC-008、AC-009

**Developer 验证**：Hypium unit；以合法值精确数值、非法值完整错误集合和 det(A) 的空 B 错误集 `[]` 为 oracle。

**Tester 验证请求**：独立执行合法/非法/空值边界测试；设备 UI 阶段确认错误坐标与摘要可见，且无效输入不产生结果。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.3：以 TDD 实现矩阵结果展示格式化

**描述**：先建立浮点噪声、整数、负零、近零、矩阵/标量结果和非 finite 结果的失败测试，再实现仅在展示边界执行的 12 位有效数字规范化。不得修改 MatrixEngine 中间计算值或现有 `NumberFormatter` 的标量契约。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/calculator/MatrixEngine.ets`
- 测试：`opencalc/entry/src/test/MatrixEngine.test.ets`

**依赖任务**：Task 1.2

**验收标准**：
- AC-006 的 A+B 精确输出文本矩阵 `[["0.1","0.3"],["0","0"]]`。
- 不显示 `0.30000000000000004`、`-0` 或整数尾随 `.0`；标量和矩阵共用相同规范化规则。
- 非 finite 运算结果不能被渲染为普通数值，须返回可由页面转成稳定错误的失败状态。

**需求追溯**：IR-004、IR-005 → AC-006

**Developer 验证**：Hypium unit；以 AC-006 exact-text oracle 及非 finite 失败分支为准，REFACTOR 后确认未改标量格式化模块。

**Tester 验证请求**：在设备结果网格中逐格比对 exact text，特别检查 `0.3`、`0`、整数和负零表现。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 2：MatrixPanel 与页面编排

#### Task 2.1：接入矩阵入口、覆盖面板与隔离会话状态

**描述**：在 `CalculatorPage` 增加独立 `matrix*` 状态、ToggleRow 入口、MatrixPanel 条件覆盖层和返回 handler。打开矩阵时关闭 Plot/Settings/About，退出时只隐藏矩阵，不改标量表达式、结果、历史或 Preferences。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 逻辑回归：`opencalc/entry/src/test/MatrixEngine.test.ets`
- Tester UI 证据：由 Tester 在独立验证任务中创建，不在 Developer 阶段预置结论

**依赖任务**：Task 1.3

**验收标准**：
- 主页面存在明确“矩阵”入口；进入后矩阵面板激活，返回后原标量表达式/结果未被覆盖。
- 矩阵、绘图、设置、关于覆盖层互斥，不新增路由、权限、依赖、Preferences key 或历史记录结构。
- 面板只显示 2×2/3×3 与 A+B、A-B、A×B、det(A) 范围内控制。

**需求追溯**：IR-001、IR-009、IR-011 → AC-001、AC-012、AC-013

**Developer 验证**：ArkTS 编译/静态集成检查；检查矩阵 handler 不写标量 `expression/result/errorMsg`，并执行既有 unit suite 防止纯逻辑回归。

**Tester 验证请求**：设备 UI 验证入口、激活态、返回和 overlay 互斥；运行基础 `1+2`、科学 `sin(30)`、绘图 `sin(x)` 回归并保留截图/日志。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 2.2：实现双矩阵网格、单元编辑与维度状态转换

**描述**：实现 A/B 网格 Builder、稳定 cell key、唯一 onChange 坐标映射和固定 3×3 backing state。只投影当前维度；2→3 保留左上 2×2 且新单元为空，3→2 清外围；任何维度变化清结果和全部错误。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 逻辑测试：`opencalc/entry/src/test/MatrixEngine.test.ets`

**依赖任务**：Task 2.1

**验收标准**：
- 2×2 时 A/B 各 4 个、3×3 时各 9 个独立可编辑单元，选中维度与可见网格同步。
- 每个 hit target 只更新其 `matrix-row-column` 坐标，并通过新 row/外层数组引用触发 ArkUI 刷新。
- AC-010 状态转换精确满足：左上重叠输入保留、新增单元为空、结果为空、错误集为空、无旧维度结果残留。
- 编辑错误单元可只清该坐标错误并使旧结果失效，不误清其他坐标错误。

**需求追溯**：IR-001、IR-002、IR-006、IR-008 → AC-001、AC-007、AC-008、AC-010

**Developer 验证**：编译/静态集成检查 + adapter unit；以 cell key 唯一性和 AC-010 状态 oracle 进行代码级审查。

**Tester 验证请求**：设备 UI 逐格输入并截图 A/B 4/9 单元形状；验证角/中心 hit target、2→3→2 转换和错误独立清除。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 2.3：编排校验、四类运算、错误摘要与结果提交

**描述**：连接操作按钮、adapter、MatrixEngine 和 formatter。每次计算先原子清空旧结果/错误；无效时一次提交完整错误 keys/摘要且不调用 Engine；成功时一次提交 matrix/scalar 互斥结果。捕获结构、非 finite 和意外异常并保留可修复输入。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 实现依赖：`opencalc/entry/src/main/ets/calculator/MatrixEngine.ets`
- 测试：`opencalc/entry/src/test/MatrixEngine.test.ets`

**依赖任务**：Task 2.2

**验收标准**：
- UI 操作产生 AC-002..AC-006 的精确矩阵/标量文本及正确结果形状。
- AC-008 时旧结果立即清空，两个错误 cell 同时标记，摘要区分空值与非法数字，且 Engine 未被调用。
- det(A) 在 B 全空时显示 `-2` 且 B 无错误；矩阵结果和标量结果不会同时显示。
- 异常路径提供稳定用户错误，不复用或污染标量 `ErrorFlags`。

**需求追溯**：IR-003、IR-004、IR-005、IR-008 → AC-002、AC-003、AC-004、AC-005、AC-006、AC-008、AC-009

**Developer 验证**：Hypium unit 覆盖 adapter/engine/formatter；编译集成检查操作映射与互斥结果状态。精确 oracle 直接引用 AC JSON，不以“无崩溃”代替。

**Tester 验证请求**：设备 UI 逐项执行 A+B/A-B/A×B/det(A)、负小数消噪、双错误定位与空 B 行列式，保存每个 AC 的预期/实际证据。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 2.4：实现清空、可访问错误反馈、结果布局与小屏可达性

**描述**：完成清空 handler、矩阵/标量只读结果、非纯颜色错误文本和可滚动布局。复用现有主题方法；phone portrait 保证 A/B、操作、错误和结果均可达，旋转或主题变化不得重建矩阵业务状态。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 逻辑回归：`opencalc/entry/src/test/MatrixEngine.test.ets`

**依赖任务**：Task 2.3

**验收标准**：
- 清空同时清 A/B 全部输入、矩阵/标量结果、错误摘要和错误 keys，维度保持且可立即重输；重复清空幂等。
- 错误反馈含矩阵名和 1-based 坐标/原因，不以颜色为唯一信息。
- 2×2/3×3 结果形状清晰，det(A) 仅显示标量；3×3 在目标 phone/tablet 视口中可滚动访问全部主要控制。
- 主题与横竖屏变化不改变 matrixSize、输入、结果或错误语义。

**需求追溯**：IR-003、IR-005、IR-007、IR-008、IR-011 → AC-004、AC-005、AC-006、AC-008、AC-011、AC-013

**Developer 验证**：编译/静态集成检查；对 clear/invalidate handlers 做状态 oracle 审查，并复跑全部逻辑单测。

**Tester 验证请求**：设备 UI 构造输入+结果+错误后执行清空；验证 2×2/3×3、亮/暗主题、竖/横屏和滚动可达性，保留截图。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 3：聚合门禁与独立验收交接

#### Task 3.1：注册测试套件并执行 Developer 侧回归门禁

**描述**：将矩阵 suite 注册到现有 Hypium 聚合入口，确认新增测试真实执行；按仓库既有脚本执行 unit、lint/编译门禁，并检查构建配置、权限、依赖和 Preferences schema 未改变。失败时回到对应 Task 的 RED-GREEN-REFACTOR 循环，不以跳过测试关闭任务。

**涉及文件**：
- 测试聚合：`opencalc/entry/src/test/List.test.ets`
- 测试：`opencalc/entry/src/test/MatrixEngine.test.ets`
- 实现审查：`opencalc/entry/src/main/ets/calculator/MatrixEngine.ets`
- 实现审查：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`

**依赖任务**：Task 1.1、Task 1.2、Task 1.3、Task 2.1、Task 2.2、Task 2.3、Task 2.4

**验收标准**：
- `List.test.ets` 显式调用矩阵 suite，执行日志显示矩阵用例被发现且运行。
- Developer unit 全部通过；ArkTS lint/编译通过；失败日志保留且被修复后再运行。
- 基础标量与绘图既有 unit 回归通过；无 build-profile、OHPM 依赖、module 权限或 Preferences schema 变更。
- Developer 报告逐项列出 AC 的已验证层级和仍需 Tester 完成的 ui/e2e/device 层级，不提前宣告 feature AC 完成。

**需求追溯**：IR-003、IR-004、IR-005、IR-009、IR-010 → AC-002、AC-003、AC-004、AC-005、AC-006、AC-007、AC-008、AC-009、AC-012、AC-014

**Developer 验证**：Hypium unit + 仓库既有 lint/编译命令 + 变更范围审计；预期 exit code 均为 0 且 suite 日志包含矩阵测试。

**Tester 验证请求**：不得把 Developer 日志作为独立通过结论；可将其作为实现版本/用例范围输入，另行生成和执行测试。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 3.2：提交 Tester 独立验证请求与 AC 证据清单

**描述**：基于权威 `acceptance-criteria.json` 准备不可替代的 Tester handoff，明确算法、边界、关键 UI、兼容回归和设备环境责任。Developer 只提供构建物、AC 映射和已知限制，不代写通过证据；环境不可用时保持 AC 为待验证并记录依赖。

**涉及文件**：
- 验收契约：`specs/changes/20261024-bugfix-matrix-operations/acceptance-criteria.json`
- 任务映射：`specs/changes/20261024-bugfix-matrix-operations/tasks.md`
- 后续 Developer 应用报告：由 APPLYING 阶段按其模板创建
- Tester 报告/日志/截图索引：由 Tester 在独立任务目录创建

**依赖任务**：Task 3.1

**验收标准**：
- Tester 请求覆盖 AC-001..AC-014；每个 P0 AC 至少要求一条实际执行证据。
- 证据字段包含 AC ID、测试环境、命令或步骤、预期、实际、时间、结果及失败保留位置。
- 算法、合法/非法/精度/状态边界、关键 UI 和基础/科学/绘图兼容回归四类请求均非空。
- UI/E2E AC 只能由设备或模拟器实际执行证据关闭；环境不可用时标为 blocked/pending，不标记通过。

**需求追溯**：IR-001..IR-011 → AC-001..AC-014（重点 IR-010 → AC-014）

**Developer 验证**：检查 handoff 的 AC 覆盖率为 100%，并确认每个 AC 的 verification_layers 均被 Developer 或 Tester 接收。

**Tester 验证请求**：在 HarmonyOS 模拟器或真机独立生成并执行测试，保证 P0 AC evidence coverage=100%，算法/边界/UI 证据均非空，失败证据可追溯。

**TDD**：不适用（验证交接任务）；以 AC 覆盖矩阵和独立执行证据作为完成 oracle

## 任务依赖与开发顺序

```text
Task 1.1
  → Task 1.2
    → Task 1.3
      → Task 2.1
        → Task 2.2
          → Task 2.3
            → Task 2.4
              → Task 3.1
                → Task 3.2
```

- 关键路径：1.1 → 1.2 → 1.3 → 2.1 → 2.2 → 2.3 → 2.4 → 3.1 → 3.2。
- 排序理由：先稳定纯逻辑和输入/格式边界，再接页面状态与 UI，最后注册聚合测试并交给独立 Tester。
- 并行约束：为避免 `MatrixEngine.ets`、`MatrixEngine.test.ets` 和 `CalculatorPage.ets` 上的写冲突，默认串行；Tester 可在 Task 3.1 期间依据已冻结 AC 准备独立用例，但不得提前写通过结论。

## AC → Task → 验证责任覆盖自检

| AC | 实现/门禁任务 | Developer 接收层级与 oracle | Tester 必须接收层级与 oracle |
|---|---|---|---|
| AC-001 | 2.1, 2.2, 3.2 | integration：入口、2/3 激活态及网格数量代码/编译检查 | ui：A/B 各 4/9 cell、单一活动维度 |
| AC-002 | 1.1, 2.3, 3.1, 3.2 | unit/integration：精确 add/sub 矩阵 | ui：结果网格 exact values/shape |
| AC-003 | 1.1, 2.3, 3.1, 3.2 | unit/integration：精确 multiply 矩阵 | ui：`[[19,22],[43,50]]` |
| AC-004 | 1.1, 2.3, 2.4, 3.1, 3.2 | unit/integration：det=-2、scalar kind | ui：只显示标量 `-2` |
| AC-005 | 1.1, 2.3, 2.4, 3.1, 3.2 | unit/integration：单位阵乘法与 det=1 | ui：3×3 结果逐格等于 B、标量 1 |
| AC-006 | 1.3, 2.3, 2.4, 3.1, 3.2 | unit/integration：exact text matrix，无 -0/尾差 | ui：逐格文本一致 |
| AC-007 | 1.2, 2.2, 3.1, 3.2 | unit/integration：约定语法映射到精确数值 | ui：输入可编辑且可计算 |
| AC-008 | 1.2, 2.2, 2.3, 2.4, 3.1, 3.2 | unit/integration：完整错误集、无 Engine 成功结果 | ui：两 cell 标错、摘要准确、旧结果为空 |
| AC-009 | 1.2, 2.3, 3.1, 3.2 | unit/integration：B errors=[]、det=-2 | ui：B 全空仍可显示 -2 |
| AC-010 | 2.2, 3.2 | integration：resize 状态转换审查 | ui：保留重叠、新格空、结果/错误空 |
| AC-011 | 2.4, 3.2 | integration：clear 幂等状态 oracle | ui：输入/结果/错误全空、维度不变 |
| AC-012 | 2.1, 3.1, 3.2 | integration：状态隔离、无 schema/权限变更、既有 unit 回归 | ui/e2e：1+2、sin(30)、sin(x) 与返回路径 |
| AC-013 | 1.1, 2.1, 2.4, 3.2 | integration：领域 API/控制集无范围外能力 | ui：exact control set |
| AC-014 | 3.1, 3.2 | integration：handoff 覆盖率 100%，不冒充独立结果 | e2e：P0 证据 100%，字段齐全且失败留存 |

自检结论：14/14 AC 均至少关联一个实现或门禁任务；所有 unit/integration/ui/e2e 层级均已分配责任；UI/E2E 未被 unit 替代；设备环境不可用时必须保留 pending/blocked 状态。

## 验收计划

| 任务 | 验收方式 | 验收时间 |
|---|---|---|
| Task 1.1 | TDD unit：算法与结构防御 | APPLYING 对应任务完成时 |
| Task 1.2 | TDD unit：解析与错误集合 | APPLYING 对应任务完成时 |
| Task 1.3 | TDD unit：exact display text | APPLYING 对应任务完成时 |
| Task 2.1 | 编译/集成检查 + Tester overlay/UI | Developer APPLYING；Tester 独立阶段 |
| Task 2.2 | 状态转换审查 + Tester 网格/UI | Developer APPLYING；Tester 独立阶段 |
| Task 2.3 | unit/integration + Tester 运算/UI | Developer APPLYING；Tester 独立阶段 |
| Task 2.4 | 状态 oracle + Tester 清空/布局/UI | Developer APPLYING；Tester 独立阶段 |
| Task 3.1 | suite 注册、unit、lint/编译、范围审计 | APPLYING 收尾 |
| Task 3.2 | AC 覆盖检查 + 独立 Tester 证据 | Tester 阶段；不得由 Developer 预判通过 |

## APPLYING 阶段约束

- 后续逐任务执行 RED → GREEN → REFACTOR；未看到预期 RED 不进入实现。
- 不修改 `acceptance-criteria.json` 以迁就实现；发现 Planning 缺口时退回 PLANNING。
- 不以 Developer unit 关闭 UI/E2E AC，不以“组件存在”或“无崩溃”替代功能 oracle。
- 本 IMPLEMENTING 阶段未修改产品源码、未运行 APPLYING、未执行构建/产品测试、未提交、未推送、未归档。
