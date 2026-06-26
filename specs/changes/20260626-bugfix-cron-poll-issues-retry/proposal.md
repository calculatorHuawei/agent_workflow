# poll_issues.py 重试机制 需求提案

## 1. 需求概述

### 1.1 功能名称
pm-01 cron poll_issues.py 网络故障重试与降级

### 1.2 需求类型
缺陷修复 (bugfix)

### 1.3 关联特性
feat-pm-01-cron (pm-01 Issue Manager 数字员工)

### 1.4 需求描述
pm-01 Issue Manager 的 cron 轮询脚本 `poll_issues.py` 在调用 `https://api.github.com` 时, 频繁 (2026-06-22 至 2026-06-26 累计 20+ 次) 抛出 `<urlopen error [WinError 10061] 由于目标计算机积极拒绝, 无法连接。>`, 导致 pm-01 无法处理分配的 open issues, 进而自动产生了 Issue #30 自身。

根因: 脚本使用 `urllib.request.urlopen()` 直接调用 GitHub API, 没有任何重试 / 退避 / 降级机制, 遇到瞬时网络故障 (WinError 10061 / SSL EOF / Timeout) 立即失败并退出。

修复目标: 为 `gh_api()` 调用增加**指数退避重试 + jitter**, 并在重试用尽后给出可观察的失败日志, 让 pm-01 数字员工在 80% 以上的瞬时网络故障中自我恢复, 减少人工介入。

### 1.5 使用场景
- 场景 A: **网络瞬时中断** — 公司代理/防火墙/本地 NIC 短暂不可用, 10061 持续 2-5 秒后恢复 → 当前立即失败, 修复后重试成功
- 场景 B: **TLS 握手失败** — 偶发 `SSL: UNEXPECTED_EOF_WHILE_READING` (poll-pm-01.log 中 2026-06-11/14/17/18 多次出现) → 修复后重试成功
- 场景 C: **GitHub API 限流** — HTTP 429 → 当前直接 exit 1, 修复后按 `Retry-After` 头退避
- 场景 D: **服务持续不可用** — 10 分钟内仍失败 → 标记 `[DEGRADED]`, 不再无限重试, 由下次 cron tick 再来

### 1.6 预期效果
- pm-01 cron 在 30 分钟调度窗口内对单次 10061 故障**完全自愈** (≤3 次重试)
- poll-pm-01.log 中 `[ERR] WinError 10061` 行数下降 ≥ 70%
- 网络恢复正常后, 下一次 cron tick (30m 后) 能成功抓到所有漏抓的 issue
- 不引入新依赖 (仅用标准库 `urllib`, `time`, `random`)

## 2. 需求解析报告

### 2.1 意图分类
- **类型**：缺陷修复
- **一句话概括**: pm-01 的 GitHub API 轮询脚本缺网络容错, 加上指数退避重试 + jitter, 让瞬时故障自愈

### 2.2 领域映射
- **网络通信**: GitHub REST API (`https://api.github.com/repos/...`) 的 `urllib.request.urlopen()` 调用路径
- **可靠性 (DFR)**: 故障检测 (HTTPError/URLError 分类) + 故障恢复 (指数退避) + 降级 (重试用尽后静默退出)
- **可观测性**: 现有 log() 函数扩展 [WARN] 标签, 区分瞬时 vs 持续故障

### 2.3 影响层次
| 层次 | 变更类型 | 说明 |
|------|---------|------|
| 基础设施 (infrastructure) | modify | `poll_issues.py` 单一文件, 修改 `gh_api()` 函数, 新增 `_retry_with_backoff()` 装饰器式函数 |
| 可观测性 | extend | 新增日志分类: `[RETRY]`, `[DEGRADED]` |

### 2.4 关键实体
- **数据实体**: 无 (不新增数据模型)
- **页面实体**: 无 (无 UI 变更)
- **接口实体**:
  - `gh_api(endpoint: str, token: str) -> dict` (modify — 增加内部重试)
  - 新增: `_retry_with_backoff(fn, *args, max_attempts=3, base_delay=2.0, **kwargs) -> result`
- **事件实体**:
  - `RetryEvent` (瞬时故障, 进入退避)
  - `DegradedEvent` (重试用尽, 本次 cron 失败)
  - `RecoveredEvent` (重试后成功)
- **配置实体**:
  - `.env`: 新增可选配置 `POLL_RETRY_MAX=3` (默认 3), `POLL_RETRY_BASE_DELAY=2.0` (默认 2 秒)

### 2.5 模糊点
| # | 类别 | 描述 | 严重程度 |
|---|------|------|---------|
| 1 | 行为模糊 | 重试次数: 2 / 3 / 5? | important (默认 3, 30 分钟 cron 窗口内可承受 ≤ 8 秒总退避) |
| 2 | 行为模糊 | 退避策略: 固定 / 线性 / 指数 / 指数+jitter? | important (默认 指数退避 2^n + ±0.5s jitter) |
| 3 | 行为模糊 | 哪些错误重试, 哪些不重试? (HTTP 401/404 应立即失败, 10061/SSL/Timeout/5xx/429 应重试) | important (按可重试白名单) |
| 4 | 范围模糊 | 是否回退到 `gh` CLI 调用? | nice-to-have (本期不做, 仅做 urllib 重试; 后续可加 gh CLI fallback) |
| 5 | 约束模糊 | 是否支持配置化? 还是硬编码? | nice-to-have (建议支持 .env 配置, 默认值兜底) |

**无 blocker 级别模糊点**, 可继续 PLANNING。

### 2.6 复杂度评估
- **等级**：S (简单)
- **理由**: 单一 Python 文件, 单一函数, < 100 行代码改动, 不涉及 UI/数据模型/架构, 无新依赖

## 3. 需求澄清

### 3.1 已澄清的关键决策
| # | 问题 | 决策 | 来源 |
|---|------|------|------|
| 1 | 重试几次? | 3 次 (默认) | 30 分钟 cron 窗口 + 退避 2+4+8=14s 总开销可接受 |
| 2 | 退避策略? | 指数退避 + ±0.5s jitter | 避免 thundering herd, 与 GitHub 限流最佳实践一致 |
| 3 | 哪些错误重试? | 10061 / SSL EOF / Timeout / 5xx / 429 (按 Retry-After) | 业务可重试白名单 |
| 4 | 哪些错误不重试? | 401 (token 无效) / 404 (repo 不存在) / 422 (请求参数错) | 永久失败, 重试无意义 |
| 5 | 是否回退到 gh CLI? | 本期**不做** | 单一改动最小化, 后续可独立 issue |
| 6 | 是否可配置? | 是 (.env 可选), 默认值兜底 | 不破坏现有部署 |

### 3.2 待定假设
- 假设 1: 当前 pm-01 cron tick 之间 (30 分钟) 大部分 10061 故障是 ≤ 15 秒的瞬时中断
- 假设 2: GitHub API 限流 (429) 频率极低, 不需要专用的速率限制器, 仅按 `Retry-After` 头退避
- 假设 3: 现有 `log()` 函数 (含 GBK 区域安全处理) 不需要修改, 仅扩展日志标签

### 3.3 功能边界
- **包含**:
  - `gh_api()` 函数的指数退避重试封装
  - 可重试错误白名单 (10061 / SSL EOF / Timeout / 5xx / 429)
  - 不可重试错误立即失败 (401/404/422)
  - 重试日志: `[RETRY]` 标签
  - 降级日志: `[DEGRADED]` 标签 (重试 N 次后仍失败)
  - .env 可选配置: `POLL_RETRY_MAX`, `POLL_RETRY_BASE_DELAY`
  - 单元测试: 覆盖 10061 / Timeout / 5xx / 429 / 401 / 200 五种场景
- **不包含** (本期边界外, 后续 issue):
  - `gh` CLI fallback
  - 持久化重试队列 (失败后写入 SQLite/JSON 等下次 tick 拉取)
  - Prometheus 指标上报
  - 跨 cron tick 的失败累计 (本次失败仅影响本次 tick)

## 4. 需求详述

### 4.1 功能需求

#### FR-1: gh_api() 增加指数退避重试
**描述**: `gh_api()` 函数被 `_retry_with_backoff()` 包装, 在遇到可重试错误时按 2^n 秒退避 (n=1,2,3) + 随机 jitter 重试
**验收条件**:
- 单次 `urllib.error.URLError` (含 WinError 10061) → 重试 3 次, 总退避 ≤ 14s
- 3 次后仍失败 → 抛出最后一次异常, 由 `main()` 记录 `[DEGRADED]` 日志
- 重试日志格式: `[RETRY] attempt=2/3 wait=4.0s reason=WinError 10061`

#### FR-2: 可重试错误白名单
**描述**: 仅对特定错误类型重试, 避免对永久错误做无意义重试
**验收条件**:
- ✅ 重试: `urllib.error.URLError` (含 10061 / SSL EOF / DNS 失败 / Timeout)
- ✅ 重试: `urllib.error.HTTPError` 429 (按 `Retry-After` 头退避)
- ✅ 重试: `urllib.error.HTTPError` 5xx
- ❌ 不重试: `HTTPError` 401 / 403 / 404 / 422 — 立即抛出
- ❌ 不重试: `JSONDecodeError` — 立即抛出 (服务端返回非 JSON 不是网络问题)

#### FR-3: 退避抖动 (jitter)
**描述**: 退避时间叠加 ±0.5s 随机抖动, 避免与同一时刻触发的其他客户端形成 thundering herd
**验收条件**:
- 第 N 次重试等待时间 = `base * 2^(N-1) + random.uniform(-0.5, 0.5)`, 最小 0.5s
- N=1: 2±0.5s; N=2: 4±0.5s; N=3: 8±0.5s

#### FR-4: .env 可选配置
**描述**: `POLL_RETRY_MAX` 和 `POLL_RETRY_BASE_DELAY` 允许通过 .env 调整, 缺省走默认值
**验收条件**:
- `POLL_RETRY_MAX=5` → 重试 5 次
- `POLL_RETRY_MAX=0` → 关闭重试 (回到原始行为)
- `POLL_RETRY_BASE_DELAY=1.0` → 退避基数 1 秒 (1/2/4s)
- 缺省: `POLL_RETRY_MAX=3`, `POLL_RETRY_BASE_DELAY=2.0`

#### FR-5: 单元测试覆盖
**描述**: 用 `unittest.mock` 模拟各种网络场景, 验证重试逻辑
**验收条件**:
- ✅ 测试 1: 200 OK → 单次调用即返回, 无重试
- ✅ 测试 2: 第一次 10061, 第二次 200 → 重试 1 次后成功
- ✅ 测试 3: 连续 3 次 10061 → 重试 2 次后失败 (max=3 即 1 原始 + 2 重试)
- ✅ 测试 4: 401 → 立即失败, 不重试
- ✅ 测试 5: 429 含 `Retry-After: 5` → 按 5s 退避
- ✅ 测试 6: 退避时间窗口验证 (mock time.sleep, 验证 [1.5, 2.5] / [3.5, 4.5] / [7.5, 8.5])

### 4.2 可靠性需求

#### REQ-DFR-001: 瞬时网络故障自愈
**描述**: pm-01 cron 在单次 30 分钟调度窗口内, 对单次 ≤ 15s 的 10061 / SSL / Timeout 故障能完全自愈
**关注点**:
- 故障检测: 捕获 `urllib.error.URLError` / `HTTPError` 5xx/429
- 故障恢复: 指数退避 + jitter, ≤ 3 次重试
- 降级策略: 3 次后失败 → 日志 `[DEGRADED]`, exit 1, 下次 cron tick (30m 后) 重新尝试
- 日志告警: 重试用尽后写 `[DEGRADED]` 而非 `[ERR]`, 提示运维 "瞬时故障, 已自动降级, 下次 tick 恢复"

#### REQ-DFR-002: 持续故障不雪崩
**描述**: 当 GitHub 持续不可用时, 单次 cron tick 最多阻塞 ≤ 30 秒 (3 次重试 + 退避), 不阻塞后续 tick
**关注点**:
- 上限: 3 次重试 × (8+0.5)s 退避 ≈ 30 秒
- 超时: 每次 urlopen 仍走现有 `timeout=15` (已存在)
- 兜底: 30 秒后必然退出, 下一个 30 分钟 tick 接管

## 5. 影响范围分析

### 5.1 涉及的模块
| 模块 | 现有功能 | 新增/修改 |
|------|---------|-----------|
| `poll_issues.py` | `gh_api()` 直接调 GitHub API | modify — 增加重试包装 |
| `poll_issues.py` | `main()` 处理 HTTP 422 fallback | modify — 区分 422 (业务逻辑) vs 10061 (网络重试用尽) |
| `poll_issues.py` | `log()` GBK-safe 输出 | extend — 新增 `[RETRY]` / `[DEGRADED]` 标签 |
| `pm-01/.env` | 当前不含 retry 配置 | extend — 新增可选 `POLL_RETRY_MAX=3` / `POLL_RETRY_BASE_DELAY=2.0` (默认值, 可不填) |
| `tests/test_poll_issues.py` | (新增) | new — 单元测试覆盖 6 个场景 |

### 5.2 代码依赖分析
- 标准库依赖: `urllib.request`, `urllib.error`, `time`, `random`, `json`, `os`, `sys`, `pathlib`, `datetime`, `unittest.mock` (测试)
- 无新第三方依赖
- 现有 `hermes_constants` 依赖不变
- 现有 `.env` 加载逻辑 (`load_env()`) 复用, 仅增加两个新 key

## 6. 复杂度评估

### 6.1 评估结果
- **复杂度等级**: 简单
- **影响模块数**: 1 (`poll_issues.py` + 同目录测试)
- **架构变更**: 否
- **数据模型变更**: 否

### 6.2 跳过策略
| 制品 | 是否产出 |
|------|---------|
| proposal.md | 必须 ✅ (本文件) |
| delta-spec.md | 必须 ✅ |
| new-arch.md | 跳过 (无架构变更) |
| delta-design.md | 必须 ✅ (mod-design skill) |
| tasks.md | 必须 ✅ (aid-implementing skill) |
| design-review.md | 必须 ✅ (step9) |

## 7. 待解决问题
- 无 (本需求无待解决问题, 所有模糊点已在 §3.1 决策)
