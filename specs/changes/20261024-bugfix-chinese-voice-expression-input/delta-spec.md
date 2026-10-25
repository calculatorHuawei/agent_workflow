# 中文语音输入算式并自动计算 — 增量需求 SPEC

---

## 1. 需求描述

| 设计资产 | 描述 |
|----------|------|
| IR标识 | IR-001～IR-018（按单一产品承诺原子化；权威文本见 `acceptance-criteria.json.source_requirements`） |
| 名称 | 中文语音输入算式并自动计算 |
| 描述 | 普通计算模式新增前台单轮中文语音输入，严格规范化后复用既有计算/历史链；失败可见且不破坏旧输入 |
| Who | 不方便触屏输入的计算器用户；执行自动化和真机验证的 Tester |
| Where | OpenCalc `entry` HAP 普通计算页面 |
| When | 用户主动点击麦克风；权限与设备/服务能力允许时 |
| Why | 降低触屏依赖，同时以可核对文本和安全失败控制识别误差风险 |
| What | 权限、监听/识别状态、中文数字与四则解析、自动计算、取消/恢复、可注入测试 |
| How | 可注入识别网关 + 严格纯 parser + 原子化统一计算提交 |
| 类别 | 设计类（工作流 bugfix；产品语义新增功能） |

### 价值

用户通过一次主动操作和一句中文算式获得与手动输入一致的结果；任何平台或语义失败都不损坏已有计算上下文。Tester 可将确定性业务验证与真实麦克风环境验证分离。

## 2. 术语与缩写

| 术语/缩写 | 定义 |
|-----------|------|
| 原始识别文本 | SpeechRecognizer 返回、尚未规范化的最终文本 |
| 规范化表达式 | 只含首期数字和 ASCII `+ - * /` 的引擎兼容表达式 |
| 单轮会话 | 用户点击开始至成功、失败或取消之间的一次语音输入 |
| Final result | `SpeechRecognitionResult.isFinal/isLast` 表示的可提交最终结果 |
| Gateway | 隔离权限、录音和语音服务的可替换端口 |
| 设备测试装配 | 与源码 SHA 可追溯、可安装到设备、仅测试 profile/Ability 可启用 scripted gateway 的 HAP/测试包 |
| AC | Acceptance Criterion，权威 ID 定义于 `acceptance-criteria.json` |

## 3. 系统上下文

### 目标系统

| 字段 | 内容 |
|------|------|
| 系统名称 | OpenCalc HarmonyOS entry HAP |
| 系统边界说明 | 页面、会话控制、文本解析、计算和历史属于应用内部；权限框、麦克风、AudioKit、CoreSpeechKit/在线服务属于外部平台能力 |

### 周边交互方清单

| 编号 | 外部系统名称 | 类型 | 接口类型 | 主要功能 |
|------|--------------|------|----------|----------|
| ES-01 | 终端用户 | 人 | UI/语音 | 开始、说话、取消、重试、核对结果 |
| ES-02 | HarmonyOS 权限管理 | 系统 | AbilityKit | MIC 授权/拒绝 |
| ES-03 | 设备麦克风/AudioKit | 设备/Kit | PCM 音频流 | 前台采集 16 kHz mono PCM |
| ES-04 | CoreSpeechKit | Kit/服务 | SDK | 中文音频转最终文本 |
| ES-05 | Tester scripted gateway | 测试系统 | 测试源码集/Ability 注入接口 | 无真实服务时在安装设备上注入 allowlisted 文本、错误和竞态 |

## 4. 需求描述

| 需求编号 | 需求名称 | 需求描述 | 设计人员 |
|----------|----------|----------|----------|
| R-VOICE-01 | 会话交互 | 入口、状态、取消、重试和生命周期清理 | MigBot Developer |
| R-VOICE-02 | 权限与识别 | 按需授权、前台录音、在线中文识别和平台错误降级 | MigBot Developer |
| R-VOICE-03 | 文本规范化 | 运算词/符号、中文/阿拉伯数与小数严格解析 | MigBot Developer |
| R-VOICE-04 | 计算提交 | 成功后显示原文、规范式、结果并历史一次 | MigBot Developer |
| R-VOICE-05 | 安全失败与测试 | 失败保持旧输入；业务与真实设备测试分层 | MigBot Developer |
| R-VOICE-06 | 设备 UI 测试装配 | release 固定真实网关；测试构建可在设备 UI 确定性执行成功、失败和竞态矩阵 | MigBot Developer |

## 5. 假设和约束

| 序号 | 约束类别 | 约束描述 | 对验收的影响 |
|------|----------|----------|----------------|
| 1 | 平台 | 目标 API 12 SDK 提供 CoreSpeechKit since API 11；设备仍可能缺 syscap/服务 | 必须覆盖 unavailable 并真机补证 |
| 2 | 权限 | 只在主动点击后申请 MIC；不申请后台麦克风 | 授权前不得启动录音；拒绝可重试 |
| 3 | 在线 | 首期 `online=0`，不承诺离线；声明 INTERNET | 无网/服务故障必须安全降级 |
| 4 | 语法 | 一个二元四则表达式，允许操作数一元负号，完整消费输入 | 多运算链或未知词拒绝而非猜测 |
| 5 | 数字 | 支持零/〇、一至九、两、十百千万、逐位数和逐位小数；不含亿、分数、量词、省略读法 | 表驱动测试锁定边界 |
| 6 | 隐私最小化 | 不持久化音频；原文仅当前页面展示；日志不记录音频/原文 | 不新增音频或原文存储验收 |
| 7 | 兼容 | 不改 HistoryItem/Preferences Schema、绘图/科学函数/手动输入结果 | 回归手动计算和历史格式 |
| 8 | 测试隔离 | scripted gateway 仅存在于测试源码集/测试 Ability/编译期测试 profile；release 不接受 Want、深链或隐藏点击激活 fake | 设备 UI 自动化可执行且不形成生产后门 |
| 9 | 环境证据 | 普通模拟器可能在 `createEngine` 失败；fake 证据不得替代真实服务 E2E | AC-015 只在 MIC、网络、zh-CN CoreSpeechKit 预检通过后执行 |

## 6. 分级规格

### 6.1 会话状态分级

| 状态 | 进入条件 | 可见信息 | 允许操作 | 退出条件 |
|------|----------|----------|----------|----------|
| idle | 无活动会话 | 麦克风入口 | 开始 | 点击开始 |
| requestingPermission | MIC 未授权且用户开始 | 权限请求/说明 | 系统选择 | 允许或拒绝 |
| listening | 授权且录音/识别已启动 | “监听中” | 取消 | 音频结束/错误/取消 |
| recognizing | 音频结束，等待最终文本 | “识别中” | 取消 | final/错误/取消 |
| success | parse 与计算成功 | 原文、规范式、结果、成功 | 再次开始/手动输入 | 下一操作 |
| error | 任一安全失败 | 明确错误与适用的重试 | 重试/手动输入 | 下一操作 |

### 6.2 数字与运算分级

| 类别 | 首期接受 | 示例 | 拒绝示例 |
|------|----------|------|----------|
| 运算符 | 加/减/乘/除，`+ - × ÷` | `二十乘三` | “乘以再加”多链 |
| 阿拉伯数 | 整数/小数，可带一元负号 | `-10.5` | `1.2.3` |
| 中文单位数 | 零/〇、一～九、两、十百千万 | `一百零二` | 亿、量词、分数 |
| 中文逐位数 | 数字逐位拼接 | `二〇二四` | 混入未知字 |
| 中文小数 | 点前整数，点后逐位 | `十点五`、`零点零五` | 空小数部分 |

## 7. 场景用例分析

> 下列 AC ID 与语义以同目录 `acceptance-criteria.json` 为权威；本章按场景镜像。

### 场景清单

| 变更类型 | 场景编号 | 场景名称 | 要素覆盖 | 优先级 |
|----------|----------|----------|----------|--------|
| ADD | SC-001 | 授权并完成有效语音计算 | UI/权限/录音/识别/解析/计算/历史 | 高 |
| ADD | SC-002 | 文本规范化边界 | parser/计算/UI | 高 |
| ADD | SC-003 | 失败、取消与恢复 | 权限/服务/录音/session/状态原子性 | 高 |
| ADD | SC-004 | 分层自动化与真机证据 | fake gateway/测试框架/设备 | 高 |
| ADD | SC-005 | 真实语音环境证据 | MIC/网络/CoreSpeechKit/设备证据 | 中 |

### ADD 场景 SC-001：有效语音计算闭环

#### 场景描述

用户在普通计算页主动发起语音输入。系统按需申请权限、展示监听/识别状态，只消费本轮最终结果，显示原文与规范化表达式，并通过既有计算链写入一条历史。

#### 场景要素分析

| 场景要素 | 取值 |
|----------|------|
| T 生命周期阶段 | 页面前台、单轮会话 |
| G 场景目标 | 低触屏成本完成一次确定性四则计算 |
| E 环境 | API 12 设备；MIC；在线 CoreSpeechKit 或测试 fake |
| A 参与者 | 用户、权限系统、麦克风、识别服务 |
| S 系统状态 | 普通模式、手动计算链可用 |

#### 用例 SC001-UC001：授权与状态流

- **Actor**：终端用户（主）、HarmonyOS 权限/语音服务（次）。
- **前置条件**：普通模式；无活动 session；手动输入可用。
- **最小保证**：授权结果返回前 `gatewayStartCount=0`；失败时旧表达式不变。
- **成功保证**：状态按 listening→recognizing→success 可见。
- **触发事件**：点击麦克风并允许权限。
- **主成功路径**：请求权限→允许→创建并启动 gateway→显示监听→识别→final。真实 AudioCapturer/recognizer 的成功启动只在 AC-015 能力环境中验收。
- **验证达成标准**：AC-001、AC-016。
- **Given/When/Then 摘要**：Given 权限未决定且 test-only gateway 可记录 start，When 用户开始并允许真实系统权限框，Then grant 前 start=0，grant 后按 `permissionGranted→gatewayStartInvoked→scriptedListening→uiListening` 可见。
- **Oracle/层级**：精确事件顺序；integration/ui/e2e；真实 capturer/recognizer 由 AC-015 分证。

#### 用例 SC001-UC002：成功解析、计算和历史一次

- **Actor**：终端用户（主）、识别服务（次）。
- **前置条件**：会话有效；历史 N 条。
- **最小保证**：局部/重复回调不提交。
- **成功保证**：原文可见；规范式/结果正确；历史 N+1。
- **触发事件**：最终文本 `123加456`。
- **主成功路径**：final→parse `123+456`→统一计算→显示 579→一次历史写入。
- **验证达成标准**：AC-007、AC-013。
- **Given/When/Then 摘要**：Given 可注入 final，When 注入 `123加456`（含局部/重复 final），Then 显示原文、`123+456`、`579` 且只新增一条历史。
- **Oracle/层级**：exact + history delta=1；integration/ui。

#### 需求分解列表（IR → SR）

| IR | SR | SR 名称 | 描述 | 关联功能 |
|----|----|---------|------|----------|
| IR-001～IR-004 | SR-01/SR-02 | 入口、状态与权限 | 状态、按需授权、生命周期 | F1/F2 |
| IR-009/IR-016 | SR-04 | 统一计算提交 | 原文/规范式/结果/历史一次 | F4 |

### ADD 场景 SC-002：规范化与数值边界

#### 场景要素分析

| 场景要素 | 取值 |
|----------|------|
| T | final 文本处理 |
| G | 无猜测地转换首期语法 |
| E | 纯 ArkTS，可无设备 |
| A | parser、统一计算链、Tester |
| S | 有效 session，旧输入已快照 |

#### 用例 SC002-UC001：运算词与整数映射

- **前置/触发**：注入八种运算词/符号以及阿拉伯/中文整数。
- **成功保证**：完整消费并输出 ASCII 运算式，结果准确。
- **验证达成标准**：AC-003、AC-004。
- **Given/When/Then 摘要**：Given fake final，When 注入映射表，Then 表达式与结果逐项等于 JSON oracle。
- **层级**：unit/integration/ui。

#### 用例 SC002-UC002：小数、逐位数和负数

- **前置/触发**：注入 `十点五减二点五`、`二〇二四减二千`、`负二加五`、`零点零五加一点九五`。
- **成功保证**：分别得到 JSON 指定规范式与 8/24/3/2。
- **验证达成标准**：AC-005、AC-018。
- **层级**：unit/integration/ui。

#### 用例 SC002-UC003：非法和歧义拒绝

- **最小保证**：不替换旧表达式、不更新结果/历史。
- **触发**：缺操作数、多运算链、未知词、多小数点。
- **验证达成标准**：AC-006。
- **Given/When/Then 摘要**：Given 旧表达式 `7*8` 和历史 N，When 注入非法文本，Then 明确错误且旧状态不变。

#### 需求分解列表（IR → SR）

| IR | SR | SR 名称 | 描述 | 关联功能 |
|----|----|---------|------|----------|
| IR-005～IR-008 | SR-03 | 中文表达式解析 | 词法、数值和严格二元语法 | F3 |
| IR-011 | SR-05 | 原子恢复 | parse 失败不提交 | F4 |

### ADD 场景 SC-003：失败、取消与恢复

#### 场景要素分析

| 场景要素 | 取值 |
|----------|------|
| T | 会话任意活动阶段 |
| G | 明确失败、立即清理、旧状态不变 |
| E | 权限拒绝、服务错误、录音中断、用户取消 |
| A | 用户、平台、gateway、controller |
| S | session active，可能存在迟到异步回调 |

#### 用例 SC003-UC001：权限拒绝与重试

- **最小保证**：不录音，表达式不变。
- **验证达成标准**：AC-002。
- **Given/When/Then 摘要**：Given 无 MIC 权限和 `12+3`，When 拒绝后点击重试，Then 显示说明/重试且不持续录音。

#### 用例 SC003-UC002：无结果、除零、服务故障和中断

- **最小保证**：旧 expression/result/history 不变，资源关闭。
- **验证达成标准**：AC-008、AC-009、AC-010、AC-011。
- **Oracle**：每类明确错误 + `historyDelta=0` + `recording=false`。

#### 用例 SC003-UC003：取消、迟到回调与重复点击

- **最小保证**：取消后不产生计算；最多一个活动 session/capturer。
- **验证达成标准**：AC-012、AC-017。
- **Given/When/Then 摘要**：Given 正在监听，When 取消并注入旧 session final 或重复点击，Then 立即停止、忽略迟到结果且无重复资源/历史。

#### 需求分解列表（IR → SR）

| IR | SR | SR 名称 | 描述 | 关联功能 |
|----|----|---------|------|----------|
| IR-003/IR-004/IR-013/IR-014 | SR-02 | 平台识别网关 | 权限、音频、识别、错误映射与清理 | F2 |
| IR-002/IR-010～IR-015 | SR-01/SR-05 | 会话与恢复 | session 隔离、取消、快照 | F1/F4 |

### ADD 场景 SC-004：确定性测试与设备 UI 证据

#### 场景要素分析

| 场景要素 | 取值 |
|----------|------|
| T | 开发/测试验收 |
| G | 环境限制不掩盖业务缺陷，且安装设备的页面行为可自动验证 |
| E | 无麦克风 CI、无 CoreSpeechKit 的模拟器、设备测试构建 |
| A | Tester、local fake、scripted gateway、测试 Ability/profile |
| S | release 装配封闭；测试装配可选择 allowlisted 场景 |

#### 用例 SC004-UC001：无设备确定性自动化

- **验证达成标准**：AC-014。
- **Actor**：Tester（主）、Local Test runner（次）。
- **前置条件**：没有麦克风或在线服务；parser/controller 通过端口接收 fake。
- **最小保证**：环境缺失不跳过业务断言，不把未执行写成通过。
- **成功保证**：成功、空结果、歧义、服务错误、中断和迟到回调均取得确定 oracle。
- **触发事件/主路径**：运行 Local Test→逐项注入事件→比较 parser、snapshot、commitCount。
- **Given/When/Then**：Given 无 MIC/服务，When 注入完整矩阵，Then 所有本地 oracle 确定通过且不需要设备。
- **Oracle/层级**：test matrix；unit/integration。

#### 用例 SC004-UC002：设备可见 scripted gateway 矩阵

- **Actor**：Tester（主）、测试 Ability/profile 与 HarmonyOS UI（次）。
- **前置条件**：安装与目标源码 SHA 一致的测试构建；release 包不可激活 scripted gateway。
- **最小保证**：失败/取消场景保持语音前 expression/result/history；测试退出后无活动 session/capturer。
- **成功保证**：成功、失败、取消、重复点击与重复 final 均可从 UI 树/截图/历史差异观察。
- **触发事件/主路径**：选择 allowlisted scenario→打开同一 CalculatorPage→点击语音入口/取消/重试→scripted gateway 发送事件→采集 UI 与 Preferences delta。
- **Given/When/Then**：Given 设备测试构建且无真实服务，When 执行 11 类 scripted 场景，Then UI oracle 与 JSON 合同一致，成功历史 +1，其他场景 +0。
- **验证达成标准**：AC-019，并承载 AC-001、003～014、016～018 的设备 UI 层证据。
- **Oracle/层级**：device UI matrix + releaseInjectionReachable=false；integration/ui/e2e。

#### 需求分解列表（IR → SR）

| IR | SR | SR 名称 | 描述 | 关联功能 |
|----|----|---------|------|----------|
| IR-017 | SR-06 | 测试注入与设备 UI 证据 | local fake、test-only scripted gateway、设备矩阵 | F5/F6 |

### ADD 场景 SC-005：真实语音环境证据

#### 场景要素分析

| 场景要素 | 取值 |
|----------|------|
| T | 验收阶段 |
| G | 证明真实权限、麦克风与 zh-CN 识别服务端到端可用 |
| E | 能力预检通过的 HarmonyOS 真机或等价环境 |
| A | Tester、权限系统、麦克风、CoreSpeechKit |
| S | release 默认真实 gateway，网络可用 |

#### 用例 SC005-UC001：真实中文语音 `123加456`

- **Actor**：Tester（主）、HarmonyOS/CoreSpeechKit（次）。
- **前置条件**：MIC、网络、zh-CN CoreSpeechKit `createEngine` 预检通过并授权。
- **最小保证**：预检失败时记录环境限制并执行 AC-010；不得用 fake 标记 AC-015 通过。
- **成功保证**：真实音频形成 listening→recognizing→success，并显示原文、`123+456`、`579`。
- **触发事件/主路径**：安装 release 候选→授权→点击麦克风→说“123加456”→采集 UI/日志/录屏。
- **Given/When/Then**：Given 真实能力可用，When 说“123加456”，Then 状态链和最终语义结果精确匹配。
- **验证达成标准**：AC-015。
- **Oracle/层级**：semantic evidence；e2e。

#### 需求分解列表（IR → SR）

| IR | SR | SR 名称 | 描述 | 关联功能 |
|----|----|---------|------|----------|
| IR-018 | SR-06 | 真实环境证据 | 能力预检、真实链路、环境限制显式记录 | F5 |

## 8. SR 功能模块点

### SR-01 会话交互与状态机〔Tier T1〕

| 字段 | 内容 |
|------|------|
| 需求场景 | SC-001、SC-003 |
| 需求价值 | 让异步语音行为可见、可取消、无竞态 |
| 需求描述 | 依赖 SR-02；唯一 session token；状态投影；重复点击收敛 |
| 关联用例 | SC001-UC001、SC003-UC003 |
| 功能点 | idle/permission/listening/recognizing/success/error；cancel；late callback guard |
| 验收场景与标准 | AC-001、AC-012、AC-017 |
| DFX/性能/功耗 | 单会话；页面离开/终态立即释放音频和引擎 |

### SR-02 HarmonyOS 识别网关〔Tier T0〕

| 字段 | 内容 |
|------|------|
| 需求场景 | SC-001、SC-003 |
| 需求价值 | 以最小权限安全访问平台语音能力 |
| 需求描述 | MIC 授权；16 kHz mono PCM；CoreSpeechKit zh-CN online；幂等 cleanup |
| 关联用例 | SC001-UC001、SC003-UC001/002 |
| 功能点 | permission、AudioCapturer、recognizer、error mapping |
| 验收场景与标准 | AC-002、AC-010、AC-011、AC-016 |
| DFX/性能/功耗 | 不后台录音、不持久化音频；640/1280 字节块；终态停止 |

### SR-03 中文表达式解析〔Tier T0〕

| 字段 | 内容 |
|------|------|
| 需求场景 | SC-002 |
| 需求价值 | 将不稳定识别文本转为确定、可验证的候选算式 |
| 需求描述 | 运算映射、中文/阿拉伯数、逐位小数、一元负号、完整消费 |
| 关联用例 | SC002-UC001/002/003 |
| 功能点 | tokenizer、ChineseNumberParser、binary grammar、ParseError |
| 验收场景与标准 | AC-003、AC-004、AC-005、AC-006、AC-018 |
| DFX/性能/功耗 | 纯同步 O(n)；无网络/设备依赖；未知输入 fail-closed |

### SR-04 统一计算与历史提交〔Tier T1〕

| 字段 | 内容 |
|------|------|
| 需求场景 | SC-001 |
| 需求价值 | 语音与手动结果、格式和历史保持一致 |
| 需求描述 | 抽取候选计算协调器；成功一次性提交，最终回调只消费一次 |
| 关联用例 | SC001-UC002 |
| 功能点 | Expression/CalcEngine/Formatter 复用；HistoryItem 一次写入 |
| 验收场景与标准 | AC-007、AC-009、AC-013 |
| DFX/性能/功耗 | 提交幂等；错误不产生部分 UI/持久化副作用 |

### SR-05 安全失败与状态恢复〔Tier T2〕

| 字段 | 内容 |
|------|------|
| 需求场景 | SC-002、SC-003 |
| 需求价值 | 外部服务/语义失败不破坏用户工作 |
| 需求描述 | session 开始保留快照；只有完整成功替换；错误可见可重试 |
| 关联用例 | SC002-UC003、SC003-UC001/002/003 |
| 功能点 | error taxonomy、snapshot、cleanup、manual fallback |
| 验收场景与标准 | AC-002、AC-006、AC-008～AC-012 |
| DFX/性能/功耗 | 清理幂等；所有异常 `historyDelta=0` |

### SR-06 可测试性与证据〔Tier T0〕

| 字段 | 内容 |
|------|------|
| 需求场景 | SC-004、SC-005 |
| 需求价值 | CI 不依赖真实语音，同时不省略平台 E2E |
| 需求描述 | local fake、release-sealed gateway factory、test-only scripted gateway、真实设备证据 |
| 关联用例 | SC004-UC001/002、SC005-UC001 |
| 功能点 | fake outcomes、设备 UI scenario registry、release 不可达校验、能力预检、真机证据模板 |
| 验收场景与标准 | AC-014、AC-015、AC-019 |
| DFX/性能/功耗 | 测试装配不进入 release 默认路径；环境限制显式报告；fake 不替代真实 E2E |

## 9. 需求 DFX 分析

### 9.1 威胁建模需求（消减措施清单）

| 措施编号 | 场景 | 风险面 | 消减措施 | 验证方式 |
|----------|------|--------|----------|----------|
| TM-01 | MIC 录音 | 过度采集 | 仅用户主动、仅前台、终态立即停止；无后台权限 | AC-002/012/016 审计+E2E |
| TM-02 | 识别文本 | 数据泄露 | 不持久化音频，不把原文/音频写日志；原文只在当前页面 | 代码审计 |
| TM-03 | 识别输出 | 注入/误算 | 白名单词法、完整消费、严格二元语法 | AC-006 单测/UI |

### 9.2 可靠性分析需求（FMEA 消减措施清单）

未调用可选 `dfr-fmea-general` skill；但基于 Issue 明示风险记录以下最小消减需求：

| 措施编号 | 故障模式 | 原因 | 影响 | 改进措施 | 影响功能 |
|----------|----------|------|------|----------|----------|
| CM-01 | 权限拒绝后仍录音 | gate 顺序错误 | 隐私/崩溃 | 授权事件必须先于 capturer start | SR-02 |
| CM-02 | 取消后迟到结果提交 | 异步竞态 | 错误覆盖/历史重复 | session token + consumed 标记 | SR-01/SR-04 |
| CM-03 | 解析猜测歧义 | 宽松自然语言规则 | 错误计算 | 完整消费、未知词 fail-closed | SR-03 |
| CM-04 | 服务/录音异常遗留资源 | cleanup 非幂等 | 麦克风占用/耗电 | finally/统一 cleanup；状态终态断言 | SR-02/SR-05 |
| CM-05 | 计算错误覆盖旧输入 | 先赋 expression 后求值 | 数据丢失 | 候选事务计算成功后一次提交 | SR-04/SR-05 |
| CM-06 | 设备测试 fake 误入生产 | 运行时隐藏开关或任意 Want 注入 | 绕过真实能力、生产攻击面 | 测试源码集/Ability/profile 隔离；release 包不可达与内容审计 | SR-06 |

### 9.3 DFX 质量属性遵从性分析

- **安全隐私韧性**：TM-01～TM-03；不新增账号、云存储或录音留存。
- **可靠可用可维**：结构化错误码仅用于状态映射；不记录原始语音内容；手动输入始终可用。
- **可服务性**：服务 unavailable/busy 为用户可理解错误与重试，不自动无限重试。
- **生命周期**：页面消失、取消、错误、成功均调用幂等清理。
- **节能减排**：只有活动会话占用麦克风/网络；终态立即释放。
- **可制造可供应**：不新增第三方包或付费服务。
- **功能安全**：非安全关键功能；fail-closed 防止歧义误算。

## 10. 系统需求列表（SR）

| SR | IR | 名称 | 系统对外能力行为 | 关联用例 | 可验证标准 | 优先级 |
|----|----|------|------------------|----------|------------|--------|
| SR-01 | IR-001,002,015 | 会话交互与状态机 | 入口、可见状态、取消、单会话 | SC001-UC001,SC003-UC003 | AC-001,012,017 | 高 |
| SR-02 | IR-003,004,013,014 | HarmonyOS 识别网关 | 按需权限、识别、错误降级 | SC001-UC001,SC003-UC001/002 | AC-002,010,011,016 | 高 |
| SR-03 | IR-005～008,011 | 中文表达式解析 | 规范化或明确拒绝 | SC002-UC001/002/003 | AC-003～006,018 | 高 |
| SR-04 | IR-009,012,016 | 统一计算与历史提交 | 显示原文/规范式/结果，历史一次 | SC001-UC002,SC003-UC002 | AC-007,009,013 | 高 |
| SR-05 | IR-010～015 | 安全失败与恢复 | 旧状态不变、资源清理、可重试 | SC002-UC003,SC003-* | AC-002,006,008～012 | 高 |
| SR-06 | IR-017,018 | 可测试性与证据 | local 自动化+设备 UI scripted matrix+真机补证 | SC004-*,SC005-* | AC-014,015,019 | 高 |

## 11. 验收总表（IR × UC × SR × AC × Evidence 追溯）

| IR | SR/Tier | 用例 | AC | 类别 | 用户可观察结果/Oracle | 验证层级 | 环境 |
|----|---------|------|----|------|-----------------------|----------|------|
| IR-001,002 | SR-01/T1 | SC001-UC001 | AC-001 | normal | 入口可用；listening→recognizing→success | integration/ui/e2e | 真机/fake |
| IR-003,004 | SR-02/T0 | SC003-UC001 | AC-002 | recovery | denied、无录音、旧表达式、retry | integration/ui/e2e | 真实权限框 |
| IR-005 | SR-03/T0 | SC002-UC001 | AC-003 | normal | 八种映射精确表 | unit/integration/ui | fake |
| IR-006,007 | SR-03/T0 | SC002-UC001 | AC-004 | normal | 阿拉伯/中文整数精确表 | unit/integration/ui | fake |
| IR-008 | SR-03/T0 | SC002-UC002 | AC-005 | boundary | `10.5-2.5=8` | unit/integration/ui | fake |
| IR-011 | SR-03/05 | SC002-UC003 | AC-006 | exception | 明确错误；expression/history 不变 | unit/integration/ui | fake |
| IR-009,016 | SR-04/T1 | SC001-UC002 | AC-007 | normal | 原文、123+456、579 | integration/ui | fake |
| IR-010 | SR-05/T2 | SC003-UC002 | AC-008 | exception | 空结果错误，旧输入/历史不变 | integration/ui | fake |
| IR-012,016 | SR-04/05 | SC003-UC002 | AC-009 | exception | 除零错误，旧状态/历史不变 | integration/ui | fake |
| IR-013,014 | SR-02/05 | SC003-UC002 | AC-010,011 | recovery | 服务/录音错误、资源停、旧输入 | integration/ui/e2e | fake+设备 |
| IR-002,015 | SR-01/T1 | SC003-UC003 | AC-012,017 | exception/boundary | 取消忽略迟到；单 session | integration/ui/e2e | fake+设备 |
| IR-016 | SR-04/T1 | SC001-UC002 | AC-013 | boundary | partial/重复 final 后 historyDelta=1 | integration/ui | fake |
| IR-017 | SR-06/T0 | SC004-UC001 | AC-014 | compatibility | 无 MIC 的 parser/controller 确定性矩阵 | unit/integration | CI/fake |
| IR-018 | SR-06/T0 | SC005-UC001 | AC-015 | normal | 真实语音 123+456=579 与状态证据 | e2e | 能力预检通过的真机/等价环境 |
| IR-003 | SR-02/T0 | SC001-UC001 | AC-016 | normal | grant 前 start=0；grant→gatewayStart→scriptedListening→UI | integration/ui/e2e | 真实权限框+test assembly |
| IR-007,008 | SR-03/T0 | SC002-UC002 | AC-018 | boundary | 逐位数字、负数、小数精确表 | unit/integration/ui | fake |
| IR-017 | SR-06/T0 | SC004-UC002 | AC-019 | normal | 设备 UI 11 类场景可执行；release fake 不可达 | integration/ui/e2e | 设备测试构建 |

## 12. 关键路径与依赖

| 路径/依赖 | 说明 |
|-----------|------|
| 权限关键路径 | click→MIC grant→gateway start；grant 前 gatewayStartCount=0（AC-016）；真实 capturer/recognizer 成功由 AC-015 的能力环境证明 |
| 成功关键路径 | final current session→parse→candidate evaluation→atomic UI/history commit |
| 失败关键路径 | error/cancel→invalidate session→cleanup→visible error/idle→old state |
| 平台依赖 | AbilityKit、AudioKit、CoreSpeechKit `SystemCapability.AI.SpeechRecognizer`、INTERNET |
| 内部依赖 | Expression、CalcEngine、NumberFormatter、ErrorFlags、PreferencesStore |
| 测试依赖 | Hypium local fake；test-only device scripted gateway；真实 E2E 由能力预检通过的环境补证 |

## 13. 待确认规格清单

| 序号 | 待确认项 | 建议默认值 | 备注 |
|------|----------|------------|------|
| 1 | 不同目标设备 CoreSpeechKit 服务可用性 | 运行时探测并显示 unavailable；真实 E2E 前先做环境预检 | 当前模拟器 CreateEngineError 已验证安全降级；不构成 Planning blocker |
| 2 | 真机 AudioCapturer 最佳 bufferSize | 使用 SDK 推荐值并切分为 640/1280 字节写入块 | 实现/设备验证项，不改变产品语义 |
| 3 | 成功状态视觉持续时间 | 保持至下一次语音或手动编辑 | 可逆 UI 默认值 |

---

> JSON AC 合同：`acceptance-criteria.json`（10 个原子 IR、19 个 feature-level AC）。
