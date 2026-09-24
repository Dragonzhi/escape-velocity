# DSH vs Dora SSR 内置 Agent · 能力对照与缺口清单

> 调查时间：2026-09-24 ｜ 调查对象：Dora SSR v1.9.3（`C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86`）
> 证据来源：引擎安装目录源码（`Script/Lib/Agent/*`、`Script/Dev/*`）、本项目 `.agent/main/SESSION.jsonl` 工具调用记录、`.www` Web IDE 前端包、引擎运行日志、本机实测（PowerShell / Python）。
> 本文只记录**可复现的事实**；推断项一律标注「推断」。

---

## 0. 结论速览

| 能力 | Dora 内置 Agent | DSH（我） | 对本项目的影响 |
|---|---|---|---|
| 读/改/删文件、grep、glob | 有（workspace 校验 + 批量读 + 多段 edit） | **有**，且更强（任意 shell、正则、批量脚本） | 无缺口 |
| **TS→Lua 编译（build + 诊断）** | **有**（依赖已连接的 Web IDE 浏览器） | **无** | 🚨 **致命**：我改 `.ts` 无法变成引擎真正执行的 `.lua` |
| **在活引擎里跑 Lua / 起游戏 / 抓帧** | **有**（`execute_command`、`previewGame`） | **无**（HTTP API 需会话令牌，见 §4.2） | 🚨 运行时验证只能靠你手动跑 |
| Dora 文档检索 | 有（`search_dora_doc`，离线索引 4 套文档） | 无内置，**可绕**：本地 Doc 全文可直接 grep；`dora cli doc search` 同一受限 | 中 |
| 图像分析（截图） | 有（`analyze_image` + 抓帧预算） | **有且更强**：`read_image` 原生视觉；`.tga` 用 Python PIL 转 PNG（已实测） | 无缺口（反而补上了你之前"Agent 无图像工具"的坑） |
| 网络 | 仅 `fetch_url` 下载（本机实测坏：0 字节；`git clone` 超时） | **有**：多引擎 web_search、web_fetch、npm/pip/git 直连（已实测通） | 我更强 |
| 检查点 / 回滚 | 有（SQLite 任务变更集 `/agent/checkpoint/rollback`） | 无内置，用 **git**（仓库已 8 提交） | 低 |
| Web IDE 实时同步 | 有（`UpdateFile`/`RefreshTree` 推送到 IDE 界面） | 无（我只写磁盘，IDE 需刷新） | 低–中 |
| 引擎自带技能 | 7 个（dora-engine-coding / ui-design / love-game-development / music-generation / memory / skill-creator / agent-command） | 技能库很大但**没有 Dora 专属技能**（全文在本机，可迁移） | 中 |
| 记忆文件机制 | 有（自动维护 MEMORY / PROJECT_MEMORY / SESSION_SUMMARY / HISTORY.jsonl） | 无同名机制（有 goal / 会话持久化 / 子代理隔离） | 中（可约定复用同一批文件） |
| 收尾契约 | `finish(outcome/validation/assumptions)` 结构化交接 | 无强制格式（我在回答里自述） | 低 |
| 子智能体 | `spawn_sub_agent` / `list_sub_agents`（异步、不可干预） | **更强**：后台、可续聊、可 steer、可打断、可 fork 上下文 | 我更强 |
| 上下文经济 | 单请求实测涨到 **41.7 万 tokens**（`log.txt`） | 有压缩 + 子代理隔离 | 我更强 |

**一句话**：文件与代码层面我已全面覆盖并更强；**唯一真正拦住我的是"引擎侧执行"两件事——编译（build）与运行时（run/execute）**，它们都锁在引擎的 HTTP/WS 接口后面，接口需要一次会话授权。

---

## 1. Dora 内置 Agent 的全部家当（证据）

### 1.1 工具集（14 个）

工具名取自 `Script/Lib/Agent/Tool/Registry.ts`，调用量取自本项目 `.agent/main/SESSION.jsonl`（1001 行真实会话）：

| 工具 | 本项目调用次数 | 作用 |
|---|---|---|
| `edit_file` | 169 | 多段 `{old_str,new_str}` 编辑，带截断恢复 |
| `execute_command` | 110 | ①在**活引擎**里跑 Lua 片段 ②Git 模式 ③`previewGame` 起游戏并按秒抓帧 |
| `build` | 91 | TS/TSX/XML/Teal/Yue/Yarn → Lua 编译 + 逐文件诊断 |
| `read_file` | 67 | 支持 `reads[]` 批量、offset/limit |
| `grep_files` | 57 | 带 glob 过滤的搜索 |
| `search_dora_doc` | 21 | 离线文档检索：dora-api / dora-tutorial / love-api / tic80-api，含 zh-Hans |
| `glob_files` | 4 | 列目录 |
| `delete_file` / `fetch_url` / `analyze_image` / `ask_user` / `spawn_sub_agent` / `list_sub_agents` / `finish` | — | 删除、带 SSRF 校验的下载、视觉模型分析（65s 预算）、问卷式提问、子代理、结构化收尾 |

### 1.2 支撑系统

- **记忆**：`.agent/main/{MEMORY.md, PROJECT_MEMORY.md, SESSION_SUMMARY.md, HISTORY.jsonl}`，配 `memory` 技能（grep 式召回）。
- **技能**：引擎内置 7 个（`Doc/skills/*/SKILL.md`），支持项目级技能自动发现与 `skill-creator`。
- **检查点**：任务级变更集写入 `agent.db`，可 diff / rollback（`/agent/checkpoint/list|diff|rollback`、`/agent/task/diff|rollback`）。
- **运行时治理**：步数预算（`Runtime/StepBudget`）、任务准入（`TaskAdmission`）、完成策略（`CompletionPolicy`）、视觉预算（`VisionBudget`）、入口租约（`EntryLease`）。
- **角色与模式**：main / sub / plan 三套角色提示词，可在项目里用 `.agent/AGENT.md` 覆写；plan 模式只允许写 `.agent/plan`。
- **Web IDE 联动**：引擎通过 WS 推 `Log` / `UpdateFile` / `RefreshTree` / `OpenFile` / `Download` / `Profiler` 给浏览器。

### 1.3 实测的短板（它自己踩过的坑）

- 上下文爆炸：`log.txt` 里连续多次请求 `prompt_tokens` 已达 **40–42 万**。
- `fetch_url` 在本机**不可用**：三个域名均报 `failed to move downloaded file into target path`，落盘 0 字节（引擎日志 `being used by another process`）；`git clone` 到 github 超时。→ 项目因此改走"代码自造 glTF"。
- 命令模式下 `Content` 被沙箱限制（只能项目内路径，无 `save`/`writablePath`，写文件必须走入口）。
- 入口租约：你正在 IDE 里跑游戏时，它既 `stopEntry` 不了也 `previewGame` 不了。
- 早期**没有图像分析工具**，被迫写 `Test/Vision.ts` 把截图降维成 ASCII 灰阶 + 直方图来判断"有没有、几个、在哪"。

---

## 2. DSH 的家当（本次会话真实可用）

`read` / `write` / `edit` / `glob` / `grep`；`pwsh`（任意 shell：node、python、git、npm、pip）；`run_code`（一次调用里循环/解析/批量编排，Dora 是一步一次工具调用）；`web_search` / `web_fetch` / `advanced_search` / `platform_search`（多引擎联网 + 时间过滤）；`read_image`（PNG/JPEG/WebP/GIF 原生视觉）；`subagent` / `subagent_fork`（后台、可续聊、可 steer、可打断）；`list_agents` / `interrupt_agent`；`todo_write`；plan 模式（`exit_plan_mode`）；后台作业（`pwsh run_in_background` + `job_output`）；`ask_user_question`；技能库 + `create_skill`；goal / ralph；`render_ui`（会话内交互 UI）；`present` / `sidebar_open`。

**本机可用工具链实测**：node、npm（registry 通，`typescript-to-lua@1.37.1` 可取）、Python 3.12 + **PIL 11.3.0** + numpy、git。

---

## 3. 缺口清单（按对剩余工作 S2.2→S4.5 的影响排序）

### 3.1 🚨 编译（build）：我改的 `.ts` 到不了引擎

- 仓库里 `.ts` 与编译产物 `.lua` **同目录共存**（`game/Game.ts` + `game/Game.lua`），引擎实际执行的是 `.lua`。
- 我可以用 `edit` 改 `.ts`，但**没有 `build`**：`.lua` 不会更新，运行结果仍是旧的。
- 现实绕法：① 你在 Web IDE 点「构建」（零成本，但我无法验证诊断）；② 我打通引擎 API 后自己调 `/ts/build`（见 §5 路线 B）；③ 本地复刻 tstl 工具链（见 §5 路线 C）。

### 3.2 🚨 运行时（execute_command）：我不能驱动引擎

- `execute_command` 能做到的事，我目前都做不到：在活引擎里跑 Lua、`enterEntryAsync` 起探针、`stopEntry`、`previewGame` 抓帧、读运行时状态。
- 我能做的替代：读它写下的**标记文件**（`.agent/test-results/*.txt`，内容形如 `status=PASS draws=3 visible=3 triangles=140`）+ 读引擎日志 `log.txt` + 把 `.tga` 截图转 PNG 后**亲眼看图**。
- 也就是说：**验证链路里"触发"那一环仍必须你手动点一下**（IDE 的运行按钮）。

### 3.3 文档检索：可绕，但需要一次整理

- `search_dora_doc` 对应本地 `Doc/{zh-Hans,en}/{Tutorial,Example}` + `Script/Lib/**/*.d.ts`（共 58 个 `.d.ts`，其中 `Script/Lib/Dora/zh-Hans/Dora.d.ts` 276 KB 是全部 API）。
- 我可以用 `grep` 直接搜这些文件（无需引擎、无需授权），效果不低于 `search_dora_doc`；缺的只是"随手就查"的封装 —— 做成一个 DSH 技能即可（见 §6 建议 1）。

### 3.4 视觉：已解决，且比内置 Agent 强

- 引擎截图是 **未压缩 TGA**（`2024×1230 RGBA`，约 9.95 MB/张），`read_image` 不支持 TGA。
- **实测通过**：`python -c "from PIL import Image; Image.open('x.tga').save('x.png')"` 转换后我能直接看图（本次已成功查看 `s21-steady.tga`：暗底 + 行星 + 贯穿的白色对齐线 + 底部白色三角探测器，与 LineAlignProbe 的预期一致）。
- 我还能做 Dora Agent 做不到的：任意裁剪/放大/画直方图/像素统计（numpy 在），以及**判断美观与可读性**（它明确承认不能）。

### 3.5 其余次要缺口

| 缺口 | 说明 | 建议绕法 |
|---|---|---|
| Web IDE 实时同步 | 我写盘后 IDE 界面可能显示旧内容 | 写完提醒你刷新；或走路线 B 用 `/write` 让引擎转发 `UpdateFile` |
| 检查点/回滚 | 无 SQLite 变更集回滚 | 用 git：小步提交（仓库已有 8 个语义化提交，习惯已成型） |
| 记忆文件 | 不自动维护 `.agent/main/*.md` | 约定：开工读、收工由我更新（沿用现有 4 个文件，不新增体系） |
| 引擎技能 | 7 个内置技能不在我的技能表里 | 迁移为 DSH 技能（正文就在本机 `Doc/skills/*/SKILL.md`） |
| 收尾契约 | 无 `finish(outcome/validation/assumptions)` 强格式 | 我在每次收尾按同样四段写 |

---

## 4. 引擎侧硬事实（本次调查新增，后续复用）

### 4.1 服务与端口

- 引擎进程：`C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86\Dora.exe`（v1.9.3，当前 PID 7812）。
- **8866**：HTTP（Web IDE 静态页 + 全部 JSON API）；**8868**：WebSocket（引擎 → IDE 推送；IDE → 引擎回包）。

### 4.2 鉴权（这是所有外部调用的门）

- 初始化：`HttpServer.authToken = ""`（`Script/Dev/WebServer.lua:37`）——**空 = 不校验**。
- 一旦有客户端完成配对，引擎把 token 设为 `"<sessionId>:<secret>"`（`WebServer.lua:189`），此后**除 `/auth` 外的所有 API 一律 401**。
- 实测 401 的路径：`/status` `/list` `/log` `/doc/search` `/run/status` `/assets` `/git/status` `/agent/task/running`（加 `Origin/Referer/X-Requested-With` 头也一样）。`/auth` 不校验（返回 `{"success":false,"message":"invalid code"}`）。
- 配对流程：`POST /auth {code}` → 引擎窗口弹确认 → `POST /auth/confirm {sessionId}` 拿 `sessionSecret`。验证码是**引擎窗口里显示的 6 位数字，30 秒轮换**（`Entry.lua:1964-1971, 2071, 2320`；待确认窗口 60s）。
- 浏览器侧的签名头（`.www/assets/main-*.js`）：`X-Dora-Session` / `X-Dora-Timestamp` / `X-Dora-Nonce` / `X-Dora-Signature`，签名 = `HMAC-SHA256(key=sessionSecret, msg="sessionId\nMETHOD\n规范化路径\ntimestamp\nnonce\nbodyBytes")`。
- **注意**：token 是单一值。任何一方重新配对，另一方立即失效 → 我给引擎配对后，你的浏览器 IDE 需要重新授权（或反过来）。

### 4.3 引擎 API 路由（可从外部驱动的完整清单，节选）

- 构建/运行：`/ts/build`、`/build`、`/run`、`/stop`、`/run/status`、`/wa/build`、`/wa/create`、`/compiler/{ready,poll,result}`
- **执行 Lua**：`/command {code, log}` → `emit("AppCommand", code, log)`（等价于内置 Agent 的 `execute_command` 核心能力）
- 日志：`/log`、`/log/save`（落 `.download/dora_full_logs.txt`）
- 文档：`/doc/search`、`/doc/read`
- 文件：`/read` `/write` `/list` `/stat` `/exist` `/new` `/delete` `/rename` `/upload` `/download` `/zip` `/unzip` `/assets/batch`
- Git：`/git/{run,status,summary,status-files,discard-untracked,file-diff,commit-file-diff,commit-files,history,remotes,branches,tags,profile/*,auth/*}`
- Agent（内置）：`/agent/session/*`、`/agent/task/{status,running,stop,diff,rollback}`、`/agent/checkpoint/{list,diff,rollback}`、`/agent/vision/asset`

### 4.4 CLI：`Dora.exe cli <命令>`

官方文档：`Doc/en/Tutorial/lua/command-line-interface.md`（`Script/Dev/cli.lua` 实现）。命令：`ts install`、`wa install`、`build`、`run`、`buildrun`、`stop`、`status`、`doctor [--fix]`、`log [-n]`、`doc search`、`doc read`、`rust ...`；连接参数 `--host/--port/--timeout`。

**实测**：`Dora.exe cli status` 与 `cli build -p .` 均因 401 失败（`/status` 与 `/ts/build`）。
**根因（推断，证据充分）**：`cli.lua` 的 `tryPostJson` **不带任何鉴权头**，而当前引擎因浏览器 IDE 已配对而持有非空 token → CLI 被锁在门外。即：**CLI 只在"引擎无已配对会话"时可用**（例如引擎重启后不开 Web IDE，或让浏览器会话失效）。

### 4.5 TS→Lua 编译链路（关键：编译发生在浏览器里）

- `/ts/build` 在非 Android 平台若 `HttpServer.wsConnectionCount == 0` 直接返回 `{"success":false,"message":"Web IDE not connected"}`（`Script/Dev/WebServer.lua`）。
- 引擎把 `TranspileTSProbe` 通过 WS 发给浏览器，浏览器用 **tstl（TypeScriptToLua）** 编译后回 `TranspileTS{luaCode}`（`Script/Lib/Agent/Tool/Build.lua:99-209`；`.www/assets/TranspileTS-*.js` 动态加载 `tstl-*.js`）。
- 引擎使用的 tstl 编译选项（从 `.www/assets/TranspileTS-*.js` 提取，**原样**）：

```js
{
  strict: true,
  jsx: ts.JsxEmit.React,
  luaTarget,                                   // 由引擎传入
  luaLibImport,                                // 由引擎传入
  luaExternalModules: ['Dora'],
  noHeader: true,
  sourceMap: true,
  noImplicitSelf: true,
  moduleResolution: ts.ModuleResolutionKind.Classic,
  target: ts.ScriptTarget.ESNext,
  module: ts.ModuleKind.ESNext,
}
```

- API 类型定义：`Script/Lib/Dora/{zh-Hans,en}/Dora.d.ts`（276 KB / 296 KB），另有 57 个 `.d.ts`。
- 本项目**没有** `tsconfig.json`，也没有 `API/` 目录（`dora cli ts install` 才会生成）——说明引擎构建时用的是内置配置。
- 结论：**只要"浏览器 IDE 没连上"，内置 Agent 自己也 `build` 不了**；反过来说，本地用 npm 的 `typescript-to-lua`（registry 实测可达，1.37.1）+ 上面这份选项 + `Dora.d.ts`，**理论上可以在纯 Node 里复刻构建**，彻底摆脱浏览器 —— 需实测标定（见路线 C）。

### 4.6 其他已核实事实

- 截图：`App.saveScreenshot` 输出未压缩 TGA；`previewGame` 抓帧落 `.agent/vision/*.png`（TGA→PNG 转换在引擎侧完成）。
- Web 导出：CLI **无** Web 构建命令，只能走 IDE「打包 / 导出 HTML」（与 `MEMORY.md` 记录一致）。
- 内置 Agent 的提示词可在项目 `.agent/AGENT.md` 覆写（工具定义与决策格式在代码里，不暴露）。

---

## 5. 三条打通路线（按性价比）

### 路线 A：维持现状（你点构建/运行，我做其余一切）
- 成本：0。能力：写码、读证据、看图、查文档全在我这边；**编译与运行时触发由你点一下**。
- 适合：继续按 PLAN.md 推进 S2.2 → S4，节奏是"我改完 → 你点构建/运行 → 我读标记文件与截图验收"。

### 路线 B：打通引擎 API（推荐，收益最大）
- 做法：完成一次配对拿到 `sessionId:secret`（引擎窗口的 6 位码 + 一次点击），我写一个 Node 签名客户端，之后可调 `/ts/build`、`/run`、`/stop`、`/log`、`/doc/search`、`/command`（跑 Lua）、`/zip`。
- 收益：**基本补齐 §3.1 与 §3.2 两个致命缺口**，我能自己编译、自己起游戏、自己读日志，形成闭环。
- 代价/风险：token 单值 → 浏览器 IDE 会话会被顶掉（需要重新授权）；或者反过来，**重启引擎后不开 IDE**，token 保持为空，此时连 `dora cli` 都能直接用（最省事，代价是没有 IDE 界面）。

### 路线 C：本地 tstl 构建链（长期最优，工作量中等）
- 做法：`npm i -D typescript-to-lua typescript` + 复制 `Dora.d.ts` + 用 §4.5 的选项写构建脚本，产出与引擎一致的 `.lua`。
- 收益：**不依赖引擎、不依赖浏览器**就能编译；比内置 Agent 更强（它的 build 依赖浏览器）。
- 风险：需与引擎产物逐文件比对（`noHeader`/`sourceMap`/模块路径/lualib 需要标定），首次投入约 1–2 小时。

---

## 6. 建议的下一步（三件小事）

1. **迁移引擎知识为 DSH 技能**（半小时）：`dora-engine-coding`（含 API 查询路径 `Script/Lib/Dora/zh-Hans/Dora.d.ts`、Doc 目录、`Dora.exe cli` 用法、TGA→PNG 一行命令、端口与鉴权事实）——让"查 API / 看图 / 写 Dora 代码"不再依赖引擎入口。
2. **选一条打通路线**（A/B/C），B 与 C 可叠加。
3. **收尾契约对齐**：每次收尾按 `outcome / validation / assumptions / 下一步` 四段写，并把结论回写 `.agent/plan/PROGRESS.md`（沿用现有记忆文件，不新增体系）。

---

## 附：常用命令速查

```powershell
# 引擎 CLI（仅在 token 为空时可用）
& "C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86\Dora.exe" cli status
& "...\Dora.exe" cli build -p .        # TS→Lua 编译（要求 Web IDE 已连接）
& "...\Dora.exe" cli run -p .          # 运行项目入口
& "...\Dora.exe" cli doc search Sprite --source tutorial --lang ts

# TGA 截图 → PNG（我可以直接看图）
python -c "from PIL import Image; Image.open(r'.agent/test-results/s21-steady.tga').save(r'.temp/s21-steady.png')"

# 引擎 API 探活（需带签名头，或引擎无会话时直接可用）
Invoke-WebRequest -Uri http://127.0.0.1:8866/status -Method Post -Body '{}' -ContentType 'application/json'
```
