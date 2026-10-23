# PR #43 Developer 过程证据修复开发任务

## 任务概述

- 功能名称：Reviewer 反馈——可审计的重复 TDD 与 exact-head Developer 交接
- 变更类型：缺陷修复（`reviewer_feedback` / process-evidence bugfix）
- 关联制品：`proposal.md` §11 / `delta-spec.md` §14（SC-006、SR-05）/ `delta-design.md` §11 / `info.md` §12 / `design-review.md` §5
- 产品基线：PR #43 head `4f81d91ab0e6ed638f955f5f9201ad93b6ce2f70`；Tester run-47 与 Reviewer result audit 已确认产品结果通过
- 开发阶段：仅规划后续 APPLYING；本文件不代表 TDD、提交、交付或审批已执行
- 预计任务数：5
- 任务颗粒度：每项预计 1–2 小时，均有明确输入、输出、依赖和可复核验收标准

## Planning 制品核验结论

- `proposal.md`：本轮只修复 Developer 过程证据；不得改写已通过的产品结论或扩大 Issue #42 范围。
- `delta-spec.md`：SC006-UC001 要求同一新 session 内逐任务真实 RED→GREEN→REFACTOR；SC006-UC002 要求 final SHA、hash 与引用路径一致。
- `delta-design.md`：§11 定义证据组件、执行时序、RED 真实性契约、日志字段和 exact-head 生成规则。
- `info.md`：未发现 `334f241`/`4f81d91` 的 originating session，因此只能采用 Reviewer 明确允许的“重复过程”路径。
- `design-review.md`：PLANNING 已通过；旧 run-46/evidence 必须保持原样，新 session、新日志、新 structured output 和新 run 共同闭环。
- `todo.md`：Planning checkpoint 已完成；本轮 IMPLEMENTING 只重做 SC-006/SR-05 的任务分解与排序。

## 任务列表

### 阶段 1：证据门禁与执行基线

#### Task 1.1: 建立同一 session 的可审计执行基线

**描述**：在后续 APPLYING session 开始时记录 session 起始时间、分支、HEAD、工作树状态、origin tracking ref，并为每个后续任务预建符合 `delta-design.md` §11.5 的证据条目和原始日志路径。先对旧 run-46 执行一致性断言，真实观察其顶层 SHA/structured output SHA 与提交/session 时间线失败（RED）；再将相同断言应用于本轮空白证据骨架，补齐可验证字段和阻塞规则（GREEN）；最后整理为所有任务复用的统一记录格式并复跑（REFACTOR）。不得编辑旧 run-46 或旧 session。

**涉及文件**：

- 过程日志：`specs/changes/20261023-requirement-add-qrcode-share/logs/verification-log.md`
- 后续报告：`specs/changes/20261023-requirement-add-qrcode-share/apply-report.md`
- 只读输入：`.agent-runtime/evidence/task-14/run-46.json`
- 新证据：由本轮 APPLYING/orchestrator 分配的新 evidence 与 handoff 路径

**依赖任务**：无

**验收标准**：

- 起始记录包含 session 时间、branch、HEAD、`git status --short`、origin tracking ref，且 session 起始时间早于本轮任何实现提交。
- 旧 run-46 校验以 Reviewer 已确认的 SHA 分裂/时间线问题真实失败；环境、网络或缓存错误不得计作 RED。
- 每条任务证据具备 `task_id/phase/command/started_at/finished_at/exit_code/expected/observed/log_path/source_state` 字段。
- 任一 RED 非预期、GREEN 未通过、日志缺失或 SHA 不一致时，状态保持 blocked，不得继续声称 ready_for_test。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

**追溯**：SC006-UC001、SC006-UC002、SR-05、AC12、AC14、AC15

### 阶段 2：受控重复产品修复（真实 TDD）

#### Task 2.1: 重复 213/214 字节容量契约的可追踪 TDD

**描述**：基于当前已绿产品基线，按设计允许的受控、可恢复实现缺口重复容量修复。先在 session 内建立与 QR 容量直接相关的受控缺口，使持久化的 213 字节通过/214 字节拒绝断言因预期契约失败而产生真实 RED；随后恢复/实现 `QrPayload` 与 `QrEncoder` 一致的 213 字节上限并用同一测试目标 GREEN；最后仅整理常量、注释或重复逻辑并以相同或更大范围复跑 REFACTOR。最终行为不得弱于 `4f81d91`。

**涉及文件**：

- 实现：`opencalc/entry/src/main/ets/qrcode/QrPayload.ets`
- 只读契约核对：`opencalc/entry/src/main/ets/qrcode/QrEncoder.ets`
- 测试：`opencalc/entry/src/test/QrShare.test.ets`
- 证据：`specs/changes/20261023-requirement-add-qrcode-share/logs/verification-log.md`

**依赖任务**：Task 1.1

**验收标准**：

- RED 为实际测试命令的非零退出码，且失败断言明确指向 213/214 容量契约；缺依赖、网络或工具故障不计。
- 实现/恢复动作在 RED 与 GREEN 之间，并可从 session 的文件修改记录定位。
- GREEN 证明 213 字节载荷成功、214 字节载荷明确拒绝，载荷层与编码器边界一致。
- REFACTOR 后同一或更大测试范围通过，普通/科学/小数/负数/多字节/长表达式行为无退化。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

**追溯**：SC006-UC001、SR-05、SC002-UC002、SR-00、CM-06、AC12、AC14

#### Task 2.2: 重复 QrLayout 整数布局与空间不足契约的可追踪 TDD

**描述**：在同一 session 中对 QrLayout 建立受控、可恢复缺口，使现有/补强的整数模块、4 模块静区、大画布上限和空间不足断言真实失败；随后恢复/实现合法输入与失败值契约并 GREEN；再整理边界分支并 REFACTOR 复跑。不得用书面声明或临时伪日志替代命令输出。

**涉及文件**：

- 实现：`opencalc/entry/src/main/ets/qrcode/QrLayout.ets`
- 测试：`opencalc/entry/src/test/QrShare.test.ets`
- 证据：`specs/changes/20261023-requirement-add-qrcode-share/logs/verification-log.md`

**依赖任务**：Task 2.1

**验收标准**：

- RED 由预期布局断言失败产生，并记录非零退出码、原始日志与执行前源码状态。
- GREEN 证明返回值为非负整数、大画布上限为 4、完整尺寸包含左右各 4 模块静区且不超画布。
- 非有限/非正尺寸、无效矩阵边长、`quietModules < 4` 和小于最小可绘制模块的空间均进入调用方可识别的失败契约。
- REFACTOR 后相同或更大范围测试通过，QrLayout 保持无状态、零 UI/Kit/OHPM 依赖。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

**追溯**：SC006-UC001、SR-05、SC005-UC001、SR-03、SR-04、AC12、AC14

#### Task 2.3: 重复 Canvas 完整重绘与内容刷新生命周期的可追踪 TDD

**描述**：围绕 CalculatorPage 最终像素链路建立不扩大需求的受控缺口或新增持久化可验证断言，使清旧态、显式白底黑模块、完整静区、空间不足失败态或重开刷新中的目标行为真实 RED；随后恢复/实现同一行为并 GREEN；再整理绘制/状态分支并 REFACTOR 复跑。若无法形成真实、产品相关的 RED，必须阻塞并报告，禁止把已绿断言冒充 RED。

**涉及文件**：

- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 布局实现：`opencalc/entry/src/main/ets/qrcode/QrLayout.ets`
- 测试：`opencalc/entry/src/test/QrShare.test.ets`
- 证据：`specs/changes/20261023-requirement-add-qrcode-share/logs/verification-log.md`

**依赖任务**：Task 2.2

**验收标准**：

- RED、修改、GREEN、REFACTOR 在同一 session 中按时间顺序可见；RED 失败点属于 SC005/SR-03 已批准范围。
- 每次打开先清除旧矩阵/成功态/错误态，再从当前 expression/result 生成；失败不得保留旧码。
- Canvas 完整铺白、黑模块按整数坐标绘制并保留完整静区；空间不足或绘制异常显示明确失败态。
- `1+2=3` 关闭后计算 `2+3=5` 并重开时仅引用新内容；关闭仍只改变面板可见状态。
- 不修改 `plot/`、`calculator/`、`model/`、`preferences/`、路由、权限或依赖配置。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

**追溯**：SC006-UC001、SR-05、SC005-UC001/UC002、SR-03、AC12、AC14、AC16

### 阶段 3：回归、提交与 exact-head 交接

#### Task 3.1: 生成单一 final SHA 的新 Developer 证据链

**描述**：前三个任务 REFACTOR 后，执行完整 Local Test、HAP build、变更源 CodeLinter 和保护模块 diff；在同一 session 中提交本轮真实变更，使提交时间晚于 session 开始。先用统一校验对旧 run-46 或未完成的新交接观察必然失败（RED），再基于 final commit 生成新的 structured output、session snapshot、hash 与 orchestrator run/delivery 事实并通过全部一致性断言（GREEN），最后收敛重复校验并复跑（REFACTOR）。旧 evidence 保持原样；网络不可用时只能使用 orchestrator-host 已验证事实，缺失即 blocked。

**涉及文件**：

- 持久化测试：`opencalc/entry/src/test/QrShare.test.ets`
- 测试注册：`opencalc/entry/src/test/List.test.ets`（仅核验，注册已存在则不修改）
- 应用报告：`specs/changes/20261023-requirement-add-qrcode-share/apply-report.md`
- 验证日志：`specs/changes/20261023-requirement-add-qrcode-share/logs/verification-log.md`
- 新交接/证据：由本轮 orchestrator 分配的 handoff、session snapshot 与 run manifest 路径

**依赖任务**：Task 2.3

**验收标准**：

- 全量 Local Test、HAP build、变更源 CodeLinter 全部通过；AC8 保护模块 diff 为空。
- 本轮 final commit 时间晚于 session 开始，工作树在交接时干净。
- `run_manifest.head_sha`、structured output 的 `commit_sha/head_sha`、本地 HEAD、origin tracking ref 与 delivery head 完全相同。
- structured output 与 session snapshot 的 SHA-256 可重算一致；manifest 引用路径全部存在。
- 若最终 SHA 改变，handoff 明确要求 Tester/Reviewer 对该准确 SHA 重新执行门禁；Developer 不自批、不归档。
- 任一 SHA/hash/path/远端事实缺失或不一致时输出 blocked，不得标记 ready_for_test。

**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

**追溯**：SC006-UC002、SR-05、AC13、AC15、AC16；AC11 仍由 Reviewer 执行

## 任务依赖与开发顺序

```text
Task 1.1 → Task 2.1 → Task 2.2 → Task 2.3 → Task 3.1 → 独立 Tester → Reviewer
```

- 全部任务串行：它们必须共享同一可保存 Applying session 与连续时间线，不能并行拆分到无法关联的 session。
- 关键路径：Task 1.1 建立证据门禁 → 三个受控重复 TDD 任务 → Task 3.1 final SHA/hashes/run manifest。
- 禁止提前：未完成 Task 3.1 的一致性校验前不得 ready_for_test；最终 SHA 变化后不得复用 run-47 作为该 SHA 的最终批准。

## 验收计划

| 任务 | 验收方式 | 后续阶段 |
|------|----------|----------|
| Task 1.1 | 对旧 run-46 的预期失败 + 新 session 起始事实/日志字段审计 | APPLYING |
| Task 2.1 | 213/214 容量契约同目标 RED-GREEN-REFACTOR | APPLYING |
| Task 2.2 | QrLayout 边界同目标 RED-GREEN-REFACTOR | APPLYING |
| Task 2.3 | Canvas/刷新生命周期同目标 RED-GREEN-REFACTOR + UI 预检 | APPLYING |
| Task 3.1 | 全量回归 + 提交时间线 + final SHA/hash/path 一致性审计 | APPLYING/Tester handoff |

## 范围护栏

- 本轮只修复 Reviewer run-48 的两个 process-audit finding，并重复已批准 QR 修复任务以产生真实、可审计的 TDD 证据。
- 不编辑或覆盖旧 run-46、旧 session、Tester run-47 或 Reviewer run-48；新证据使用新路径。
- 不新增产品能力、不放宽验收标准、不触碰 AC8 保护模块、不引入网络/依赖/权限/路由/持久化数据。
- IMPLEMENTING 完成只授权后续 workflow gate 审查任务计划；本阶段不修改产品源码、不执行测试/构建、不 commit、不 push、不 approve、不 archive。
