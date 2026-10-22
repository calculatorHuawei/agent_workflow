# 函数图像绘制（Issue #40） 增量设计（delta-design）

> 增量设计：专注变更点。基线架构见全局 specs/design.md（当前为骨架）与 opencalc/README.md §架构。
> 需求追溯：delta-spec.md §8 SR-00/01/02；代码事实来源：info.md。

---

## 1. 概述

### 1.1 应用定位
OpenCalc HarmonyOS 科学计算器新增函数绘图能力：输入含变量 `x` 的表达式（`sin(x)`、`x^2`），在独立全屏面板绘制 `[-2π,2π]` 曲线，可返回计算器且既有功能零退化。

### 1.2 核心交互
用户 → ToggleRow"绘图" → PlotPanel（预填表达式/TextInput 编辑/x 插入）→ "绘制" → Canvas 坐标轴+分段曲线 → "返回" → 主界面（状态保留）。

### 1.3 技术栈概览
- 框架：ArkTS + Stage 模型 + ArkUI 声明式（与基线一致）
- 状态管理：**V1**（@State，与基线 CalculatorPage 一致，不引入 V2）
- Kit：@kit.ArkUI（Canvas/CanvasRenderingContext2D、promptAction 既有）；无新增 Kit
- Native：无；Hvigor：无新增插件；依赖：无新增 OHPM 包

---

## 2. 功能清单

| 功能名 | 说明 | 入口 Ability/Page | 优先级 |
|--------|------|-------------------|--------|
| 变量 x 求值 | CalcEngine 可选绑定求值 + Expression x 隐式乘法（SR-00） | CalculatorPage（经 PlotPanel 间接触发；引擎级能力） | P0 |
| 函数采样分段 | [-2π,2π] 401 点弧度采样、无效点断段（SR-01） | PlotPanel"绘制" | P0 |
| 绘图面板 | 全屏 PlotPanel：输入/坐标轴/曲线/返回/错误提示/主题适配（SR-02） | ToggleRow"绘图" | P0 |
| x 按钮插入 | 科学区新增 'x' 按钮（onConst('x') 复用） | ButtonGrid 科学区 | P1 |
| 缩放/平移/自定义范围 | 不做（增强项） | - | P2（不做） |

---

## 3. 实现模型

### 3.1 上下文视图

```plantuml
@startuml
actor 用户
rectangle "OpenCalc HarmonyOS" {
  rectangle "CalculatorPage\n(+PlotPanel 面板)" as UI
  rectangle "FunctionPlotter\n(新增)" as FP
  rectangle "CalcEngine/Expression\n(扩展)" as ENG
}
rectangle "ArkUI Canvas/TextInput" as KIT
用户 --> UI : 输入表达式/绘制/返回
UI --> FP : plot(cleanExpr)
FP --> ENG : 逐点 evaluate(clean,false,x)
UI --> KIT : Canvas 2D 绘制
@enduml
```

### 3.2 总体架构

```
View（CalculatorPage/PlotPanel @State）
  → Service（FunctionPlotter 采样分段）
    → Engine（CalcEngine.evaluate + Expression 清洗 + ErrorFlags）
      → Platform-Kit（Canvas 2D；无数据层变更）
```
单向数据流：UI 事件 → 计算产生 PlotResult @State → Canvas 按 state 渲染。

### 3.3 HAP/HAR/HSP 模块划分

不变更：仅 entry HAP。新增源码目录 `entry/src/main/ets/plot/`；新增测试目录 `entry/src/test/`。见 info.md §4。

### 3.4 设计系统规格

复用基线（见 design.md §3.4 占位/CalculatorPage 取色函数）。本次新增色彩：

#### 3.4.1 色彩系统（新增部分）

| 名称 | Light | Dark(AMOLED/暗色) | 用途 |
|------|-------|-------------------|------|
| 曲线色 | '#4684E3'（getOp 强调蓝） | 同左（暗色下自动取 getOp()='#0070BC'） | 函数曲线 |
| 坐标轴色 | getT2() | getT2() | 轴线（浅灰/深灰） |
| 网格刻度 | getT2() | getT2() | 刻度短线与标签 |
| 面板底色 | getPanelBg() | getPanelBg() | Canvas 背景与面板 |

#### 3.4.2 主题系统
沿用 themeIdx 0/1/2 + 既有取色函数；PlotPanel 不自持配色，全部经 CalculatorPage 方法取色。

#### 3.4.3 排版系统
轴标签 fontSize 10（getT2()）；错误提示 fontSize 14（getErr()）；标题"函数绘图" fontSize 18 Bold（getT1()）。

#### 3.4.4 间距与尺寸系统
面板内边距 16；Canvas 高度 layoutWeight(1)；按钮行高 40；与既有面板 padding 惯例一致。

#### 3.4.5 图标与图形资源
无新增资源文件（入口用文本"绘图"）。

#### 3.4.6 动画规格
无新增动画（面板瞬显，与 Settings/About 一致）。

#### 3.4.7 响应式断点与栅格
PlotPanel 全屏自适应；横竖屏均可用（无专用横屏布局，增强项）。

### 3.5 FunctionPlotter 模块实现设计

#### 3.5.1 模块介绍
entry 模块内纯逻辑类（无 @Component/@Entry 依赖），可被 hypium 本地单测直接构造。新增文件 `entry/src/main/ets/plot/FunctionPlotter.ets`。

#### 3.5.2 功能描述
- 表达式清洗（一次）→ 等距采样 N 点 → 逐点弧度制求值 → 有效性判定 → 分段构建 → y 轴范围估算

#### 3.5.3 目录结构

```
entry/src/main/ets/plot/
└── FunctionPlotter.ets        # PlotPoint/PlotSegment/PlotResult 接口 + FunctionPlotter 类
entry/src/test/
├── List.test.ets              # hypium 测试入口（聚合）
└── PlotFunction.test.ets      # SR-00/SR-01 单测套件
```

#### 3.5.4 架构图谱

```plantuml
@startuml
class FunctionPlotter {
  +plot(expr: string, xMin: number, xMax: number, n: number): PlotResult
  -evaluateAt(clean: string, x: number): number
  -isValid(y: number): boolean
  -buildSegments(xs: number[], ys: number[], valid: boolean[]): PlotSegment[]
  -yRange(ys: number[], valid: boolean[]): number[]
}
class CalcEngine {
  +evaluate(equation: string, isDegree: boolean, varX?: number): number
}
class Expression {
  +getCleanExpression(...): string
}
FunctionPlotter --> Expression : 清洗一次
FunctionPlotter --> CalcEngine : 每点求值
FunctionPlotter --> ErrorFlags : reset()/读取
@enduml
```

```plantuml
@startuml
title 绘制时序
actor 用户
participant "PlotPanel" as P
participant "FunctionPlotter" as F
participant "Expression" as E
participant "CalcEngine" as C
participant "ErrorFlags" as EF
用户 -> P : 点击"绘制"
P -> F : plot(plotInput, -2π, 2π, 401)
F -> E : getCleanExpression(expr, '.', ',')
F -> F : for i in 0..400: x_i
loop 每采样点
  F -> EF : reset()
  F -> C : evaluate(clean, false, x_i)
  C --> F : y_i（错误经 EF）
  F -> F : valid_i = flags全false && isFinite && |y|<=1e6
end
F --> P : PlotResult{segments, yMin, yMax, allValidCount}
P -> P : Canvas 坐标映射绘制分段折线
@enduml
```

#### 3.5.5 功能与用例分析

```
用例：sin(x) 采样（SC001-UC001/SC002-UC001 数据层）
前置：clean 表达式 "sin(x)" 可求值
步骤：1. 清洗 2. 401 点求值 3. 全有效 → 单段
后置：PlotResult.segments.length === 1

用例：1/x 分段（SC002-UC001）
前置：clean "1/x"
步骤：1. 采样 2. x=0 点 division_by_0 → 无效 3. 两侧各自成段
后置：segments.length === 2，断点在 x=0
```

#### 3.5.6 接口设计

```typescript
// 接口（含于 FunctionPlotter.ets 导出）
interface PlotPoint { x: number; y: number; valid: boolean }
interface PlotSegment { points: PlotPoint[] }        // points 全部 valid，x 递增
interface PlotResult {
  segments: PlotSegment[]   // 连续有效段（长度≥1 点）
  yMin: number; yMax: number // 有限样本范围（min==max → ±1，含 10% padding）
  totalValid: number
}
class FunctionPlotter {
  plot(expr: string, xMin: number, xMax: number, n: number): PlotResult  // 同步，无异常抛出（错误→空 segments）
}
```
无 async；调用约束：n ≥ 2、xMin < xMax，表达式先经 Expression 清洗（plot 内部执行清洗）。

#### 3.5.7 状态管理设计
纯逻辑无状态（每次 plot 独立）；不使用 @State。UI 侧：CalculatorPage 新增 @State showPlot: boolean、plotInput: string、plotError: string、plotSegments: PlotSegment[]、plotYMin/plotYMax: number。

```
plotInput --"绘制"--> FunctionPlotter.plot --> plotSegments/plotYMin/plotYMax/plotError --渲染--> Canvas
```

#### 3.5.8 核心算法

- **等距采样**：`x_i = xMin + i*(xMax-xMin)/(n-1)`，i∈[0,n)；n=401、[-2π,2π] 时步长 π/100
- **有效性判定**：`valid = (!syntax_error && !division_by_0 && !domain_error && !is_infinity && !require_real_number) && isFinite(y) && Math.abs(y) <= 1e6`
  - 1e6 夹持：tan 在 ±π/2 为 ~1.6e16 有限大数，仅 isFinite 不足
- **分段**：单遍扫描，valid[i] && valid[i-1] 同段；段内 ≥1 点即成段（孤立有效点画短段/点）
- **y 范围**：仅统计 valid 且 finite 的 y；min==max → ±1；再 +10% 对称 padding
- 复杂度：O(n·L)（L=表达式长度），n=401 → 单次绘制 <10ms 量级（不阻塞 UI 线程可接受；不做异步）

#### 3.5.9 错误处理
- plot 不抛异常：内部 try/catch，异常 → 空 segments
- 全无效（totalValid===0）→ segments 空，UI 显示"无可绘制的有效数据点"
- 空表达式由 UI 层前置拦截（"请输入表达式"）
- 错误文案中文，风格与既有一致

#### 3.5.10 依赖关系
内部：calculator/Calculator、calculator/Expression、model/ErrorFlags；外部：无。

### 3.6 CalcEngine/Expression 扩展实现设计

#### 3.6.1 模块介绍
既有文件修改：calculator/Calculator.ets、calculator/Expression.ets。SR-00 载体。

#### 3.6.2 功能描述
- CalcEngine：evaluate(equation, isDegree, varX?) —— varX 提供时启用变量绑定
- Expression：addMultiply 识别变量字符 'x'（'xp' 保护）

#### 3.6.3 目录结构
不变（修改既有文件）。

#### 3.6.4 架构图谱

```plantuml
@startuml
title parseFactor 变量分支（函数名段解析后）
start
:收集连续小写字母段 fn;
if (fn === 'xp' ?) then (yes)
  :e^x 函数（既有）;
elseif (fn === 'x' && varXEnabled ?) then (yes)
  :返回 varXValue;
  if (eat('^')) then (yes)
    :powx(x, parseFactor());
  endif
  stop
else (no)
  :既有函数调度/未知→syntax_error;
endif
stop
@enduml
```

#### 3.6.5 功能与用例分析

```
用例：SC001-UC002
前置：new CalcEngine()/new Expression()
步骤：1. clean = getCleanExpression("2x+1",".",",")  // → "2*x+1"
      2. evaluate(clean, false, 2)
后置：= 5；ErrorFlags 全 false
```

#### 3.6.6 接口设计

| 方法 | 签名 | 变更 | 兼容性 |
|------|------|------|--------|
| evaluate | (equation: string, isDegree: boolean, varX?: number): number | 追加可选参 | 两参调用行为逐位不变 |
| getCleanExpression | 签名不变 | 对含 'x' 输入插入 '*' | 不含 'x' 输出与基线逐字符一致 |

#### 3.6.7 状态管理设计
CalcEngine 新增私有实例字段 `varXEnabled: boolean = false`、`varXValue: number = 0`，evaluate 入口设置——与既有 eq/p/c/deg 字段同模式；Expression 保持无状态。

#### 3.6.8 核心算法（addMultiply 'x' 规则）

扫描到字符 'x'（非 'xp' 前缀）时：
```
后邻规则：next ∈ "0123456789π(ex" → 在 x 后插 '*'
  例：x2→x*2, xπ→x*π, x(→x*(, xx→x*x, xln→x*ln(函数首字母)
  例外：substring(i,i+2)==='xp' → 跳过（e^x 函数名）
前邻规则：i≥1 且 prev ∈ "0123456789)πex" → 在 x 前插 '*'
  例：2x→2*x, )x→)*x, πx→π*x, ex→e*x, xx→x*x（由后邻规则覆盖）
```
顺序保障：replaceSymbols 已把 'exp'→'xp'、'E'→'*10^'，正文中小写 'xp' 仅源于 e^x 函数。

#### 3.6.9 错误处理
未启用绑定时 fn==='x' 走既有 ErrorFlags.syntax_error 路径（错误文案"表达式错误"不变）。

#### 3.6.10 依赖关系
不变更（ErrorFlags 既有依赖）。

### 3.7 PlotPanel 面板实现设计

#### 3.7.1 模块介绍
CalculatorPage 内新增 @Builder PlotPanel()（与 SettingsPanel/AboutPanel 同模式），Stack 条件渲染 `if (this.showPlot)`；不新增路由页。

#### 3.7.2 功能描述
布局（全屏 Column，backgroundColor getPanelBg()）：
```
Row: Text('函数绘图')+Blank()+Text('✕ 返回')  ← onClick: showPlot=false（始终可点）
TextInput({ text: plotInput })  ← onChange 更新 plotInput；预填主表达式
Row: [插入 x] [AC] [绘制]      ← 插入x: plotInput+='x'；AC: plotInput=''; 绘制: onPlot()
Text(plotError)                 ← plotError 非空时显示（getErr 色）
Canvas                          ← layoutWeight(1)；onReady/onAreaChange 记录宽高
```

#### 3.7.3 目录结构
无新文件（Builder 位于 CalculatorPage.ets）。

#### 3.7.4 架构图谱
见 §3.5.4 时序图（PlotPanel 角色）。

#### 3.7.5 功能与用例分析

```
用例：SC003-UC001 进出与回归
前置：主界面正常
步骤：1. ToggleRow"绘图"→ showPlot=true，plotInput 预填 this.expression
      2. "✕ 返回" → showPlot=false
      3. 主界面表达式/历史/设置可用
后置：主界面状态保留
```

#### 3.7.6 接口设计
新增 CalculatorPage 私有方法：

| 方法 | 签名 | 职责 |
|------|------|------|
| onOpenPlot | (): void | showPlot=true；plotInput=expression；清 plotError |
| onPlot | (): void | 空值拦截 → plot(expr,'.',',') → FunctionPlotter.plot → 更新状态/错误（try/catch 包裹） |
| drawAxes | (ctx, w, h): void | 坐标映射：xAxisY=h/2（按 y 范围比例）、yAxisX=w/2；x 轴刻度 -2π/-π/0/π/2π（文字标签）|
| drawCurve | (ctx, w, h): void | 遍历 plotSegments，moveTo/lineTo 逐段绘制（无效点已在段构建时断开） |
| mathToPx | (x,y,w,h): 坐标 | x∈[xMin,xMax]→[0,w]，y∈[plotYMin,plotYMax]→[h,0] |

#### 3.7.7 状态管理设计
新增 @State：showPlot、plotInput、plotError、plotSegments、plotYMin、plotYMax、canvasW、canvasH。V1 装饰器；数据流单向（§3.5.7）。

#### 3.7.8 核心算法
坐标映射 + 分段折线绘制（无插值/平滑——忠实采样数据，避免视觉造假）。

#### 3.7.9 错误处理
onPlot 整体 try/catch → plotError='计算错误'；空表达式 → '请输入表达式'；全无效 → '无可绘制的有效数据点'。Canvas 未就绪（canvasW===0）时仅更新数据不绘制。

#### 3.7.10 依赖关系
依赖 plot/FunctionPlotter（新增单向依赖）、既有主题取色函数、promptAction（不新增）。

---

## 4. 接口设计

### 4.1 内部数据访问 API
无相关实现（无持久化）。

### 4.2 业务抽象接口
PlotPoint/PlotSegment/PlotResult（§3.5.6）——纯数据接口，ArkTS interface 导出。

### 4.3 后台任务与 ExtensionAbility 接口
无相关实现。

### 4.4 Want / Action 协议
无相关实现。

### 4.5 URI / Deep Link / AppLinking 协议
无相关实现。

### 4.6 IPC 与 RPC 接口
无相关实现。

### 4.7 Native（C/C++）接口
无相关实现。

### 4.8 文件交换接口
无相关实现。

---

## 5. 数据模型

### 5.1 关系型数据库模型
无相关实现。

### 5.2 领域模型

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| PlotPoint.x | number | 是 | 采样自变量 |
| PlotPoint.y | number | 是 | 函数值（无效点为 NaN 哨兵，不参与绘制） |
| PlotPoint.valid | boolean | 是 | 有效性（§3.5.8 判定） |
| PlotSegment.points | PlotPoint[] | 是 | 连续有效点，x 严格递增 |
| PlotResult.segments | PlotSegment[] | 是 | 分段集合（可为空数组） |
| PlotResult.yMin/yMax | number | 是 | 渲染 y 范围（有限值） |
| PlotResult.totalValid | number | 是 | 有效点计数 |

### 5.3 Preferences 结构
无相关实现（不新增偏好项）。

### 5.4 分布式数据对象模型
无相关实现。

### 5.5 文件格式 Schema
无相关实现。

---

## 6. UI设计系统

见 §3.4（新增色彩/排版/尺寸）+ 基线主题函数。

### 6.7 一多响应式规范要点
PlotPanel width('100%').height('100%')；Canvas layoutWeight(1) 随可用空间伸缩；竖屏/横屏均以单列布局呈现（无断点切换，增强项遗留）。

---

## 7. 页面清单与导航

### 7.1 页面清单总表

| 页面名 | 路径 | 入口 Ability | 传参 | 功能摘要 |
|--------|------|--------------|------|----------|
| Index | pages/Index | EntryAbility | 无 | 不变更 |
| CalculatorPage | pages/CalculatorPage | EntryAbility | 无 | 增加绘图入口 + PlotPanel 覆盖层（非新路由页） |

### 7.2 全局导航图

```plantuml
@startuml
Index --> CalculatorPage : replaceUrl（既有）
CalculatorPage --> CalculatorPage : showSettings/showAbout/showHistory/showPlot（面板覆盖层）
note right of CalculatorPage : PlotPanel 经 Stack 条件渲染，\n非 router 跳转
@enduml
```

### 7.3 Deep Link / AppLinking 处理
无相关实现。

### 7.4 Want 跳转矩阵
无相关实现。

---

## 8. 用户交互规格

### 8.1 手势交互目录

| 手势/组件 | 位置 | 行为 |
|-----------|------|------|
| onClick | ToggleRow'绘图' | onOpenPlot() |
| onClick | PlotPanel'✕ 返回' | showPlot=false |
| onClick | [插入 x]/[AC]/[绘制] | plotInput 编辑/清空/onPlot() |
| onClick | 科学区 'x' 按钮 | onConst('x')（主界面表达式追加） |
| onChange | TextInput | 更新 plotInput |

### 8.2 弹窗/Sheet/Menu 目录
无新增（错误信息用面板内 Text 行内提示，不用弹窗——保持与既有 errorMsg 显示风格一致）。

### 8.3 剪贴板与反馈行为
不涉及（绘图面板不使用剪贴板/Toast）。

### 8.4 卡片交互
无相关实现。

---

## 9. 平台集成

### 9.1 构建配置与依赖
零依赖变更：entry/oh-package.json5、根 oh-package.json5、build-profile.json5、main_pages.json、module.json5 全部不动。测试新增 `entry/src/test/`（hypium 已在根 devDependencies）。

### 9.2 权限与运行时请求
无新增权限。

### 9.3 系统能力（Kits）清单

| Kit | 关键 API | 用途 |
|-----|----------|------|
| ArkUI（既有） | CanvasRenderingContext2D（API ≥ 8）、TextInput、Canvas | 曲线渲染（最低 API version 随基线 SDK 12） |

### 9.4 后台与 Extension
无相关实现。

### 9.5 备份与恢复
无相关实现。

### 9.6 分布式与跨端
无相关实现。

---

## 10. 偏好设置目录

无相关实现（不新增偏好项；绘图弧度制为硬编码行为约定，非用户偏好）。

---

## 自验证（Step 3 交叉校验）

| 校验项 | 结果 |
|--------|------|
| 功能一致性 | delta-spec SR-00/01/02 ↔ §2 功能清单 1:1 ✓ |
| 页面一致性 | R3 全屏面板 ↔ §7.1 PlotPanel 覆盖层（非新路由页，符合 delta-spec §5 约束 4）✓ |
| 数据一致性 | PlotResult/分段 ↔ SR-01 AC ✓ |
| 权限一致性 | 无新增权限 ↔ delta-spec 无权限需求 ✓ |
| Kit 一致性 | Canvas/TextInput ↔ ArkUI 既有 ✓ |

---
> 本文档由 mod-design skill 生成。
> 标记 [推断] 的内容为基于设计推断，非确定性事实。
> 生成时间: 2026-10-22
