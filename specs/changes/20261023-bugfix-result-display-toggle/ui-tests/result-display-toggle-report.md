# 结果小数/分数切换 UI 自动化报告

## 基本信息

| 项目 | 内容 |
|------|------|
| 应用 | OpenCalc HarmonyOS |
| 日期 | 2026-10-23 |
| 工具 | hdc 3.2.0d |
| 设备 | 未连接 |
| 用例文件 | `result-display-toggle-cases.md` |

## 结果

| 状态 | 数量 |
|------|------|
| PASS | 0 |
| BUG | 0 |
| Blocked | 8 |
| 总计 | 8 |

全部设备 UI 用例在 RED 环境检查阶段被同一前置条件阻塞：`hdc list targets` 返回 `[Empty]`。未执行点击、截图、无障碍树或剪贴板操作，也未虚构设备结果。

设备无关的自动化证据已通过：FractionUtil 4/4，ResultDisplayPresenter/生命周期/可访问标签 7/7，全量 Local Test 62/62，HAP 构建成功，CodeLinter 0 error。

## Tester 后续

连接真机或模拟器后，按用例文件逐条执行并保存每条用例的截图和 UI tree；重点验证横屏入口、32vp 触控高度、分数态复制以及历史不重复。
