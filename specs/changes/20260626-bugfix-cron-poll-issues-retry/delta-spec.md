# 需求SPEC v1.2 (Delta)

> 说明: 本文件为增量 SPEC, 仅描述本次需求 (poll_issues.py 重试机制) 相对基础功能的差异。基础功能在已有 poll_issues.py 脚本中已实现 (轮询 GitHub issues), 本 SPEC 聚焦"增加网络故障重试"这一增量。

---

## 系统背景

### 目的

> 用 ≤200 字描述：系统为谁解决什么问题，对应的业务目标/用户价值是什么。

为 pm-01 数字员工 (项目总管) 的 Issue Manager cron 任务增加**网络故障容错**能力。当调用 GitHub REST API 遭遇瞬时网络故障 (WinError 10061 / SSL EOF / Timeout / 5xx / 429) 时, 通过指数退避重试让 pm-01 在 ≤30s 内自愈, 避免单次网络抖动就丢失 30 分钟调度窗口的 issue 轮询。

业务价值: pm-01 自动 triage 能力恢复率从 0% (瞬时故障即失败) 提升到 ≥80% (重试覆盖), Issue #30 自身就是因为 poll 失败导致 pm-01 误判"自己无法工作"而产生的元 issue。

### 术语与缩写

| 术语/缩写 | 定义  |
| ----- | --- |
| pm-01 | 项目总管 hermes 数字员工 profile |
| cron tick | hermes cron 调度的单次执行 |
| 10061 | Windows WinError 10061 = "由于目标计算机积极拒绝, 无法连接" |
| SSL EOF | `SSL: UNEXPECTED_EOF_WHILE_READING` TLS 握手失败 |
| 429 | GitHub API 限流响应 (含 `Retry-After` 头) |
| jitter | 退避时间叠加的随机抖动, 避免 thundering herd |
| DEGRADED | 本次 tick 重试用尽, 降级到"等下次 tick" |

---

## 系统上下文

### 目标系统

| 字段                | 内容  |
| ----------------- | --- |
| 系统名称              | pm-01 Issue Manager (hermes cron) |
| 系统边界说明（内部/外部判定依据） | 内部: Python 脚本 `poll_issues.py`; 外部: GitHub REST API (`api.github.com`) |

### 周边交互方清单

| 编号    | 外部系统名称 | 类型（人/系统/服务/设备/协议栈） | 交互接口类型（API/协议/UI/SDK/Kit/设备接口/文件/其他） | 交互接口主要功能 |
| ----- | ------ | ------------------ | ------------------------------------ | -------- |
| ES-01 | GitHub REST API | 服务 | HTTPS (443) | 查询分配给 @me 的 open issues |
| ES-02 | Windows 计划任务 | 系统 | Task Scheduler | 每 30 分钟触发 cron tick |
| ES-03 | ~/.hermes/poll-pm-01.log | 文件 | log file | 累积轮询日志 (UTF-8) |

---

## 需求描述

| 需求编号 | 需求名称 | 需求描述 | 设计人员 |
| -------- | -------- | -------- | -------- |
| SR-RT-01 | gh_api 指数退避重试 | `gh_api()` 被 `_retry_with_backoff()` 包装, 瞬时网络故障时按 2^n 秒 + jitter 退避, 最多 3 次 | dev-01 |
| SR-RT-02 | 可重试错误白名单 | 仅对 URLError/SSL/Timeout/5xx/429 重试, 401/403/404/422 立即失败 | dev-01 |
| SR-RT-03 | 退避抖动 (jitter) | 第 N 次退避时间 = `base * 2^(N-1) + random.uniform(-0.5, 0.5)`, 最小 0.5s | dev-01 |
| SR-RT-04 | 429 遵守 Retry-After | 收到 HTTP 429 时按响应头的 `Retry-After` 值退避 | dev-01 |
| SR-RT-05 | .env 可选配置 | `POLL_RETRY_MAX` (默认 3) / `POLL_RETRY_BASE_DELAY` (默认 2.0) 支持 .env 覆盖 | dev-01 |
| SR-RT-06 | 可观察日志 | 新增 `[RETRY]` / `[DEGRADED]` 标签, 区分瞬时与持续故障 | dev-01 |
| SR-RT-07 | 单元测试 | 6 个 unittest 场景覆盖 200/10061/SSL/Timeout/5xx/429/401/422 | dev-01 |
| SR-RT-08 | 不破坏现有行为 | 422 fallback 路径、log() GBK-safe 输出、.env 解析逻辑保持不变 | dev-01 |

### 用户旅程

#### 旅程总览

| 旅程编号 | 旅程名称 | 目标用户/角色 | 旅程目标（G） | 触发与结束条件 | 关键体验路径（KEP-XXX） |
| ---- | ---- | ------- | ------- | ------- | --------------- |
| J-01 | 瞬时网络故障自愈 | hermes cron 调度器 | 30 分钟 tick 窗口内, 10061 ≤ 15s 故障自愈 | 触发: cron tick; 结束: 重试成功 / 降级 | KEP-RT-01, KEP-RT-02 |
| J-02 | 持续故障降级 | hermes cron 调度器 | 持续故障时, 单次 tick ≤ 30s 退出, 不阻塞下次 tick | 触发: 重试 3 次仍失败; 结束: 写 [DEGRADED] 日志并 exit 1 | KEP-RT-03 |

### 关键体验路径（KEP）

- **KEP-RT-01 (瞬时网络故障自愈)**:
  - 用户目标: 10061 故障 ≤ 15s 时, pm-01 自我恢复
  - 路径: cron tick → gh_api() → 10061 URLError → _retry_with_backoff() 退避 2±0.5s → 第二次 gh_api() 成功 → 写 [OK]
  - 体验预期: 单次 tick 总耗时 < 30s, [RETRY] 日志清晰, [INBOX] 数据完整

- **KEP-RT-02 (GitHub 限流自适应)**:
  - 用户目标: 429 响应时, 脚本按 Retry-After 退避
  - 路径: cron tick → gh_api() → 429 + Retry-After: 5 → _retry_with_backoff() 退避 5s → 第二次成功
  - 体验预期: 单次 tick 总耗时 ≈ 5s + 网络耗时, 不触发 60s/h 的硬限流

- **KEP-RT-03 (持续故障降级)**:
  - 用户目标: GitHub 持续不可用时, 不阻塞下次 cron tick
  - 路径: cron tick → gh_api() → 10061 → 退避 → 10061 → 退避 → 10061 → 写 [DEGRADED] → exit 1
  - 体验预期: 单次 tick 总耗时 ≤ 30s, 下次 30 分钟 tick 重新尝试

### 关键体验指标（KEI）

| 指标编号 | 指标名称 | 定义  | 底线值 | 达标值 | 挑战值 | 测量方法 |
| ---- | ---- | --- | --- | --- | --- | ---- |
| KEI-RT-01 | 单次 tick 自愈率 | (重试后成功的 tick) / (总 tick) | ≥ 60% | ≥ 80% | ≥ 95% | 统计 poll-pm-01.log 30 天 |
| KEI-RT-02 | 单次 tick P99 耗时 | 第 99 百分位 cron tick 总耗时 | ≤ 60s | ≤ 30s | ≤ 20s | 统计 poll-pm-01.log 时间戳差 |
| KEI-RT-03 | 退避精度 | 实际退避时间在 [target-0.5, target+0.5] 区间 | ≥ 90% | 100% | 100% | 单元测试 mock time.sleep |
| KEI-RT-04 | 重试不命中 401/404 | 永久错误未被重试 | 100% | 100% | 100% | 单元测试 |

### 假设和约束

| 序号 | 约束类别                       | 约束描述 | 对设计的影响 |
| ---- | ------------------------------ | -------- | ------------ |
| C-01 | 外部系统接口（兼容/对接）      | GitHub API 限流 60/h 匿名 / 5000/h 认证 | 30 分钟 tick 间隔足够, 单次重试 3 次后下次 tick 距离 29 分钟+ |
| C-02 | 硬件限制                       | Windows 计划任务, PowerShell 环境 | 不引入 Linux 专用工具 |
| C-03 | 标准/规范约束（必须遵从/禁用） | 复用现有 log() GBK-safe 约定 | 新增日志标签但不改 log() 函数签名 |
| C-04 | 其他硬约束                     | 不引入第三方依赖 (hermes profile 纯净) | 仅用 Python 标准库 |
| C-05 | 其他硬约束                     | 现有 422 fallback 路径必须保留 | `gh_api()` 内部不感知 422, 由 main() 处理 |
| C-06 | 其他硬约束                     | 单次 tick 总耗时 ≤ 60s (避免阻塞下次 tick) | 重试次数 × 退避时间 ≤ 30s |

---

## 场景用例分析

### 场景清单

| 场景编号 | 场景名称 | 场景要素覆盖 | 优先级 | 备注 |
| -------- | -------- | ------------ | ------ | ---- |
| SC-RT-01 | 瞬时 10061 故障自愈 | E (网络瞬时中断), G (自愈) | 高 | Issue #30 报告的故障模式 |
| SC-RT-02 | SSL EOF 故障自愈 | E (TLS 握手失败) | 中 | poll-pm-01.log 2026-06-11/14 多次出现 |
| SC-RT-03 | Timeout 故障自愈 | E (服务端慢) | 中 | poll-pm-01.log 2026-06-25 出现过 |
| SC-RT-04 | GitHub 5xx 自愈 | E (服务端异常) | 低 | GitHub SRE 概率低 |
| SC-RT-05 | GitHub 429 限流 | E (限流), G (自适应) | 中 | 必须按 Retry-After 退避 |
| SC-RT-06 | 401 鉴权失败 | E (token 失效), G (立即失败) | 高 | 重试无意义 |
| SC-RT-07 | 404 repo 错配 | E (配置错), G (立即失败) | 高 | 重试无意义 |
| SC-RT-08 | 422 @me 解析 | E (业务逻辑), G (fallback) | 高 | 现有行为, 不重试, 走 state=open |
| SC-RT-09 | 持续 10061 降级 | E (持续故障), G (降级 + 下次 tick) | 中 | 30s 内退出, 写 [DEGRADED] |

### 场景 SC-RT-01：瞬时 10061 故障自愈

#### 场景描述

> 一句话描述场景特征

Windows 网络栈在 ~5s 内瞬时不可用 (代理握手/防火墙/DNS 抖动), 第一次 `urllib.request.urlopen()` 报 WinError 10061, 第二次成功。

#### 场景要素分析

| 场景要素         | 取值  |
| ------------ | --- |
| **T** 生命周期阶段 | 正常运行期 |
| **G** 场景目标   | pm-01 cron 自愈, 不丢失本 tick 的 issue 轮询 |
| **E** 环境     | Windows + 偶发代理/防火墙抖动, api.github.com 偶发不可达 5s |
| **A** 参与者    | hermes cron 调度器, Windows 网络栈, GitHub API |
| **S** 系统状态   | 进程已启动, .env 已加载, 上一次 tick [OK] |

#### 用例识别

| 用例编号 | 用例名称 | 用例目的 | 用例描述 | 是否基础用例 |
| -------- | -------- | -------- | -------- | ------------ |
| UC-RT-01-01 | gh_api 指数退避重试 | 让单次 gh_api 调用在瞬时网络故障时自愈 | gh_api 被包装, 失败时按 2^n + jitter 退避后重试, 最多 3 次 | 是 |

#### 用例 UC-RT-01-01：gh_api 指数退避重试

##### 简要说明

`gh_api()` 现有签名保持不变 (`gh_api(endpoint, token) -> dict`), 内部被 `_retry_with_backoff()` 包装。所有调用方 (目前仅 `main()`) 无感知。

##### Actor

| 角色  | 类型（主/次，人/系统） | 与系统的关系 |
| --- | ------------ | ------ |
| hermes cron | 主, 系统 | 每 30 分钟触发 main() |
| urllib.request.urlopen | 主, 系统 | 实际发起 HTTPS 请求 |
| GitHub API | 主, 系统 | 响应端 |
| log() | 次, 系统 | 记录 [RETRY] / [DEGRADED] / [OK] |

##### 前置条件

| 场景要素         | 本用例采用的取值 | 对用例的影响点 | 处理方式 |
| ------------ | ---------- | ------------ | ------- |
| **T** 生命周期阶段 | 正常运行 | 无 | 保持 |
| **G** 场景目标   | 瞬时故障自愈 | 决定重试上限 | 扩展: max_attempts=3 |
| **E** 环境     | 偶发网络中断 | 决定退避策略 | 扩展: 指数退避 + jitter |
| **A** 参与者    | 系统 | 无 | 保持 |
| **S** 系统状态   | 正常 | 无 | 保持 |

##### 最小保证

- 重试时不能阻塞 cron tick 超过 30s
- 重试失败必须写日志, 不能静默

##### 成功保证（后置条件）

- 网络恢复后, gh_api 成功返回, main() 走正常 [INBOX] / [REPO] 路径
- 日志中含 [RETRY] 标签 (重试发生) 和 [OK] 标签 (最终成功)

##### 触发事件

`urllib.error.URLError` 异常抛出, error code 10061 / SSL EOF / socket.timeout

##### 主成功路径（基本事件流）

```
1. main() 调用 gh_api("/repos/.../issues?assignee=@me&state=open", token)
2. _retry_with_backoff 调用 gh_api() 第 1 次
3. urlopen 抛 URLError(10061)
4. _retry_with_backoff 捕获, 判定为可重试, log "[RETRY] attempt=1/3 wait=2.0s"
5. time.sleep(2.0 + random.uniform(-0.5, 0.5))
6. _retry_with_backoff 调用 gh_api() 第 2 次
7. urlopen 成功
8. 解析 JSON 返回 dict
9. main() 走正常路径, log "[INBOX] ..."
10. exit 0
```

##### 扩展路径

```
3a. 第 1 次 401 Unauthorized
    → 判定为不可重试, log "[ERR] HTTP 401: Unauthorized"
    → 抛出 HTTPError, 由 main() 捕获, exit 1
3b. 第 1 次 429 Too Many Requests + Retry-After: 5
    → 判定为可重试, log "[RETRY] attempt=1/3 wait=5.0s (from Retry-After)"
    → time.sleep(5.0)
    → 第二次成功
3c. 连续 3 次 URLError(10061)
    → 第 3 次后 log "[DEGRADED] retried 3 times, giving up"
    → 抛出最后一次 URLError, 由 main() 捕获, exit 1
3d. POLL_RETRY_MAX=0 (关闭重试)
    → 第一次失败立即抛出, 不重试
```

##### 功能图(可选)

> （无, 单一函数包装）

##### DFX 属性

| DFX 属性                      | 是否涉及 | 要求（可验证表述） |
| ----------------------------- | -------- | ------------------ |
| 性能（时延/吞吐/并发）        | 是 | 单次 tick P99 ≤ 30s (KEI-RT-02) |
| 可靠性（故障恢复/数据一致性） | 是 | 10061 ≤ 15s 自愈率 ≥ 80% (KEI-RT-01) |
| 安全                          | 否 | token 仍在 log() 之外, 不变更 |
| 隐私                          | 否 | 不涉及 |
| 韧性                          | 是 | 持续故障 30s 内降级, 不阻塞下次 tick (REQ-DFR-002) |
| 可服务性                      | 是 | [RETRY]/[DEGRADED] 标签便于运维定位 |
| 可测试性                      | 是 | 单元测试覆盖 6 个场景 (SR-RT-07) |
| 兼容性                        | 是 | .env 缺省值兜底, 向后兼容现有部署 (SR-RT-08) |

##### 业务威胁建模需求（消减措施清单，可选）

| 措施编号  | 适用场景/用例步骤 | 风险/威胁面（简述） | 消减措施（可验证表述） | 关联数据/接口 | 验证方式（测试/审计/评审） |
| ----- | --------- | ---------- | ----------- | ------- | -------------- |
| TM-01 | 步骤 3 | 重试风暴: 多 profile 同时触发 + 同时重试撞 GitHub | jitter ±0.5s 错峰 | github_api | 单元测试 KEI-RT-03 |
| TM-02 | 步骤 3c | 持续故障阻塞 cron tick | max_attempts=3 + 退避封顶 8s → 最坏 30s | poll_issues.py | 单元测试 KEI-RT-02 |

##### 可靠性分析需求（FMEA 消减措施清单，可选）

| 异常事件编号 | 异常事件（Actor/环境/系统状态） | 影响（对目标/数据/可用性） | 消减措施（可验证表述） | 触发检测/告警/日志要求 | 恢复与兜底（最小保证对齐） |
| ------ | ------------------- | -------------- | ----------- | ------------ | ------------- |
| FM-01 | WinError 10061 瞬时中断 | 单 tick 数据丢失 | 指数退避重试 3 次, 30s 内自愈 | log [RETRY] | 30s 内 exit 0, 数据不丢失 |
| FM-02 | SSL: UNEXPECTED_EOF_WHILE_READING | TLS 握手失败 | 重试, 同 FM-01 | log [RETRY] | 同 FM-01 |
| FM-03 | socket.timeout (15s) | 服务端慢 | 重试 | log [RETRY] | 同 FM-01 |
| FM-04 | HTTP 5xx | 服务端异常 | 重试 | log [RETRY] | 同 FM-01 |
| FM-05 | HTTP 429 + Retry-After | 限流 | 按 Retry-After 退避 | log [RETRY] | 1 次重试后大概率成功 |
| FM-06 | HTTP 401/403/404/422 | 永久错误 | 不重试, 立即失败 | log [ERR] | main() exit 1, 下次 tick 仍然失败 (需人工介入 token 修复) |
| FM-07 | 持续网络不可用 (10 分钟) | 数据延迟 ≥ 30 分钟 | max_attempts=3 封顶, 30s 内退出 | log [DEGRADED] | 下次 30 分钟 tick 重试 |
| FM-08 | GitHub API 整体故障 | 全部 issue 抓取延迟 | 退避 + 下次 tick 接管 | log [DEGRADED] | 不阻塞下次 tick |

##### 验证达成标准

| 编号 | 标准 |
|------|------|
| AC-01 | 单次 10061 → 重试 1 次后成功, poll-pm-01.log 含 [RETRY] + [OK] |
| AC-02 | 连续 3 次 10061 → 重试 2 次后失败, log 含 [DEGRADED], exit 1 |
| AC-03 | 401 → 立即失败, 不重试, log [ERR] |
| AC-04 | 429 + Retry-After: 5 → 按 5s 退避 |
| AC-05 | POLL_RETRY_MAX=0 → 不重试, 行为同当前 |
| AC-06 | 6 个单元测试全部通过 |

##### 是否影响架构

| 是否影响 | 影响范围 | 影响类型 | 影响描述 |
| ---- | ---- | ------------------------------ | ---- |
| 否 | - | - | 仅修改单文件单一函数, 不影响架构 |

##### 功能影响列表

| 功能编号 | 功能描述 | 影响类型（新增/修改/删除） | 影响描述（详细变更点） |
| ---- | ---- | -------------- | ----------- |
| F-RT-01 | _retry_with_backoff 包装器 | 新增 | 新增内部函数, 包装 gh_api() |
| F-RT-02 | gh_api 函数体 | 修改 | 不修改函数签名, 仅调用方改为走 _retry_with_backoff |
| F-RT-03 | log 标签 | 扩展 | 新增 [RETRY] / [DEGRADED] |
| F-RT-04 | .env 解析 | 扩展 | 读取 POLL_RETRY_MAX / POLL_RETRY_BASE_DELAY |
| F-RT-05 | 单元测试 | 新增 | 新增 test_poll_issues.py |

##### 需求分解列表（IR → SR）

| IR 编号 | SR 编号 | SR 名称 | SR 描述 | 关联功能 | 关联功能编号 |
| ----- | ----- | ----- | ----- | ---- | ------ |
| IR-RT-01 | SR-RT-01 | gh_api 指数退避重试 | gh_api 被 _retry_with_backoff 包装, 最多重试 3 次 | _retry_with_backoff | F-RT-01 |
| IR-RT-02 | SR-RT-02 | 可重试错误白名单 | 仅 URLError/SSL/Timeout/5xx/429 重试, 401/403/404/422 立即失败 | _retry_with_backoff | F-RT-01 |
| IR-RT-03 | SR-RT-03 | 退避抖动 | base * 2^(N-1) + random(-0.5, 0.5) | _retry_with_backoff | F-RT-01 |
| IR-RT-04 | SR-RT-04 | 429 Retry-After | 收到 429 时按响应头退避 | _retry_with_backoff | F-RT-01 |
| IR-RT-05 | SR-RT-05 | .env 可选配置 | POLL_RETRY_MAX / POLL_RETRY_BASE_DELAY | load_env | F-RT-04 |
| IR-RT-06 | SR-RT-06 | 可观察日志 | [RETRY] / [DEGRADED] 标签 | log | F-RT-03 |
| IR-RT-07 | SR-RT-07 | 单元测试 | 6 个 unittest 场景 | test_poll_issues.py | F-RT-05 |
| IR-RT-08 | SR-RT-08 | 不破坏现有行为 | 422 fallback / log() / load_env 签名不变 | gh_api / main | F-RT-02 |

---

## 系统需求列表（SR）

| SR 编号 | IR 编号 | SR 名称 | SR 描述（What） | 关联功能 | 利益相关者（who） | 系统对外能力行为（what） | 其他 5W2H（可选） | 关联用例/场景 | 可验证达成标准 | 优先级（高/中/低） | 需求来源 |
| ------- | ------- | ------- | --------------- | -------- | ----------------- | ------------------------ | ----------------- | ------------- | -------------- | ------------------ | -------- |
| SR-RT-01 | IR-RT-01 | gh_api 指数退避重试 | gh_api 被 _retry_with_backoff 包装, 最多重试 3 次, base=2s | F-RT-01 | pm-01 数字员工 | 当 gh_api 抛可重试异常时, 退避后重试 | Where: poll_issues.py; When: gh_api 失败时 | UC-RT-01-01 | AC-01, AC-02 | 高 | Issue #30 |
| SR-RT-02 | IR-RT-02 | 可重试错误白名单 | URLError/SSL/Timeout/5xx/429 重试; 401/403/404/422 立即失败 | F-RT-01 | pm-01 数字员工 | 异常分类白名单 | When: 异常抛出时 | UC-RT-01-01 / 3a | AC-03 | 高 | Issue #30 |
| SR-RT-03 | IR-RT-03 | 退避抖动 | base * 2^(N-1) + random(-0.5, 0.5) | F-RT-01 | pm-01 数字员工 | 退避时间随机化 | - | UC-RT-01-01 | KEI-RT-03 | 中 | 最佳实践 |
| SR-RT-04 | IR-RT-04 | 429 Retry-After | 按响应头 Retry-After 退避 | F-RT-01 | pm-01 数字员工 | 尊重 GitHub 限流策略 | - | UC-RT-01-01 / 3b | AC-04 | 中 | GitHub API 规范 |
| SR-RT-05 | IR-RT-05 | .env 可选配置 | POLL_RETRY_MAX=3 / POLL_RETRY_BASE_DELAY=2.0 | F-RT-04 | 运维 | 可调参不破坏部署 | - | - | AC-05 | 中 | 可配置性 |
| SR-RT-06 | IR-RT-06 | 可观察日志 | [RETRY] / [DEGRADED] 标签 | F-RT-03 | 运维 | 区分瞬时与持续故障 | - | UC-RT-01-01 | 单元测试 | 中 | 可观测性 |
| SR-RT-07 | IR-RT-07 | 单元测试 | 6 个 unittest 场景 | F-RT-05 | dev-01 | 回归保护 | - | - | AC-06 | 高 | TDD |
| SR-RT-08 | IR-RT-08 | 不破坏现有行为 | 422 fallback / log() / load_env 签名不变 | F-RT-02 | 现有部署 | 向后兼容 | - | SC-RT-08 | 单元测试 | 高 | 兼容性 |
