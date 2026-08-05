# 网络层方案对比（2026-08-03 现状 + 3 候选方案）

> 给你带去 ChatGPT 讨论用。
> 写完后 Hermes 不动网络，等你定方案再回来执行。

---

## 1. 当前网络层现状

### 1.1 你在用

| 元素 | 状态 |
|---|---|
| WSL2 (mirrored 模式) | ✅ 与 Windows 共用网络栈 |
| Clash Verge (Windows) | ✅ 浏览器 / WSL 127.0.0.1:7897 |
| Sangfor 校园 VPN (Windows) | ⚠️ 临时启用（拉代码时）|
| Litellm Gateway (Docker) | ✅ :4000 在跑 |
| `api.minimaxi.com` | ✅ 已通（通过 Litellm 容器直连）|

### 1.2 现状问题（按踩坑顺序）

| # | 问题 | 表现 | 当前 workaround |
|---|---|---|---|
| 1 | WSL 端 DNS 整体被劫持 | `socket.gethostbyname` 仍 timeout | 改用 Docker 容器直连（容器有独立 DNS）|
| 2 | WSL 端 TCP 出公网被阻 | `socket 8.8.8.8:53` = `No route to host` | 走 Litellm 容器（Docker bridge 出公网）|
| 3 | Sangfor 推 0.0.0.0/0 路由 | WSL 默认流量走 Sangfor gateway | 用 `no_proxy=219.224.0.0/16` 让校园 IP 绕开 Clash |
| 4 | Litellm base image 硬编 `https_proxy=127.0.0.1:7897` | 容器内 HTTP 调上游走错 | 显式覆盖为空字符串（compose env）|
| 5 | 家用路由器/ISP block 出公网 TCP | WSL 端 socket 直连公网 = No route | 走 Docker bridge / Clash proxy |

### 1.3 真实影响

- ✅ **业务链路全通**：a ider → Litellm → UIBE MiniMax-M3 OK
- ✅ **浏览器 ChatGPT** OK
- ✅ **WSL 装包（npm/pip 国内源）** OK
- ⚠️ **WSL 拉代码** 需要开 Sangfor + 手动关 Clash（5 分钟切换成本）
- ⚠️ **Aider 走 Litellm** OK 但要先 `source ~/.bashrc` 让 `HTTP_PROXY=127.0.0.1:7897` 生效

### 1.4 当前文档

- `~/infra/VPN-RUNBOOK.md`：VPN 切换手册
- `~/.bashrc`：proxy / DNS / no_proxy 配置
- `~/infra/docker-compose.yml`：Litellm 容器（env 显式覆盖）

---

## 2. 候选方案（3 个）

### 方案 A：当前架构修补（最小变更）

**思路**：不换工具栈，靠 `ip route` + 脚本自动化修 WSL 端 Sangfor 抢路由问题。

**具体动作**：
```bash
# 1. SSH 校园前（自动脚本）
wsl-vpn-on.sh:
  - 关 Clash system proxy（GUI / 任务栏）
  - 启 Sangfor（GUI / 任务栏）
  - 等 30s
  - 跑 ssh 测试

# 2. SSH 后
wsl-vpn-off.sh:
  - 关 Sangfor
  - 等 10s
  - 开 Clash system proxy
  - 删 WSL 端 Sangfor 推的 0.0.0.0/0 路由
  - 加 default via 192.168.1.1
  - 加 219.224.0.0/16 via Sangfor gateway（手动）
```

**优点**：
- 改动最小（不改架构）
- 用现有工具
- 1-2 小时能搞定

**缺点**：
- 仍依赖 Sangfor 客户端（UIBE IT 限制）
- 切 VPN 每次仍要 1-2 分钟手动或脚本
- 真有"双 VPN 抢路由"风险（如果 Sangfor 重连推路由）

**工作量**：半天到一天

---

### 方案 B：Dev Containers / GitHub Codespaces（推倒重来）

**思路**：把"开发环境"放到云端容器（GitHub Codespaces / Gitpod / Cursor Cloud Agents），**完全**避开 WSL + 本地 VPN。

**具体动作**：
1. 选 cloud IDE（GitHub Codespaces 最稳）
2. aitutor / 题库分析 / BioFLow 等项目 push 到 GitHub
3. Codespace 启动时：
   - 自动 `pip install -e .[dev]`
   - 自动 `npm install`
   - 自动 SSH config（含 Sangfor 跳板）
4. 在浏览器 IDE 里写代码
5. SSH 拉代码走 cloud 内置隧道（不依赖本地 WSL 网络）

**优点**：
- **彻底**绕开 WSL 网络层所有问题
- 任何地方任何设备都能开发
- 不依赖本地 Sangfor 客户端
- 自动 provision 环境

**缺点**：
- **有月费**（GitHub Codespaces ≈ $0.18/h × 60h = $11/月）
- Push 代码到 GitHub（如果项目还没 push 要先做）
- 网络依赖 GitHub（GitHub 在国内偶尔被 block，但通常 OK）
- 调试 / 跑 test 在 cloud，可能比本地慢

**工作量**：1-2 天（push 项目 + 配 Codespaces）

---

### 方案 C：双 VM 物理隔离（最干净）

**思路**：跑 2 个 Linux VM，**严格分离** Sangfor / Clash 流量。

**具体动作**：
- VM 1 (Sangfor VM)：跑 SSH 客户端 + git 拉代码，**只连 Sangfor**，不装 Clash
- VM 2 (Dev VM)：跑 dev tools，**只走 Clash**，不装 Sangfor
- 两个 VM 通过 NFS / git / rsync 共享代码（中间有一个"sync VM"做转换）

**优点**：
- 物理隔离，**不可能**有 VPN 抢路由冲突
- 调试简单（每个 VM 单一职责）

**缺点**：
- **资源重**（2 个 VM 跑在 VirtualBox/VMware/Hyper-V 各占 4-8GB 内存）
- 切换 VM 切窗口麻烦
- WSL 已经够用，再加 VM 是倒退

**工作量**：2-3 天（VM 装系统 + 配环境）

---

## 3. 方案对比表

| 维度 | A. 修补当前 | B. 云端 IDE | C. 双 VM 隔离 |
|---|---|---|---|
| 工作量 | 半天 | 1-2 天 | 2-3 天 |
| 月成本 | 0 | ~$11 | 0（但占资源）|
| 可靠性 | 偶有冲突 | 稳定 | 最稳 |
| 切换 VPN 速度 | 1-2 分钟（脚本半自动）| 不需要 | 不需要（VM 分离）|
| 网络依赖 | 家用 LAN + Sangfor | GitHub | 双 VM 内部分离 |
| 未来扩展性 | 0（仍受本机网络限制）| ✅ 不限 | 0（仍是单机）|
| 调试 WSL 现有项目 | ✅ 不变 | ⚠️ 要 push GitHub | ⚠️ VM 路径 |

---

## 4. 我的判断（Hermes 看法）

> ⚠️ 这只是**初步观点**，最终你跟 ChatGPT 讨论决定。

**短期（本周）**：
- 当前架构（A 方案）的修补足够 —— Litellm + a ider 链路已经跑通
- 写一个 `wsl-vpn-on.sh` / `wsl-vpn-off.sh` 脚本半自动切换，省你每次手动

**中期（1 个月）**：
- 考虑 **B 方案**（GitHub Codespaces）—— 它**根本**解决了"家用 LAN block 公网 TCP / DNS 劫持"这种本机网络层问题
- 唯一需要做的：把 6 个项目 push 到 GitHub（一次性的）

**长期**：
- C 方案**不建议**——WSL 已经够用，再加 VM 是倒退
- 真要彻底解：GitHub Codespaces + 本地仅留 SSH 客户端

---

## 5. 我建议的讨论问题（带去 ChatGPT）

```
Q1: 你常用项目（aitutor / BioFLow / 投资 / 论文）有没有已经 push 到 GitHub？
    - 全都 push 了 → B 方案可行，迁移成本低
    - 没 push（如 BioFLow 学校项目）→ A 方案更实际
    
Q2: "家用 LAN block 出公网 TCP" 这个判断对吗？
    - 你之前装过什么家用代理 / router config？
    - 还是 4G/5G 共享网？
    
Q3: 你现在用 ChatGPT 是浏览器直接打开，还是用 IDE plugin？
    - 如果 browser → A 方案不影响 ChatGPT
    - 如果 IDE plugin (Cursor/Copilot) → 这些 IDE 自己也连海外，跟 Litellm 同链路
    
Q4: 预算 / 月费可接受？
    - $11/月 GitHub Codespaces 是否 OK？
    - 还是要 0 月费方案？
    
Q5: "拉代码"频率？
    - 每天 5+ 次 → 切换成本 1-2 分钟/次 需要自动化
    - 每天 1-2 次 → 半自动 OK
    - 偶尔 → 手动
```

---

## 6. 决定后回来执行

不管哪个方案，告诉我"用 A/B/C"或"和 ChatGPT 讨论结果：XXX"，我接着做。

Hermes **当前不主动动**任何网络配置。
