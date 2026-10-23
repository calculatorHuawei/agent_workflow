# 程序员模式与四进制转换 - 代码仓理解

## 1. 基本信息
- **需求类别**：新增功能；当前产品不存在程序员模式，Issue #45 要求新增独立能力。
- **需求名称**：程序员模式与 BIN/OCT/DEC/HEX 转换。
- **分析时间**：2026-10-23。
- **分析范围**：`opencalc/entry` 主页面、计算逻辑、模型、偏好、构建与本地测试。
- **重点分析类别**：架构与约束、公共组件、接口契约、影响范围、构建集成、风险与测试。
- **约束边界**：仅规划；未修改产品源码、构建配置或测试源码。

## 2. 模块架构

### 2.1 当前模块结构
```text
OpenCalc (single entry HAP)
├── entryability/EntryAbility.ets
│   └── loads pages/Index
├── pages/Index.ets
│   └── router.replaceUrl('pages/CalculatorPage')
├── pages/CalculatorPage.ets
│   ├── UI + @State + event routing
│   ├── Expression → CalcEngine → NumberFormatter
│   ├── PreferencesStore → preferences (history/settings)
│   └── FunctionPlotter/PlotAxis → Canvas
├── calculator/
├── model/
├── plot/
└── preferences/
```

项目只有一个 `entry` HAP，无 HAR/HSP/feature HAP。`CalculatorPage` 是实际主页面，当前承担 UI、页面状态和事件编排；业务算法按 `calculator/` 与 `plot/` 子目录拆分。

### 2.2 核心模块职责
| 模块 | 位置 | 当前职责 | 与本需求关系 |
|------|------|----------|--------------|
| `CalculatorPage` | `entry/src/main/ets/pages/CalculatorPage.ets` | 普通/科学计算 UI、历史、设置、绘图覆盖层、主题与横竖屏 | 修改：增加应用模式状态和程序员面板 |
| `CalcEngine` | `calculator/Calculator.ets` | 基于 `number` 的递归下降表达式求值 | 保持不变；不适合作为 U64 转换核心 |
| `Expression` | `calculator/Expression.ets` | 普通表达式清理/转换 | 保持不变；本期不支持程序员表达式 |
| `NumberFormatter` | `calculator/NumberFormatter.ets` | 十进制结果分组/格式化 | 保持不变；它服务浮点/十进制显示，不承担多进制 U64 |
| `Models` | `model/Models.ets` | 错误、编号体系、科学模式、历史、偏好模型 | 扩展模式/进制/结果/错误类型时须保持既有字段兼容 |
| `PreferencesStore` | `preferences/PreferencesStore.ets` | 主题、振动、历史等 Preferences 读写 | 不修改 schema；模式切换不得触发历史清空 |
| `FunctionPlotter/PlotAxis` | `plot/` | 函数采样、分段、坐标轴布局 | 不涉及；回归范围 |

### 2.3 扩展点与推荐落点
现有目录惯例按领域拆分纯业务代码。推荐新建 `entry/src/main/ets/programmer/ProgrammerConverter.ets`，把校验和转换与页面/浮点引擎隔离；页面只负责状态和呈现。无需新模块或新路由。

## 3. 接口与契约

### 3.1 现有关键接口
| 接口 | 位置 | 功能 | 参数/返回 |
|------|------|------|-----------|
| `CalcEngine.evaluate` | `calculator/Calculator.ets` | 普通/科学表达式求值 | `(equation: string, isDegree: boolean, varX?: number): number` |
| `Expression.getCleanExpression` | `calculator/Expression.ets` | UI 表达式转求值表达式 | string → string |
| `NumberFormatter.format` | `calculator/NumberFormatter.ets` | 现有十进制格式化 | string + separator/system → string |
| `PreferencesStore.getHistory/setHistory` | `preferences/PreferencesStore.ets` | JSON 历史持久化与按上限裁剪 | `Promise<HistoryItem[]>` / `Promise<void>` |
| 页面事件方法 | `pages/CalculatorPage.ets` | `onDigit/onOp/onBS/onAC/onEquals` 等 | 直接修改 `@State` |

### 3.2 现有状态与事件机制
| 状态/事件 | 当前行为 | 规划约束 |
|-----------|----------|----------|
| `expression/result/errorMsg` | 普通计算状态 | 程序员模式不得复用或清空 |
| `history` | 启动加载，等号成功时保存 | 模式切换只读保留，不新增程序员历史 |
| `scientific/radianMode/themeIdx` | 页面内状态，部分来自偏好 | 程序员模式往返后保持 |
| `isLandscape` | 根 Stack 的 `onAreaChange` 更新；横屏强制 `scientific=true` | 新面板需适配但不改变该既有规则 |
| `showPlot/showSettings/showAbout` | 同页覆盖层 | 程序员模式入口不应重建页面或路由 |

### 3.3 新接口建议（设计输入）
| 接口 | 所属元素 | 契约 |
|------|----------|------|
| `convert(text, radix)` | `ProgrammerConverter` | 返回完整 `ConversionResult` 或 `ProgrammerError`，不得抛出到 UI |
| `isDigitAllowed(digit, radix)` | `ProgrammerConverter` | UI 键启停与业务校验共用同一规则 |
| `appendDigit(state, digit)` | 状态操作层 | 成功返回新状态；失败返回原状态 + 错误 |
| `changeRadix(state, target)` | 状态操作层 | 有值时保持数值并重写草稿；空值只变 radix |

调用约束：converter 必须纯同步、无 IO、无 ArkUI/Preferences 依赖；成功前完成字符、范围和精度验证；失败不得部分更新多个页面字段。

## 4. 构建与集成
- **项目类型**：HarmonyOS Stage 模型、ArkTS、ArkUI 声明式 UI。
- **兼容/目标 SDK**：HarmonyOS 5.0.0(12)，API 12。
- **构建入口**：`opencalc/build-profile.json5`、`opencalc/hvigorfile.ts`、`entry/build-profile.json5`。
- **模块**：仅 `entry`，类型 `entry`，支持 phone/tablet，自动旋转。
- **OHPM 依赖**：产品依赖为空；本地测试使用 `@ohos/hypium 1.0.15`，根 devDependency 另有 `@ohos/hamock`。
- **权限**：仅既有 `ohos.permission.VIBRATE`；本需求不新增权限。
- **规划后验证命令**：构建使用仓库约定 `opencalc/build-test.bat` 或等价 `hvigorw assembleHap`；本地 Hypium 使用 worker 约定 `hvigorw --mode module -p module=entry@default test`，不是旧文档中的 `test@entry`。
- **测试聚合**：`entry/src/test/List.test.ets` 目前仅注册 `PlotFunction.test`；后续实现需注册新的程序员转换套件。

## 5. 影响范围
| 模块/文件 | 影响内容 | 风险 |
|-----------|----------|------|
| `pages/CalculatorPage.ets` | 新增模式、程序员状态、Builders 与动画 | 文件已较大（约 32KB），需限制新增职责，防止状态交叉 |
| `model/Models.ets` | 新增枚举/接口，不改既有类型字段 | 命名冲突或对现有 import 造成非预期影响 |
| `programmer/ProgrammerConverter.ets`（新） | U64 业务逻辑 | ArkTS `bigint` 语法/编译约束、边界精度 |
| `entry/src/test` | 新套件与聚合注册 | 测试任务/ArkTS 语法与产品编译差异 |
| `PreferencesStore.ets` | 原则上不修改 | 若错误复用会导致不必要持久化或历史覆盖 |
| `calculator/`、`plot/` | 不修改，仅回归 | 模式条件若包裹错误会隐藏或破坏既有入口 |

调用链规划：
```text
Programmer key/radix event
  → CalculatorPage handler
  → ProgrammerConverter / state operation
  → success: atomically replace programmer state
    failure: retain valid data + replace feedback
  → ArkUI rerender programmer panel only
```

## 6. 约束清单
| 约束 | 来源 | 遵守方式 |
|------|------|----------|
| 仅执行 PLANNING，不修改产品源码 | 用户指令 | 只写 `specs/changes/...` 制品 |
| 不创建 `tasks.md` | 用户指令 | todo 仅跟踪 PLANNING；IMPLEMENTING 保持待开始 |
| 保持向后兼容 | Issue/worker workflow | 隔离普通和程序员状态，不改既有接口/schema |
| 安全可逆默认 | GitHub assignment | 采用 U64 非负、页面内草稿、不含位运算并记录 rationale |
| 精确转换 | Issue 的错算/边界 AC | 禁止浮点 `number` 处理 U64；边界单测门禁 |
| 最小权限 | workflow | 无新权限、依赖、网络、后台任务或持久化 |
| 现有工作树保护 | workspace 规则 | 目标 change 目录为当前未跟踪规划稿；不触碰无关改动 |

## 7. 可复用组件
| 组件 | 位置 | 复用方式 |
|------|------|----------|
| 主题颜色 getters | `CalculatorPage.ets` | 程序员标签、键盘、反馈沿用 `getBg/getBtnBg/getOp/getErr/getT1/getT2` |
| 响应式 `isLandscape` | `CalculatorPage.ets` | 程序员面板复用现有横竖屏状态，不新增监听器 |
| Builder 按钮惯例 | `CalculatorPage.ets` | 沿用 `Text(...).onClick`、统一尺寸/圆角模式，新增受限 digit builder |
| Hypium 套件惯例 | `entry/src/test/PlotFunction.test.ets` | `describe/it/expect`，模块级函数，避免 ArkTS 禁止的嵌套函数 |
| Models 集中定义 | `model/Models.ets` | 公共枚举/接口保持显式类型 |

不建议复用：`CalcEngine`、`Expression` 和 `NumberFormatter` 的 `number` 路径，因为其语义是十进制浮点表达式而非 U64 进制转换。

## 8. 关键实现现状
- `CalculatorPage` 的模式概念当前只有 `scientific: boolean`，它控制附加科学按键，不是独立应用模式。
- 普通输入由 `onDigit/onOp/...` 直接拼接 `expression`；等号后调用 `Expression → CalcEngine → NumberFormatter`，并把结果写入历史。
- 历史保存在 Preferences 的单个 JSON 字符串 `history` 中；损坏时返回空数组。模式切换无需触碰它。
- 横屏在 `onAreaChange` 中自动开启科学模式；程序员模式设计必须明确与此既有行为隔离。
- 页面已有函数绘图全屏覆盖层，证明同页分支可保持主计算状态；但程序员模式是核心模式分支，宜由显式 `CalculatorMode` 控制。
- 当前 SDK 的 API 声明多处使用 `bigint`，表明类型能力存在；具体 ArkTS 源码字面量/构造语法仍必须在 APPLYING 编译验证。

### 边界条件
- 十六进制大小写：UI 仅大写，防御入口可规范化小写。
- 空字符串与 `0` 不同；空值不应产生数值结果。
- U64 最大长度随进制为 BIN 64、OCT 22、DEC 20、HEX 16 位，但仅长度不能独立判断上界（如 OCT/DEC 最大首位）。
- 换进制必须先基于旧 radix 解析，再按新 radix 格式化，不能直接重解释相同文本。
- 非法/越界不能覆盖最后有效结果；清空与退格必须能恢复。

## 9. 风险与测试
| 风险 | 缓解 | 测试策略 |
|------|------|----------|
| U64 被 `number` 舍入 | 独立精确算法与代码评审禁则 | MAX、MAX-1、MAX+1，跨进制往返 |
| ArkTS `bigint` 源语法不兼容 | 编译先行；必要时精确字符串算法 | 最小编译探针 + 全转换套件 |
| UI 禁用规则与业务规则漂移 | 共用 `isDigitAllowed` | 各 radix 合法/非法字符矩阵 |
| 多个 `@State` 部分更新 | 操作返回单一状态对象或严格原子赋值顺序 | 失败前后状态深度比较 |
| 快速动画重入 | 同步幂等 mode 状态，动画不提交业务 | 180ms 内连续切换序列 |
| 普通状态丢失 | 模式分支不调用 `onAC`/历史写入 | 普通状态快照往返测试 |
| 横屏布局拥挤 | 复用响应式标志、限制键盘行高 | phone/tablet 横竖屏 UI 验证（Tester 阶段） |

回归范围：`CalculatorPage` 普通基础/科学输入、等号、错误、历史加载/删除/点击、主题/角度、绘图入口与已有 PlotFunction 本地测试。

## 10. 关键发现

### 可复用组件
- 主题、响应式布局与 Builder 风格可直接沿用。
- Hypium 本地测试框架和聚合入口已存在。
- 单 entry HAP 足以承载本功能，无需模块化扩张。

### 风险提示
- 最大技术风险不是算法复杂度，而是精度模型和页面状态交叉。
- 现有 `CalculatorPage` 体积较大；业务算法必须移出页面。
- 初始化标记里的旧测试命令已被 worker workflow 的新命令覆盖，后续执行应采用后者。

### 建议
- 先实现/编译/单测 T0 converter，再接状态与 UI。
- 不修改 PreferencesStore，模式只保存页面内草稿。
- UI 自动化由 Tester 阶段在设备/模拟器上完成；Developer 不应声称未运行的设备覆盖。

---
> 本文件由 rq-codebase 工作流产出，仅包含代码仓理解与设计输入，不包含产品源码修改。
