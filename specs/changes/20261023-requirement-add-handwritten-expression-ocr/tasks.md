# 拍照识别手写算式并自动填入开发任务

## 任务概述

- 功能名称：拍照识别手写算式并自动填入
- 变更类型：新增功能
- 关联 Issue：calculatorHuawei/agent_workflow#46
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 规划输入：`proposal.md` / `delta-spec.md` / `new-arch.md` / `delta-design.md` / `info.md` / `design-review.md`
- 开发阶段：IMPLEMENTING 任务分解（后续 APPLYING 按 TDD 执行）
- 预计任务数：20
- 单任务目标工时：1–2 小时

## 任务列表

### 阶段 1：平台能力与基础契约

#### Task 1.1: 完成 API 12 相机与端侧 OCR 最小编译探针

**描述**：用目标 API 12 SDK 验证 CAMERA 权限查询/申请、单次拍照、设置跳转和端侧离线 OCR 的真实 API、类型、依赖与设备约束，记录选型及清理临时代码；若没有兼容的端侧方案，停止后续实现并按设计报告阻塞，不得切换云端。
**涉及文件**：
- 实现：`opencalc/entry/src/main/module.json5`、`opencalc/oh-package.json5`、`opencalc/entry/oh-package.json5`（仅在探针确认需要时修改）
- 记录：`specs/changes/20261023-requirement-add-handwritten-expression-ocr/api12-capability-probe.md`
- 验证：`opencalc/entry/src/main/ets/recognition/platform/`（临时探针不得残留无用代码）
**依赖任务**：无
**验收标准**：
- `hvigorw --mode module -p module=entry@default assembleHap` 对选定 API/依赖编译通过，并记录 SDK、符号、版本和设备限制。
- 证明 OCR 路径端侧离线且无网络、账号、密钥或付费服务；不满足时形成明确阻塞记录。
- 临时探针已删除或转化为后续正式 adapter，不污染产品入口。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 1.2: 定义识别领域模型与平台端口契约

**描述**：定义状态、会话快照、权限/拍照/OCR 联合结果、验证结果、错误枚举和强类型确认结果，建立 gateway/provider 接口，确保预期错误不依赖异常且原始字符串不能绕过有效确认类型。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/model/RecognitionModels.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/platform/CameraPermissionGateway.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/platform/CaptureGateway.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/platform/HandwritingOcrProvider.ets`
- 测试：`opencalc/entry/src/test/RecognitionModels.test.ets`
**依赖任务**：Task 1.1
**验收标准**：
- 状态覆盖 IDLE、REQUESTING_PERMISSION、CAPTURING、RECOGNIZING、REVIEWING_VALID、REVIEWING_INVALID、ERROR。
- 权限区分 granted、denied、permanentlyDenied；拍照和 OCR 区分成功、取消、空结果、失败。
- 模型中无照片/候选持久化字段，确认结果只能携带已验证的规范化文本。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 1.3: 配置 CAMERA 权限与权限文案资源

**描述**：按 Task 1.1 核验结果增加最小 CAMERA user_grant 声明、资源化 reason/usedScene 和用户可理解的拒绝/永久拒绝文案，不增加无关权限。
**涉及文件**：
- 实现：`opencalc/entry/src/main/module.json5`
- 实现：`opencalc/entry/src/main/resources/base/element/string.json`
- 测试：`opencalc/entry/src/test/CameraPermissionConfig.test.ets`
**依赖任务**：Task 1.1、Task 1.2
**验收标准**：
- manifest 仅新增实现拍照所需的 CAMERA 权限且 reason/usedScene 可被构建解析。
- 自动检查能发现权限名、资源引用或 usedScene 缺失。
- entry HAP 构建通过，无网络权限或其他范围扩张。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 1.4: 实现相机权限与设置引导 adapter

**描述**：实现权限状态查询、首次请求、拒绝和永久拒绝映射，以及可用时的系统设置跳转；平台错误只映射为稳定领域结果。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/platform/HarmonyCameraPermissionGateway.ets`
- 测试：`opencalc/entry/src/test/HarmonyCameraPermissionGateway.test.ets`
**依赖任务**：Task 1.2、Task 1.3
**验收标准**：
- granted 不重复申请；denied 可恢复；permanentlyDenied 不循环弹权限框并暴露设置动作。
- 权限 API 异常被映射为领域错误且不触发拍照。
- 测试替身覆盖授权、拒绝、永久拒绝和设置入口不可用四类结果。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 1.5: 实现单次拍照与端侧 OCR adapter

**描述**：按已验证 API 实现单次拍照结果映射、图片临时句柄释放和端侧离线 OCR provider；adapter 不持久化图片、不上传、不记录完整候选。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/platform/HarmonyCaptureGateway.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/platform/OnDeviceHandwritingOcrProvider.ets`
- 测试：`opencalc/entry/src/test/RecognitionPlatformAdapters.test.ets`
**依赖任务**：Task 1.1、Task 1.2、Task 1.4
**验收标准**：
- 拍照成功、用户取消和平台错误均返回明确联合结果。
- OCR 在断网条件可运行，且代码/配置中不存在云端 URL、凭据或网络回退。
- 成功、失败、取消与会话关闭均释放图片/相机会话资源，测试可观察释放调用。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

### 阶段 2：安全验证与识别编排

#### Task 2.1: 实现候选归一化、字符白名单和长度门禁

**描述**：先实现表驱动测试，再实现空白清理、`×/x/X→*`、`÷→/`、Unicode 减号→`-` 的确定性映射、字符白名单和 128 code unit 上限。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/service/ExpressionValidator.ets`
- 测试：`opencalc/entry/src/test/ExpressionValidatorNormalization.test.ets`
**依赖任务**：Task 1.2
**验收标准**：
- 允许数字、小数点、二元四则和圆括号；拒绝变量、函数、常量、多行及其余字符。
- 127/128 code unit 可继续语法校验，129 code unit 返回稳定超限错误。
- 空文本、仅空白和未授权 Unicode 字符返回可定位的无效结果。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 2.2: 实现严格基础四则 tokenizer 与 grammar

**描述**：在归一化之后实现 O(n) token、括号栈和操作数/运算符状态机，拒绝隐式乘法、错误小数、空括号、连续运算符和不平衡括号，不调用既有宽松自动补全逻辑。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/service/ExpressionValidator.ets`
- 测试：`opencalc/entry/src/test/ExpressionValidatorGrammar.test.ets`
**依赖任务**：Task 2.1
**验收标准**：
- `12 + 3 × 4`、带小数和嵌套括号的合法样例通过并返回规范化文本。
- 隐式乘法、函数/变量、括号不平衡、缺失操作数和多个小数点均失败。
- 验证器无副作用，测试证明不会调用 `Expression.addParenthesis` 或 `CalcEngine.evaluate`。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 2.3: 实现会话启动、权限与拍照状态流

**描述**：实现 coordinator 的 start 流程、原表达式快照、单调 session id、权限门禁和拍照调度，使用单一状态枚举输出视图快照。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/service/RecognitionCoordinator.ets`
- 测试：`opencalc/entry/src/test/RecognitionCoordinatorStart.test.ets`
**依赖任务**：Task 1.2、Task 1.4、Task 1.5
**验收标准**：
- start 不修改原表达式，状态按 IDLE → REQUESTING_PERMISSION → CAPTURING 转换。
- 非 granted 状态绝不调用 capture，并生成对应可恢复错误快照。
- 连续启动产生不同 session id，且不存在由多个布尔组合出的不可达 UI 状态。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 2.4: 实现 OCR 编排、空结果和 5 秒超时

**描述**：把当前会话图片交给 provider，在 coordinator 层施加可测试的 5 秒超时，将成功、空结果、provider 错误和超时收敛到明确状态。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/service/RecognitionCoordinator.ets`
- 测试：`opencalc/entry/src/test/RecognitionCoordinatorOcr.test.ets`
**依赖任务**：Task 2.2、Task 2.3
**验收标准**：
- 有效结果进入 REVIEWING_VALID；无效结果进入 REVIEWING_INVALID；空结果/失败/超时提供重拍或关闭动作。
- 使用可控时钟测试 4999 ms 与 5000 ms 边界，不依赖真实等待。
- 每个结果分支都保持 originalExpression 不变并结束处理中状态。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 2.5: 实现候选编辑和二次确认门禁

**描述**：实现 updateCandidate 的实时校验和 confirm 的二次校验，只有当前会话 REVIEWING_VALID 的强类型成功结果才能提交规范化表达式。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/service/RecognitionCoordinator.ets`
- 测试：`opencalc/entry/src/test/RecognitionCoordinatorConfirm.test.ets`
**依赖任务**：Task 2.2、Task 2.4
**验收标准**：
- 编辑在 valid/invalid 状态间确定性切换，非法候选的 confirm 返回拒绝。
- confirm 会再次校验，防止陈旧 UI 状态或裸字符串绕过门禁。
- 成功确认只返回规范化表达式，不调用求值、写历史或持久化候选。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 2.6: 实现取消、重拍、迟到回调隔离和资源清理

**描述**：覆盖任意非 IDLE 状态的关闭/取消、ERROR/REVIEWING 的重拍、Ability 后台/组件销毁清理，并用 session id 丢弃旧异步结果。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/service/RecognitionCoordinator.ets`
- 测试：`opencalc/entry/src/test/RecognitionCoordinatorLifecycle.test.ets`
**依赖任务**：Task 2.4、Task 2.5
**验收标准**：
- 取消、关闭、失败、重拍和生命周期终止均不提交表达式并释放当前资源。
- 会话 A 取消后即使迟到，不能改变会话 B 的状态、候选或原值。
- retry 清除旧候选/错误并回到拍摄流程，同时保留最初原表达式快照。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

### 阶段 3：确认界面与计算器集成

#### Task 3.1: 建立 RecognitionPanel 状态渲染骨架

**描述**：新增独立覆盖层组件，渲染权限请求、拍摄、识别中、有效/无效预览和错误状态；组件只消费视图快照并发出用户意图。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/view/RecognitionPanel.ets`
- 测试：`opencalc/entry/src/test/RecognitionPanelState.test.ets`
**依赖任务**：Task 1.2、Task 2.4
**验收标准**：
- 每个领域状态具有确定的标题、说明和动作集合，不暴露平台错误码。
- 处理中状态不会显示可确认按钮，所有非 IDLE 状态均有安全退出路径。
- UI 组件不 import 或调用 `CalcEngine`。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 3.2: 实现候选编辑、校验提示、确认与重拍交互

**描述**：接入可编辑候选、实时错误提示、确认禁用规则、重拍/取消/确认动作，并防止原始 OCR 文本绕过 coordinator。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/view/RecognitionPanel.ets`
- 测试：`opencalc/entry/src/test/RecognitionPanelReview.test.ets`
**依赖任务**：Task 2.5、Task 2.6、Task 3.1
**验收标准**：
- 无效/空/超长候选显示明确提示且确认不可用；编辑有效后才启用确认。
- 重拍清除候选但不改变 CalculatorPage 原输入，取消关闭面板。
- 确认事件只传递 coordinator 返回的已验证成功结果。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 3.3: 实现权限拒绝、失败与设置恢复界面

**描述**：为可再次申请、永久拒绝、相机失败、OCR 空/失败/超时提供区分文案和可执行恢复动作，设置跳转不可用时仍能关闭继续手工输入。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/view/RecognitionPanel.ets`
- 实现：`opencalc/entry/src/main/resources/base/element/string.json`
- 测试：`opencalc/entry/src/test/RecognitionPanelRecovery.test.ets`
**依赖任务**：Task 1.4、Task 2.6、Task 3.1
**验收标准**：
- 拒绝与永久拒绝动作不同，永久拒绝不触发循环申请。
- 空结果、失败和超时均可重拍；设置入口失败仍可退出且应用不崩溃。
- 错误说明不记录或显示隐私敏感的完整照片路径/候选日志。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 3.4: 集成 CalculatorPage 拍照入口与唯一提交点

**描述**：在现有页面加入可访问的拍照识别入口、面板挂载、coordinator 生命周期和有效确认回调；确认后以规范化候选替换 expression，仅清理适当错误展示，不求值、不写历史。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 实现：`opencalc/entry/src/main/ets/recognition/view/RecognitionPanel.ets`
- 测试：`opencalc/entry/src/test/CalculatorRecognitionIntegration.test.ets`
**依赖任务**：Task 3.2、Task 3.3
**验收标准**：
- 打开、拒绝、取消、失败、非法、重拍均保持打开前 expression、result 和历史不变。
- 有效显式确认后替换 expression，不追加，且 `onEquals`/`CalcEngine.evaluate` 未被调用。
- 原按钮输入、设置、关于和绘图覆盖层行为不回归。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 3.5: 完成主题、横竖屏、无障碍与生命周期适配

**描述**：复用现有三主题和面板间距，保证 phone/tablet 横竖屏动作可见/可滚动，为入口和动作补齐可访问文本，并在页面后台或销毁时取消会话。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/recognition/view/RecognitionPanel.ets`
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 实现：`opencalc/entry/src/main/resources/base/element/string.json`
- 测试：`opencalc/entry/src/test/RecognitionPanelAccessibility.test.ets`
**依赖任务**：Task 3.4
**验收标准**：
- 浅色、暗色、AMOLED 主题均复用既有颜色函数，无新增不受控硬编码主题。
- phone/tablet 横竖屏下关闭、重拍和确认动作可达，入口/图标具有 accessibilityText。
- 页面后台/销毁后相机和 OCR 被取消释放，迟到结果不更新 UI。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

### 阶段 4：端到端验收与质量门禁

#### Task 4.1: 补齐 fake gateway/provider 集成场景测试

**描述**：使用 fake 权限、拍照、OCR、时钟和提交 spy 串联 coordinator、panel 与 CalculatorPage，覆盖规格 SC-001 至 SC-005 的主路径和异常矩阵。
**涉及文件**：
- 测试：`opencalc/entry/src/test/RecognitionFlowIntegration.test.ets`
- 测试：`opencalc/entry/src/test/List.test.ets`
**依赖任务**：Task 2.6、Task 3.5
**验收标准**：
- 覆盖授权拍摄成功、拒绝/永久拒绝、取消、空结果、非法字符、编辑确认、失败重拍、超时和迟到回调。
- 每个非成功确认分支断言原 expression、result、历史不变。
- 每个非法输入分支断言 evaluate 调用次数为 0。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 4.2: 增加真机权限、拍照与确认 UI 测试

**描述**：建立 ohosTest 用例和可复验步骤，覆盖首次授权、拒绝/永久拒绝、完成拍摄、识别失败重拍、候选编辑及确认填入。
**涉及文件**：
- 测试：`opencalc/entry/src/ohosTest/ets/test/RecognitionFlow.test.ets`
- 测试：`opencalc/entry/src/ohosTest/ets/test/List.test.ets`
- 配置：`opencalc/entry/src/ohosTest/module.json5`
**依赖任务**：Task 1.5、Task 3.5、Task 4.1
**验收标准**：
- 支持设备上能从计算器进入拍照并完成一次拍摄，失败时可重拍且不崩溃。
- 确认前候选可查看编辑，确认后只填入；拒绝/失败不覆盖原输入。
- 测试记录设备、系统版本、权限前置状态和截图/日志证据，且日志不包含照片或完整候选。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 4.3: 建立固定 OCR 数据集准确率门禁

**描述**：固化至少 100 张、至少 5 名书写者、仅含首期字符集的清晰单行算式及真值清单，编写离线批量测试并按规范化完全匹配计算准确率。
**涉及文件**：
- 数据：`opencalc/entry/src/ohosTest/resources/rawfile/ocr_dataset/`
- 真值：`opencalc/entry/src/ohosTest/resources/rawfile/ocr_dataset/ground-truth.json`
- 测试：`opencalc/entry/src/ohosTest/ets/test/OcrAccuracy.test.ets`
- 报告：`specs/changes/20261023-requirement-add-handwritten-expression-ocr/ocr-quality-report.md`
**依赖任务**：Task 1.5、Task 2.2、Task 4.2
**验收标准**：
- 数据集数量、书写者分布、字符范围、真值和许可/来源可审计且固定版本。
- 断网条件下规范化表达式完全匹配率 ≥90%，报告列出失败样例编号但不包含用户隐私。
- 未达门禁时测试失败且不得通过放宽 grammar 或改用云端规避。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 4.4: 执行性能、离线、隐私与全量回归门禁

**描述**：在参考支持设备统计拍照确认到候选展示耗时，验证 P95、5 秒超时、断网可用、资源释放和无持久化，并运行单测、lint/类型检查与 HAP 构建。
**涉及文件**：
- 测试：`opencalc/entry/src/ohosTest/ets/test/OcrPerformancePrivacy.test.ets`
- 报告：`specs/changes/20261023-requirement-add-handwritten-expression-ocr/ocr-quality-report.md`
- 配置：`opencalc/entry/src/main/module.json5`、`opencalc/oh-package.json5`、`opencalc/entry/oh-package.json5`
**依赖任务**：Task 4.1、Task 4.2、Task 4.3
**验收标准**：
- 参考设备上 P95 ≤2 秒，单次超过 5 秒稳定进入可重拍超时态；报告包含样本数、设备和系统版本。
- 飞行模式/断网可完成拍照、识别、编辑和确认；照片/候选不进入 Preferences、历史、普通日志或应用持久文件。
- `hvigorw --mode module -p module=entry@default test`、项目约定 lint/类型检查和 HAP 构建全部通过，既有计算、设置、历史和绘图测试无回归。
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

## 依赖关系与关键路径

- 关键路径：Task 1.1 → Task 1.2 → Task 1.4 → Task 1.5 → Task 2.3 → Task 2.4 → Task 2.5 → Task 2.6 → Task 3.1 → Task 3.2 → Task 3.4 → Task 3.5 → Task 4.1 → Task 4.2 → Task 4.3 → Task 4.4。
- 可并行项：Task 1.3 可在 Task 1.2 后与 Task 1.4 并行；Task 2.1/2.2 可在平台 adapter 工作期间独立推进；Task 3.3 可与 Task 3.2 并行。
- 强制门禁：Task 1.1 若确认 API 12 无兼容端侧离线 OCR，立即阻塞，不执行后续任务，不引入云端回退。
- 安全门禁：Task 2.2 和 Task 2.5 完成前不得接入 CalculatorPage 提交点。
- 质量门禁：Task 4.3/4.4 未达到准确率、时延、离线与隐私目标时不得判定 APPLYING 完成。

## 开发顺序

```text
Task 1.1
  → Task 1.2
  → { Task 1.3 ∥ Task 1.4 ∥ Task 2.1 }
  → { Task 1.5 ∥ Task 2.2 }
  → Task 2.3 → Task 2.4 → Task 2.5 → Task 2.6
  → Task 3.1
  → { Task 3.2 ∥ Task 3.3 }
  → Task 3.4 → Task 3.5
  → Task 4.1 → Task 4.2 → Task 4.3 → Task 4.4
  → 完成
```

## 验收计划

| 任务 | 主要验收方式 | 追溯需求 |
|------|--------------|----------|
| Task 1.1 | API 12 编译探针、依赖与离线边界审查 | A-01、P-01 |
| Task 1.2–1.5 | 契约单测、adapter 单测、HAP 构建、真机能力验证 | R1、R2、R5 |
| Task 2.1–2.2 | 表驱动/边界/语法单测、无 evaluate 调用审计 | R4、A-04 |
| Task 2.3–2.6 | 状态机、超时、竞态、原值保护和资源生命周期单测 | R2、R5 |
| Task 3.1–3.5 | 组件测试、集成测试、主题/响应式/无障碍检查 | R1、R3、R5 |
| Task 4.1 | fake 端到端异常矩阵 | SC-001–SC-005 |
| Task 4.2 | 真机权限/拍摄/UI 测试 | R1、R2、R3、R5 |
| Task 4.3 | 固定 100 图集完全匹配率 ≥90% | R6、A-02 |
| Task 4.4 | P95 ≤2 s、5 s 超时、断网、隐私、全量回归 | R4、R6 |

## APPLYING 执行约束

- 每个任务按 RED → GREEN → REFACTOR 执行，并在本文件勾选对应 TDD 状态；本 IMPLEMENTING 阶段不执行这些任务。
- 只允许在有效显式确认点替换 `CalculatorPage.expression`，不得自动调用 `onEquals()` 或 `CalcEngine.evaluate`。
- 不得新增云端 OCR、网络权限、账号、密钥、付费服务、图片/候选持久化或超出基础四则的语法。
- Task 1.1 的平台结论若与设计假设冲突，先报告阻塞并回到设计审视，不得静默扩大范围。
