# 应用报告

## 应用信息

- 变更类型：bugfix（编排分类；产品语义为新增功能）
- 变更名称：中文语音输入算式并自动计算
- 关联 Issue：#52
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 应用日期：2026-10-24
- 分支：`agent/issue-52-task-51`

## 代码完成情况

| 任务 | 状态 | 完成时间 |
|------|------|----------|
| Task 1.1 语音领域模型、端口与 fake | ✅ 完成 | 2026-10-24 |
| Task 1.2 中文数字与小数解析 | ✅ 完成 | 2026-10-24 |
| Task 1.3 严格二元表达式规范化 | ✅ 完成 | 2026-10-24 |
| Task 2.1 无副作用候选计算协调器 | ✅ 完成 | 2026-10-24 |
| Task 2.2 会话状态机与成功/失败编排 | ✅ 完成 | 2026-10-24 |
| Task 2.3 取消、迟到、重复 final 与并发保护 | ✅ 完成 | 2026-10-24 |
| Task 3.1 麦克风/网络权限与权限适配 | ✅ 完成 | 2026-10-24 |
| Task 3.2 AudioCapturer 与 CoreSpeechKit 网关 | ✅ 完成 | 2026-10-24 |
| Task 4.1 手动/语音统一计算与历史提交 | ✅ 完成 | 2026-10-24 |
| Task 4.2 入口、状态、取消/重试与生命周期 | ✅ 完成 | 2026-10-24 |
| Task 5.1 无设备自动化验收矩阵 | ✅ 完成 | 2026-10-24 |
| Task 5.2 构建回归与 E2E 交接 | ✅ 完成（真机证据待 Tester） | 2026-10-24 |

## 测试结果

- 单元/集成测试：通过，64/64，0 failure，0 error
- 构建：通过，`BUILD SUCCESSFUL`
- Lint：通过（DevEco CodeLinter 退出码 0，0 error；275 个存量/风格 warning）
- Hvigor lint：项目未注册 `lint` task，真实命令已执行并记录该工具限制
- 真机 E2E：未在 Developer 环境执行；按 AC-015 交由具备麦克风/CoreSpeechKit 的 Tester 环境补证

## TDD 执行记录

| 任务 | RED | GREEN | REFACTOR |
|------|-----|-------|----------|
| Task 1.1～2.3 | ✅ 新语音模块缺失导致测试失败，确认能力尚不存在 | ✅ parser/coordinator/controller/fake 最小实现后 62/62 | ✅ 页面共用计算协调器后 64/64 |
| Task 3.1～3.2 | ✅ 权限/平台 seam 模块缺失导致测试失败 | ✅ permission/gateway seam 测试通过 | ✅ 真实 CoreSpeechKit/AudioCapturer driver 编译并保持 64/64 |
| Task 4.1～4.2 | ✅ 成功提交、错误保留、取消/迟到与状态行为测试先行 | ✅ 页面原子提交、状态 UI、取消/重试、dispose 编译通过 | ✅ 移除重复页面计算链，统一到 CalculationCoordinator；64/64 |
| Task 5.1～5.2 | ✅ 初始测试/依赖环境暴露缺失模块与 hypium 缺失 | ✅ 安装声明的 devDependencies，全矩阵通过 | ✅ 最终 build/test/CodeLinter 回归通过 |

## 测试详情

### RED 证据

1. `hvigorw test -p module=entry -p coverage=false --no-daemon` 首次退出码 1：VoiceModels/parser/coordinator/controller/fake 尚不存在。
2. 平台 seam RED 再次退出码 1：VoicePermissionAdapter 与 HarmonySpeechRecognitionGateway 尚不存在。
3. Local Test 首轮环境同时发现 `@ohos/hypium` 未安装；执行项目已声明依赖的 `ohpm install` 后恢复可执行测试环境。

### GREEN / REFACTOR 证据

- 结果文件：`opencalc/entry/.test/default/intermediates/test/coverage_data/test_result.txt`
- 汇总：`Tests run: 64, Failure: 0, Error: 0, Pass: 64, Ignore: 0`
- 新增覆盖：中文单位/逐位/负数/小数、八种运算词/符号、非法输入 fail-closed、除零、成功状态、错误快照不变、重复 final、取消迟到回调、权限拒绝、平台启动/清理时序。
- 既有 PlotFunction/PlotAxis/渐近线回归全部继续通过。

### 构建

- 命令：`opencalc/run-build-wt.bat`
- 环境：Hvigor 6.24.2，JBR 21.0.8
- 结果：`BUILD SUCCESSFUL`
- 产物：`opencalc/entry/build/default/outputs/default/entry-default-unsigned.hap`（未配置签名，符合项目基线）

### Lint

- Hvigor 命令：`hvigorw lint --no-daemon`；项目 task graph 无 `lint`，命令按预期报告 task not found。
- 替代命令：DevEco Studio CodeLinter，`@typescript-eslint`、`@hw-stylistic`、`@correctness`、`@compatibility` recommended。
- 结果：退出码 0，0 error，275 warning；无 error 级问题。
- 报告：`logs/codelinter.json`

## 代码变更摘要

- 新增严格、确定性的中文数字与二元四则表达式解析，只输出 ASCII 运算符并对歧义输入 fail-closed。
- 新增候选计算协调器，语音与手动输入复用现有 Expression/CalcEngine/NumberFormatter 逻辑。
- 新增 session 隔离的语音控制器、可注入 gateway/fake、重复 final 与迟到回调防护。
- 新增运行时 MIC 授权、INTERNET/MICROPHONE 声明、CoreSpeechKit + 16 kHz mono 16-bit AudioCapturer 适配。
- 普通模式页面新增 44 vp 语音入口、监听/识别/成功/错误、原始识别文本、取消和重试，并在页面退出时释放资源。
- 成功语音计算通过唯一提交路径更新表达式、结果和一条历史；任何失败保留原输入与历史。

## 安全与隐私审计

- 仅用户主动点击后申请前台麦克风权限。
- 未声明后台麦克风权限；未新增 HistoryItem/Preferences schema。
- 音频与识别原文均未持久化、未写日志。
- cancel/error/final/dispose 统一停止 capturer 并 shutdown recognizer，清理幂等。

## 已知限制与 Tester 交接

- Developer 环境未连接具备麦克风和 CoreSpeechKit 在线服务的设备，不能替代 AC-015 真机证据。
- Tester 应在可重置 MIC 权限的 API 12+ 设备验证：拒绝/重试、`listening → recognizing → success`、说“123加456”得到 `123+456`/`579`、取消与页面离开释放。
- CodeLinter 的 warning 主要来自项目既有紧凑编码风格；本次门禁以 error 为失败级别，完整 JSON 已保留。

## 下一步

仅交由 Tester 验证；本阶段不归档、不审批。
