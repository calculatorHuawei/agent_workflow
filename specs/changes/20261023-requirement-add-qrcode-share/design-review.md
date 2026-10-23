# 设计审视报告 — Reviewer 过程证据修复（PLANNING Step 9）

> 审视对象：`specs/changes/20261023-requirement-add-qrcode-share/` 的本轮 PLANNING 制品
>
> 触发：Reviewer run-48 对 PR #43 head `4f81d91ab0e6ed638f955f5f9201ad93b6ce2f70` 返回 changes_requested；产品 result audit 通过，process audit 因 Developer manifest SHA 不一致与 TDD session 不具认证性而失败
>
> 日期：2026-10-23

> 阅读说明：§1–§4 保留上一轮 Tester 截图缺陷规划的审视记录作为历史基线；§5 是本轮 Reviewer process-audit 反馈的现行审视结论。

## 1. 完整性评估

- [x] 制品齐全性：**通过**
  - proposal.md：已把本轮意图从原始“新增功能”上下文修订为 tester_feedback **缺陷修复**。
  - delta-spec.md：保留模板 §1–§13，新增 SC-005 两个完整 MOD 用例及 SR/追溯更新。
  - info.md：已按 rq-codebase 增量分析当前仓库、`964c83e..334f241` 差异和 Tester 最终像素链路。
  - delta-design.md：保留 mod-design D1–D10，新增 §3.8 QrLayout 截图可解码布局设计。
  - new-arch.md：已存在且本轮复核结论仍为“无架构级变更”；QrLayout 是 qrcode 内部纯函数，不需新增架构文档。
  - todo.md：本轮 PLANNING 子步骤和阶段状态已刷新。
  - tasks.md：是先前阶段已有文件；本轮按指令**未创建、未修改**。
- [x] 需求覆盖度：**100%（本轮范围）**
  - Tester 失败 AC2/AC3/AC5/AC10 → proposal §4.5/R7 → delta-spec SC005-UC001/UC002、SR-03/SR-04 → delta-design §3.8 → Tester 独立截图解码门禁。
  - 已通过 AC1/AC4/AC6/AC7/AC8/AC9 作为保护范围保留；AC11 仍为 Reviewer 职责。

## 2. 一致性评估

- [x] proposal → delta-spec：**通过**
  - F7/R7 的整数模块像素、显式白底、4 模块静区、重绘时序、空间不足失败态和独立解码门禁均在 SC-005 与 SR-03/SR-04 呈现。
  - 容量口径统一为 EC-M v10 byte 模式 **213 字节**；不再把 271 字节写成标准容量。
- [x] delta-spec → delta-design：**通过**
  - SC005-UC001 → §3.8 QrLayout + §3.6 Canvas 双层白底/完整重绘 + §3.7 布局边界测试。
  - SC005-UC002 → 打开时清旧态/现算矩阵/按最新尺寸重绘 + 两次设备截图独立解码。
  - SR-00 容量契约与 §3.5/§4.8 统一为 213/214 边界。

## 3. 规范性评估

- [x] 格式规范：**通过**
  - delta-spec 新场景包含 STAGE 五要素、Actor、前置条件、最小/成功保证、主/扩展路径、Given-When-Then、IR→SR 分解。
  - delta-design 新模块包含 3.8.1–3.8.10，全 D1–D10 结构保留。
- [x] 命名规范：**通过（有说明）**
  - 本轮 intent=bugfix，但 orchestrator 明确指定复用既有 `20261023-requirement-add-qrcode-share`；不因阶段复规划擅自移动或重命名目录。
- [x] 不猜测 material ambiguity：**通过**
  - 文档只把“最终截图不可解码/主题呈现异常”写为已观察事实；未把某个 Canvas 运行时机制伪装成已证实根因。模块像素上限属于待设备证据验证的设计约束。

## 4. 风险与后续门禁

| # | 风险/待验证项 | 门禁 | 归属 |
|---|---------------|------|------|
| 1 | 当前 HEAD `334f241` 含候选 QrLayout 修复，但尚无本轮独立 Tester 证据 | 后续阶段必须把最终 PR head SHA 写入构建、安装、截图和解码证据；不得沿用 `964c83e` 的 Developer 证据 | Applying/Tester |
| 2 | 代码中载荷层仍可能保留 271 字节常量，与编码器 213 字节不一致 | 后续实现按规划统一 213/214 边界并更新持久化测试 | Applying |
| 3 | 小画布布局函数可能返回小于最小可绘制模块的数值 | 调用方必须显式失败或选择可解码布局，不得静默空白/旧码 | Applying |
| 4 | 纯函数与矩阵测试不能覆盖 ArkUI Canvas 最终像素 | light/dark/AMOLED 原始设备截图逐张独立解码；内容更新前后各保留解码日志 | Tester |
| 5 | 横屏验证受当前 Emulator CLI 限制 | 保留证据并由 Reviewer 判断环境限制；不得把未执行写成通过 | Tester/Reviewer |

## 5. 审视结论

### 5.1 本轮增量完整性

- [x] proposal.md：新增 §11，明确 process-evidence bugfix、证据搜索结论、R8 与 AC12–AC16。
- [x] delta-spec.md：新增 §14、SC-006 两个完整 MOD 用例与 SR-05；包含 STAGE、Actor、前置条件、最小/成功保证、主/扩展路径、Given-When-Then 和 IR→SR 追溯。
- [x] info.md：新增 §12，记录 run-46/run-47/run-48、Git/session 时间线和 originating session 检索结果。
- [x] delta-design.md：新增 §11，给出同 session TDD 时序、日志模型、RED 真实性契约和 exact-head manifest 算法。
- [x] todo.md：只更新本轮 PLANNING 跟踪；`tasks.md` 未创建、未修改。
- [x] new-arch.md：无需更新；过程证据修复不改变 HAP、页面、接口、数据流或部署架构。

### 5.2 一致性与可验证性

| 检查 | 结果 |
|---|---|
| Reviewer finding 1 → proposal/spec/design | R8/AC13/AC15 → SC006-UC002/SR-05 → delta-design §11.6，完整覆盖 |
| Reviewer finding 2 → proposal/spec/design | R8/AC12/AC14 → SC006-UC001/SR-05 → delta-design §11.3–§11.4，完整覆盖 |
| result audit 与 process audit 分离 | 保留 Tester run-47 产品结果事实；不将其冒充 Developer TDD 证据 |
| exact-head 规则 | 顶层/structured output/local/origin/delivery 单一 final SHA；不一致即 blocked |
| TDD 真实性 | RED 必须为预期断言失败，环境失败不计；修改必须位于 RED 与 GREEN 之间 |
| 最终 SHA 变化后的门禁 | 明确要求重新走 Tester/Reviewer，禁止复用旧 SHA 最终批准 |

### 5.3 模糊性审视

Reviewer 提供了两个修复路径：“提供 originating Applying session/evidence”或“重复过程”。对 `.agent-runtime/evidence` 的检索只发现 task-12 与 task-14 两个事后审计 session，没有覆盖 `334f241`/`4f81d91` 实际修改的 originating session。因此选择“重复过程”由可验证事实和 Reviewer 明示选项共同决定，不是对 material ambiguity 的猜测。若后续发现此前未暴露的可信 originating evidence，应先交由 Reviewer 判断，不能在 Applying 中擅自切换路径。

### 5.4 风险与后续门禁

| # | 风险 | 设计门禁 | 归属 |
|---|---|---|---|
| 1 | 当前代码已绿，伪 RED 风险 | 断言若预先通过则不计 RED；必须建立不扩大需求的真实缺口或阻塞 | Implementing/Applying |
| 2 | 手工修改旧 run-46 掩盖历史 | 生成新 run、新 session、新 hash；旧 evidence 保持原样 | Applying/orchestrator |
| 3 | 新提交改变 final SHA | exact SHA 重新 Tester/Reviewer，不复用 run-47 作最终 head 批准 | Tester/Reviewer |
| 4 | 日志只有摘要无原始输出 | per-task 字段 + 原始日志路径 + session 工具调用三方交叉验证 | Applying |
| 5 | 把产品通过等同过程通过 | result/process 双审继续独立 | Reviewer |

### 5.5 审视结论

**PLANNING 通过。** 初始化、bugfix 意图、Reviewer 两个 major finding、代码仓/证据仓事实、复杂度、无架构变更结论、过程组件设计和追溯均已复核。没有待用户选择的 material ambiguity。本轮严格止于 PLANNING：未创建或修改 `tasks.md`，未修改产品源码，未实施 TDD，未构建、提交、推送、审批或归档。
