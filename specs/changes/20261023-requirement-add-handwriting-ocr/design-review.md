# 设计审视报告

> 审视对象：`specs/changes/20261023-requirement-add-handwriting-ocr/`
> 审视时间：2026-10-24
> 精确基线：PR #48 head `19f7c3d146dc30574738dd2187dd99ec6877610d`
> 结论：通过 PLANNING；普通产品歧义已按授权采用安全、可逆、最小范围默认值，真机/数据集证据明确移交 Tester。

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
  - 待设计项已定为：CoreVisionKit 端侧离线 OCR；基础四则字符集；固定数据集完全识别率 ≥90%；P95 ≤2 s；5 s 超时；确认后替换但不自动计算。
  - 本轮未创建 `tasks.md`；目录中的制品均为 PLANNING 输出。

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
| A-01 | API 12 CoreVisionKit/CameraKit/ImageKit 可编译 | 满足离线、最小权限与隐私边界 | 已由精确 head 的 HAP build 验证；真机行为由 Tester 验证 |
| A-02 | 100 张清晰单行、≥5 名书写者数据集可代表首期目标 | 让准确率可重复测量 | Tester 固化样本、真值、设备与结果 |
| A-03 | `x/X` 在本功能中一律表示乘号 | 首期无变量，符合常见手写四则输入 | 归一化单测与 UI 提示 |
| A-04 | 128 code unit 足够首期表达式 | 限制异常输出和解析成本 | 127/128/129 边界测试 |
| P-01 | 真实相机与 CoreVisionKit 成功路径尚无物理设备证据 | Developer 环境只有模拟器 | Tester 在支持设备完成拍摄、识别、确认填入 |
| P-02 | 固定 100 图/≥5 书写者数据集不存在 | 不伪造质量样本或指标 | Tester 建立/审计数据集并测量 ≥90% 完全匹配率 |
| P-03 | P95、飞行模式和持久文件扫描未完成 | 依赖支持设备与测试环境 | Tester 记录设备/系统版本、样本、耗时和隐私扫描结果 |
| P-04 | CodeLinter 有 279 个既有 warning、0 error | 不在本 Issue 扩大基线清理范围 | 保留为项目基线风险；新增代码不得引入 error |

## 5. 审视结论

PLANNING 通过。精确 PR head 的实现已存在，且上游 evidence 记录 API 12 build、57/57 Local Test、CodeLinter 0 error 和可用模拟器恢复路径通过；因此无需再次进入 IMPLEMENTING/APPLYING，也无需修改产品代码。真实拍摄/OCR 成功、固定数据集准确率、P95、飞行模式和持久文件扫描作为 Tester 风险继续验证，不是 Developer blocker；最终验收标准不降低。后续不得把端侧 OCR 改为云端，不得扩展字符语法、权限或数据留存，也不得降低安全校验。

## 6. 会话快照与边界审计

| 检查项 | 结果 |
|--------|------|
| 初始化 | `specs/initialized.flag` 存在；PROJECT_ROOT/CHANGES_ROOT/TEST_ROOT 有效 |
| 意图 | 产品新增功能；本轮 bugfix 为 Developer→Tester 门禁纠偏 |
| HEAD | worktree、任务 PR head、Developer evidence 均为 `19f7c3d146dc30574738dd2187dd99ec6877610d` |
| Evidence | `D:\\huawei\\Demo\\calculatorHuawei\\.agent-runtime\\evidence\\task-23\\run-61.json` |
| 产品源码 | 本轮未修改 |
| 禁止制品/动作 | 未创建 `tasks.md`；未实现、提交、推送或归档 |
