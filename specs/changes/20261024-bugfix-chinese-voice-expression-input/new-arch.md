# 中文语音输入算式并自动计算 - 架构变更

## 1. 变更概述

| 项目 | 内容 |
|------|------|
| 变更类型 | 应用内新增分层组件，不改变部署单元 |
| 变更日期 | 2026-10-25（Tester 反馈后修订） |
| 变更人 | MigBot Developer |
| 追溯 | Issue #52；IR-001～IR-018；Tester run 114；目标 SHA `d904e4c3b8dc26c0490eeda5d43805f5a10310aa` |

## 2. 最新架构【架构前置】

### 2.1 架构总览

应用仍是单 `entry` HAP。新增“语音会话控制—识别网关—纯表达式解析”三层，以平台适配器隔离麦克风、权限和在线识别，以纯解析器隔离语言规则；成功候选最终汇入既有计算与历史链。

### 2.2 分层架构图

```text
┌──────────────────────────────────────────────────────────┐
│ 表现层：CalculatorPage                                  │
│ 麦克风/取消/重试 │ 状态/原文/错误 │ expression/result    │
└───────────────────────┬──────────────────────────────────┘
                        │ user command / state projection
┌───────────────────────▼──────────────────────────────────┐
│ 应用层：VoiceInputController                            │
│ session token │ state machine │ old-input snapshot      │
└───────────────┬────────────────────────┬─────────────────┘
                │ recognition outcome    │ parse text
┌───────────────▼──────────────┐  ┌──────▼─────────────────┐
│ SpeechRecognitionGateway     │  │ VoiceExpressionParser  │
│ interface                    │  │ pure, deterministic    │
├──────────────────────────────┤  └──────────┬─────────────┘
│ Harmony gateway │ factory    │             │ candidate expr
└───────┬─────────┴────────────┘  ┌──────────▼─────────────┐
        │                          │ CalculationCoordinator │
┌───────▼──────────────────────┐  │ Expression/CalcEngine │
│ Platform Kits               │  │ Formatter/History      │
│ AbilityKit/AudioKit/         │  └────────────────────────┘
│ CoreSpeechKit               │
└──────────────────────────────┘

测试装配（不进入 release 可达路径）：
Test Ability/profile → allowlisted VoiceTestScenarioRegistry
                    → ScriptedSpeechRecognitionGateway
                    → 同一 VoiceInputController / CalculatorPage
```

### 2.3 组件职责

| 组件 | 类型 | 职责 | 边界 |
|------|------|------|------|
| CalculatorPage voice UI | View | 发送开始/取消/重试命令并投影可见状态 | 不直接解析中文或管理 PCM |
| VoiceInputController | 应用服务 | 单轮状态机、session 隔离、快照、回调编排 | 不依赖 ArkUI；通过接口接收 gateway/parser/commit |
| VoiceExpressionParser | 纯业务 | 将受限中文算式完整转换或返回结构化错误 | 不访问 SDK、UI、历史 |
| SpeechRecognitionGateway | 端口 | 定义 start/cancel/dispose 与 outcome callback | 不暴露具体 SDK 类型给控制器 |
| CalculatorPage permission gate | View/平台边界 | 调用真实 HarmonyOS 权限框并在 grant 后创建/启动 gateway | grant 前 `gatewayStartCount=0` |
| HarmonySpeechRecognitionGateway | 适配器 | AudioCapturer、CoreSpeechKit 生命周期 | 仅前台、无音频持久化；权限由页面先行 gate |
| VoiceGatewayFactory | 装配边界 | release 固定返回 Harmony gateway；测试装配可替换为 scripted gateway | release 不读取 scenario Want/深链/隐藏 UI |
| Local FakeSpeechRecognitionGateway | 测试适配器 | parser/controller Local Test 注入最终文本、错误与时序 | 仅测试源码集，不进入 HAP |
| ScriptedSpeechRecognitionGateway | 设备测试适配器 | 在安装设备上执行 allowlisted 成功/失败/竞态脚本 | 仅测试 Ability/profile；记录 scenarioId 与源码 SHA，不接受任意生产输入 |
| CalculationCoordinator | 应用服务/现有逻辑抽取 | 对候选表达式原子计算并生成 history item | 失败不修改调用方状态 |

### 2.4 交互关系

| 交互 | 方向 | 接口 | 说明 |
|------|------|------|------|
| UI → Controller | 命令 | `start/cancel/retry` | 每次 start 生成新 session |
| UI permission gate → Factory/Controller | 顺序调用 | `requestPermissionsFromUser` 后 `create/start` | 授权结果返回前不得触发 gateway start |
| Controller → Gateway | 异步调用 | `start(sessionId)` | 权限通过后开始受控会话 |
| Gateway → Controller | 事件 | listening/recognizing/final/error | 仅当前 session 生效 |
| Controller → Parser | 同步调用 | `parse(text)` | 只处理 final 非空文本 |
| Controller → Coordinator | 同步调用 | `evaluateCandidate(expr)` | 返回成功快照或错误，不直接写 UI |
| UI → Preferences | 既有路径 | 成功提交历史 | 每个 session 最多一次 |
| Test Ability/profile → Factory | 测试装配 | scenario registry | 仅测试构建选择 scripted gateway；release 静态不可达 |

**数据流**：麦克风 PCM（内存）→ 在线识别文本→纯 parser→规范化候选→既有计算链→可见结果/历史。

**控制流**：用户开始→真实权限框→grant→gateway start→监听→识别→final→parse→evaluate→一次提交；任意错误/取消→cleanup→保留旧计算状态。测试装配以 `permissionGranted→gatewayStartInvoked→scriptedListening→uiListening` 证明权限顺序；真实 capturer/recognizer 成功由 AC-015 单独证明。

## 3. 变更原因

| 原因类型 | 说明 |
|----------|------|
| 业务需求 | 提供中文语音算式输入闭环 |
| 可靠性 | 外部识别异步且易失败，必须与页面/计算状态隔离 |
| 可测试性 | 设备与服务不可稳定用于每次 CI，需可注入端口和纯解析器 |
| 验收可达性 | Tester 已证明 local fake 不能驱动已安装页面；设备 UI 需要独立、封闭的测试装配 |
| 兼容性 | 复用既有计算/历史，避免形成第二套规则 |

## 4. 变更点

### 4.1 新增语音端口与平台适配器

- 新增 `SpeechRecognitionGateway` 契约与 Harmony 实现。
- 页面只在用户点击后申请 `MICROPHONE`，在线识别声明 `INTERNET`；不申请后台录音权限。
- 资源清理幂等，错误映射为权限拒绝、服务不可用、录音中断、无结果。

### 4.2 新增严格表达式解析器

- 词法层识别空白、数字、中文数位、点、四种运算词/符号和一元负号。
- 语法层只接受 `signedNumber operator signedNumber`，完整消费输入。
- 输出 ASCII `+ - * /` 规范式；未知词、多运算链、缺操作数、多小数点、超出首期数位范围均拒绝。

### 4.3 抽取原子计算协调器

- 将现有 `onEquals()` 的核心变为“候选输入→成功/错误结果”。
- 只有成功结果由页面一次性更新 expression/result/history。
- 手动等号和语音成功使用同一入口，保持格式和错误语义兼容。

### 4.4 扩展 CalculatorPage

- 延续 ArkUI V1 `@State`，加入 `voiceState/recognizedText/voiceError`。
- 入口置于普通计算模式的 ToggleRow 附近；监听时显示取消，失败显示重试。
- 页面消失和切换到不适用状态时清理当前会话。

### 4.5 增加 release-sealed 装配与设备测试 harness

- 页面不再直接构造 `CoreSpeechPlatformDriver`，改为从 `VoiceGatewayFactory` 取得端口实现；release 默认行为保持真实 Harmony gateway。
- Local Test fake 继续只验证 parser/controller；设备测试构建额外提供 allowlisted scripted scenarios，覆盖 success/empty/ambiguous/divideByZero/serviceUnavailable/interrupted/cancel-late/duplicate-start/duplicate-final。
- 测试 Ability/profile 加载同一 `CalculatorPage`，采集 UI 树、截图、事件与 Preferences delta；不复制页面实现。
- release HAP 必须通过包内容或装配测试证明 `releaseInjectionReachable=false`，不能通过 Want、深链、环境变量或隐藏控件启用 fake。
- 真实语音 AC 仍使用 release 默认 gateway；测试 harness 不得作为 AC-015 证据。

### 4.6 Tester 反馈迭代 2：权限顺序与真实服务分证

- 保持 release 生产路径不变：真实权限框 grant 后才 `VoiceGatewayProvider.create()` 并启动 controller。
- ohosTest 证据链增加权限动作时间点与 gateway `sessionStarted`/`listening` 的顺序关联；不得要求缺少 zh-CN engine 的模拟器产生 `capturerStarted/recognizerStarted`。
- AC-016 验证“授权前没有启动，授权后 test-only gateway 能驱动同一页面进入 listening”；AC-015 验证“真实 AudioCapturer/CoreSpeechKit 成功并得到 `123+456=579`”。两者均须通过，互不替代。
- 不增加生产诊断接口、任意 transcript 注入、后台权限、第三方服务或凭据。

## 5. 兼容性说明

| 现有功能 | 影响 | 兼容策略 |
|----------|------|----------|
| 手动输入和等号 | 内部提交逻辑重用 | 保持现有显示、错误文案和历史格式；加回归测试 |
| 科学模式 | 不扩展语音语法 | 手动科学计算不变；语音只支持四则二元表达式 |
| 绘图 | 无交互依赖 | 不修改 plot 模块与入口行为 |
| 历史 | 增加语音来源的普通条目 | 不改 `HistoryItem` Schema，不新增 source 字段 |
| 偏好 | 无新增配置 | 不迁移 Preferences |
| release 安全边界 | 新增测试装配 | fake/scenario registry 只进入测试构建；release 无激活参数、路由或 UI |

## 6. 迁移方案

本文档不涉及数据迁移。运行部署仍为单 entry HAP；测试时可附加测试 Ability/profile。回滚时移除 factory 的测试绑定并恢复 release 默认真实装配，不影响 Preferences 或历史数据。

## 7. 附录

### 7.1 关键架构决策

| 决策 | 选择 | 理由 |
|------|------|------|
| ADR-01 | 平台能力置于 gateway | 可测试、可降级、可替换 |
| ADR-02 | 严格二元语法 | 防止语音误猜导致错误计算，符合非目标 |
| ADR-03 | 候选计算原子提交 | 满足失败保留输入与历史恰好一次 |
| ADR-04 | 单 HAP 内新增目录 | 最小架构改动，无独立部署价值 |
| ADR-05 | release-sealed factory + test-only scripted gateway | 满足设备 UI 自动化，不向生产暴露通用注入后门 |
| ADR-06 | fake 与真实 E2E 分证 | 普通模拟器 `CreateEngineError` 只能证明 AC-010，不能替代真实语音 AC-015 |

### 7.2 参考

- Issue #52 原文
- 本地 HarmonyOS API 12 SDK：`@kit.CoreSpeechKit`、`@hms.ai.speechRecognizer.d.ts`
- `info.md`、`proposal.md`、`delta-spec.md`
