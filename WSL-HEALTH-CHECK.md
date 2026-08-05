# WSL 开发环境健康检查报告

> 生成时间: 2026-07-30
> 范围: WSL 内 PATH + Windows PATH + 关键 binary 多版本冲突

---

## 1. 摘要（4 个数字说明一切）

| 指标 | 数值 |
|---|---|
| WSL PATH 总目录数 | **102** |
| WSL PATH 去重后 | 71（**31 个重复 ≈ 30%**）|
| WSL PATH 死路径（不存在的 dir） | **11 个** |
| Windows PATH（user + machine） | 86 dirs（user 层 79）|
| 同名 binary 多位置冲突（关键 tool）| **11 类** |

**核心问题**：PATH 已经 30% 重复 + 多版本 binary 冲突。shell 启动 + 命令解析都会被拖累。

---

## 2. WSL PATH 重复（按重复次数排序）

| 重复次数 | PATH 目录 |
|---|---|
| **× 5** | `/mnt/c/Users/CaoXv/.dotnet/tools` |
| × 3 | `/mnt/c/Program Files/dotnet` |
| × 3 | `/mnt/c/Program Files/NVIDIA Corporation/NVIDIA App/NvDLISR` |
| × 2 | `/home/cx/.local/bin`（uv/aider/rtk 装的）|
| × 2 | `/mnt/c/Python311/Scripts` |
| × 2 | `/mnt/c/Python311` |
| × 2 | `/mnt/c/Program Files/Common Files/Oracle/Java/javapath` |
| × 2 | `/mnt/c/Program Files (x86)/Common Files/Oracle/Java/java8path` |
| × 2 | `/mnt/c/Program Files (x86)/Common Files/Oracle/Java/javapath` |
| × 2 | `/mnt/c/Windows/system32` |
| × 2 | `/mnt/c/Windows` |
| × 2 | `/mnt/c/Windows/System32/Wbem` |
| × 2 | `/mnt/c/Windows/System32/WindowsPowerShell/v1.0` |
| × 2 | `/mnt/c/Windows/System32/OpenSSH` |
| × 2 | `/mnt/c/Program Files (x86)/NVIDIA Corporation/PhysX/Common` |
| × 2 | `/mnt/c/msys64/mingw64/bin` |
| × 2 | `/mnt/c/Java/jdk-21/bin` |
| × 2 | `/mnt/c/veighna_studio` (×2 处) |
| × 2 | `/mnt/c/Program Files/Microsoft SQL Server/150/Tools/Binn` |
| × 2 | `/mnt/c/Program Files/Microsoft SQL Server/Client SDK/ODBC/170/Tools/Binn` |
| × 2 | `/mnt/c/Program Files (x86)/Windows Kits/10/Windows Performance Toolkit` |
| × 2 | `/mnt/d/Git/cmd` |
| × 2 | `/mnt/d/cursor/resources/app/bin` |
| × 2 | `/mnt/c/Program Files/Rust stable MSVC 1.92/bin` |
| × 2 | `/mnt/c/tools/vcpkg` |

**根因**：每次装一个 Windows app 都给 PATH 加一次；没人删旧条目。

---

## 3. WSL PATH 死路径（11 个 dir 实际不存在）

```
/mnt/c/Users/CaoXv/AppData/Local/hermes/hermes-agent/venv/Scripts  ← hermes-agent venv 已删
/mnt/c/Users/CaoXv/AppData/Local/hermes/bin                          ← 同上
/mnt/c/Program Files (x86)/Common Files/Oracle/Java/javapath          ← ×2 死路径
/mnt/d/anaconda3/Library/mingw-w64/bin                               ← 你现在用 miniconda3 而非 anaconda3
/mnt/c/Users/CaoXv/.dotnet/tools                                       ← ×4 重复且实际死路径
/mnt/c/Users/CaoXv/AppData/Local/Programs/WinClaw/resources/cli       ← WinClaw 没装
```

**根因**：装/卸载 app 留下的 dangling 条目。shell 启动会触发 `stat()` 失败但不致命。

---

## 4. 关键 binary 多版本冲突（最危险项）

| Binary | 位置数 | 实际优先级风险 |
|---|---|---|
| **`npm`** | **5** | `/usr/bin/npm`、`/bin/npm`、`/mnt/d/nodejs/npm`、`/mnt/c/nvm4w/nodejs/npm`、`/mnt/c/Users/CaoXv/AppData/Roaming/npm/npm` |
| **`pip3`** | 3 | miniconda3 vs /usr/bin vs /bin |
| **`python3`** | 3 | miniconda3 vs /usr/bin vs /bin |
| **`pip`** | 3 | miniconda3 vs /usr/bin vs /bin |
| `docker` | 3 | WSL interop stub（实际走 Windows daemon）|
| `java` | 2 | /usr/bin + /bin（同一二进制两路径）|
| `node` | 2 | /usr/bin + /bin（同上）|

### npm 是真正的高风险

5 个 npm 路径，Windows + WSL + nvm 混着。最近的 PATH 顺序决定哪个生效：

- 现在最快被命中的是 `/usr/bin/npm`（WSL 内 apt 装的旧版）
- 但你安装的全局 npm 包在 Windows 端的 `%APPDATA%\npm`
- → 出现 "command not found" / "module not found" 时往往是版本错乱

### Python pip 多版本

- miniconda3 是你主要用的（venv 在里面）
- /usr/bin 是 WSL 自带
- 通常 miniconda 在 PATH 前即 OK；当前确实在前 ✅
- 但写脚本用 `pip install` 不指 conda env 时会落到 conda pip，可能跟系统 pip 打架

---

## 5. 风险等级排序

| 等级 | 项 | 影响 | 是否建议立即动 |
|---|---|---|---|
| 🔴 高 | `/home/cx/.dotnet/tools` 死路径 × 5 | shell 启动每次 stat() 失败 | **立即清** |
| 🔴 高 | npm 5 路径冲突 | 跨系统全局包安装错乱 | **立即清**（保留一个） |
| 🟡 中 | Python 三套同时存在 | 容易踩版本坑 | 当前顺序对，**不改** |
| 🟡 中 | PATH 31 个重复 | shell 启动慢 30% | **清**（手动 1 次）|
| 🟡 中 | dotnet 路径 ×3 | CPU 时间浪费 | **清** |
| 🟢 低 | `/home/cx/.local/bin` ×2 | 影响 < 1ms | 不必管 |
| 🟢 低 | `git` `/bin/git` `/usr/bin/git` | 同一 binary（软链） | 不必管 |
| 🟢 低 | `java` `/bin` + `/usr/bin` | 同上 | 不必管 |

---

## 6. 修复方案（按优先级）

### A. 立即清（安全 + 高 ROI）

1. **删除 /home/cx/.dotnet/tools 死路径**：从 PATH 删 5 次
2. **统一 npm**：保留 `/mnt/d/nodejs/npm`，其他删

### B. 短期能改（建议，但你手动做）

3. **整理 Windows PATH**：跑 PowerShell 脚本批量去重（不动 PATH editor，只打印报告 + 给一键清理）

### C. 长期建议

4. **统一 Python**：明确"WSL 内只用 miniconda3 pip"，写进 `~/.bashrc` 一个 alias `python` → `python3 miniconda3` 版本
5. **统一 Node**：建议装 nvm for Linux（不用 nvm4w），一个 `~/.nvm` 管理 node 版本

---

## 7. 清理脚本

附 `~/infra/fix-wsl-path.sh`：

```bash
bash ~/infra/fix-wsl-path.sh --dry-run    # 默认：只打印报告，不改
bash ~/infra/fix-wsl-path.sh --apply      # 真改
```

**保证**：
- 只清重复 + 死路径
- 保留每个 binary 的第一个出现位置
- 不动 litellm / docker / ollama 等关键服务路径
- 不动 `/home/cx/.local/bin` 任何条目的存在性（只去掉它的重复条目）

---

## 8. 几个不解的疑点（建议手动 review）

1. **`/mnt/d/anaconda3` vs `/home/cx/miniconda3`**：你装了 2 个 conda 套件（一个在 D 盘 anaconda3，一个在 home/miniconda3）—— 选择一个
2. **`/mnt/c/veighna_studio`**：量化交易软件？跟你的投资 Agent 有重叠，确认是否要用
3. **`/mnt/c/Program Files/Rust stable MSVC 1.92/bin`**：Windows 端 Rust。WSL 内 cargo 没装——你 RTK 装的，应该用 npm 版（不是 cargo）

---

## 9. 不在本报告范围内

- bash / zsh / fish 自动启动脚本（~/.bashrc / ~/.profile / ~/.zshrc）里面的 PATH 操作
- 应用级配置（npmrc / pip.conf / cargo config）
- WS 资源（CPU / RAM / Disk）
- Hyper-V 网络栈

需要这些报告另启一项。
