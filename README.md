# Hermes Infra — 基础设施层

> 长期演进的家。

## 当前内容（Phase 1，最小版）

只起一个 LiteLLM Gateway，统一 6 个项目的 LLM 调用入口。

```
infra/
├── docker-compose.yml          # LiteLLM 容器
├── config/litellm.yaml         # capability 路由配置
├── .env.example                # 环境变量模板（提交 git）
├── .env                        # 真实 key（不提交）
├── .gitignore
└── README.md
```

## 启动

```bash
# 1. Docker Desktop 已在 Windows 端启动，并已开启 WSL Integration（一次性）
# 2. 填好 .env
cp .env.example .env
$EDITOR .env

# 3. 启动
cd ~/infra
docker compose up -d

# 4. 验证
curl http://localhost:4000/health
curl http://localhost:4000/v1/models          # 应返回 5 个 capability alias
```

## 演进路线（按触发条件）

| Phase | 加什么 | 触发条件 |
|---|---|---|
| 1 (现在) | LiteLLM | — |
| 2 | + Redis | 需要 cache / rate limit / budget |
| 3 | + Langfuse | 需要调试 Agent 行为 / token 用量 |
| 4 | + Qdrant | 新项目需要 hybrid retrieval |
| 5 | + Postgres | 需要共享数据（如跨项目 RAG） |

每次演进先 `docker compose down`，加 service，up 一次完成，不破坏现有服务。

## 接入业务项目

每个项目的 `OPENAI_BASE_URL` 改成：

```
http://localhost:4000/v1
```

Model 字段引 5 个 capability alias 任一：

- `fast` —— 默认（MiniMax-M3）
- `reasoning` —— 复杂推理（Claude）
- `chinese` —— 中文生成（Qwen-Max）
- `coding` —— 代码任务（DeepSeek）
- `vision` —— 多模态（Qwen-VL-Max）

切换厂商只改 `config/litellm.yaml`，不动业务代码。

## 停止

```bash
cd ~/infra
docker compose down          # 停止并删容器（保留镜像）
# 或
docker compose down --rmi all # 完全清理
```

## 日志与排错

```bash
docker compose logs -f litellm
docker exec -it hermes-litellm cat /app/config.yaml
curl -v http://localhost:4000/v1/models | jq .
```
