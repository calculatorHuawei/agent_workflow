# 2×2 / 3×3 矩阵运算 - 代码仓理解

> 2026-10-25 Tester-feedback 增量分析：基于 PR #54 精确 head `6e76305e8d3df57378314d78f30f4b53b0dc4690` 重新核查，重点由“从零新增矩阵功能”调整为“修复设备 TextInput 提交/状态同步闭环”。原有全量代码仓信息继续有效。

## 1. 基本信息
- **需求类别**：工作流路由=缺陷修复；代码语义=新增功能
- **需求名称**：2×2 / 3×3 矩阵运算
- **分析时间**：2026-10-24
- **分析范围**：`opencalc/entry` 的页面、calculator、model、preferences、test 与构建配置；现有规划/设计惯例
- **约束边界**：只读检查；未修改产品源码；不引入权限、持久化、网络、外部依赖
- **重点类别**：架构/公共组件/接口约束/影响范围/构建集成/测试策略

## 2. 模块架构

```text
EntryAbility
  → pages/Index.ets
    → router.replaceUrl('pages/CalculatorPage')
      → CalculatorPage.ets (@Entry, @Component, V1 @State)
         ├─ scalar: Expression → CalcEngine → NumberFormatter
         ├─ plot: PlotPanel → FunctionPlotter → Expression/CalcEngine
         ├─ history/settings: PreferencesStore
         └─ [planned] MatrixPanel → MatrixEngine/format helper
```

### 核心模块职责
| 模块 | 当前职责 | 本需求关系 |
|---|---|---|
| `pages/CalculatorPage.ets` | 701 行单页，维护标量、历史、设置、绘图全部 UI 状态 | 必改：矩阵入口、会话状态、面板、事件 |
| `calculator/Calculator.ets` | 无 UI 的递归下降标量引擎；可选绘图变量 x | 不改：矩阵不应混入表达式 parser |
| `calculator/Expression.ets` | 标量输入清洗 | 不改 |
| `calculator/NumberFormatter.ets` | 对数字字符串做国际/印度分组；本身不执行 precision 舍入 | 可复用分组；矩阵需先独立消噪 |
| `model/Models.ets` | 错误/编号体系/历史/Preferences 与默认精度 12 | 参考精度；矩阵类型优先放新模块内以减耦 |
| `plot/FunctionPlotter.ets` | 纯逻辑采样和分段，Hypium 可直接测试 | 可复用“纯逻辑模块 + 页面适配”的结构惯例 |
| `preferences/PreferencesStore.ets` | 历史与设置持久化 | 不改 schema；矩阵为会话状态 |
| `entry/src/test` | Hypium 本地测试；`List.test.ets` 当前只注册 PlotFunction | 新增矩阵 suite 并注册 |

### 扩展点位置
- 竖屏模式栏：`CalculatorPage.ets:498-514` 的 `ToggleRow()`；现有“绘图”入口提供最接近的惯例。
- 覆盖层：`build():453-456` 条件渲染 Settings/About/Plot；矩阵面板应同层并互斥。
- 全屏面板：`PlotPanel():656-700`，包含标题/返回、输入、操作、错误和主体区域。
- 清空与错误：标量 `onAC():92`、`onEquals():94-115`；矩阵必须使用独立状态，避免共享 `errorMsg/result`。

## 3. 接口与契约

### 3.1 外部接口
无网络/API/文件接口。唯一外部边界是 ArkUI 用户事件与设备可见状态。

### 3.2 内部接口
| 接口 | 位置 | 当前契约 | 复用/影响 |
|---|---|---|---|
| `CalcEngine.evaluate(equation,isDegree,varX?)` | calculator/Calculator.ets | 返回 scalar number；错误通过静态 ErrorFlags | 不复用，避免矩阵污染全局 ErrorFlags |
| `NumberFormatter.format(text,'.',',',system)` | calculator/NumberFormatter.ets | 字符串分组，不截断精度 | 可作为最后一步；矩阵先 `toPrecision`/归一 |
| `PreferencesStore` | preferences/PreferencesStore.ets | async preferences/history | 不用于矩阵 |
| `FunctionPlotter.plot(...)` | plot/FunctionPlotter.ets | 同步纯逻辑返回 `PlotResult` | 设计范式参考 |

### 3.3 建议新增契约（设计输入，不是已实现事实）
```typescript
type Matrix = number[][]
enum MatrixOperation { ADD, SUBTRACT, MULTIPLY, DETERMINANT }
interface CellError { matrix: 'A' | 'B'; row: number; column: number; reason: 'empty' | 'invalid' }
interface MatrixResult { kind: 'matrix' | 'scalar'; matrix?: Matrix; scalar?: number }

class MatrixEngine {
  add(a: Matrix, b: Matrix): Matrix
  subtract(a: Matrix, b: Matrix): Matrix
  multiply(a: Matrix, b: Matrix): Matrix
  determinant(a: Matrix): number
}
```
调用约束：输入必须是 2 或 3 阶、方阵、同维且元素 finite；UI 解析器在调用前保证，Engine 仍进行结构防御并对非法结构抛出/返回明确内部错误，UI 统一转为用户错误。

### 3.4 事件机制
| 事件 | 触发 | 消费者 | 状态效果 |
|---|---|---|---|
| openMatrix | ToggleRow 点击 | CalculatorPage | 关闭其他 overlay，显示 MatrixPanel |
| dimensionChange | 2×2/3×3 点击 | Matrix state handler | resize preserve overlap；clear result/errors |
| cellChange | TextInput.onChange | Matrix state handler | 更新单元字符串；清目标错误/使结果陈旧 |
| calculate | 运算按钮 | validator + engine | error map 或 result |
| clearMatrix | 清空按钮 | Matrix state handler | 清输入/result/errors，保留维度 |
| closeMatrix | 返回 | CalculatorPage | 仅隐藏面板，主 scalar 状态不变 |

## 4. 构建与集成
- **构建入口**：`opencalc/build-profile.json5` → 单一 `entry` module；产品 compatible/target SDK `5.0.0(12)`。
- **模块类型**：`entry/src/main/module.json5` 为 entry HAP，支持 phone/tablet，orientation auto_rotation。
- **依赖**：entry 无运行时 OHPM 依赖；devDependency `@ohos/hypium 1.0.15`。
- **权限**：当前仅 `ohos.permission.VIBRATE`；矩阵无需新增。
- **测试入口**：`entry/src/test/List.test.ets` 聚合 suite；当前注册 `PlotFunction.test`。
- **发布形式**：单 HAP；无 HAR/HSP/Native。
- **裁剪机制**：无 feature flag；UI 通过 `@State` 条件渲染。
- **初始化基线**：`specs/initialized.flag` 记录 build success、TEST_ROOT=`opencalc/entry/src/test`；本 PLANNING 不重复构建且不修改该标记。

## 5. 影响范围
| 模块/文件 | 规划影响 | 风险 |
|---|---|---|
| 新 `calculator/MatrixEngine.ets`（建议） | 类型、结构校验、四类算法、数字格式辅助或拆分 helper | det 符号/索引错误、浮点尾差 |
| `pages/CalculatorPage.ets` | 新 `@State`、入口、MatrixPanel、网格 Builder 和 handlers | 文件继续膨胀；条件渲染/overlay 冲突；重复 cell 错配 |
| `entry/src/test/MatrixEngine.test.ets`（建议） | 算法/输入/精度边界 suite | 只测函数不足以证明 UI |
| `entry/src/test/List.test.ets` | 注册 matrix suite | 漏注册导致测试未执行 |
| `model/Models.ets`（可选） | 仅共享类型确有跨模块需求时扩展 | 不必要公共 API 膨胀；优先不改 |
| `NumberFormatter.ets`（可选） | 若抽取通用数值消噪 API | 标量展示回归；优先矩阵局部 helper |

### 调用链
```text
ToggleRow → showMatrix
Matrix TextInput(row,col) → string[][] state
operation click → parseRequiredMatrices(operation)
  ├─ errors → cellErrorKeys + summary + empty result
  └─ matrices → MatrixEngine operation → normalize/format → result state → UI
```

### 兼容性评估
- 主风险在 `CalculatorPage.build()` 的 overlay 顺序和现有 `scientific/showPlot/showHistory` 状态，而非标量算法。
- 矩阵使用独立 `matrix*` 状态与 `MatrixEngine`，不修改 `expression/result/errorMsg/ErrorFlags`。
- `onAreaChange` 横屏会强制 `scientific=true`（现有行为）；矩阵覆盖层应独立全屏，不依赖科学按钮网格。
- 当前仓库没有分数/程序员实现。验收只能对现有基础/科学/绘图做实测；规划明确不得占用或伪造未实现模式。

## 6. 约束清单
| 约束 | 来源 | 遵守方式 |
|---|---|---|
| n 只能为 2/3，同维方阵 | Issue | UI 固定控制 + Engine 结构防御 |
| 仅四类操作 | Issue 非目标 | exact control set，拒绝旧文档“转置”建议 |
| 普通十进制 | Issue | 完整字符串 regex + finite |
| 精度策略 | Issue + Models 默认 12 | 仅展示边界 12 位有效数字，-0→0 |
| 清空/切换稳定 | Issue | 单一状态转换 handler；结果/error 一致失效 |
| 既有模式兼容 | Issue | 独立状态/引擎，无 Preferences/权限/路由变更 |
| ArkTS 限制 | 现有代码 | 显式类型、简单数组/循环、避免动态 JS 模式 |
| 仅 Planning | 用户 | 不修改 `opencalc` 产品源、不创建 tasks.md、不测试实现 |

## 7. 可复用组件
| 组件 | 位置 | 复用方式 |
|---|---|---|
| 覆盖面板样式/返回行 | CalculatorPage.PlotPanel | 复用 Builder 布局惯例、主题函数、常驻返回 |
| 主题函数 | CalculatorPage.getBg/getT1/getT2/getOp/getErr 等 | 矩阵面板不持有独立颜色体系 |
| NumberFormatter | calculator/NumberFormatter | 对已消噪文本做最终分组（如需要） |
| DEFAULT_PREFERENCES.numberPrecision | model/Models | 作为默认 12 位有效数字基线 |
| Hypium suite 聚合 | entry/src/test/List.test.ets | 注册新的 `matrixEngineTest()` |

## 8. 关键实现现状
- `CalculatorPage` 已使用 V1 `@State`，没有 ViewModel 分层；矩阵应遵循现状但将数学逻辑移出页面。
- UI 重复项已有 `ForEach(history)`，矩阵网格可用固定循环/ForEach；必须以 `A-r-c`/`B-r-c` 稳定 key 映射 hit target 和错误。
- 标量错误依赖静态 `ErrorFlags`；矩阵校验不应复用，以免与绘图/标量状态交叉污染。
- `NumberFormatter` 只做分组，`raw.toString()` 仍可能显示尾差；矩阵需明确新的局部规范化函数。
- `Models.DEFAULT_PREFERENCES.numberPrecision=12` 存在，但 CalculatorPage 当前未加载此项；矩阵第一版可用常量 12，并为后续接通偏好保留参数。
- 旧增强分析 `opencalc/docs/增强需求-修改分析.md` #22 建议 MatrixEngine + CalculatorPage，但错误地包含转置；Issue #51 优先级更高并明确排除转置。

## 9. 风险与测试
| 风险 | 缓解 | 测试策略 |
|---|---|---|
| 索引/乘法次序错误 | 标准三重循环和非对称矩阵 | AC-003、单位阵和额外非对称 unit |
| 3×3 det 符号错误 | 明确展开或余子式实现 + 已知 determinant 用例 | unit：I、奇异阵、含负数阵 |
| parseFloat 接受部分非法串 | regex 全串匹配再 Number/finite | `1x`,`1e2`,`--1`,空白、NaN/Infinity |
| 浮点噪声和 -0 | toPrecision 参数化 + epsilon/Number 归一 | AC-006 精确文本 |
| 切换不触发 UI | 替换新数组引用，不原地深层 mutate | AC-010 UI |
| 重复单元错误映射 | 稳定坐标 key | 每个角/中心单元独立输入 UI test |
| overlay 叠加 | 单一 open handler 关闭其他 overlay | 矩阵↔绘图/设置回归 |
| 横竖屏溢出 | Scroll/自适应网格，按钮保持可达 | phone/tablet 关键 UI |
| 测试只写未运行 | List.test 注册 + Tester 保存执行日志 | AC-014 |

### 回归范围
1. 基础 `1+2=3`、AC/退格、历史入口。
2. 科学 `sin(30)=0.5`（角度默认）。
3. 绘图 `sin(x)` 有有效曲线和返回。
4. 设置/关于覆盖层仍可打开关闭，主题色函数可用。
5. module 权限、OHPM 依赖、Preferences schema 不变。

## 10. 关键发现

### 可复用组件
PlotPanel 的全屏 overlay 模式、主题函数、Hypium 聚合和纯逻辑 FunctionPlotter 架构可直接指导本设计。

### 风险提示
最大的实现风险是 `CalculatorPage` 响应式深层数组更新和多覆盖层互斥，而非矩阵公式本身；必须以 UI/integration AC 证明状态刷新。

### 建议
- 新增单一纯逻辑 `MatrixEngine.ets`，将 Matrix 类型、校验结果和格式化 helper 内聚，避免立即扩大公共 Models/NumberFormatter。
- 页面只负责编排字符串状态和可见反馈；引擎只接收完整 number 矩阵。
- Tester 建立 cell 坐标级 UI 证据，不以“面板存在”替代运算语义。

## 11. Tester 反馈专项代码仓分析（Task 61）

### 11.1 可复现事实

| 项目 | 事实 |
|---|---|
| 精确 revision | `6e76305e8d3df57378314d78f30f4b53b0dc4690`；任务开始时 tracked worktree clean |
| 本地门禁 | 独立测试 68/68、`assembleHap`、CodeLinter 均通过（Tester handoff） |
| 设备 | OpenHarmony 6.1.1.125 模拟器 `127.0.0.1:5555` |
| 成功部分 | 矩阵入口、2×2/3×3 网格形状与范围外控件约束通过 |
| 失败步骤 | `uitest uiInput inputText 963 1784 1` exit 0；输入后/失焦后 UI 树与截图仍为空；A+B 标记全部八格为空 |
| 证据 | `.agent-runtime/evidence/task-56/run-106/device/logs/MX-UI-002_commands.json`、对应 UI tree/screenshots、`ui-assertions.json` |

### 11.2 当前调用链与风险点

```text
TextInput(text = values[row][column])
  └─ onChange(value)
      └─ CalculatorPage.onMatrixCell(name,row,column,value)
          ├─ loadMatrixSession()       @State arrays → mutable session
          ├─ MatrixSession.setCell()   clone matrix, invalidate derived state
          └─ storeMatrixSession()      session arrays → @State arrays → ArkUI redraw
```

| 风险点 | 代码位置 | 规划判断 |
|---|---|---|
| 重复 TextInput 身份 | `CalculatorPage.ets` `MatrixGrid` 的嵌套 `ForEach` 未提供显式稳定 key/test identifier | 保证 A/B + row + column 唯一 identity，避免重绘或自动化命中歧义 |
| 受控文本与 Builder 参数 | `TextInput({ text: values[row][column] })` 读取 Builder 参数，同时 onChange 经 Session 往返写顶层状态 | 验证 onChange 是否触发以及重绘是否用旧空值覆盖内部编辑值；保持单一状态所有权 |
| 焦点/自动化判定 | 当前单元格无可定位的语义标识，Tester 以坐标输入 | 记录焦点节点并优先使用稳定节点身份；exit 0 不作为文本提交 oracle |
| Scroll/IME 重布局 | 输入网格位于 `Scroll`，IME 显示会改变可见区域 | 覆盖输入后、IME 收起/失焦、滚动/重绘三阶段，区分坐标偏移与产品缺陷 |
| 算法层 | `MatrixSession`/`MatrixEngine` 单测通过 | 不修改算法语义；仅增加必要的 UI→state 集成覆盖 |

### 11.3 影响范围与兼容边界

| 文件/资产 | 计划影响 | 禁止扩张 |
|---|---|---|
| `opencalc/entry/src/main/ets/pages/CalculatorPage.ets` | 诊断并修正单元格 identity、焦点、文本绑定/状态同步 | 不改其他模式/标量状态，不新增权限、路由、自定义键盘 |
| `opencalc/entry/src/main/ets/calculator/MatrixEngine.ets` | 原则上不变；若 UI 状态适配需要，仅保持既有公开语义 | 不改数字语法、算法、精度或会话规则 |
| `opencalc/entry/src/test/` | 后续阶段可增加 UI-state adapter/会话回归；本 PLANNING 不改 | 不以单元测试替代设备 AC-015 |
| Tester UI case/evidence | 稳定节点、焦点、分时点 UI tree/screenshot 与最终计算 oracle | 不增加产品测试后门 |

### 11.4 构建与环境结论

继续使用现有 `entry` HAP、ArkUI V1 `@State`、API 12、Hvigor/Hypium 配置；不新增 OHPM 依赖、系统 Kit 或权限。该缺陷属于表现层输入事件到页面会话状态的跨层集成问题，复杂度为中等、影响模块为 UI + 测试证据两类，不需要新的 HAP/HAR/HSP 或外部架构。
