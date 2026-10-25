# 中文语音输入算式并自动计算 - 代码仓理解

## 1. 基本信息

- **需求类别**：工作流为 bugfix；代码事实表明是新增功能
- **分析时间**：2026-10-25（基于 PR #55 SHA `d904e4c3b8dc26c0490eeda5d43805f5a10310aa` 与 Tester run 114 复核）
- **项目根**：`opencalc/`
- **分析范围**：`entry` HAP 的 CalculatorPage、计算引擎、表达式清洗、历史持久化、权限与构建配置、测试入口
- **重点**：现有统一计算链的复用边界、语音平台隔离、失败时状态原子性、可注入测试

## 2. 模块架构

```text
EntryAbility
  └─ Index / CalculatorPage (@Entry @Component, ArkUI V1 state)
       ├─ Expression.getCleanExpression()
       ├─ CalcEngine.evaluate()
       ├─ NumberFormatter.format()
       ├─ PreferencesStore (history/preferences)
       └─ FunctionPlotter / PlotAxis
```

| 模块 | 路径 | 现有职责 | 与需求关系 |
|------|------|----------|------------|
| 主页面 | `entry/src/main/ets/pages/CalculatorPage.ets` | 输入、展示、计算提交、历史、设置、绘图、语音 UI | `onVoiceStart()` 等待真实系统权限结果后才调用 `VoiceGatewayProvider.create()` 与 controller start |
| 表达式清洗 | `calculator/Expression.ets` | `×/÷`→`*/`、隐式乘法、括号/百分比等 | 规范化输出可使用 UI 运算符或引擎符号，最终仍走该层 |
| 计算引擎 | `calculator/Calculator.ets` | 递归下降解析、四则/科学函数、错误旗标 | 语音不得复制计算器；直接复用 |
| 错误状态 | `model/ErrorFlags.ets` | 除零、语法、定义域等全局旗标 | 语音计算错误映射为明确错误且不落历史 |
| 历史/偏好 | `preferences/PreferencesStore.ets` | JSON 历史持久化和裁剪 | 复用一次写入，不新增 Schema |
| 模块声明 | `entry/src/main/module.json5` | EntryAbility、VIBRATE/MIC/INTERNET 权限 | release 不注册测试 Ability；权限用途资源已存在 |
| release 装配 | `voice/VoiceGatewayFactory.ets` | release 默认真实 gateway；EntryAbility 启动时重新封闭 | `releaseInjectionReachable=false`，不接受 Want/URI/transcript |
| 设备测试入口 | `entry/src/ohosTest/ets/testability/VoiceTestAbility.ets` | allowlisted scenario 装配 scripted gateway 后加载同一 CalculatorPage | 11 类 UI 场景已由 Tester run 114 独立执行 |
| 本地测试入口 | `entry/src/test/List.test.ets` | Hypium 聚合 parser/controller/factory/release seal/matrix tests | exact HEAD 73/73 通过 |

## 3. 接口与契约

### 3.1 现有关键接口

| 接口 | 位置 | 契约/行为 |
|------|------|-----------|
| `Expression.getCleanExpression(calculation, '.', ',')` | `Expression.ets` | 将 UI 表达式转换为引擎语法，补隐式乘法与括号 |
| `CalcEngine.evaluate(equation, isDegree, varX?)` | `Calculator.ets` | 返回数值并通过 `ErrorFlags` 报告语义错误 |
| `NumberFormatter.format(...)` | `NumberFormatter.ets` | 按现有国际数字格式输出结果 |
| `CalculatorPage.onEquals()` | `CalculatorPage.ets:94` | 当前唯一计算+历史提交闭环，但直接读取/修改页面状态 |
| `PreferencesStore.setHistory(items)` | `PreferencesStore.ets` | 按偏好上限裁剪并 flush JSON |

### 3.2 本地 SDK 平台契约（只读核验）

| 能力 | SDK 定义 | 最低版本/约束 |
|------|----------|---------------|
| 语音识别 | `@kit.CoreSpeechKit` → `speechRecognizer` | since 4.1.0(11)，syscap `SystemCapability.AI.SpeechRecognizer` |
| 创建引擎 | `speechRecognizer.createEngine({ language, online })` | `online: 0` 表示在线；busy/unavailable 可抛 BusinessError |
| 会话 | `setListener`、`startListening`、`writeAudio`、`finish`、`cancel`、`shutdown` | `writeAudio` 数据块必须为 640 或 1280 字节 |
| 结果 | `SpeechRecognitionResult` | `result`、`isFinal`、`isLast`；只能最终结果触发提交 |
| 权限 | `abilityAccessCtrl.createAtManager().requestPermissionsFromUser(...)` | MIC 为 user_grant，since API 8 |
| 录音 | `@kit.AudioKit` / AudioCapturer | 需 `ohos.permission.MICROPHONE`；前台短时采集 |

### 3.3 调用约束

- 必须先权限通过，再创建/启动录音与识别。
- 必须先 `setListener` 再 `startListening`；每轮使用唯一 sessionId。
- 只有当前 session 且 `isFinal`/`isLast` 的非空结果可进入解析；取消后回调必须丢弃。
- 页面离开必须停止捕获、取消识别并释放资源。
- 计算前 `ErrorFlags.reset()`；只有无错误时才更新结果和历史。

## 4. 构建与集成

- **项目类型**：HarmonyOS Stage 模型、单 `entry` HAP、ArkTS/ArkUI。
- **SDK**：`compatibleSdkVersion` / `targetSdkVersion` 均为 5.0.0(12)。
- **状态管理**：`@State` V1；新增 UI 状态需延续同一范式。
- **依赖**：entry 无运行时 OHPM 依赖；CoreSpeechKit/AudioKit/AbilityKit 来自 SDK Kit，不引入第三方服务包。
- **构建入口**：`opencalc/hvigorfile.ts`、`build-profile.json5`、`entry/hvigorfile.ts`。
- **交付**：仍为单 entry HAP；不新增 HAR/HSP/ExtensionAbility。
- **Tester 实证**：目标模拟器 HarmonyOS 6.1/API 24 在权限通过后由 CoreSpeechKit 记录服务不可用；页面正确显示服务错误并保留输入，但无法进入真实 listening。该事实证明 SDK 类型存在不等于运行环境提供 zh-CN engine。
- **装配现状**：release 由 `ReleaseVoiceGatewayFactory` 创建真实实现；ohosTest 的 `VoiceTestAbility` 仅接受 allowlist scenarioId 并绑定 scripted factory，销毁时恢复 release factory。Tester 已证明 release HAP 无 scripted 激活符号。
- **AC-016 证据缺口**：当前设备矩阵记录 `sessionStarted`，权限拒绝/重试另有真实系统框证据，但旧 oracle 要求在 production service 可用后看到 `capturerStarted/recognizerStarted`，把权限顺序与 AC-015 的外部服务前置耦合。新设计以真实权限框时间线、授权前 `gatewayStartCount=0`、授权后 `gatewayStartInvoked→scriptedListening→uiListening` 验证权限 gate；真实 capturer/recognizer 成功留给 AC-015。

## 5. 影响范围

| 模块/文件 | 影响内容 | 风险 |
|-----------|----------|------|
| `CalculatorPage.ets` | 新状态、控件、会话生命周期；抽取统一计算提交 | 页面已较大，异步回调易产生陈旧状态和重复历史 |
| 新 `voice/` 目录 | parser、controller、gateway/model | 需保持纯层与平台层边界，避免测试依赖设备 |
| `module.json5` | MIC/INTERNET 权限及 usedScene | 权限用途/场景声明错误会导致授权或审核失败 |
| `string.json` | 权限说明与 UI 文案 | 当前页面大量硬编码中文；本变更至少权限 reason 必须资源化 |
| tests | parser/controller 单测及 UI fake 测试 | 本地 Hypium 与真机平台能力需分层 |
| gateway factory + device UI harness | release 默认真实实现；测试构建注入脚本 gateway | 必须防止 fake 被生产 Want/深链/隐藏 UI 激活；测试包需记录源码 SHA/场景 ID |

## 6. 约束清单

| 约束 | 来源 | 遵守方式 |
|------|------|----------|
| 失败不覆盖旧表达式 | Issue | 会话开始保存快照；解析成功且计算成功后才提交 |
| 历史恰好一次 | Issue/现有 onEquals | 抽取 `commitExpression`，最终结果一次调用；session 消费标记防重入 |
| 可取消且无迟到结果 | Issue | session token；cancel 后失效，清理 audio/engine |
| 最小权限 | 用户指令 | 只新增 MIC 与在线服务必要 INTERNET；不申请后台麦克风 |
| 不持久化音频 | 最小数据原则 | PCM 只在内存流转；停止后释放；日志不包含音频/原文 |
| 向后兼容 | 用户指令 | 手动输入、科学模式、绘图、历史格式与偏好 Schema 不变 |
| 严格 ArkTS | 现有仓库/SDK | 明确类型、无动态对象滥用；接口驱动 fake |
| 测试装配隔离 | IR-017/Tester 反馈 | release 工厂固定真实 gateway；scripted gateway 只由测试源码集/测试 Ability 或编译期 profile 装配 |
| 真实证据不可替代 | IR-018 | fake 只证明业务/UI；AC-015 必须在麦克风、网络、zh-CN CoreSpeechKit 能力预检通过后执行 |

## 7. 可复用组件

| 组件 | 位置 | 复用方式 |
|------|------|----------|
| `Expression` | `calculator/Expression.ets` | 规范式进入计算前统一清洗 |
| `CalcEngine` | `calculator/Calculator.ets` | 手动和语音共用求值 |
| `NumberFormatter` | `calculator/NumberFormatter.ets` | 共用展示格式 |
| `ErrorFlags` | `model/ErrorFlags.ets` | 共用除零/语法等错误分类 |
| `PreferencesStore` | `preferences/PreferencesStore.ets` | 共用历史裁剪/持久化 |
| 主题 getter | `CalculatorPage.ets` | 新语音控件沿用颜色与响应式尺寸 |

## 8. 关键实现现状

- `onEquals()` 同时承担清洗、求值、错误映射、格式化和历史写入；若语音直接设置 `expression` 后调用它，可复用逻辑，但无法在失败时保证旧表达式原子保留。因此设计要求抽取接收候选表达式的纯提交结果/事务式函数，成功后再赋页面状态。
- 表达式清洗已将 `×`/`÷` 映射成 `*`/`/`；语音 parser 为满足 AC 显示 `+ - × ÷` 还是 ASCII 的问题，采用统一显示 ASCII `+ - * /`，之后仍通过 `Expression`，与验收 `123+456` 一致。
- `CalcEngine` 除零通过 `ErrorFlags.division_by_0` 报告；语音候选发生除零时不得修改 expression/result/history。
- 历史插入由页面构造新数组并调用 Preferences；必须防止 partial/final 多次回调导致重复条目。

## 9. 风险与测试

| 风险 | 缓解 | 测试策略 |
|------|------|----------|
| 识别服务/网络/设备不可用 | 网关错误分类与可见重试，手动功能保持 | fake 错误 UI；真机补证 |
| 取消与最终回调竞态 | session token、单次消费、幂等 cleanup | controller 单测：cancel 后注入 final |
| 中文数字歧义误算 | 严格语法、完整消费、无猜测 | 表驱动 parser 单测 |
| 权限拒绝后错误启动录音 | 权限 gate | fake permission denied UI + 资源未启动断言 |
| 旧输入被覆盖 | 候选计算事务/快照 | 每类异常断言 expression/result/history 不变 |
| 历史重复 | 仅 final current session 提交一次 | partial+duplicate final 测试 |
| 页面状态未刷新 | 所有可见字段为 `@State` | UI 自动化逐状态验证 |
| fake 仅在 Local Test，设备 UI 矩阵不可执行 | release-sealed `VoiceGatewayFactory` + device-installable test harness | 在设备 UI 逐项执行成功、失败、取消、重复点击、重复 final、页面与 Preferences 历史 delta |
| 测试入口误入生产包 | 测试依赖放入独立测试源码集/Ability/profile；release 构建静态校验无 scenario registry/激活参数 | 对 release HAP 做不可达断言和包内容审计 |

## 10. 关键发现与建议

1. 仓库没有语音相关既有机制，需新增小型分层，但无需拆分 HAP。
2. CoreSpeechKit SDK 契约存在且兼容 API 12；在线识别不等于所有测试环境可用，因此注入边界是验收必要条件。
3. 最大兼容性风险不是 parser，而是当前 `onEquals()` 的非事务式页面副作用；先设计统一候选提交结果，再接 UI，可同时保护手动与语音路径。
4. Tester run 114 已确认 parser/controller/UI harness 不是剩余缺陷来源：73/73 Local Test、11 类设备 UI scripted 矩阵、权限拒绝/重试与 release 封闭性均通过。
5. 剩余两项应分证：AC-016 用真实权限框 + test-only gateway 事件验证 grant-before-start；AC-015 仍须在 MIC、网络、zh-CN CoreSpeechKit 全部可用的环境验证真实音频链。
6. 本阶段仅修订 Planning 制品，没有修改上述产品文件、测试源码、构建配置或 `tasks.md`。
