# AID Todo — Issue #16 长按菜单

> aid-workflow 20260616-requirement-add-long-press-menu
> worktree: D:\huawei\Demo\worktrees\issue-16
> 类型: requirement-add (中等需求, ⭐⭐)
> 自动授权模式 (claude -p), 用户确认点全部自动通过, 理由记录在本文件

## 路径配置
- CHANGES_ROOT: specs/changes/20260616-requirement-add-long-press-menu
- SPECS_FEATURE_ROOT: specs/changes/20260616-requirement-add-long-press-menu

## 环境能力（来自 .claude/capabilities.json）
- 项目类型: HarmonyOS
- 平台: Windows
- bundleName: com.darkempire78.opencalculator
- 编译命令: hvigorw --no-daemon assembleHap
- 单元测试命令: hvigorw --no-daemon test
- **UI 自动化测试能力: ✅ 可用 (hdc + 模拟器)**
- 模拟器: 127.0.0.1:5555
- hdc 路径: D:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe
- hvigorw: /d/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw
- 真实验证: hvigorw / hdc 均在 PATH 可达 ✅

## git_branch
- git_branch_adopted: N/A (worktree 已隔离 issue-16,无需另开分支)
- 当前分支: HEAD (worktree 模式)

## 阶段间确认
- PLANNING → IMPLEMENTING: 自动同意,需求边界清晰
- IMPLEMENTING → APPLYING: 自动同意,任务分解后无 ambiguity
- 理由: 中等需求 (⭐⭐),模式已被 issue #9/#11/#12 验证可行, 不需要反复确认

## PLANNING 阶段进度
- [x] step0.5 环境能力盘点
- [x] step1 用户意图理解 (requirement-add)
- [x] step2 需求理解 (rq-parse → proposal.md)
- [x] step3 需求澄清 (无 blocker/important,跳过)
- [x] step4 需求 spec 设计 (delta-spec.md)
- [x] step5 代码仓理解 (rq-codebase → info.md)
- [x] step6 需求复杂度评估 (S 简单)
- [x] step7 架构设计 (跳过 new-arch.md,无架构变更)
- [x] step8 组件设计 (mod-design → design.md)
- [x] step9 设计审视 (design-review.md)
- **PLANNING ✅ 完成**

## IMPLEMENTING 阶段进度
- [x] step2-1 任务分解
- [x] step2-2 任务排序
- [x] step2-3 产出 tasks.md (15 个任务, RED-GREEN-REFACTOR + UI 自动化)
- **IMPLEMENTING ✅ 完成**

## APPLYING 阶段进度
- [ ] 待 IMPLEMENTING 完成后开始

## 风险点
- 无 (简单 UI 增强, 不删现有功能, 不改架构)