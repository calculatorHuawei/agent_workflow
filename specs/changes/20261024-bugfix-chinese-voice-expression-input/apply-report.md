# 应用报告（Tester 反馈迭代 2）

## 应用信息

- 变更类型：bugfix（编排分类；产品语义为新增功能）
- 变更名称：中文语音输入算式并自动计算
- 关联 Issue / PR：#52 / #55
- 目标基线：`d904e4c3b8dc26c0490eeda5d43805f5a10310aa`
- 分支：`agent/pull_request-55-task-64`
- 应用日期：2026-10-25
- 阶段边界：仅 APPLYING；未归档、未批准

## 代码完成情况

| 任务 | 状态 | 完成时间 |
|------|------|----------|
| Task 1.1 gateway start/listening 结构化顺序合同 | ✅ 完成 | 2026-10-25 |
| Task 2.1 真实权限框与 test-only 事件/UI 证据链 | ✅ 完成 | 2026-10-25 |
| Task 3.1 全量回归、release 封闭与真实 E2E 交接 | ✅ 完成；AC-015 保持环境限制 | 2026-10-25 |

## TDD 执行记录

| 任务 | RED | GREEN | REFACTOR |
|------|-----|-------|----------|
| 1.1 | 新测试因缺少 create/start/session 字段与方法而失败；cancel cleanup 断言随后以 `false` 失败 | recorder/factory/gateway 最小实现通过，duplicate start、cancel、late final 不变量通过 | 将 create/start/listening/cleanup 记录集中到 recorder；77/77 |
| 2.1 | permission-order 测试显示首事件是 `gatewayCreated`，缺少 `permissionGranted` | test factory 在生产页权限 await 返回后的 create 边界记录 grant；Ability 在点击前记录 start=0；78/78 | 统一 hilog 字段并保持 recorder 只记录 allowlisted 元数据；test HAP 构建及设备证据通过 |
| 3.1 | matrix contract 因缺少 start/session/cleanup 字段而编译失败 | 11 类结果均输出 `gatewayStartCount=1`、`activeSessionId=1`、cleanup=true；79/79 | 提取统一 evidence projection；重跑 local/build/lint/package/device gates |

## 最终验证

- Local Test：`79/79` 通过，0 failure，0 error，0 ignore。
- Release HAP：`opencalc/run-build-wt.bat` → `BUILD SUCCESSFUL`。
- Test HAP：`hvigorw assembleHap -p module=entry@ohosTest --no-daemon` → `BUILD SUCCESSFUL`。
- Device install：最终 ohosTest HAP 在 emulator `127.0.0.1:5555` 安装成功。
- AC-016：真实 HarmonyOS 权限框可见时，结构化日志只有 `testAbilityReady` 且 `gatewayStartCount=0`；点击 Allow 后按时间顺序出现 `permissionGranted → gatewayCreated → gatewayStartInvoked(sessionId=1) → scriptedListening(sessionId=1)`，随后 UI tree 显示 `监听中`。最终显示 `识别：123加456`、`123+456`、`579`。
- Device matrix：最终 test HAP 上复跑 11 个 allowlisted scenario 并保留 UI tree；成功、失败、取消、重复开始与重复 final 的可见 oracle 保持。
- Lint：项目没有 Hvigor `lint` task；实际命令返回 task-not-found。DevEco CodeLinter 6.0.240 exit 0，0 error，271 warning。
- AC validator：18 个 IR、19 个 feature AC，exit 0。
- Release seal：release source/manifest 与 release HAP 文件表/二进制扫描对 test Ability、scripted gateway、scenario registry、recorder、test module 标识均 0 命中。
- Diff：`git diff --check` 通过。

## 验证命令

```text
D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat --version
D:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat install
opencalc\run-build-wt.bat
hvigorw test -p module=entry -p coverage=false --no-daemon
hvigorw assembleHap -p module=entry@ohosTest --no-daemon
hvigorw lint --no-daemon
node DevEco-CodeLinter -c opencalc/codelinter.json5 -f json -o .../codelinter-task-64.json -e error opencalc
validate_acceptance_criteria.py acceptance-criteria.json
hdc install -r entry-ohosTest-unsigned.hap
hdc start VoiceTestAbility + real permission Allow + uitest dumpLayout/screenCap + hilog
hdc run 11 allowlisted scenarios with isolated force-stop/start and final UI dumps
release HAP/source/manifest scripted-symbol audit
git diff --check
```

## 证据路径

- `opencalc/entry/.test/default/intermediates/test/coverage_data/test_result.txt`
- `specs/changes/20261024-bugfix-chinese-voice-expression-input/logs/codelinter-task-64.json`
- `specs/changes/20261024-bugfix-chinese-voice-expression-input/logs/device-permission-order-task-64.log`
- `D:\huawei\Demo\calculatorHuawei\.agent-runtime\evidence\task-64-permission-dialog.json`
- `D:\huawei\Demo\calculatorHuawei\.agent-runtime\evidence\task-64-listening.json`
- `D:\huawei\Demo\calculatorHuawei\.agent-runtime\evidence\task-64-listening.png`
- `D:\huawei\Demo\calculatorHuawei\.agent-runtime\evidence\task-64-success.json`
- `D:\huawei\Demo\calculatorHuawei\.agent-runtime\evidence\task-64-success.png`
- `D:\huawei\Demo\calculatorHuawei\.agent-runtime\evidence\task-64-device-matrix\`

## AC 状态

- AC-001～014、AC-016～019：Developer 层验证通过；Tester 应在精确 PR HEAD 独立复核。
- AC-015：未关闭。当前 emulator 不具备成功的 zh-CN CoreSpeechKit 真实识别链；本轮 scripted evidence 不替代真实 AudioCapturer/CoreSpeechKit E2E。Tester 仍须在 MIC、网络和服务能力预检通过环境说“123加456”并保留真实证据。

## 已知限制

- Hvigor 未注册 lint task，DevEco CodeLinter 是实际静态检查门禁。
- release/test HAP 均为 unsigned，符合仓库未配置可用 signingConfig 的基线。
- 271 条 warning 为存量/风格/兼容性告警；无 error 级问题。

## 下一步

仅交由 Tester 验证；本阶段不归档、不审批。
