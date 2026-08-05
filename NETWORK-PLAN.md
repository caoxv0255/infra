# 网络层执行计划 v5（2026-08-04）

> v1: 3 方案对比
> v2: 执行计划（Day 1-3 行动）
> v3: 改"加路由不删 default"
> v4: 能力检测脚本 + 状态确认
> **v5: 当前**——Day 1 收尾 + 立即做 .devcontainer 模板

---

## 0. Day 1 已收尾

| 任务 | 状态 | 证据 |
|---|---|---|
| Day 0 `network-status.sh` | ✅ | 5 section 系统化观测 + baseline 留底 |
| Day 1 `vpn-route-check.sh` | ✅ | 实测跑通 |
| Day 1 `vpn-school-on.sh` v4.2 | ✅ | TCP 22 + UIBE 路由 + SSH auth 三项 OK |
| Day 1 `vpn-normal-on.sh` v4 | ✅ | 状态确认（kernel 自动清路由）|
| ssh -vvv 调试 | ✅ | 7 层全通（KEX + host key + RSA auth + whoami）|
| GitHub repo | ✅ | `git@github.com:caoxv0255/infra` |
| 第一次 commit + push | ✅ | `1e3a73b feat: bootstrap infra/ as Git repo` |

**结论**：网络层 7 个踩坑全解决。Sprint 1 收工。

---

## 1. Day 2 立即做：.devcontainer 模板

### 1.1 动机

按你 v3 反馈：

> "现在就做：每个项目增加 .devcontainer/devcontainer.json。但不启动。"

`/devcontainer/devcontainer.json` 是 VSCode Remote Container 标准配置——**未来灾备**用：
- 电脑坏 → 1 分钟 cloud 重建开发环境
- 出差 / 旅游 → 临时开发

**但** 6 个项目根（aitutor / BioFLow / investment / paper / 题库分析 / 智启复习）**不是** infra repo 的管理范围。

**策略**：在 `~/infra/templates/devcontainer/` 写**配置模板**（**不写**真 `.devcontainer/`，因为那是项目层），用户手动 cp 到项目根。

### 1.2 文件结构

```
~/infra/templates/
├── README.md                          # 模板使用说明
├── devcontainer/
│   ├── generic-python.json            # 通用 Python 项目
│   ├── generic-node.json              # 通用 Node.js 项目
│   ├── aitutor.json                    # Node + Postgres + pgvector + AGE
│   ├── investment.json                 # Python + DuckDB + pandas + akshare
│   └── paper.json                     # Python + Zotero API + better-bibtex
```

### 1.3 模板关键字段

- `image`: 基础 Docker image（如 `mcr.microsoft.com/devcontainers/python:3.11`）
- `features`: Git / Node / Postgres / Docker-in-Docker
- `extensions`: VSCode 必装插件（Ruff / Pylance / Docker / a ider）
- `forwardPorts`: 端口转发（4000=litellm / 5432=postgres）
- `postCreateCommand`: pip install / npm install
- `customizations`: vscode settings（lint / format）

---

## 2. Day 3+ 待做（不阻塞）

| 触发 | 动作 |
|---|---|
| 电脑故障 / 出差 | 启用 B 方案（git push → 1 分钟 Codespace）|
| 家用 LAN 频繁 block 公网 | 触发 D 方案（Hetzner VPS）|
| 项目想私有仓库（.env 等敏感）| 把对应 `.devcontainer/` cp 到项目根 + 配 GitHub private repo |
| 半年后 | D 方案评估 + 渐进迁移投资 / 论文 / aitutor 到 VPS |

---

## 3. 决策（不变）

| 阶段 | 方案 | 状态 |
|---|---|---|
| 立即 | A. 能力检测 + SSH 调试 | ✅ Day 1 收工 |
| 立即 | B. .devcontainer 模板 | 🟡 写模板（v5）|
| 半年 | D. 远程 VPS | ⏸ 准备中 |
| 不用 | C. 双 VM | ❌ |

---

## 4. 改写历史

- v1: 3 方案对比
- v2: 执行计划
- v3: 改"加路由不删 default"
- v4: 能力检测脚本
- **v5: Day 1 收工 + .devcontainer 模板**
