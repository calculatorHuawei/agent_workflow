# 应用报告 (Apply Report)

## 应用信息
- **变更类型**: bugfix
- **变更名称**: cron-数据采集脚本连接失败-winerror-1006
- **Issue**: #30 [CRON] 数据采集脚本连接失败 - WinError 10061
- **关联特性**: feat-pm-01-cron
- **应用日期**: 2026-06-26 16:23
- **责任人**: dev-01 (claude -p 自动执行)
- **worktree**: D:\huawei\Demo\worktrees\issue-30
- **目标文件**: `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\poll_issues.py` (modify) + `test_poll_issues.py` (new) + `.env` (extend)

## 代码完成情况

| 任务 | 状态 | 完成时间 | 备注 |
|------|------|----------|------|
| Task 0.1 环境检查 | ✅ 完成 | 16:19 | Python 3.12.10, 标准库全 OK |
| Task 1.1 测试骨架 (RED) | ✅ 完成 | 16:20 | test_poll_issues.py (17 测试方法) |
| Task 1.2 验证 RED | ✅ 完成 | 16:20 | 12/17 FAILED (AttributeError: 缺新函数), 5/17 PASS (现有函数) |
| Task 2.1 _is_retryable (GREEN #1) | ✅ 完成 | 16:22 | HTTPError 必须先判 (URLError 子类) |
| Task 2.2 _get_retry_after (GREEN #2) | ✅ 完成 | 16:22 | 支持整数 Retry-After, HTTP-date 待后续 |
| Task 2.3 _retry_with_backoff (GREEN #3) | ✅ 完成 | 16:22 | 主循环 + 退避 + jitter + 日志 |
| Task 2.4 main() 集成 (GREEN #4) | ✅ 完成 | 16:22 | 替换 2 处 gh_api 调用 + .env 缺省值 |
| Task 3.1 重构常量 | ✅ 完成 | 16:22 | DEFAULT_RETRY_MAX / BASE_DELAY / JITTER / MIN_DELAY |
| Task 3.2 完善 docstring | ✅ 完成 | 16:22 | Google-style 完整 |
| Task 4.1 单元测试 | ✅ 完成 | 16:23 | **17/17 PASS** (0.011s) |
| Task 4.2 真实集成 | ✅ 完成 | 16:23 | `python poll_issues.py` 跑通, 7 issues 抓到, 422 fallback 工作 |
| Task 4.3 回归测试 | ✅ 完成 | 16:23 | 422 fallback / log() GBK-safe / 函数签名 全部保持 |
| Task 4.4 .env 注释 | ✅ 完成 | 16:23 | load_env() 正确跳过 # 注释行, POLL_RETRY_* 在 env dict 中 False |

**TDD 循环**: RED (12 fail) → GREEN (17 pass) → REFACTOR (无功能变化, 仍 17 pass)

## 测试结果
- **单元测试**: ✅ **17/17 通过** (0.011s)
- **集成测试**: ✅ **通过** (真实跑 python poll_issues.py, 7 issues 抓取, 422 fallback 工作, exit 0)
- **Lint 检查**: N/A (Python 脚本无 linter 配置, 仅做 py_compile + 人工 review)

## 测试详情

### 单元测试 (17/17 OK)
```
test_backoff_jitter_range ... ok
test_degraded_after_max_attempts ... ok
test_no_retry_on_401 ... ok
test_no_retry_on_404 ... ok
test_retry_on_10061_then_success ... ok
test_retry_on_429_with_retry_after ... ok
test_retry_on_5xx ... ok
test_retry_on_ssl_eof ... ok
test_retry_on_timeout ... ok
test_success_first_try ... ok
test_custom_retry_config ... ok
test_default_retry_config ... ok
test_poll_retry_max_zero ... ok
test_no_retry_on_422 ... ok
test_log_gbk_safe ... ok
test_gh_api_signature_unchanged ... ok
test_main_signature_unchanged ... ok

Ran 17 tests in 0.011s
OK
```

### 真实集成运行结果
```
[2026-06-26 16:23:39] [pm-01] ==================================================
[2026-06-26 16:23:39] [pm-01] ????  (= "开始轮询" GBK-safe)
[2026-06-26 16:23:40] [pm-01] [ERR] HTTP Error 422: Unprocessable Entity
[2026-06-26 16:23:40] [pm-01] [WARN] @me 解析失败, 改用 all issues
[2026-06-26 16:23:41] [pm-01] [REPO] 仓库 open 总数: 7
[2026-06-26 16:23:41] [pm-01]   #30 [CRON] 数据采集脚本连接失败 - WinError 10061 (assignees: ['littleleafccccc'])
[2026-06-26 16:23:41] [pm-01]   #29 中等模糊 (assignees: ['littleleafccccc', 'littleleafAnalysis'])
[2026-06-26 16:23:41] [pm-01]   #28 简单需求 (assignees: ['littleleafccccc'])
[2026-06-26 16:23:41] [pm-01]   #27 进阶 (assignees: ['littleleafccccc'])
[2026-06-26 16:23:41] [pm-01]   #25 中等模糊 (assignees: ['littleleafccccc'])
[2026-06-26 16:23:41] [pm-01]   #23 fix(merge): CalculatorPage.ets conflicts (assignees: [])
[2026-06-26 16:23:41] [pm-01]   #22 简单需求 (assignees: ['littleleafccccc'])
```
- exit 0 (成功)
- 422 走原 fallback 路径, 行为不变
- 7 个 open issues 全部抓到
- #30 已被 `littleleafccccc` assign (即本人)
- GBK-safe 输出 (中文 → `?` 在 stdout, 文件 UTF-8 完整)

### 关键设计点验证
| 设计点 | 验证方式 | 结果 |
|--------|---------|------|
| HTTPError 优先判 (URLError 子类) | test_no_retry_on_401 / 404 / 422 | ✅ 1 次调用即抛出, 不进重试 |
| 指数退避 + jitter | test_backoff_jitter_range | ✅ [1.5, 2.5] / [3.5, 4.5] / [7.5, 8.5] |
| 429 Retry-After 覆盖 | test_retry_on_429_with_retry_after | ✅ 退避 == 5.0, 不走指数 |
| [DEGRADED] 日志 | test_degraded_after_max_attempts | ✅ 重试用尽时写 1 次 [DEGRADED] |
| [RETRY] 日志 | 多个 test 输出验证 | ✅ `[RETRY] attempt=N/3 wait=X.Xs reason=...` |
| log() GBK-safe | test_log_gbk_safe + 集成运行 | ✅ UTF-8 文件 + ASCII stdout |
| gh_api / main 签名不变 | test_*_signature_unchanged | ✅ gh_api(endpoint, token) / main() |
| 422 fallback 保留 | 集成运行 | ✅ @me 失败 → 改用 all issues |
| .env 注释行 | test_default_retry_config + .env 追加 | ✅ load_env() 跳过 `#` 行 |
| POLL_RETRY_MAX=0 关闭重试 | test_poll_retry_max_zero | ✅ 1 次调用, 失败立即抛出 |

## 代码 diff 摘要

### poll_issues.py 变更
**新增 import**: `socket`, `ssl`, `time`, `random`, `urllib.error` (已有 urllib.request)
**新增常量** (模块顶部):
- `DEFAULT_RETRY_MAX = 3`
- `DEFAULT_RETRY_BASE_DELAY = 2.0`
- `RETRY_JITTER = 0.5`
- `MIN_DELAY = 0.5`
**新增函数** (gh_api 之后, main 之前):
- `_is_retryable(exc) -> bool` — 异常分类白名单
- `_get_retry_after(exc) -> Optional[float]` — Retry-After 头解析
- `_compute_delay(attempt, base_delay, retry_after) -> float` — 退避时间计算
- `_retry_with_backoff(fn, *args, max_attempts=3, base_delay=2.0, **kwargs)` — 主循环
**修改 main()**:
- 新增 4 行: 读取 `POLL_RETRY_MAX` / `POLL_RETRY_BASE_DELAY` (try/except 兜底)
- 替换 3 处 `gh_api(...)` 调用为 `_retry_with_backoff(gh_api, ...)`
- 其他逻辑不变 (422 fallback, 错误处理)

### test_poll_issues.py (新文件, 17 测试)
- 3 个 TestCase: TestRetryBackoff (10), TestEnvConfig (3), TestRegression (4)
- 使用 `unittest.mock` mock `urllib.request.urlopen`, `time.sleep`, `poll_issues.log`
- 完整覆盖: 200/10061/401/404/422/429/5xx/SSL/Timeout 9 种异常 + 退避 jitter + .env 配置 + 现有行为不变

### .env 变更
末尾追加 6 行注释 (均以 `#` 开头, load_env() 自动跳过):
```
# === 2026-06-26 Issue #30 retry mechanism ===
# 可选配置: 网络故障重试 (缺省走代码默认值)
# POLL_RETRY_MAX=3         # 最大尝试次数, 0=关闭重试 (回退到原始行为), 3=1 原始+2 重试
# POLL_RETRY_BASE_DELAY=2.0  # 退避基数 (秒), 第 N 次退避 = base * 2^(N-1) + jitter ±0.5s
# 重试白名单: URLError / SSL EOF / Timeout / HTTP 5xx / 429
# 不重试 (立即失败): 401 / 403 / 404 / 422
```

## 风险与回退

### 已识别风险 → 已缓解
- ✅ R1 重试阻塞 cron tick > 30s: max_attempts=3 + 退避封顶 8s → 最坏 30s
- ✅ R2 thundering herd: jitter ±0.5s
- ✅ R3 401/404 被错误重试: HTTPError 先判 (URLError 子类) + 白名单分类
- ✅ R4 .env 缺省值破坏兼容: 双 key 缺省 + try/except 兜底
- ✅ R5 poll-pm-01.log GBK 解码: 沿用现有 log() UTF-8/ASCII 策略

### 回退方案
- 若需回退: `git checkout HEAD -- poll_issues.py` (恢复原版, 约 129 行)
- 单元测试在 `test_poll_issues.py`, 可独立回退

## 下一步
- 真实运行验证: 等下次 cron tick (≤ 30 分钟), 观察 `~/.hermes/poll-pm-01.log` 是否包含 `[RETRY]` 标签
- 监控指标: 30 天后统计 `[RETRY]` / `[DEGRADED]` 出现频率, 评估自愈率 (KEI-RT-01 ≥ 80%)
- 后续 issue 候选: 把重试逻辑抽到 `~/.hermes/lib/retry_helper.py`, 同步应用到 dev-01 / rev-01 / arch-01 profile

## 收尾
- AID 制品清单 (在 worktree 内的 git 跟踪文件):
  - `proposal.md` ✅
  - `delta-spec.md` ✅
  - `info.md` ✅
  - `delta-design.md` ✅
  - `design-review.md` ✅
  - `todo.md` ✅
  - `tasks.md` ✅
  - `apply-report.md` ✅ (本文件)
- 实际代码改动 (在 hermes profile 目录, git 跟踪外):
  - `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\poll_issues.py` (modify)
  - `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\test_poll_issues.py` (new)
  - `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\.env` (extend 注释)
