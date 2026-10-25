# 中文语音输入算式并自动计算开发任务（Tester 反馈迭代 2）

## 任务概述

- 功能名称：中文语音输入算式并自动计算
- 变更类型：`bugfix`（编排分类；产品语义为新增功能）
- 关联 Issue / PR：Issue #52 / PR #55
- 目标基线：`d904e4c3b8dc26c0490eeda5d43805f5a10310aa`
- 规划依据：`proposal.md` / `delta-spec.md` / `acceptance-criteria.json` / `info.md` / `new-arch.md` / `delta-design.md` / `design-review.md`
- 开发阶段：Tester 反馈迭代 2 的增量 IMPLEMENTING；本文只拆解后续工作，不表示任务或 AC 已实现/通过
- 预计任务数：3

## 已验证的 Planning 输入

- `proposal.md`、`delta-spec.md`、`acceptance-criteria.json`、`info.md`、`new-arch.md`、`delta-design.md`、`design-review.md`、`todo.md` 均存在、非空且相互一致。
- `design-review.md` 的 PLANNING gate 为通过且无 blocker；目标源码基线与 Tester run 114 均指向 SHA `d904e4c3b8dc26c0490eeda5d43805f5a10310aa`。
- AC 校验器退出码为 0：18 个原子需求 `IR-001～IR-018`，19 个 feature-level AC `AC-001～AC-019`。
- Tester run 114 已独立确认 73/73 Local Test、release/ohosTest HAP 构建、CodeLinter 0 error、11 类 scripted 设备矩阵及权限拒绝/重试；本迭代不重复实现这些已闭合能力。
- 批准的修订把 AC-016 固定为“真实系统权限框 + test-only gateway 顺序事件”的确定性验证；AC-015 仍单独要求真实 AudioCapturer/CoreSpeechKit 成功，不得以 scripted evidence 替代。

## 实施约束

- 后续 APPLYING 必须逐任务执行 RED → GREEN → REFACTOR；本 IMPLEMENTING 阶段不修改产品/测试源码、不运行产品测试、不构建、不提交、不推送。
- AC-016 的新增观测只能位于 `ohosTest` recorder、测试合同或外部设备动作日志；不得给 release 增加诊断接口、scenario 参数、任意 transcript 注入或 fake 激活入口。
- 真实系统权限结果返回前，合并证据中的 `gatewayStartCount` 必须为 0；grant 后事件顺序必须是 `permissionGranted → gatewayStartInvoked → scriptedListening → uiListening`。
- AC-015 只由具备 MIC、网络和 zh-CN CoreSpeechKit 的 release 环境关闭；当前服务不可用模拟器只能证明 AC-010 的安全降级。
- 保持 11 类 allowlisted scripted 场景、`HistoryItem`/Preferences Schema、手动计算路径、权限范围以及“不持久化音频/原文”约束不变。

## 任务列表

### 阶段 1：test-only 权限顺序观测

#### Task 1.1: 扩展 gateway start/listening 的结构化顺序合同

**描述**：先用失败测试锁定 AC-016 的 test-only 事件模型，再扩展 recorder、scripted factory/gateway，使每轮会话明确记录 gateway 创建/启动计数、`gatewayStartInvoked` 和 `scriptedListening`。记录只包含 allowlisted 场景元数据与 sessionId，不触碰 release 页面、真实网关或用户内容。

**涉及文件**：
- 测试实现：`opencalc/entry/src/ohosTest/ets/voice/VoiceTestEventRecorder.ets`
- 测试实现：`opencalc/entry/src/ohosTest/ets/voice/ScriptedVoiceGatewayFactory.ets`
- 测试实现：`opencalc/entry/src/ohosTest/ets/voice/ScriptedSpeechRecognitionGateway.ets`
- 单元/合同测试：`opencalc/entry/src/test/VoiceTestEvidence.test.ets`
- 单元/合同测试：`opencalc/entry/src/test/ScriptedGateway.test.ets`
- 测试聚合：`opencalc/entry/src/test/List.test.ets`

**依赖任务**：无

**验收标准**：
- RED 测试先证明当前 recorder 不能给出 gateway start 次数与 `gatewayStartInvoked → scriptedListening` 顺序；GREEN 后精确断言该顺序和 sessionId 一致。
- start 前计数为 0；一次有效 start 后计数为 1；重复点击/重复 start 不产生第二个活动 session 或第二次 start 记录。
- cancel/dispose 后记录 cleanup，迟到 final 不改变 start 计数；记录结构不包含 PCM、真实 transcript、权限 token 或用户数据。
- 所有变更仅在 `ohosTest`/test 源码集；main/release 仍无 recorder、scenario registry 或 scripted 类型依赖。

**需求追溯**：IR-003、IR-015、IR-017 → AC-012、AC-016、AC-017、AC-019

**Developer 验证**：运行 recorder/scripted gateway 的 unit/integration 合同，精确比较 `gatewayStartCount`、session cardinality、事件数组和 cleanup；静态检查 main/release 不导入新增测试类型。

**Tester 验证请求**：在设备测试包采集同一 session 的 `gatewayStartInvoked`、`scriptedListening` 和 cleanup 结构化记录，确认重复操作不增加 start/session 数。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 2：真实权限框与页面状态的设备关联

#### Task 2.1: 建立 AC-016 的确定性设备证据链

**描述**：新增/收紧设备测试合同与执行入口。每次从清除 MIC 授权的干净状态启动 test-only Ability，先证明系统权限结果返回前 recorder 中 start 为 0，再由设备动作日志记录允许操作，并把 recorder 与 UI tree 时间线合并为 `permissionGranted → gatewayStartInvoked → scriptedListening → uiListening`。页面仍加载生产 `CalculatorPage`，不得复制权限或 UI 逻辑。

**涉及文件**：
- 测试装配：`opencalc/entry/src/ohosTest/ets/testability/VoiceTestAbility.ets`
- 测试合同：`opencalc/entry/src/ohosTest/ets/test/VoiceUiMatrix.ets`
- 设备测试：`opencalc/entry/src/ohosTest/ets/test/VoiceUiMatrix.test.ets`
- 本地镜像合同：`opencalc/entry/src/test/VoiceUiMatrixContract.test.ets`
- 测试聚合：`opencalc/entry/src/ohosTest/ets/test/List.test.ets`
- 后续设备证据：`.agent-runtime/evidence/<tester-task>/<run>/device/`

**依赖任务**：Task 1.1

**验收标准**：
- 权限未决定时点击语音入口，真实 HarmonyOS 权限框可见；允许前 recorder 显示 `gatewayStartCount=0` 且 UI 不显示 listening。
- 允许后合并时间线严格为 `permissionGranted → gatewayStartInvoked → scriptedListening → uiListening`，并保留系统权限动作日志、结构化事件、UI tree 和截图。
- 拒绝路径仍不启动 gateway，保留旧表达式并显示说明/重试；再次重试只重新发起权限流程。
- 设备流程不要求当前模拟器产生真实 `capturerStarted/recognizerStarted`；这两个真实平台事实不得写入 AC-016 的通过条件。
- test Ability 仍只接受 allowlisted scenarioId；release manifest/HAP 不注册该 Ability，且不能通过 Want、URI、隐藏 UI 或任意 transcript 激活 fake。

**需求追溯**：IR-001～IR-004、IR-017 → AC-001、AC-002、AC-016、AC-019

**Developer 验证**：运行 test composition/matrix 合同，验证 test Ability 在页面创建前绑定 scripted factory、before-grant start=0、grant 后事件顺序及 release/test manifest 隔离；产出可供设备驱动合并的稳定字段。

**Tester 验证请求**：独立重置权限并操作真实系统权限框，按单调时间戳合并 command log、recorder 与 UI tree；缺少任一阶段或顺序错误均判 AC-016 失败。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 3：回归、release 封闭与环境交接

#### Task 3.1: 回归完整 AC 矩阵并单独交接真实语音 E2E

**描述**：在 Task 2.1 完成后执行全量 local/build/lint、11 类 scripted 设备 UI 矩阵、release 包封闭审计和权限拒绝/允许回归。将 AC-016 的确定性顺序证据与 AC-015 的真实语音环境责任分开报告；若当前环境无 zh-CN CoreSpeechKit，只记录 AC-015 environment limitation，不更改产品实现或验收标准。

**涉及文件**：
- 本地测试入口：`opencalc/entry/src/test/List.test.ets`
- 设备测试入口：`opencalc/entry/src/ohosTest/ets/test/List.test.ets`
- release 装配审计：`opencalc/entry/src/main/ets/voice/VoiceGatewayFactory.ets`
- release manifest 审计：`opencalc/entry/src/main/module.json5`
- test manifest 审计：`opencalc/entry/src/ohosTest/module.json5`
- 后续应用报告：`specs/changes/20261024-bugfix-chinese-voice-expression-input/apply-report.md`
- 后续证据目录：`.agent-runtime/evidence/<developer-or-tester-task>/<run>/`

**依赖任务**：Task 2.1

**验收标准**：
- 现有 parser/controller/calculation/history 的 Local Test 全部通过；release 与 ohosTest HAP 构建成功；CodeLinter 无 error。
- 11 类 allowlisted scripted 场景全部执行且 oracle 不变：成功历史 `+1`，失败/取消 `+0`，旧输入、cleanup、重复点击/重复 final 不变量均保持。
- AC-016 由真实权限框和 test-only 顺序事件确定通过；AC-019 继续证明设备 UI 矩阵与 `releaseInjectionReachable=false`。
- release HAP 不含 test Ability、scenario registry、scripted gateway、recorder、setter 或激活路由；手动/科学/绘图/历史及权限范围无回归。
- AC-015 仅在能力预检确认 MIC、网络和 zh-CN CoreSpeechKit 可用后，用 release factory 说“123加456”并观察真实 `listening → recognizing → success`、`123+456`、`579`；能力不足时保持未通过/环境限制，scripted 证据不得替代。

**需求追溯**：IR-001～IR-018 → AC-001～AC-019

**Developer 验证**：后续 APPLYING 运行 unit/integration、release/test build、CodeLinter、包内容/manifest/source 审计及可用设备上的 scripted matrix；报告 AC-015 与 AC-016 的不同证据来源和状态。

**Tester 验证请求**：在精确目标 SHA 上独立复跑 11 类矩阵和 AC-016 权限顺序；另在能力预检通过的真实环境执行 AC-015，保留 UI/录屏、结构化记录和环境信息。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

## 依赖关系与开发顺序

### 依赖与关键路径

```text
Task 1.1（test-only 顺序合同）
    → Task 2.1（真实权限框 + recorder + UI 时间线）
        → Task 3.1（全量回归、release seal、AC-015 独立交接）
```

本迭代无安全并行实现项：Task 2.1 依赖 Task 1.1 的稳定事件 schema，Task 3.1 必须在设备顺序合同冻结后执行。

### 建议执行序列

```text
Task 1.1 → Task 2.1 → Task 3.1 → 完成
```

## AC 覆盖自检

| AC | 任务 | Developer 验证责任 | Tester 验证责任 | 环境依赖 |
|----|------|----------------------|-----------------|----------|
| AC-001 | 2.1,3.1 | 状态顺序回归与 UI 合同 | scripted UI/真实语音状态链 | 设备 UI；real 需服务 |
| AC-002 | 2.1,3.1 | deny-before-start、旧输入不变量 | 真实权限框拒绝/重试 | 可重置 MIC 权限 |
| AC-003 | 3.1 | 八种映射 local/matrix 回归 | 设备 UI exact table | scripted harness |
| AC-004 | 3.1 | 阿拉伯/中文整数回归 | 设备 UI 精确表达式/结果 | scripted harness |
| AC-005 | 3.1 | 中文小数回归 | 设备 UI `10.5-2.5=8` | scripted harness |
| AC-006 | 3.1 | 非法输入与状态原子性 | 设备 UI 明确错误 | scripted harness |
| AC-007 | 3.1 | 原文/计算/格式化回归 | 原文、规范式、结果 UI | scripted harness |
| AC-008 | 3.1 | empty 与 historyDelta=0 | 设备 UI 空结果恢复 | scripted harness |
| AC-009 | 3.1 | 除零与旧状态不变量 | 设备 UI 除零安全失败 | scripted harness |
| AC-010 | 3.1 | service error cleanup | scripted UI + 当前模拟器真实降级 | fake 必测；real 可补证 |
| AC-011 | 3.1 | interruption cleanup | 设备 UI 中断恢复 | scripted harness |
| AC-012 | 1.1,3.1 | cancel/late callback 与 cleanup | 设备 UI 立即取消 | scripted harness |
| AC-013 | 3.1 | duplicate final/historyDelta=1 | 页面与 Preferences 一次 | scripted harness |
| AC-014 | 3.1 | 无 MIC 的 local matrix | 独立复跑 local deterministic suite | 无 MIC/服务 |
| AC-015 | 3.1 | release 真实装配与预检交接 | 真实语音 E2E | MIC/网络/zh-CN 服务 |
| AC-016 | 1.1,2.1,3.1 | beforeGrant=0 与顺序合同 | 真实权限框 + recorder + UI | 设备/test assembly |
| AC-017 | 1.1,3.1 | session/start cardinality | 快速重复点击 UI | scripted harness |
| AC-018 | 3.1 | 边界 exact oracle 回归 | 三组 UI 精确结果 | scripted harness |
| AC-019 | 1.1,2.1,3.1 | test assembly、事件、release seal | 设备矩阵 + release 不可达 | test/release 包 |

### 覆盖结论

- 19/19 feature-level AC 均关联至少一个任务，并分配 Developer 与 Tester 验证责任。
- unit/integration/ui/e2e 层级均被接收；UI/E2E AC 不由 Local Test 单独关闭。
- AC-016 的确定性权限顺序与 AC-015 的真实语音链严格分证；环境不可用不会弱化或伪造 AC-015。
- 本迭代只细化批准设计的实现与验证责任，未新增、替换或缩减任何 IR/AC。

## 验收计划

| 任务 | 验收方式 | 执行时点 |
|------|----------|----------|
| Task 1.1 | recorder/scripted gateway RED-GREEN-REFACTOR 合同 | 对应任务 REFACTOR 后 |
| Task 2.1 | 真实权限框 + recorder + UI tree 顺序证据 | 对应任务 REFACTOR 后及 Tester 独立复核 |
| Task 3.1 | local/build/lint、11 类矩阵、release seal、真实 E2E 交接 | 后续 APPLYING/Tester；本阶段不执行 |
