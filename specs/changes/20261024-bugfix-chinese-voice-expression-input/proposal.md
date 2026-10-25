# 中文语音输入算式并自动计算需求提案

## 1. 需求概述

### 1.1 基本信息

- **功能名称**：中文语音输入算式并自动计算
- **需求类型**：`bugfix`（工作流编排分类）；产品语义为“新增功能”
- **关联 Issue**：#52
- **关联全局文件**：`specs/spec.md` / `specs/arch.md` / `specs/design.md`

### 1.2 需求描述

在普通计算模式提供麦克风入口。用户说出包含阿拉伯数字或常见中文数字、四则运算词/符号和小数的单个算式后，应用展示原始识别文本，将其规范化为现有引擎可计算的表达式，自动计算并沿用现有历史记录逻辑。监听、识别、成功、失败、取消和权限拒绝均有明确可见状态；任何失败不得覆盖语音前的手动输入。

### 1.3 使用场景

用户不方便触屏时，在普通计算页面点击麦克风，说“123加456”“二十乘三”或“十点五减二点五”，确认屏幕上的识别文本、规范化表达式和结果。

### 1.4 预期效果

- 语音入口只在用户主动点击后启动前台本轮识别。
- 有效语音通过与手动输入相同的 `Expression → CalcEngine → NumberFormatter → HistoryItem` 计算链完成一次计算和一次历史写入。
- 权限拒绝、取消、无结果、歧义、除零、录音中断和服务不可用均安全结束，不覆盖进入语音前的表达式。
- 解析器与语音网关可注入，使 Tester 可在无麦克风/无在线服务时独立验证解析与 UI 状态。

### 1.5 背景与价值

#### 问题背景

原始基线只支持触屏按钮输入。PR #55 在 SHA `d904e4c3b8dc26c0490eeda5d43805f5a10310aa` 已加入 release 封闭的真实 gateway 和 ohosTest-only scripted UI harness。Tester run 114 在同一 SHA 上独立确认 73/73 Local Test、两类 HAP 构建、11 类 scripted 设备矩阵和权限拒绝/重试均通过；剩余失败是目标模拟器缺少可用 zh-CN CoreSpeechKit，导致 AC-015 无法取得真实语音成功证据，以及旧 AC-016 把“授权顺序”与“真实服务成功启动”错误耦合。本轮 PLANNING 将权限顺序改为真实权限框 + test-only gateway start 事件的确定性 oracle，真实 capturer/recognizer 成功仍仅由 AC-015 在能力可用环境证明；不修改产品源码或 `tasks.md`。

#### 需求价值

为不方便触屏的用户增加低步骤的算式输入方式，同时保留可核对文本和安全失败，避免识别误差破坏已有输入。

#### 核心问题

需要补齐前台语音采集与识别、中文算式确定性规范化、可观察状态、错误恢复，以及与既有计算/历史链路的单次集成。

#### 不做什么（边界）

不做连续对话、多轮追问、复杂自然语言题意理解、后台持续录音、录音留存、首期离线识别承诺、云服务自建或新增账号体系。

## 2. 竞品/参考方案分析

本次未执行可选竞品调研；Issue 已给出明确首期范围，且规划优先复用本地 HarmonyOS API 12 SDK 中已安装的 `@kit.CoreSpeechKit` 契约，避免扩大范围。

## 3. 需求解析报告（rq-parse）

### 3.1 意图分类

- **工作流类型**：缺陷修复（服从 `_orchestrator.change_type=bugfix`）
- **产品意图**：新增功能（Issue 标题 `feat` 且现有仓库无语音输入）
- **一句话概括**：为普通计算模式新增可取消、可恢复、可测试的中文语音算式输入闭环。

### 3.2 领域映射

- **UI/交互与状态管理**：麦克风入口、监听/识别/成功/失败状态、取消和重试。
- **系统能力/媒体处理**：麦克风权限、前台 PCM 录音、CoreSpeechKit 在线中文识别。
- **业务逻辑**：中文数字与运算符规范化、歧义拒绝、结果提交。
- **数据管理**：复用现有历史记录，无新增持久化模型。
- **测试基础设施**：识别网关和结果注入边界、解析单元测试、UI 自动化与真机证据分层。

### 3.3 影响层次

| 层次 | 变更类型 | 说明 |
|------|----------|------|
| 表现层 | modify | `CalculatorPage` 增加入口、识别文本和语音状态 UI |
| 业务层 | new/modify | 新增语音会话控制器与表达式规范化器；页面复用统一计算提交函数 |
| 数据层 | reuse | 复用 `HistoryItem` 和 `PreferencesStore.setHistory`，不新增表/偏好 |
| 基础设施 | new/modify | 新增可替换识别网关；模块声明 MIC/INTERNET 权限与用途资源 |

### 3.4 关键实体

- **数据实体**：`VoiceInputState`、`VoiceRecognitionOutcome`、`VoiceParseResult`；复用 `HistoryItem`。
- **页面实体**：`CalculatorPage`、语音状态区域、麦克风/取消/重试控件。
- **接口实体**：`SpeechRecognitionGateway`、`VoiceExpressionParser`、`abilityAccessCtrl`、`speechRecognizer`、`audio.AudioCapturer`。
- **事件实体**：开始、权限结果、监听开始、音频结束、识别结果、识别错误、取消、页面消失。

### 3.5 原始需求原子

| IR | 原文依据 | 触发操作 | 用户可观察结果 | 明示约束 |
|----|----------|----------|----------------|----------|
| IR-001 | 普通计算模式增加入口 | 点击入口 | 可发起语音输入 | 仅普通模式 |
| IR-002 | 监听中、识别中、成功、失败状态 | 发起并完成单轮会话 | 状态和控件按序更新 | 用户可见 |
| IR-003 | 首次按规范申请麦克风权限 | 首次点击并授权 | 授权前 gateway start 为 0；授权后才开始会话 | HarmonyOS 权限框 |
| IR-004 | 拒绝权限后的提示和重试 | 拒绝后点击重试 | 无录音/崩溃；说明和重试可见 | 用户主动重试 |
| IR-005 | 八种运算词/符号映射 | 输入 `加减乘除 + - × ÷` | 精确显示引擎兼容运算符 | 首期四则 |
| IR-006 | 口述阿拉伯数字 | 输入 `123加456` | `123+456` 和 `579` | 完整消费 |
| IR-007 | 常见中文整数/逐位数字 | 输入 `二十`、`二〇二四` 等 | 精确十进制规范式和结果 | 首期字表 |
| IR-008 | 中文口述小数 | 输入 `十点五减二点五` 等 | 精确小数规范式和结果 | 小数部分逐位 |
| IR-009 | 成功后保留原文、填入并计算 | 有效 final | 原文、规范式和结果同时可见 | 自动计算 |
| IR-010 | 无结果安全失败 | 空 final | 明确错误，旧算式保持 | 历史不变 |
| IR-011 | 歧义/非法语法安全失败 | 多运算链、未知词等 | 明确错误，旧算式保持 | 不猜测 |
| IR-012 | 除零安全失败 | `十除零` | 明确错误，旧算式/结果保持 | 历史不变 |
| IR-013 | 服务不可用安全失败 | create/start/busy 失败 | 明确错误、资源停止、旧算式保持 | 可重试 |
| IR-014 | 录音中断安全失败 | capturer 中断 | 明确错误、资源停止、旧算式保持 | 可重试 |
| IR-015 | 监听可取消 | 取消并收到迟到 final | 立即停止，不计算且忽略迟到结果 | 单会话 |
| IR-016 | 共用计算逻辑并写历史一次 | 有效 final/重复 final | 与手动结果一致，历史恰好 +1 | 失败 +0 |
| IR-017 | 注入/模拟独立测试 | 无 MIC/在线服务运行 local/device harness | 解析、UI、竞态矩阵确定执行 | release fake 不可达 |
| IR-018 | 真实语音 E2E 补证 | 能力预检通过后说 `123加456` | 真实权限→音频→识别→计算成功证据 | fake 不替代 |

### 3.6 可观察行为与验收风险

| IR | 前置状态 | 操作 | 状态变化 | 用户可见结果 | 失败/恢复 | 风险触发器 |
|----|----------|------|----------|----------------|-----------|------------|
| IR-001～002 | 普通页空闲 | 点击麦克风并完成会话 | idle→listening→recognizing→success/error | 入口/状态/控件同步 | 失败可重试 | user_visible,state_sync,integration |
| IR-003～004 | 权限未决定/拒绝 | 点击、允许/拒绝、重试 | grant 前 start=0；拒绝不录音 | 系统框、说明、重试 | 可恢复 | boundary,exception,environment |
| IR-005～008 | 获得 final 文本 | 完成严格解析 | 词符号、整数、小数归一 | 确切规范式/结果 | 非法转 IR-011 | normal,boundary,integration |
| IR-009 | 有效 final | 提交结果 | 原文保存、规范式提交 | 原文+表达式+结果 | - | user_visible,state_sync,integration |
| IR-010～014 | 原表达式存在 | 分别触发五类失败 | 不提交并清理 | 明确错误+旧状态 | 可重试 | exception,recovery,environment |
| IR-015 | 正在监听/识别 | 取消/迟到回调/重复点击 | active→idle，旧 session 失效 | 状态停止 | 不提交 | boundary,exception,state_sync |
| IR-016 | 历史 N 条 | final/重复 final/失败 | 成功提交一次，失败零次 | 历史 N+1/N | 幂等 | integration,state_sync |
| IR-017 | 无真实服务 | local fake/设备 test Ability | allowlisted 事件驱动同一页面 | UI/历史/事件可断言 | release fake 不可达 | environment,integration,user_visible |
| IR-018 | 能力预检通过 | 真实说“123加456” | 平台→解析→计算真实流转 | 状态链、原文、`123+456`、`579` | 能力不足记环境限制 | environment,integration |

### 3.7 模糊点与严重程度

| # | 描述 | 原严重度 | 自治处理 |
|---|------|----------|----------|
| 1 | 使用哪个语音服务及音频输入方式 | important | 采用 API 12 SDK 可用的 CoreSpeechKit 在线识别 + 前台 AudioCapturer；以网关隔离，安全可替换 |
| 2 | “常见中文数字表达”边界 | important | 首期支持零/〇、一至九、十百千万、两及逐位数字，小数点后逐位；不支持亿、分数和口语省略 |
| 3 | 歧义的判定 | important | 必须完整消费单个二元四则表达式；多运算链、未知词、缺操作数、多小数点一律拒绝 |
| 4 | 成功提示保留时长 | nice-to-have | 原始识别文本持续显示至下次语音或手动编辑；状态成功可被下一次操作替换 |
| 5 | Tester 如何在设备 UI 注入识别事件而不暴露生产后门 | important | 增加 release-sealed gateway factory；fake/scenario registry 只由测试构建或测试 Ability 装配，且必须与源码 SHA 可追溯 |
| 6 | 普通模拟器缺失 CoreSpeechKit 服务时是否以 fake 替代真实 E2E | important | 不替代；先做能力预检，AC-015 只在真实服务可用环境执行，能力不足继续按 AC-010 验证安全降级 |

### 3.8 复杂度评估

- **等级**：L
- **理由**：涉及 UI、权限、录音、外部识别、纯解析、计算/历史集成与测试注入，跨 3+ 模块和多层。

## 4. 需求澄清（rq-clarify）

用户已授权对安全、可逆且 Issue 内的普通歧义自主选择。本次未触发需人工确认的凭据、付费、隐私合规、不可逆或范围扩张事项。

### 4.1 已澄清的关键决策

| # | 问题 | 决策 | 来源/理由 |
|---|------|------|-----------|
| 1 | 识别能力 | `@kit.CoreSpeechKit` 在线中文识别，语言 `zh-CN`，音频由前台 AudioCapturer 提供 | 本地 SDK API 12 契约；不承诺离线 |
| 2 | 权限 | 仅在用户点击麦克风后请求 `ohos.permission.MICROPHONE`；拒绝不自动循环请求 | 最小权限与平台惯例 |
| 3 | 网络 | 声明 `ohos.permission.INTERNET` 供在线服务；网络/服务不可用统一可恢复错误 | 首期在线识别 |
| 4 | 语法 | 单个二元四则表达式；允许一元负号；完整消费输入 | 降低误算风险，不扩展为自然语言理解 |
| 5 | 成功提交 | 只接受最终结果；先解析、再替换表达式并调用同一计算函数一次 | 防止局部结果重复记历史 |
| 6 | 隐私默认 | 不持久化音频，不把原始识别文本写入额外存储/日志；仅当前页面内显示 | 最小数据处理 |
| 7 | 权限 gate 与真实语音如何分证 | AC-016 用真实权限框 + test-only gateway start/listening 事件证明 grant-before-start；AC-015 在能力环境证明真实 capturer/recognizer 与语义结果 | run 114 的服务缺失不应掩盖权限缺陷，也不能用 fake 替代真实链 |

### 4.2 待定假设

- 设备需支持 `SystemCapability.AI.SpeechRecognizer`；不支持时显示“语音服务不可用”，手动计算不受影响。
- 音频采用 16 kHz、单声道、16-bit PCM，以 640/1280 字节块写入识别引擎，具体 AudioCapturer source 与停止时序按 SDK 可用能力实现。
- `二〇二四` 等逐位读法按数字串处理；`一百零二` 等单位读法按中文整数处理；小数部分逐位解析。
- 识别结果允许空白和中文/英文标点清理，但不猜测未知词；“一百二”这类省略语义按严格规则拒绝，以避免误算。
- 页面离开、重复点击开始、引擎 busy 都先终止/拒绝本轮，且不修改计算状态。

### 4.3 功能边界

- **包含**：前台单轮中文语音；权限；四态/取消/重试；严格解析；统一计算与历史；依赖注入；自动化和真机验证点。
- **不包含**：连续对话、多轮语义、复杂题意、后台录音、录音文件、离线保证、第三方付费服务、服务端建设。

## 5. 特性清单

- **F1：语音入口与会话状态**：普通模式入口、状态、取消、重试和生命周期清理。
- **F2：权限与平台识别网关**：按需 MIC 权限、AudioCapturer、CoreSpeechKit 在线识别、服务错误映射。
- **F3：中文表达式规范化**：运算符、阿拉伯/中文整数与小数、严格语法和歧义拒绝。
- **F4：统一计算提交与恢复**：复用现有计算/格式化/历史逻辑；成功一次提交；失败保留快照。
- **F5：可测试性**：接口注入、纯解析器单测、UI fake、真机/模拟环境端到端证据。
- **F6：设备测试装配隔离**：同一页面可由设备测试构建装配 allowlisted scripted gateway；release 固定真实 gateway，不能从 Want、深链或隐藏 UI 开启 fake。

## 6. 系统架构概述

```text
CalculatorPage / Voice UI state
        │ user action + visible state
        ▼
VoiceInputController ──▶ SpeechRecognitionGateway (interface)
        │                         ├─ HarmonySpeechRecognitionGateway
        │                         │   ├─ abilityAccessCtrl
        │                         │   ├─ AudioCapturer
        │                         │   └─ CoreSpeechKit
        │                         └─ ScriptedSpeechRecognitionGateway (test build/Ability only)
        ▼
VoiceExpressionParser (pure)
        ▼
CalculatorPage.commitExpression()
        ▼
Expression → CalcEngine → NumberFormatter → History/Preferences
```

### 6.1 核心模块职责

| 模块 | 职责 | 备注 |
|------|------|------|
| Voice UI | 入口、状态、原始文本、错误、取消/重试 | 修改 CalculatorPage |
| VoiceInputController | 单会话状态机、快照、迟到回调隔离 | 新增，UI 无关 |
| SpeechRecognitionGateway | 权限后启动/取消/释放识别 | 新增接口与平台实现 |
| VoiceGatewayFactory | release 装配真实 gateway；设备测试装配 scripted gateway | 新增装配边界，生产路径封闭 |
| VoiceExpressionParser | 确定性规范化与错误分类 | 新增纯 ArkTS 模块 |
| Calculation submit path | 计算、格式化、历史恰好一次 | 从现有 onEquals 抽取复用 |

### 6.2 明确不涉及的模块

绘图算法、科学函数语法、Preferences Schema、导航结构、后台任务和远端服务端均不改变。

## 7. 需求规格摘要

- **R1/P0**：用户可主动开始/取消单轮语音，看到状态；关联 F1。
- **R2/P0**：按需获取 MIC 权限，拒绝可恢复；关联 F2。
- **R3/P0**：严格转换首期数字、运算词/符号和小数；关联 F3。
- **R4/P0**：最终识别结果经统一计算链提交，显示原文/规范式/结果，历史一次；关联 F4。
- **R5/P0**：所有明确失败均保留旧输入且不写历史；关联 F1/F2/F3/F4。
- **R6/P0**：解析与控制器可用 local fake 独立测试，设备 UI 可由隔离的测试装配执行完整矩阵；关联 F5/F6。
- **R7/P1**：真实语音平台链只能由能力预检通过的真机或等价环境补证，不能用 fake 代替；关联 F5。

## 8. 影响范围分析

| 模块 | 现有功能 | 新增/修改 |
|------|----------|-----------|
| `pages/CalculatorPage.ets` | 页面状态、计算、历史、布局 | 语音 UI/状态；抽取统一提交路径 |
| `voice/VoiceExpressionParser.ets` | 不存在 | 新增纯解析模块 |
| `voice/VoiceInputController.ets` | 不存在 | 新增会话状态机 |
| `voice/SpeechRecognitionGateway.ets` | 不存在 | 新增接口、平台实现及 fake seam |
| `module.json5` + string resources | VIBRATE 权限 | 新增 MIC/INTERNET 与用途文案 |
| `entry/src/test` / UI 测试 | 绘图单测 | 后续阶段新增解析/控制器/UI 测试 |
| gateway 装配/设备测试 harness | 页面直接 `new CoreSpeechPlatformDriver()`；fake 仅 `entry/src/test` | 增加 release-sealed factory 与 test-only scenario 装配，供安装包 UI 自动化 |

## 9. 复杂度评估

- **复杂度等级**：复杂
- **影响模块数**：6 类
- **架构变更**：是（新增平台适配边界和状态控制器，不改变应用模块部署）
- **数据模型变更**：仅运行时领域状态；无持久化 Schema 变化

| 制品 | 是否产出 |
|------|----------|
| proposal.md | 是 |
| delta-spec.md + acceptance-criteria.json | 是 |
| new-arch.md | 是 |
| delta-design.md | 是 |
| tasks.md | 否（明确禁止进入 IMPLEMENTING） |

## 10. 待解决问题

### 10.1 已定决策

所有 Issue 内的普通歧义及 Tester 反馈均已按 §4 的保守默认值解决并同步到 AC 契约。设备测试装配是对 IR-017 的验收可达性修正，不新增用户功能；AC-016 与 AC-015 分证是验证职责修正，不弱化真实语音要求。

### 10.2 待解决问题

无 PLANNING blocker。后续阶段需实现并验证测试装配隔离；AC-015 仍需由具备麦克风、网络与 zh-CN CoreSpeechKit 的环境提供真实证据。当前 Tester 模拟器的 `CreateEngineError` 是已记录的环境能力限制，不授权引入付费服务、凭据或放宽真实 E2E oracle。
