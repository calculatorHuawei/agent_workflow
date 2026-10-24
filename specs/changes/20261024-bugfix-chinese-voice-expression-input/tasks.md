# 中文语音输入算式并自动计算开发任务

## 任务概述

- 功能名称：中文语音输入算式并自动计算
- 变更类型：`bugfix`（编排分类；产品语义为新增功能）
- 关联 Issue：#52
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 规划依据：`proposal.md` / `delta-spec.md` / `acceptance-criteria.json` / `info.md` / `new-arch.md` / `delta-design.md` / `design-review.md`
- 开发阶段：后续 APPLYING 阶段按 TDD 执行；本文只定义任务，不代表任何 AC 已完成
- 预计任务数：12

## 实施约束

- 每个实现任务在 APPLYING 阶段按 RED → GREEN → REFACTOR 执行，先形成失败测试或可观察失败证据，再写最小实现。
- 只接受当前 session 的最终识别结果；取消、失败、重复 final 和迟到回调不得产生计算或历史副作用。
- 语音与手动输入必须共用候选计算、格式化和历史提交逻辑；不得复制计算引擎。
- 音频和原始识别文本不得持久化或写入日志；只申请前台 `MICROPHONE` 与在线识别所需 `INTERNET`。
- UI/E2E/真机条件由 Tester 验证；Developer 的 unit/integration 结果不能替代 AC-015 的真机证据。

## 任务列表

### 阶段 1：领域契约与确定性解析

#### Task 1.1: 建立语音领域模型、端口与可注入测试替身

**描述**：定义 voice state、gateway event/error、parse result、calculation outcome 与 gateway/parser/callback 端口；在测试侧提供可记录启动次数、事件顺序、取消和迟到回调的 fake gateway，确保生产装配不引用 fake。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/voice/VoiceModels.ets`
- 实现：`opencalc/entry/src/main/ets/voice/SpeechRecognitionGateway.ets`
- 测试：`opencalc/entry/src/test/FakeSpeechRecognitionGateway.ets`
- 测试入口：`opencalc/entry/src/test/List.test.ets`

**依赖任务**：无

**验收标准**：
- 端口不暴露 ArkUI 或 CoreSpeechKit 具体类型，事件均携带 sessionId。
- fake 可注入 listening、recognizing、partial、final、empty、service error、recording interruption 和 delayed final，并记录 active session/cancel/dispose 次数。
- 测试装配与生产默认装配可分离，缺少麦克风和在线服务时仍可运行确定性测试。

**需求追溯**：IR-001、IR-006、IR-007、IR-009 → AC-001、AC-010～AC-012、AC-014、AC-017

**Developer 验证**：unit 编译与 fake contract 测试；oracle 为事件类型、sessionId、计数和调用顺序与注入脚本完全一致。

**Tester 验证请求**：在无麦克风环境确认 fake 能驱动全部 AC-014 outcomes，且自动化不因平台能力缺失而跳过。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.2: 实现中文数字与小数解析

**描述**：实现零/〇、一至九、两、十/百/千/万、无单位逐位数字、阿拉伯数字、一元负号和逐位小数解析；对亿、分数、单位量词、单位进入小数部分、多小数点和“一百二”等省略读法 fail-closed。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/voice/ChineseNumberParser.ets`
- 测试：`opencalc/entry/src/test/ChineseNumberParser.test.ets`
- 测试入口：`opencalc/entry/src/test/List.test.ets`

**依赖任务**：Task 1.1

**验收标准**：
- `123`、`二十`、`一百零二`、`两`、`二〇二四`、`负二`、`十点五`、`零点零五`、`一点九五` 得到精确数值文本。
- 所有非法/歧义边界返回结构化错误，不抛出用户输入异常，不产生猜测结果。
- 解析为纯同步确定性逻辑，无 Kit、UI、网络或持久化依赖。

**需求追溯**：IR-004、IR-006 → AC-004～AC-006、AC-018

**Developer 验证**：表驱动 unit 测试；oracle 包含 `20`、`102`、`2024`、`-2`、`10.5`、`0.05`、`1.95` 及非法集合的精确结果/错误码。

**Tester 验证请求**：通过注入识别文本复核中文整数、小数、负数和歧义输入的 UI 结果；不得依赖真实语音服务。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.3: 实现严格二元语音表达式规范化

**描述**：完成有限标点/空白清理、八种运算词/符号映射、单个二元运算结构和操作数一元负号判定；只输出 ASCII `+ - * /`，要求完整消费输入。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/voice/VoiceExpressionParser.ets`
- 测试：`opencalc/entry/src/test/VoiceExpressionParser.test.ets`
- 测试入口：`opencalc/entry/src/test/List.test.ets`

**依赖任务**：Task 1.1、Task 1.2

**验收标准**：
- 八种运算符映射表与 AC-003 完全一致。
- `123加456`、`二十乘三`、`十点五减二点五` 和 AC-018 三组边界得到精确规范式。
- 缺操作数、多运算链、未知词、多小数点和未完整消费输入返回明确 parse failure。

**需求追溯**：IR-003、IR-004、IR-006 → AC-003～AC-006、AC-018

**Developer 验证**：unit 表驱动测试；oracle 为 acceptance-criteria.json 的 exact_table/exact 规范式和 failure code。

**Tester 验证请求**：UI 注入覆盖八种运算符、三类成功示例和四类非法结构，断言规范式或明确错误文本。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 2：候选计算与会话编排

#### Task 2.1: 抽取无副作用的候选计算协调器

**描述**：从页面 `onEquals()` 抽取 `Expression → CalcEngine → ErrorFlags → NumberFormatter` 候选求值，返回 CalculationOutcome；成功提交历史仍由调用方执行，失败不得修改页面或 Preferences 状态。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/voice/CalculationCoordinator.ets`
- 测试：`opencalc/entry/src/test/CalculationCoordinator.test.ets`
- 复用：`opencalc/entry/src/main/ets/calculator/Expression.ets`
- 复用：`opencalc/entry/src/main/ets/calculator/Calculator.ets`
- 复用：`opencalc/entry/src/main/ets/calculator/NumberFormatter.ets`

**依赖任务**：Task 1.1

**验收标准**：
- 有效候选返回规范表达式与现有格式化结果，不写历史、不改调用方状态。
- 除零、语法、定义域、无穷大、非实数和异常映射为现有等价用户错误。
- 手动与语音调用同一个 evaluator，结果格式规则一致。

**需求追溯**：IR-005、IR-006、IR-008 → AC-007、AC-009、AC-013

**Developer 验证**：unit 测试 `123+456=579`、`10.5-2.5=8`、`10/0` failure；oracle 为 CalculationOutcome 且测试 history sink 调用数始终为 0。

**Tester 验证请求**：集成/UI 对比同一表达式的手动与语音结果、错误文案和数字格式。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 2.2: 实现语音会话状态机与成功/失败编排

**描述**：实现 start、状态投影、final-only 消费、parse、candidate evaluation、终态 cleanup 和 retry；保存语音前 expression/result 快照，只有完整成功才向 UI 发出原子提交指令。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/voice/VoiceInputController.ets`
- 测试：`opencalc/entry/src/test/VoiceInputController.test.ets`

**依赖任务**：Task 1.1、Task 1.3、Task 2.1

**验收标准**：
- fake 成功事件严格产生 listening → recognizing → success，并携带原文、规范式和结果。
- empty、parse failure、除零、service unavailable、recording interruption 均进入可恢复 error，保留原快照且 historyDelta=0。
- partial result 不提交；每个终态触发幂等 cleanup。

**需求追溯**：IR-001、IR-005、IR-006、IR-008、IR-009 → AC-001、AC-006～AC-011、AC-013、AC-014

**Developer 验证**：fake integration 测试成功矩阵与五类失败矩阵；oracle 为有序状态、原始快照不变量、commit 次数和 cleanup 次数。

**Tester 验证请求**：以 fake 驱动 UI 逐状态断言成功、空结果、歧义、除零、服务错误和录音中断。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 2.3: 加固取消、迟到回调、重复 final 与并发开始

**描述**：为每轮分配唯一 token 和 consumed 标志；cancel 先使 token 失效并立即投影 idle，再异步清理；拒绝活动期重复 start，忽略旧 session 或重复 final。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/voice/VoiceInputController.ets`
- 测试：`opencalc/entry/src/test/VoiceInputController.test.ets`
- 测试替身：`opencalc/entry/src/test/FakeSpeechRecognitionGateway.ets`

**依赖任务**：Task 2.2

**验收标准**：
- cancel 返回后立即为 idle；随后注入旧 final 不提交、不写历史。
- partial + final + duplicate final 只提交一次，history sink 预期调用一次。
- 快速重复开始最多一个 active session；dispose 可重复调用且无资源计数泄漏。

**需求追溯**：IR-001、IR-007、IR-008、IR-009 → AC-012～AC-014、AC-017

**Developer 验证**：竞态 integration 测试；oracle 为 `lateResultIgnored=true`、`commitCount=1`、`activeSessions<=1`、`activeCapturers<=1`。

**Tester 验证请求**：自动化点击取消/快速重复麦克风并注入迟到/重复回调，核对 UI、expression/result 和 history delta。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 3：HarmonyOS 平台适配

#### Task 3.1: 配置麦克风/网络权限与权限适配器

**描述**：声明 `MICROPHONE`、`INTERNET`，资源化 MIC 用途说明和前台 usedScene；实现仅在用户主动 start 时检查/请求权限的适配器，并将拒绝结果映射为业务错误。

**涉及文件**：
- 实现：`opencalc/entry/src/main/module.json5`
- 实现：`opencalc/entry/src/main/resources/base/element/string.json`
- 实现：`opencalc/entry/src/main/ets/voice/VoicePermissionAdapter.ets`
- 测试：`opencalc/entry/src/test/VoicePermissionAdapter.test.ets`

**依赖任务**：Task 1.1

**验收标准**：
- 授权前不创建/启动 capturer 或 recognizer，不写音频。
- 拒绝后返回 PERMISSION_DENIED，不循环请求、不申请后台麦克风权限。
- 权限说明明确仅用于识别用户主动说出的计算表达式。

**需求追溯**：IR-002、IR-006 → AC-002、AC-016

**Developer 验证**：配置审计 + adapter integration test；oracle 为 permission result 早于任何 platform start event，deny 分支 start count 为 0。

**Tester 验证请求**：在可重置权限的设备执行首次拒绝、页面说明、主动重试和授权流程；记录系统权限框与无录音证据。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 3.2: 实现 AudioCapturer 与 CoreSpeechKit 识别网关

**描述**：按平台顺序创建 zh-CN 在线识别引擎、注册 listener、创建 16 kHz/mono/16-bit PCM capturer、切分 640/1280 字节音频、finish/cancel/shutdown；统一映射 busy/unavailable/interrupted/no-result/internal，并保证 cleanup 幂等。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/voice/HarmonySpeechRecognitionGateway.ets`
- 实现：`opencalc/entry/src/main/ets/voice/VoicePermissionAdapter.ets`
- 测试：`opencalc/entry/src/test/HarmonySpeechRecognitionGateway.test.ets`

**依赖任务**：Task 1.1、Task 3.1

**验收标准**：
- 事件顺序满足 permissionGranted → capturerStarted → recognizerStarted → listening；final/last 之外的结果不输出可提交 final。
- cancel/error/complete/dispose 均停止并释放 capturer，取消并 shutdown engine；重复清理不抛到 UI。
- 服务不可用、busy、录音中断和空 final 映射到设计定义的业务错误，手动计算不受影响。

**需求追溯**：IR-001、IR-002、IR-006、IR-007、IR-009 → AC-001、AC-002、AC-008、AC-010～AC-012、AC-015、AC-016

**Developer 验证**：platform seam integration test + API 12 编译；oracle 为调用时序、PCM block size、错误码和终态资源计数 0。

**Tester 验证请求**：fake 验证错误/中断，具备能力的真机验证实际监听与停止；平台缺能力时记录环境限制，不用其替代 fake 矩阵。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 4：页面集成与可见交互

#### Task 4.1: 统一手动与语音的原子计算/历史提交路径

**描述**：重构 CalculatorPage 的 `onEquals()`，使手动和语音候选共用 CalculationCoordinator；新增唯一 commit 路径一次更新 expression/result/error/history/Preferences，失败不触碰旧状态。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 实现：`opencalc/entry/src/main/ets/voice/CalculationCoordinator.ets`
- 测试：`opencalc/entry/src/test/CalculatorSubmission.test.ets`
- 复用：`opencalc/entry/src/main/ets/preferences/PreferencesStore.ets`

**依赖任务**：Task 2.1、Task 2.3

**验收标准**：
- 手动等号现有成功/错误/格式/历史行为回归通过。
- 语音成功原子设置原文对应规范式和结果，并仅新增一个既有 HistoryItem。
- parse/计算/重复回调失败时 expression/result/history/Preferences 均保持不变。

**需求追溯**：IR-005、IR-006、IR-008 → AC-006～AC-009、AC-013

**Developer 验证**：integration tests 使用 history sink/Preferences test double；oracle 为成功 historyDelta=1、失败 historyDelta=0、手动与语音结果相同。

**Tester 验证请求**：UI 检查 `123加456` 原文、`123+456`、`579` 与一条历史；同时回归手动计算、科学模式、绘图和历史格式。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 4.2: 集成语音入口、状态、取消/重试与生命周期清理

**描述**：在普通计算模式装配 controller 与生产 gateway，增加麦克风、监听/识别/成功/失败文本、原始识别文本、取消和重试；适配横竖屏和三主题，手动编辑清理旧 voice 状态，页面离开时 dispose。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 实现：`opencalc/entry/src/main/ets/voice/VoiceInputController.ets`
- 实现：`opencalc/entry/src/main/resources/base/element/string.json`

**依赖任务**：Task 2.3、Task 3.2、Task 4.1

**验收标准**：
- 入口只在普通计算上下文可用；监听/识别/成功/失败、取消/重试控件与 controller snapshot 同步。
- 点击目标至少 44 vp，状态不只依赖颜色；识别原文最多两行，横竖屏均不遮挡 ButtonGrid。
- 取消立即离开活动态；权限拒绝/服务错误显示说明和重试；页面离开释放资源。

**需求追溯**：IR-001、IR-002、IR-005～IR-007 → AC-001、AC-002、AC-007～AC-012、AC-016、AC-017

**Developer 验证**：页面装配 integration test/预览或设备 smoke；oracle 为状态文本、控件 enabled/visible、原快照不变量和 dispose 事件。

**Tester 验证请求**：执行 fake UI 状态矩阵与横竖屏/三主题检查，并在真机覆盖授权、监听、取消、重试和生命周期退出。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 5：测试聚合与分层验收交接

#### Task 5.1: 聚合无设备自动化验收矩阵

**描述**：把 parser、coordinator、controller、gateway contract 和页面提交测试接入现有 Hypium 入口，形成 AC-003～AC-014、AC-017、AC-018 的确定性矩阵，并保留用例到 AC 的命名/注释追溯。

**涉及文件**：
- 测试入口：`opencalc/entry/src/test/List.test.ets`
- 测试：`opencalc/entry/src/test/ChineseNumberParser.test.ets`
- 测试：`opencalc/entry/src/test/VoiceExpressionParser.test.ets`
- 测试：`opencalc/entry/src/test/CalculationCoordinator.test.ets`
- 测试：`opencalc/entry/src/test/VoiceInputController.test.ets`
- 测试：`opencalc/entry/src/test/CalculatorSubmission.test.ets`

**依赖任务**：Task 1.3、Task 2.3、Task 4.1、Task 4.2

**验收标准**：
- 无麦克风/无在线服务环境可执行全部确定性业务矩阵，不跳过成功、空结果、歧义、服务错误、中断、取消迟到回调。
- exact table、ordered state、event order、history delta 与 invariant oracle 均来自 acceptance-criteria.json，测试失败可定位到 AC。
- 现有 PlotFunction 测试仍被聚合且无回归。

**需求追溯**：IR-003～IR-009 → AC-003～AC-014、AC-017、AC-018

**Developer 验证**：运行本地 unit/integration test；oracle 为所有新增矩阵与既有测试通过，且无设备依赖。

**Tester 验证请求**：独立运行同一注入矩阵及 UI 自动化，报告每个 AC 的 pass/fail/blocked，不把设备缺失记作业务通过。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 5.2: 完成构建回归与真机 E2E 证据交接

**描述**：完成 API 12 编译/lint/回归，审计权限、日志、资源释放和非目标边界；向 Tester 交接真机用例，记录 `123加456` 的权限/监听/识别/成功链路及环境限制。

**涉及文件**：
- 测试入口：`opencalc/entry/src/test/List.test.ets`
- 配置：`opencalc/entry/src/main/module.json5`
- 交接依据：`specs/changes/20261024-bugfix-chinese-voice-expression-input/acceptance-criteria.json`
- 后续 APPLYING 报告：`specs/changes/20261024-bugfix-chinese-voice-expression-input/apply-report.md`

**依赖任务**：Task 3.2、Task 4.2、Task 5.1

**验收标准**：
- Hvigor build、lint、unit/integration 和手动计算回归结果均有可复现记录。
- 审计确认无后台麦克风、无音频/原文持久化或日志、无 HistoryItem/Preferences Schema 变更。
- Tester 在具备能力环境获取 `listening → recognizing → success`、`123+456`、`579` 证据；缺能力时标记 blocked/environment，并保留 fake 测试结果。

**需求追溯**：IR-001、IR-002、IR-008、IR-009 → AC-001、AC-002、AC-013～AC-016

**Developer 验证**：build/lint/test/regression + 静态审计；oracle 为命令退出码 0、权限/日志/Schema 检查通过和测试报告完整。

**Tester 验证请求**：执行 AC-001/002/015/016 真机 E2E，并补充 AC-010～012 的可用设备证据；提交截图/录屏和结构化环境信息。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

## 依赖关系与开发顺序

### 可并行关系

- Task 1.2 与 Task 2.1 可在 Task 1.1 后并行。
- Task 3.1 可与 Task 1.2/1.3/2.1 并行，但 Task 3.2 必须等待 Task 3.1。
- Task 3.2 与 Task 2.2/2.3 可并行推进，最终在 Task 4.2 汇合。

### 关键路径

```text
Task 1.1 → Task 1.2 → Task 1.3 → Task 2.2 → Task 2.3 → Task 4.1 → Task 4.2 → Task 5.1 → Task 5.2
```

### 建议执行序列

```text
Task 1.1
  ├─→ Task 1.2 → Task 1.3 ─┐
  ├─→ Task 2.1 ────────────┼─→ Task 2.2 → Task 2.3 ─┐
  └─→ Task 3.1 → Task 3.2 ─┘                        ├─→ Task 4.2 → Task 5.1 → Task 5.2
                               Task 2.1/2.3 → Task 4.1 ┘
```

## AC 覆盖自检

| AC | 实现任务 | Developer 验证责任 | Tester 验证责任 | 环境依赖 |
|----|----------|----------------------|-----------------|----------|
| AC-001 | 1.1, 2.2, 3.2, 4.2, 5.2 | 状态机 integration、平台时序、页面状态投影 | UI + 真机 E2E 有序状态 | 真机 MIC/CoreSpeechKit；fake 可覆盖业务状态 |
| AC-002 | 3.1, 3.2, 4.2, 5.2 | deny 分支、录音未启动、快照不变 | 系统权限框拒绝/重试 E2E | 可重置 MIC 权限设备 |
| AC-003 | 1.3, 5.1 | 八种映射 unit/integration | 注入 UI exact table | 无设备依赖 |
| AC-004 | 1.2, 1.3, 5.1 | 整数 exact table unit | 注入 UI 表达式/结果 | 无设备依赖 |
| AC-005 | 1.2, 1.3, 5.1 | 小数 exact unit | 注入 UI `10.5-2.5=8` | 无设备依赖 |
| AC-006 | 1.2, 1.3, 2.2, 4.1, 5.1 | 非法矩阵 + 状态/历史不变量 | 注入 UI 错误与旧输入保持 | 无设备依赖 |
| AC-007 | 2.1, 2.2, 4.1, 4.2, 5.1 | 成功集成、原子提交 | UI 原文/规范式/结果 | fake UI |
| AC-008 | 2.2, 3.2, 4.2, 5.1 | empty outcome 与 historyDelta=0 | UI 空结果恢复 | fake gateway |
| AC-009 | 2.1, 2.2, 4.1, 5.1 | 除零 outcome 与原状态不变量 | UI 除零安全失败 | fake recognition result |
| AC-010 | 1.1, 2.2, 3.2, 4.2 | unavailable/busy 与 cleanup | UI 重试；可选真机降级 | fake 必测，真机可选 |
| AC-011 | 1.1, 2.2, 3.2, 4.2 | interruption 与资源计数 0 | UI 中断；可选真机 | fake 必测，真机可选 |
| AC-012 | 1.1, 2.3, 3.2, 4.2 | cancel/late callback 竞态 | UI 取消立即；真机停止录音 | fake 必测，真机补证 |
| AC-013 | 2.1, 2.2, 2.3, 4.1, 5.1 | duplicate final、historyDelta=1 | UI/Preferences 历史一次 | fake + Preferences test double |
| AC-014 | 1.1, 2.2, 2.3, 5.1 | 无设备完整确定性矩阵 | 独立运行解析与 UI 自动化 | 不需要 MIC/在线服务 |
| AC-015 | 3.2, 4.2, 5.2 | 构建与平台装配、交接用例 | 真机/等价环境截图或录屏 | MIC、网络、zh-CN CoreSpeechKit；不可用则环境阻塞 |
| AC-016 | 3.1, 3.2, 4.2, 5.2 | grant-before-start 事件顺序 | 授权 E2E 与监听 UI | 权限框 + MIC 设备 |
| AC-017 | 1.1, 2.3, 4.2, 5.1 | 并发 start/cardinality | 快速重复点击 UI | fake rapid events |
| AC-018 | 1.2, 1.3, 5.1 | 边界数字 exact table | 注入 UI 表达式/结果 | 无设备依赖 |

### 覆盖结论

- 18/18 个 feature-level AC 均至少关联一个实现任务、Developer 验证责任和 Tester 验证责任。
- 所有 unit/integration/UI/E2E 层级均已分配；包含 UI/E2E 的 AC 未被单元测试单独关闭。
- AC-015、AC-016 及 AC-001/002 的设备路径明确保留为 Tester 环境验证；环境不可用只能标记 blocked/environment，不能标记 AC 完成。
- 未新增、替换或弱化 Planning 定义的 IR/AC。

## 验收计划

| 阶段 | 任务 | 验收方式 | 执行时点 |
|------|------|----------|----------|
| 领域契约与解析 | 1.1～1.3 | ArkTS 编译 + 表驱动 unit | 对应任务 GREEN/REFACTOR 后 |
| 计算与控制器 | 2.1～2.3 | fake integration + 副作用/竞态 oracle | 对应任务 GREEN/REFACTOR 后 |
| 平台适配 | 3.1～3.2 | 配置审计 + platform seam + API 12 build | 对应任务完成后 |
| 页面集成 | 4.1～4.2 | integration + UI 自动化/设备 smoke | 集成完成后 |
| 分层验收 | 5.1～5.2 | 全量 test/build/lint + Tester 真机证据 | APPLYING 收尾，不在 IMPLEMENTING 执行 |
