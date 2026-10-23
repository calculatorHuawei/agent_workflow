# 程序员模式与四进制转换开发任务

## 任务概述

- 功能名称：程序员模式与 BIN/OCT/DEC/HEX 转换
- 变更类型：新增功能（new_requirement）
- 关联 Issue：#45
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 设计输入：`proposal.md` / `delta-spec.md` / `info.md` / `new-arch.md` / `delta-design.md` / `20261023-programmer-mode-fmea分析表.md` / `design-review.md`
- 开发阶段：T0 精确转换 → T1 不可变状态操作 → T2 页面集成 → T3 回归与交接
- 预计任务数：7
- 任务颗粒度：每项预计 1–2 小时，均在 APPLYING 阶段按 RED → GREEN → REFACTOR 执行

## Planning 制品核验

- [x] `proposal.md`：功能边界、U64 安全默认值、状态隔离与验收目标明确。
- [x] `delta-spec.md`：IR-45-R1~R5、SC001~003、SR-01~05 及验收门禁完整可追溯。
- [x] `info.md`：实际代码路径、API 12、Hypium 聚合入口、构建命令和回归范围明确。
- [x] `new-arch.md`：单 entry HAP 增量架构及 `CalculatorPage → ProgrammerConverter → Models` 依赖方向明确。
- [x] `delta-design.md`：接口、状态、错误、UI、动画、响应式、T0~T3 顺序及精确算法回退策略明确。
- [x] `20261023-programmer-mode-fmea分析表.md`：CM-01~06 已映射到 SR 与测试门禁。
- [x] `design-review.md`：审视结论为“通过”，无 Planning blocker；`bigint` 语法和设备动画属于后续验证项。
- [x] `todo.md`：2026-10-24 PLANNING 复核已完成；本次 IMPLEMENTING 可进入，且本次不执行 APPLYING/ARCHIVING。

## 任务列表

### 阶段 1：基础模型与精确转换（T0）

#### Task 1.1：建立程序员模式领域契约与典型值转换

**描述**：先为 DEC `10`、HEX `FF`、零值规范化和非法字符编写失败测试，再新增 `CalculatorMode`、`Radix`、`ProgrammerError`、`ConversionResult`、`ProgrammerState`、`ProgrammerOperationResult` 等显式类型，并实现与 UI 无关的字符映射、精确解析和四进制大写格式化骨架。禁止复用浮点 `CalcEngine` 或 `number` 中转。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/model/Models.ets`
- 实现：`opencalc/entry/src/main/ets/programmer/ProgrammerConverter.ets`（新增）
- 测试：`opencalc/entry/src/test/ProgrammerConverter.test.ets`（新增）

**依赖任务**：无

**验收标准**：
- DEC `10` 输出 BIN `1010`、OCT `12`、DEC `10`、HEX `A`。
- HEX `FF` 输出 DEC `255`，字母统一大写，输出无前缀和无多余前导零。
- `isDigitAllowed` 对 BIN/OCT/DEC/HEX 的 `0-9/A-F` 合法矩阵与 SR-02 一致。
- 新增类型不修改既有模型字段语义，converter 不依赖 ArkUI、Preferences、网络或 IO。

**追溯**：IR-45-R2/R3；SR-01；SC002-UC001；AR-01/05；CM-01/03  
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.2：补齐 U64 边界、错误分类与精确算法回退

**描述**：扩充 RED 用例覆盖各进制的 `0`、U64_MAX、U64_MAX+1、负号、前缀、空格、分隔符、小写规范化与超长输入；实现逐字符范围门禁和 O(n) 早停。优先验证 ArkTS `bigint` 编译能力；若产品编译不接受，则保持公共接口不变，改用精确字符串算法，严禁降级为 `number`。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/programmer/ProgrammerConverter.ets`
- 测试：`opencalc/entry/src/test/ProgrammerConverter.test.ets`

**依赖任务**：Task 1.1

**验收标准**：
- `0` 与 `18446744073709551615` 精确成功，`18446744073709551616` 返回 `OUT_OF_RANGE`，不返回截断、舍入或部分结果。
- 非法字符返回 `INVALID_DIGIT`；空字符串返回 `EMPTY`；异常被转换为结构化 `INTERNAL`，不传播至 UI。
- BIN 64 位、HEX 16 位等最大有效输入可处理；明显超长输入快速拒绝，算法 O(n)、无 IO。
- 编译与单测证明实现未通过浮点 `number` 处理 U64。

**追溯**：IR-45-R3/R4；SR-01/05；SC003-UC002；AR-01/05；TM-01；CM-01/02/05  
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 2：不可变状态操作（T1）

#### Task 2.1：实现输入、退格、清空与进制切换的原子状态操作

**描述**：先编写状态转换失败测试，再实现 `appendDigit`、`backspace`、`clear`、`changeRadix` 和初始状态工厂。每个操作返回完整新对象；失败仅更新反馈语义并保留最后有效的 radix/input/result，合法恢复操作清除旧错误。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/model/Models.ets`
- 实现：`opencalc/entry/src/main/ets/programmer/ProgrammerConverter.ets`
- 测试：`opencalc/entry/src/test/ProgrammerConverter.test.ets`

**依赖任务**：Task 1.2

**验收标准**：
- BIN 状态追加 `2` 被拒绝，原 input/result/radix 不变并返回 `INVALID_DIGIT`。
- DEC `10` 切换至 BIN 后 input 为 `1010`；空态切换进制只改变 radix。
- 退格重算剩余值，删除最后一位与 AC 均进入 `EMPTY` 且 `result=null`；重复清空幂等。
- 非法或越界后可通过合法输入、退格或清空恢复，所有状态更新均为新对象且无异步副作用。

**追溯**：IR-45-R2/R3/R4；SR-02/05；SC002-UC002、SC003-UC001；AR-02/05；CM-03/06  
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 3：主页面与程序员面板集成（T2）

#### Task 3.1：集成模式状态、双向切换与普通状态隔离

**描述**：在同一 `CalculatorPage` 中新增默认 `NORMAL` 的单一模式状态、默认 DEC 空态的程序员状态及紧凑模式切换栏。模式赋值必须同步、幂等，不调用 `onAC`、历史写入或路由；先定义普通状态快照和快速切换验收场景，再完成最小集成。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 测试：`opencalc/entry/src/test/ProgrammerConverter.test.ets`（状态契约回归）

**依赖任务**：Task 2.1

**验收标准**：
- 启动仍为普通模式，普通 ↔ 程序员可双向切换，重复选择当前模式幂等。
- 普通 expression/result/history/scientific/radianMode/themeIdx 及绘图入口在往返后保持不变。
- 180ms 内连续模式选择以最后一次选择为准，不出现双分支或业务状态回调错序。
- 不新增路由、Preferences key、权限、依赖或持久化写入。

**追溯**：IR-45-R1/R5；SR-03/04/05；SC001-UC001/002；AR-03/04；CM-04  
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 3.2：渲染四进制结果、进制选择与内联反馈

**描述**：新增 `ProgrammerPanel`、`ProgrammerResults` 与 `ProgrammerRadixRow` Builders，把 converter 的完整状态一次性映射到输入、BIN/OCT/DEC/HEX 四行结果和 EMPTY/INVALID_DIGIT/OUT_OF_RANGE/INTERNAL 反馈；进制标签调用原子 `changeRadix`。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 测试：`opencalc/entry/src/test/ProgrammerConverter.test.ets`（页面消费契约）

**依赖任务**：Task 3.1

**验收标准**：
- 每次有效输入后四行结果同步来自同一 `ConversionResult`，DEC `10` 与 HEX `FF` 的页面展示符合 Issue AC。
- 空态显示占位符与“请输入数值”；非法、越界和内部错误文案可区分，错误态不展示候选部分结果。
- 进制切换保持数值并重写 input；选中状态不能只依赖颜色表达。
- 程序员面板复用现有主题 getter，在 Light/Dark/AMOLED 下不新增资源或偏好项。

**追溯**：IR-45-R2/R3/R4；SR-01/02/03；SC002、SC003；AR-02/03  
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 3.3：接入受限键盘、轻量动画与横竖屏布局

**描述**：新增 4×4 程序员键盘及 digit/AC/退格 handlers，UI 启停规则与业务 `isDigitAllowed` 共源；为实际模式变化添加 180ms ease-in-out 淡入和 4vp 位移动画，并复用 `isLandscape` 完成竖屏上下、横屏结果区与键盘区 2:3 的响应式布局。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 测试：`opencalc/entry/src/test/ProgrammerConverter.test.ets`（键矩阵和 handler 业务契约）

**依赖任务**：Task 3.2

**验收标准**：
- BIN 禁用 `2-9/A-F`，OCT 禁用 `8-9/A-F`，DEC 禁用 `A-F`，HEX 开放 `0-9/A-F`；禁用键无有效提交。
- AC、退格与合法字符事件只整体替换 `programmerState`，不修改普通状态。
- 动画只影响呈现，不用延时提交或完成回调修改业务状态；快速切换无明显空白帧、点击穿透或闪烁。
- phone/tablet 横竖屏中模式入口、反馈、AC/退格和四行结果可见可操作，64 位 BIN 结果不覆盖其他行。

**追溯**：IR-45-R1/R2/R5；SR-02/03/05；SC001、SC002-UC002；AR-03/05；CM-03/04/05  
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 4：聚合、回归与验证交接（T3）

#### Task 4.1：注册测试套件并完成构建、回归与设备验收交接

**描述**：将程序员转换测试注册到 Hypium 聚合入口，执行完整单测和产品构建，回归普通/科学/历史/主题/绘图链路；整理 Tester 阶段的模式动画、快速切换、横竖屏和触控尺寸用例，不以 Developer 阶段替代设备证据。

**涉及文件**：
- 实现：`opencalc/entry/src/test/List.test.ets`
- 测试：`opencalc/entry/src/test/ProgrammerConverter.test.ets`
- 验证：`opencalc/entry/src/test/PlotFunction.test.ets`（既有测试，不改语义）

**依赖任务**：Task 1.1、Task 1.2、Task 2.1、Task 3.1、Task 3.2、Task 3.3

**验收标准**：
- Hypium 聚合入口同时执行既有 PlotFunction 与新增 ProgrammerConverter 套件，典型值、边界、非法、空态、进制切换和失败原子性全部通过。
- `opencalc/build-test.bat`（或仓库约定等价 hvigor 命令）构建通过，无新增 ArkTS/lint 错误。
- 普通基础/科学计算、历史读取/删除/点击、主题/角度、绘图入口回归通过，Preferences schema 与权限/依赖清单无变化。
- Tester 交接明确覆盖双向/快速切换、180ms 动画无闪烁、phone/tablet 横竖屏布局和禁用键可访问性。

**追溯**：IR-45-R1~R5；SR-01~05；AR-04/05；Issue #45 全部验收标准  
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

## 依赖关系与并行性

| 任务 | 前置依赖 | 可并行说明 | 关键路径 |
|------|----------|------------|----------|
| Task 1.1 | 无 | 起点 | 是 |
| Task 1.2 | Task 1.1 | 与后续 UI 不可并行，先锁定精度契约 | 是 |
| Task 2.1 | Task 1.2 | 与 UI 不可并行，页面依赖状态契约 | 是 |
| Task 3.1 | Task 2.1 | 完成模式骨架后可为 3.2/3.3 提供落点 | 是 |
| Task 3.2 | Task 3.1 | 可与 Task 3.3 在不同 Builder 边界协作，但合入顺序在前 | 是 |
| Task 3.3 | Task 3.2 | 动画、键盘与布局共同依赖完整面板 | 是 |
| Task 4.1 | Task 1.1~3.3 | 收敛验证，不与未完成实现并行 | 是 |

## 开发顺序

```text
Task 1.1 → Task 1.2 → Task 2.1 → Task 3.1 → Task 3.2 → Task 3.3 → Task 4.1 → 完成
```

## 验收计划

| 任务 | 验收方式 | 验收阶段 |
|------|----------|----------|
| Task 1.1 | Hypium 典型值/字符矩阵单测 + 代码审查 | APPLYING / T0 |
| Task 1.2 | Hypium U64 边界/异常单测 + 产品编译 | APPLYING / T0 |
| Task 2.1 | Hypium 状态转换/失败原子性单测 | APPLYING / T1 |
| Task 3.1 | 构建 + 模式往返状态回归 + 快速切换场景 | APPLYING / T2 |
| Task 3.2 | 构建 + 结果/反馈/主题场景核对 | APPLYING / T2 |
| Task 3.3 | 构建 + 键矩阵核对；动画/响应式交 Tester | APPLYING / Tester |
| Task 4.1 | 全量 Hypium、产品构建、普通功能回归、UI 用例交接 | APPLYING / Tester |

## 阶段边界

本文件仅完成 IMPLEMENTING 任务分解与排序。本阶段不修改产品源码、不运行测试或构建、不进入 APPLYING、不提交、不推送、不归档。
