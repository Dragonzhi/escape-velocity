# AGENTS.md · 《单程》Escape Velocity

本仓库是 **Dora SSR + TypeScript** 的竖屏小游戏（比赛项目）。任何在此仓库工作的编码 Agent
（DSH 会话、子智能体、其他工具）**先读这份守则**，再动手。

## 先读什么（唯一事实来源）

| 内容 | 文件 |
|---|---|
| 技术与决策（冲突时以它为准） | `docs/开发手册.md` |
| 计划 / 进度与证据 | `.agent/plan/PLAN.md`、`.agent/plan/PROGRESS.md` |
| 玩法与关卡设计稿（讨论稿 + Agent 批注：已实现/待做/成本） | `docs/单程_最终玩法与关卡优化方案.md` |
| 长期记忆与已知坑 | `.agent/main/{MEMORY,PROJECT_MEMORY,SESSION_SUMMARY}.md` |
| 引擎 API / 鉴权 / 构建链路事实 | `docs/DSH-vs-Dora内置Agent-能力对照.md` |
| 本地构建工具说明 | `tools/dora-build/README.md` |

## 硬约束（都是踩过的坑）

1. **`.ts` 与编译产物 `.lua` 同目录共存**：引擎执行的是 `.lua`，改完 `.ts` **必须重新构建**才会生效。
   `Test/gen_shapes.lua` 是手写 Lua，没有对应 `.ts`。
2. **构建两条路**：`node tools/dora-build/build.mjs --all`（不依赖引擎与浏览器，推荐）或
   `Dora.exe cli build -p .`（要求 Web IDE 浏览器已连接）。**校验纪律**：`--out` 到临时目录再
   `compare-all`，不要直接覆盖仓库 `.lua` 再 `git diff`。
3. **TSTL 三坑**（编译期不报错、运行时报错）：① 接口/对象成员函数默认带 self → 接口标 `/** @noSelf **/`，
   返回对象里别用简写属性（包一层箭头函数）；② `threadLoop` 返回 `false` 继续、`true` 停止；
   ③ 工厂命名空间不是类型（写 `Vec3.Type` / `Node3D.Type`）。
4. **触摸**：全屏 `touchEnabled + swallowTouches` 的节点会**独占**整屏点击；隐藏时**必须同时断掉触摸**
   （只设 `visible = false` 不够 —— 真机验收踩过：进关卡拖不动飞行器）。瞄准层是唯一允许全屏独占的层，
   且只在该关 `Aiming` 时开启。子节点可独立命中（父节点不必开触摸）。
5. **物理确定性**：`game/Gravity.ts` 是纯函数、零引擎依赖；预测线与真实轨迹共用同一个 `simulate`；
   不引入时钟/帧率依赖（固定步长 `Config.PhysicsStep`）。
6. 不新增运行时依赖；`Assets/*` 由仓库内脚本代码生成（`Test/gen_shapes.lua` 几何 + `Test/gen_star_assets.py` 星空贴图，
   **不引入第三方素材**）；除记忆维护任务外不要动 `.agent/main/*`。
7. **全屏容器的 `anchor` 必须是 `(0,0)`**：子坐标原点 = 位置 − anchor×尺寸，取 `(0.5,0.5)` 会把整棵子树（含**触摸命中框**）推走半个屏幕 —— 踩过两次（预测线平移半屏、命中框只剩左下象限）。
8. **不要只在启动时读 `View.size`**：手机浏览器的画布启动后还会变一次，视口变化必须整体重建（`Director.entry.onAppChange(name === 'Size')`）。
   重建时**必须清掉旧运行时的预测线/尾迹**（`trajectory.clearPrediction/clearTrail`——DrawNode 挂在关卡 2D 层上，不随 runtime 消失；
   横屏截图实测残留一段游离旧线）。
9. **Windows PowerShell 脚本带 here-string 的必须 CRLF**（here-string 在纯 LF 下解析失败，`tools/input-inject/set-window.ps1` 踩过）。
   只用普通字符串的脚本（`tools/engine-run.ps1`、`tools/level-shots.ps1`）纯 LF 也能跑。

## 验证纪律（写了代码 ≠ 通过）

构建通过只证明编译过，进程存活只证明没崩。输入、状态迁移、输赢流程、持久化、时序、视觉各自需要证据。

**先看三条现成的脚本**（都是会话 29 建的，把下面这些坑都封在注释里了）：

```powershell
# ① 引擎内跑一次入口（起引擎 → /run → 等 phase=done → 读标记 → 打印日志尾 → 停引擎）
pwsh tools/engine-run.ps1 -Run Test/UnitRunner -WaitFile .agent/test-results/unit-summary.txt -LogTail 6
pwsh tools/engine-run.ps1 -Run Test/XxxProbe   -WaitFile .agent/test-results/xxx.txt

# ② 逐关截图（每关重启引擎 + enter-request 进关 + GameShot 抓帧 + TGA→PNG）
pwsh tools/level-shots.ps1 -Levels 1,2,3,4,5,6      # 产物 .agent/test-results/level-N.png

# ③ 关卡数值秒级扫掠（Node 里跑**同一套公式**，不用起引擎；调数值先用它，再进引擎验收）
node tools/level-sweep.mjs                          # 仓库六关，12 方向 × 4 档力度
node tools/level-sweep.mjs --grid 24x6 --t0 24 --detail
```

单测基线：`SUMMARY passed=8 failed=0 total=8`（**219 条断言**）→ `.agent/test-results/unit-summary.txt`。
引擎 API（8866）需要引擎设置里「访问验证 / Auth Required」为关闭；`/ts/build` 还要求 Web IDE 浏览器已连接
（TS 编译实际发生在浏览器里 —— 本地构建用 `tools/dora-build/` 即可，不要依赖它）。
截图是未压缩 TGA，转 PNG：`python -c "from PIL import Image; Image.open(r'x.tga').save(r'x.png')"`。

⚠️ **引擎的四个运行时坑（会话 29 实测，脚本已封好，手写命令时要记住）**：

1. **引擎的工作目录必须是引擎目录**（`<引擎>`）：拿项目目录当 cwd 启动，引擎会去跑项目的 `init.lua`，
   报 `module 'lualib_bundle' not found` 然后死在半路（3 秒后进程还在、API 已经废了）。
2. **冷引擎的 `Content.searchPaths` 是空的**（`sp0=nil`，只有一个 `sp1=<proj>/Test`）⇒ 驱动器里
   `Path(root, ...)` 直接报 `argument 2 is 'nil', 'string' expected`，`root` 也会退化成 `"."` 让
   `Content:save` 静默失败。`UnitRunner`/`GameShot` 已加两级兜底（`searchPaths[0]` 上跳一级、
   `Content.writablePath/escape-velocity`）+ `Content:addSearchPath(root)`（不然 `Assets/...` 解析不了）。
3. **标记文件要在 `/run` 之前删**：入口一开始就写一次 `phase=running`，跑完才改写 `phase=done`；
   在 `/run` 之后删会把第一次写入吃掉，而第二次写入**不会重新建文件** —— 于是永远等不到 `phase=done`。
   （另：一次 pwsh 调用结束后，它派生的进程会被一起收走 —— 起引擎、`/run`、读结果必须在**同一次调用**里。）
4. **进游戏别用 `require("init")`**：Dora 的全局 `require` 按 `Content.searchPaths` 顺序找模块，
   而冷引擎的搜索路径里**没有项目根**（只有 `<proj>/Test` 与引擎的 `Script/`）⇒ `require("init")` 命中的是
   **引擎自带的 `Script/init.lua`**（返回一个表、游戏一行都不跑）：进程活着、`/run` 报 success、
   `pcall` 返回 `ok=true`，但**日志里一条 `[escape-velocity]` 都没有、截图整屏只有清屏色**
   （2026-09-26 实测 `uniq=1, mean=[26,26,26]`，排查了两小时）。`Test/GameShot.lua` 现在按绝对路径
   `Content:load` + `load` 执行，绕开模块解析。**判断"游戏到底跑没跑"最快的办法：看日志里有没有
   `[escape-velocity] started: 6 levels`。**

✅ **触摸可以自动验收（Windows 桌面）**：`Touch` 是私有构造，探针注入不了，
但 Dora 的触摸事件**同时代表鼠标点击** —— 用 `tools/input-inject/mousectl.ps1` 合成鼠标事件即可驱动真实命中判定与状态机。
坐标换算：`View.size`（W×H，用 `Test/SizeProbe.lua` 读，**不要写死** —— 横屏 2024×1230 / 竖屏 601×1066）是逻辑坐标，窗口客户区是缩放显示，
`client_x = view_x·(clientW/W)`、`client_y = (H−view_y)·(clientH/H)`（`set-window.ps1` 改窗口后 W/H 会变）。
回归模板：点选关(674,191) → 拖动(674,600→690,320) → 日志应依次出现 `enter L1`、`phase -> Flying`、`result = ...`、`phase -> Aiming`（点重试 674,470）。
真机多点触控/手势差异仍建议人工抽查；日志请用 `POST /log` 读（`log.txt` 有缓冲与轮转）。
⚠️ **单文件入口的搜索根陷阱**：`POST /run {asProj:false}` 时引擎把**入口文件所在目录**当搜索根（`Content.searchPaths[0]` = `<proj>/Test`）——于是 `require("game.Scene")`、`Model3D("Assets/...")` 全部解析失败，标记文件也会落到 `Test/.agent/...`。**正确做法**：遍历 `Content.searchPaths`（**0 基**数组，内容随引擎状态变化）找**同时含 `init.lua` 与 `game/Scene.lua`** 的那一个当项目根
（照 `Test/UnitRunner.lua`）。从 1 扫起会漏掉 `[0]`；只认 `init.lua` 会误中引擎自带的 `Script\init.lua` —— 都实测踩过。并用绝对路径访问 Assets。

## 交付习惯

- 完成一个小节 → 更新 `PROGRESS.md`（已实现 / 已验证的证据 / 未验证 / 下一步）→ 一次语义化 git 提交。
- 提交前清理：不带入 `.agent/test-results/*`、临时日志、密钥或个人配置。
- 许可 **AGPL-3.0-only**：`LICENSE` 是官方全文，**不要改动它**。
- ⚠️ **提交前必须确认构建全绿**：`node tools/dora-build/build.mjs --all` 要 **0 失败**（当前 41 个文件，
  以工具输出的合计为准，别照抄旧数字）；单测基线 `SUMMARY passed=8 failed=0 total=8`（**219 条断言**）。曾提交过一个构建失败的状态（诊断代码残留导致 init.ts 编译失败、init.lua 没更新，见 e62c07d）—— 构建失败时产物不会更新，提交进去的就是「源码与产物不一致」。
