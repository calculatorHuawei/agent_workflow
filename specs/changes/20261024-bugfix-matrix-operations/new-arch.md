# 2×2 / 3×3 矩阵运算 - 架构变更

## 1. 变更概述
| 项目 | 内容 |
|---|---|
| 变更类型 | 新增核心业务模块（工作流目录类型 bugfix） |
| 变更日期 | 2026-10-24 |
| 变更人 | Developer |
| 架构范围 | entry HAP 内部；不改变部署、路由、权限或外部接口 |

## 2. 最新架构【架构前置】

### 2.1 架构总览
维持单 entry HAP 和单页面架构。新增 MatrixEngine 作为与标量 CalcEngine、FunctionPlotter 并列的纯逻辑域模块；CalculatorPage 新增 MatrixPanel，仅负责字符串输入、状态转换与渲染。数据流严格单向，矩阵数据不进入 Preferences 或标量历史。

### 2.2 分层架构图
```text
┌──────────────────────────────────────────────────────────┐
│ 表现层：CalculatorPage                                   │
│  Display/ButtonGrid │ PlotPanel │ [新增] MatrixPanel     │
│                                  string grids/@State      │
├──────────────────────────────────────────────────────────┤
│ 应用编排：matrix handlers                                │
│  open/close │ resize │ parse-required │ clear │ format    │
├──────────────────────────────────────────────────────────┤
│ 纯业务逻辑层                                             │
│  CalcEngine/Expression │ FunctionPlotter │ MatrixEngine   │
│                                         add/sub/mul/det   │
├──────────────────────────────────────────────────────────┤
│ 数据/基础设施                                            │
│ PreferencesStore（矩阵不接入）│ ArkUI │ Hypium           │
└──────────────────────────────────────────────────────────┘
```

### 2.3 组件职责
| 组件 | 类型 | 职责 | 边界 |
|---|---|---|---|
| CalculatorPage | 表现/编排 | 管理 overlay、主计算器与矩阵会话状态 | 不实现矩阵公式 |
| MatrixPanel | Builder/UI | 维度、A/B 网格、操作、结果、错误、清空、返回 | 输入为字符串；只调用 handler |
| Matrix input adapter | 应用编排 | 按 operation 解析必填矩阵并生成 CellError[] | 不宽松截断非法文本 |
| MatrixEngine | 业务逻辑 | 2/3 阶方阵加减乘和 determinant | 只接受完整 finite number[][]；无 UI/状态依赖 |
| Matrix formatter | 应用编排/纯 helper | 12 位有效数字、-0→0、整数简洁文本 | 不修改中间计算值 |
| Hypium matrix suite | 测试 | 算法、结构、解析/格式边界 | 不替代设备 UI 验收 |

### 2.4 交互关系
| 交互 | 方向 | 接口/协议 | 说明 |
|---|---|---|---|
| 用户 → MatrixPanel | 事件 | onClick/onChange | 进入、编辑、运算、切换、清空、返回 |
| MatrixPanel → handlers | 调用 | 强类型方法 | 页面状态原子更新 |
| handlers → adapter | 调用 | parseRequired(operation) | 返回 matrices 或全部 cell errors |
| handlers → MatrixEngine | 调用 | add/subtract/multiply/determinant | 同步纯逻辑 |
| handlers → formatter | 调用 | formatMatrix/formatScalar | 只在展示边界消噪 |
| @State → MatrixPanel | 数据 | ArkUI 响应式渲染 | 必须替换数组引用触发刷新 |

**数据流**：`string[][] → validation → number[][] → MatrixEngine → number/number[][] → format → UI`。

**控制流**：UI 事件只能经矩阵 handler 改矩阵状态；不得写入标量 `expression/result/errorMsg`。

## 3. 变更原因
| 原因类型 | 说明 |
|---|---|
| 业务需求 | Issue #51 要求新增 2×2/3×3 矩阵模式与四类运算 |
| 可测试性 | 纯算法若内联 CalculatorPage 难以独立单测和复用 |
| 兼容性 | 独立 MatrixEngine 可避免改动成熟的标量 parser/ErrorFlags |
| 状态可靠性 | 显式 adapter/handler 可集中落实必填范围、切换失效和错误定位 |

## 4. 变更点【展开细节】

### 4.1 新增 MatrixEngine
**变更类型**：新增。

| 组件 | 变更内容 |
|---|---|
| `calculator/MatrixEngine.ets` | Matrix 类型、四类运算、结构防御；可内聚解析/格式 helper 类型 |

**变更理由**：矩阵是结构化域对象，不适合编码进标量表达式语法。

**实现要点**：无状态；n 只能 2/3；加减 O(n²)、乘法 O(n³)、det 固定阶公式或安全消元；不在中间步骤舍入。

### 4.2 扩展 CalculatorPage/MatrixPanel
**变更类型**：修改。

| 组件 | 变更内容 |
|---|---|
| ToggleRow | 新增矩阵入口 |
| build Stack | 增加 `showMatrix` 条件覆盖层 |
| MatrixPanel | 两组输入网格、维度/运算/清空/返回、结果和错误 |
| handlers | open/close/resize/edit/calculate/clear |

**变更理由**：遵循 PlotPanel 的现有覆盖层约定，最小化导航和 HAP 改动。

**实现要点**：打开时关闭 Plot/Settings/About；矩阵状态字段使用 `matrix*` 前缀；深层 cell 变更通过复制数组触发 ArkUI；cell key 包含矩阵名/行/列。

### 4.3 扩展测试聚合
**变更类型**：新增/修改。

| 组件 | 变更内容 |
|---|---|
| MatrixEngine.test | 精确算例、单位阵、奇异阵、负小数、非法结构、格式边界 |
| List.test | 显式调用 matrix suite |
| Tester evidence | UI cell 映射、状态转换、跨模式回归 |

**变更理由**：满足 IR-010，防止“测试存在但未注册/未运行”。

## 5. 兼容性说明

### 5.1 对现有功能的影响
| 功能 | 影响 | 处理方式 |
|---|---|---|
| 普通/科学计算 | 仅共享页面容器 | 不改 CalcEngine/Expression；独立状态；AC-012 |
| 绘图 | 新 overlay 与 PlotPanel 同层 | open handler 互斥；绘图回归 sin(x) |
| 历史/设置/关于 | 入口空间和 Stack overlay | 不改数据契约；打开矩阵关闭其他 overlay |
| 分数/程序员 | 当前仓库无实现 | 不新增、不占用其契约；未来基线需追加隔离回归 |
| 主题/横竖屏 | MatrixPanel 使用现有颜色和自适应容器 | 不新增硬编码主题状态；关键 UI 回归 |

### 5.2 对现有接口的影响
不修改公开接口。只新增 MatrixEngine 内部接口；标量 `evaluate()`、PreferencesStore、module 配置保持兼容。

### 5.3 对现有数据的影响
无持久化数据模型、key 或历史格式变化；矩阵状态仅内存。

## 6. 迁移方案

本文档不涉及数据或模块迁移。

### 6.1 迁移范围
无。

### 6.2 迁移步骤
不适用；实现仅增量编译进现有 entry HAP。

### 6.3 回滚方案
代码变更可通过移除矩阵入口、MatrixPanel 和新增 MatrixEngine/test 文件完整回滚；无数据清理。

### 6.4 验证方法
AC-002..009 验证算法/校验，AC-001/010/011 验证状态，AC-012 验证兼容，AC-014 验证独立证据。

## 7. 附录

### 7.1 术语表
| 术语 | 定义 |
|---|---|
| overlay | CalculatorPage Stack 内条件渲染的全屏覆盖面板 |
| matrix adapter | UI 字符串状态到完整 numeric Matrix 的校验边界 |

### 7.2 参考文档
- `proposal.md`
- `delta-spec.md`
- `acceptance-criteria.json`
- `info.md`
- `opencalc/spec/DESIGN.md`
