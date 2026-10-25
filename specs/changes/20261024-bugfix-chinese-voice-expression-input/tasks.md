# 中文语音输入算式并自动计算开发任务（Tester 反馈迭代 1）

## 任务概述

- 功能名称：中文语音输入算式并自动计算
- 变更类型：`bugfix`（编排分类；产品语义为新增功能）
- 关联 Issue / PR：Issue #52 / PR #55
- 目标基线：`4af7209810beb3c5378d4e8a89f0137a58c91802`
- 规划依据：`proposal.md` / `delta-spec.md` / `acceptance-criteria.json` / `info.md` / `new-arch.md` / `delta-design.md` / `design-review.md`
- 开发阶段：Tester 反馈后的增量 IMPLEMENTING；本文只拆解后续工作，不表示任务或 AC 已实现/通过
- 预计任务数：7

## 已验证的 Planning 输入

- 八个 Planning 制品均存在且非空；`design-review.md` 结论为通过、无 Planning blocker。
- AC 校验器退出码为 0：10 个原子需求 `IR-001～IR-010`，19 个 feature-level AC `AC-001～AC-019`。
- Tester run 107 的反馈已进入设计：普通模拟器的 `CreateEngineError` 只证明 AC-010；Local Test fake 无法驱动安装包页面，必须补齐 AC-019 的设备测试装配。
- AC-014（本地确定性验证）、AC-019（设备 scripted UI 矩阵）、AC-015（真实语音 E2E）分层验收，不得互相替代。

## 实施约束

- 后续 APPLYING 按 RED → GREEN → REFACTOR 执行；本阶段不修改产品/测试源码或构建配置，也不运行测试。
- release 只能创建真实 `HarmonySpeechRecognitionGateway(CoreSpeechPlatformDriver)`，不得从 Want、深链、环境变量、隐藏点击或任意 transcript 参数激活 fake。
- 设备测试只接受 allowlisted `VoiceTestScenarioId`，加载同一 `CalculatorPage`，不得复制页面、parser、controller、计算或历史实现。
- scripted gateway 不得用于关闭 AC-015；真实环境能力不足时必须报告 environment limitation。
- 不新增音频/原文持久化；`HistoryItem` / Preferences Schema 不变。

## 任务列表

### 阶段 1：生产装配边界

#### Task 1.1: 建立 release-sealed VoiceGatewayFactory

**描述**：新增最小工厂端口与 release 实现，将真实 Harmony gateway 构造集中到 composition root。release 实现不包含 scenario setter、测试 registry 或参数解析。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/voice/VoiceGatewayFactory.ets`
- 复用：`opencalc/entry/src/main/ets/voice/SpeechRecognitionGateway.ets`
- 复用：`opencalc/entry/src/main/ets/voice/HarmonySpeechRecognitionGateway.ets`
- 复用：`opencalc/entry/src/main/ets/voice/CoreSpeechPlatformDriver.ets`
- 测试：`opencalc/entry/src/test/VoiceGatewayFactory.test.ets`
- 测试入口：`opencalc/entry/src/test/List.test.ets`

**依赖任务**：无

**验收标准**：
- release factory 每次创建真实 Harmony gateway，授权前不启动 capturer/recognizer。
- main 源码不导入 scripted gateway、scenario registry 或测试 Ability。
- factory 不读取 Want、URI、环境变量或任意 transcript，不存在运行时切换 fake 的公开入口。

**需求追溯**：IR-001、IR-002、IR-009 → AC-001、AC-002、AC-016、AC-019

**Developer 验证**：先写失败的 factory contract/装配测试；GREEN 后断言真实 driver 构造路径唯一、测试类型对 main 不可见、授权事件早于平台启动事件。

**Tester 验证请求**：在 release HAP 上尝试 scenario 参数、深链和普通启动，确认均不能激活 scripted gateway；保留包内容审计证据。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.2: 让 CalculatorPage 通过工厂装配并保持默认行为

**描述**：移除页面对具体 driver/gateway 的直接构造，使页面只消费工厂/端口；保持普通启动、权限拒绝、服务不可用、取消、页面销毁和手动计算行为，为 test-only composition 留出页面创建前绑定点。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 实现：`opencalc/entry/src/main/ets/voice/VoiceGatewayFactory.ets`
- 集成：`opencalc/entry/src/main/ets/entryability/EntryAbility.ets`
- 测试：`opencalc/entry/src/test/VoicePageComposition.test.ets`
- 测试入口：`opencalc/entry/src/test/List.test.ets`

**依赖任务**：Task 1.1

**验收标准**：
- 普通 EntryAbility 只能绑定 release factory，用户路径与目标 SHA 的真实语音行为一致。
- 权限拒绝或 CreateEngineError 保留旧表达式、停止录音并提供重试。
- dispose 幂等；重复开始最多一个活动 session，成功仍只提交一次历史。

**需求追溯**：IR-001、IR-002、IR-005～IR-009 → AC-001、AC-002、AC-007～AC-014、AC-016、AC-017、AC-019

**Developer 验证**：composition integration tests 使用记录型 factory，断言 create/start/dispose 次数、失败快照不变量、duplicate start/final 的 session 与 history cardinality。

**Tester 验证请求**：回归已通过的 AC-002/010，再由设备测试装配验证同一页面可进入 scripted 状态链。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 2：设备测试专用 scripted 装配

#### Task 2.1: 实现 allowlisted scenario registry 与 scripted gateway

**描述**：在设备测试源码集中定义枚举场景和确定性事件脚本，覆盖运算符、整数、小数、歧义、空结果、除零、服务错误、录音中断、取消迟到回调、重复开始和重复 final；只输出现有 gateway 事件，不复制业务判断。

**涉及文件**：
- 新增：`opencalc/entry/src/ohosTest/ets/voice/VoiceTestScenario.ets`
- 新增：`opencalc/entry/src/ohosTest/ets/voice/VoiceTestScenarioRegistry.ets`
- 新增：`opencalc/entry/src/ohosTest/ets/voice/ScriptedSpeechRecognitionGateway.ets`
- 测试：`opencalc/entry/src/ohosTest/ets/test/ScriptedGateway.test.ets`

**依赖任务**：Task 1.1

**验收标准**：
- registry 只接受设计批准的 11 类枚举 scenarioId，不接受任意 transcript 或动态脚本。
- transcript、事件顺序和 late/duplicate 行为与 `acceptance-criteria.json` oracle 一致。
- cancel/dispose 幂等；事件含 sessionId；可确定报告 activeSessions、cleanup 和 duplicate/late callback。

**需求追溯**：IR-003～IR-009 → AC-003～AC-014、AC-017～AC-019

**Developer 验证**：scenario contract 表驱动测试逐项比较 allowlist、输入事件和预期 oracle；未知 ID 必须 fail-closed。

**Tester 验证请求**：逐个枚举 scenario，确认无 MIC/CoreSpeechKit 时仍可重复执行且无任意文本入口。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 2.2: 增加 test-only Ability/profile 并加载同一页面

**描述**：新增仅进入设备测试包的 Ability/profile。测试 Ability 在加载页面前解析 allowlisted scenarioId、绑定 scripted factory，再加载同一 `pages/Index` / `CalculatorPage`；权限顺序场景仍走真实 HarmonyOS 权限框。

**涉及文件**：
- 新增：`opencalc/entry/src/ohosTest/module.json5`
- 新增：`opencalc/entry/src/ohosTest/ets/testability/VoiceTestAbility.ets`
- 新增：`opencalc/entry/src/ohosTest/ets/voice/ScriptedVoiceGatewayFactory.ets`
- 配置：`opencalc/build-profile.json5`
- 配置：`opencalc/entry/build-profile.json5`
- 复用：`opencalc/entry/src/main/ets/pages/Index.ets`
- 复用：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`

**依赖任务**：Task 1.2、Task 2.1

**验收标准**：
- 设备测试包从 test-only Ability 启动同一页面，scenario 绑定发生在 controller 创建前。
- test Ability/action/URI 和 registry 不进入 release module 或 release HAP。
- AC-016 场景记录 `permissionGranted → capturerStarted → recognizerStarted → uiListening`，授权前音频写入数为 0。

**需求追溯**：IR-001、IR-002、IR-009 → AC-001、AC-002、AC-016、AC-019

**Developer 验证**：test-profile composition test + release/test manifest diff；断言相同页面路径、绑定顺序、release test Ability 缺失和 permission event order。

**Tester 验证请求**：安装设备测试包确认场景可驱动页面；安装 release 候选包确认同名 Ability/action/scenario 不可启动。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 2.3: 提供结构化测试观测与历史 delta 证据

**描述**：test-only harness 输出源码 SHA、scenarioId、session/state/event/cleanup、expression/result 及页面/Preferences 历史前后数量。只记录预定义场景元数据，不记录真实音频或真实用户原文。

**涉及文件**：
- 新增：`opencalc/entry/src/ohosTest/ets/voice/VoiceTestEventRecorder.ets`
- 修改：`opencalc/entry/src/ohosTest/ets/voice/ScriptedSpeechRecognitionGateway.ets`
- 修改：`opencalc/entry/src/ohosTest/ets/testability/VoiceTestAbility.ets`
- 测试：`opencalc/entry/src/ohosTest/ets/test/VoiceTestEvidence.test.ets`

**依赖任务**：Task 2.2

**验收标准**：
- 每个场景记录目标源码 SHA 和唯一 scenarioId，可与 UI tree/截图一一关联。
- success/duplicate-final 的页面和 Preferences `historyDelta=1`；失败、取消、重复开始前 `historyDelta=0`。
- cancel-late 记录 UI idle、cleanup 完成和旧 final 被忽略；不新增持久化 key 或改变 HistoryItem Schema。

**需求追溯**：IR-005～IR-009 → AC-007～AC-014、AC-017、AC-019

**Developer 验证**：recorder contract/integration tests 比较精确 delta、事件顺序和 schema；静态检查禁止记录 PCM、真实 transcript 和用户内容。

**Tester 验证请求**：每个设备 UI 场景同时采集 UI tree、截图和结构化记录，核对 SHA/scenarioId/history delta。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 3：矩阵验收与安全回归

#### Task 3.1: 自动化执行设备可见 UI 场景矩阵

**描述**：编写设备 UI 用例驱动 11 类 scenario，按 AC oracle 断言状态、原文、规范式、结果、错误、取消/重试、旧输入保持与历史 delta；覆盖关键响应式布局，不把 Local Test 当作 UI 证据。

**涉及文件**：
- 新增：`opencalc/entry/src/ohosTest/ets/test/VoiceUiMatrix.test.ets`
- 修改：`opencalc/entry/src/ohosTest/ets/test/List.test.ets`
- 依据：`specs/changes/20261024-bugfix-chinese-voice-expression-input/acceptance-criteria.json`
- 后续证据目录：`.agent-runtime/evidence/<tester-task>/<run>/`

**依赖任务**：Task 2.3

**验收标准**：
- UI 覆盖八种运算符、`123加456`、`二十乘三`、`十点五减二点五` 和 AC-018 三个边界案例。
- 覆盖 ambiguous、empty、divideByZero、serviceUnavailable、recordingInterrupted、cancelLateCallback、duplicateStart、duplicateFinal；失败/取消保留旧状态。
- 状态、控件、页面历史与 Preferences delta 均来自设备证据；每个失败能定位到 AC/scenarioId。

**需求追溯**：IR-001、IR-003～IR-009 → AC-001、AC-003～AC-014、AC-017～AC-019

**Developer 验证**：后续 APPLYING 构建设备测试包并运行 integration/UI suite；11 类场景全部执行、无跳过，oracle 与 AC JSON 一致。

**Tester 验证请求**：在目标模拟器独立执行完整矩阵并提交每个 AC 的 UI tree、截图、事件和 history delta；未执行项按失败处理。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 3.2: 审计 release 封闭性并交接真实语音 E2E

**描述**：完成 Local Test、HAP build、CodeLinter、release/test 包差异、权限/日志/Schema 和手动计算回归；交接 AC-015 能力预检。真实链路仅使用 release factory，在具备 MIC、网络和 zh-CN CoreSpeechKit 的环境说“123加456”。

**涉及文件**：
- 测试入口：`opencalc/entry/src/test/List.test.ets`
- 设备测试入口：`opencalc/entry/src/ohosTest/ets/test/List.test.ets`
- 配置：`opencalc/entry/src/main/module.json5`
- 配置：`opencalc/entry/src/ohosTest/module.json5`
- 后续报告：`specs/changes/20261024-bugfix-chinese-voice-expression-input/apply-report.md`

**依赖任务**：Task 1.2、Task 3.1

**验收标准**：
- release HAP 不含 test Ability、registry、scripted gateway、scenario setter 或激活路由，`releaseInjectionReachable=false`。
- Local Test、设备 UI matrix、build、CodeLinter 和手动/科学/绘图/历史回归可复现；无后台 MIC、音频/原文持久化或 Schema 变化。
- 能力预检通过时取得真实 `listening → recognizing → success`、原文、`123+456`、`579`；能力不足时记录 environment limitation，不用 scripted 证据关闭 AC-015。

**需求追溯**：IR-001～IR-010 → AC-001～AC-019

**Developer 验证**：后续 APPLYING 运行 unit/integration/UI/build/lint 与 release package audit；所有命令成功、11 类 UI 场景执行、release 测试符号/路由零命中、回归无变化。

**Tester 验证请求**：独立复核 AC-019 与 release 封闭性；在能力预检通过环境单独执行 AC-015，分别报告 scripted 与 real evidence。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

## 依赖关系与开发顺序

### 可并行关系

- Task 2.1 可在 Task 1.1 完成后与 Task 1.2 并行。
- Task 3.2 的 release 审计用例可在 Task 1.2 后预写，但最终验收等待 Task 3.1。

### 关键路径

```text
Task 1.1 → Task 1.2 ─────────────┐
          └→ Task 2.1 → Task 2.2 → Task 2.3 → Task 3.1 → Task 3.2
```

### 建议执行序列

```text
Task 1.1 → (Task 1.2 ∥ Task 2.1) → Task 2.2 → Task 2.3 → Task 3.1 → Task 3.2 → 完成
```

## AC 覆盖自检

| AC | 任务 | Developer 验证责任 | Tester 验证责任 | 环境依赖 |
|----|------|----------------------|-----------------|----------|
| AC-001 | 1.1,1.2,2.2,3.1,3.2 | factory/状态投影与顺序 | scripted UI + real E2E | 设备 UI；real 需 CoreSpeechKit |
| AC-002 | 1.1,1.2,2.2,3.2 | deny-before-start | 权限框拒绝/重试 | 可重置 MIC 权限 |
| AC-003 | 2.1,3.1,3.2 | 八种运算符 regression + oracle | 设备 UI exact table | device harness |
| AC-004 | 2.1,3.1,3.2 | 整数 regression + oracle | 设备 UI 精确表达式/结果 | device harness |
| AC-005 | 2.1,3.1,3.2 | 小数 regression + oracle | 设备 UI `10.5-2.5=8` | device harness |
| AC-006 | 1.2,2.1,2.3,3.1 | 非法输入与旧状态不变量 | 设备 UI 明确错误 | device harness |
| AC-007 | 1.2,2.1,2.3,3.1 | 原子提交/状态投影 | 原文、规范式、结果 UI | device harness |
| AC-008 | 1.2,2.1,2.3,3.1 | empty 与 historyDelta=0 | 设备 UI 空结果恢复 | device harness |
| AC-009 | 1.2,2.1,2.3,3.1 | 除零与旧状态不变量 | 设备 UI 除零安全失败 | device harness |
| AC-010 | 1.2,2.1,2.3,3.1 | service error cleanup | scripted UI/真实降级 | fake 必测；real 可补证 |
| AC-011 | 1.2,2.1,2.3,3.1 | interruption cleanup | 设备 UI 中断恢复 | device harness |
| AC-012 | 1.2,2.1,2.3,3.1 | cancel/late callback 竞态 | 设备 UI 立即取消 | device harness |
| AC-013 | 1.2,2.1,2.3,3.1 | duplicate final/historyDelta=1 | 页面+Preferences 一次 | device harness |
| AC-014 | 1.2,2.1,3.2 | Local deterministic regression | 独立运行 local matrix | 无 MIC/服务 |
| AC-015 | 1.1,1.2,3.2 | release 真实装配/预检交接 | 真实语音 E2E | MIC/网络/zh-CN 服务 |
| AC-016 | 1.1,1.2,2.2,3.2 | grant-before-start | 权限框+监听 UI | 权限设备/test assembly |
| AC-017 | 1.2,2.1,2.3,3.1 | session/capturer cardinality | 快速重复点击 UI | device harness |
| AC-018 | 2.1,3.1,3.2 | 边界 exact oracle | 三组 UI 精确结果 | device harness |
| AC-019 | 1.1～3.2 | test assembly、矩阵、release seal | device evidence + 不可达 | test/release 包 |

### 覆盖结论

- 19/19 feature-level AC 均关联实现/验证任务，并分配 Developer 与 Tester 责任。
- unit/integration/ui/e2e 层级均已接收；UI/E2E AC 不由 Local Test 单独关闭。
- AC-015 与 AC-019 责任明确分开；环境不可用不弱化 AC。
- 未新增、替换或缩减 Planning 的 IR/AC。

## 验收计划

| 阶段 | 任务 | 验收方式 | 执行时点 |
|------|------|----------|----------|
| 生产装配边界 | 1.1～1.2 | factory/composition TDD + release 回归 | 对应任务 GREEN/REFACTOR 后 |
| 设备测试装配 | 2.1～2.3 | scenario contract + test Ability + evidence | 对应任务 GREEN/REFACTOR 后 |
| 分层验收 | 3.1～3.2 | UI matrix + release 审计 + real E2E 交接 | 后续 APPLYING/Tester；本阶段不执行 |
