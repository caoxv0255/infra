# 下一步路线 / 观察清单（2026-07-30 起，一周观察期）

> 原则：**先稳定 → 再观测 → 最后优化**
> 不要急着装新组件。每加一层复杂度就先回答："它能告诉我什么我现在不知道的事吗？"

---

## 这一周（Day 6+）该做的事

### 1. 验证 local alias 链路（15 分钟，今天做）

```bash
bash ~/infra/restart-litellm.sh           # 重启 Litellm 让 config 加载
bash ~/infra/validate-local-alias.sh       # 验证 model="local" 实际调通 Ollama
```

预期看到：
```
=== 1) LiteLLM 别 alias 列表 ===
  - fast
  - reasoning
  - chinese
  - coding
  - vision
  - local     ← 已加载

=== 3) 用 LiteLLM 'local' alias 跑一个最小 chat ===
REPLY: 'ollama-ok'
```

### 2. 把 BioFLow 切到 LiteLLM（30 分钟）

BioFLow 当前直接走 `bioflow/llm/providers.py`（Ollama 单独配置）。改成：
- base_url → `http://localhost:4000/v1`
- model → `local`

具体改完后跑一次 BioFLow pipeline 验证。

### 3. 让 LiteLLM 自然跑一周（不需要做事）

- 你日常会触发 LiteLLM 调用（aider、题库分析 pipeline、未来 BioFLow）
- `~/.hermes/litellm/access.log` 自然积累
- 自己估计调用频率：今天大约 X 次

### 4. RTK baseline 一周后看

```bash
rtk gain   # 一周后看真实数据
```

**判断标准**：
- 节省 > 10% token / ¥50+ → 保留
- 节省 < 5% → 卸 RTK（plug-in 卸载 = `rtk init --agent hermes --global` 反向）

---

## 一周后回来的判断项

| 观察项 | 该看什么 | 该决定什么 |
|---|---|---|
| RTK gain 数据 | saved % 是否 ≥ 5% | 是 → 留 / 否 → 卸 |
| LiteLLM 调用分布 | "local" 用了多少次 vs cloud | 是否要把 alias 默认改成 local |
| BioFLow 切走后 | 跑一次完整 pipeline | latency / 质量是否 ok |
| 题库分析 CI | 改 .github/workflows 后第一次 push | 测试能否通过 |

---

## 一周后才考虑：Langfuse（按触发条件）

**装 Langfuse 的真实条件**：

```
日均调用  > 50 次（自然积累，非 forced）
日志开始混杂   （>5 alias 在用 + 用户加 key 了）
Token 异常   （某 task 突然贵了）
失败率上升   （某 alias 健康状态变红）
```

满足 **任一** 再装。**不预先装**。

如果一周后 LiteLLM 日均 < 10 次调用 → Langfuse 完全不需要。

---

## 永远不做的（已删除）

按你的判断：

- ❌ Neo4j —— 6 个项目都没到那个量级
- ❌ MCP Profile（research/coding/invest）—— 现代 Agent 框架 dynamic tool selection 已替代
- ❌ Multi-Subagent（Research/Coding/Risk/Decision）—— Task Router 一层足够
- ❌ Continue.dev Index / Tree-sitter 自动化 —— 当前手动搜已够
- ❌ Semantic Cache（如 GPTCache）—— 真实模式出现再上

---

## 短期 P0 阶段剩余（P2 候选）

按触发条件再上：

| 项 | 触发条件 |
|---|---|
| 投资 DuckDB | InvestHelper 处理 > 10MB CSV / 时间序列计算 |
| BioFLow Cross-project RAG | 跨项目联合文献分析的需求 |
| Semantic Cache | RTK / Langfuse 数据表明 "review / rename / explain pattern" 重复 ≥ 30% |

---

## 自我约束

> **加任何组件前问自己 3 个问题**：
>
> 1. 没有它之前我没解决的痛点是什么？
> 2. 它的 ROI 在我当前的使用量上是否真的正？
> 3. 我有一周以上数据支撑这个决定吗？
>
> 三个都答不上 → 暂缓。

---

## 文件快速索引

```
~/infra/
├── docker-compose.yml          # 容器编排
├── config/litellm.yaml         # 5+1 个 capability alias
├── .env                        # OPENAI_API_KEY（DASHSCOPE 等 4 alias 待配）
├── CONFIG.md                   # Docker 4 层 proxy 经验
├── WSL-HEALTH-CHECK.md         # PATH 健康报告
├── fix-wsl-path.sh             # PATH 清理脚本（dry-run default）
├── restart-litellm.sh          # 重启 Litellm + 列 aliases
├── validate-local-alias.sh     # 验证 'model=local' 真走 Ollama
├── PHASE-NEXT.md               # 本文件
└── ZOTERO-DAY4.md              # Zotero 操作清单
```
