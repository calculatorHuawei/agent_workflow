# 计算结果小数/分数切换 Tester 反馈修正开发任务

## 任务概述

- 功能名称：结果显示 canonical UI 回归套件持久化
- 变更类型：缺陷修复（Issue #44 / PR #47 Tester feedback）
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 设计输入：`proposal.md` / `delta-spec.md` / `delta-design.md` / `info.md` / `design-review.md`
- 开发阶段：仅补齐 Tester run-59 指出的 canonical UI 用例来源并验证既有 loader 契约
- 预计任务数：2
- 任务粒度：每项预计不超过 1–2 小时；每项均有明确输入、输出与验收标准
- 范围约束：不修改 `opencalc/` 产品源码、`harmony_ui_driver.py`、现有 `function_plot.json`、run-59 evidence 或 PR 历史
- 制品说明：本文取代上一轮面向产品实现的 6 项任务；相关产品行为、主机测试、构建、lint 与模拟器 UI 验收已由 run-59 证明通过

## 任务列表

### 阶段 1：Canonical 测试资产

#### Task 1.1: 持久化已执行的结果显示 UI 套件

**描述**：以 Tester run-59 已执行的 `result-display-toggle-cases.json` 为唯一内容基线，按现有 `function_plot.json` 的 version-1 顶层结构与蛇形文件命名约定，在 canonical 目录新增 `result_display_toggle.json`。只持久化稳定测试意图，不写入设备 ID、HEAD、时间戳、截图路径、绝对 evidence 路径、执行坐标或凭据。

**输入**：
- `D:/huawei/Demo/calculatorHuawei/.agent-runtime/evidence/task-24/run-59/result-display-toggle-cases.json`
- `D:/huawei/Demo/calculatorHuawei/orchestrator/ui_cases/function_plot.json`
- `delta-spec.md` SC004-UC001 / SR-03
- `delta-design.md` §3.9

**输出**：与 run-59 已执行语义一致的 UTF-8 canonical version-1 JSON 套件。

**涉及文件**：
- 测试资产（新增）：`D:/huawei/Demo/calculatorHuawei/orchestrator/ui_cases/result_display_toggle.json`
- 内容基线（只读）：`D:/huawei/Demo/calculatorHuawei/.agent-runtime/evidence/task-24/run-59/result-display-toggle-cases.json`
- 格式参考（只读）：`D:/huawei/Demo/calculatorHuawei/orchestrator/ui_cases/function_plot.json`

**依赖任务**：无

**验收标准**：
- 目标文件位于准确 canonical 路径，能按 UTF-8 解析为 JSON，顶层 `version` 为 `1`，`suite` 为稳定字符串，`cases` 为数组。
- 精确保留 5 个已执行 case：`half-toggle`、`third-toggle`、`reduced-half`、`negative-half`、`integer-fraction-mode`，且 ID 唯一。
- 每个 case 均包含非空 `id`、`purpose`、`expression` 和机器可读 `assertions`。
- 表达式与关键断言覆盖 `1÷2` 双向切换、`1÷3`、`2÷4`、`-1÷2` 和 `4÷2` 不显示 `/1`。
- canonical 内容与 run-59 基线的 `version`、`suite`、case 顺序、ID、purpose、expression、assertions 语义一致，不新增未经执行的产品场景。
- 未修改 `function_plot.json`、现有 evidence、产品源码、driver API 或构建配置。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 2：契约与范围验证

#### Task 2.1: 验证 loader 契约、覆盖集合与最小变更范围

**描述**：使用现有 `harmony_ui_driver.load_cases()` 加载 Task 1.1 的 canonical 文件，并执行结构、唯一性、覆盖集合及 run-59 语义一致性断言。验证失败时修正 JSON 资产，不修改 loader 绕过错误；同时用版本控制 diff 确认没有触碰已通过的产品实现或其他 canonical/evidence 文件。

**输入**：Task 1.1 输出；`delta-spec.md` SC004-UC001 / SR-03；`delta-design.md` §3.9.5–§3.9.10；现有 `orchestrator/harmony_ui_driver.py` 与 driver 测试。

**输出**：可重复的 loader/语义校验结果，以及仅新增目标 JSON 的范围审查结果。

**涉及文件**：
- 被测资产：`D:/huawei/Demo/calculatorHuawei/orchestrator/ui_cases/result_display_toggle.json`
- loader（只读）：`D:/huawei/Demo/calculatorHuawei/orchestrator/harmony_ui_driver.py`
- 既有测试（只读）：`D:/huawei/Demo/calculatorHuawei/orchestrator/tests/test_harmony_ui_driver.py`
- 比对基线（只读）：`D:/huawei/Demo/calculatorHuawei/.agent-runtime/evidence/task-24/run-59/result-display-toggle-cases.json`

**依赖任务**：Task 1.1

**验收标准**：
- `load_cases()` 无异常返回 5 个 `UiCase`，且所有 `id` 唯一、必要字符串字段非空、`assertions` 非空。
- 加载结果的 ID 集合精确等于 `{half-toggle, third-toggle, reduced-half, negative-half, integer-fraction-mode}`。
- expression 映射精确覆盖 `1÷2`、`1÷3`、`2÷4`、`-1÷2`、`4÷2`；整数 case 同时包含 `text_present: 2` 与 `text_absent: 2/1`。
- canonical JSON 与 run-59 基线做结构化比较后语义相等；换行或缩进差异不视为漂移。
- 现有 `test_harmony_ui_driver.py` 通过；无需设备、HAP 重建、产品测试或 UI 重跑即可完成本任务。
- diff 审查确认实现范围仅包含目标 canonical JSON；不修改 `opencalc/`、loader、`function_plot.json`、现有 evidence、提交历史或归档内容。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

## 依赖关系与并行策略

| 任务 | 前置依赖 | 可并行说明 | 关键路径 |
|------|----------|------------|----------|
| Task 1.1 | 无 | 起始任务；先固定已执行基线 | 是 |
| Task 2.1 | Task 1.1 | 不可提前；依赖 canonical 文件存在 | 是 |

## 开发顺序

```text
Task 1.1 → Task 2.1 → 完成
```

## 验收计划

| 任务 | 验收方式 | 验收时间 |
|------|----------|----------|
| Task 1.1 | JSON 结构审查 + run-59 语义比对 | APPLYING 当日 |
| Task 2.1 | `load_cases()` 解析 + 覆盖断言 + 既有 driver 测试 + diff 审查 | APPLYING 当日 |

## 完成定义

- 两项任务均完成 RED、GREEN、REFACTOR 与各自验收标准。
- Tester/Reviewer 能从 `orchestrator/ui_cases/result_display_toggle.json` 稳定加载 run-59 已执行的 5 个结果显示 case。
- run-59 唯一失败门禁“缺少相关 persistent canonical UI suite”已被直接修复。
- 产品源码、driver API、现有 canonical 文件、历史 evidence、提交与归档均保持不变。
- APPLYING 必须由后续独立阶段授权；本 IMPLEMENTING 阶段不创建 JSON、不运行验证、不提交或推送。
