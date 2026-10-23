# 当前算式与结果一键生成二维码 - 代码仓理解（info.md）

> rq-codebase 产出 ｜ 分析基线：`2500bf49d79b08b135059419c422a3d49dfb4a73`（PR #41 合并后，Issue #42 指定开发基线）
> 注意：当前工作区分支 HEAD=`672e005`（基线 merge 的第一父提交），本文内容基于 `git show 2500bf4:...` 读取的基线真实代码；分支对齐是 IMPLEMENTING/APPLYING 门禁项（见 todo.md）。

## 1. 基本信息
- **需求类别**：新增功能（orchestrator 元数据标注 refactor，按需求内容纠正，差异已在 todo.md/proposal.md 记录）
- **需求名称**：当前算式与结果一键生成二维码（二维码分享）
- **分析时间**：2026-10-23
- **分析范围**：`opencalc/entry/src/main/ets/`（calculator/model/pages/plot/preferences/entryability）、`opencalc/entry/src/test/`、构建配置（oh-package/build-profile/module.json5）
- **约束边界**：零三方依赖、离线生成、AC8 零退化模块（plot/、calculator/ 算法、model/、preferences/）不得改动
- **重点分析类别**（新增功能 ✓✓ 项）：架构分析、公共组件识别、接口/契约识别、约束检查、构建集成分析

## 2. 模块架构

### 2.1 模块结构图（基线 2500bf4）

```
EntryAbility（mainElement，UIAbility）
  └─ Index.ets（@Entry 启动页）─ router.replaceUrl ─► pages/CalculatorPage.ets（@Entry 主页面）
                                                        │
       ┌────────────────────────────────────────────────┤
       │ CalculatorPage（单页 + Stack overlay 容器）      │
       │  · 显示/按键/历史/设置/关于 状态与 @Builder       │
       │  · overlay: SettingsPanel/AboutPanel/PlotPanel  │
       └── 依赖 ──► calculator/Expression.ets（表达式清洗）
                 ► calculator/Calculator.ets（CalcEngine 求值）
                 ► calculator/NumberFormatter.ets（千分位格式化）
                 ► model/Models.ets（枚举/HistoryItem/偏好模型）
                 ► model/ErrorFlags.ets（静态错误标志，共享可变状态）
                 ► preferences/PreferencesStore.ets（@ohos.data.preferences 持久化）
                 ► plot/FunctionPlotter.ets（采样分段，Issue #40 新增）
                 ► plot/PlotAxis.ets（刻度/标签布局函数，Issue #40 新增）
测试：entry/src/test/List.test.ets → PlotFunction.test.ets（hypium 本地单测）
```

### 2.2 核心模块职责

| 模块 | 职责 | 与本需求关系 |
|------|------|-------------|
| pages/CalculatorPage.ets（~700 行） | 全部 UI 与交互状态：expression/result/errorMsg、面板开关（showHistory/showSettings/showAbout/showPlot）、主题取色函数（getBg/getPanelBg/getT1/getT2…，themeIdx 0=浅色 1=AMOLED 2=暗色）、按钮事件 | **扩展点**：新增二维码入口、showQrShare 状态、QrSharePanel @Builder |
| calculator/Calculator.ets | CalcEngine.evaluate(clean, degreeMode, xVar?) 四则/科学求值 | 只读复用（零改动） |
| calculator/Expression.ets | getCleanExpression(input, decimal, grouping) 表达式清洗 | 只读复用（零改动） |
| calculator/NumberFormatter.ets | 千分位/小数格式化（国际制/印度制） | 只读复用（零改动）；**注意输出含逗号分组符** |
| model/Models.ets | NumberingSystem/HistoryItem/CalculatorPreferences/DEFAULT_PREFERENCES | 只读复用（零改动） |
| model/ErrorFlags.ets | 静态可变错误标志（syntax_error/division_by_0/domain_error/is_infinity/require_real_number）+ reset() | 只读复用（零改动）；门控以 errorMsg 为准 |
| preferences/PreferencesStore.ets | 偏好与历史持久化（getHistory/setHistory/setTheme…） | 不触碰（零改动） |
| plot/FunctionPlotter.ets, plot/PlotAxis.ets | 函数绘图采样/坐标轴（PR #41 能力） | 不触碰（零退化对象） |

### 2.3 扩展点位置
- **overlay 面板模式**（本需求的落点惯例）：`build()` 的 Stack 内 `if (this.showXxx) this.XxxPanel()`，面板为 `@Builder` 成员；关闭仅复位布尔开关（SettingsPanel/AboutPanel/PlotPanel 三个先例）。
- **纯函数模块惯例**：plot/、calculator/ 均为无 UI 依赖的纯逻辑模块，可被 hypium 直接导入测试——qrcode/ 模块沿用此惯例。
- **测试注册惯例**：每个测试文件 `export default function xxxTest()`，在 `List.test.ets` 的 `testsuite()` 中追加调用。

## 3. 接口与契约

### 3.1 外部接口（与本需求相关）

| 接口 | 位置 | 功能 | 参数格式 |
|------|------|------|----------|
| `CalcEngine.evaluate` | calculator/Calculator.ets | 求值 | (cleanExpr: string, degreeMode: boolean, xVar?: number) → number；错误经 ErrorFlags 静态标志 |
| `NumberFormatter.format` | calculator/NumberFormatter.ets | 结果格式化 | (text, '.', ',', INTERNATIONAL) → string；**千分位含逗号**（如 "12,345.5"） |
| `promptAction.showToast` | @kit.ArkUI | 轻提示 | { message: string }；复用既有"已复制"机制 |
| `Canvas/CanvasRenderingContext2D` | ArkUI | 2D 绘制 | PlotPanel 同机制：onReady/onAreaChange 触发重绘 |
| `pasteboard`（既有 onCopy） | @kit.BasicServicesKit | 剪贴板 | 本需求不新增使用 |
| （新增）`buildQrPayload` | qrcode/QrPayload.ets | 载荷构造 | (expression: string, result: string) → string \| 失败态；纯函数 |
| （新增）`encodeQr` | qrcode/QrEncoder.ets | QR 编码 | (text: string) → { size: number, modules: boolean[][] } \| 失败态/异常；纯函数 |

### 3.2 事件机制

| 事件 | 触发条件 | 消费者 | 格式 |
|------|---------|--------|------|
| 入口点击 | 用户点击"二维码分享" | CalculatorPage 门控逻辑 | 函数调用（同步） |
| 面板打开 | showQrShare=true 挂载 | QrSharePanel（现算载荷→编码→绘制） | @Builder 条件渲染 |
| 面板关闭 | 用户点击"✕ 返回" | CalculatorPage | showQrShare=false（唯一副作用） |
| 主题切换 | 设置面板选择主题 | 面板取色函数（码区恒定配色不受影响） | themeIdx 状态 |

### 3.3 调用约束

| 接口 | 约束条件 |
|------|----------|
| ErrorFlags | 导入变量只读 → 用类静态可变字段；使用前必须 reset()（既有惯例） |
| Canvas 绘制 | 必须在 onReady/onAreaChange 后且有有效宽高（canvasW/H>0），PlotPanel 同款守卫 |
| ArkTS 语法 | 禁止嵌套函数（测试辅助函数须模块级）；字面量分支赋值规避枚举类型收窄（CalculatorPage applyHAlign 先例）；显式类型标注（既有代码全量显式标注） |
| 面板开关 | 关闭仅复位自身布尔，不触碰 expression/result（AC7 约束） |

## 4. 构建与集成

- **构建入口**：`opencalc/` 为 hvigor 工程根（hvigorfile.ts + build-profile.json5）；SDK `5.0.0(12)`，runtimeOS HarmonyOS，单模块 `entry`；产品名 `default`（debug/release）。
- **依赖声明**：根与 entry 的 oh-package.json5 `dependencies: {}`（仅 devDependencies: @ohos/hypium 1.0.15、@ohos/hamock 1.0.0）——**本需求不新增任何依赖**。
- **签名**：build-profile 内 signingConfigs 为原移植机 macOS 路径（/Users/jordanzt/...），本机构建/Tester 侧需本地签名适配（工程根已有 run-build.bat/build-test.bat 辅助脚本；Tester 按 AC10 独立构建安装，不属于 Developer 规划改动范围）。
- **页面注册**：`$profile:main_pages`（Index、CalculatorPage 已注册）；本需求不加新路由页（面板为页面内 overlay）。
- **权限**：仅 `ohos.permission.VIBRATE`；**零新增权限**是离线约束的可验证证据。
- **测试执行**：hypium 本地单测经 hvigor；List.test.ets 为唯一注册入口。

## 5. 影响范围

| 模块 | 影响内容 | 风险 |
|------|---------|------|
| pages/CalculatorPage.ets | +入口（DisplayPanel 区）、+showQrShare 状态、+QrSharePanel @Builder、+Canvas 绘码 | 中：触碰主页面，需保证既有布局/手势（长按复制）不受扰动 |
| qrcode/QrPayload.ets（新增） | 载荷构造+容量判定纯函数 | 低：零依赖纯函数 |
| qrcode/QrEncoder.ets（新增） | QR byte/EC-M/v1-10/RS/掩模编码器 | 中：自研编码正确性是最大技术风险（FM-02，RPN 180），以结构断言+独立解码器验证消减 |
| entry/src/test/List.test.ets | 追加 1 行注册 | 低 |
| entry/src/test/QrShare.test.ets（新增） | 载荷/编码/口径断言 | 低 |
| plot/、calculator/ 算法、model/、preferences/、EntryAbility/Index/module.json5、oh-package | **零改动** | 低（AC8 硬约束） |

调用链：入口点击 → 门控（expression/result/errorMsg）→ showQrShare=true → QrSharePanel → buildQrPayload → encodeQr → Canvas。单向依赖，无反向耦合，不破坏既有接口。

## 6. 约束清单

| 约束 | 来源 | 遵守方式 |
|------|------|----------|
| 离线生成、不依赖远端服务 | Issue #42 明文 | 纯 ArkTS 编码器，进程内计算；零网络 Kit、零新增权限 |
| 零三方依赖惯例 | 基线 oh-package dependencies={} | 不新增依赖；编码器自研 |
| AC8 零退化 | Issue #42 验收标准 8 | plot/、calculator/、model/、preferences/ 不改；既有测试保持通过 |
| AC7 状态零扰动 | Issue #42 验收标准 7 | 面板关闭仅复位自身开关（overlay 先例） |
| AC2 逐字一致 | Issue #42 验收标准 2 | 载荷取 this.expression/this.result 原串（含千分位逗号），不重算 |
| ArkTS 语法约束 | 既有代码惯例 | 显式类型、无嵌套函数、字面量分支赋值规避类型收窄 |
| 基线约束 | Issue #42 开发基线 | 一切改动基于 `2500bf4`；分支对齐是 APPLYING Step 0 门禁 |

## 7. 可复用组件

| 组件 | 位置 | 复用方式 |
|------|------|----------|
| overlay 面板模式 | CalculatorPage SettingsPanel/AboutPanel/PlotPanel | 模式复用：@Builder + 布尔开关 + Stack 条件渲染 |
| Canvas 绘制机制 | PlotPanel（canvasCtx/onReady/onAreaChange/守卫） | 模式复用：二维码 Canvas 渲染 |
| 主题取色函数 | CalculatorPage getBg/getPanelBg/getT1/getT2 | 直接复用：面板卡片/文字配色；码区恒定黑白不取主题色 |
| toast 提示 | onCopy 的 promptAction.showToast | 直接复用：不可分享提示 |
| hypium 测试惯例 | PlotFunction.test.ets（describe/it/expect、模块级辅助函数、default 注册函数） | 惯例复用：QrShare.test.ets |
| CalcEngine/NumberFormatter/ErrorFlags | calculator/、model/ | 只读数据来源（本需求不调用新逻辑，载荷直接取显示串） |

## 8. 关键实现

- **核心逻辑（分享链路）**：门控（`expression.length > 0 && result.length > 0 && errorMsg.length === 0`）→ 打开面板 → `buildQrPayload(this.expression, this.result)` → `encodeQr(payload)` → Canvas 白底黑模块绘制 + 4 模块静区 → 关闭仅复位开关。
- **结果串形态**：`this.result` = NumberFormatter.format(raw, '.', ',', INTERNATIONAL)，**可能含千分位逗号**（如 "12,345.5"）与负号；载荷逐字保留（AC2）。错误态时 result 为空串、errorMsg 非空（onEquals 的六个错误分支），门控天然拦截。
- **边界条件**：
  1. 空算式/未按 =/计算失败 → 门控三分支拒绝（SC002-UC001）；
  2. 载荷 > 271 字节（EC-M v10 上限）→ 容量分支提示（SC002-UC002）；
  3. 多字节字符（× ÷ π e 中文提示词不会入载荷，但算式可含 × ÷ π）→ UTF-8 byte 模式正确编码（FM-05/CM-09）；
  4. 面板打开中主题切换 → 码区恒定配色不受影响（FM-09/CM-05）；
  5. 横屏（isLandscape=true 不渲染 ToggleRow）→ 入口置于 DisplayPanel 区保证两方向可用（待定假设 9）。

## 9. 风险与测试

| 风险 | 缓解 | 测试策略 |
|------|------|---------|
| 自研 QR 编码器正确性（FM-02，RPN 180，最高风险） | 结构断言（尺寸公式/定位×3/时序/确定性）+ 容量边界 + 独立解码器抽样（Tester 侧） | QrShare.test.ets 结构断言；AC10 Tester 真实 UI + 解码工具 |
| 载荷不一致（FM-01/05） | 单一纯函数 + 逐字/字节级断言（含 ×÷π、千分位、负数、小数） | 六类口径数据驱动用例 |
| 主页面改动回归（AC8） | 最小侵入（新增状态与 @Builder，不改既有函数）；零改动模块约束 | 既有 PlotFunction.test.ets 同批执行 + 既有功能手工回归 |
| 分支未对齐基线（当前 672e005） | APPLYING Step 0 门禁：先对齐 `2500bf4` | 构建前 git 核对 merge-base |
| 签名配置指向原移植机路径 | Tester 侧本地签名适配（AC10 独立构建） | Tester 构建日志证据 |

## 10. 关键发现

### 可复用组件
- overlay 面板模式、Canvas 绘制守卫机制、主题取色函数、toast 机制、hypium 测试惯例（§7 详表）——本需求全部沿用，不引入新模式。

### 风险提示
- 最大技术风险为自研编码器正确性（FM-02 RPN 180），必须在 TDD RED 阶段先落结构断言。
- `this.result` 含千分位逗号：解码一致性断言必须按原串逐字比对，不得用数值化简。
- 当前工作区分支落后基线 merge 一个合并（缺 plot/ 与 specs/ 全局文件），任何实施前必须先对齐 `2500bf4`。

### 建议
- qrcode/ 两文件保持零 UI 依赖，全部导出为纯函数/纯数据结构，确保 hypium 直接可测。
- 面板 @Builder 命名与文案沿用既有中文惯例（"二维码分享"/"✕ 返回"）。
- 新增代码遵循全量显式类型标注，与基线风格一致（Reviewer 检查项）。
