# UI 自动化测试产物 (Deferral 文档)

> 变更目录: `specs/changes/20260617-requirement-add-result-display-toggle/`
> 关联 Issue: #27
> 更新时间: 2026-06-29
> 状态: ⏭️ **Deferred — 模拟器未连接** (rev-01 re-dispatch 后的二次诚实披露)

## 目录结构

```
ui-tests/
├── README.md           # 本文件 (deferral 说明 + 未来执行协议)
├── results.json        # 5 AC 状态记录 (全部 deferred)
├── run_tests.py        # 模拟器可用时可直接执行的脚本模板
├── parse_ui.py         # UI 树解析工具 (与 harmonyos-ui-test skill 对齐)
├── screenshot/         # (空) 模拟器可用时产出 PNG
└── dump/               # (空) 模拟器可用时产出 XML/JSON
```

## 真实环境探测 (2026-06-29 重新确认)

| 探测项 | 命令 | 结果 |
|--------|------|------|
| hdc 路径 | `which hdc` | `/d/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc` ✅ |
| hdc 版本 | `hdc version` | `Ver: 3.2.0d` ✅ |
| 已连接设备 (默认) | `hdc list targets` | `[Empty]` ❌ |
| 已连接设备 (verbose) | `hdc list targets -v` | 仅 `COM3`/`COM4` UART Ready (非 HarmonyOS 设备) |
| capabilities.json 声明设备 | 127.0.0.1:5555 | 连接失败 `[Fail]Not match target founded` |
| COM3 直连 | `hdc -t COM3 shell echo HELLO` | `[Fail][E001005] Device not found or connected` |
| COM4 直连 | `hdc -t COM4 shell echo HELLO` | `[Fail][E001005] Device not found or connected` |
| 模拟器进程 | `tasklist \| grep -i emulator` | 无 |

**能力评估**:

| 项目 | 状态 | 详情 |
|------|------|------|
| hdc 可用 | ✅ | 3.2.0d |
| 模拟器/真机在线 | ❌ | hdc list targets 返回空, COM 端口均不可用 |
| 应用已安装 | ❌ | 依赖设备 |
| 应用可启动 | ❌ | 依赖设备 |
| 整体 UI 自动化能力 | ❌ | **环境不满足** |

**结论**: 与 2026-06-17 初次 apply-report 状况完全一致 — capabilities.json
中 `ui_test.available=true` 标注与实际环境存在不一致, 模拟器
`127.0.0.1:5555` 未真正运行。本机 hdc 看不到任何 HarmonyOS 设备。

按 capabilities.json 协议 + 铁律 7 不伪造, **不产出虚假 screenshot / dump**。

## 与 capabilities.json 不一致的责任划分

| 责任方 | 责任 |
|--------|------|
| **配置维护者 (littleleafccccc / dev-01)** | 修复 capabilities.json `emulator_status=running` 与实际 `hdc list targets` 状态不一致的问题; 或启动 127.0.0.1:5555 模拟器 |
| **claude -p (本次 re-dispatch)** | 产出 runnable 脚本模板 + 协议文档, 模拟器可用时一键执行 |
| **rev-01** | 当前次接受 deferral + 协议, 不视为 bloker |

## 模拟器可用时的执行协议

### Step 1: 验证设备

```bash
hdc list targets
# 期望输出: 127.0.0.1:5555    device
```

若仍为空, 启动模拟器:

```bash
# DevEco Studio 菜单 → Tools → Device Manager → Start 模拟器
# 或命令行启动 (路径按实际):
"D:/Program Files/Huawei/DevEco Studio/tools/emulator/emulator.exe" @Nexus_5_API_30
```

### Step 2: 编译并安装 HAP

```bash
cd "D:/huawei/Demo/worktrees/issue-27/opencalc"
PATH="/c/Windows/System32:$PATH" \
DEVECO_SDK_HOME="D:\\Program Files\\Huawei\\DevEco Studio\\sdk" \
"D:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.bat" \
  --no-daemon assembleHap

# 安装 (路径按实际 HAP 产物)
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
```

### Step 3: 启动 app

```bash
hdc shell aa start -a EntryAbility -b com.darkempire78.opencalculator
```

### Step 4: 执行 UI 自动化

```bash
cd "D:/huawei/Demo/worktrees/issue-27"
python3 specs/changes/20260617-requirement-add-result-display-toggle/ui-tests/run_tests.py
```

`run_tests.py` 包含 AC-1~5 全部用例:

| AC | 操作序列 | 预期 | 截图文件名 |
|----|---------|------|-----------|
| AC-1 | tap 1, ÷, 2, = | 结果区显示 `0.5` | `ac1_initial_decimal.png` |
| AC-2 | tap 切换按钮 | 结果区显示 `1/2` | `ac2_toggle_fraction.png` |
| AC-3 | tap 切换按钮 (再次) | 结果区显示回 `0.5` | `ac3_toggle_back_decimal.png` |
| AC-4 | 关闭 app, 重启 | 启动后直接显示 `1/2` (上一轮 FRACTION 模式保留) | `ac4_persist_fraction.png` |
| AC-5 | 计算 `1÷3` (= 0.33333...) | 切换到 FRACTION 仍显示 `0.33333...` (历史记录保持小数) | `ac5_history_decimal.png` |

每个 AC 完成后, `run_tests.py` 会:

1. 截图到 `ui-tests/screenshot/ac{N}_{name}.png` (hdc uitest screenCap)
2. dump UI 树到 `ui-tests/dump/ac{N}_{name}.xml` (hdc uitest dumpLayout)
3. 解析 UI 树, 查找结果区 Text 节点 (resource-id 包含 `result`/`display`)
4. 比对 text 与预期
5. 写结果到 `ui-tests/results.json` (pass/fail)

### Step 5: 提交产物

```bash
git add specs/changes/20260617-requirement-add-result-display-toggle/ui-tests/
git commit -m "test(ui): Issue #27 补 AC-1~5 截图 + dump (设备可用后)"
# force-push 由 dev-01 统一操作
```

## 二次 deferral 的诚实性声明

本 README 与 `results.json` (全部 deferred) 在 2026-06-29 re-dispatch 时生成。
**未产出**:
- 任何 screenshot PNG
- 任何 dump XML/JSON
- 任何伪造的 results.json pass 项

**已产出**:
- 5 个 AC 的协议文档
- runnable 脚本 (模拟器就绪即可执行)
- UI 树解析工具
- 完整状态报告

铁律 7 (不伪造测试结果) 严格遵守。

## 与 20260627 AID 产物的关系

`specs/changes/20260627-requirement-add-进阶/` 是同一 Issue #27 的进阶分支产物
(2026-06-27 重新跑 AID 三阶段, 互引关系见 进阶/apply-report.md §1.2)。
本文档聚焦 20260617 第一次 PR 的 UI 测试补缺, 两者产物独立但结论一致:
**模拟器未连接, UI 自动化均 deferred**。
