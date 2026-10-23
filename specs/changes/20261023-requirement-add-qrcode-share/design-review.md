# 设计审视报告 — QR 截图可解码缺陷修复（PLANNING Step 9）

> 审视对象：`specs/changes/20261023-requirement-add-qrcode-share/` 的本轮 PLANNING 制品
>
> 触发：Tester run-35 对 PR #43 head `964c83e77e0c558001dcff396c07d43b226deae4` 返回 changes_requested
>
> 日期：2026-10-23

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

**PLANNING 通过。** 初始化、意图、需求、代码仓、复杂度、架构、组件设计和一致性均已复核；本轮无架构或数据模型变更，无需用户对 material ambiguity 作选择。可以进入后续任务分解/应用阶段，但本轮严格止于 PLANNING：未创建或修改 tasks.md，未修改产品源码，未实现、提交、推送或归档。
