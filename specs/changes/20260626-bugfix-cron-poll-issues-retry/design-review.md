# 设计审视报告

**Issue**: #30 [CRON] 数据采集脚本连接失败 - WinError 10061
**变更目录**: `specs/changes/20260626-bugfix-cron-poll-issues-retry/`
**审视时间**: 2026-06-26 16:15
**审视人**: claude -p (AID PLANNING step9)

---

## 1. 完整性评估

### 1.1 制品齐全性
| 制品 | 是否产出 | 评估 |
|------|---------|------|
| `proposal.md` | ✅ | 通过 — 包含需求概述/解析/澄清/详述/影响范围/复杂度 |
| `delta-spec.md` | ✅ | 通过 — 8 个 SR + FMEA 8 项 + 9 个场景 |
| `info.md` | ✅ | 通过 — 含环境能力/架构/接口/影响/风险/测试 |
| `delta-design.md` | ✅ | 通过 — 由 mod-design skill 产出, D1-D10 + 自验证 |
| `todo.md` | ✅ | 通过 — 含环境能力/进度/关键决策 |
| `new-arch.md` | ✅ (跳过) | 跳过合理, 无架构变更, 单一文件 |
| `design-review.md` | ✅ | 本文件 |
| **完整性**: **通过 (8/8 制品齐全或合理跳过)** | | |

### 1.2 需求覆盖度
| 需求 | proposal | delta-spec | delta-design | 覆盖度 |
|------|----------|-----------|--------------|--------|
| gh_api 重试包装 | FR-1 (§4.1) | SR-RT-01 (§需求列表) | F-RT-01 + D3.5.8 算法 | 100% |
| 可重试错误白名单 | FR-2 (§4.1) | SR-RT-02 | F-RT-02 + D3.5.8 算法 1 | 100% |
| 退避抖动 | FR-3 (§4.1) | SR-RT-03 | F-RT-01 + D3.5.8 算法 2 | 100% |
| 429 Retry-After | (隐含) | SR-RT-04 | F-RT-03 + D3.5.8 算法 2 | 100% |
| .env 可选配置 | FR-4 (§4.1) | SR-RT-05 | F-RT-04 + D5.5 | 100% |
| [RETRY]/[DEGRADED] 日志 | FR-5 (隐含) | SR-RT-06 | F-RT-05 + D3.5.9 | 100% |
| 单元测试 | FR-5 (§4.1) | SR-RT-07 | F-RT-06 + D3.5.3 目录 | 100% |
| 不破坏现有行为 | (隐含) | SR-RT-08 | D3.5.10 (依赖) | 100% |
| 瞬时自愈 | REQ-DFR-001 (§4.2) | KEIs + FMEA FM-01~05 | D3.5.9 错误处理表 | 100% |
| 持续降级 | REQ-DFR-002 (§4.2) | FMEA FM-07/08 | D3.5.9 降级策略 | 100% |
| **总覆盖度**: **100%** | | | | |

---

## 2. 一致性评估

### 2.1 proposal → delta-spec 一致性
| proposal 章节 | delta-spec 对应 | 一致? |
|--------------|----------------|------|
| §1.4 需求描述 | §需求描述 表格 8 条 SR | ✅ |
| §1.5 使用场景 A/B/C/D | §场景 SC-RT-01/02/05/09 | ✅ |
| §2.4 关键实体 gh_api | §用例 UC-RT-01-01 | ✅ |
| §2.5 模糊点 1-6 | §3.1 决策 D1-D6 | ✅ |
| §2.6 复杂度 S | §6 复杂度 S | ✅ |
| §4.1 FR-1~5 | §需求列表 SR-RT-01~07 | ✅ |
| §4.2 REQ-DFR-001/002 | §FMEA FM-01~08 | ✅ |
| §5.1 涉及模块 | §3.5.3 目录结构 | ✅ |

**结论**: **通过 (8/8 一致)**

### 2.2 delta-spec → delta-design 一致性
| delta-spec 章节 | delta-design 对应 | 一致? |
|----------------|-----------------|------|
| SR-RT-01 重试 | F-RT-01 + D3.5.6 接口 + D3.5.8 算法 | ✅ |
| SR-RT-02 白名单 | F-RT-02 + D3.5.8 算法 1 | ✅ |
| SR-RT-03 抖动 | F-RT-01 + D3.5.8 算法 2 (random ±0.5) | ✅ |
| SR-RT-04 429 | F-RT-03 + D3.5.8 算法 2 (Retry-After 覆盖) | ✅ |
| SR-RT-05 .env | F-RT-04 + D5.5 Schema + D10 偏好 | ✅ |
| SR-RT-06 日志 | F-RT-05 + D3.5.9 错误处理表 | ✅ |
| SR-RT-07 单元测试 | F-RT-06 + D3.5.3 目录 (6 个测试方法) | ✅ |
| SR-RT-08 不破坏 | D3.5.10 依赖 (gh_api 函数体不变) | ✅ |
| FMEA FM-01~05 | D3.5.9 错误处理表 5 行 | ✅ |
| FMEA FM-06 永久错误 | D3.5.9 错误处理表 (401/403/404) | ✅ |
| FMEA FM-07/08 持续故障 | D3.5.9 降级策略 [DEGRADED] | ✅ |
| KEI-RT-01~04 | D3.5.8 算法 + D3.5.9 错误处理 | ✅ |

**结论**: **通过 (12/12 一致)**

### 2.3 delta-design 内部一致性
- D1.3 技术栈 (Python 3.12, 标准库) ↔ D3.5.10 依赖 (无 OHPM/OHOS) ↔ D9.1 (无 hvigor) — **一致**
- D2 P0 功能 ↔ D3.5.3 目录 ↔ D3.5.6 接口 — **一致**
- D3.5.8 算法 1 (_is_retryable) ↔ D3.5.9 错误处理表 — **一致** (URLError/SSL/Timeout/5xx/429 → 重试; 401/403/404/422 → 立即失败)
- D3.5.8 算法 2 (退避公式) ↔ SR-RT-03 (2^n + jitter ±0.5) — **一致**
- D3.5.8 算法 3 (主循环) ↔ D3.5.6 接口签名 — **一致**

**结论**: **通过**

---

## 3. 规范性评估

### 3.1 格式规范
- [x] proposal.md 章节结构: 1-7 章节完整 ✅
- [x] delta-spec.md 章节结构: 系统背景/上下文/需求/用例/SR 完整 ✅
- [x] info.md 章节结构: 环境能力 + 9 个分析类别完整 ✅
- [x] delta-design.md 章节结构: D1-D10 完整 (D4-D10 大部分标记 "无相关实现" 因 Python 脚本无 UI/页面/数据模型) ✅
- [x] design-review.md 章节结构: 1-4 章节完整 ✅

### 3.2 命名规范
- [x] 制品名: proposal/delta-spec/info/delta-design/design-review — 与模板一致 ✅
- [x] 目录名: `20260626-bugfix-cron-poll-issues-retry` (格式 `YYYYMMDD-type-name`) ✅
- [x] 函数名: `_retry_with_backoff`, `_is_retryable`, `_get_retry_after` (Python snake_case, `_` 前缀表示 internal) ✅
- [x] 测试名: `TestRetryBackoff`, `TestEnvConfig`, `TestRegression` (unittest PascalCase) ✅
- [x] 日志标签: `[RETRY]`, `[DEGRADED]`, `[OK]`, `[WARN]`, `[ERR]`, `[INBOX]`, `[REPO]` (大写一致) ✅
- [x] .env key: `POLL_RETRY_MAX`, `POLL_RETRY_BASE_DELAY` (大写下划线) ✅

### 3.3 描述清晰度
- [x] 需求描述有量化指标 (重试 3 次, 退避 2s 基数, ±0.5s jitter) ✅
- [x] 错误分类有明确白名单 (URLError/SSL/Timeout/5xx/429 vs 401/403/404/422) ✅
- [x] 日志格式有示例 (RETRY attempt=1/3 wait=2.0s reason=WinError 10061) ✅
- [x] 边界条件已覆盖 (连续 3 次失败, 持续故障, POLL_RETRY_MAX=0) ✅
- [x] KEI 指标已定义 (自愈率 ≥80%, P99 ≤30s, 退避精度 100%) ✅

### 3.4 可追溯性
- [x] SR ↔ FR ↔ UseCase ↔ Design 双向可追溯 ✅
- [x] FMEA 故障模式 ↔ 错误处理表 双向可追溯 ✅
- [x] KEI ↔ 单元测试 双向可追溯 ✅

---

## 4. 风险与遗留问题

### 4.1 风险
| # | 风险 | 等级 | 已缓解? | 缓解措施 |
|---|------|------|---------|---------|
| R-01 | 重试阻塞 cron tick > 30s | 中 | ✅ | max_attempts=3 + 退避封顶 8s → 最坏 30s |
| R-02 | thundering herd | 低 | ✅ | jitter ±0.5s |
| R-03 | 401/404 被错误重试 | 中 | ✅ | 白名单明确分类 |
| R-04 | 修改影响其他 profile | 低 | ✅ | 仅改 pm-01 副本 |
| R-05 | .env 缺省值破坏兼容 | 低 | ✅ | 双 key 缺省 + 类型转换 try/except |
| R-06 | poll-pm-01.log GBK 解码 | 低 | ✅ | 沿用现有 log() UTF-8/ASCII 策略 |
| R-07 | 跨 profile 共用 (dev-01/rev-01/arch-01) 修复 | 中 | ⏳ | 本期不动, 后续 issue 提取到 `~/.hermes/lib/` |
| R-08 | poll-*.log 长期累积 | 低 | ⏳ | 不在本期范围, 后续 issue 加 log rotation |

### 4.2 遗留问题
- **Q-01** (低): 是否需要在 Issue 评论里 @ pm-01 通知本 issue 修复方案?
  - **建议**: 不需要, pm-01 自动轮询时会自己看到 #30 close
- **Q-02** (中): 是否需要给 dev-01/rev-01/arch-01 同步应用修复?
  - **建议**: 另开 issue, 本 issue 严格限定 pm-01 (per Issue #30 描述)
- **Q-03** (低): 单元测试是否需要在 CI 中跑?
  - **建议**: 本期手动跑, 后续接入 hermes profile 的 CI

### 4.3 非阻塞警告
- W-01: 现有 `poll_issues.py` 已被修改过多次 (2026-06-09 19:49 最后一次), 建议本 issue 用最小 diff 避免冲突
- W-02: `archive_hermes.ps1` cron 任务结束时会自动归档, 本次修改后归档路径不变, 不影响流程

---

## 5. 审视结论

| 维度 | 结论 |
|------|------|
| **完整性** | ✅ **通过** (8/8 制品齐全, 100% 需求覆盖) |
| **一致性** | ✅ **通过** (proposal↔spec↔design 全链路一致) |
| **规范性** | ✅ **通过** (格式/命名/描述/追溯均规范) |
| **风险** | ✅ **可接受** (8 个风险已识别, 6 个已缓解, 2 个延后) |
| **遗留问题** | ✅ **非阻塞** (3 个, 均建议另开 issue 处理) |

### 总体评估
**PLANNING 阶段审视通过, 可进入 IMPLEMENTING 阶段。**

制品已就绪:
- `proposal.md` ✅
- `delta-spec.md` ✅
- `info.md` ✅
- `delta-design.md` ✅ (mod-design 产出)
- `design-review.md` ✅ (本文件, step9)
- `todo.md` ✅

### 下一步
进入 **AID IMPLEMENTING 阶段** — 调用 `aid-implementing` skill 产出 `tasks.md`, 将上述设计分解为可执行的任务序列。
