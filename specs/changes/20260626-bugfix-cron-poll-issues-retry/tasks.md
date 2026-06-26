# poll_issues.py 重试机制 开发任务

## 任务概述

- **功能名称**: pm-01 cron poll_issues.py 网络故障重试与降级
- **变更类型**: bugfix
- **关联特性**: feat-pm-01-cron
- **开发阶段**: Issue #30 修复
- **预计任务数**: 9 个 (含 6 个 TDD 测试任务)
- **预计总工作量**: 2-3 小时
- **责任人**: dev-01
- **TDD 模式**: ✅ 严格 RED → GREEN → REFACTOR

---

## 任务列表

### 阶段 0：环境检查

#### Task 0.1: 验证 Python 解释器与标准库可用性
**描述**: 在 pm-01 profile 目录下跑 `python --version` 确认 Python 3.x 可用; 跑 `python -c "import urllib, unittest, ssl, socket, random, time"` 确认无外部依赖
**涉及文件**: 无
**依赖任务**: 无
**估时**: 2 分钟
**验收标准**:
- [ ] `python --version` 输出 Python 3.x
- [ ] 标准库 import 全部成功
- [ ] 当前 `poll_issues.py` 可被 `python -m py_compile` 编译通过
- [ ] 当前 `python poll_issues.py` 跑通 (可能因网络失败, 但语法/import 无错)

---

### 阶段 1：TDD RED — 先写失败的测试

#### Task 1.1: 创建 test_poll_issues.py 测试骨架 (RED)
**描述**: 新建 `test_poll_issues.py`, 含 6 个测试方法, 每个测试 mock `urllib.request.urlopen` 模拟不同场景。所有测试初始应 FAIL (因 _retry_with_backoff 还不存在)
**涉及文件**:
- `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\test_poll_issues.py` (new)
**依赖任务**: Task 0.1
**估时**: 15 分钟
**验收标准**:
- [ ] 文件存在, 6 个 test_* 方法已写
- [ ] `python -m unittest test_poll_issues -v` 输出 "Ran 6 tests" 全部 FAILED
- [ ] 失败原因: `ImportError: cannot import name '_retry_with_backoff' from 'poll_issues'`
- [ ] 测试方法清单:
  - `test_success_first_try` (200 OK, 无重试)
  - `test_retry_on_10061_then_success` (10061 → 200, 重试 1 次)
  - `test_no_retry_on_401` (401 立即失败)
  - `test_retry_on_429_with_retry_after` (429 + Retry-After: 5)
  - `test_degraded_after_max_attempts` (连续 3 次 10061)
  - `test_backoff_jitter_range` (验证 [1.5, 2.5] / [3.5, 4.5] / [7.5, 8.5])
**TDD**: [x] RED

#### Task 1.2: 验证 RED 状态
**描述**: 跑 `python -m unittest test_poll_issues -v`, 确认 6 个测试全部 FAILED 且失败原因符合预期
**涉及文件**: 无
**依赖任务**: Task 1.1
**估时**: 2 分钟
**验收标准**:
- [ ] 6/6 tests FAILED
- [ ] 失败原因一致: ImportError 或 AttributeError
- [ ] 截图/log 保存到 `apply-report.md` RED 阶段

---

### 阶段 2：TDD GREEN — 实现核心功能

#### Task 2.1: 实现 _is_retryable 异常分类 (GREEN #1)
**描述**: 在 `poll_issues.py` 中新增 `_is_retryable(exc) -> bool` 函数。判定规则: URLError/ssl.SSLError/socket.timeout → True; HTTPError 5xx/429 → True; HTTPError 401/403/404/422/其他 → False; 其他 Exception → False
**涉及文件**:
- `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\poll_issues.py` (modify)
**依赖任务**: Task 1.2
**估时**: 10 分钟
**验收标准**:
- [ ] `_is_retryable` 函数已实现
- [ ] 单元测试 `test_no_retry_on_401` 通过
- [ ] 其他 5 个测试仍 FAILED (因 _retry_with_backoff 未实现)
- [ ] 函数有 docstring
- [ ] 不修改 gh_api() / main() / log() 现有函数
**TDD**: [x] GREEN (部分)

#### Task 2.2: 实现 _get_retry_after 头解析 (GREEN #2)
**描述**: 在 `poll_issues.py` 中新增 `_get_retry_after(exc) -> Optional[float]` 函数。从 HTTPError 响应头提取 `Retry-After` 字段并转为 float 秒数; 非 429 或无头则返回 None
**涉及文件**:
- `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\poll_issues.py` (modify)
**依赖任务**: Task 2.1
**估时**: 8 分钟
**验收标准**:
- [ ] `_get_retry_after` 函数已实现
- [ ] 处理整数 (如 "5") 和 HTTP-date 格式 (本设计只支持整数)
- [ ] 单元测试 `test_retry_on_429_with_retry_after` 部分通过 (退避逻辑待 Task 2.3 验证)
- [ ] 函数有 docstring
**TDD**: [x] GREEN (部分)

#### Task 2.3: 实现 _retry_with_backoff 主循环 (GREEN #3)
**描述**: 在 `poll_issues.py` 中新增 `_retry_with_backoff(fn, *args, max_attempts=3, base_delay=2.0, **kwargs)` 函数。包含: 退避计算 (算法 2), 主循环 (算法 3), 日志 [RETRY]/[DEGRADED] 标签, jitter, Retry-After 覆盖
**涉及文件**:
- `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\poll_issues.py` (modify)
**依赖任务**: Task 2.2
**估时**: 20 分钟
**验收标准**:
- [ ] `_retry_with_backoff` 函数已实现
- [ ] 6/6 单元测试全部通过 (`python -m unittest test_poll_issues -v`)
- [ ] 退避时间在 jitter 范围内 (测试已验证)
- [ ] 日志输出格式: `[RETRY] attempt=N/3 wait=X.Xs reason=...` 与 `[DEGRADED] retried N times, giving up: ...`
- [ ] 不可重试异常 (401/404) 不进入重试循环
- [ ] 函数有完整 docstring + 类型注解
**TDD**: [x] GREEN (完成)

#### Task 2.4: 修改 main() 调用方使用 _retry_with_backoff (GREEN #4)
**描述**: 在 `poll_issues.py` 的 `main()` 函数中, 把所有 `gh_api(...)` 调用改为 `_retry_with_backoff(gh_api, ...)`。读取新 .env 配置 `POLL_RETRY_MAX` (默认 3) 和 `POLL_RETRY_BASE_DELAY` (默认 2.0)
**涉及文件**:
- `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\poll_issues.py` (modify)
**依赖任务**: Task 2.3
**估时**: 10 分钟
**验收标准**:
- [ ] `main()` 中两处 `gh_api(...)` 调用 (assignee=@me + state=open fallback) 改为走 `_retry_with_backoff`
- [ ] `load_env()` 扩展读取 `POLL_RETRY_MAX` 和 `POLL_RETRY_BASE_DELAY`, 缺省走默认值
- [ ] `.env` 值类型转换有 try/except 兜底 (如 `int("abc")` 失败时用默认值)
- [ ] 现有 422 fallback 路径行为不变
- [ ] 现有 `log()` 调用不变 (不引入新参数)
- [ ] `python -m unittest test_poll_issues -v` 仍 6/6 通过
- [ ] 集成测试: `python poll_issues.py` 真实跑一次, 无论成功失败, 行为符合预期
**TDD**: [x] GREEN (完成)

---

### 阶段 3：TDD REFACTOR — 代码质量优化

#### Task 3.1: 提取常量 + 减少重复
**描述**: 把魔术数字 (0.5 jitter, 15s timeout, "POLL_RETRY_MAX" 等) 提取为模块级常量, 减少函数内重复
**涉及文件**:
- `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\poll_issues.py` (modify)
**依赖任务**: Task 2.4
**估时**: 8 分钟
**验收标准**:
- [ ] 顶部定义常量: `DEFAULT_RETRY_MAX = 3`, `DEFAULT_RETRY_BASE_DELAY = 2.0`, `RETRY_JITTER = 0.5`, `MIN_DELAY = 0.5`
- [ ] 6/6 单元测试仍通过
- [ ] 无功能变化 (仅重构)
- [ ] 集成测试: `python poll_issues.py` 真实跑一次仍成功
**TDD**: [x] REFACTOR

#### Task 3.2: 完善 docstring 与注释
**描述**: 为 `_retry_with_backoff`, `_is_retryable`, `_get_retry_after` 补全 docstring (Args/Returns/Raises/Examples), 为模块顶部加 usage 说明
**涉及文件**:
- `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\poll_issues.py` (modify)
**依赖任务**: Task 3.1
**估时**: 5 分钟
**验收标准**:
- [ ] 三个新函数都有 Google-style docstring
- [ ] 模块顶部 docstring 增加 "Changes: 2026-06-26 add retry mechanism (Issue #30)" 注释
- [ ] 6/6 单元测试仍通过
- [ ] `python -c "import poll_issues; help(poll_issues._retry_with_backoff)"` 输出正常
**TDD**: [x] REFACTOR

---

### 阶段 4：回归验证 + 集成验证

#### Task 4.1: 单元测试完整运行
**描述**: 跑完整测试套件, 确认 6/6 通过
**涉及文件**: 无
**依赖任务**: Task 3.2
**估时**: 2 分钟
**验收标准**:
- [ ] `python -m unittest test_poll_issues -v` 输出 "OK" (6/6 passed)
- [ ] 无 warning, 无 skip

#### Task 4.2: 真实集成运行
**描述**: 真实跑一次 `python poll_issues.py` (在 pm-01 profile 目录下), 观察是否能成功调 GitHub API 或按预期降级
**涉及文件**: 无
**依赖任务**: Task 4.1
**估时**: 5 分钟 (含脚本运行)
**验收标准**:
- [ ] 脚本无 Python 异常 (ImportError / SyntaxError / TypeError)
- [ ] 日志写入 `~/.hermes/poll-pm-01.log`, 含 `[pm-01]` 前缀
- [ ] stdout 含 ASCII 摘要 (兼容 GBK)
- [ ] 网络正常时: 看到 `[INBOX] ...` 或 `[REPO] ...` 日志, exit 0
- [ ] 网络异常时: 看到 `[RETRY] ...` 多次, 最终 `[DEGRADED] ...`, exit 1
- [ ] 422 时: 看到 `[WARN] @me 解析失败, 改用 all issues` 走 fallback, exit 0

#### Task 4.3: 回归测试 — 现有行为不变
**描述**: 验证本次修改不破坏现有功能
**涉及文件**: 无
**依赖任务**: Task 4.2
**估时**: 5 分钟
**验收标准**:
- [ ] `log()` 函数行为不变 (UTF-8 文件 + ASCII stdout)
- [ ] `load_env()` 函数签名不变 (现有调用方式仍工作)
- [ ] `gh_api()` 函数签名不变 (现有调用方式仍工作)
- [ ] 422 fallback 路径仍触发 (故意构造一个请求触发 422 验证)
- [ ] `.env` 缺省 `POLL_RETRY_*` 时, 默认值生效 (POLL_RETRY_MAX=3, BASE_DELAY=2.0)
- [ ] `POLL_RETRY_MAX=0` 时, 行为同当前 (不重试)

#### Task 4.4: 文档同步 (.env 注释)
**描述**: 在 pm-01 `.env` 文件末尾追加注释, 说明新增的可选配置
**涉及文件**:
- `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\.env` (extend, 加注释)
**依赖任务**: Task 4.3
**估时**: 2 分钟
**验收标准**:
- [ ] `.env` 末尾追加注释:
  ```
  # 2026-06-26 Issue #30 retry mechanism
  # POLL_RETRY_MAX=3        # 0=off, 3=1 original + 2 retries
  # POLL_RETRY_BASE_DELAY=2.0  # base seconds, exp backoff 2/4/8
  ```
- [ ] 注释行以 `#` 开头, `load_env()` 跳过
- [ ] 集成测试仍通过

---

## 开发顺序

```
Task 0.1 (环境检查)
    ↓
Task 1.1 (测试骨架) → Task 1.2 (验证 RED)
    ↓
Task 2.1 (_is_retryable)
    ↓
Task 2.2 (_get_retry_after)
    ↓
Task 2.3 (_retry_with_backoff) ← 6/6 GREEN
    ↓
Task 2.4 (main() 集成) ← 集成通过
    ↓
Task 3.1 (重构常量) → Task 3.2 (docstring)
    ↓
Task 4.1 (单测) → Task 4.2 (真实跑) → Task 4.3 (回归) → Task 4.4 (.env 注释)
    ↓
完成 → 进入 AID APPLYING 阶段
```

**关键路径**: 0.1 → 1.1 → 1.2 → 2.1 → 2.2 → 2.3 → 2.4 → 3.1 → 3.2 → 4.1 → 4.2 → 4.3 → 4.4

---

## 验收计划

| 任务 | 验收方式 | 验收时间 | DoD |
|------|---------|----------|-----|
| Task 0.1 | `python --version` + import 测试 | 即时 | Python 3.x, 标准库 OK |
| Task 1.1 | unittest 输出 6 FAILED | 即时 | 6/6 RED, 失败原因 = ImportError |
| Task 1.2 | 跑 + 截图 RED 状态 | 即时 | RED 状态确认 |
| Task 2.1 | unittest | 即时 | test_no_retry_on_401 通过 |
| Task 2.2 | unittest | 即时 | 函数实现 + 单元测试可调 |
| Task 2.3 | unittest 6/6 PASS | 即时 | 全绿, 日志格式正确 |
| Task 2.4 | unittest + 集成 | 即时 | 6/6 仍 PASS, 真实跑无异常 |
| Task 3.1 | unittest 6/6 | 即时 | 重构无功能变化 |
| Task 3.2 | help() 输出 | 即时 | docstring 完整 |
| Task 4.1 | unittest | 即时 | 6/6 通过 |
| Task 4.2 | python poll_issues.py 跑 | 即时 | 成功或按预期降级 |
| Task 4.3 | 422 触发测试 | 即时 | 现有行为不变 |
| Task 4.4 | .env 注释检查 | 即时 | load_env() 跳过注释行 |

---

## 风险与回退

### 风险
- **R1**: 集成到 main() 时改坏现有逻辑 → 解决: Task 4.3 强制回归
- **R2**: 退避时间超过 cron tick 间隔 → 解决: max_attempts=3 + base=2s = 14s 远小于 30m
- **R3**: .env 类型转换 ValueError → 解决: try/except 兜底用默认值
- **R4**: 修改影响其他 profile 的 poll_issues.py → 解决: 只改 pm-01 副本 (路径已限定)

### 回退方案
- 若 Task 4.x 验证失败: `git checkout HEAD -- poll_issues.py` 回到原版
- 单元测试发现 bug: 修代码或修测试, 重新走 GREEN → REFACTOR
- 不删除任何现有功能 (SR-RT-08)

---

## IMPLEMENTING 阶段完成

**产出物位置**: `D:/huawei/Demo/worktrees/issue-30/specs/changes/20260626-bugfix-cron-poll-issues-retry/tasks.md`

**任务列表**:
- Task 0.1: 环境检查
- Task 1.1: 测试骨架 (RED)
- Task 1.2: 验证 RED
- Task 2.1: _is_retryable (GREEN #1)
- Task 2.2: _get_retry_after (GREEN #2)
- Task 2.3: _retry_with_backoff (GREEN #3)
- Task 2.4: main() 集成 (GREEN #4)
- Task 3.1: 重构常量 (REFACTOR)
- Task 3.2: 完善 docstring (REFACTOR)
- Task 4.1: 单元测试
- Task 4.2: 真实集成
- Task 4.3: 回归测试
- Task 4.4: .env 注释

**开发顺序**: 0.1 → 1.1 → 1.2 → 2.1 → 2.2 → 2.3 → 2.4 → 3.1 → 3.2 → 4.1 → 4.2 → 4.3 → 4.4

**已通过 PLANNING + IMPLEMENTING, 进入 AID APPLYING 阶段。**
