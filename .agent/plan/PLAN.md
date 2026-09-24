# 实施计划

> 唯一事实来源是 [`docs/开发手册.md`](../../docs/开发手册.md)。本计划只细化"按什么顺序做、怎么验收"，不另立技术说法。
> 进度与证据见 [`PROGRESS.md`](./PROGRESS.md)。

## 目标

按开发手册交付一个可玩、可 Web 导出、通过验收的竖屏六关物理规划小游戏。

## 范围

**做**：竖屏、单指、六关、一次性发射、引力弹弓、结算与关卡选择、Web 导出。
**不做**：真实轨道力学、自由漫游沙盒、多人、复杂后处理管线。

## 步骤

### S0 · 裸测（最高优先级，未通过不得进入 S1）

依赖：无。

- [x] S0.1 资产：用 `Test/gen_shapes.lua` 离线生成 `Sphere`/`Ring`/`Probe` 三个自包含 `.gltf`（已逐字节校验 base64 一致）
- [x] S0.2 关闭 R2：确认 TS 层没有程序化几何工厂，只能 `Model3D(path)`（已核查全部 `*3D` 导出；且 `Model3D` 加载自产 glTF 已运行时验证）
- [x] S0.7 冒烟：运行 `Test/Smoke.ts`，确认三个资产能被 `Model3D` 加载并渲染（`status=PASS draws=3 visible=3 triangles=140`）
- [x] S0.3 关闭 R4：自建 3D→2D 投影（`game/Projection.ts`），以 `getRayDirection` 做真值标定；实测最大像素误差 **1.00 px**，回归测试 `Test/ProjectionProbe.ts` 反复 `RESULT=PASS`。
- [x] S0.4 关闭 R3：`Camera3D` 竖屏构图。用已标定的投影模块对竖屏宽高比（1080×1920）计算 NDC：**纵向展开轨道 `maxNdcX=0.72` 完整可见**；横向展开需 dist≥50（否则 `maxNdcX=1.50` 被裁）。⇒ **物理平面必须沿屏幕纵向展开**（已写入 `Config.ts` 与手册 §5.1）。
- [x] S0.5 关闭 R1：**Web IDE 导出 HTML + 浏览器实机可见 3 个 3D 物体**（无需源码构建）
- [ ] S0.6 关闭 R6：🚨 实测包体 **17 MB**，超 8 MB 预算 → 需确认口径或裁剪（见手册 §11）
- [x] S0.8 视觉确认：人工查看 `Test/Smoke.ts` 截图，确认造型/光影/层级（用户确认：球体/圆环/棱锥从左至右依次排开）

验收判据：R1/R2/R3/R4 全部关闭并有证据；若 R1 失败，立即决策是否退回 2D 呈现。

### S1 · 核心循环

依赖：S0。

- [x] S1.1 `game/Gravity.ts`：固定步长积分 + 纯函数可测。已交付 `Test/GravityTest.ts`（25 断言全过，跨运行逐位一致，且已验证测试判别力）。
- [x] S1.2 `game/Scene.ts` / `CameraRig.ts`：行星、探测器、跟随相机。已交付 `Test/SceneProbe.ts`（运行时：`draws=4 triangles=260`）与 `Test/CameraRigTest.ts`（11 断言）；跟随拉远实测 `min=53.95 max=82.55`。
- [x] S1.3 `game/Trajectory.ts`：预测线（拖动实时重画）+ 真实尾迹。已交付 `Test/TrajectoryTest.ts`（10 断言）与 `Test/TrajectoryProbe.ts`（运行时 40+ 区域检出）；预测线与尾迹共用同一份 `simulate` 结果。
- [x] S1.4 `game/Hud.ts`：单指拖拽瞄准、松手发射。已交付 `Test/HudTest.ts`（17 断言）与 `Test/HudProbe.ts`（运行时链路验证）；真触摸坐标系待人工校对。
- [x] S1.5 `game/Game.ts` + `init.ts`：`Aiming → Flying → Result` 状态机与单一主循环。已交付 `Test/GameTest.ts`（22 断言）与 `Test/GameProbe.ts`（完整循环运行时验证 `RESULT=PASS`）。

验收判据：一关可触屏完成"拖→松手→飞行→结算"；物理单测证明同一输入结果一致。

### S2 · 关卡与结算

依赖：S1。

- [x] S2.1 `game/LevelData.ts`：六关数据。已交付 `Test/LevelDataTest.ts`（34 断言，含每关角度×力度扫掠的可玩性硬门）；目标判定接入 Game（到达即截断收束）。
- [x] S2.2 结算三态（成功 / 错过 / 撞毁）+ "重试本关 / 返回关卡选择"。已交付 `game/Ui.ts`（2D 原语）
  与 `game/Hud.ts` 的 `createResultPanel`；运行时探针 `Test/UiProbe.ts` 三态各一张截图 + 文本化视觉判定，
  `RESULT=PASS`（证据见 `PROGRESS.md` 会话 14）。
- [x] S2.3 关卡选择与解锁进度。已交付 `game/Progress.ts`（解锁夹紧/推进 + `writablePath` 存档）与
  `createLevelSelect`；`Game` 增加 `LevelSelect` 相态与 `coreBackToSelect`；`init.ts` 启动即选关、
  按需惰性建每关运行时。`Test/ProgressTest.ts`（36 断言）已并入 `UnitRunner`（`SUMMARY passed=7 failed=0`）。

验收判据：六关数据齐备 ✅；三态判定正确 ✅（单测 + 探针截图）；
进度可持久化 ✅（存档往返单测 + 真实文件 `%APPDATA%\IppClub\DoraSSR\escape-velocity.progress`）。
⚠️ 桌面侧触摸路径**已可自动验收**（`tools/input-inject/mousectl.ps1` 合成鼠标 = 真实命中判定，会话 16/18）；仍开放的是**手机浏览器上的复测**（见手册 §12）。

### S3 · 视觉（下一步；S2 已交付）

依赖：S2（已交付）。整体验收判据：初始帧与飞行帧视觉检查通过，层级正确（星 < 行星 < 轨迹 < UI）、文字不被遮挡。

#### S3.1 星球与土星环造型

- **交付物**：提高球体细分（`Test/gen_shapes.lua` 的 SEG/RING）或产出更精细的自产 glTF；六关行星的配色/尺寸表（`LevelData.visuals`）定稿；土星环朝向与（可选）半透明；探测器造型可读化（四面体 → 有明显指向）。
- **验收判据（可观测）**：① 近/中/远三档相机距离各一张初始帧截图，行星边缘无可见多边形（SEG ≥ 24 时人工看图确认）；② 环与球面不深度冲突（连续 3 帧 `view.stats` 稳定、截图无闪面亮斑）；③ 飞行帧截图里 `faceVelocity` 生效（探测器指向与速度方向一致）；④ 人工看图确认“从哪边借力”可读（公转箭头/尾迹在场）。

#### S3.2 轨迹发光与星空

- **交付物**：预测线/尾迹的发光（`blendFunc` 叠加 + 多层 `drawSegment`，或贴图管线）；背景星空（`View3D.setEnvironmentMap`，或反面球片 + 星点）；轨迹颜色随力度变化（可选）。
- **验收判据（可观测）**：① 同机位截图里轨迹的亮像素占比与连通域数**不低于**当前基线（0.30% / 40+ 区域，`Test/Vision.ts` 可自动读），且线上无断点；② 层级正确（星 < 行星 < 轨迹 < UI，用遮挡关系截图判定）；③ 性能：连续 120 帧的 `App.deltaTime` 相比 S3 前基线劣化 ≤ 10%；④ 人工看图确认风格统一（暗底亮线）。

#### S3.3 金唱片开场与关间简报

- **交付物**：启动 Title（金唱片开场，2–4 秒、可点击跳过）→ `LevelSelect`；关间任务简报（`LevelDef.brief` 的可见呈现：进关时短暂展示，或常驻一行小字）。
- **验收判据（可观测）**：① 日志/截图证明 Title → `LevelSelect` 的相态流转，且“跳过”与“自然结束”两条路径都能到选关；② 简报文案与 `LevelData` 逐字一致（截图人工比对）；③ 一次合成点击即可跳过（`tools/input-inject/mousectl.ps1`）；④ 全流程仍可触屏完成（开始 → 游玩 → 结算 → 重开）。

#### S3.4（可选）粒子与后处理

- **交付物**：到达/撞毁处的粒子爆发；可选 `View.postEffect` 的泛光或引力透镜（愿景 §13 第 3/4 级）。
- **验收判据（可观测）**：① 开/关该效果的同一帧截图对比有可见差异；② 可整体禁用（禁用后不影响状态机与结算）；③ 若掉帧 > 10%（对比基线）**直接砍**（愿景 §13 已授权）。

### S4 · 素材与提交

依赖：S3。

- [ ] S4.1 icon 1024×1024 PNG
- [ ] S4.2 封面 1080×1920 JPG
- [ ] S4.3 演示视频 1080×1920 MP4（30–60 秒）
- [x] S4.4 LICENSE 换为 AGPL-3.0 官方全文 —— **已完成（会话 13）**：34,523 B / 661 行，SHA256 双侧一致
- [ ] S4.5 AtomGit 公开仓库提交

## 风险与回退

见开发手册 §11 与技术未知项清单；每一项都有明确的失败回退路径。
R1/R2/R3/R4 已关闭（见手册 §11）；当前唯一已知验收风险是 **R6 Web 包体积 17 MB > 8 MB**，用户已决定暂缓。

## 待确认（Pending Questions）

- [x] 3D 资产来源 → **已解决**：引擎侧取物不可用（R8），改由 `Test/gen_shapes.lua` 代码生成自包含 glTF（参见手册 §5.9）；如需外部素材，走 DSH 侧网络取物。
- [x] 设计分辨率 1080×1920 是否定稿 → **已解，不需要定稿**：布局与分辨率解耦（全部按 `View.size` 实际逻辑像素推导），竖屏 601×1066 与横屏 2024×1231 两套实测通过；1080×1920 仅作设计参考（见手册 §5.9/§12）。
- [x] LICENSE 官方全文由谁在何时补齐 → **已完成（会话 13）**：`LICENSE` = 官方全文，版权通知在 `README.md`。
- [ ] 第 7/8 关是否纳入？
- [ ] 是否要音频？

## 验证工具（会话 13–20 新增）

| 工具 | 用途 | 入口 / 产物 |
|---|---|---|
| `tools/dora-build/` | **本地 TS→Lua 构建**：不依赖引擎与浏览器，产物与引擎逐字节一致（tstl 1.37.1 + TS 5.9.3，必须 `npm i --legacy-peer-deps`） | `node tools/dora-build/build.mjs --all`；一致性 `--out` + `compare-all.mjs` |
| `Test/UnitRunner.lua` | **单测批跑**（引擎内执行）：7 个纯逻辑模块一次跑完 | 标记文件 `.agent/test-results/unit-summary.txt`，基线 `SUMMARY passed=7 failed=0 total=7` |
| `tools/input-inject/mousectl.ps1` | **合成鼠标 = 真实触摸路径**：驱动真实命中判定、相对拖动、松手发射、按钮点击 | `-Action click/drag/press/move/release`；坐标换算见该目录 README |
| `tools/input-inject/set-window.ps1` | **竖屏窗口**（交付形态）：客户区 400×710 → `View.size` 601×1066；也是“运行中改窗口复现手机视口变化”的手段 | `-Shape portrait` / `-Shape landscape`（脚本必须 CRLF） |
| `Test/SizeProbe.lua` | 读 `View.size` / `windowSize` / `aspectRatio` 等（合成鼠标的坐标换算基准，**不要写死分辨率**） | 标记文件 `.agent/test-results/size-probe.txt` |

> 另有：`Test/Vision.ts`（TGA → ASCII/亮度/连通域的文本化视觉验证）与 `python -c "from PIL import Image; Image.open('x.tga').save('x.png')"`（DSH 原生看图）。
