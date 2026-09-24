# DSH vs Dora SSR 内置 Agent · 能力对照与缺口清单

> 调查时间：2026-09-24 ｜ 调查对象：Dora SSR v1.9.3（`C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86`）
> 证据来源：引擎安装目录源码（`Script/Lib/Agent/*`、`Script/Dev/*`）、本项目 `.agent/main/SESSION.jsonl` 工具调用记录、`.www` Web IDE 前端包、引擎运行日志、本机实测（PowerShell / Python）。
> 本文只记录**可复现的事实**；推断项一律标注「推断」。
> **更新（会话 13–21）**：§0 的两条「🚨 致命缺口」（编译、运行时）**都已关闭** —— 编译走本地 tstl（`tools/dora-build/`），
> 运行时走「关掉引擎「访问验证」后 8866 API 无鉴权」；§3.1/§3.2/§5/§6 已就地标注现状，新增能力清单见 §2.5。

---

## 0. 结论速览

| 能力 | Dora 内置 Agent | DSH（我） | 对本项目的影响 |
|---|---|---|---|
| 读/改/删文件、grep、glob | 有（workspace 校验 + 批量读 + 多段 edit） | **有**，且更强（任意 shell、正则、批量脚本） | 无缺口 |
| **TS→Lua 编译（build + 诊断）** | 有（依赖已连接的 Web IDE 浏览器） | ✅ **有**（会话 13 起）：`tools/dora-build/` 本地 tstl，**不依赖引擎与浏览器**，产物与引擎**逐字节一致** | 无缺口 |
| **在活引擎里跑 Lua / 起游戏 / 抓帧** | 有（`execute_command`、`previewGame`） | ✅ **有**（会话 13 起）：引擎设置里关掉「访问验证」后 8866 API 无鉴权 —— `POST /run`、`/stop`、`/log`、`/run/status` 实测可用；截图落 TGA → PNG 后直接看图 | 无缺口（**真机触屏**与**手机复测**仍人工） |
| Dora 文档检索 | 有（`search_dora_doc`，离线索引 4 套文档） | 无内置，**可绕**：本地 Doc 全文可直接 grep；`dora cli doc search` 同一受限 | 中 |
| 图像分析（截图） | 有（`analyze_image` + 抓帧预算） | **有且更强**：`read_image` 原生视觉；`.tga` 用 Python PIL 转 PNG（已实测） | 无缺口（反而补上了你之前"Agent 无图像工具"的坑） |
| 网络 | 仅 `fetch_url` 下载（**引擎侧实测坏**：落盘 0 字节；`git clone` 超时 ⇒ R8） | **有**：多引擎 web_search、web_fetch、npm/pip/git 直连（已实测通） | 资产改由 `Test/gen_shapes.lua` 代码生成；需要外部素材时走 **DSH 侧**取物 |
| 检查点 / 回滚 | 有（SQLite 任务变更集 `/agent/checkpoint/rollback`） | 无内置，用 **git**（小步语义化提交已成纪律，`f28b018`/`ad007ca` 等） | 低 |
| Web IDE 实时同步 | 有（`UpdateFile`/`RefreshTree` 推送到 IDE 界面） | 无（我只写磁盘，IDE 需刷新） | 低–中 |
| 引擎自带技能 | 7 个（dora-engine-coding / ui-design / love-game-development / music-generation / memory / skill-creator / agent-command） | ✅ **已迁移 Dora 专属技能**：`.dsh/skills/dora-ssr-engine/SKILL.md`（引擎路径/端口/API/构建/探针） | 无缺口 |
| 记忆文件机制 | 有（自动维护 MEMORY / PROJECT_MEMORY / SESSION_SUMMARY / HISTORY.jsonl） | 无同名机制（有 goal / 会话持久化 / 子代理隔离） | 中（可约定复用同一批文件） |
| 收尾契约 | `finish(outcome/validation/assumptions)` 结构化交接 | 无强制格式（我在回答里自述） | 低 |
| 子智能体 | `spawn_sub_agent` / `list_sub_agents`（异步、不可干预） | **更强**：后台、可续聊、可 steer、可打断、可 fork 上下文 | 我更强 |
| 上下文经济 | 单请求实测涨到 **41.7 万 tokens**（`log.txt`） | 有压缩 + 子代理隔离 | 我更强 |

**一句话（会话 21 现状）**：当初唯一拦住我的两件事——**编译**与**运行时**——都已关闭：编译走本地 tstl（路线 C 落地），运行时走「关闭访问验证后 8866 无鉴权」。现在剩下的**人工项**只有两件：真机上抽查多点触控/手势差异，以及手机浏览器上复测 Web 导出包。

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

### 2.5 会话 13–21 新增的可用能力（工具清单）

| 能力 | 入口 | 现状 / 证据 |
|---|---|---|
| **本地 TS→Lua 构建**（已入库，不是 `.temp/`） | `node tools/dora-build/build.mjs --all` | 不依赖引擎与浏览器；**版本必须钉死 `typescript-to-lua@1.37.1` + `typescript@5.9.3`**，安装必须 `npm i --legacy-peer-deps`（TS 6.0.2 会静默产出 `Math:sqrt(...)` 错码）；当前整项目 **36/36 成功**；一致性门禁 = `--out <tmp>` + `compare-all.mjs`（产物与引擎逐字节一致，见 `tools/dora-build/REPORT.md`） |
| **单测批跑** | `Test/UnitRunner.lua`（引擎内运行） | 标记文件 `.agent/test-results/unit-summary.txt`；基线 `SUMMARY passed=7 failed=0 total=7`（**7 模块 / 164 断言**）。新增单测模块必须加进它的 `modules` 列表 |
| **合成鼠标 = 真实触摸路径** | `tools/input-inject/mousectl.ps1` | Dora 的触摸事件同时代表鼠标点击 ⇒ 可驱动**真实命中判定**与状态机（六点命中网格、相对拖动、松手发射、按钮重试均已跑通）；`-Action click/drag/press/move/release`、`-HoldMs` |
| **开发窗口 = 竖屏交付形态** | `tools/input-inject/set-window.ps1 -Shape portrait\|landscape` | Win32 `MoveWindow`；客户区 400×710 → `View.size` 601×1066（横屏 1349×820 → 2024×1230）；也是复现「手机视口变化」的手段。⚠️ 脚本必须 **CRLF** |
| **屏幕几何探针** | `Test/SizeProbe.lua` | 标记文件 `.agent/test-results/size-probe.txt`；读 `View.size`/`windowSize`/`aspectRatio`/`fieldOfView`/`App.platform`，供合成鼠标坐标换算（**不要写死分辨率**） |
| **引擎操作技能** | `.dsh/skills/dora-ssr-engine/SKILL.md` | 引擎路径、端口、HTTP API、构建两条路、探针与标记文件、TGA→PNG 看图的速查 |

运行时验证的固定套路：`POST /run {file, asProj}` 起入口/探针 → 轮询标记文件到 `phase=done`（或 `RESULT=PASS/FAIL`）→ `POST /log` 读日志（`log.txt` 有缓冲与轮转）→ `POST /stop`；截图用 `python -c "from PIL import Image; Image.open('x.tga').save('x.png')"` 转 PNG 后直接看图。

## 3. 缺口清单（按对剩余工作 S3→S4.5 的影响排序）

### 3.1 ✅ 编译（build）：已解决（会话 13，路线 C 落地）

> 下面是**当时的缺口描述**，保留作历史；现状见本节末尾。

- 仓库里 `.ts` 与编译产物 `.lua` **同目录共存**（`game/Game.ts` + `game/Game.lua`），引擎实际执行的是 `.lua`。
- 我可以用 `edit` 改 `.ts`，但**没有 `build`**：`.lua` 不会更新，运行结果仍是旧的。
- 现实绕法：① 你在 Web IDE 点「构建」（零成本，但我无法验证诊断）；② 我打通引擎 API 后自己调 `/ts/build`（见 §5 路线 B）；③ 本地复刻 tstl 工具链（见 §5 路线 C）。

**现状（会话 21）**：路线 C 已落地并入库 —— `tools/dora-build/`（`build.mjs` / `compare.mjs` / `compare-all.mjs` / `REPORT.md`），
`node tools/dora-build/build.mjs --all` 在无引擎、无浏览器的情况下构建全项目（当前 **36/36**），产物与引擎产物**逐字节一致**（标定报告见工具目录）。
引擎侧 `Dora.exe cli build -p .` 仍可用，但**要求 Web IDE 已连接**（TS 编译实际发生在浏览器里，见 §4.5）。

### 3.2 ✅ 运行时（execute_command 等价能力）：已解决（会话 13）

> 下面是**当时的缺口描述**，保留作历史；现状见本节末尾。

- `execute_command` 能做到的事，我目前都做不到：在活引擎里跑 Lua、`enterEntryAsync` 起探针、`stopEntry`、`previewGame` 抓帧、读运行时状态。
- 我能做的替代：读它写下的**标记文件**（`.agent/test-results/*.txt`，内容形如 `status=PASS draws=3 visible=3 triangles=140`）+ 读引擎日志 `log.txt` + 把 `.tga` 截图转 PNG 后**亲眼看图**。
- 也就是说：**验证链路里"触发"那一环仍必须你手动点一下**（IDE 的运行按钮）。

**现状（会话 21）**：引擎设置里**关闭「访问验证 / Auth Required」**后（`Script/Dev/Entry.lua` 的 `HttpServer.authRequired`），
8866 端口 API 无需签名即可用 —— 实测 `POST /status` / `/run` / `/stop` / `/run/status` / `/log` 全部可用，
可以自己起入口或探针、自己读标记文件与日志、自己停入口；触摸类改动还可以用 §2.5 的合成鼠标驱动**真实命中判定**。
⚠️ 两点保留事项：① 关闭鉴权后**同局域网其他设备也能无鉴权访问**（本机开发可接受，勿在不安全网络下长期关闭）；
② 仍有**入口租约**：Web IDE 正在跑游戏时 `stopEntry()` 不释放，需先停游戏才能跑探针。

### 3.3 文档检索：可绕，但需要一次整理

- `search_dora_doc` 对应本地 `Doc/{zh-Hans,en}/{Tutorial,Example}` + `Script/Lib/**/*.d.ts`（共 58 个 `.d.ts`，其中 `Script/Lib/Dora/zh-Hans/Dora.d.ts` 276 KB 是全部 API）。
- 我可以用 `grep` 直接搜这些文件（无需引擎、无需授权），效果不低于 `search_dora_doc`；缺的只是"随手就查"的封装。
- **现状**：已迁移为 DSH 技能 `.dsh/skills/dora-ssr-engine/SKILL.md`（§6 建议 1 已完成）。

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
- ✅ **现状（会话 13 起）**：本机开发的固定做法是**在引擎设置里关闭「访问验证 / Auth Required」**，
  于是 `HttpServer.authRequired = false`、API 无鉴权可直接调用 —— **不需要走上面的配对/签名流程**（该流程只作为「必须保鉴权时」的备用路径保留）。
  ⚠️ 代价：同一局域网内其他设备也能无鉴权访问，勿在不安全网络下长期关闭。

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
- ✅ **现状（会话 13 起）**：因为长期保持「访问验证」关闭，**CLI 与 HTTP API 都可直接使用** ——
  会话 14 实测 `Dora.exe cli build -p <proj>` 全量编译通过；`cli status` / `cli run` / `cli log` 同理。
  ⚠️ `cli build` 仍要求 **Web IDE 已连接**（引擎的 TS 编译发生在浏览器里，见 §4.5）。

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
- ✅ **补记（会话 21）**：上面这条推断**已实测落地** —— `tools/dora-build/` 用同一份编译选项 + 引擎自带的 `Dora.d.ts` 副本，
  **在没有引擎、没有浏览器的情况下产出与引擎逐字节一致的 `.lua`**（差异项：TAB 缩进、`luaExternalModules`、`-- [ts]:` 行号标记的后处理，见 `tools/dora-build/REPORT.md`）。
  ⇒ "TS 编译发生在浏览器里" 描述的是**引擎自身**的构建链路；**项目侧已不再受它约束**。

### 4.6 其他已核实事实

- 截图：`App.saveScreenshot` 输出未压缩 TGA；`previewGame` 抓帧落 `.agent/vision/*.png`（TGA→PNG 转换在引擎侧完成）。
- Web 导出：CLI **无** Web 构建命令，只能走 IDE「打包 / 导出 HTML」（与 `MEMORY.md` 记录一致）。
- 内置 Agent 的提示词可在项目 `.agent/AGENT.md` 覆写（工具定义与决策格式在代码里，不暴露）。

---

## 5. 三条打通路线（按性价比）

### 路线 A：维持现状（你点构建/运行，我做其余一切）—— ⛔ 已被 B/C 取代
- 成本：0。能力：写码、读证据、看图、查文档全在我这边；**编译与运行时触发由你点一下**。
- 适合：继续按 PLAN.md 推进 S2.2 → S4，节奏是"我改完 → 你点构建/运行 → 我读标记文件与截图验收"。

### 路线 B：打通引擎 API（推荐，收益最大）—— ✅ 已生效（但比预想更简单：直接关鉴权，不需要配对签名）
- 做法：完成一次配对拿到 `sessionId:secret`（引擎窗口的 6 位码 + 一次点击），我写一个 Node 签名客户端，之后可调 `/ts/build`、`/run`、`/stop`、`/log`、`/doc/search`、`/command`（跑 Lua）、`/zip`。
- 收益：**基本补齐 §3.1 与 §3.2 两个致命缺口**，我能自己编译、自己起游戏、自己读日志，形成闭环。
- 代价/风险：token 单值 → 浏览器 IDE 会话会被顶掉（需要重新授权）；或者反过来，**重启引擎后不开 IDE**，token 保持为空，此时连 `dora cli` 都能直接用（最省事，代价是没有 IDE 界面）。

### 路线 C：本地 tstl 构建链（长期最优，工作量中等）—— ✅ 已落地并入库（`tools/dora-build/`，会话 13）
- 做法：`npm i -D typescript-to-lua typescript` + 复制 `Dora.d.ts` + 用 §4.5 的选项写构建脚本，产出与引擎一致的 `.lua`。
- 收益：**不依赖引擎、不依赖浏览器**就能编译；比内置 Agent 更强（它的 build 依赖浏览器）。
- 风险：需与引擎产物逐文件比对（`noHeader`/`sourceMap`/模块路径/lualib 需要标定），首次投入约 1–2 小时。

---

## 6. 建议的下一步（三件小事，会话 21 全部已完成 ✅）

1. **迁移引擎知识为 DSH 技能**（半小时）：`dora-engine-coding`（含 API 查询路径 `Script/Lib/Dora/zh-Hans/Dora.d.ts`、Doc 目录、`Dora.exe cli` 用法、TGA→PNG 一行命令、端口与鉴权事实）——让"查 API / 看图 / 写 Dora 代码"不再依赖引擎入口。
2. **选一条打通路线**（A/B/C），B 与 C 可叠加。→ ✅ 已选：C 落地本地构建，B 简化为「关闭访问验证」；A 已不需要。
3. **收尾契约对齐**：每次收尾按 `outcome / validation / assumptions / 下一步` 四段写，并把结论回写 `.agent/plan/PROGRESS.md`（沿用现有记忆文件，不新增体系）。→ ✅ 已成惯例（`PROGRESS.md` 的会话条目 + `AGENTS.md` 的交付习惯）。

---

## 附：常用命令速查

```powershell
# 本地构建（推荐：不需要引擎，不需要浏览器；产物与引擎逐字节一致）
cd tools/dora-build; npm i --legacy-peer-deps      # 版本钉死 tstl 1.37.1 + TS 5.9.3
node build.mjs --all                               # 全项目，提交前应 36/36
node build.mjs --all --out out; node compare-all.mjs out   # 一致性门禁

# 引擎 CLI（「访问验证」关闭时可直接用；build 仍要求 Web IDE 已连接）
& "C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86\Dora.exe" cli status
& "...\Dora.exe" cli build -p .
& "...\Dora.exe" cli run -p .
& "...\Dora.exe" cli doc search Sprite --source tutorial --lang ts

# 引擎 HTTP API（关闭「访问验证」后无鉴权）
Invoke-WebRequest -Uri http://127.0.0.1:8866/status -Method Post -Body '{}' -ContentType 'application/json'
# 单测批跑：POST /run {"file":"<proj>/Test/UnitRunner","asProj":false} → 读标记文件 → POST /stop

# 开发窗口与合成鼠标（真机触摸的可自动化替身）
powershell -File tools/input-inject/set-window.ps1 -Shape portrait
powershell -File tools/input-inject/mousectl.ps1 -Action click -StartX 674 -StartY 191

# 看截图：TGA → PNG（转换后可直接看图）
python -c "from PIL import Image; Image.open(r'.agent/test-results/s21-steady.tga').save(r'.temp/s21-steady.png')"
```
