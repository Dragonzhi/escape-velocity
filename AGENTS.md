# AGENTS.md · 《单程》Escape Velocity

本仓库是 **Dora SSR + TypeScript** 的竖屏小游戏（比赛项目）。任何在此仓库工作的编码 Agent
（DSH 会话、子智能体、其他工具）**先读这份守则**，再动手。

## 先读什么（唯一事实来源）

| 内容 | 文件 |
|---|---|
| 技术与决策（冲突时以它为准） | `docs/开发手册.md` |
| 计划 / 进度与证据 | `.agent/plan/PLAN.md`、`.agent/plan/PROGRESS.md` |
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
6. 不新增运行时依赖；`Assets/*` 由 `Test/gen_shapes.lua` 代码生成；除记忆维护任务外不要动 `.agent/main/*`。
7. **全屏容器的 `anchor` 必须是 `(0,0)`**：子坐标原点 = 位置 − anchor×尺寸，取 `(0.5,0.5)` 会把整棵子树（含**触摸命中框**）推走半个屏幕 —— 踩过两次（预测线平移半屏、命中框只剩左下象限）。
8. **不要只在启动时读 `View.size`**：手机浏览器的画布启动后还会变一次，视口变化必须整体重建（`Director.entry.onAppChange(name === 'Size')`）。
9. **Windows PowerShell 脚本用 CRLF**（here-string 在纯 LF 下解析失败，`tools/input-inject/set-window.ps1` 踩过）。

## 验证纪律（写了代码 ≠ 通过）

构建通过只证明编译过，进程存活只证明没崩。输入、状态迁移、输赢流程、持久化、时序、视觉各自需要证据。

```powershell
# 单测（引擎内批跑）→ .agent/test-results/unit-summary.txt，基线 SUMMARY passed=7 failed=0 total=7
# 先 POST /run {"file":"<proj>/Test/UnitRunner","asProj":false}，再读标记文件，最后 POST /stop

# 运行时探针：同上，换成 Test/XxxProbe；标记文件里找 RESULT=PASS

# 引擎 API（8866）需要引擎设置里「访问验证 / Auth Required」为关闭；
# /ts/build 还要求 Web IDE 浏览器已连接（TS 编译实际发生在浏览器里）

# 看截图：引擎截图是未压缩 TGA
python -c "from PIL import Image; Image.open(r'x.tga').save(r'x.png')"
```

✅ **触摸可以自动验收（Windows 桌面）**：`Touch` 是私有构造，探针注入不了，
但 Dora 的触摸事件**同时代表鼠标点击** —— 用 `tools/input-inject/mousectl.ps1` 合成鼠标事件即可驱动真实命中判定与状态机。
坐标换算：`View.size`（W×H，用 `Test/SizeProbe.lua` 读，**不要写死** —— 横屏 2024×1230 / 竖屏 601×1066）是逻辑坐标，窗口客户区是缩放显示，
`client_x = view_x·(clientW/W)`、`client_y = (H−view_y)·(clientH/H)`（`set-window.ps1` 改窗口后 W/H 会变）。
回归模板：点选关(674,191) → 拖动(674,600→690,320) → 日志应依次出现 `enter L1`、`phase -> Flying`、`result = ...`、`phase -> Aiming`（点重试 674,470）。
真机多点触控/手势差异仍建议人工抽查；日志请用 `POST /log` 读（`log.txt` 有缓冲与轮转）。

## 交付习惯

- 完成一个小节 → 更新 `PROGRESS.md`（已实现 / 已验证的证据 / 未验证 / 下一步）→ 一次语义化 git 提交。
- 提交前清理：不带入 `.agent/test-results/*`、临时日志、密钥或个人配置。
- 许可 **AGPL-3.0-only**：`LICENSE` 是官方全文，**不要改动它**。
- ⚠️ **提交前必须确认构建全绿**：`node tools/dora-build/build.mjs --all` 要 36/36。曾提交过一个构建失败的状态（诊断代码残留导致 init.ts 编译失败、init.lua 没更新，见 e62c07d）—— 构建失败时产物不会更新，提交进去的就是「源码与产物不一致」。
