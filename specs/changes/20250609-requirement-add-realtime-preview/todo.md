# Issue #3 实时预览结果 — todo 跟踪

## 路径配置
- **变更目录**：`specs/changes/20250609-requirement-add-realtime-preview/`
- **关联特性**：feat-calculator-core
- **Git 分支**：`feat/issue-3-realtime-preview`（已采用）
  - `git_branch_adopted: true`
- **工作根**：`opencalc/`（OpenCalc HarmonyOS 移植版）

## 阶段状态

| Step | 名称 | 状态 | 产出物 | 备注 |
|------|------|------|--------|------|
| step1 | 用户意图理解 | ✅ done | — | 分类：新增功能；分支已就绪 |
| step2 | 需求解析 | ✅ done | `proposal.md` | rq-parse 输出 |
| step3 | 需求澄清 | ✅ done | `proposal.md §3` | 用户未交互，采用推荐默认值；3 项决策均采用推荐方案（见下） |
| step4 | 需求spec设计 | ✅ done | `delta-spec.md` | IR-01~05 / SR-001~005 / UC-001-01 |
| step5 | 代码仓理解 | ✅ done | `info.md` | rq-codebase 输出，复用链路明确 |
| step6 | 复杂度评估 | ✅ done | `proposal.md §6` | 简单需求，跳过 new-arch.md |
| step7 | 架构设计 | ⏸ skip | — | 复杂度简单，无架构变更 |
| step8 | 组件设计 | ✅ done | `delta-design.md` | mod-design 输出，含 PlantUML 时序/类图与字号表 |
| step9 | 设计审视 | ✅ done | `design-review.md` | 完整性/一致性/规范性/可追溯性全部通过；可进入 IMPLEMENTING |
| step2-1 | 任务分解 | ✅ done | `tasks.md §任务列表` | 8 个任务拆为 4 阶段，每任务 1-2h 颗粒度 |
| step2-2 | 任务排序 | ✅ done | `tasks.md §开发顺序` | 4 个原子提交，每个 buildable |
| step2-3 | 产出 tasks.md | ✅ done | `tasks.md` | 含依赖关系/提交顺序/验收计划/D12 检查清单映射 |
| — | **IMPLEMENTING 阶段结论** | ✅ done | `tasks.md` | 任务分解完成，等待用户确认后进入 APPLYING |

## 自动化决策留痕
- **2026-06-09 / rq-parse nice-to-have 自动决策**：
  - 决策：实时预览不引入 debounce，单次求值 <1ms，按键即算即可。
  - 风险：低（最坏情况长表达式多消耗毫秒级时间）。
  - 依据：`CalcEngine.evaluate` 是 O(n) 字符串扫描，n 通常 < 100。
- **2026-06-09 / rq-parse nice-to-have 自动决策**：
  - 决策：预览态与 result 视觉差异通过字号/颜色区分，不引入「预览」文字前缀。
  - 风险：低（视觉风格在用户多次使用后即可形成认知）。
  - 依据：保持 UI 简洁，避免文字噪音。
- **2026-06-09 / rq-parse nice-to-have 自动决策**：
  - 决策：默认开启实时预览，不新增设置项。
  - 风险：低（功能无副作用）。
  - 依据：核心交互改进应面向所有用户。

## 重要决策待用户确认
- 表达式不完整时（如 `1+`、`(`），预览区显示什么？→ 见 rq-clarify 阶段交互。

## rq-clarify 默认决策（2026-06-09）
用户未应答 AskUserQuestion，按 rq-clarify skill「提前终止」原则采纳推荐默认值：
1. **不完整表达式 → 预览区空白**：与 AC 初始态一致，避免误导。
2. **无预览开关**：默认开启，不扩张设置面板；保持「简单快捷」基调。
3. **视觉区分**：仅通过字号/颜色区分，不加「预览」文字前缀。

> 若后续用户在 GitHub Issue 上提出反对意见，可单独提 Issue 调整；当前 PLANNING 阶段以上述默认值推进。

## 阶段产出物清单（最终）
- [x] `proposal.md`
- [x] `delta-spec.md`
- [x] `info.md`
- [x] `delta-design.md`
- [x] `design-review.md`
- [x] `todo.md`（本文件）

## PLANNING 阶段结论（2026-06-09）
- 全部 8 个有效步骤 + 1 个跳过步骤均已完成/记录。
- 审视报告（design-review.md）结论：通过，可进入 IMPLEMENTING 阶段。
- 关键决策已留痕（自动决策 3 项 + rq-clarify 默认决策 3 项 + 跳过 new-arch 1 项）。
- 遗留 nice-to-have 问题（4 项）均为实施阶段可选项，不阻塞进入下一阶段。

## IMPLEMENTING 阶段产出（2026-06-09）
- **产出物**：`tasks.md`（含 8 个任务、4 阶段、4 个原子提交、6 主题×2 方向×3 KEP 验收矩阵）
- **任务数**：8（阶段 1: 2 / 阶段 2: 2 / 阶段 3: 2 / 阶段 4: 2）
- **提交数**：3 原子提交 + 1 可选（仅当 Task 3.2 被决定执行时升为独立 #4）
- **依赖关系**：
  ```
  1.1 (@State preview) → 1.2 (updatePreview 方法) → 2.1 (6 回调接入) → 2.2 (onAC 同步) → 3.1 (DisplayPanel) → 3.2 (onEquals 同步, 可选)
                                                                                                          ↓
                                                                       4.1 (5 种 ErrorFlags 回归) → 4.2 (KEP-01/02/03 体验)
  ```
- **关键设计决策落地**：
  - Task 1.2 不抽离 `compute()` 公共方法（与设计 D-07 一致，与基线 onEquals 共享求值代码 1 处重复）
  - Task 3.2 标记 *可选*，**默认跳过**（与设计 D-08「保持 preview 不动」推荐一致），待用户确认
  - Task 2.2 在 onAC 显式 `preview = ''`（与 result/errorMsg 同步，防御性写法）

## IMPLEMENTING 阶段结论
- 任务分解已完成，粒度符合 aid-implementing §全局约束（每任务 1-2h 可完成、有明确验收标准）。
- 等待用户确认后进入 APPLYING 阶段。

## APPLYING 阶段产出
- **完成日期**: 2026-06-09
- **提交**: 
  - #1 `b32bfa6` feat(calculator): add preview state and updatePreview method
  - #2 `33f701d` feat(calculator): wire updatePreview into 6 button callbacks
  - #3 `bf6b087` feat(calculator): render realtime preview in DisplayPanel
- **产出物**: `apply-report.md`
- **状态**: ✅ 完成
- **待验证**: Task 4.1, 4.2 需在 DevEco Studio 模拟器手动执行

## 阶段状态汇总
| 阶段 | 状态 | 备注 |
|------|------|------|
| PLANNING | ✅ 完成 | 全部 8 步骤完成 |
| IMPLEMENTING | ✅ 完成 | 8 任务分解完成 |
| APPLYING | ✅ 完成 | 3 个原子提交 |
| ARCHIVING | ⏳ 待审核 | 待 rev-01 审核后执行 |