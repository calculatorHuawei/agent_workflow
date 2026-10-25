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

原始基线只支持触屏按钮输入。PR #55 已加入语音实现，但 Tester 在 SHA `4af7209` 上发现新的验收缺口：授权后目标模拟器的 CoreSpeechKit `createEngine` 失败，应用只能进入服务不可用恢复分支；同时 fake gateway 只存在于 Local Test，安装到设备的页面没有可由 UI 自动化驱动的确定性注入装配，导致成功、取消、重复点击、历史与失败矩阵无法取得设备 UI 证据。本轮 PLANNING 只修订需求与设计，不修改产品源码。

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
| IR-001 | 普通计算模式增加入口和四类状态 | 点击麦克风 | 看到监听中、识别中、成功或失败 | 普通模式、有明确状态 |
| IR-002 | 首次申请麦克风权限；拒绝提示和重试 | 首次点击或拒绝后重试 | 系统权限请求/说明；不录音、不崩溃 | HarmonyOS 规范 |
| IR-003 | 运算词与符号映射 | 识别到加减乘除或 `+ - × ÷` | 显示引擎兼容的规范化表达式 | 首期四则运算 |
| IR-004 | 阿拉伯/常见中文数字和小数 | 说出数字表达 | `二十`→`20`、`十点五`→`10.5` | 拒绝不确定语法 |
| IR-005 | 成功后填入、计算并保留识别文本 | 完成有效识别 | 同时看到原文、规范式和结果 | 自动计算 |
| IR-006 | 多类失败安全结束且不覆盖旧输入 | 发生无结果/歧义/除零/服务故障/中断 | 明确错误；旧表达式保持 | 安全失败 |
| IR-007 | 监听可取消 | 点击取消 | 本轮立即结束且不产生结果 | 不提交迟到回调 |
| IR-008 | 与手动输入共用逻辑、历史一次 | 有效语音完成 | 结果按现有规则展示；新增一条历史 | 恰好一次 |
| IR-009 | 可注入/模拟识别结果独立验证解析与 UI | Tester 在无真实语音服务环境运行本地测试或设备测试构建 | 本地 parser/controller 与设备 UI 成功/失败/竞态矩阵均可确定执行 | release 不得暴露 fake 激活入口 |
| IR-010 | 在有能力环境补充真实语音证据 | Tester 在预检通过的真机或等价环境说话 | 真实权限、麦克风、识别、解析、计算链取得端到端证据 | fake 不得替代真实链路 |

### 3.6 可观察行为与验收风险

| IR | 前置状态 | 操作 | 状态变化 | 用户可见结果 | 失败/恢复 | 风险触发器 |
|----|----------|------|----------|----------------|-----------|------------|
| IR-001 | 普通计算页空闲 | 点击麦克风 | idle→listening→recognizing→success/error | 状态文本与控件同步 | 失败可重试 | user_visible,state_sync,integration |
| IR-002 | 权限未决定/已拒绝 | 点击麦克风/重试 | 不得在授权前进入 listening | 权限说明 | 拒绝可重试 | exception,environment |
| IR-003 | 获得识别文本 | 完成解析 | 运算词/符号归一 | 确切规范式 | 未知字符拒绝 | boundary,integration |
| IR-004 | 获得数字短语 | 完成解析 | 中文数字转十进制 | 确切数字/小数 | 多小数点等拒绝 | boundary |
| IR-005 | 有效文本 | 最终识别结果 | 原文保存、规范式提交 | 原文+表达式+结果 | - | user_visible,state_sync,integration |
| IR-006 | 原表达式存在 | 发生异常 | 回滚到快照 | 错误+旧表达式 | 可再次发起 | exception,recovery |
| IR-007 | 正在监听/识别 | 点击取消 | active→idle/cancelled | 状态停止 | 忽略迟到回调 | exception,state_sync,environment |
| IR-008 | 历史 N 条 | 有效语音完成 | 调用统一计算提交一次 | 历史 N+1 | 错误不写历史 | integration,state_sync |
| IR-009 | 无真实麦克风/服务 | 运行本地 fake 或设备测试装配 | 受控脚本事件驱动同一页面状态 | UI 树/截图/历史差异可断言 | release 构建不可激活 fake | environment,integration,user_visible,state_sync |
| IR-010 | 能力预检通过的真机/等价环境 | 真实说“123加456” | 平台→解析→计算真实流转 | 状态链、原文、`123+456`、`579` | 能力不足只记录环境限制，不伪造通过 | environment,integration |

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

所有 Issue 内的普通歧义及 Tester 反馈均已按 §4 的保守默认值解决并同步到 AC 契约。设备测试装配是对 IR-009 的验收可达性修正，不新增用户功能。

### 10.2 待解决问题

无 PLANNING blocker。后续阶段需实现并验证测试装配隔离；AC-015 仍需由具备麦克风、网络与 zh-CN CoreSpeechKit 的环境提供真实证据。当前 Tester 模拟器的 `CreateEngineError` 是已记录的环境能力限制，不授权引入付费服务、凭据或放宽真实 E2E oracle。
