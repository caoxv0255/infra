# 网络层执行计划 v4（2026-08-04）

> v1: 3 方案对比
> v2: 执行计划（Day 1-3 行动）
> v3: 改"加路由不删 default"
> **v4: 当前**——网络已基本 OK，只剩工程优化

---

## 0. 关键变化（你提的洞察）

```
之前假设：Sangfor 抢 default route → 需要修路由
现在确认：Sangfor 已经是 split tunnel 模式（自动推 219.224.x.x 路由）
       → 不需要修 default route
       → 不需要手动 add 219.224 路由
       → A 方案从"修网络"变成"诊断+验证 + SSH 调试"
```

**网络层已 OK**：

```
✓ WSL default route 稳定（192.168.1.1）
✓ Sangfor split tunnel 正常（自动推 292 条路由）
✓ Litellm 链路稳定（容器能直连 UIBE Maas）
✓ Docker 出公网正常
✓ 校园 SSH 网络可达（TCP 22 通）
```

---

## 1. 真正剩下的工作（极简）

### 1.1 工程优化 1：脚本能力检测

```
vpn-school-on.sh:
  旧: pgrep Sangfor → 误判（GUI 进程不在但守护进程在）
  新: TCP 219.224.3.96:22 capability check（真实信号）

vpn-normal-on.sh:
  旧: 删 219.224 路由（冗余——kernel 自动清）
  新: 状态确认（tunnel gone + default 仍 eth0 + Clash 端点）
```

### 1.2 工程优化 2：SSH 认证修复

```
tunnel 通（网络层 OK）→ SSH BatchMode 不响应（七层认证问题）
诊断: ssh -vvv xh@219.224.3.96
可能: 用户名错 / key 未加载 / ssh-agent 没起 / 服务器禁密码
```

### 1.3 工程优化 3：Clash 端点（暂不动）

```
7897 listening 但 GUI 不在
可能: Clash core 残留 / 端口 listener 但配置失效
当前: Litellm 链路通、浏览器 ChatGPT 通 → 不阻塞
策略: 记录 + 不动，等真出问题再修
```

---

## 2. Day 0-1 完成情况

| 阶段 | 文件 | 状态 |
|---|---|---|
| Day 0 | `network-status.sh` | ✅ 已写 + 已跑 baseline |
| Day 1 v3 | `vpn-school-on.sh` 加路由 | ❌ **取消**（Sangfor 已自动推）|
| Day 1 v3 | `vpn-normal-on.sh` 删路由 | ❌ **取消**（kernel 自动清）|
| Day 1 v4 | `vpn-school-on.sh` 能力检测 | ✅ **新版本** |
| Day 1 v4 | `vpn-normal-on.sh` 状态确认 | ✅ **新版本** |
| Day 1 | SSH 认证调试 | ⏸ 待做（`ssh -vvv`）|

---

## 3. 时间线（极简版）

```
本周末前:
  - [已做] 跑 baseline network-status
  - [已做] 重写两个脚本（v4 能力检测 + 状态确认）
  - [待做] ssh -vvv 219.224.3.96 调试认证

下周末前:
  - [可选] 给活跃项目加 .devcontainer/ 配置（你建议暂缓）
  
下个月:
  - [待定] 整理 GitHub 仓库结构

3-6 个月:
  - [P2] Hetzner VPS 部署

6 个月+:
  - [P2] D 方案完整运行
```

---

## 4. 决策（不变）

| 阶段 | 方案 | 时间 | 状态 |
|---|---|---|---|
| 立即 | A. 能力检测脚本 + SSH 调试 | 本周 | 🟡 进行中（脚本写完，等 SSH 调试）|
| 半年 | D. 远程 VPS | 6 个月内 | ⏸ 准备中 |
| 备用 | B. GitHub Codespaces + `.devcontainer/` | 触发条件 | ⏸ 暂缓 |
| 不做 | C. 双 VM | — | ❌ |

---

## 5. 改写历史

- v1: 3 方案对比
- v2: 执行计划（Day 1-3 行动）
- v3: 改"加路由不删 default"
- **v4: 网络已基本 OK，只剩工程优化**
