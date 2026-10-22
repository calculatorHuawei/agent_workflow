# 函数图像绘制（Issue #40） - 代码仓理解

## 1. 基本信息
- **需求类别**：新增功能
- **需求名称**：函数图像绘制：输入 sin(x) 显示曲线
- **分析时间**：2026-10-22
- **分析范围**：opencalc/entry/src/main/ets（calculator/、model/、pages/、preferences/）+ 构建配置 + 测试基建
- **约束边界**：不新增 @Entry 页面；不改 main_pages.json/module.json5；不引入第三方依赖；ArkTS 语法限制（无解构、无 any、类静态可变字段模式）

## 2. 模块架构

```
opencalc/entry/src/main/ets/
├── entryability/EntryAbility.ets     # UIAbility 入口，加载 pages/Index
├── pages/
│   ├── Index.ets                     # 启动页 → replaceUrl(CalculatorPage)
│   └── CalculatorPage.ets            # 唯一业务页面（@Entry + Stack 面板覆盖层）
├── calculator/
│   ├── Calculator.ets                # CalcEngine：递归下降解析器（字符码驱动）
│   ├── Expression.ets                # 表达式预处理（符号替换/隐式乘法/括号补齐）
│   └── NumberFormatter.ets           # 结果格式化（绘图不涉及）
├── model/
│   ├── Models.ets                    # 枚举 + HistoryItem/CalculatorPreferences 接口
│   └── ErrorFlags.ets                # 全局静态错误标志 + reset()
└── preferences/PreferencesStore.ets  # 偏好持久化（绘图不涉及）
```

- 核心模块职责：
  - **CalcEngine.evaluate(equation, isDegree)**：入口；字段 eq/p/c/deg 为实例状态；`parseFactor` 中小写字母连续段解析为函数名（未知名→syntax_error）；`^` 幂在 factor 尾部处理
  - **Expression.getCleanExpression(calculation, decSep, grpSep)**：replaceSymbols（×÷→*/、log→logten、**E→\*10^、exp→xp**、逆三角→arc*）→ addMultiply（隐式乘法）→ √/%/! 格式化 → addParenthesis
  - **CalculatorPage**：@State UI 状态；Stack 叠放全屏面板（Settings/About 为条件渲染 Builder，History 为内嵌 Builder）；主题色函数（getBg/getBtnBg/getPanelBg/getFuncBg/getOp/getEq/getClr/getErr/getT1/getT2/getBtnText）
- 扩展点位置：
  - 变量绑定 → `CalcEngine.parseFactor` 函数名分支（fn==='x' 且绑定生效 → 返回变量值）
  - x 隐式乘法 → `Expression.addMultiply`（须排除 'xp' 序列）
  - 绘图面板 → `CalculatorPage.build()` Stack 增加条件渲染 Builder（与 showSettings/showAbout 同模式）
  - 采样器 → 新增 `plot/FunctionPlotter.ets` 纯逻辑类

## 3. 接口与契约
### 3.1 外部接口
| 接口 | 位置 | 功能 | 参数格式 |
|------|------|------|----------|
| CalcEngine.evaluate | calculator/Calculator.ets:28 | 求值 | (equation: string, isDegree: boolean) => number；错误经 ErrorFlags 报告 |
| Expression.getCleanExpression | calculator/Expression.ets:8 | 预处理 | (calculation: string, decimalSeparatorSymbol: string, groupingSeparatorSymbol: string) => string |
| ErrorFlags.reset | model/ErrorFlags.ets:17 | 清零 5 个静态标志 | () => void |
| NumberFormatter.format | calculator/NumberFormatter.ets | 结果格式化 | (raw: string, dec: string, grp: string, system: NumberingSystem) => string |

### 3.2 事件机制
| 事件 | 触发条件 | 消费者 | 格式 |
|------|---------|--------|------|
| onEquals | '=' 点击 | CalculatorPage | 表达式求值 + 历史写入 + prefs 持久化 |
| onDigit/onOp/onFunc/onConst/onBS/onAC | 按钮点击 | CalculatorPage | 追加/删除表达式字符；onFunc 追加 `name(` |
| onAreaChange | 页面尺寸变化 | CalculatorPage | isLandscape 判定（w>h），横屏强制 scientific=true |
| LongPressGesture(显示区) | 长按显示屏 | onCopy | 复制结果到剪贴板 |

### 3.3 调用约束
| 接口 | 约束条件 |
|------|----------|
| evaluate | 非线程安全（实例字段状态）；错误不在调用点抛出，必须求值后读 ErrorFlags；deg=true 表示角度模式（sin 参数×π/180） |
| getCleanExpression | 必须在 evaluate 之前调用；同实例可重复调用（无状态，方法内局部变量） |
| ErrorFlags | 全局共享可变状态——采样循环中每点求值前必须 reset，否则跨点污染 |

## 4. 构建与集成
- 构建入口：`opencalc/` 目录，`hvigorw assembleHap`（PATH 内 hvigorw 6.24.2；DevEco 环境变量已由机器配置；checked-in 包装脚本 build-test.bat/run-build.bat/run-build-wt.bat 编码了相同环境，但本会话权限策略禁止直接执行 .bat）
- 集成方式：单模块 entry；无第三方运行时依赖（entry/oh-package.json5 dependencies 为空）；根 oh-package.json5 devDependencies 含 @ohos/hypium 1.0.15 + @ohos/hamock 1.0.0（测试基建可用）
- 裁剪机制：不涉及（单产品 default）
- 发布形式：`entry/build/default/outputs/default/entry-default-unsigned.hap`（本地无签名配置，SIGN 由 Tester/环境负责）
- 测试：`hvigorw test@entry` 本地单测路径 `entry/src/test/`（目录当前不存在，需创建 List.test.ets 入口）
- 页面路由：main_pages.json 仅 pages/Index + pages/CalculatorPage——**新增 UI 不应新增路由页**

## 5. 影响范围
| 模块 | 影响内容 | 风险 |
|------|---------|------|
| calculator/Calculator.ets | parseFactor 增加变量 x 分支；evaluate 增加可选第三参 | 默认路径回归（可选参数+默认无绑定缓解） |
| calculator/Expression.ets | addMultiply 增加 x 规则 | 误伤 'xp'（e^x）序列、'exp' 已在 replaceSymbols 映射为 'xp' |
| pages/CalculatorPage.ets | ToggleRow 入口 + PlotPanel Builder + 科学区 x 按钮 + Canvas | 布局挤压既有按钮；主题色遗漏 |
| model/ErrorFlags.ets | 不改动，仅新增调用 reset() | 无 |
| entry/src/test/ | 新建 hypium 本地单测 | 测试框架配置首次搭建 |

## 6. 约束清单
| 约束 | 来源 | 遵守方式 |
|------|------|----------|
| 不新增 @Entry 页面/路由 | 现状（main_pages.json 两页）+ 低回归目标 | PlotPanel 用 CalculatorPage 内条件渲染 Builder |
| ArkTS 语法限制 | 项目注释（Calculator.ets 头部：类方法代替内部函数） | 纯逻辑类用 class + 静态/实例方法，不用闭包捕获 this 之外的模式 |
| 隐式乘法规则集中 | Expression.addMultiply 为唯一插入点 | x 规则加在同函数，函数名分支保护 'xp' |
| 错误经 ErrorFlags 而非异常 | 既有约定 | 采样逐点 reset + 检查 |
| 中文错误文案 | 既有 UI 文案（'表达式错误'等） | 绘图错误提示复用同风格 |
| 权限策略禁止执行 .bat | 本会话权限系统 | 直接调用 PATH 内 hvigorw |

## 7. 可复用组件
| 组件 | 位置 | 复用方式 |
|------|------|----------|
| CalcEngine | calculator/Calculator.ets | 采样逐点调用 evaluate |
| Expression | calculator/Expression.ets | 绘制前清洗一次 |
| ErrorFlags | model/ErrorFlags.ets | 采样有效性判定 |
| 主题取色函数 | CalculatorPage（getBg 等 11 个） | PlotPanel 配色一致 |
| 面板覆盖模式 | Stack + 条件渲染 Builder（Settings/About） | PlotPanel 同模式 |
| hypium 测试依赖 | 根 oh-package.json5 devDependencies | 本地单测直接使用 |

## 8. 关键实现
- 核心逻辑：
  - 解析器对连续小写字母段（97-122）整体解析为函数名：`xp`（2 字符）优先于单字符——变量 `x` 命名为 fn==='x' 天然无冲突（最长段匹配）
  - addMultiply 的函数名列表 functionsList 含 'xp'；处理 'x' 时须先检查 `substring(i, i+2) === 'xp'` 跳过
  - `x` 的隐式乘法双向规则：前邻（数字/) /π/e/x）插入前置 `*`；后邻（数字/π/( /x /函数名字母）插入后置 `*`
- 边界条件：
  - 'exp' 在 replaceSymbols 中先被 'E'→'*10^' 影响？否——'E' 为大写，'exp' 小写不受影响；顺序为 E→\*10^ 后 exp→xp
  - 数字重复小数点 / 孤立 '.' → syntax_error（既有）
  - evaluate 空字符串：nx 后 c=-1 → parseFactor → else 分支 syntax_error（既有，绘图入口需前置空检查）
  - 采样 N 点含双端点：x_i = xMin + i*(xMax-xMin)/(N-1)，N=401 时步长恰为 π/100
  - 1/x 在 x=0：d===0 → division_by_0 置位、返回 0——有效性与 isFinite 双重判定缺一不可
  - tan(x) 在 ±π/2：浮点近似值非 Inf 而是大数（~1.6e16），isFinite 为 true 但视觉发散——需按 |y| 夹持阈值（如 1e6）判无效

## 9. 风险与测试
| 风险 | 缓解 | 测试策略 |
|------|------|----------|
| 既有求值回归 | varX 可选参数、默认无绑定走原路径 | 单测 AC：未绑定 sin(x) 报错、常数表达式不变 |
| 'xp' 误伤 | addMultiply 'xp' 序列保护 | 单测：2xp3=2*e^3、xp(1)≈e |
| 错误标志跨采样点污染 | 每点 reset | 单测：1/x 仅 x=0 无效 |
| tan 发散点误连 | 有限值但超大 → 夹持阈值判无效 | 单测：tan 分段数 >1 |
| Canvas 首帧/尺寸时序 | onAreaChange/绘制按钮触发时重建 | UI 由 Tester 验证；逻辑层不依赖 Canvas |
| 测试框架首次搭建 | 遵循 hypium 本地单测模板 | APPLYING 阶段 hvigorw test@entry 退出码 0 |

## 10. 关键发现
### 可复用组件
- CalcEngine / Expression / ErrorFlags / 主题取色函数 / Stack 面板模式 / hypium 依赖

### 风险提示
- ErrorFlags 全局静态状态是采样正确性的最大隐患（CM-02）
- 'xp' 与变量 'x' 的字符串级区分是预处理改动的主要回归点（CM-03）
- tan(x) 发散点为有限大数，仅 isFinite 判定不足（需幅值夹持）
- 本会话禁止执行 .bat 包装脚本，构建须直接调用 hvigorw（环境变量已由机器全局提供，基线构建已验证通过）

### 建议
- 采样器做成纯逻辑类（无 @Component 依赖），先写单测再实现（TDD）
- PlotPanel 保持与 Settings/About 相同的条件渲染 Builder 惯例，避免新增路由
- 隐式乘法 'x' 规则的每个分支都配单测（2x、x2、x(x+1)、πx、ex、xx、xp 保护）

## 11. 补救轮代码仓理解（R4 可读坐标系，2026-10-22 追加）

### 11.1 基本信息
- **需求类别**：功能变更（渲染可读性补救）
- **分析范围**：plot/、pages/CalculatorPage.ets 绘图渲染路径、entry/src/test/
- **约束边界**：无 UI 依赖的纯逻辑惯例；无缩放/平移/自定义范围；标签 ≥14px

### 11.2 现有绘图渲染路径（FunctionPlotter → CalculatorPage）
| 代码点 | 位置 | 现状 | R4 影响 |
|--------|------|------|---------|
| PlotPoint/PlotSegment/PlotResult | plot/FunctionPlotter.ets:9-29 | 采样分段数据契约 | 不变（R4 只消费） |
| PLOT_X_MIN/MAX/N | plot/FunctionPlotter.ets:32-34 | -2π/2π/401 | 复用为刻度范围输入 |
| mathToPx | CalculatorPage.ets:158 | 数学→像素映射 | 复用 |
| drawPlot | CalculatorPage.ets:171 | clear→drawAxes→drawCurve | 改为 clear→drawGrid→drawAxes(刻度+标签+轴名)→drawRangeText→drawCurve |
| drawAxes | CalculatorPage.ets:179 | x 轴+y 轴+10px center 标签（边缘必裁切）、无 Y 刻度 | 重写：PlotAxis 驱动刻度/标签/轴名 |
| drawCurve | CalculatorPage.ets:215 | 分段折线最后绘制 | 保持最后绘制（网格不遮挡曲线） |
| 主题色 | getT1/getT2/getOp/getPanelBg（CalculatorPage.ets:239-303） | themeIdx 0/1/2 | 标签色沿用 T2 语义；网格色新增低对比纯函数 |
| 测试脚手架 | PlotFunction.test.ets（4 套件 30 用例） | hypium 本地 | 新增 PlotAxisTest 套件 |

### 11.3 新增模块约束（PlotAxis）
- 位置：entry/src/main/ets/plot/PlotAxis.ets（与 FunctionPlotter 同层同惯例）
- 纯逻辑：不得 import ArkUI/@Component；输入输出皆为 number/string/接口数组 → hypium 本地可测
- 契约：AxisTick{value,label}；xAxisTicks(xMin,xMax)（π 倍数步长，5~9 条）；yTicks(yMin,yMax,minCount)（{1,2,5}×10^k，退化输入返回 []）；水平/垂直标签布局函数返回夹持后锚点+对齐；PLOT_LABEL_FONT_PX≥14；plotGridColor(themeIdx)/plotLabelColor(themeIdx)

### 11.4 补救轮风险与测试策略
| 风险 | 缓解 | 测试策略 |
|------|------|---------|
| 边缘标签仍裁切 | 布局函数以"锚点±半宽不越 [0,w]"为契约 | 单测：左缘/右缘/顶缘/底缘/中部五点断言 |
| Y 刻度数量/值错误 | nice-number 算法（业界标准） | 单测：[-1.2,1.2]→含 ±1/±0.5/0 五条；[0.8,3.2]→≥5 条整数 |
| 退化输入抛异常 | yMin≥yMax 或非有限 → 返回 [] | 单测：不抛异常且空数组 |
| 三主题不可读 | 色值纯函数按 themeIdx 返回 | 单测：网格色/标签色/背景两两不同；字号常量 ≥14 |
| 绘制顺序回归 | drawPlot 单一顺序入口 | Tester UI 截图（网格不遮挡曲线） |

## 12. 补救轮代码仓理解（R5 渐近线视觉分离，2026-10-22 追加）

### 12.1 基本信息
- **需求类别**：缺陷修复（SR-01 绘制结果补救 + 持久化回归测试）
- **分析范围**：plot/FunctionPlotter.ets 分段与 y 范围逻辑、pages/CalculatorPage.ets drawCurve/drawAxes、entry/src/test/
- **约束边界**：不改 plot() 签名与返回语义；无缩放/平移/自定义范围；不改既有有效性（totalValid）语义

### 12.2 缺陷机理定位（d905042 后残留，用户实测反馈）
| 代码点 | 位置 | 现状 | R5 影响 |
|--------|------|------|---------|
| plot() 有效性判定 | FunctionPlotter.ets:58-75 | valid = 无错误标志 ∧ isFinite ∧ \|y\|≤1e6——1/x 在 x=±0.031 处 y=±31.8 仍为"有效点" | 有效性语义保留；新增"可绘制"层 |
| yRange 稳健裁剪 | FunctionPlotter.ets:123-149 | 2%~98% 中心范围抑制渐近线极值压扁（1/x → [-4.2,4.2]） | 保留不变（截图证实主体可读） |
| buildSegments | FunctionPlotter.ets:89-117 | 仅"无效点断段 + 跨零且 \|Δy\|>1.5×span 断段"——同号大跳变（如 1/x 左支 -15.9→-31.8）不断段且全部参与连线 | 收紧：视窗裁剪 + 断口阴影 |
| drawCurve | CalculatorPage.ets:324-340 | moveTo/lineTo 无像素夹持（折线可达画布外 2×h 以上） | 增加 ±2px 超扫夹持（防御） |
| drawAxes | CalculatorPage.ets:212-227 | plotLabelColor 1px、绘制于曲线之后 | 改 getT1 主文字色 2px（轴/曲线/网格三方可辨） |
| 真实 UI 证据 | .agent-runtime/evidence/plot-asymptote-remediation/ | 02_1overx_committed.png：右支顶端/左支底端与 Y 轴汇聚粘连；03_logx.png：曲线贴轴冲出底边 | 修复靶点 |

### 12.3 修改约束（FunctionPlotter 内部语义收紧）
- 纯逻辑：不新增 import、不新增模块；PLOT_VIEW_INSET_RATIO 导出常量供测试引用
- 兼容：sin(x)/x²/常数/sqrt 既有断言零回归（sin 峰值 ±1.0 距裁剪线 ±1.08 有浮点余量）
- 可测试：视窗/阴影皆为纯数据判定，hypium 本地直接断言 segments 集合

### 12.4 补救轮风险与测试策略
| 风险 | 缓解 | 测试策略 |
|------|------|---------|
| 裁剪误伤连续函数 | inset=span/20（0.5×padding）；病态回退（全不可绘制→绘制全部有效点） | AC4 零回归断言（sin 401 点单段含峰、x² 含顶点） |
| 断口阴影误伤 sqrt 顶点 | 已裁决接受 1 步长（≈3px）缩进（proposal §12.2 决策 2） | 断言绘制点 x ≥ 1 步长（既定语义） |
| totalValid 语义漂移 | 有效性计数与可绘制性解耦，"无可绘制的有效数据点"路径不变 | 既有 1/x 400 有效用例不回归 |
| 轴线样式三主题不可辨 | getT1 为既有主文字色（黑/#EFEFEF），对比度高于原标签灰 | Tester 三主题截图终验 |
