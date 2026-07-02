# Issue #30 Todo 跟踪

## 基本信息
- **Issue**: #30 [CRON] 数据采集脚本连接失败 - WinError 10061
- **变更类型**: bugfix
- **变更名**: cron-数据采集脚本连接失败-winerror-1006
- **目录**: `specs/changes/20260626-bugfix-cron-poll-issues-retry/`
- **worktree**: D:\huawei\Demo\worktrees\issue-30
- **分支**: feat/issue-30-cron-数据采集脚本连接失败-win
- **开始时间**: 2026-06-26 16:11
- **git_branch_adopted**: true (已使用现成 feat/issue-30-* 分支)

## 环境能力（来自 .claude/capabilities.json）
- 项目类型: HarmonyOS (本 issue 实际涉及 hermes 数字员工 Python 脚本, 不涉及 hvigor)
- 平台: Windows
- bundleName: com.darkempire78.opencalculator
- 编译命令: hvigorw --no-daemon assembleHap (**本 issue 不使用**)
- 单元测试命令: Python 标准库 `python -m unittest scripts.test_poll_issues -v`
- **UI 自动化测试能力: ✅ 可用 (hdc + 模拟器) 但本 issue 不涉及**
- 模拟器: ["127.0.0.1:5555"]
- hdc 路径: D:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe

## 阶段间确认 (方案 C, 自动答)
- ✅ 阶段间确认一律自动同意
- ✅ 编译环境检查: Python 3.12 (windows-cmd, 不需要 hvigorw/hdc)
- 高风险点检查:
  - [x] capabilities.json 存在 (D:/huawei/Demo/calculatorHuawei/.claude/capabilities.json)
  - [x] Python 解释器可用 (标准库 unittest, 不需要 hdc/hvigorw)
  - [x] PLANNING 识别为 bugfix (非 arch-refactor / platform-migration)
  - [x] delta-spec.md / delta-design.md 不涉及删除现有功能 (仅扩展)
  - [x] 无 SKILL 安全拦截触发

## 进度

### PLANNING 阶段
- [x] **step1**: 用户意图理解 (识别为 bugfix)
- [x] **step2**: rq-parse (输出: 复杂度 S, 单一文件, 无 blocker)
- [x] **step3**: rq-clarify (跳过, 无 blocker 级别模糊点; important 已在 proposal §3.1 决策)
- [x] **step4**: delta-spec.md (需求分解到 8 个 SR + FMEA 8 项)
- [x] **step5**: rq-codebase (info.md 含环境能力 + 风险 + 测试能力评估)
- [x] **step6**: 复杂度评估 (S 简单, 跳过 new-arch.md)
- [x] **step7**: 架构设计 (跳过, 无架构变更)
- [ ] **step8**: mod-design (产出 delta-design.md) ← **当前**
- [ ] **step9**: design-review.md

### IMPLEMENTING 阶段
- [ ] aid-implementing 调出 tasks.md

### APPLYING 阶段
- [x] aid-applying + tdd-enforcer (RED-GREEN-REFACTOR, 真实写代码 + 跑测试)
- [x] 产出 apply-report.md
- 17/17 单元测试通过, 集成测试通过, 422 fallback 保留, .env 注释行被 load_env() 正确跳过

### 收尾
- [ ] git commit (不 push)
- [ ] gh_helper.py comment <num> 通知 littleleafccccc

## 关键决策记录
1. **D1**: 范围仅限 pm-01 profile — 不动 dev-01/rev-01/arch-01 的 poll_issues.py
   - 理由: Issue #30 仅描述 pm-01 的故障, 避免范围蔓延
2. **D2**: 重试策略 3 次 + 2s 指数 + ±0.5s jitter
   - 理由: 30s 内完成, 不阻塞下次 tick, 避免 thundering herd
3. **D3**: 不引入第三方依赖
   - 理由: hermes profile 纯净, 仅用 Python 标准库
4. **D4**: .env 缺省值兜底
   - 理由: 现有部署无需任何修改即可获得重试能力
5. **D5**: 422 仍走原 fallback, 不重试
   - 理由: 422 是业务参数错, 重试无意义; 现有行为不变
6. **D6**: 401/403/404 立即失败
   - 理由: 永久错误, 重试无意义
7. **D7**: 429 按 Retry-After 退避, 不指数
   - 理由: GitHub 明确告诉客户端等多久, 尊重服务端
