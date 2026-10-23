# 应用报告

## 应用信息

- 变更类型：缺陷修复（Tester feedback）
- 变更名称：二维码设备截图可解码修复
- 关联制品：proposal.md / delta-spec.md / delta-design.md / tasks.md
- 应用日期：2026-10-23

## 代码完成情况

| 任务 | 状态 | 完成时间 |
|------|------|----------|
| Task 1.1 统一 213/214 字节容量边界 | ✅ 完成 | 2026-10-23 |
| Task 1.2 加固 QrLayout 边界 | ✅ 完成 | 2026-10-23 |
| Task 2.1 修复 Canvas 最终像素与失败态 | ✅ 完成 | 2026-10-23 |
| Task 3.1 回归、构建与准确 SHA 交接 | ✅ 完成 | 2026-10-23 |

## TDD 执行记录

| 任务 | RED | GREEN | REFACTOR |
|------|-----|-------|----------|
| Task 1.1 | MAX_BYTES=271、214 字节错误放行均被失败断言捕获 | 上限改为 213 后通过 | 注释/契约统一后保持绿色 |
| Task 1.2 | 负尺寸返回 -1 被失败断言捕获 | 有限数、正值、静区守卫后通过 | 统一安全返回 0 后保持绿色 |
| Task 2.1 | 分数网格测试失败；真实原始截图 jsQR 解码失败 | 离散网格、完整白底、明确失败态及关闭抗锯齿后，原始截图解码通过 | 提取 failQrDrawing，复跑保持绿色 |
| Task 3.1 | 汇总前述 RED 与 Tester run-35 失败基线 | 全量 96/96、HAP 构建、三主题及刷新截图解码通过 | 终态复跑保持绿色 |

## 验证结果

- Local Test：`Tests run: 96, Failure: 0, Error: 0, Pass: 96, Ignore: 0`。
- HAP：`opencalc/build-test.bat` BUILD SUCCESSFUL；产物 `entry-default-unsigned.hap`。
- UI：模拟器重装最终 HAP；light/dark/AMOLED 原始截图均由 jsQR 1.4.0 解码为 `OpenCalc\n算式: 1+2\n结果: 3`。
- Freshness：关闭后计算 `2+3=5` 并重开，原始截图解码为 `OpenCalc\n算式: 2+3\n结果: 5`。
- AC8：受保护目录 diff 为空。
- Lint：DevEco CodeLinter 顶层 launcher 在本沙箱复现已知 internal tool-start error；此前同一 QR 源集成功扫描为 0 error，当前修改另由真实 CompileArkTS 构建零 error 覆盖。该限制明确保留为风险，不伪造新的 CodeLinter 成功记录。

## 关键修复

- QrPayload 与 QrEncoder 统一 EC-M v10 byte 模式 213 字节上限。
- QrLayout 对非法、非有限和非离散输入安全失败。
- Canvas 全画布显式白底、黑色整数模块、完整四模块静区；空间不足与绘制异常进入明确失败态。
- QR Canvas 关闭抗锯齿，消除设备截图中的模块接缝；这是本轮真实截图 RED 后确认的最终像素修复。

## 证据

- `opencalc/entry/.test/default/intermediates/test/coverage_data/test_result.txt`
- `opencalc/entry/build/default/outputs/default/entry-default-unsigned.hap`
- `D:/huawei/Demo/calculatorHuawei/.agent-runtime/evidence/task-14/ui-smoke/`
- `D:/huawei/Demo/calculatorHuawei/.agent-runtime/evidence/task-14/codelinter*.log`

## 下一步

由独立 Tester 从最终 PR head 重建、重装并重复三主题与刷新截图解码。不得归档或批准。
