# Task Router — Hermes AI Agent 抽象层

> 唯一目的是：**把"业务说我要做什么"和"调用哪个模型"解耦。**

## 一句话

业务代码不再关心"用哪个模型"，只声明 `task="review"` 等意图。
未来切换 MiniMax → Claude / Gemini / Ollama，只改 `TASK_MAP` 和 `litellm/config/`，**业务项目不动**。

## 怎么用

### 业务项目 import

```bash
# 系统级装（一次）
uv tool install --with litellm task-router   # 或者 pip install --user
```

或 **项目级**（更推荐）：

```bash
# 在 BioFLow 项目里加 path
export PYTHONPATH=~/infra:$PYTHONPATH
```

```python
from router.task_router import route_chat, chat

# 完整用法
resp = route_chat("review", [{"role": "user", "content": "看这段代码..."}])
print(resp.choices[0].message.content)

# 短用法（只要 content 字符串）
answer = chat("summarize", "下面这段论文摘要...", system_message="你是个学术助理")
```

### 列出所有 task

```bash
python -m hermes_router list
# 或者
python ~/infra/router/task_router.py list
```

会打印：
```
  review          alias=local        max_tokens=500   T=0.0  — 代码 Review / 行级反馈
  summarize       alias=fast         max_tokens=500   T=0.2  — 日志 / 注释 / 章节摘要
  architecture    alias=reasoning    max_tokens=2000  T=0.4  — 架构设计 / 模块边界
  ...
```

## 设计原则（不做什么）

| ❌ 不做 | 原因 |
|---|---|
| Agent / Planning | 已经有 Hermes / aider |
| Workflow orchestration | 已经有 Langfuse / cron |
| Memory / state | 跟具体业务有关 |
| Trace / 监控 | 留给 Litellm callback 或 Langfuse |
| 多个 model 选择（投票） | 简单优先，复杂需求留 Langfuse |

只做：把 task → (alias, max_tokens, temperature, retry)。

## 接入业务项目（3 步）

### Step 1 — 加 `register_task()`
在 BioFLow / AI Tutor 等项目里：

```python
# bioflow/llm/prompts/__init__.py
from hermes_router import register_task, RouteSpec

# 项目专属 task 覆盖
register_task("qc_step", RouteSpec(
    alias="local",
    max_tokens=500,
    temperature=0.0,
    description="QC 步骤的指导生成",
))
```

### Step 2 — 业务调用
```python
# bioflow/modules/qc/runner.py
from hermes_router import chat
hint = chat("qc_step", f"qc 的步骤：{qc_step}")
```

### Step 3 — 切模型时只改 litellm config
想把 `qc_step` 从 local 换成 cloud：
- 不改业务代码
- 改 `~/infra/router/task_router.py` 的 `TASK_MAP` 中 `qc_step` 别名
- 或者改 `~/infra/config/litellm.yaml` 的 `local` 别名映射

## 启动验证

```bash
# 确保 litellm gateway 已起
curl -s http://localhost:4000/health | head -3

# 试跑 task router smoke test
python ~/infra/router/test_router_smoke.py
```

预期：每条 task 都返回 200 + 真实内容。

## 已知限制

- **同步调用**（后续可加 async wrapper）
- **不流式**（`stream=True` 内部有支持，但业务项目不直接用）
- **不嵌入 multi-turn memory**（留给 Langfuse）
- **litellm SDK 必须装**：要么 pip / uv tool / pipx
