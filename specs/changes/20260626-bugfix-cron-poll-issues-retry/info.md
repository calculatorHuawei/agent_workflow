# poll_issues.py 重试机制 - 代码仓理解

## 环境能力（来自 .claude/capabilities.json）
- 项目类型: HarmonyOS (但本 issue 实际涉及 hermes 数字员工基础设施, 非 opencalc 自身)
- 平台: Windows
- bundleName: com.darkempire78.opencalculator (opencalc app, 与本 issue 无直接关系)
- 编译命令: hvigorw --no-daemon assembleHap (与本 issue 无关, 不变更)
- 单元测试命令: hvigorw --no-daemon test (与本 issue 无关)
- UI 测试能力: true (hdc + 模拟器, 与本 issue 无关)
- 模拟器列表: ["127.0.0.1:5555"]
- hdc: D:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe
- **本 issue 真实环境**: Python 3.12 标准库 (`urllib`, `time`, `random`, `unittest.mock`) + Windows 计划任务, **不依赖** hvigor/hdc/DevEco

> 说明: capabilities.json 描述的是 calculatorHuawei 主项目 (HarmonyOS opencalc), 本 issue 修复的是 `~/.hermes/profiles/pm-01/scripts/poll_issues.py` (hermes 数字员工的 Python 脚本), 运行在 Windows 计划任务下, 调用 GitHub REST API。两者技术栈完全不同, capabilities.json 中的 hvigorw/hdc 仅供上下文参考, 本次改动**不使用**这些工具。

## 基本信息
- **需求类别**: 缺陷修复 (bugfix) — 网络故障重试
- **需求名称**: pm-01 cron poll_issues.py 网络故障重试与降级
- **分析时间**: 2026-06-26 16:13
- **分析范围**: `~/.hermes/profiles/pm-01/scripts/poll_issues.py` 单一文件 + 同目录新增测试文件

## 架构分析

### 涉及系统
本 issue 涉及**两个**独立系统:
1. **calculatorHuawei 主项目** (D:/huawei/Demo/calculatorHuawei) — HarmonyOS opencalc, 与本 issue **无关**
2. **hermes 数字员工基础设施** (C:\Users\26909\AppData\Local\hermes) — 本 issue **真正**涉及

### hermes profiles 目录结构
```
~/.hermes/
├── poll-{profile}.log          ← 所有 profile 共享的轮询日志
├── poll-arch-01.log
├── poll-default.log
├── poll-dev-01.log
├── poll-pm-01.log              ← 本 issue 关注
├── poll-rev-01.log
└── profiles/
    ├── pm-01/                  ← 本 issue 目标
    │   ├── .env                ← GITHUB_TOKEN, GITHUB_REPO
    │   ├── cron/jobs.json      ← cron 任务定义
    │   ├── scripts/
    │   │   └── poll_issues.py  ← 本 issue 修复目标
    │   └── ...
    ├── dev-01/scripts/poll_issues.py
    ├── rev-01/scripts/poll_issues.py
    ├── analysis/scripts/dispatch_analysis.py
    └── ... (其他 profile)
```

### 模块依赖
```
poll_issues.py
├── stdlib: urllib.request, urllib.error, json, time, random, os, sys, pathlib
├── hermes_constants (可选, 来自 hermes 框架)
└── .env (PM-01 profile)
```

无第三方依赖, 无 UI 组件, 无网络服务端口监听。

## 接口/契约识别

### 输入契约
- `gh_api(endpoint: str, token: str) -> dict` — 调用 GitHub REST API, 现有契约
  - `endpoint`: e.g. `/repos/my-ai-team/agent_workflow/issues?assignee=@me&state=open`
  - `token`: GITHUB_TOKEN, 来自 .env 或 process env
  - 返回: `dict` (解析后的 JSON)

### 输出契约
- 日志: UTF-8 写 `LOG_FILE` (含中文), ASCII 写 stdout (兼容 GBK 区域 cron capture)
- exit code: 0 成功, 1 失败 (由 hermes cron 任务消费)

### 错误契约 (当前)
- `urllib.error.HTTPError 422` → 走 fallback 路径 (`assignee=@me` → `state=open`), 不重试
- `urllib.error.HTTPError` 其他 → 记录 `[ERR]`, exit 1
- `urllib.error.URLError` (含 10061/SSL EOF) → 记录 `[ERR]`, exit 1, **不重试** ← 本 issue 修复点
- 其他 `Exception` → 记录 `[ERR]`, exit 1

## 公共组件或函数识别

### 可复用函数
- `log(msg: str)` — UTF-8 文件 + ASCII stdout 双写, 已被 `gh_api()` / `main()` / `load_env()` 共用, **无需修改**
- `load_env() -> dict` — 解析 .env, 已被 `main()` 调用, **仅需扩展读取 2 个新 key**

### 跨 profile 可复用
- `dev-01/scripts/poll_issues.py` / `rev-01/scripts/poll_issues.py` / `arch-01/scripts/poll_issues.py` 与 `pm-01/scripts/poll_issues.py` 结构高度相似 (80%+)
- **本期边界**: 仅修改 pm-01, 不动其他 profile (避免范围蔓延)
- **后续 issue 候选**: 把重试逻辑抽成 `~/.hermes/lib/retry_helper.py`, 所有 profile 共享

### 测试相关可复用
- Python 标准库 `unittest.mock` (mock `urllib.request.urlopen`)
- Python 标准库 `time.sleep` 可被 mock 加速测试
- 无现有 test_poll_*.py 参考, 需从零编写

## 影响范围分析

### 需要修改的文件
| 文件 | 变更类型 | 影响 |
|------|---------|------|
| `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\poll_issues.py` | modify | 新增 `_retry_with_backoff()`, 包装 `gh_api()` |
| `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\.env` | extend (可选) | 新增 `POLL_RETRY_MAX=3`, `POLL_RETRY_BASE_DELAY=2.0` (缺省即可) |
| `C:\Users\26909\AppData\Local\hermes\profiles\pm-01\scripts\test_poll_issues.py` | new | 6 个单元测试用例 |

### 不影响
- 其他 profile 的 poll_issues.py (dev-01/rev-01/arch-01)
- hermes 框架本身
- calculatorHuawei 主项目
- opencalc App

### 调用链
```
hermes cron (jobs.json) → Python 解释器 → poll_issues.py:main()
    → poll_issues.py:gh_api() → urllib.request.urlopen(https://api.github.com/...)
    → 解析 JSON → log() 写文件 + stdout
```

修改后:
```
hermes cron → poll_issues.py:main() → _retry_with_backoff(gh_api) → gh_api() → urllib
    ↑ 失败时退避 + 重试
```

## 现有代码分析

### 关键代码段
**`gh_api()` 当前实现** (poll_issues.py:74-85):
```python
def gh_api(endpoint: str, token: str) -> dict:
    url = f"https://api.github.com{endpoint}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github.v3+json",
        },
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())
```

**`main()` 当前错误处理** (poll_issues.py:100-125):
```python
try:
    data = gh_api(...)
    ...
except urllib.error.HTTPError as e:
    if e.code == 422:
        log(f"[WARN] @me 解析失败，改用 all issues")
        all_open = gh_api(...)  # ← 422 后又调一次, 同样无重试
        ...
    log(f"[ERR] HTTP {e.code}: {e.reason}")
    return 1
except Exception as e:
    log(f"[ERR] {e}")
    return 1
```

### 关键变量
- `LOG_FILE`: `~/.hermes/poll-pm-01.log` (全局, 跨 cron tick 累积)
- `PROFILE`: "pm-01"
- `ENV_FILE`: `~/.hermes/profiles/pm-01/.env`

### 边界条件
- 网络完全不可达 (10061) — 当前立即 exit 1
- TLS 握手失败 (SSL EOF) — 当前立即 exit 1
- 鉴权失败 (401) — 当前立即 exit 1 (应继续立即失败, 不可重试)
- 限流 (429) — 当前立即 exit 1 (应按 Retry-After 退避)

## 风险识别

### 技术风险
| # | 风险 | 等级 | 缓解 |
|---|------|------|------|
| 1 | 重试阻塞 cron tick 时间过长 | 中 | max_attempts=3 + base=2s → 最坏 14s 退避 + 3×15s 超时 = ~60s, 在 30 分钟 tick 内可接受 |
| 2 | 退避时与下次 cron tick 重叠 (如果 cron 自身无 jitter) | 低 | 单次退避最长 14s, 远小于 30 分钟 tick 间隔 |
| 3 | 重试风暴 (thundering herd) | 低 | 加 ±0.5s jitter |
| 4 | 401/404 等永久错误被重试 | 中 | 白名单: 仅 10061/SSL/Timeout/5xx/429 重试, 401/403/404/422 立即失败 |
| 5 | 修改影响其他 profile | 低 | 仅改 pm-01 副本, 不动其他 profile |
| 6 | poll-pm-01.log GBK 解码问题 | 低 | 沿用现有 log() 函数, 保持 UTF-8 写文件 + ASCII stdout |

### 业务风险
- pm-01 Issue Manager 任务中断时间缩短: 从 30 分钟 tick 失败 → 30s 内自愈
- 不影响 opencalc App 自身 (完全独立)

## 测试验证策略

### 测试场景
| # | 场景 | Mock 行为 | 预期 |
|---|------|----------|------|
| 1 | 200 OK | urlopen 成功一次 | 单次调用, 无重试 |
| 2 | 10061 → 200 | 第一次 URLError(10061), 第二次成功 | 重试 1 次后成功, log 含 [RETRY] |
| 3 | 10061 × 3 | 连续 3 次 URLError(10061) | 重试 2 次后失败 (max=3 = 1 原始 + 2 重试), log 含 [DEGRADED] |
| 4 | 401 | HTTPError(401) | 立即失败, 不重试, log [ERR] |
| 5 | 429 + Retry-After: 5 | HTTPError(429, headers={Retry-After: 5}) | 按 5s 退避, 1 次后成功 |
| 6 | 退避时间窗口 | mock time.sleep | 验证 [1.5, 2.5] / [3.5, 4.5] / [7.5, 8.5] |
| 7 | SSL EOF → 200 | 第一次 ssl.SSLEOFError, 第二次成功 | 重试 1 次后成功 |
| 8 | Timeout → 200 | 第一次 socket.timeout, 第二次成功 | 重试 1 次后成功 |

### 验证方法
- 本地: `python -m unittest scripts.test_poll_issues -v` (在 pm-01 profile 目录下)
- CI: 后续可集成到 hermes profile 自身的 test harness
- 端到端: 等待下次 cron tick (≤30 分钟), 观察 poll-pm-01.log 是否 [RETRY] 后成功

### 回归范围
- 现有 `main()` 行为不变 (除错误日志标签新增 [RETRY]/[DEGRADED])
- 现有 422 fallback 路径不变
- 现有 `log()` UTF-8/GBK 行为不变

## 监控运维支持

### 监控指标 (可选, 后续)
- `pm01_poll_success_total` (counter)
- `pm01_poll_retry_total` (counter, 按 reason 分桶)
- `pm01_poll_degraded_total` (counter)
- `pm01_poll_duration_seconds` (histogram)

### 配置清单
| 配置项 | 默认 | 范围 | 说明 |
|--------|------|------|------|
| `POLL_RETRY_MAX` | 3 | 0-10 | 最大重试次数, 0 = 关闭重试 |
| `POLL_RETRY_BASE_DELAY` | 2.0 | 0.1-30.0 | 退避基数 (秒), 第 N 次等待 `base * 2^(N-1) + jitter` |

### 日志记录点
| 标签 | 含义 | 何时出现 |
|------|------|---------|
| `[OK]` | 轮询成功 | 正常路径 |
| `[INBOX]` | 分配给 @me 的 issue 数量 | 正常路径 |
| `[REPO]` | 仓库 open issue 总数 | 正常路径 |
| `[WARN]` | @me 解析失败, 改用 all | 422 fallback |
| `[RETRY]` | 瞬时失败, 准备重试 | 新增 |
| `[DEGRADED]` | 重试用尽, 本次失败 | 新增 |
| `[ERR]` | 永久错误 (401/404/422) 或未捕获异常 | 永久失败 |

## 关键发现

### 可复用组件或函数
- `log()` 函数: GBK-safe 输出, 直接复用, 扩展标签
- `load_env()` 函数: .env 解析, 复用, 增加 2 个新 key
- `gh_api()` 函数: 内部被 `_retry_with_backoff()` 包装, 函数签名不变
- 标准库 `unittest.mock`: 写测试用

### 风险提示
- **同一脚本的变体散布在 5+ profile 中** (dev-01/rev-01/arch-01/pm-01/analysis), 本期仅修 pm-01, 后续应考虑提取到 `~/.hermes/lib/`
- **poll-*.log 长期累积** (`poll-pm-01.log` 已有 1100+ 行, 16KB+), 不在本次范围, 但建议后续加 log rotation
- **hermes cron 调度本身无 jitter**: 多 profile 同时触发时可能撞车, 但与本 issue 无关

### 建议事项
- **最小修改原则**: 本次仅改 pm-01, 不动其他 profile
- **测试可独立运行**: `python -m unittest scripts.test_poll_issues`, 不依赖 hermes
- **.env 变更向后兼容**: 缺省值兜底, 现有部署无需任何修改
- **不引入第三方依赖**: 仅用标准库, 避免污染 hermes profile 环境

### 测试能力评估
- 单元测试能力: ✅ (Python 标准库 unittest, 无外部依赖)
- UI 自动化测试能力: ✅ (但与本 issue 无关, hermes cron 是 Python, 非 UI)
- 端到端集成测试能力: ✅ (等待下次 cron tick, 观察日志)
- 不能跑的实际原因: 无, 本 issue 全部可在本地跑通
