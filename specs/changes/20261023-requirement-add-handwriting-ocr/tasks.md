# 拍照识别手写算式交付门禁纠偏开发任务

## 任务概述

- 功能名称：拍照识别手写算式并自动填入
- 产品需求类型：新增功能
- 本次变更类型：缺陷修复（既有实现的 Developer→Tester 交付门禁纠偏）
- 关联 Issue / PR：Issue #46 / PR #48
- 精确基线：`19f7c3d146dc30574738dd2187dd99ec6877610d`
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 规划输入：`proposal.md` / `delta-spec.md` / `delta-design.md` / `info.md` / `design-review.md`
- 开发阶段：IMPLEMENTING 任务分解；既有实现采用“先验证、仅在发现规格偏差时补强”的执行方式
- 预计任务数：12
- 单任务目标工时：1–2 小时

## 执行边界

- 本清单不把真实相机、真实手写 OCR、100 图/至少 5 名书写者数据集、准确率、P95、飞行模式或持久文件隐私扫描作为 Developer 完成条件；这些项目是 Tester 风险和最终验收门禁。
- Developer 门禁固定为：精确 PR head 上 API 12 HAP 构建通过、Local Test 全部通过、CodeLinter 0 error、可用模拟器权限/失败恢复检查通过。
- 不得降低最终验收标准，不得引入云端 OCR、网络权限、账号、密钥、付费服务、图片/候选持久化或超出基础四则的语法。
- 后续 APPLYING 若未发现设计偏差，应只复验证据；只有失败测试或可追溯审计证明存在偏差时才修改产品源，并按 RED → GREEN → REFACTOR 执行。

## 任务列表

### 阶段 1：基线、契约与平台边界

#### Task 1.1: 锁定精确 PR 基线与规划追溯

**描述**：在执行任何验证前确认工作树、PR #48 head、Developer evidence 与六项 Planning 制品指向同一 SHA，并建立 R1–R6、SR-00–SR-02 到后续任务的追溯表；发现 SHA 或制品矛盾时停止后续任务并报告。

**涉及文件**：
- 输入：`specs/changes/20261023-requirement-add-handwriting-ocr/proposal.md`
- 输入：`specs/changes/20261023-requirement-add-handwriting-ocr/delta-spec.md`
- 输入：`specs/changes/20261023-requirement-add-handwriting-ocr/delta-design.md`
- 输入：`specs/changes/20261023-requirement-add-handwriting-ocr/info.md`
- 输入：`specs/changes/20261023-requirement-add-handwriting-ocr/design-review.md`
- 证据：`D:\\huawei\\Demo\\calculatorHuawei\\.agent-runtime\\evidence\\task-23\\run-61.json`

**依赖任务**：无

**验收标准**：
- `git rev-parse HEAD`、PR head 与 evidence head 均为 `19f7c3d146dc30574738dd2187dd99ec6877610d`。
- 六项 Planning 制品齐全，且 OCR 路线、字符范围、确认语义、Developer 门禁和 Tester 风险不存在冲突。
- 追溯覆盖 IR-046-R1–R6、SR-00–SR-02 和 SC-001–SC-005。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（复核上游失败证据、57/57 回归与无产品改动重构结论）

#### Task 1.2: 复核识别领域模型与平台端口契约

**描述**：用现有单测验证识别状态、会话快照、权限/拍照/OCR 联合结果、错误枚举及 gateway/provider 边界；只有测试暴露设计偏差时才补强模型或测试。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/model/RecognitionModels.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/platform/CameraPermissionGateway.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/platform/CaptureGateway.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/platform/HandwritingOcrProvider.ets`
- 测试：`opencalc/entry/src/test/Recognition.test.ets`

**依赖任务**：Task 1.1

**验收标准**：
- 状态和结果类型覆盖权限请求、拍摄、识别、有效/无效复核、错误和取消路径。
- 平台错误映射为稳定领域结果，原始 OCR 字符串不能绕过有效确认结果。
- 模型不包含照片或候选持久化契约。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（复核上游失败证据、57/57 回归与无产品改动重构结论）

#### Task 1.3: 复核 CAMERA 配置与端侧平台适配器

**描述**：验证 CAMERA 最小权限声明、资源化文案、权限状态映射、系统相机 picker、CoreVisionKit/ImageKit 端侧 OCR 及资源释放；禁止增加网络或云端回退。

**涉及文件**：
- 实现：`opencalc/entry/src/main/module.json5`
- 实现：`opencalc/entry/src/main/resources/base/element/string.json`
- 实现：`opencalc/entry/src/main/ets/recognition/platform/HarmonyCameraPermissionGateway.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/platform/HarmonyCaptureGateway.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/platform/OnDeviceHandwritingOcrProvider.ets`
- 测试：`opencalc/entry/src/test/Recognition.test.ets`

**依赖任务**：Task 1.2

**验收标准**：
- manifest 仅声明所需 CAMERA 权限，reason/usedScene 可由 API 12 构建解析。
- granted、denied、permanentlyDenied、拍照取消和平台错误均有确定性结果，非 granted 不启动拍照。
- OCR 路径无网络、账号、密钥或远端 URL；图片解码资源在成功和失败路径均释放。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（复核上游失败证据、API 12 构建与无产品改动重构结论）

### 阶段 2：安全验证与会话编排

#### Task 2.1: 复核表达式归一化、白名单和严格 grammar

**描述**：以表驱动测试验证 128 code unit 长度门禁、确定性符号映射、字符白名单、token、括号和基础四则完整语法；验证器必须保持 O(n) 且无求值副作用。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/service/ExpressionValidator.ets`
- 测试：`opencalc/entry/src/test/Recognition.test.ets`

**依赖任务**：Task 1.2

**验收标准**：
- `12 + 3 × 4`、小数和嵌套括号返回规范化有效结果。
- 空文本、129 code unit、未知字符、函数/变量、隐式乘法、错误小数和不平衡括号均被拒绝。
- recognition 模块不导入或调用 `CalcEngine.evaluate`，不依赖宽松括号自动补全。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（复核 grammar RED、57/57 GREEN 与无产品改动重构结论）

#### Task 2.2: 复核会话启动、权限与拍摄状态流

**描述**：验证 coordinator 在 start 时保存原表达式、生成会话身份、执行权限门禁并调度拍摄，所有可观察状态来自单一枚举快照。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/service/RecognitionCoordinator.ets`
- 测试：`opencalc/entry/src/test/Recognition.test.ets`

**依赖任务**：Task 1.3、Task 2.1

**验收标准**：
- start 不修改原表达式，授权后才进入拍摄；拒绝和永久拒绝绝不调用 capture。
- 连续会话具有不同身份，状态转换不存在由多个布尔量组合出的非法中间态。
- 权限和拍摄失败均进入可关闭或重试状态且不崩溃。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（复核权限状态 RED、57/57 GREEN 与无产品改动重构结论）

#### Task 2.3: 复核 OCR、超时、编辑与确认门禁

**描述**：验证 OCR 成功/空/失败/5 秒超时的收敛逻辑、候选编辑实时校验和确认时二次校验；成功确认只产生规范化表达式。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/service/RecognitionCoordinator.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/service/ExpressionValidator.ets`
- 测试：`opencalc/entry/src/test/Recognition.test.ets`

**依赖任务**：Task 2.2

**验收标准**：
- 有效/无效候选分别进入正确复核状态，空结果、失败和超时均可恢复。
- 编辑可在 valid/invalid 间切换；无效或陈旧状态的 confirm 被拒绝。
- 成功确认只返回规范化表达式，不求值、不写历史、不持久化候选。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（复核候选/超时 RED、57/57 GREEN 与无产品改动重构结论）

#### Task 2.4: 复核取消、重拍、迟到回调与生命周期清理

**描述**：验证关闭/取消、失败后重拍、会话替换、迟到 Promise 和组件销毁路径，确保旧会话不能污染当前视图或表达式。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/service/RecognitionCoordinator.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/platform/OnDeviceHandwritingOcrProvider.ets`
- 测试：`opencalc/entry/src/test/Recognition.test.ets`

**依赖任务**：Task 2.3

**验收标准**：
- 取消、关闭、失败、重拍和生命周期终止均不提交表达式并释放当前资源。
- 会话 A 取消后迟到的回调不能修改会话 B 的状态、候选或原值。
- retry 清除旧候选/错误并重新进入拍摄，同时保留进入流程前的原表达式。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（复核取消/迟到回调 RED、57/57 GREEN 与无产品改动重构结论）

### 阶段 3：界面与计算器集成

#### Task 3.1: 复核 RecognitionPanel 状态与恢复交互

**描述**：验证识别面板对权限、处理中、有效/无效候选和错误状态的渲染，以及编辑、确认、重拍、设置引导、取消等动作；UI 只消费 view state 并发出意图。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/view/RecognitionPanel.ets`
- 实现：`opencalc/entry/src/main/resources/base/element/string.json`
- 测试：`opencalc/entry/src/test/Recognition.test.ets`

**依赖任务**：Task 2.3、Task 2.4

**验收标准**：
- 无效、空和超长候选显示明确提示且确认不可用，编辑有效后才可确认。
- 拒绝/永久拒绝、相机失败、OCR 失败和超时具有区分文案及安全退出/重试动作。
- 面板不导入或调用 `CalcEngine`，不显示敏感图片路径或记录完整候选。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（复核面板恢复 RED、57/57 GREEN 与无产品改动重构结论）

#### Task 3.2: 复核 CalculatorPage 入口与唯一提交点

**描述**：验证计算器拍照入口、面板挂载和确认回调；显式有效确认后以规范化候选替换 expression，其他路径保持 expression、result 和历史不变。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/view/RecognitionPanel.ets`
- 测试：`opencalc/entry/src/test/Recognition.test.ets`
- 测试入口：`opencalc/entry/src/test/List.test.ets`

**依赖任务**：Task 3.1

**验收标准**：
- 打开、拒绝、取消、失败、非法、超时和重拍均不覆盖原表达式。
- 有效确认只替换 expression，不追加、不调用 `onEquals`/`CalcEngine.evaluate`、不新增历史。
- 既有数字输入、等号、设置、关于和绘图覆盖层行为无回归。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（复核唯一提交点 RED、57/57 GREEN 与无产品改动重构结论）

### 阶段 4：Developer 门禁与 Tester 移交

#### Task 4.1: 执行完整 Local Test 与安全静态审计

**描述**：执行 entry Local Test，确认所有识别测试被 `List.test.ets` 收集，并静态审计 recognition 目录不存在求值直连、云端回退、图片/候选持久化或敏感日志。

**涉及文件**：
- 测试：`opencalc/entry/src/test/List.test.ets`
- 测试：`opencalc/entry/src/test/Recognition.test.ets`
- 审计：`opencalc/entry/src/main/ets/recognition/`

**依赖任务**：Task 3.2

**验收标准**：
- Local Test 全部通过，基线为 57/57；若测试总数变化，必须说明原因且不得减少规格覆盖。
- SC-001–SC-005 的权限、成功、失败、编辑确认、超时、重试和迟到回调路径均有断言。
- 静态审计未发现 `evaluate` 直连、网络/凭据、持久化照片/候选或敏感完整文本日志。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（测试收集先因缺少 Hypium 依赖为环境 RED，恢复声明依赖后 57/57 GREEN，产品代码保持不变）

#### Task 4.2: 执行 API 12 构建与 CodeLinter 门禁

**描述**：在精确 head 上执行 entry API 12 HAP 构建和项目 CodeLinter，区分既有 warning 与新增 error；任何构建失败或 lint error 均为 Developer blocker。

**涉及文件**：
- 构建配置：`opencalc/build-profile.json5`
- 模块配置：`opencalc/entry/src/main/module.json5`
- Lint 配置：`opencalc/code-linter.json5`

**依赖任务**：Task 4.1

**验收标准**：
- API 12 entry HAP 构建成功，CameraKit/CoreVisionKit/ImageKit 符号可解析。
- CodeLinter 为 0 error；既有 warning 数量和性质被记录，不冒充本次新增缺陷。
- `git diff --check` 通过，验证过程未生成未说明的产品变更。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（构建/lint 门禁复核通过；无失败规格，因此不修改产品代码）

#### Task 4.3: 执行可用模拟器检查并形成 Tester 风险快照

**描述**：在当前可用模拟器上复核安装启动、首次拒绝、永久拒绝、相机不可用/失败恢复及原输入保护；随后记录精确 head、命令、日志、Developer 门禁结论和 Tester 下游风险。

**涉及文件**：
- 实现核对：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 实现核对：`opencalc/entry/src/main/ets/recognition/view/RecognitionPanel.ets`
- 报告：`specs/changes/20261023-requirement-add-handwriting-ocr/apply-report.md`

**依赖任务**：Task 4.2

**验收标准**：
- HAP 可安装启动；权限拒绝/永久拒绝和相机失败均显示可恢复提示，应用无 fatal，原表达式不变。
- build、Local Test、lint 和可用模拟器检查通过时结论为 `ready_for_test`，不得因缺少物理设备或数据集标记 Developer blocked。
- 风险快照明确移交：真实拍摄/CoreVisionKit 手写成功、100 图/至少 5 名书写者准确率 ≥90%、P95 ≤2 秒、5 秒真实超时、飞行模式和持久文件隐私扫描；最终验收标准不降低。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（模拟器拒绝/永久拒绝/相机失败恢复复核通过；真实硬件项移交 Tester）

## 依赖关系与关键路径

- 关键路径：Task 1.1 → Task 1.2 → Task 1.3 → Task 2.2 → Task 2.3 → Task 2.4 → Task 3.1 → Task 3.2 → Task 4.1 → Task 4.2 → Task 4.3。
- 可并行项：Task 2.1 可在 Task 1.3 平台复核期间独立执行；Task 3.1 的静态 UI 契约审查可与 Task 2.4 的生命周期测试准备并行。
- 安全门禁：Task 2.1 和 Task 2.3 完成前，不得认可 CalculatorPage 的确认提交点。
- Developer 阻塞条件：精确 head 不一致、Planning 制品冲突、Local Test 失败、API 12 构建失败、CodeLinter error 或可用模拟器恢复路径失败。
- Tester 风险不是 Developer 阻塞：物理设备、真实手写数据集、准确率、P95、飞行模式和持久文件扫描缺失时，按 Task 4.3 移交并保持最终验收待完成。

## 开发顺序

```text
Task 1.1 → Task 1.2
  → { Task 1.3 ∥ Task 2.1 }
  → Task 2.2 → Task 2.3 → Task 2.4
  → Task 3.1 → Task 3.2
  → Task 4.1 → Task 4.2 → Task 4.3
  → ready_for_test
```

## 验收计划

| 任务 | 主要验收方式 | 追溯需求 |
|------|--------------|----------|
| Task 1.1 | SHA/evidence/Planning 制品一致性审计 | R1–R6、SR-00–02 |
| Task 1.2–1.3 | 契约单测、配置审计、API 12 平台边界审计 | R1、R2、R5 |
| Task 2.1 | 表驱动、边界和 grammar 单测；无 evaluate 调用审计 | R4、A-04 |
| Task 2.2–2.4 | 状态机、超时、竞态、原值保护和资源生命周期单测 | R1、R2、R5 |
| Task 3.1–3.2 | 面板状态、恢复交互和 CalculatorPage 集成测试 | R1、R3、R4、R5 |
| Task 4.1 | 57/57 Local Test 与安全静态审计 | SC-001–SC-005 |
| Task 4.2 | API 12 HAP build、CodeLinter 0 error、diff check | Developer 门禁 |
| Task 4.3 | 模拟器恢复场景与可追溯 Tester 风险快照 | R1–R6、A-02/A-05 |

## 后续 APPLYING 约束

- 每个发现实现偏差的任务必须先补失败测试，再最小修复并重构；本 IMPLEMENTING 阶段不执行测试或修改产品源。
- 如果现有实现已满足任务验收标准，仅记录复验证据，不为制造代码变更而重写实现。
- 未获得新的明确授权前，不得扩展权限、数据留存、语法或外部服务范围。
- APPLYING 是否开始由 workflow command 阶段闸门决定，本文件完成不代表已执行任何任务。
