# 变更状态机 — 20250611-requirement-add-percentage-button

## 路径配置
- SPECS_FEATURE_ROOT: opencalc/spec
- CHANGES_ROOT: specs/changes
- CHANGE_DIR: specs/changes/20250611-requirement-add-percentage-button
- WORK_DIR: opencalc/

## 关联 Issue
- Issue: #6
- 标题: 加一个百分号按钮，输入50+10%自动算出55
- 分类: UX增强
- 难度: ⭐
- 仓库: calculatorHuawei/agent_workflow

## 阶段状态

| 阶段 | 状态 | 起始 | 结束 | 备注 |
|------|------|------|------|------|
| PLANNING | ✅ DONE | 2026-06-11 | 2026-06-11 | proposal / delta-spec / info / design |
| IMPLEMENTING | ✅ DONE | 2026-06-11 | 2026-06-11 | tasks.md |
| APPLYING | ✅ DONE | 2026-06-11 | 2026-06-11 | TDD 9/9 PASS + apply-report |

## 进度

- [x] 步骤 0: 初始化检查
- [x] 步骤 1: 意图识别 — New Requirement
- [x] 步骤 2-1: PLANNING 阶段
  - [x] step1-9 全流程
  - [x] proposal.md
  - [x] delta-spec.md
  - [x] info.md
  - [x] design.md
- [x] 步骤 2-2: IMPLEMENTING 阶段
  - [x] tasks.md
- [x] 步骤 2-3: APPLYING 阶段 (TDD RED-GREEN-REFACTOR)
  - [x] T1 RED: 写失败测试
  - [x] T2 RED 确认: 10/10 FAIL exit=1
  - [x] T3 GREEN: 移植算法
  - [x] T4 GREEN 确认: 9/9 PASS exit=0
  - [x] T5-T8: UI 改造 (BtnPct/getPct/AboutPanel)
  - [x] T9: 全套验证 + diff
  - [x] T10: apply-report.md

## 验证

- 测试: 9/9 PASS (Node percent_node.mjs)
- UI 静态: 24/24 PASS (harmonyos-ui-test 降级 — 无 hdc/hvigorw)
- 改动: CalculatorPage.ets +18/-1 (预算 ≤ 200)
- 铁律 7: 所有 PASS 输出真实跑出
- 不变性: Expression.ets / Calculator.ets 未改

## 强制约束

- 铁律 0/2: PLANNING → IMPLEMENTING → APPLYING 全部跑完 ✅
- 铁律 7: 真实跑测试，不准伪造输出 ✅
- 强制 tdd-enforcer: RED → GREEN → REFACTOR ✅
- 所有产出物落到 specs/changes/20250611-requirement-add-percentage-button/ ✅

