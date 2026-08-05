# Zotero / Obsidian 端补完清单（Day 4，**ZotLit v2 版**）

> 详细文档（旧 v1 版）：`/home/cx/论文/配置指南.md`
> 本清单只列**v2 简化版 5 步**，跳过 v1 的"装 Zotero 端 xpi"和"启本地 API"。

---

## A. Zotero 7 端（Windows）

打开 Zotero。

### 步骤

| # | 操作 | 注意事项 |
|---|---|---|
| 1 | Zotero 版本 ≥ 7.0.15 | 帮助 → 关于 Zotero → 检查更新 |
| 2 | 装 Better BibTeX | https://retorque.re/zotero-better-bibtex/installation/<br>工具 → 插件 → 齿轮 → Install Add-on From File<br>**重启 Zotero** |
| 3 | 刷新所有 citekey | 工具 → Better BibTeX → Refresh BibTeX keys<br>1.4 万篇，几分钟 |
| 4 | 拿 Web API key | 浏览器打开 https://www.zotero.org/settings/security<br>→ Create new private key<br>→ 勾 ☑ Allow library access<br>→ Description: "Obsidian zotlit"<br>→ Save → **复制那个 key（很长只显示一次）** |

**ZotLit v2 不需要在 Zotero 装任何 xpi**。Better BibTeX 是为了稳定 citekey（zotlit 靠 citekey 关联笔记）。

**本地 API 端口 23119 不用开**（v2 用 Web API）。

---

## B. Obsidian 端（Windows）

打开 Obsidian。

### 步骤

| # | 操作 | 注意事项 |
|---|---|---|
| 5 | 打开 vault | 左下角 ⚙ → 打开文件夹作为仓库 → `d:\Desktop\论文\obsidian-vault` |
| 6 | 装 ZotLit（**v2 主线**）| Settings → Community plugins → Browse<br>搜索 `ZotLit`<br>Install → Enable |
| 7 | 配 ZotLit | 插件设置里：<br>→ Connection type: **Web API**<br>→ User ID:（你的 Zotero user ID，zotero.org/settings）<br>→ API Key:（第 4 步复制的那串）<br>→ Citation Format: Pandoc |
| 8 | 装其余 3 个插件 | 同搜索：<br>**Dataview**（元数据查询）<br>**Templater**（模板）<br>**Excalidraw**（手绘图）|

---

## 验证（两段都做）

### C. 验证 Zotero → Web API 通路

Powershell / 任何浏览器：

```
https://api.zotero.org/users/<你的 userID>/items?limit=1
```

应在浏览器里看到 1 条 JSON item（替代品的真实文献）。

### D. 验证 Obsidian → Zotero 通路

在 Obsidian 任意 md 文件里：

```
输 @ → 应该弹文献下拉 → 选一篇 → 自动插入 citekey 形式
```

如果弹不出：
1. 检查 Obsidian 进程是否能联网（v2 走 Web API 不是本机端口）
2. 检查 API key 是否正确
3. 检查 User ID（数字，在 zotero.org/settings 那个页面）

---

## E. 我下一步（Wrote，按你的"Zotero OK"触发）

A-D 4 步 GUI 操作完成，回我**"Zotero OK"**，我立刻：

1. WSL 这边 run 端到端：
   ```bash
   curl -s -H "Zotero-API-Key: <key>" "https://api.zotero.org/users/<id>/items?limit=5"
   ```
   验通链路（WSL → Web API → Zotero 服务器）

2. 加 Hermes cron（每天 23:00 跑 bootstrap_literature_notes.py）

3. **P0 全部收尾报告**

---

## v1 / v2 切换备忘

如果以后 v2 有问题想退回 v1，照 `/home/cx/论文/配置指南.md` 走。

v2 的官方文档：https://github.com/PKM-er/obsidian-zotlit（看 README 顶上的版本号）
