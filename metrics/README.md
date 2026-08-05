# AI Agent Metrics

> Agent 工作流的真实效率指标。**比 token 节省、RTK gain 重要得多。**

---

## 4 个核心指标

| 指标 | 测什么 | 怎么算 |
|---|---|---|
| **First-pass Success Rate** | a ider/task router 一次过的比例 | `first_pass / total * 100%` |
| **Avg Modifier Rounds** | 平均修改轮次（含 retry）| `Σrounds / total_tasks` |
| **Manual Intervention Count** | 需要人工改的次数 | 每次任务手动改 = 1 |
| **Wall-clock Time / Task** | 端到端耗时 | `end_time - start_time`（分钟） |

---

## 每周文件

每个周末建一份 `~/infra/metrics/YYYY-Wnn.md`（ISO 周编号）：

```
~/infra/metrics/
├── README.md          ← 本文件
├── 2026-W31.md        ← 本周（7月28日-8月3日）
├── 2026-W32.md
└── ...
```

### 模板字段（每周必填）

| 字段 | 填法 |
|---|---|
| 总任务数 | `total_tasks: N` |
| 一次过任务 | `first_pass: M` |
| 累计修改轮 | `total_rounds: K` |
| 人工干预次数 | `manual_interventions: P` |
| 总耗时（小时）| `wall_clock_hours: H` |
| 备注 | （失败 case / 思考 / 下周目标）|

自动算的指标：
- `first_pass_rate = first_pass / total_tasks`
- `avg_rounds = total_rounds / total_tasks`
- `intervention_rate = manual_interventions / total_tasks`

---

## 为什么比 token 数更重要

Databricks 文章核心：真正优化目标是 **"Cost per Successful Task"**，不是 token 数量。

token 便宜但任务失败率高 → 综合成本更高。
token 贵但一次成功 → 综合成本更低。

这 4 个指标直接量化"成本"，不靠感觉判断。

---

## 来源

- Hermes log 输出（task_router.py） 自动记录每次调用
- a ider session log（手动 / 自动）
- 用户每日填写

短期：**手动填写**（最干净）
长期：Task Router + Langfuse 自动采集

---

## 当前阶段

- 还没有 Langfuse → 手动跟踪
- 每周一遍足矣（不要每天填，琐事变负担）

下一周回看时，看 4 个指标是否都比**上一周**变好 → 体系真的 work
