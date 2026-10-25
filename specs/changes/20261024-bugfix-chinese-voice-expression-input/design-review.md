# 设计审视报告（Tester 反馈迭代 1）

## 1. 审视范围与结论

- **关联**：Issue #52、PR #55、目标 SHA `4af7209810beb3c5378d4e8a89f0137a58c91802`、Tester run 107。
- **初始化**：复用 `specs/initialized.flag`；`PROJECT_ROOT=opencalc`、`CHANGES_ROOT=specs/changes`、`TEST_ROOT=opencalc/entry/src/test` 均存在；当前分支 `agent/pull_request-55-task-59`，检查前工作树干净。
- **意图分类**：编排类型 `bugfix`；产品原意仍是新增中文语音能力；本轮是对 Tester 失败暴露的验收可达性缺口进行增量规划。
- **审视结论**：通过，可结束本轮 PLANNING。
- **需求覆盖度**：100%（10/10 原子 IR 均有 feature-level AC、SR/UC 与设计分配）。
- **阻塞项**：无。当前模拟器缺 CoreSpeechKit engine 是明确环境限制，不需要凭据、付费服务、隐私决策或范围扩张即可继续规划。

## 2. Tester 反馈闭环

| 反馈事实 | 代码仓证据 | 规划决策 | 追溯 |
|----------|------------|----------|------|
| MIC 授权后 CoreSpeechKit `CreateEngineError` | `CoreSpeechPlatformDriver.begin()` 首先调用 `createEngine`; run 107 hilog 记录失败 | 维持 AC-010 安全降级；AC-015 只在能力预检通过环境执行，fake 不替代 | IR-006/010；AC-010/015 |
| 安装应用没有设备可见 fake 注入 | `CalculatorPage.onVoiceStart()` 直接 new 真实 driver；fake 仅 `entry/src/test` | 增加 release-sealed factory 与 test-only scripted gateway/Ability/profile | IR-009；AC-019 |
| Local Test 64/64 但 UI 成功/失败矩阵未执行 | controller/parser fake 只验证本地对象状态 | AC-014 负责 local；AC-019 单独要求设备 UI 树、截图、页面/Preferences delta | SR-06；SC004 |
| 取消、重复点击、历史无法在设备验证 | 无活动真实 session 且无设备 harness | scripted scenarios 覆盖 cancel-late、duplicate-start、duplicate-final | AC-012/013/017/019 |

## 3. 完整性评估（Step 9.1）

| 制品 | 状态 | 说明 |
|------|------|------|
| `proposal.md` | 通过 | rq-parse/rq-clarify 决策、10 个原子 IR、假设、边界、复杂度 |
| `delta-spec.md` | 通过 | 1～13 章节、SC001～SC005、SR、DFX、追溯总表 |
| `acceptance-criteria.json` | 通过 | 10 IR、19 feature AC、七维覆盖、假设与非目标 |
| `info.md` | 通过 | 当前源码、Tester 证据、装配缺口与环境事实 |
| `new-arch.md` | 通过 | factory、release/test 装配边界、兼容与回滚 |
| `delta-design.md` | 通过 | mod-design D1～D10；AR-VOICE-01～07 |
| `todo.md` | 通过 | 复盘 PLANNING 子步骤均完成；历史阶段保留 |
| `tasks.md` | 未触碰 | 文件来自前序 handoff；本轮没有创建或修改 |

## 4. 一致性评估（Step 9.2）

### 4.1 Issue/Tester → IR → AC

| 承诺 | IR | AC | 结论 |
|------|----|----|------|
| 入口与四态 | IR-001 | AC-001/012/016/017 | 通过 |
| 权限拒绝、说明、重试 | IR-002 | AC-002/016 | 通过 |
| 八种运算词/符号 | IR-003 | AC-003 | 通过 |
| 阿拉伯/中文数字、小数、歧义 | IR-004 | AC-004/005/006/018 | 通过 |
| 原文、填入、自动计算 | IR-005 | AC-007 | 通过 |
| 无结果/歧义/除零/服务/中断安全失败 | IR-006 | AC-006/008～011 | 通过 |
| 可见监听与取消 | IR-007 | AC-012/017 | 通过 |
| 共用计算链、历史一次 | IR-008 | AC-007/009/013 | 通过 |
| 可注入解析与设备 UI 自动化 | IR-009 | AC-014/019 | 通过；local 与 device UI 分证 |
| 真实麦克风端到端证据 | IR-010 | AC-015 | 通过；能力预检，fake 不替代 |

### 4.2 Spec → Design

| 规格 | 设计分配 | 结论 |
|------|----------|------|
| SR-01 会话状态 | VoiceInputController/session token | 通过 |
| SR-02 平台识别 | Harmony gateway/CoreSpeech driver | 通过 |
| SR-03 规范化 | ChineseNumberParser/VoiceExpressionParser | 通过 |
| SR-04 原子计算历史 | CalculationCoordinator/单一 commit | 通过 |
| SR-05 安全恢复 | snapshot、幂等 cleanup、错误映射 | 通过 |
| SR-06 测试与证据 | local fake + release-sealed factory + test-only scripted gateway + real E2E | 通过 |

## 5. AC 独立质量门禁（Step 9.2.1）

执行：

```text
python D:\huawei\Demo\calculatorHuawei\orchestrator\skill-bundles\developer\skills\migbot-increment-planning\scripts\validate_acceptance_criteria.py specs\changes\20261024-bugfix-chinese-voice-expression-input\acceptance-criteria.json
```

结果：

```text
VALID: 10 source requirement(s), 19 acceptance criterion/criteria
exit_code=0
```

语义审查：

| 维度 | 结论 |
|------|------|
| normal | 状态成功、数字/运算解析、自动计算、真实语音与设备 UI matrix 均有精确 oracle |
| boundary | 小数、逐位数、负数、重复点击、partial/duplicate final 均覆盖 |
| exception | 权限拒绝、空结果、歧义、除零、服务不可用、录音中断、取消迟到回调均覆盖 |
| user_visible | UI 文本/状态/控件/表达式/结果/历史，不以“组件存在”代替语义结果 |
| state_sync | `@State` 状态、取消/重试条件渲染、历史列表与 Preferences delta 均覆盖 |
| integration | 权限→driver→controller→parser→calculator→history 以及 device harness→同一页面覆盖 |
| environment | local fake、无服务模拟器、设备测试构建、真实有能力设备四层分离 |

HarmonyOS/ArkUI 专项：AC-001/002/007/012/017/019 验证响应式状态与条件渲染；AC-013/019 验证历史 `ForEach`/Preferences 同步；AC-002/010/015/016 验证权限与设备能力；release fake 不可达是 AC-019 的强制安全 oracle。

## 6. 规范性与复杂度（Step 6、Step 9.3）

- **复杂度**：复杂。影响页面、应用状态机、平台端口、解析、计算历史、composition root、测试装配与真机环境。
- **架构变化**：有，但部署仍为单 entry HAP；设备测试可附加测试 Ability/profile。
- **数据模型**：无持久化 Schema 变化。
- **向后兼容**：手动输入、科学模式、绘图、HistoryItem/Preferences 均保持；release 默认仍是真实 gateway。
- **最小权限**：不新增后台录音，不持久化音频/原文，不引入第三方凭据、付费服务或远端服务端。
- **文档规范**：proposal、spec 1～13、new-arch、design D1～D10、todo 与本报告完整。

## 7. 假设与风险

1. 设备测试装配只允许枚举 scenarioId，并与源码 SHA 绑定；不接受 release Want 中的任意 transcript。
2. release `module.json5` 不注册测试 Ability/action/URI，release factory 没有 scripted setter；需以包审计/装配测试证明 `releaseInjectionReachable=false`。
3. 当前模拟器可继续验证 AC-002、AC-010 与 AC-019；不能用于宣称 AC-015。
4. AC-015 仍需具备 MIC、网络、zh-CN CoreSpeechKit 的真机或等价环境。缺环境是后续验收限制，不是本轮 Planning blocker。

## 8. Phase Gate

- PLANNING：通过。
- IMPLEMENTING/APPLYING/ARCHIVING：本轮未执行。
- 产品源码、测试源码、构建配置、`tasks.md`：未修改。
- commit/push/PR/归档：未执行。
