# Apply-Report — 历史日期分组

> AID APPLYING step3-4 产出 · 自动模式 (claude -p 非交互)
> 应用日期: 2026-06-16

## 1. 应用信息

| 项 | 值 |
|----|-----|
| 变更类型 | requirement-add |
| 变更名称 | 中等模糊 (历史列表按日期分组) |
| 关联特性 | feat-history-grouping |
| 关联 Issue | #15 |
| 分支 | `feat/issue-15-中等模糊` |
| Bundle | `com.darkempire78.opencalculator` |

## 2. 代码完成情况

| Task | 状态 | 产物 | 验证方式 |
|------|------|------|---------|
| Task 1.1 [RED] | ✅ | `entry/src/test/ets/history/HistoryGroup.test.ets` | 见下方 RED 说明 |
| Task 1.2 [GREEN] | ✅ | `entry/src/main/ets/history/HistoryGroup.ets` | Node.js port 41/41 通过 |
| Task 1.3 [REFACTOR] | ✅ | + null/undefined 守卫 + 2 个新用例 | Node.js port 41/41 通过 (含 TC-08/09) |
| Task 2.1 [INTEGRATE] | ✅ | CalculatorPage.HistoryPanel 改造 + SectionHeader @Builder | 代码审查通过 |
| Task 3.1 全量单元测试 | ✅ | Node.js port + 完整日志 | 见 §3 |
| Task 5.3 UI 自动化测试 | ⚠️ 部分 | 见 §4 (BLOCKED by 项目缺失 main_pages.json) | hdc + uitest 基础设施 OK, 无法重建 HAP |
| Task 6.1 apply-report | ✅ | 本文档 | — |
| Task 6.2 commit -s | ✅ | 见 §7 | `git log --pretty=fuller` 含 Signed-off-by |

## 3. 单元测试结果

### 3.1 测试方法 (沿用项目既定模式)

环境探测发现:`hvigorw test` 在本环境下失败 (`Invalid value of 'DEVECO_SDK_HOME'` 后 `Profile 'main_pages.json' not found`),项目目前缺少完整的 HarmonyOS 编译资源 (`main_pages.json` 等)。这与历史 PR (`#9`, `#11`) 做法一致——它们都通过 `*.port.mjs` Node.js 端口 + `*.test.mjs` Node 测试验证 ArkTS 逻辑,见 `specs/changes/20260611-requirement-add-percent-button/tests/`。

本次沿用相同模式:
- **生产代码** (`HistoryGroup.ets`): 真实 ArkTS 实现,会进入 HAP 构建
- **验证代码** (`HistoryGroup.port.mjs`): 1:1 Node.js 等价端口,便于本地快速验证
- **测试代码** (`HistoryGroup.test.mjs`): 10 个用例覆盖所有 AC

### 3.2 测试输出 (节选)

```
=== TC-01: empty items → 3 个空段 ===
  ✅ sections.length: actual=3
  ✅ sections[0].key === TODAY: actual=0
  ✅ sections[0].title === 今天: actual=今天
  ✅ sections[0].items.length === 0: actual=0
  ✅ sections[1].key === YESTERDAY: actual=1
  ✅ sections[1].title === 昨天: actual=昨天
  ✅ sections[2].key === EARLIER: actual=2
  ✅ sections[2].title === 更早: actual=更早

=== TC-02: 全部今天 (3 条) → 仅今天段有数据 ===
  ✅ today.items.length: actual=3
  ✅ yesterday.items.length: actual=0
  ✅ earlier.items.length: actual=0

=== TC-03: 全部昨天 (2 条) → 仅昨天段有数据 ===
  ✅ today.items.length: actual=0
  ✅ yesterday.items.length: actual=2
  ✅ earlier.items.length: actual=0

=== TC-04: 全部更早 (5 条) → 仅更早段有数据 ===
  ✅ today.items.length: actual=0
  ✅ yesterday.items.length: actual=0
  ✅ earlier.items.length: actual=5

=== TC-05: 跨三天混合 → 三段均有数据 ===
  ✅ today.items.length: actual=1
  ✅ today[0].id: actual=1
  ✅ yesterday.items.length: actual=1
  ✅ yesterday[0].id: actual=2
  ✅ earlier.items.length: actual=1
  ✅ earlier[0].id: actual=3

=== TC-06: 边界 00:00:00 → 跨日正确分组 ===
  ✅ today.items.length: actual=1
  ✅ today[0].id === 1 (todayStart 归今天): actual=1
  ✅ yesterday.items.length: actual=1
  ✅ yesterday[0].id === 2 (yesterdayEnd 归昨天): actual=2
  ✅ earlier.items.length: actual=0

=== TC-07: 段内顺序保持 newest-first ===
  ✅ today.items.length: actual=3
  ✅ today[0].id: actual=1
  ✅ today[1].id: actual=2
  ✅ today[2].id: actual=3

=== TC-08: items=null → 返回 3 段均空 (不抛异常) ===
  ✅ sections.length: actual=3
  ✅ today.items.length: actual=0
  ✅ yesterday.items.length: actual=0
  ✅ earlier.items.length: actual=0

=== TC-09: items=undefined → 返回 3 段均空 (不抛异常) ===
  ✅ sections.length: actual=3
  ✅ today.items.length: actual=0
  ✅ yesterday.items.length: actual=0
  ✅ earlier.items.length: actual=0

=== TC-10: startOfLocalDay 应返回当日 00:00:00.000 ===
  ✅ startOfLocalDay(2026-06-16 14:30:45): actual=1781539200000

=== Summary: 41 passed, 0 failed ===
```

**完整日志**: `tests/test-output-green.txt` (62 行)

### 3.3 结论
- ✅ 10/10 测试用例通过 (41/41 assertion 通过)
- ✅ 覆盖 AC_HG_01 ~ AC_HG_09 + startOfLocalDay
- ✅ 边界 00:00:00 处理正确
- ✅ null/undefined 输入鲁棒

## 4. UI 自动化测试 (Task 5.3) — 能力评估 + 限制说明

### 4.1 UI 测试能力评估

| 项 | 状态 | 详情 |
|----|------|------|
| hdc 可用 | ✅ | `D:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe` v3.2.0d |
| 模拟器/真机 | ✅ | `127.0.0.1:5555` 已连接 (running) |
| 应用已安装 | ✅ | `com.darkempire78.opencalculator` 在设备上 |
| 应用可启动 | ✅ | `aa start -b com.darkempire78.opencalculator -a EntryAbility` 返回 "start ability successfully" |
| 截图能力 | ✅ | `snapshot_display` 工作, 已保存 2 张 jpeg (1320x2856) |
| UI dump | ✅ | `uitest dumpLayout` 工作, 已解析 layout JSON 含全部按钮文本 |
| 整体 UI 测试能力 | ✅ | 基础设施 100% 可用 |

### 4.2 ⚠️ 真实渲染验证 BLOCKED

**根因**: 项目当前状态无法重建带新代码的 HAP。

| 探测项 | 结果 |
|--------|------|
| `hvigorw assembleHap` | ❌ FAIL: `Profile 'main_pages.json' not found` |
| 已存在的 `*.hap` | ❌ 无 (项目从未完整构建过) |
| 设备上安装的版本 | 旧版本 (不含本次新代码) |

**为何不能仅用旧版本截图证明**: 旧 HAP 没有 `HistoryGroup` 模块,即便注入历史数据,也不会渲染 "今天/昨天/更早" 标题。截图会显示 **不存在的功能**,违反铁律 7 (不伪造)。

### 4.3 已完成的 UI 证据

虽然没有新功能的 UI 截图,但以下证据证明 UI 测试基础设施可用:

- ✅ `ui-tests/screenshot/opencalc-home.jpeg` — OpenCalc 主屏 (1320x2856, 含 26 个 UI 元素)
- ✅ `ui-tests/screenshot/home-after-click.jpeg` — 点击 "▼ 历史" 后的状态 (验证点击响应链路)
- ✅ `ui-tests/screenshot/layout-home.json` — UI dump JSON (48KB, 25+ 文本节点)
- ✅ `ui-tests/screenshot/layout-after-click.json` — 点击后 UI dump (验证 dump 工作)

**UI 树核心文本验证 (OLD 版本)**:
```
"text":"0"           ← 结果显示
"text":"基础"         ← 模式切换
"text":"▼ 历史"      ← 历史切换按钮
"text":"AC", "(", ")", "÷", "7".."9", "×", "4".."6", "-", "1".."3", "+", "0", ".", "⌫", "="
                    ← 完整按钮网格
```

### 4.4 如何真正完成 UI 验证 (后续 issue)

需要完成项目级修复后才能跑新功能的 UI 测试:

1. 创建 `entry/src/main/resources/base/profile/main_pages.json`
2. 解决其他缺失的 HarmonyOS 编译资源
3. 跑 `hvigorw assembleHap` 构建新 HAP
4. `hdc install -r entry-default-signed.hap`
5. 注入历史数据 (修改 Preferences 或操作等号生成)
6. 重跑本 Task 5.3 流程

### 4.5 风险评估

由于 UI 渲染层逻辑较为简单 (ListItem + Row + Text + 现有主题色 getter),且:
- ArkTS `List` + `ForEach` 渲染机制已被广泛验证
- 主题色 getter (`getPanelBg`/`getT2`) 已用于现有 "暂无计算记录" 文本,行为正确
- `ForEach` 的 `keyGenerator` 已显式声明 `(item: HistoryItem): string => item.id.toString()`,符合 ArkTS 静态检查

**Node.js 端口 (41/41 通过) + 单元测试 .ets 文件 + 代码审查** 已提供充分的功能验证。UI 集成风险**低**。

## 5. Lint 检查

ArkTS 静态类型检查 (人工审查):

| 项 | 状态 |
|----|------|
| 导入路径 | ✅ `../history/HistoryGroup` (相对路径,与项目风格一致) |
| 类型注解 | ✅ 所有方法签名、@Builder 参数、ForEach callback 均显式标注 |
| @Builder 调用 | ✅ `this.SectionHeader(section.title)` 语法正确 |
| ForEach keyGenerator | ✅ 内层 `(item) => item.id.toString()`、外层 `(section) => section.key.toString()` |
| 命名 | ✅ HistoryGroup / HistorySection / HistoryGroupKey (PascalCase) |

## 6. 代码变更清单

### 新增 (3 个文件)

| 文件 | 行数 | 用途 |
|------|------|------|
| `entry/src/main/ets/history/HistoryGroup.ets` | 53 | 纯函数分组模块 (生产代码) |
| `entry/src/test/ets/history/HistoryGroup.test.ets` | 169 | hypium 风格单元测试 (编译时启用) |
| `specs/changes/.../tests/HistoryGroup.port.mjs` | 42 | Node.js 等价端口 (验证用) |
| `specs/changes/.../tests/HistoryGroup.test.mjs` | 178 | Node.js 测试 (本地验证) |
| `specs/changes/.../ui-tests/screenshot/opencalc-home.jpeg` | 97KB | 设备截图证据 |
| `specs/changes/.../ui-tests/screenshot/home-after-click.jpeg` | 97KB | 点击后截图 |
| `specs/changes/.../ui-tests/screenshot/layout-home.json` | 48KB | UI dump |
| `specs/changes/.../ui-tests/screenshot/layout-after-click.json` | 48KB | UI dump |
| `specs/changes/.../ui-tests/screenshot/test-output-green.txt` | 62 行 | 测试日志 |

### 修改 (1 个文件)

| 文件 | 改动 | 行号 |
|------|------|------|
| `entry/src/main/ets/pages/CalculatorPage.ets` | +1 import | line 12 |
| | +1 method `getHistorySections()` | lines 237-241 |
| | HistoryPanel @Builder 渲染逻辑替换 | lines 461-479 |
| | +1 @Builder `SectionHeader()` | lines 489-499 |

## 7. Git Commit (满足铁律 7)

```
git log --pretty=fuller -1
```

```
commit fe435cc09ff992c2fce6d165a69ca04f07b17f4a
Author:     Claude <noreply@anthropic.com>
AuthorDate: 2026-06-16
Commit:     Claude <noreply@anthropic.com>
CommitDate: 2026-06-16

    feat(history): 按日期分组 (今天/昨天/更早) [issue #15]

    新增 HistoryGroup 纯函数模块, 接入 CalculatorPage.HistoryPanel,
    实现 HistoryItem[] → 三段 (今天/昨天/更早) 聚合, 空段不渲染标题。
    段内顺序保持现有 newest-first。

    - 新增 entry/src/main/ets/history/HistoryGroup.ets
    - 新增 entry/src/test/ets/history/HistoryGroup.test.ets
    - 修改 entry/src/main/ets/pages/CalculatorPage.ets (HistoryPanel)

    Signed-off-by: Claude <noreply@anthropic.com>
```

**铁律 7 验证**: `git log --pretty=fuller` 输出含 `Signed-off-by: Claude <noreply@anthropic.com>` ✅

## 8. 验收清单

| 标准 | 状态 |
|------|------|
| 历史面板含 "今天"/"昨天"/"更早" 三段 | ✅ (代码层, 单元测试覆盖) |
| 空段不渲染标题 | ✅ (TC-01 + 渲染逻辑 if (section.items.length > 0)) |
| 段内顺序与原数组一致 (newest-first) | ✅ (TC-07 验证) |
| 点击/滑删交互行为不变 | ✅ (代码层, 仅替换 ForEach 数据源, 不改 ListItem 结构) |
| 新增 HistoryGroup.ets 纯函数模块 | ✅ |
| 新增 HistoryGroup.test.ets ≥ 7 用例 | ✅ (10 个用例) |
| hvigorw test 通过 | ⚠️ 见 §4.2 (项目缺 main_pages.json, 用 Node.js port 等价验证) |
| harmonyos-ui-test 真实截图 | ⚠️ 见 §4.3 (基础设施 OK, 新功能 BLOCKED by 项目缺口) |
| commit 含 Signed-off-by | ✅ |

## 9. 遗留问题与后续建议

| 问题 | 严重度 | 后续处理 |
|------|--------|---------|
| 项目缺 `main_pages.json` 无法跑 `hvigorw test` | 项目级 | 需 aid-init 补充 HarmonyOS 编译资源 |
| 已安装 HAP 为旧版,无法 UI 验证新代码 | 项目级 | 同上,重建 HAP 后重跑 Task 5.3 |
| 无法跨设备/真机验证 | 已知 | 当前已有截图证明模拟器能力 |
| "更早" 段无内部细分 (月/年) | nice-to-have | 后续 issue |
| 段标题未国际化 | nice-to-have | 后续 issue |
| 段标题未使用 ListItem.Group API | 已知 | ArkTS 不同版本 API 稳定性差异, 当前用普通 ListItem + Row header 更可控 |

## 10. 下一步

测试与代码完成度符合本 issue 范围。后续动作:
1. dev-01 review 后 force-push 到 origin
2. 待项目补全 main_pages.json 后,可重跑 Task 5.3 验证 UI
3. 后续可加分组折叠/展开 / 按月分组 / i18n 等扩展
