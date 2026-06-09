# 实时预览结果 — 开发任务

> 关联特性：`feat-calculator-core`（OpenCalc HarmonyOS 移植版主计算器）
> 关联设计：`delta-design.md` D1~D12
> 关联需求：`delta-spec.md` SR-001~005
> 变更类型：requirement-add（新增功能）
> 工作分支：`feat/issue-3-realtime-preview`
> 唯一修改文件：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
> 变更日期：2026-06-09

---

## 任务概述

- **功能名称**：实时预览计算结果
- **关联特性**：feat-calculator-core
- **开发阶段**：IMPLEMENTING（基于已通过审视的设计方案 D1~D12）
- **预计任务数**：8 个（4 阶段）
- **预计提交数**：4 个（每个阶段一个原子提交，buildable 状态）

---

## 设计落地映射

| 设计条目 | 实施任务 | 验收点 |
|---------|---------|--------|
| D11 新增 `@State preview: string = ''` | Task 1.1 | 字段声明到位 |
| D11 新增 `updatePreview()` | Task 1.2 | 方法签名 + 5 种 ErrorFlags 分支 + try/catch |
| D11 6 个按钮回调追加 `this.updatePreview()` | Task 2.1 | 6 处回调末尾插入调用 |
| D11 调整 `onAC` 同步清 preview | Task 2.2 | AC 后 preview = '' |
| D11 DisplayPanel 结果 Text 多源渲染 | Task 3.1 | 优先级：preview > result > '0'；视觉按 SR-005 |
| D11 `onEquals` 末尾同步 `preview = result`（可选） | Task 3.2 | 推荐保持 preview 不动（设计 D-08 决策） |
| D12 #1-#9 检查清单 | Task 4.1 / 4.2 | 手动回归 + KEI 验证 |

---

## 任务列表

### 阶段 1：基础设施（State 字段 + 求值方法）

#### Task 1.1：新增 `@State preview` 字段
**描述**：在 CalculatorPage 的"显示状态"分区（line 16-25 附近）新增 `@State preview: string = ''` 字段声明。该字段承载"实时预览"语义，初值与 result/errorMsg 一致为空串。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`（line 18 附近插入）

**依赖任务**：无

**验收标准**：
- [ ] `@State preview: string = ''` 出现在"显示状态"分区内
- [ ] 字段修饰符、类型、命名与 result/errorMsg 风格一致
- [ ] 项目可编译（hilog 无新增 error）

**TDD**：N/A（纯字段声明，不涉及行为）

---

#### Task 1.2：实现 `updatePreview()` 私有方法
**描述**：在 CalculatorPage 内部新增 `private updatePreview(): void` 方法。算法严格对齐 `delta-design.md §3.5.8`：
1. 入口 `ErrorFlags.reset()`，杜绝上次残留（设计 R-01 缓解）
2. 空表达式短路：`expression.length == 0` → `preview = ''`，返回
3. `try` 内 `getCleanExpression` + `engine.evaluate`
4. 按 ErrorFlags 类型分别赋错误文案或格式化结果
5. `catch` 内统一赋 `preview = '计算错误'`

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`（建议放在 onEquals 之前，与按钮回调相邻）

**依赖任务**：Task 1.1（字段已就绪）

**验收标准**：
- [ ] 方法签名：`private updatePreview(): void`
- [ ] 入口首行 `ErrorFlags.reset()`
- [ ] 5 种 ErrorFlags 全部覆盖：division_by_0 / domain_error / syntax_error / is_infinity / require_real_number
- [ ] 异常 catch 分支返回 `preview = '计算错误'`
- [ ] 不写历史、不修改 result/errorMsg
- [ ] 不修改 expression 字段
- [ ] 项目可编译

**参考骨架**（来自 `delta-design.md §3.5.8` 算法 1）：
```typescript
private updatePreview(): void {
  if (this.expression.length === 0) { this.preview = ''; return }
  ErrorFlags.reset()
  try {
    const clean: string = this.expr.getCleanExpression(this.expression, '.', ',')
    if (ErrorFlags.syntax_error) { this.preview = ''; return }
    const raw: number = this.engine.evaluate(clean, !this.radianMode)
    if (ErrorFlags.division_by_0) { this.preview = '除数不能为零'; return }
    if (ErrorFlags.domain_error) { this.preview = '定义域错误'; return }
    if (ErrorFlags.is_infinity) { this.preview = '结果无穷大'; return }
    if (ErrorFlags.require_real_number) { this.preview = '需要实数'; return }
    if (ErrorFlags.syntax_error) { this.preview = ''; return }
    this.preview = NumberFormatter.format(raw.toString(), '.', ',', NumberingSystem.INTERNATIONAL)
  } catch (_e) { this.preview = '计算错误' }
}
```

**TDD**：RED → GREEN（Stage 4 单元测试覆盖）

---

### 阶段 2：触发链路（按钮回调接入）

#### Task 2.1：6 个按钮回调追加 `updatePreview()` 调用
**描述**：在 6 个按钮回调（`onDigit` / `onOp` / `onFunc` / `onConst` / `onBS` / `onAC`）的末尾插入 `this.updatePreview()`。注意：onEquals 不调用 updatePreview（设计 §3.5.4 时序图 2 明确 `=` 走原 result 固化流程，不经 preview）。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`（line 70-75 区域）

**依赖任务**：Task 1.2（方法已实现）

**验收标准**：
- [ ] onDigit 末尾追加 `this.updatePreview()`
- [ ] onOp 末尾追加 `this.updatePreview()`
- [ ] onFunc 末尾追加 `this.updatePreview()`
- [ ] onConst 末尾追加 `this.updatePreview()`
- [ ] onBS 末尾追加 `this.updatePreview()`
- [ ] onAC 末尾追加 `this.updatePreview()`（AC 也走 updatePreview 的"空表达式 → 空白"短路，无需在 onAC 内手动清 preview，但需注意 onAC 已有的 `ErrorFlags.reset()` 重复问题 — 保留即可，updatePreview 入口会再次 reset）
- [ ] onEquals 不调用 updatePreview（保持 `=` 行为不变，SR-004）
- [ ] 每个回调中 `this.updatePreview()` 是最后一句
- [ ] 项目可编译

**TDD**：N/A（接线层，行为验证在 Stage 4）

---

#### Task 2.2：onAC 内 `this.preview = ''` 显式同步（防御性）
**描述**：虽然在 onAC 末尾 `this.updatePreview()` 会被调用且 `expression.length === 0` 短路会赋 `preview = ''`，但出于「状态显式可控」原则，在 onAC 显式赋 `this.preview = ''`（参照 `this.result = ''; this.errorMsg = ''` 既有写法）。这一步让 onAC 内对所有可清状态的依赖是"显式"，与 result/errorMsg 对齐。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`（line 75）

**依赖任务**：Task 2.1

**验收标准**：
- [ ] onAC 内 `this.preview = ''` 与 `this.result = ''; this.errorMsg = ''` 并列
- [ ] onAC 末尾仍调用 `this.updatePreview()`（Task 2.1 已添加，不冲突）
- [ ] 项目可编译

**TDD**：N/A

---

### 阶段 3：UI 渲染（DisplayPanel 多源）

#### Task 3.1：DisplayPanel 改为多源渲染
**描述**：修改 `DisplayPanel` @Builder（line 225-253），将结果 Text 渲染逻辑改为：
- 优先级 1：`preview.length > 0` → 渲染 preview（**预览样式**：getT2() + 24-28pt + Normal 字重）
- 优先级 2：`result.length > 0` → 渲染 result（**固化样式**：getT1() + 36pt + Bold 字重）
- 优先级 3：兜底渲染 `'0'`（**固化样式**：getT1() + 36pt + Bold 字重）
- errorMsg 仍按基线单独渲染（在 Text 之前 if 分支），保留对 `=` 后错误态的展示

字号细节（来自 `delta-design.md §3.4.3`）：
| 元素 | 竖屏 | 横屏 | 颜色 | 字重 |
|------|------|------|------|------|
| preview | 28 | 22 | `getT2()` | Normal |
| result | 36 | 28 | `getT1()` | Bold |
| error | 28 | 22 | `getErr()` | Normal |

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`（line 242-249）

**依赖任务**：Task 2.1（preview 已有值流入）

**验收标准**：
- [ ] `if (this.errorMsg.length > 0)` 分支保留（基线行为）
- [ ] `else` 内改为 if-else if-else 三段：preview > result > '0'
- [ ] preview 渲染使用 `this.isLandscape ? 22 : 28` 字号 + `getT2()` 颜色（无 Bold）
- [ ] result 渲染保留 `this.isLandscape ? 28 : 36` 字号 + `getT1()` 颜色 + `FontWeight.Bold`
- [ ] '0' 兜底使用 result 同款样式
- [ ] 三个 Text 共享 `width('100%').textAlign(TextAlign.End).padding({ right: 12, left: 12 })` 属性
- [ ] 横竖屏字号正确联动
- [ ] 项目可编译

**TDD**：N/A（UI 渲染，手动走查）

---

#### Task 3.2：`onEquals` 末尾追加 `preview = result` 同步（可选，采用设计 D-08 推荐方案）
**描述**：在 `onEquals` 成功分支（result 赋值后）追加 `this.preview = this.result`，使 `=` 后 preview 与 result 视觉一致。**设计 D-08 推荐"保持 preview 不动"**——这是因 updatePreview 已在每次按键时实时刷新，`=` 时 preview 与 result 数值已一致；额外同步属冗余。本任务标 *可选*，**实施阶段建议跳过**（保持 preview 不动，避免重复赋值增加认知负担）。如最终决定同步，应只在成功分支追加（错误分支 result 为空，无需同步）。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`（line 90-91 区域，**仅当决定同步时**修改）

**依赖任务**：Task 3.1

**验收标准**（**仅当本任务被执行时**）：
- [ ] onEquals 成功分支 `this.result = fmt` 之后追加 `this.preview = this.result`
- [ ] 错误分支不动（result 为空，无须同步）
- [ ] 项目可编译

**TDD**：N/A

> **本任务的决策**：建议在 IMPLEMENTING 阶段与用户确认后决定。若用户未指定，默认**跳过**（与设计 D-08 推荐一致）。

---

### 阶段 4：验证与回归

#### Task 4.1：手动回归 — 5 种 ErrorFlags 渲染检查
**描述**：在 DevEco Studio 启动模拟器，逐项验证 5 种 ErrorFlags 都能在预览态正确渲染（KEI-03 = 5/5）。每项检查后通过 AC 清状态再继续。

**测试用例**（来自 `delta-design.md §3.5.5` 用例 2 + KEP-01/02）：
| 序号 | 输入序列 | 预期 preview |
|------|---------|-------------|
| 1 | `1` `/` `0` | `除数不能为零` |
| 2 | `ln` `(` `-` `1` `)` | `定义域错误` |
| 3 | `1` `+` | `''`（空白） |
| 4 | `9` `^` `999` | `结果无穷大` 或 `''`（视 evaluate 内部 ErrorFlags 行为） |
| 5 | `√` `(` `-` `1` `)` 或 `(-1)^0.5` | `需要实数` |
| 6 | `AC` | `''`（空白） |

**依赖任务**：Task 3.1

**验收标准**：
- [ ] 5 种 ErrorFlags 全部按预期渲染
- [ ] 不完整表达式 → 空白
- [ ] AC 后立即清空

**TDD**：手动回归

---

#### Task 4.2：手动回归 — KEP-01/02/03 关键体验
**描述**：在 3 种主题（浅色 / 暗色 / AMOLED）和横竖屏下分别验证 KEP-01/02/03 路径。

**测试矩阵**：
| 主题 | 横屏 | 竖屏 |
|------|------|------|
| 浅色 (themeIdx=0) | KEP-01/02/03 | KEP-01/02/03 |
| 暗色 (themeIdx=2) | KEP-01/02/03 | KEP-01/02/03 |
| AMOLED (themeIdx=1) | KEP-01/02/03 | KEP-01/02/03 |

**具体路径**：
- KEP-01（合法表达式预览）：输入 `1+2` → 立即看到 `3`（无 `=`）
- KEP-02（退格修正）：输入 `100/30` → 看到 `3.333...` → 退格 → 看到 `10` → 再退格 → 空白
- KEP-03（`=` 行为兼容）：输入 `2+3` → 按 `=` → result 区显示 `5`（字号更大）→ HistoryPanel 顶部新增

**依赖任务**：Task 4.1

**验收标准**：
- [ ] 3 主题 × 2 方向 = 6 个组合下，preview/result 视觉差异肉眼可辨
- [ ] KEP-01：按键到结果区像素刷新 < 100ms
- [ ] KEP-02：退格无残留
- [ ] KEP-03：`=` 行为与变更前完全一致（result 固化 + history 新增）

**TDD**：手动回归

---

## 开发顺序

```
阶段 1 基础设施
  Task 1.1（@State preview 字段）        ← 原子提交 #1
  Task 1.2（updatePreview 方法）          ← 原子提交 #1（同提交）
  ↓
阶段 2 触发链路
  Task 2.1（6 回调接入）                  ← 原子提交 #2
  Task 2.2（onAC 显式清 preview）         ← 原子提交 #2（同提交）
  ↓
阶段 3 UI 渲染
  Task 3.1（DisplayPanel 多源渲染）       ← 原子提交 #3
  Task 3.2（onEquals 同步，可选）         ← 视决策并入 #3 或独立 #4
  ↓
阶段 4 验证
  Task 4.1（5 种 ErrorFlags 检查）        ← 手动验证，不提交
  Task 4.2（KEP-01/02/03 体验）           ← 手动验证，不提交
```

### 提交顺序（4 个原子提交）

| 提交序号 | 包含任务 | 提交信息要点 | 状态 |
|---------|---------|------------|------|
| #1 | Task 1.1 + 1.2 | `feat(calculator): add preview state and updatePreview method` | buildable（功能未启用，行为无变化） |
| #2 | Task 2.1 + 2.2 | `feat(calculator): wire updatePreview into 6 button callbacks` | buildable（DisplayPanel 仍只渲染 result/errorMsg，无视觉变化） |
| #3 | Task 3.1 (+ 3.2 视决策) | `feat(calculator): render realtime preview in DisplayPanel` | buildable（功能全量启用，行为符合 D12 检查清单） |
| #4 (可选) | Task 3.2 独立 | `feat(calculator): sync preview with result on equals` | 仅当 Task 3.2 未并入 #3 时存在 |

> **为什么分 3 个原子提交？** 设计审查 D-07 标记"compute() 抽离"为可选，Task 1.2 未抽离公共方法（与基线 onEquals 共享求值代码存在 1 处重复）。分阶段提交让 reviewer 能逐步核对：(1) 字段/方法骨架正确 → (2) 触发链正确 → (3) 渲染正确，避免一次性大 diff 难以 review。

---

## 风险与回退

| 风险 | 应对 |
|------|------|
| 提交 #2 行为未变化，难以观察正确性 | 在 PR description 中标注"行为静默，DisplayPanel 尚未消费 preview" |
| 提交 #3 后视觉/功能异常 | `git revert` 提交 #3（#1/#2 仍可保留作为未来重构基础） |
| onEquals `preview = result` 同步引发用户感知差异 | 默认跳过此任务（设计 D-08 推荐） |
| 极长表达式性能 | 设计 R-02 评估 < 1ms；若实测卡顿，列入后续 Issue |

---

## 验收计划

| 任务 | 验收方式 | 验收时间 | 阻塞？ |
|------|---------|---------|-------|
| Task 1.1 | 代码审查（hilog 无 error） | 提交 #1 时 | 否 |
| Task 1.2 | 代码审查（5 种分支覆盖） | 提交 #1 时 | 否 |
| Task 2.1 | 代码审查（6 处插入 + 1 处 onEquals 排除） | 提交 #2 时 | 否 |
| Task 2.2 | 代码审查 | 提交 #2 时 | 否 |
| Task 3.1 | 代码审查 + 手动走查 | 提交 #3 时 | 否 |
| Task 3.2 | 代码审查（若执行） | 提交 #3 或 #4 时 | 否 |
| Task 4.1 | 手动回归（5 种 ErrorFlags） | 提交 #3 后 | **是**（阻塞 PR 合并） |
| Task 4.2 | 手动回归（3 主题 × 2 方向 × 3 KEP） | 提交 #3 后 | **是**（阻塞 PR 合并） |

---

## 实施检查清单（对齐 D12）

- [ ] Task 1.1：`@State preview: string = ''` 已声明
- [ ] Task 1.2：`updatePreview()` 实现含 ErrorFlags.reset + try/catch + 5 种错误分支 + format
- [ ] Task 2.1：6 个按钮回调追加 `this.updatePreview()`
- [ ] Task 3.1：DisplayPanel 改为 preview > result > '0' 优先级
- [ ] Task 3.1：preview 字号 `isLandscape ? 22 : 28`、颜色 `getT2()`、Normal 字重
- [ ] Task 4.1：5 种 ErrorFlags 均能正确渲染
- [ ] Task 4.1：退格/AC 后预览立即清空
- [ ] Task 4.2：`=` 行为完全不变
- [ ] Task 4.2：横竖屏、3 种主题下视觉一致

---

## 与设计决策的对应

| 设计决策 | 对应任务 | 备注 |
|---------|---------|------|
| D-07 不抽离 compute() 公共方法 | Task 1.2 与现有 onEquals 共享求值代码（1 处重复） | 标记 nice-to-have，不阻塞 |
| D-08 `onEquals` 末尾 `preview = result` 二选一，推荐后者 | Task 3.2 标记可选，建议跳过 | 与用户确认前默认跳过 |
| D-04 不引入 debounce | 8 个任务均无 debounce 设计 | 符合 |
| D-06 沿用 CalculatorPage.ets 内 @Builder，不抽离 | 8 个任务均无新建文件 | 符合 |

---

> 本文档由 aid-implementing skill 生成。
> 颗粒度校验：每个任务 1-2 小时内可完成；输入/输出明确；验收标准可观察。
> 生成时间：2026-06-09
