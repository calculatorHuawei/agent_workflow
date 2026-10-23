# QR 设备截图可解码缺陷修复开发任务

## 任务概述

- 功能名称：PR #43 Tester 反馈——二维码设备截图不可稳定解码
- 变更类型：缺陷修复（`tester_feedback`）
- 关联制品：`proposal.md` / `delta-spec.md` / `delta-design.md` / `info.md` / `design-review.md`
- 失败基线：PR #43 head `964c83e77e0c558001dcff396c07d43b226deae4`
- 开发阶段：仅规划后续 APPLYING 的 RED → GREEN → REFACTOR 工作；本文件不代表代码已修改或验证通过
- 预计任务数：4
- 任务颗粒度：每项预计 1–2 小时，可独立验收

## Planning 制品核验结论

- `proposal.md`：本轮意图已明确为 bugfix；修复范围限定为 QR 布局、Canvas 最终像素与相应测试，保护已通过的 AC1/AC4/AC6/AC7/AC8/AC9。
- `delta-spec.md`：SC-005、SR-03、SR-04 已覆盖整数模块、完整静区、显式白底、重绘时序、空间不足失败态、三主题及内容刷新后的独立截图解码。
- `delta-design.md`：§3.8 定义 QrLayout 纯函数边界及 CalculatorPage Canvas 契约；容量契约统一为 EC-M v10 byte 模式 213 字节。
- `info.md`：失败链路定位为 `QrPayload → QrEncoder → drawQr/Canvas → 设备截图 → 解码器`；不把候选修复或未证实 Canvas 机制写成已确认根因。
- `design-review.md`：PLANNING 已通过；准确修复 SHA、三主题原始截图、内容刷新前后载荷与独立解码日志仍是后续门禁。
- `todo.md`：PLANNING 已完成；本轮 IMPLEMENTING 仅刷新任务分解与阶段状态。

## 任务列表

### 阶段 1：契约修复（纯函数优先）

#### Task 1.1: 统一载荷层与编码器的 213/214 字节容量边界

**描述**：先把现有 271/272 载荷边界断言改为 213 字节通过、214 字节拒绝并观察 RED；随后仅修正 QrPayload 的容量常量、注释与失败契约，使载荷层和 QrEncoder 的 EC-M v10 byte 模式上限一致。不得改动载荷三行格式或已验证的编码算法。

**涉及文件**：

- 实现：`opencalc/entry/src/main/ets/qrcode/QrPayload.ets`
- 测试：`opencalc/entry/src/test/QrShare.test.ets`

**依赖任务**：无

**验收标准**：

- `MAX_BYTES` 等于 213，代码和测试中不再把 271 描述为 EC-M v10 byte 容量。
- 总 UTF-8 载荷恰为 213 字节时 `buildQrPayload` 成功并原样返回；214 字节时返回 `ok=false`、空 payload 和明确“内容过长”原因。
- `selectQrVersion(213)` 仍选 v10，`selectQrVersion(214)` 仍拒绝，载荷层与编码器不存在双重边界。
- 普通、科学、多字节、小数、负数及约 200 字节长载荷既有断言保持通过。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

**追溯**：SC002-UC002、SR-00、SR-04、CM-06、AC4、AC9

#### Task 1.2: 加固 QrLayout 的整数布局与空间不足契约

**描述**：先补充非法尺寸、非有限数、静区不足和最小可绘制边界测试并观察 RED；随后使 `qrModulePixels` 对有效输入返回非负整数、对非法或无法布局的输入返回安全失败值，并保持大画布模块上限 4。纯函数只计算布局，不接触主题或矩阵内容。

**涉及文件**：

- 实现：`opencalc/entry/src/main/ets/qrcode/QrLayout.ets`
- 测试：`opencalc/entry/src/test/QrShare.test.ets`

**依赖任务**：无（可与 Task 1.1 并行）

**验收标准**：

- 大画布返回 `MAX_SCREENSHOT_MODULE_PX=4`，较小画布返回实际可用整数，完整边长始终包含左右各 4 模块静区且不超画布。
- 零值、负值、`NaN`、无穷尺寸、非正矩阵边长或 `quietModules < 4` 不产生负数/小数布局，统一返回可被调用方识别的失败值。
- 当计算结果小于最小可绘制模块 4 时，测试明确标识为空间不足条件，不把它当作可扫码布局。
- QrLayout 保持无状态、零 UI/Kit/OHPM 依赖。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

**追溯**：SC005-UC001、SR-03、SR-04、F7、AC5、AC10

### 阶段 2：最终像素链路修复

#### Task 2.1: 修复 Canvas 完整重绘、失败态与内容刷新生命周期

**描述**：基于 Task 1.2 的布局失败信号修复 `drawQr` 和面板生命周期。每次打开先清除旧矩阵/成功态/错误态，再从当前 expression/result 现算；每次绘制先清整张 Canvas、显式铺满白底，再按整数网格绘制黑模块和完整静区。空间不足、空矩阵或绘制异常必须切换到明确失败态并移除旧码，不能静默 return。保持入口、回显、关闭零扰动及非 QR 模块行为不变。

**涉及文件**：

- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 测试：`opencalc/entry/src/test/QrShare.test.ets`

**依赖任务**：Task 1.1、Task 1.2

**验收标准**：

- Canvas 组件背景和 bitmap 绘制均为恒定 `#FFFFFF`，模块恒定 `#000000`；主题色不进入码面。
- 白底覆盖完整 Canvas；二维码按整数坐标居中，4 模块静区完整且不裁切。
- `onReady`、`onAreaChange` 及必要的主题/重新打开路径使用最新宽高与最新矩阵完整重绘。
- `modulePx < 4`、矩阵为空或绘制异常时清除旧矩阵/成功态并显示明确失败提示，不留下空白、残缺或陈旧二维码。
- 先打开 `1+2=3`，关闭后计算 `2+3=5` 并重开时，内部状态与人类可读回显只引用第二次内容；关闭仍仅改变 `showQrShare`。
- 不修改 `plot/`、`calculator/`、`model/`、`preferences/`、路由、权限或依赖配置。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

**追溯**：SC005-UC001、SC005-UC002、SR-03、CM-02、CM-05、CM-10、AC2、AC3、AC5

### 阶段 3：回归与可交付证据

#### Task 3.1: 完成持久化回归、构建检查与准确 SHA 测试交接

**描述**：在前三项 GREEN/REFACTOR 后执行完整持久化测试、HAP 构建、变更源 lint 和保护模块差异审计；执行 Developer 侧真实 UI 冒烟并保存截图解码日志用于快速发现最终像素问题。Developer 证据只作预检，不替代 Tester 从最终准确 PR head 独立重建、重装、三主题截图解码和内容刷新解码。

**涉及文件**：

- 测试注册：`opencalc/entry/src/test/List.test.ets`（仅核验，除非注册缺失不得修改）
- 持久化测试：`opencalc/entry/src/test/QrShare.test.ets`
- 后续 APPLYING 报告：`specs/changes/20261023-requirement-add-qrcode-share/apply-report.md`
- 后续验证日志：`specs/changes/20261023-requirement-add-qrcode-share/logs/verification-log.md`

**依赖任务**：Task 2.1

**验收标准**：

- 完整 Local Test 批次通过，包含 QrShare 与既有 PlotFunction 套件；新增断言已持久注册而非临时脚本。
- HAP 构建成功；变更 ArkTS 源 lint 无错误；AC8 保护模块 git diff 为空。
- Developer 冒烟至少覆盖 light/dark/AMOLED、`1+2=3` 与更新后的 `2+3=5`，并用独立标准解码器逐张核对精确 UTF-8 载荷；失败不得自报通过。
- apply-report/verification-log 记录 RED、GREEN、REFACTOR 命令和结果，不伪造未执行步骤。
- 交接清单明确最终 PR head SHA，并要求 Tester 从同一 SHA 重建、重装、保存原始截图/UI tree/命令日志，独立完成三主题及内容刷新解码；AC10 在 Tester 完成前保持未通过。

**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（汇总核验各任务记录）

**追溯**：SR-04、AC8、AC9、AC10；AC11 仍由 Reviewer 执行

## 任务依赖与开发顺序

```text
Task 1.1 ─┐
          ├─→ Task 2.1 → Task 3.1 → 交给独立 Tester
Task 1.2 ─┘
```

- 可并行：Task 1.1 与 Task 1.2 修改不同实现文件，但共享 `QrShare.test.ets`；并行实施时需协调测试文件编辑。
- 关键路径：Task 1.2 → Task 2.1 → Task 3.1。
- 禁止提前：Task 2.1 未完成前不得把纯函数测试通过等同于最终截图可解码；Task 3.1 的 Developer 冒烟不得替代 Tester/Reviewer 门禁。

## 验收计划

| 任务 | 验收方式 | 后续阶段 |
|------|----------|----------|
| Task 1.1 | 213/214 边界 RED-GREEN、QrPayload/QrEncoder 契约一致性审查 | APPLYING |
| Task 1.2 | QrLayout 合法/非法/最小空间数据驱动单测 | APPLYING |
| Task 2.1 | 持久化测试 + Developer 真实 UI/最终像素预检 | APPLYING |
| Task 3.1 | 全量测试、构建、lint、保护模块 diff、准确 SHA 交接审计 | APPLYING/Tester handoff |

## 范围护栏

- 本轮任务只允许修复 QR 容量契约、布局/Canvas 最终像素、失败态及相应测试。
- 不重做已通过的入口、面板回显、关闭、计算、绘图、历史、设置或主题业务。
- 不引入网络、第三方依赖、新权限、新路由或持久化数据。
- IMPLEMENTING 完成不授权修改产品源码、运行 APPLYING、commit、push 或 archive。
