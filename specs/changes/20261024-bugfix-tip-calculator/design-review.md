# 设计审视报告

## 1. 审视范围与结论
- **结论**：通过；Tester 反馈迭代 1 的 PLANNING 可完成。
- **输入**：Issue #50 原文、Developer handoff、Tester run-100、当前 HEAD 源码、proposal/spec/AC/info/design。
- **范围守卫**：只修改规划制品和外部 checkpoint candidate；未修改产品源码、测试源码、`tasks.md`、提交、推送或归档。

## 2. 初始化与意图确认
| 项目 | 结果 | 证据/理由 |
|---|---|---|
| 初始化 | 通过 | `specs/initialized.flag` 有效；PROJECT_ROOT=`opencalc`、TEST_ROOT=`opencalc/entry/src/test` |
| Git | 通过 | 独立分支 `agent/pull_request-53-task-58`；开始时工作树干净；HEAD=`84941216afa12ec6fa12c2383a86be2d38976fbb` |
| 产品意图 | 新增功能 | Issue 标题 `feat` 且目标是新增小费分摊能力 |
| 编排意图 | bugfix | payload change_type；本轮 reason=`tester_feedback`，只影响工作流元数据 |
| 人工确认 | 不需要 | 选择均安全、可逆、Issue 内且不需凭据/付费/隐私合规/不可逆动作 |

现有初始化已记录成功构建基线；用户明确只执行 PLANNING，因此未重复执行构建或产品测试。

## 3. rq-parse / rq-clarify 结果
- 原始 Issue 已原子化为 IR-001～IR-013；Tester P0 反馈单列 IR-014，没有把设备缺陷静默吸收到内部实现描述。
- 普通歧义继续采用既有安全默认：单页覆盖层、默认 15%/1 人、点号十进制最多两位、整数分值舍入、不持久化、不补建程序员模式。
- 新增纠正默认：页面 `@State` 是唯一 UI 输入源，纯计算器只接收不可变快照。理由是设备 UI 树已证明当前可见输入和 `TipSession` 快照可以脱节。

## 4. 代码仓与 Tester 证据复核
| 发现 | 证据 | 设计响应 |
|---|---|---|
| 纯算法 oracle 成立 | Local Test 64/64 | 保留 `TipCalculator` 分值算法 |
| 真机可见 `100/15%/2` 但结果 `--` | run-100 `02-ac002-pass.json/png` | AC-002/011 要求同帧输入和结果 exact oracle |
| 页面与 TipSession 各持有输入/派生状态 | CalculatorPage `@State` + 普通 `TipSession` | 删除生产 UI 的可变镜像回写链 |
| 日志无可归因产品异常栈 | run-100 hilog | 不虚构平台根因；只处理已证实多源状态风险 |
| 无 ohosTest target | Tester instrument command 失败 | 不把缺失 target 冒充产品通过；核心门禁为 Local Test + 真机 UI/E2E |

## 5. 完整性评估
| 制品 | 结果 |
|---|---|
| proposal.md | 通过：意图、IR、假设、Tester 反馈和范围 |
| delta-spec.md | 通过：§1～§13、STAGE、GWT、SR、FMEA、追溯 |
| acceptance-criteria.json | 通过：14 IR、11 feature AC、七维覆盖、假设 |
| info.md | 通过：代码、证据、根因边界和最小纠正方向 |
| delta-design.md | 通过：D1～D10、单一源事件事务、算法、UI/E2E 门禁 |
| new-arch.md | 不需要：entry HAP、路由、外部依赖和部署边界不变 |
| todo.md | 通过：本轮 PLANNING 子步骤完成，下一步等待独立阶段调度 |
| tasks.md | 未修改：用户禁止本阶段创建或更新 |

## 6. 一致性与追溯评估
| Issue/反馈承诺 | IR | SR/UC | AC | 结果 |
|---|---|---|---|---|
| 入口、返回、既有模式/历史 | IR-001/012 | SR-00；SC-001/003 | AC-001/009 | 通过 |
| 输入、四预设、自定义比例 | IR-002/003 | SR-01；SC-001/002 | AC-002～004/006～008 | 通过 |
| 自动三结果 | IR-004 | SR-02；SC-001/002 | AC-002～005/011 | 通过 |
| 两个精确示例和 0% | IR-005/006/007 | SR-02/03 | AC-002/003/005 | 通过 |
| 两位小数和舍入 | IR-008 | SR-03 | AC-002/003/005 | 通过 |
| 非法账单/人数/比例、防误导 | IR-009/010/011 | SR-04；SC-002 | AC-006～008/011 | 通过 |
| 独立证据 | IR-013 | SR-05；SC-003 | AC-010 | 通过 |
| 可见输入与计算快照一致 | IR-014 | SR-02；SC001-UC002/SC002-UC003 | AC-002/004/011 | 通过 |

JSON 的 AC ID、GWT、oracle 和层级已在 delta-spec §7/§11 镜像，并在 delta-design 的 AC 落点矩阵中覆盖。

## 7. AC 独立质量门禁

### 7.1 七维和 ArkUI 风险
| 检查 | 结果 |
|---|---|
| normal / boundary / exception | 每条 IR 均 covered 或有具体 N/A 理由 |
| user_visible | 产品 AC 均精确断言 UI 文本/状态；证据 AC 断言制品语义 |
| state_sync | AC-004/011 覆盖连续编辑、真实 IME、同帧输入/结果 |
| integration | 所有 feature AC 均含 integration/ui/e2e，非 unit-only |
| environment | 横竖屏、HarmonyOS、IME、真机、UI 树均显式 |
| `@State` | 单一源和原子派生提交被 AC-002/004/011 约束 |
| 条件渲染/模式切换 | AC-001/009 覆盖入口、返回和兼容性 |
| 重复按钮 | AC-004 要求四个预设各自映射自身值 |
| 权限/外设 | 无权限、网络、相机或付费服务；无需扩张环境矩阵 |

### 7.2 校验器
命令：
```text
python D:\huawei\Demo\calculatorHuawei\orchestrator\skill-bundles\developer\skills\migbot-increment-planning\scripts\validate_acceptance_criteria.py specs\changes\20261024-bugfix-tip-calculator\acceptance-criteria.json
```

- 首次修订运行：退出 1，发现 3 个 coverage 追溯引用未同时列入 AC 的 source_requirement_ids。
- 修正：补齐 AC-005→IR-004、AC-006/007→IR-002 追溯；未删除 IR、弱化 oracle 或滥用 N/A。
- 最终运行：退出 0，`VALID: 14 source requirement(s), 11 acceptance criterion/criteria`。

## 8. 规范性和向后兼容
- 模板章节完整，无 TODO/TBD/“此处填写”占位。
- IR/SR/SC/UC/AC 编号稳定；JSON 是机器权威。
- 无架构、路由、权限、Kit、依赖、持久化或历史契约变化。
- 设计只收敛状态所有权，保留纯算法和 UI 范围，是修复 Tester P0 的最小常规方案。

## 9. 遗留风险和后续门禁
- 无 PLANNING blocker。
- 当前规划尚未实现；AC-011 必须在后续 Applying 后由独立 Tester 在真实设备用系统 IME 复测。
- 直接向原生 TextInput 注入文本而不触发用户事件不能单独作为产品语义证据；必须同时采集可见输入、选中态和结果。
- `ohosTest` target 缺失是测试基础设施限制，不属于本轮规划授权范围；不得因此把未执行 instrument test 标记通过。
