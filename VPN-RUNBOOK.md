# VPN 共存运行手册（升级版 2026-08-03）

> 上次版本（VPN-RUNBOOK.md）写于 Sangfor 仍不通的时候。
> 现在 Sangfor + Clash 都能工作，但**互斥 default route**——必须按需切换。

---

## 当前态（2026-08-03 实测）

| 客户端 | Listen / 状态 | 影响 |
|---|---|---|
| Clash Verge (Windows) | 端口 `::7897` (IPv6 any) | 浏览器 / Windows 应用层 |
| Sangfor (Windows) | 虚拟 IP `2.0.0.58` / 网关 `2.0.0.54` | WSL 全部流量 |
| WSL default route | `192.168.1.1`（家用）| WSL 内很多 IP 实际走 Sangfor 推的更具体路由 |
| WSL Sangfor 路由 | `2.0.0.54 dev eth3` | 包含 `1.0.0.0/8` 到 `223.0.0.0/8`（全流量覆盖）|

**关键**：
- WSL 用 `host.docker.internal` 不解析（之前以为 work）—— 应该用 **`127.0.0.1`**（WSL2 mirrored 模式 127.0.0.1 = Windows loopback）
- Clash 端只能 listen IPv6 `::7897`（Allow LAN 不开 IPv4 0.0.0.0）

---

## 三种状态（按需切换）

### 状态 A：常态（用浏览器 + 装包）

```
Clash system proxy: ON
Sangfor:            OFF（断开）
WSL default route:  192.168.1.1

可用：
  ✓ 浏览器 ChatGPT
  ✓ WSL 装包（npm / pip 走国内镜像）
  ✗ WSL → 校园 SSH
```

**怎么来这个状态**：
- 默认
- 不用刻意做什么

### 状态 B：SSH 校园（要拉/推代码时）

```
Clash system proxy: OFF（关掉，让浏览器暂不能上外网）
Sangfor:            ON（连接）
WSL default route:  192.168.1.1（家用）
WSL Sangfor 路由:   2.0.0.54 dev eth3（覆盖所有）

可用：
  ✓ WSL → 校园 SSH（拉代码 / 推 / shell）
  ✓ WSL 装包（npm/pip 走国内源，**绕过 Sangfor 推的 0.0.0.0**）
  ✗ 浏览器 ChatGPT（要的话只能去开 Clash，会冲突）
```

**怎么来这个状态**：
1. Windows 任务栏 → Clash Verge → 主界面 → **System Proxy 按钮关掉**（变灰）
2. Windows 任务栏 → Sangfor 客户端 → **连接** vpn.uibe.edu.cn
3. 等 Sangfor 状态："已连接" + 虚拟 IP 显示数字（如 `2.0.0.58`） + 流量 > 0
4. WSL 跑：
   ```bash
   ssh -o ConnectTimeout=10 -o BatchMode=yes xh@219.224.3.96 whoami
   # 预期: xh
   ```

### 状态 C：浏览器 + 校园 + 海外（全部要）

**做不到**。两个 VPN 互抢 default route，不可能同时满足。

**变通**：
- 需要 SSH 校园时用状态 B
- 浏览器 ChatGPT 用状态 A
- 两个分开时段做

---

## 日常操作清单

### 每次开机

```bash
# 1. Clash 自动启动（开机自启）
# 2. Clash system proxy 默认 ON → 浏览器可上 ChatGPT
# 3. Sangfor 默认 OFF → 不抢路由
# 4. WSL 装包用国内源：npm / pip config 已设好（不用每次设）
```

### SSH 校园前

```bash
# Windows 端:
# 1. Clash Verge → 系统代理按钮关（变灰）
# 2. Sangfor → 点连接
# 3. 等状态：已连接 + 虚拟 IP 有数字 + 流量 > 0
```

### 校园 SSH 后

```bash
# Windows 端:
# 1. Sangfor → 断开
# 2. Clash Verge → 系统代理按钮开（亮蓝）
```

---

## WSL 端 ~ 必要的 4 件配置（一次性）

### 1. `~/.bashrc` proxy

```bash
# WSL 用 Windows Clash（Allow LAN ON, port 7897）
# WSL2 mirrored 模式：127.0.0.1 = Windows loopback
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY no_proxy 2>/dev/null
export http_proxy="http://127.0.0.1:7897"
export https_proxy="http://127.0.0.1:7897"
export all_proxy="socks5://127.0.0.1:7897"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export ALL_PROXY="$all_proxy"
# 校园网段不走代理（Sangfor 接管）
export no_proxy="127.0.0.1,localhost,10.*,172.16.*,172.17.*,172.18.*,172.19.*,172.20.*,172.21.*,172.22.*,172.23.*,172.24.*,172.25.*,172.26.*,172.27.*,172.28.*,172.29.*,172.30.*,172.31.*,192.168.*,*.local,<local>,219.224.0.0/16,*.uibe.edu.cn"
export NO_PROXY="$no_proxy"
```

### 2. npm 镜像源（写 `~/.npmrc`）

```bash
npm config set registry https://registry.npmmirror.com
```

### 3. pip 镜像源（写 `~/.config/pip/pip.conf`）

```bash
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
```

### 4. SSH key（已配，自动 BatchMode=yes 通过）

无需每次配。

---

## 故障排查

| 现象 | 修法 |
|---|---|
| WSL → 校园 `No route to host` | Sangfor 没真连（虚拟 IP 未分配）→ 重启 Sangfor 客户端 |
| WSL 端 Clash proxy 不通 | 几乎都是因为 Sangfor 抢了 default route（**预期**）→ 临时关 system proxy |
| 浏览器 → ChatGPT 不通 | Clash system proxy 没开（主界面按钮）|
| 装包慢 | 镜像源没设：`npm config get registry` / `pip config list` |
| `host.docker.internal` ping 不通 | **不要用 host.docker.internal**，WSL mirrored 模式下用 `127.0.0.1` |

---

## 关键认知（避免重蹈）

1. **WSL2 mirrored 模式下**：
   - `127.0.0.1` = Windows host loopback ✅
   - `host.docker.internal` = **不解析** ❌

2. **两个 VPN 互抢 default route 是物理事实**：
   - Sangfor 推的 `0.0.0.0/0` 会让 Clash 失效（WSL 端）
   - Clash 启用 system proxy 不会影响 Sangfor
   - **必须按需切换**

3. **Sangfor "已连接" ≠ tunnel 通了**：
   - 必看"虚拟 IP" 字段有数字 + 流量 > 0
   - 看不到 IP = 认证没完成或客户端 driver 错

4. **WSL `ip route` 看 Sangfor**：
   - 看到 `2.0.0.54 dev eth3` 多条路由 = Sangfor 推了完整路由表 = tunnel 真工作
   - 没看到 eth3 = Sangfor 推路由没传到 WSL = 重启 Sangfor 客户端

---

## 历史（避免重蹈）

| 日期 | 事件 |
|---|---|
| 2026-07-30 | 第一次同时开两个 VPN → Sangfor 路由被 Clash 抢 → SSH timeout |
| 2026-07-31 | 决策：Clash 常开 + Sangfor 临时启（手动切换）|
| 2026-08-03 | Sangfor 重启后真连上，WSL → 校园 SSH 通（22ms）|
| 2026-08-03 | 文档升级（当前版本）|
