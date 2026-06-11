# Todo: Issue #7 - 百分号按钮

## 路径配置
- SPECS_FEATURE_ROOT: specs/specs
- CHANGES_ROOT: specs/changes
- CHANGE_DIR: specs/changes/20260611-requirement-add-percentage-btn
- TEST_ROOT: opencalc
- git_branch_adopted: true (feat/issue-7-percentage-btn)

## 阶段状态

### PLANNING ✅ COMPLETED
- [x] step1-step9 全部完成
- 制品: proposal.md, delta-spec.md, info.md, delta-design.md, design-review.md

### IMPLEMENTING ✅ COMPLETED
- [x] 任务分解 (tasks.md)
  - Task 1.1: 测试入口 + 目录骨架
  - Task 1.2: [RED→GREEN] 失败/通过用例 TC-01~08
  - Task 2.1: [GREEN] 修复 getPercentString
  - Task 2.2: [REFACTOR] 提取 findOperatorBefore
  - Task 3.1: UI 视觉确认（条件任务）

### APPLYING ✅ COMPLETED
- [x] Task 1.1: 创建测试骨架 (ETS + Node 镜像)
- [x] Task 1.2: RED→GREEN 测试用例 8/8 PASS
- [x] Task 2.1: 跳过（实测无 bug）
- [x] Task 2.2: 跳过（无重构必要）
- [x] Task 3.1: UI 验证（位置/颜色合规）
- [x] apply-report.md

## 制品清单
- [x] proposal.md
- [x] delta-spec.md
- [x] info.md
- [x] delta-design.md
- [x] design-review.md
- [x] tasks.md
- [x] apply-report.md

## 关键结论
- **百分号按钮已在 UI 显化**（`CalculatorPage.ets:278` 第二行第二槽）
- **百分号语义 8/8 PASS**：50+10%=55、200-10%=180、100*10%=10、100/10%=1000、50%=0.5、复合/括号/阶乘 全过
- **REQ-7-07（bug 修复）转为行为锁定**：实测无 bug，PROPOSAL/delta-spec 同步更新
