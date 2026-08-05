# Hermes Infra 运维手册

> 记录 Day 1 当天踩过的坑。下次重启维护时请先扫本文档。

---

## 1. 当前架构

```
┌─────────────────────────────────────────────┐
│  Windows (Docker Desktop)                   │
│  └─ docker-desktop (WSL distribution)       │  ← 自管轻量 Linux 跑 daemon
│      └─ 容器 hermes-litellm                 │  ← 当前 phase 唯一容器
│          └─ 监听 127.0.0.1:4000             │
└─────────────────────────────────────────────┘
              ↑
              │ localhost 透传
              │
┌─────────────────────────────────────────────┐
│  WSL2 Ubuntu                                │
│  /home/cx/infra/                            │
│    ├─ docker-compose.yml                    │
│    ├─ config/litellm.yaml                   │  ← 5 个 capability alias
│    ├─ .env          (API key, 不进 git)      │
│    ├─ .env.example                          │
│    └─ ~/.hermes/litellm/access.log (容器内) │
└─────────────────────────────────────────────┘
```

**演进路线**（按触发条件）：

| Phase | 加什么 | 触发条件 |
|---|---|---|
| 1 (现在) | Litellm | — ✅ |
| 2 | + Redis | 需要 cache / rate limit / budget |
| 3 | + Langfuse | 需要调试 Agent 行为 / token 用量 |
| 4 | + Qdrant | 新项目需要 hybrid retrieval |

每次演进前 `docker compose down` + 加 service + `up`，不破坏现有。

---

## 2. 重启三件事（按破坏性从大到小）

### 2.1 完全重启（WSL 内会断 vscode ~30 秒）

**PowerShell 跑**：

```powershell
wsl --shutdown                       # 关 WSL 所有 distribution
Start-Sleep 5
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"  # 重启 Docker Desktop
Start-Sleep 30                       # 等 docker-desktop 自动起 daemon
wsl -l -v                            # 看: docker-desktop Running?
```

**预期信号**：`docker -l -v` 显示两行都是 `Running`。WSL 内 `/var/run/docker.sock` 自动重新挂载。

### 2.2 仅重启 daemon distribution（**不踢 vscode**）

```powershell
wsl -t docker-desktop
```

PowerShell 跑完后等 5 秒，Docker Desktop 主程序自动重启 `docker-desktop` distribution，**不影响 Ubuntu**（vscode 还连着）。**首选**这步。

### 2.3 仅重启 Litellm 容器（WSL 内）

```bash
cd /home/cx/infra
sg docker -c 'docker compose restart litellm'
```

容器 level 重启，配置改了之后用这个。

---

## 3. Docker Desktop 4 层 proxy（最容易踩的坑）

Docker Desktop 把 proxy 拆成**两段 + 一个 checkbox**，**四件事都要做**：

```
Settings → Resources → Proxies
```

| # | 字段 | 值 | 不配的后果 |
|---|---|---|---|
| 1 | **Docker Desktop proxy** → Proxy mode | Manual configuration | daemon 不能 pull image |
| 2 | Docker Desktop proxy → Web Server | `127.0.0.1` | daemon HTTP 出不去 |
| 3 | Docker Desktop proxy → Secure Web Server (HTTPS) | `127.0.0.1` | daemon HTTPS 出不去 |
| 4 | **Containers proxy** → Proxy mode | Manual configuration | 容器 HTTP 出不去 |
| 5 | Containers proxy → Web Server (HTTP) | `127.0.0.1` : `7897` | 容器 HTTP 出不去 |
| 6 | Containers proxy → Secure Web Server (HTTPS) | `127.0.0.1` : `7897` | **容器 HTTPS 出不去（GHCR 卡这里）** |

**端口**：Clash 默认 `7897`（HTTP/HTTPS 同一个端口）。如果用其他代理请相应替换。

**Apply & Restart 后**才能生效。

**任意一条漏配都会出现**：
- pull image 时 `unexpected EOF` 或 dial timeout
- 容器内 curl 失败
- 都不是错误信息直接指出来，得查 docker logs / Daemon diagnostics

---

## 4. 故障排查 Checklist

```
Symptom                              → First check
─────────────────────────────────────────────────────────────
docker: command not found             → Docker Desktop 没启 或 WSL integration 没勾
                                       (检查: Settings → Resources → WSL integration)
daemon IO error                       → wsl -t docker-desktop
sh: 1: docker: Input/output error     → docker-desktop distribution 卡死
                                       (检查: wsl -l -v 看是否 Stopped)
curl localhost:4000 → empty           → 看 docker compose ps / docker logs hermes-litellm
pull 反复 EOF (同 blob 不同时间)      → Containers proxy HTTPS 没配（看 §3）
chat 返回 401 Invalid API Key         → ~/infra/.env 里对应 key 没填/填错
chat 返回 "Invalid model name"        → model 字段没引 capability alias
aider 启动撞 API key 校验             → .env 里 OPENAI_API_KEY 是否被误清
                                       (其实是 dummy 即可，LiteLLM 不校验业务项目 key)
```

---

## 5. 重要文件位置

| 路径 | 用途 | 是否进 git |
|---|---|---|
| `~/infra/docker-compose.yml` | 容器编排 | 进 |
| `~/infra/config/litellm.yaml` | capability 路由 | 进 |
| `~/infra/.env` | API key 真实值 | **不**（在 .gitignore） |
| `~/infra/.env.example` | API key 模板 | 进 |
| `~/infra/README.md` | 用户文档 | 进 |
| `~/infra/CONFIG.md` | **本文件**，运维笔记 | 进 |
| `~/infra/pull.log` | 调试日志 | 不 |

---

## 6. 添加新 capability alias

`~/infra/config/litellm.yaml` 加一项：

```yaml
  - model_name: mytask                     # 别名
    litellm_params:
      model: anthropic/claude-sonnet-4-20250514
      api_key: os.environ/MY_NEW_KEY       # 从 ~/infra/.env 读
```

然后：

```bash
cd ~/infra
sg docker -c 'docker compose restart litellm'        # 重启容器
# 看 ~/.hermes/litellm/access.log 确认加载
sg docker -c 'docker compose logs --tail=20 litellm'
```

---

## 7. 业务项目接入 LiteLLM

```bash
# 项目 .env（关键三行）
OPENAI_API_BASE=http://localhost:4000/v1
OPENAI_MODEL=fast                         # 五个 alias 任选
OPENAI_API_KEY=dummy                      # dummy 即可，LiteLLM 不校验业务侧 key
```

具体每个项目该改什么文件 / 哪个 SDK 调用，扫完所有项目后我会做一次集中 patch（避免散乱修改）。

---

## 8. Day 1 真实执行总结（学习用）

完整跑下来踩过的坑顺序：

1. ❌ pipx install 'litellm[proxy]' → `proxy_server` 模块 import 失败（已知坑）
2. ❌ ghcr.io/berriai/litellm:main → 反复 EOF（GHCR CDN 经 Clash 链路不稳）
3. ❌ daocloud 中转 → 不镜像 GHCR，返回 403
4. ❌ Docker Desktop Apply & Restart → WSL integration 勾选被重置（已知行为）
5. ❌ vscode 连不上 → wsl.conf 错 / WSL 重启踢 vscode server
6. ❌ vscode WSL extension `WebSocket 1006` → 实际是 daemon socket 缺失拖累
7. ✅ Containers proxy HTTPS 补配 → pull 通，docker hub 上 `litellm/litellm:main-latest` 镜像到位
8. ✅ LiteLLM container 启动 + 5 alias 加载 + 真 chat 调通
