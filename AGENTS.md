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
   ④ **有些 ES 内建在 tstl 里不存在**（手册 §7.1 已列：`Math.hypot`、`Math.imul`；另有 `toExponential`）。
   `Math.hypot` 的报错是 `TS100029 Math.hypot is unsupported` —— 换成 `Math.sqrt(x*x+y*y)` / `toFixed`。
   🚨 **构建失败 = 那一份 .lua 还是旧的**：别拿它截图/跑单测当证据（2026-09-27 踩过：改完 L1 轨道后截图没变，
   其实是构建 40/41，白白多截了一轮）。**每次截图/验收前先确认构建是 41/41。**
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
10. **读工具会静默截断长文件 —— 永远不要「读全文再整体改写」**（2026-09-27 踩过，一次写坏三个文档）：
    `read` 只返回前 N 行（实测 1689 行的 PROGRESS.md 只回 444 行、1267 行的开发手册只回 ~509 行），
    返回结果里**没有「你被截断了」的信号**（只有 `totalLines` 是真相）。把 `lines.map(l => l.text).join()`
    当全文再 `write` 回去 = 把文件腰斩；更坏的是**它看起来像成功**（写操作报 OK）。
    ✅ 纪律：① 整文件改写前先断言 `lines.length === totalLines`；② 优先用**锚点式 `edit`**（只改要改的那几行，
    其余字节原样不动）；③ 恢复手段是 `git checkout -- <file>`，然后改用 `edit` 重做。
11. **在交给运行时的程序里写中文，字符串一律用「」当引号**：直接写直双引号会把程序语句截断
    （实测报 `Expected ',', got '...'`，连踩三次）。英文引号只在确实要英文时用。

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

# ④ 行星相位设计器（改 orbiter 的第 4 个参数前**必须**用它，别再手填 —— S3.11 的教训）
node tools/level-phases.mjs 5                       # 解 L5：最佳相位 + "有多少条路线"
node tools/level-phases.mjs 4 --t0 180              # 解"第 180 秒才对齐"的相位（L4/L6 用）
# ⑥ 时间窗设计器（S3.13）：相位与日期是**同一个自由度** —— 把每颗行星的 phase0 一起减 ω·δ
#    等价于把整条可行日期带平移 δ 秒。六关都有时间轴，所以"哪一天最好"是设计出来的。
node tools/level-window.mjs 4 --shifts -200,-100,0,100,200   # 平移候选 + 每档成功数 + 硬门判定
node tools/level-window.mjs 4 --tol 20,30 --span 400          # 试算容差/跨度

# ⑦ glTF/GLB 交付自检（S3.14 起）：单位球 / UV / 内嵌贴图 / 面数 / 环材质，读二进制不用起引擎
node tools/glb-check.mjs --all

# ⑤ 合成鼠标"玩一关"（按住/连按/相态守卫/按钮命中这类**时序**行为，逐关截图证明不了）
pwsh tools/level-play.ps1 -Level 4 -HoldWarpMs 2500
# 自动进 Armed（enter-request 的 N@arm:<frames>）→ 连点「发射」→ 同时抓"发射前/后"两帧做 A/B
pwsh tools/level-play.ps1 -Level 4 -AutoArmFrame 120 -HoldWarpMs 2500 -Taps 1 -ShotBeforeTaps
```

单测基线：`SUMMARY passed=8 failed=0 total=8`（**273 条断言**：Gravity 37 / Game 50 / LevelData 73 / Hud 17 /
Trajectory 11 / CameraRig 16 / Progress 36 / Opening 33）→ `.agent/test-results/unit-summary.txt`。
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

⚠️ **会话 38–39 的四个新坑（都是"看起来不像 bug"的那种）**：

5. **面板/按钮的显隐必须由状态驱动，不能只由点按驱动**：一次"点重试没反应"的根因是 ——
   状态被别的东西（切关、视口重建、自动回归序列）改掉之后，屏幕上仍留着一个"没东西可改"的面板；
   点它当然毫无反应。规则：**`onPhase` 里一旦离开 `Result` 就收起结算面板**，状态是唯一事实来源；
   且结算面板要认**它自己显示的那一关**（`resultIndex`），不要用 `activeRuntime()`。
6. **别自己往 `createButton` 的节点挂 `onTapBegan/onTapEnded`**：`createButton` 内部已经注册过，
   后注册会把它的处理器顶掉 —— 实测表现为"按下去既没有按下反馈、也拿不到回调"。要按钮行为就用它自己的 `onTap`。
   另：d.ts 要求回调**必须收 `touch` 参数**（`(this: void, touch: Touch) => void`），零参数箭头函数会编译失败。
7. **任何"世界时刻"都要带发射日期**：`tWorld = core.t0 + core.flightTime`。
   踩过的现象：物理位置是对的、**行星模型却跳回 t=0**（瞄准段用了 `t0 + clock`，飞行段漏了 `t0`）——
   用户一眼就能看出来"物理对、画面错"。飞行/结算/环/i 任何按时间取行星位置的地方，一律用 `tWorld`。
8. **合成点击会整个丢事件**（本机引擎实测：6 次点击只有 1 次进入游戏，日志里连 `tap:` 都没有）——
   所以自动化回归**不能以"点了一次"为判据**：要么多点几次（`for` 循环 + 间隔），要么以**日志行**或**像素差异**为判据。
   ⚠️ 这条同时提醒：**真机上的"点了没反应"可能根本不在游戏逻辑里**。区分办法：每次点按都打一行带状态的日志
   （本项目现在是 `[escape-velocity] tap: retry (resultIndex=0 phase=Result)`），有行 = 事件到了、没行 = 事件没到。

⚠️ **会话 44 的三条新坑**：

9. **一次性按钮必须"按下即动作"**（`ButtonOptions.fireOn: 'press'`；用户原话：「有的时候还是会出现
   按钮点击了没有反应的情况，比如发射按钮」）。Dora 的 `onTap` 挂在 **`onTapEnded`（松手）**上，
   而引擎**会丢事件**、也**没有"触摸取消"回调** —— 按下后划出按钮再松开，那一下可能落到别的节点上。
   用 `'press'` 的：「发射」「重试本关 / 返回关卡选择」、选关按钮、「重看开场」；
   状态型按钮（时间流 ◀/▶、惯性/刹车）保持 `'release'`。共用同一条 0.5 秒防抖，**幂等由调用方保证**。
   每次动作都打一行日志（`launch button fire (press)`）—— 有行 = 事件到了。
10. **世界时刻只有一个事实来源**：`tWorld = core.t0 + core.flightTime`。而且 `core.t0` 在
   **发射瞬间由发射日期交棒而来**（`coreHandoffDate`：发射 `clock→t0`、重试 `t0→clock`、进关都归零）。
   踩过的现象：L4/L6"调好时间一按发射，行星跳回原位"（`core.t0` 永远是 0，只有 `clock` 在变）。
   交棒必须保证 **`t0 + clock` 守恒**（画面不跳），单测 `handoff-*` 守着。
11. **贴图走外部文件、由代码绑定**（S3.14）：交付的 .glb **不含内嵌贴图**（`images = 0`），行星贴图用
    `game/Scene.ts` 的 `PLANET_TEX` + `applyPlanetTexture()` 绑（**有贴图时 baseColor 必须置白**，否则与视觉色相乘变脏）；
    环的贴图靠 `alphaMode === Blend` 认材质（引擎拿不到 glTF 材质名）；细节图集**只能给有 UV 的新模型**
    （旧 `Probe_Body/Probe_Antenna` 没有 UV）。
12. **预测线只在"玩家瞄过"之后才存在**（`aimed` 标志）：进关**一条线都不画**，
   松手进 `Armed` 后**保持**玩家那条线（别拿待机轨道去覆盖它）；重算的缓存键必须含
   **日期 + 探测器此刻位置**（行星随日期动、L1 的探测器自己在动）。

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
  以工具输出的合计为准，别照抄旧数字）；单测基线 `SUMMARY passed=8 failed=0 total=8`（**273 条断言**）。曾提交过一个构建失败的状态（诊断代码残留导致 init.ts 编译失败、init.lua 没更新，见 e62c07d）—— 构建失败时产物不会更新，提交进去的就是「源码与产物不一致」。
