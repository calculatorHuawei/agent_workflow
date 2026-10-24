# 小费计算器与多人账单分摊 - 代码仓理解

## 1. 基本信息
- **需求类别**：产品语义为新增功能；编排目录类型为 bugfix。
- **需求名称**：小费计算器与多人账单分摊。
- **分析时间**：2026-10-24。
- **分析范围**：`opencalc/entry/src/main/ets`、模块/路由配置、既有测试与规格制品。
- **约束边界**：仅规划；不修改产品源码，不运行构建或测试，不新增依赖/权限/持久化。

## 2. 模块架构

```text
Index.ets --router.replaceUrl--> CalculatorPage.ets
                                   ├─ calculator/{Expression,Calculator,NumberFormatter}
                                   ├─ preferences/PreferencesStore
                                   ├─ model/{Models,ErrorFlags}
                                   └─ plot/{FunctionPlotter,PlotAxis}
```

| 模块 | 现有职责 | 与本需求关系 |
|------|---------|-------------|
| `pages/CalculatorPage.ets` | `@Entry` 单页；V1 `@State`；主计算、历史、设置、关于和绘图覆盖层 | 主要扩展点 |
| `calculator/*` | 通用表达式解析、运算和数值格式化 | 不复用来解析受约束账单表单，保持不变 |
| `preferences/PreferencesStore.ets` | 主题、模式、历史等 Preferences 持久化 | 明确不修改 |
| `plot/*` | 绘图纯逻辑与坐标渲染支持 | 回归边界，不修改 |
| `entry/src/test` | Hypium 本地单元测试 | 后续增加纯逻辑测试 |

既有扩展惯例是 `CalculatorPage` 的 `Stack` 条件渲染覆盖层：`SettingsPanel`、`AboutPanel`、`PlotPanel`。本需求复用该模式比新增路由页更安全。

## 3. 接口与契约

### 3.1 外部接口
无网络、云、支付或外部服务接口。

### 3.2 关键内部契约
| 接口/状态 | 位置 | 当前契约 | 设计约束 |
|----------|------|----------|----------|
| `showPlot/showSettings/showAbout` | CalculatorPage | 布尔状态驱动覆盖层 | 新增 `showTip` 沿用同型模式 |
| `history` / `PreferencesStore.setHistory` | CalculatorPage / PreferencesStore | 仅主计算 `onEquals` 增加历史 | TipPanel 不调用、不改数组 |
| `themeIdx` + `getBg/getPanelBg/getT1/getT2/getOp/getErr` | CalculatorPage | 三主题动态色 | TipPanel 复用，避免新增主题体系 |
| `isLandscape` | CalculatorPage | 根区域变化更新布局；横屏隐藏 ToggleRow | 小费入口必须为横屏提供独立可达点 |
| `@State` | CalculatorPage | V1 响应式状态 | 输入变化和派生结果必须同步刷新 |

### 3.3 事件机制
无总线。ArkUI `onClick` / `onChange` 直接更新 `@State`，条件渲染和依赖文本随之刷新。

## 4. 构建与集成
- 构建入口：`opencalc/hvigorfile.ts`、`build-profile.json5`；entry 为单 HAP。
- 路由：`Index` 启动后替换到 `pages/CalculatorPage`；无需添加页面或修改 `main_pages.json`。
- 依赖：根/entry `oh-package.json5` 不需要新增包。
- 权限：`module.json5` 不需要新增权限。
- 测试：`opencalc/entry/src/test` 已存在 Hypium 测试；纯逻辑文件可按既有 Plot 测试方式导入。

## 5. 影响范围
| 模块/文件 | 影响内容 | 风险 |
|-----------|---------|------|
| `pages/CalculatorPage.ets` | 增加入口、TipPanel 和状态 | 覆盖层互斥、横屏可达性、主状态污染 |
| `tip/TipCalculator.ets`（候选新增） | 校验、整数分值换算、计算、格式化 | 小数精度、溢出、错误优先级 |
| `entry/src/test/TipCalculator.test.ets`（后续） | 核心与边界测试 | 测试必须对语义结果断言 |

调用链：`Toggle/landscape entry → onOpenTip → TipPanel input onChange → validate/calculate → @State result/error → ArkUI rerender`。

## 6. 约束清单
| 约束 | 来源 | 遵守方式 |
|------|------|----------|
| 现有普通、科学、绘图和历史不受影响 | Issue | 不修改计算引擎/历史持久化；面板为隔离状态 |
| 自动更新 | Issue | 每个输入事件统一调用重新计算，不提供“计算”按钮 |
| 金额两位小数 | Issue | 内部以分为单位，输出固定两位 |
| 非法人数禁止除法 | Issue | 验证通过前不得进入计算分支 |
| 无新增权限/服务 | 最小权限原则 | 本地纯逻辑，无 Kit 增量 |
| ArkTS 静态约束 | 代码基线 | 明确 interface，避免 `any`、动态对象形状和新语言特性 |

## 7. 可复用组件
| 组件 | 位置 | 复用方式 |
|------|------|----------|
| 覆盖面板布局 | `CalculatorPage.PlotPanel/SettingsPanel` | Stack 条件渲染、标题行关闭按钮、全屏主题背景 |
| 主题方法 | `CalculatorPage` | 所有文本、按钮、错误和面板沿用现有色值 |
| 响应式状态 | `CalculatorPage @State` | 原始输入、选择、错误、结果分别建稳定字段 |
| Hypium 测试样式 | `entry/src/test/PlotFunction.test.ets` | 纯逻辑导入与确定性断言 |

`NumberFormatter` 面向普通计算器分组与科学数字，不适合作为货币格式器；强行复用可能引入分组或精度差异，因此小费模块使用专用两位格式。

## 8. 关键实现现状
- `CalculatorPage` 将表达式、结果、历史、面板开关和主题都保存在同一组件实例中；覆盖层不会触发路由或页面销毁，适合状态保留。
- 竖屏 `ToggleRow` 有科学/基础、绘图、历史和设置入口；横屏不渲染 ToggleRow，只在 `DisplayPanel` 提供历史开关，因此小费入口需要同时设计横屏入口。
- 主计算历史仅在 `onEquals()` 成功后创建 `HistoryItem` 并调用 `setHistory()`；隔离小费逻辑即可保证历史不变。
- `PlotPanel` 已验证“全屏 Builder + showX 条件渲染 + 返回关闭”的仓内惯例。

## 9. 风险与测试
| 风险 | 缓解 | 测试策略 |
|------|------|----------|
| IEEE-754 导致 `x.xx5` 舍入漂移 | 输入转分/万分比例后进行整数/受控舍入；限定安全范围 | 精确边界表驱动单测 |
| 人数非法仍除法 | 校验结果与计算分支分离 | 0、负数、小数、空值、非数字 |
| 无效后旧结果残留 | 每次重算先清结果，再验证 | 有效→非法→有效 UI 序列 |
| 预设和自定义选中态冲突 | 单一 `tipMode/tipPercent` 来源 | 点击四个预设并编辑自定义 |
| 覆盖层污染主状态/历史 | Tip 状态独立且不调用引擎/Preferences | 预置表达式与历史后进出对比 |
| 横屏入口不可达 | 在横屏 DisplayPanel 操作区增加入口 | 横竖屏 UI 测试 |
| Tester 证据弱化为截图 | AC 使用精确显示值和状态差异 oracle | 测试报告关联 AC ID 与断言结果 |

## 10. 关键发现与建议
- 最小设计为一个新纯逻辑模块加 `CalculatorPage` 内的覆盖层，不需要新页面、路由、权限、依赖或持久化。
- 使用会话内状态保留输入既便于返回，也不会改变应用重启和历史语义。
- 当前仓库没有程序员模式。兼容性验收覆盖所有现存模式，并把“不得补建/破坏程序员模式”作为范围约束。
- `new-arch.md` 可跳过：主分层、模块边界、外部交互和数据流方向均不变。
