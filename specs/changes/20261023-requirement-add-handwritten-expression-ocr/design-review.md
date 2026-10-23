# 设计审视报告

> 审视对象：`specs/changes/20261023-requirement-add-handwritten-expression-ocr/`
> 审视时间：2026-10-23
> 结论：通过 PLANNING；普通产品歧义已按授权采用安全、可逆、最小范围默认值。

## 1. 完整性评估

- [x] 制品齐全性：通过
  - [x] `proposal.md`：含初始化/意图确认、rq-parse、rq-clarify 自主决策与理由
  - [x] `delta-spec.md`：保留模板 1~13 章，含 5 场景/6 UC、SR 与追溯
  - [x] `info.md`：rq-codebase 代码仓理解
  - [x] `new-arch.md`：复杂需求的架构变更
  - [x] `delta-design.md`：mod-design D1~D10 与自验证
  - [x] `todo.md`：PLANNING 子步骤状态
  - [x] `design-review.md`：本报告
- [x] 需求覆盖度：100%
  - Issue 的入口、权限、拍照、识别、编辑确认、失败恢复、原值保护、安全解析和测试要求均有 UC/SR/设计映射。
  - 待设计项已定为：端侧离线 OCR；基础四则字符集；固定数据集完全识别率 ≥90%；P95 ≤2 s；5 s 超时；确认后替换但不自动计算。

## 2. 一致性评估

- [x] proposal → delta-spec：通过；F1~F5、R1~R6、A-01~A-04 均已落入 IR/SR/UC。
- [x] delta-spec → delta-design：通过；SR-00/01/02 分别映射会话平台、OCR/确认 UI、安全验证。
- [x] delta-design → new-arch：通过；View/Coordinator/Domain/Platform/On-device Provider 边界一致。
- [x] 安全主张：原始 OCR 文本无通向 `CalcEngine` 的直接路径；确认前后二次校验，不使用动态执行。
- [x] 原值保护：拒绝、取消、失败、空结果、非法结果、重拍、超时、迟到回调均不提交；只在 REVIEWING_VALID 的显式确认点替换。
- [x] 隐私与权限：仅 CAMERA 最小权限；图片/候选不持久化、不上传；无网络/账号/密钥/付费依赖。

## 3. 规范性评估

- [x] 格式规范：通过；模板章节完整，不适用项明确说明。
- [x] 命名规范：通过；目录符合 `YYYYMMDD-requirement-add-name`。
- [x] 设计结构：通过；`delta-design.md` 含 D1~D10，架构/状态/时序图使用 PlantUML。
- [x] 可追溯性：通过；IR-046-R1~R6 ↔ SR-00~02 ↔ SC001~005 UC 有明确关系。
- [x] 阶段边界：通过；未创建 `tasks.md`，未修改产品源，未实现、提交、推送或归档。

## 4. 假设、风险与后续门禁

| ID | 已定假设/风险 | 理由 | 后续验证 |
|----|---------------|------|----------|
| A-01 | API 12 存在可用的端侧 OCR Kit 或可随包交付离线组件 | 满足离线、最小权限与隐私边界 | IMPLEMENTING 首个最小编译探针；不可用则阻塞并报告，不改云端 |
| A-02 | 100 张清晰单行、≥5 名书写者数据集可代表首期目标 | 让准确率可重复测量 | Tester 固化样本、真值、设备与结果 |
| A-03 | `x/X` 在本功能中一律表示乘号 | 首期无变量，符合常见手写四则输入 | 归一化单测与 UI 提示 |
| A-04 | 128 code unit 足够首期表达式 | 限制异常输出和解析成本 | 127/128/129 边界测试 |
| P-01 | 相机/OCR/设置跳转的具体 API 符号尚需 SDK 验证 | 规划不虚构平台符号 | 实现前编译核验；保持 adapter 契约不变 |

## 5. 审视结论

PLANNING 通过，可以作为后续 IMPLEMENTING 的输入。后续不得把端侧 OCR 改为云端，不得扩展字符语法、权限或数据留存，也不得降低安全校验；若 API 12 端侧能力不可用，按外部技术依赖报告阻塞，而不是静默扩大范围。
