# 应用报告（Tester 反馈迭代 1）

## 应用信息

- 变更类型：bugfix（编排分类；产品语义为新增功能）
- 变更名称：中文语音输入算式并自动计算
- 关联 Issue / PR：#52 / #55
- 目标基线：`4af7209810beb3c5378d4e8a89f0137a58c91802`
- 分支：`agent/pull_request-55-task-59`
- 应用日期：2026-10-25
- 阶段边界：仅 APPLYING；未归档、未批准

## 代码完成情况

| 任务 | 状态 | 完成时间 |
|------|------|----------|
| Task 1.1 release-sealed VoiceGatewayFactory | ✅ 完成 | 2026-10-25 |
| Task 1.2 CalculatorPage 工厂装配 | ✅ 完成 | 2026-10-25 |
| Task 2.1 allowlisted scenario registry / scripted gateway | ✅ 完成 | 2026-10-25 |
| Task 2.2 test-only Ability/profile / 同页装配 | ✅ 完成 | 2026-10-25 |
| Task 2.3 结构化 test evidence recorder | ✅ 完成 | 2026-10-25 |
| Task 3.1 11 类 scripted UI 场景矩阵 | ✅ 完成 | 2026-10-25 |
| Task 3.2 release 封闭性与真实 E2E 交接 | ✅ 完成；AC-015 仍待能力环境 | 2026-10-25 |

## TDD 执行记录

| 任务 | RED | GREEN | REFACTOR |
|------|-----|-------|----------|
| 1.1 | 缺少 `VoiceGatewayFactory`，Local Test 编译失败 | fresh real gateway contract 通过 | 工厂只构造 Harmony gateway/CoreSpeech driver；73/73 |
| 1.2 | 缺少 composition provider，Local Test 编译失败 | test binding / release reset contract 通过 | 页面仅依赖端口；EntryAbility 显式 bindRelease；73/73 |
| 2.1 | 缺少 registry/scripted gateway，Local Test 编译失败 | 11 类 allowlist、未知 ID fail-closed、事件顺序通过 | session/cleanup 与 late/duplicate 行为集中；73/73 |
| 2.2 | 缺少 scripted factory，Local Test 编译失败 | enum-only factory contract 通过 | ohosTest Ability 在同一 CalculatorPage 创建前绑定；test HAP 编译通过 |
| 2.3 | 缺少 event recorder，Local Test 编译失败 | SHA/scenario/event/cleanup/historyDelta contract 通过 | 不记录 PCM、真实用户原文或新增 Preferences key；73/73 |
| 3.1 | 缺少 UI matrix，Local Test 编译失败 | 11/11 场景执行、success/failure oracle 通过 | test-only 自动事件调度供设备采证；两个 HAP 安装与同页 UI 链路通过 |
| 3.2 | 缺少 release seal contract，Local Test 编译失败 | `releaseInjectionReachable=false` / real gateway contract 通过 | release HAP/source 零 test symbol；最终 build/test/lint 全绿 |

## 最终验证

- Local Test：`73/73` 通过，0 failure，0 error，0 ignore。
- Release HAP：`opencalc/run-build-wt.bat` → `BUILD SUCCESSFUL`。
- Test HAP：`hvigorw assembleHap -p module=entry@ohosTest --no-daemon` → `BUILD SUCCESSFUL`。
- Device install：release/test HAP 均在 `127.0.0.1:5555` 安装成功。
- Device scripted UI：`VoiceTestAbility` 加载生产 `CalculatorPage`；设备树分别记录 `监听中…`、`识别中…`、`识别：123加456`、`123+456`、`579`。
- Lint：项目没有 Hvigor `lint` task；真实命令已执行并记录 task-not-found。DevEco CodeLinter exit 0，0 error，271 warning。
- Diff：`git diff --check` 通过。

## 验证命令

```text
D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat --version
D:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat install
opencalc\run-build-wt.bat
hvigorw assembleHap -p module=entry@ohosTest --no-daemon
hvigorw test -p module=entry -p coverage=false --no-daemon
hvigorw lint --no-daemon
node DevEco-CodeLinter -c opencalc/codelinter.json5 -f json -e error opencalc
hdc install -r entry-default-unsigned.hap
hdc install -r entry-ohosTest-unsigned.hap
hdc shell aa start -a VoiceTestAbility -b com.darkempire78.opencalculator -m entry_voice_test --ps scenarioId integerTable
hdc shell uitest dumpLayout ...
git diff --check
```

## 证据路径

- `opencalc/entry/.test/default/intermediates/test/coverage_data/test_result.txt`
- `specs/changes/20261024-bugfix-chinese-voice-expression-input/logs/codelinter-task-59.json`
- `specs/changes/20261024-bugfix-chinese-voice-expression-input/logs/device-permission-dialog.json`
- `specs/changes/20261024-bugfix-chinese-voice-expression-input/logs/device-listening.json`
- `specs/changes/20261024-bugfix-chinese-voice-expression-input/logs/device-recognizing.json`
- `specs/changes/20261024-bugfix-chinese-voice-expression-input/logs/device-success.json`

## Release 封闭性审计

- `entry/src/main` 与 release `module.json5` 对 `Scripted*`、`VoiceTestScenario*`、`VoiceTestAbility`、`scenarioId` 零命中。
- release HAP 文件表对 `VoiceTest`、`Scripted`、`ohosTest`、`entry_voice_test` 零命中。
- 普通 `EntryAbility.onCreate` 无条件 `bindRelease()`；不读取 Want、URI、环境变量或 transcript。
- test Ability/profile、registry、scripted gateway、evidence recorder 均位于 `entry/src/ohosTest`，只由 `ohosTest` target 打包。

## AC 状态

- AC-001～014、016～019：Developer 层验证通过；AC-019 的 device-visible injection 缺口已闭合，Tester 仍需在 exact PR HEAD 独立复核完整矩阵。
- AC-015：未关闭。当前 emulator 的真实 CoreSpeechKit 曾返回 CreateEngineError；scripted 证据不替代真实中文语音 E2E。Tester 必须在 MIC、网络和 zh-CN CoreSpeechKit 预检通过环境说“123加456”并采集 real evidence。

## 已知限制

- 项目未注册 Hvigor lint task，使用 DevEco CodeLinter 作为实际 lint 门禁。
- 两个 HAP 均为 unsigned，符合仓库无可用 signingConfig 的基线。
- 271 条 warning 为项目存量/风格/兼容性警告；无 error 级问题。

## 下一步

仅交由 Tester 验证；本阶段不归档、不审批。
