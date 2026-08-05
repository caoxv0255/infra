"""
Task Router — Hermes AI Agent 体系的薄抽象层

设计原则：
- 不做 Agent
- 不做 Workflow
- 不做 Planning / Memory / Tracing

只做一件事：

    task
     ↓
    model alias  +  temperature  +  max_tokens  +  retry policy
     ↓
    litellm SDK
     ↓
    LiteLLM Gateway :4000
     ↓
    真实模型

唯一入口是 `route_chat(task=..., messages=...)`。
未来切换 MiniMax → Claude / Gemini / 本地 Ollama，
只改 TASK_MAP 和 litellm config，业务代码不动。

依赖：
- litellm（已经 pip 装好）
- litellm Gateway 跑在 http://localhost:4000
"""
from __future__ import annotations

import os
import sys
import time
import logging
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

from litellm import completion


# === Logger ===
# 默认 INFO 级别；可设环境变量 HERMES_LOG=DEBUG 看更详细
logging.basicConfig(
    level=os.environ.get("HERMES_LOG", "INFO").upper(),
    format="%(asctime)s [%(levelname)s] hermes-router: %(message)s",
)
log = logging.getLogger("hermes-router")


LITELLM_BASE = os.environ.get("LITELLM_BASE_URL", "http://localhost:4000")
LITELLM_KEY = os.environ.get("LITELLM_API_KEY", "")  # LiteLLM 不校验业务侧 key


# ============================================================
# TASK_MAP — 业务代码只声明 task="review" 等意图，
#             不直接选模型。
# ============================================================

@dataclass
class RouteSpec:
    """一个 task 对应的路由配置"""
    alias: str            # litellm model alias（fast / coding / reasoning / ...）
    max_tokens: int       # 单次响应的 max_tokens
    temperature: float    # 0 = 严格；1 = 自由
    description: str      # task 的人类描述（doc 用）


# 默认 TASK_MAP。
# 业务代码可以：
#   1. import 后用默认值
#   2. 通过 register_task() 扩展 / 覆盖
TASK_MAP: Dict[str, RouteSpec] = {
    # === 代码相关（适合本地 Ollama / 便宜模型）===
    "review":          RouteSpec(alias="local",       max_tokens=500,   temperature=0.0,  description="代码 Review / 行级反馈"),
    "summarize":       RouteSpec(alias="fast",        max_tokens=500,   temperature=0.2,  description="日志 / 注释 / 章节摘要"),
    "log_explain":      RouteSpec(alias="local",       max_tokens=500,   temperature=0.0,  description="SQL explain / 日志解读"),
    "commit_msg":      RouteSpec(alias="fast",        max_tokens=200,   temperature=0.5,  description="git commit message"),

    # === 代码相关（适合强模型）===
    "code":             RouteSpec(alias="coding",      max_tokens=2000,  temperature=0.2,  description="生成 / 改写代码"),
    "debug":            RouteSpec(alias="reasoning",   max_tokens=2000,  temperature=0.2,  description="分析 bug 原因"),
    "refactor":         RouteSpec(alias="reasoning",   max_tokens=2000,  temperature=0.3,  description="代码重构建议"),
    "architecture":     RouteSpec(alias="reasoning",   max_tokens=2000,  temperature=0.4,  description="架构设计 / 模块边界"),
    "bug_analysis":     RouteSpec(alias="reasoning",   max_tokens=2000,  temperature=0.2,  description="分析 bug"),

    # === 文字 / 翻译（适合便宜模型）===
    "translate":        RouteSpec(alias="chinese",     max_tokens=1000,  temperature=0.3,  description="中英 / 英中翻译"),
    "extract":          RouteSpec(alias="fast",        max_tokens=1000,  temperature=0.0,  description="结构化抽取 (JSON / field)"),
    "format":           RouteSpec(alias="fast",        max_tokens=500,   temperature=0.0,  description="格式化（to JSON / to table）"),

    # === 长文 / 论文 / RAG（适合 Claude 推理）===
    "research":         RouteSpec(alias="reasoning",   max_tokens=2000,  temperature=0.4,  description="文献综述 / 跨论文综合"),
    "literature":       RouteSpec(alias="reasoning",   max_tokens=2000,  temperature=0.4,  description="学术任务 / paper critique"),
    "rag_query":        RouteSpec(alias="fast",        max_tokens=1000,  temperature=0.2,  description="RAG 检索 query 改写"),
    "paper_summary":    RouteSpec(alias="reasoning",   max_tokens=2000,  temperature=0.3,  description="论文单篇深度摘要"),

    # === 高风险决策 / 战略思考 ===
    "decision":         RouteSpec(alias="reasoning",   max_tokens=2000,  temperature=0.4,  description="投资 / 风险决策建议"),

    # === 默认 fallback ===
    "default":          RouteSpec(alias="fast",        max_tokens=500,   temperature=0.3,  description="未指定 task 时 fallback"),
}


def register_task(task: str, spec: RouteSpec) -> None:
    """动态注册 / 覆盖任务路由（用于项目级自定义）"""
    TASK_MAP[task] = spec


def resolve_route(task: str) -> RouteSpec:
    """获取 task 对应的路由；找不到返回 default"""
    return TASK_MAP.get(task, TASK_MAP["default"])


# ============================================================
# 入口 — 业务代码只调这个
# ============================================================

def route_chat(
    task: str = "default",
    messages: Optional[List[Dict[str, str]]] = None,
    *,
    max_tokens: Optional[int] = None,    # 覆盖 TASK_MAP 默认
    temperature: Optional[float] = None,
    stream: bool = False,
    extra_kwargs: Optional[Dict[str, Any]] = None,
) -> Any:
    """
    主入口。

    用法:
        from hermes_router import route_chat

        resp = route_chat("review", [
            {"role": "user", "content": "看一下这段 Python 代码哪里有问题..."}
        ])
        print(resp.choices[0].message.content)

    Args:
        task:        任务名 (review / summarize / architecture / ...)
                     自动决定 model alias + max_tokens + temperature
        messages:    chat 格式消息列表 [{role, content}, ...]
        max_tokens:  覆盖默认 max_tokens
        temperature: 覆盖默认 temperature
        stream:      是否流式
        extra_kwargs: 其他传给 litellm 的参数（如 top_p、tools 等）
    """
    if messages is None:
        raise ValueError("messages 不能为空")

    spec = resolve_route(task)
    log.info(
        f"route task={task} → alias={spec.alias} max_tokens={spec.max_tokens} T={spec.temperature}"
    )

    call_kwargs: Dict[str, Any] = {
        "model": spec.alias,
        "messages": messages,
        "max_tokens": max_tokens if max_tokens is not None else spec.max_tokens,
        "temperature": temperature if temperature is not None else spec.temperature,
        "api_base": LITELLM_BASE,
        "api_key": LITELLM_KEY,
    }
    if extra_kwargs:
        call_kwargs.update(extra_kwargs)

    if stream:
        call_kwargs["stream"] = True
        return completion(**call_kwargs)

    # retry 简单包一层（最多 2 次，覆盖网络瞬断）
    last_err = None
    for attempt in range(3):
        try:
            response = completion(**call_kwargs)
            if attempt > 0:
                log.info(f"task={task} 成功（重试 {attempt} 次后）")
            return response
        except Exception as e:
            last_err = e
            err_type = type(e).__name__
            err_msg = str(e)[:200]
            if attempt < 2:
                wait_s = 2 ** attempt  # 1s, 2s 退避
                log.warning(
                    f"task={task} attempt {attempt+1}/3 failed [{err_type}]: {err_msg} "
                    f"→ retry in {wait_s}s"
                )
                time.sleep(wait_s)
            else:
                log.error(f"task={task} attempt 3/3 failed [{err_type}]: {err_msg}")
    raise last_err  # type: ignore


# ============================================================
# 便利函数 — 跟 route_chat 同语义，更短
# ============================================================

def chat(task: str, user_message: str, system_message: Optional[str] = None, **kwargs) -> str:
    """最简用法：直接得 content 字符串"""
    msgs: List[Dict[str, str]] = []
    if system_message:
        msgs.append({"role": "system", "content": system_message})
    msgs.append({"role": "user", "content": user_message})
    resp = route_chat(task=task, messages=msgs, **kwargs)
    return resp["choices"][0]["message"]["content"]


def list_tasks() -> List[str]:
    """所有已注册的 task 名（业务项目方便 introspect）"""
    return sorted(TASK_MAP.keys())


# ============================================================
# CLI: python -m hermes_router list_tasks | cat <task>
# ============================================================

if __name__ == "__main__":
    import sys
    arg = sys.argv[1] if len(sys.argv) > 1 else "list"
    if arg == "list":
        for t in list_tasks():
            spec = TASK_MAP[t]
            print(f"  {t:14s}  alias={spec.alias:12s}  max_tokens={spec.max_tokens:<5d}  T={spec.temperature}  — {spec.description}")
    elif arg in TASK_MAP:
        spec = TASK_MAP[arg]
        print(f"task: {arg}")
        print(f"  alias:       {spec.alias}")
        print(f"  max_tokens:  {spec.max_tokens}")
        print(f"  temperature: {spec.temperature}")
        print(f"  description: {spec.description}")
    else:
        print(f"unknown task: {arg}", file=sys.stderr)
        print(f"可用 task: {', '.join(list_tasks())}", file=sys.stderr)
        sys.exit(1)
