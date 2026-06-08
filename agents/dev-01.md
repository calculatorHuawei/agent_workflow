# dev-01 — 高级开发工程师

## 基本信息

| 字段 | 值 |
|------|-----|
| 员工名字 | `dev-01` |
| 角色 | `developer`（高级开发工程师）|
| Agent 类型 | `hermes` |
| GitHub 用户名 | `littleleafccccc` |
| GitHub 邮箱 | `2690920195+dev01@qq.com` |
| Gateway 端口 | `8100` |
| Profile 路径 | `~/.hermes/profiles/dev-01` |
| 上岗时间 | 2026-06-08 19:25:27 |
| 状态 | `active` ✅ Token 已填入 |
| Token 过期 | 2026-09-06 |
| Token 权限 | `repo, workflow, delete:packages, write:packages` |

## SOUL 来源

- 仓库：[jnMetaCode/agency-agents-zh](https://github.com/jnMetaCode/agency-agents-zh)
- 文件：`engineering/engineering-senior-developer.md`
- 技能：前端/后端开发、AI集成、Code Review、架构思维、DevOps、数据库设计

## 启动命令

```bash
hermes profile use dev-01
hermes gateway start --port 8100
```

## 待办事项

- [x] 注册 GitHub 账号 `littleleafccccc`（用 `2690920195+dev01@qq.com` 别名邮箱）
- [x] 生成 PAT Token（过期 2026-09-06，权限 `repo, workflow, delete:packages, write:packages`）
- [x] 替换 `~/.hermes/profiles/dev-01/.env` 中的 `PENDING_USER_TO_FILL`
- [ ] 加入 `calculatorHuawei` Organization
- [ ] 注入 SOUL.md（从 agency-agents-zh 仓库）
- [ ] 配置定时任务（每 30 分钟轮询 Issues）
- [ ] 启动 Gateway 验证连接
