# Devcontainer Templates — 灾备配置（不启动）

> 这些是**配置模板**，不是真 `.devcontainer/devcontainer.json`。
> 真正需要用时，**手动 cp** 到项目根 `mkdir .devcontainer && cp <template> .devcontainer/devcontainer.json`。
>
> **为什么不直接放项目根**：
> - 6 个项目根不在 `infra/` repo 管理范围
> - 避免自动 commit 到项目代码（项目级改动需用户自己决定）
> - 用户可以 review / 修改后再启用
>
> **启用条件**（任一）：
> 1. 电脑故障需要 cloud 重建环境
> 2. 出差 / 旅游需要临时开发
> 3. 项目需要分享给协作者快速 onboarding

---

## 模板列表

| 模板 | 适用项目 | 基础 image | 关键 services |
|---|---|---|---|
| `generic-python.json` | 通用 Python / any CLI | `python:3.11-slim` | Git, Docker-in-Docker |
| `generic-node.json` | 通用 Node.js | `node:20-slim` | Git, Docker-in-Docker |
| `aitutor.json` | aitutor | `node:20-slim` | Postgres 15 + pgvector + AGE |
| `investment.json` | investment (backend/) | `python:3.11-slim` | Docker-in-Docker (litellm 跑) |
| `paper.json` | 论文工具 | `python:3.11-slim` | Docker-in-Docker |

---

## 使用方法

```bash
# 1. 选择对应项目模板
TPL=~/infra/templates/devcontainer/aitutor.json

# 2. 在项目根创建 .devcontainer/
mkdir -p ~/aitutor/.devcontainer

# 3. 复制 + 重命名
cp "$TPL" ~/aitutor/.devcontainer/devcontainer.json

# 4. 提交（用户自己决定是否 git add）
cd ~/aitutor
git add .devcontainer/
git commit -m "devcontainer: add Codespace config (B plan 灾备)"
```

---

## 模板关键字段说明

- `image`: 基础 Docker image（用微软 devcontainer 官方 image）
- `features`: 额外系统工具（git / docker / node / postgres）
- `extensions`: VSCode 必装扩展
- `forwardPorts`: 容器内端口转发到 host
- `postCreateCommand`: 容器创建后跑的命令
- `customizations.vscode.settings`: VSCode 工作区设置
- `remoteUser`: 容器内用户

---

## 启用灾备（B 方案）的流程

1. 笔记本故障 / 旅途中
2. 找一台临时机器（Chromebook / 网吧 / 朋友电脑）
3. 安装 VSCode（10 分钟）
4. 登录 GitHub
5. 在 GitHub 仓库页面点 "Code → Codespaces → Create"
6. VSCode 自动克隆 + 启动容器 + 加载 devcontainer.json 配置
7. 写代码
8. push 到 GitHub

总耗时：**15 分钟**（最坏情况）。
