# 设计审视报告

## 1. 审视范围与结论

审视对象：Issue #45 的 `proposal.md`、`delta-spec.md`、`info.md`、`new-arch.md`、`delta-design.md`、FMEA 分析表和 `todo.md`。

**结论：通过。** PLANNING 制品完整，需求→场景/UC→SR→AR/设计→验收门禁可追溯；普通产品歧义已按 assignment 授权采用安全、可逆、最小范围默认值，不存在需要凭据、付费服务、隐私/合规决策、破坏性操作或范围实质扩张的 blocker。

## 2. 完整性评估
- [x] 制品齐全性：通过（proposal/spec/info/architecture/design/FMEA/review/todo 均存在）。
- [x] 需求覆盖度：100%（Issue 6 项功能范围与 6 项验收要求均有 UC、SR 和设计映射）。
- [x] 初始化确认：通过（`specs/initialized.flag` 有效；PROJECT_ROOT=`opencalc`，TEST_ROOT=`opencalc/entry/src/test`）。
- [x] 意图分类：通过（产品意图为新增功能；当前 `bugfix` 标签仅表示 Reviewer 反馈触发的流程补正）。
- [x] 阶段边界：通过（本次复核未创建或修改 `tasks.md`、产品源码，未实施/提交/推送/归档；仓库中既有文件来自被复核的精确 PR HEAD）。

### 2.1 Issue 验收覆盖
| Issue 验收点 | Spec/UC | SR | Design/AR | 结论 |
|--------------|---------|----|-----------|------|
| DEC 10 → BIN 1010/OCT 12/HEX A | SC002-UC001 | SR-01 | AR-01/05 | 覆盖 |
| HEX FF → DEC 255 | SC002-UC001 | SR-01 | AR-01/05 | 覆盖 |
| BIN 禁止 2-9 | SC002-UC002 | SR-02/05 | AR-02/03/05 | 覆盖 |
| 普通/程序员双向切换，动画无闪烁 | SC001-UC001/002 | SR-03/05 | AR-03/05 | 覆盖 |
| 切换无崩溃、错算或无关历史丢失 | SC001-UC001/002 | SR-04/05 | AR-04/05 | 覆盖 |
| 边界、非法、切换测试 | SC001~003 | SR-01~05 | AR-05 | 覆盖 |

## 3. 一致性评估
- [x] proposal → delta-spec：通过。U64、状态保持、进制切换语义、范围排除和动画规格一致。
- [x] delta-spec → new-arch：通过。SR-01/02 的独立业务组件与 SR-03/04 的页面集成/兼容边界一致。
- [x] delta-spec → delta-design：通过。5 个 SR 均映射到 AR，6 个 UC 均有实现设计与门禁。
- [x] info → design：通过。单 entry HAP、V1 `@State`、现有 Preferences/Hypium/响应式和主题惯例均被遵守。
- [x] FMEA → spec/design：通过。CM-01~05 已进入 SR-05、算法禁则、错误原子性和自动化门禁；CM-06 由 EMPTY 状态设计覆盖。

### 3.1 追溯摘要
```text
IR-45-R1 模式切换 → SC001 → SR-03/05 → AR-03/05
IR-45-R2 合法输入 → SC002-UC002 → SR-02/05 → AR-02/03/05
IR-45-R3 同步转换 → SC002 → SR-01/02 → AR-01/02/05
IR-45-R4 错误边界 → SC003 → SR-01/02/05 → AR-01/02/05
IR-45-R5 兼容测试 → SC001-UC001 → SR-04 → AR-04/05
```

## 4. 规范性评估
- [x] 格式规范：通过。proposal 遵循 1~10；delta-spec 保留 1~13；delta-design 按 D1~D10 并补充追溯/门禁；new-arch 保留完整架构前置结构。
- [x] 命名规范：通过。场景 `SC-xxx`、用例 `SCxxx-UCxxx`、需求 `IR-45-Rx`、系统需求 `SR-xx`、分配需求 `AR-xx` 一致。
- [x] 验收可测：通过。UC 均包含 Actor、STAGE 前置、最小/成功保证、触发、主/扩展路径和 Given-When-Then。
- [x] 无模板占位：通过。所有模板字段均已解析为本需求的实际内容。
- [x] 最小权限/依赖：通过。无新增权限、网络、后台、第三方包、持久化 key 或部署模块。

## 5. 设计质量评估

### 5.1 正确性
- 精确转换与现有浮点表达式引擎隔离，避免 U64 大值静默舍入。
- 输入字符、上界和输出格式都有单一业务边界；UI 禁用不是唯一校验。
- 进制切换保持数值而非重解释文本，避免 `DEC 10 → BIN 2` 类语义错误。

### 5.2 兼容性
- 普通字段/接口/Preferences schema 不改，模式切换不调用 `onAC` 或 `setHistory`。
- 不新增路由，减少页面生命周期造成的状态丢失。
- 默认启动仍为普通模式；程序员草稿不跨重启，避免迁移和设置扩张。

### 5.3 可靠性
- FMEA 中 RPN≥100 的精度、越界和非法输入风险均有 SR 与测试门禁。
- 快速切换采用同步幂等状态，动画不提交业务；失败不部分更新。
- 超长/超范围输入早停，纯内存 O(n)，无主线程 IO。

### 5.4 可实现性
- 当前 SDK API 声明存在 `bigint`，但 ArkTS 产品源码语法仍标记为实施验证项。
- 若 `bigint` 源语法不可用，设计已提供接口不变的精确字符串算法回退；不允许退化为 `number`。
- 现有 Hypium 测试聚合入口和主题/布局惯例可复用。

## 6. 审视中发现并已修正的问题
| # | 问题 | 级别 | 修正 |
|---|------|------|------|
| 1 | 早期草稿把普通范围歧义误标为 blocker 并等待人工确认 | 中 | 按 worker authorization 自动选择 U64 非负与隔离草稿并记录 rationale |
| 2 | 设计错误模型的内部异常行与枚举图不一致 | 低 | 在 spec 状态和 design enum/state machine 中统一增加 `INTERNAL` 兜底 |
| 3 | 历史增强草案包含位运算，可能扩大当前 Issue | 中 | 明确排除位运算/表达式/补码/字长，当前 Issue 优先 |

## 7. 遗留问题与非阻塞风险
| 风险 | 状态 | 后续门禁 |
|------|------|----------|
| ArkTS 编译器是否接受计划的 `bigint` 源语法 | 非阻塞实施验证 | APPLYING 先做最小编译 + MAX/MAX+1 单测；失败采用精确字符串算法 |
| 动画无闪烁与横竖屏触控尺寸 | 需设备/模拟器证据 | Tester 阶段执行 UI 测试；Developer 不提前声称覆盖 |
| `CalculatorPage` 已较大 | 可控维护性风险 | 转换算法必须放 `programmer/`，页面只做编排/Builders |

以上风险均不要求凭据、付费服务、隐私/合规选择、破坏性动作或超出 Issue 的范围，因此不构成 Planning blocker。

## 8. 最终门禁
- [x] proposal 完整且假设有 rationale。
- [x] delta-spec 具有完整场景/UC/SR/DFX/追溯。
- [x] info 基于实际代码和构建约定。
- [x] new-arch 明确当前架构与变更点。
- [x] delta-design 覆盖 D1~D10、接口、模型、状态、错误、UI、平台和门禁。
- [x] FMEA 高风险全部转化为可验证 SR。
- [x] todo 已单独记录本次 PLANNING 复核完成；既有 IMPLEMENTING/APPLYING 历史不被本次重写或冒认。

**审视判定：PLANNING 复核通过；本次到此停止，不创建或修改 tasks.md，不进入 IMPLEMENTING/APPLYING/ARCHIVING。**

## 9. 2026-10-24 Reviewer 反馈闭环复审

| 检查项 | 结果 | 依据 |
|--------|------|------|
| 初始化与意图分类 | 通过 | 初始化标记有效；产品意图为新增功能，`bugfix` 仅是过程补正标签 |
| PLANNING 顺序 | 通过 | 依次完成 rq-parse、rq-clarify、delta-spec/FMEA、rq-codebase、复杂度、架构、mod-design、设计审视 |
| 制品完整性 | 通过 | proposal、delta-spec、info、new-arch、FMEA、delta-design、design-review、todo 均非空 |
| 设计与精确 HEAD 一致性 | 通过 | 字符串精确算法、共享键规则、隔离状态、180ms/4vp 过渡均落在已批准设计范围 |
| 本次阶段边界 | 通过 | 未触碰产品源码、`tasks.md`、提交、推送、PR、归档或外部系统状态 |

Reviewer 指出的旧 run manifest 缺少 session source/snapshot/hash 属于外层证据保存问题，无法通过伪造历史记录修复。本次采用真实、独立的 PLANNING 执行重新生成可由 orchestrator 捕获的过程，并只更新规划制品；无阻塞条件。
