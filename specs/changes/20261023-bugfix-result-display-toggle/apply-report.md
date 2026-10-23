# 应用报告

## 应用信息
- 变更类型：缺陷修复
- 变更名称：result-display-toggle
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 应用日期：2026-10-23
- 关联 Issue：#44

## 代码完成情况
| 任务 | 状态 | 完成时间 |
|------|------|----------|
| Task 1.1 分数转换 | ✅ 完成 | 2026-10-23 |
| Task 1.2 展示选择器 | ✅ 完成 | 2026-10-23 |
| Task 2.1 页面生命周期状态 | ✅ 完成 | 2026-10-23 |
| Task 2.2 可访问切换 UI | ✅ 完成 | 2026-10-23 |
| Task 3.1 自动化注册与回归 | ✅ 完成 | 2026-10-23 |
| Task 3.2 设备 UI 验收 | ⚠️ 环境阻塞，转 Tester | 2026-10-23 |

## 测试结果
- 单元测试：通过，62/62
- 集成测试：设备 UI 阻塞；hdc 3.2.0d 无连接 target
- Lint 检查：通过，CodeLinter 0 error；项目存量 222 warnings，新增 common 文件 0 warning
- 构建：通过，`entry-default-unsigned.hap` 已生成

## TDD 执行记录
| 任务 | RED | GREEN | REFACTOR |
|------|-----|-------|----------|
| Task 1.1 | ✅ 缺失实现与断言失败已确认 | ✅ 4/4 | ✅ 4/4 |
| Task 1.2 | ✅ 模式/分数断言失败已确认 | ✅ 4/4 | ✅ 4/4 |
| Task 2.1 | ✅ 生命周期 API 缺失已确认 | ✅ 6/6 | ✅ 6/6 |
| Task 2.2 | ✅ 可访问标签 API 缺失已确认 | ✅ 7/7 + HAP build | ✅ 7/7 + HAP build |
| Task 3.1 | ✅ 注册入口在实现缺失时失败并发现套件 | ✅ 全量 62/62 | ✅ 全量 62/62 |
| Task 3.2 | ✅ hdc 无 target | ⏳ 待 Tester 设备 | ⏳ 待 Tester 设备 |

## 测试详情
### 单元测试
命令：`hvigorw --no-daemon test -p module=entry -p coverage=false`

结果：`Tests run: 62, Failure: 0, Error: 0, Pass: 62, Ignore: 0`。

### Lint 检查
DevEco CodeLinter 使用 `@typescript-eslint`、`@hw-stylistic`、`@performance`、`@cross-device-app-dev` recommended 规则集并以 error 为门禁。结果为 0 error、222 个项目存量 warning；新增 `FractionUtil.ets` 与 `ResultDisplayPresenter.ets` 无告警。

### 构建
命令：`opencalc/run-build-wt.bat`

结果：`BUILD SUCCESSFUL`；产物为 `opencalc/entry/build/default/outputs/default/entry-default-unsigned.hap`。

### UI 设备验收
`hdc version` 成功；`hdc list targets` 返回 `[Empty]`。阻塞证据与待执行用例位于 `ui-tests/`。

## 代码变更摘要
- 新增有界连分数转换、最简化、整数/负数规范与可靠性门禁。
- 新增纯展示 presenter 和生命周期 snapshot，确保切换不求值、不写历史。
- 页面保存 raw result 与小数快照，在结果区域增加竖横屏共用、带无障碍说明的 32vp 切换入口。
- 长按复制改为复制当前可见表示；AC 与错误状态清理陈旧 raw result。
- 注册并覆盖转换、降级、切换、状态不变量和可访问标签自动化测试。

## 问题与解决
- 初始 Local Test 因 `oh_modules` 未安装而无法解析 Hypium；执行既有 lockfile 的 `ohpm install --all` 后恢复。
- 一次 Hvigor daemon 挂起导致组合命令超时；停止 daemon 并改用 `--no-daemon` 后测试与构建稳定通过。
- 设备 UI 无法执行，已明确转交 Tester，未伪造截图或结论。

## 下一步
由 Tester 执行设备 UI 验收。当前禁止归档或批准。
