# 实施进度

> 状态只能根据**已观察到的证据**更新。写了代码 = 已实现；构建通过 = 构建通过；进程存活 = 运行时存活。它们都不能证明未测试的输入、状态转换、输赢流程、持久化、时序或视觉行为。
> 步骤定义见 [`PLAN.md`](./PLAN.md)，技术细节见 [`docs/开发手册.md`](../../docs/开发手册.md)。

## 当前阶段

**S2 全部交付；S3.1 完成（会话 22/23），S3.2 的星空一半已定稿（会话 24，用户拍板方案 B）。**
行星/探测器已换 Blender `.glb`（尺度/朝向实测）；星空 = 程序化星图贴图 + 每帧贴着相机的背板（72 KB / 2 面 / 1 draw）；
相机取景按真实投影求解（探测器必在框内）。
下一步：**S3.2 剩余的轨迹发光** → S3.3 开场（金唱片 + `Probe_Voyager` 细节版特写）。
**唯一开放的真机项**：手机浏览器上重跑 Web 导出包（含转屏清线修复）。

## 变更日志

### 会话 25 · 四条视觉反馈落地：轨迹重画 / 晨昏线 / 星空压暗 / 地球锚点与天线分体

**用户反馈（原话）**：① 星空过于敞亮喧宾夺主；② 预测线要愤怒小鸟式虚线+末端渐隐，轨迹线要彗星拖尾
（不必一直显示一条线）；③ 行星没有晨昏线；④ 飞行器僵硬，大天线应始终朝向地球——并决定**游戏里加一个地球**。
方案经 ask_user_question 讨论：地球=出发点下方纯视觉实体；天线分体走建模侧（提示词文档已交付，
用户建模 Agent 已交付分组版 glb：37 节点 / 764 面 / Probe_Antenna 组 / FX 喷焰挂点 ×7）。

**已实现（源码）**

- `game/Trajectory.ts` 重画（用户反馈 ②）：预测线 = `drawSegment` 逐段**虚线**（dashOn 12 / dashOff 9 px）
  + **沿线渐隐**（幂次 1.35，末端残留 0.10 保留弹弓规划信息）+ 光晕垫底；尾迹 = **彗尾**（只保留最近 280 个
  采样点 ≈1.2s，宽度/alpha 从头部向尾部收窄，头部亮点）。`projectPolyline`/`decimate` 与对外 API 不变。
- `game/Scene.ts`：① 星空只走 emissive 槽并压到 0x8c（**首版双槽全白 = 贴图亮度 ×2**，反馈①的根因）；
  ② 方向光方位角与相机视线错开（angleY=75）+ 环境光 0.35→0.12（init.ts）⇒ 行星出现晨昏线（反馈③）；
  ③ **地球锚点**：`home`（出发点下方 ≈4.2 格，蓝绿配色 + 微弱夜面自发光，**不进物理/不进取景**）；
  ④ **探测器分体**：`Probe_Body.glb` + `Probe_Antenna.glb`（转轴在文件原点，枢轴节点本地 (0, 0.20, 0)·scale），
  `syncProbe` 每帧让天线从"朝上"向地球方向倾 ≤46°（方位角随位置实时转，距离 <0.5 渐入）——
  **等建模侧拆分文件落地后自动启用**，当前回退单体（天线刚性）。
- `init.ts`：`enter-request.txt` 开发钩子（"N" 自动进第 N关；"N@frames:vx:vy" 到帧自动发射）——
  合成鼠标的选关点击不可靠（同一坐标两次进了 L6，原因未查明），验证脚本从此绕开坐标点击。
- **两个顺手修掉的既有缺陷**（钩子路径暴露）：① `enterLevel` 不隐藏选关面板（隐藏原来只在 onPick
  回调里做，任何其它进入路径面板都会盖在关卡上——截图实测像隔了层毛玻璃）；② `showOnlyLevel` 不切 2D 层，
  上一关的预测线/尾迹会一直叠在当前关画面里（现在连 levelLayers 一起切）。
- 建模提示词文档 v1（`Probe_Antenna` 分组）已交付用户；**后续拆分文件的提示词待写**（见残留）。

**探针/调试期间的引擎坑（本轮新确认）**

- ⚠️ `Model3D` 对**不存在的文件不是返回 nil 而是抛运行时错误**（"can not locate full path" →
  Object::createNotNull failed，把建关流程整个炸掉、画面全黑）——可选资产必须先 `Content.exist` 守卫。
- ⚠️ `Node3D` **不把 glTF 子节点暴露成可寻址节点**（`Test/AntennaProbe` 实测：children/eachChild/name
  全不可访问、hasChildren 恒 false）——按名字找子节点的路走不通，只能拆文件。
- ⚠️ `BlendFunc(One, One)` 加法混合下 **color 的 alpha 分量不参与混合**（虚线/渐隐首版全失效）——
  亮度必须**预乘进 RGB**。
- `Content.searchPaths` 是 **0 基**数组且内容随引擎状态变化（AGENTS.md 已更新）。

**已验证的证据**

- 构建 39/39；单测 `SUMMARY passed=7 failed=0 total=7`（169 断言）；
  逐关 `s31-wire.txt` 六关 match=true（**846/926/1550/846/1630/1230**——探测器换成 764 面的新资产）。
- 游戏内截图（`.agent/test-results/`）：`s32d-0.png`（L1 瞄准：虚线渐隐预测线 + 压暗星空 + 地球在下缘微光）、
  `s32d-2.png`（飞行：彗星拖尾 + 火星晨昏线）、`s32b-L1-aim-dash.png`（L6：土星晨昏线 + 碟面立体感）。

**会话 25 补充（同日）**：建模侧交付拆分文件，**天线指向已启用**。

- ⚠️⚠️ **用户报告的"结算/选关点按钮卡死"已修复**：根因是**每帧旋转一个普通 `Node3D()` 空容器**
  （天线枢轴）会触发引擎堆损坏（0xc0000374，ntdll 检出，事件日志 APPCRASH）——二分定位：
  关掉旋转存活（C1）→ 整体 `angles` 写入仍崩（C2）→ **直接旋转 Model3D 节点则稳定（D，35s × 多轮）**。
  修复 = 去掉枢轴容器，天线模型直接挂在 probeNode 下、位置在转轴处、绕自身原点旋转（几何等价）。
  ⚠️ 这是 Dora 引擎级缺陷（旋转空 Node3D 容器 + Model3D 子级 = 堆损坏），值得报给 Dora 作者。
- 拆分文件验收：Antenna 316 面 + Body 448 面 = 764 面与单体一致；根节点无平移（转轴=原点）；
  碟面文件内 Y 0.0009~0.295（+0.20 拼回原位）——建模 Agent 同时勘误了自查项（1.405 是整机包围盒，
  非碟面；转轴残差 0.0009 可忽略）。
- **Euler 次序数学探针**：两种机身朝向下天线法线世界偏移均 dx=0.000/dz=+1.055 ⇒ 倾角锁定地球 ✓
  （偏移 1.055 对应 26° 倾角 = 距离渐入斜坡在短距离下的正常值）。

- `Probe_Body.glb`（448 面 / 20 mesh / 根在原点）+ `Probe_Antenna.glb`（316 面 / 8 mesh / 转轴=原点）
  —— 合计 764 面与单体严丝合缝；建模 Agent 勘误了自查项（1.405 是整机包围盒数据，碟面实际 Y 0.2009~0.495），
  并确认转轴残差 0.0009（可忽略）。零件拼装在游戏内截图验证：身体与天线无错位。
- **Euler 次序数学探针**（`Test/AntennaTiltProbe`，已删）：两种机身朝向（yaw=-90 / yaw=0）下，
  天线法线世界偏移均为 dx=0.000 / dz=+1.055 ⇒ 倾角方向锁定地球、不随机身转 ⇒ `Ry∘Rz` 复合正确。
  探针同时确认 `GameScene.antenna` 需要由 Scene 直接暴露（子节点遍历不可用）。
- 游戏内截图 `s32e-0/2.png`：瞄准/飞行帧天线与身体对齐、拖尾正常。

**未验证 / 残留**

- 手机复测（含转屏清线）；S3.3 开场 / 路线图选关 / 重主题 / L7 按 PLAN 新增的 S3.5 推进。

### 会话 24 · 星空定稿（用户拍板方案 B）+ 顺手修掉"转屏残留旧预测线"

**用户决定**：① 星空换成方案 B（程序化星图贴图），约束放宽为「素材全部由本仓库代码生成，**不引入第三方素材**」；
② `Probe_Voyager_v1.glb` 的重新导出（164 面 → 600 面）是有意的，无需回退。

**已实现（源码）**

- `Test/gen_star_assets.py`：只产出正式素材 —— `Assets/Image/starfield.png`（**1024×1024**，950 颗，r 0.3–1.4）
  + `Assets/Model/StarQuad.gltf`（顶点 ±1 ⇒ **scale = 半边长**，材质自带 doubleSided）；删除 make_shell（C2 版本在 git 历史 38733a9）。
  密度/尺寸按**游戏内截图**标定：首版（2048×1024 / 2600 颗 / r 0.6–3.4）在游戏里满屏"雪崩"（每颗 4–10 px、互相打架），
  现版是稀密合适的软圆点 + 少数十字亮星。
- `game/Scene.ts`：星空壳 → **背板**（StarQuad + `setBaseColorTexture/setEmissiveTexture` 双槽 + emissive 白 ⇒ 不吃光照）；
  新增 `syncBackdrop(eye, target)` —— 每帧把背板钉到「相机视线前方 600」（半边长 560 > 需求 ≈490）⇒ 等效"星空在无穷远"
  （无视差），任何相机距离/宽高比都正好铺满。远裁剪面实测 **>2000**（一次性诊断探针，用后已删；
  早前"z=-900 不可见"是误报，手册里的旧结论已更正）。
- `game/Game.ts`：两处相机落点（Aiming/Flying）后各调一次 `syncBackdrop`。
- `init.ts`：视口重建时 `trajectory.clearPrediction/clearTrail` —— **修一个既有 bug**：旧运行时的轨迹 DrawNode
  挂在关卡 2D 层上、不随 runtime 消失，重建后旧视口算出的线残留在新视口（横屏截图实测：画面左侧游离一段旧预测线）。
- `Test/SceneWireProbe.ts`：期望改为"星空=2 面"；`rig.step` 传探测器半径 2.13；背板同步与游戏同款。
- `Test/UnitRunner.lua` + `Test/GameShot.lua`：根扫描统一改为 **0 基 + `game/Scene.lua` 判别**（见下面的坑）。
- 文档：手册 §5.9（方案 B / 新开销 / setEnvironmentMap 实测否决 / 风格口径）、README、PLAN S3.2、
  AGENTS（素材口径、重建清轨迹、searchPaths 0 基 + 判别）。

**探针期间踩的坑（已写进 AGENTS.md）**

- `Content.searchPaths` 是 **0 基**数组且内容随引擎状态变化：本次 `[0]`=项目根、`[1]`=引擎 Script 目录；
  从 1 扫起会漏掉项目根。引擎自带 `Script\init.lua`，只认 init.lua 会误中 —— 必须加 `game/Scene.lua` 判别。
- `Path()` 的参数不能带斜杠整段塞（`Path(root, '.agent/test-results/x.txt')` ⇒ `Content.save` **静默失败**、文件不落盘），
  必须逐段 join（照 SceneWireProbe）。
- tstl 环境没有 `JSON`（`JSON.stringify` 编译失败）。

**已验证的证据**

- 构建 `node tools/dora-build/build.mjs --all` → **39 个文件 39 成功 0 失败**。
- 单测 `SUMMARY passed=7 failed=0 total=7`（169 断言）。
- 逐关核对 `s31-wire.txt`：六关 match=true（**682/762/1386/682/1466/1066 面**；星空从 1940 面/2 draw → **2 面/1 draw**），
  逐资产 `StarQuad.gltf = 2` ✓。
- 游戏内截图（合成鼠标，`Test/GameShot.lua`，全部在 `.agent/test-results/`）：
  `s32-L1-aiming.png`（首版星图：质感正确但密度/个头超标 → 据此重标定生成器）、
  `s32-L1-v2.png`（重标定后：稀密合适、软圆点+十字亮星，行星/轨迹读数不受干扰）、
  `s32-L3-aiming.png`（L3 探测器完整在框内 + 新星空）、
  `s32-L1-flying.png`（飞行中：背板跟随相机、拖尾清晰）、
  `s32-landscape-rebuild.png`（切横屏重建后：背板铺满、**无游离旧线** —— 重建清轨迹的修复生效）。

**未验证 / 残留**

- 手机浏览器未复测（含本次的转屏清线修复）。
- S3.2 剩另一半：预测线/尾迹的**双层发光**未开工。
- 极端逃逸飞行时探测器可能跑到背板（距离 600）之外——逃逸半径 400 + 相机 100 的理论上限 ≈ 450 < 600，判定安全，但未逐关验证逃逸全程。

### 会话 23 · 相机取景改为"按真实投影求解"（S3.1 复核中发现并修复）

**起因**：复核 S3.1 交付时**看截图**（不是看 stats）发现 L3 进关卡后**探测器整个在画面外** ——
只有预测线从画面右下角射进来。子智能体的报告写的是"几乎被挤出画面右下"，实际已经完全出画；
它报的 `view.stats` 之所以"六关全对"，正是因为提前关了 `frustumCulling`。
**根因不在 S3.1 的接线，而在 `CameraRig` 的取景公式**，且可复算：

- 旧公式 `距离 = minDistance(25) + 包围盒半对角 × fitFactor(1.6)` 是**与相机无关的启发式**。
- L3 关键点 (0,18)/(0,-2)/(−26,−26) ⇒ 中心 (−13,−4)、半对角 25.55 ⇒ 距离 65.9。
- 竖屏 `aspect = 601/1066 = 0.5638`、`fovY = 45`：探测器的相机空间深度 vz = 50.3，
  **比注视点的 65.9 更靠近相机**（屏幕下方就是近景侧），于是
  `ndcX = (13/50.3) × focal / aspect = 1.11` ⇒ **出画**（|ndc| > 1）。

**已实现（源码）**

- `game/CameraRig.ts`：`RigOptions` 用 `fovYDeg` / `aspect` / `margin(0.05)` 取代 `fitFactor`；
  新增 `frameAt` / `frameFits` / `fitDistance` —— 在 `[minDistance, maxDistance]` 上**二分**求解
  "所有关键点都投影在画面内缩 margin 内"的**最小**距离，投影复用 `game/Projection.ts`
  （与渲染/预测线同一套已标定公式；`viewW/viewH` 取 2 ⇒ 返回值就是 NDC）。
  `step(points, probeRadius?)` 的第 2 个参数只作用于 `points[0]`（约定 = 探测器）。
- `game/Scene.ts`：`GameScene` 新增 `probeRadius` = 局部 AABB **最大边一半** × scale × 1.1
  （不取外接球：两根吊杆沿飞行轴伸出、屏幕不占宽度，用外接球会把相机推得过远；取不到包围盒时用兜底值）。
- `game/Game.ts`：两处 `rig.step(...)` 传 `deps.scene.probeRadius`；顺手修两处 `矄准` → `瞄准` 错别字。
- `init.ts`：`createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio))`；
  `probeScale` 注释改为**当前**资产数字（旧的 164 面/2.9 世界单位已过期）。
- 文档：手册 §5.4 **重写为"已落地实现"**（原描述还是设计稿：加权中点 / 距离随目标距离单调，与实现不符）、
  参数表补 `RigOptions.margin` 与 `View.fieldOfView/aspectRatio`、断言数 164 → **169**；`AGENTS.md` 构建基线改正。
- 清理：删掉星空方案 A/B/C 的一次性探针（`Test/StarProbe*`、`StarDiag*`、`StarCommon`、`PathProbe`、
  `Test/Shader/`、`Test/StarQuad.gltf`、`Test/*.png`、`Test/StarShell*.gltf` 重复副本）；
  `Test/gen_star_assets.py` 保留并改为**直接写 `Assets/Model/`**（实测重新生成的两个壳与原文件**逐字节一致**）。

**已验证的证据**

- 构建：`node tools/dora-build/build.mjs --all` → **48 成功 / 0 失败**。
- 单测：`SUMMARY passed=7 failed=0 total=7`，其中 `CameraRigTest :: passed | checks=16`（新增 5 条：
  `rig-frame-portrait-fits` / `rig-frame-probe-inside` / `rig-frame-portrait-distance` /
  `rig-frame-landscape-fits` / `rig-frame-radius-matters`）。
- 游戏内截图（`Test/GameShot.lua` + 合成鼠标；竖屏客户区 400×710 → `View.size` 601×1066）：
  `shot-002.png`（L3 Aiming，修复后）**探测器完整在框内**（碟形天线 + 支杆，右侧留白约 20 px），
  预测线从探测器出发射向木星；对照修复前 `s31-portrait-L3-aiming.png`（只剩一根支杆贴在角落）。
  L1 竖屏 / L1 横屏同样正常；横屏是从竖屏**切窗口**得到的，日志有 `viewport rebuilt: 2024x1231`
  且随后 `enter L1` ⇒ 视口变化会重建关卡运行时，新宽高比自动生效（回归了 AGENTS.md 第 8 条）。

**未验证 / 残留**

- 飞行途中探测器仍可能短暂出画：距离被 `CameraMaxDistance = 100` 夹住时只能保证"尽量"（夹紧优先于取景）。
- 手感无结论（机架距离在竖屏普遍比旧公式更远，横屏更近）—— 需要真人试玩校准。
- 手机浏览器仍未复测（三处"待复测"依旧）。
- 星空星点在横屏明显偏方（截图 `shot-003.png` 左侧可见明显白色菱形）⇒ S3.2 处理，或改用方案 B。

**下一步**：S3.2 轨迹双层发光 + 星点大小/亮度（或按用户决定切方案 B）→ S3.3 开场。

### 会话 22 · S3.1 模型接线与标定（行星/探测器换 .glb + 星空壳接线）

**已实现（源码）**

- `game/LevelData.ts`：`PlanetVisualDef` 新增可选 `model?: string`；六关按文件注释填天体
  （**只加视觉字段，物理数值一字未动**）：L1 `Planet_Mars`；L2 `Planet_Venus`+`Planet_Mars`；
  L3 `Planet_Jupiter`+`Planet_Saturn`；L4 `Planet_Mars`；L5 `Planet_Jupiter`+`Planet_Saturn`+`Planet_Neptune`（**当天王星代用**）；
  L6 `Planet_Saturn`。
- `game/Scene.ts`：`vis.model` 非空 → `Model3D('Assets/Model/'+model+'.glb')`，否则回退 `spherePath`；
  染色用 `while` 循环 `getMaterial(k)` 直到 `undefined`（**不写死材质数量**）；
  尺度 `scale = displayRadius / MODEL_RADIUS[model]`；**只有「没有 model 且 ring:true」才叠 `Ring.gltf`**；
  探测器 = `Probe_Voyager_v1.glb` + `ProbeYawOffsetDeg`；
  星空 = `StarShell.gltf` + `StarShellBright.gltf`（emissive、不放大、与行星同根）。
- `init.ts`：`probePath` → `Assets/Model/Probe_Voyager_v1.glb`，`probeScale` 1.6 → **1.2**（新常量均带注释）。
- 新工具：`Test/ModelCalibProbe.ts`（标定）、`Test/SceneWireProbe.ts`（逐关 stats 核对）、`Test/GameShot.lua`（游戏内抓帧驱动）。

**已实测的标定数字**

- **行星半径系数 k**（= 模型 scale=1 时的外接半径；两个独立口径 ±4% 内一致）：
  Mars **1.0227** / Venus **1.0215** / Jupiter **1.0000** / Saturn **0.9837**（本体；环 ±2.2 不参与）/ Neptune **1.0170**。
  口径①=引擎 `getLocalBoundsMin/Max`；口径②=与已知半径 1 的 `Sphere.gltf` **并排同 scale 渲染**后的像素直径比
  （参考球实测 17.0 px 半径 ↔ fov 推算 17.83；对象屏幕位置与自建投影逐点吻合）。
- **探测器朝向**：`Probe_Voyager_v1.glb` 的抛物面天线是**朝上的圆盘**（直径 3.227 = 模型最长边）、
  **两根粗主杆沿局部 +Z**（z=+1.00）、**细磁强计杆沿 -Z**（z=-1.85）⇒ `ProbeYawOffsetDeg = -90`
  （细杆朝前、主杆拖后）。`angleY` 的世界映射（局部 +X → (cosθ,0,-sinθ)）用**已知朝 +X 的旧 `Probe.gltf` 四面体**
  在 yaw=0/90/180/270 读**世界包围盒**标定（顶点分别在 world +x / −z / −x / +z），并用俯视网格的标记球（大小不同）
  实测“屏幕右 = 世界 +X、屏幕下 = 世界 +Z”。
- ⚠️ **资产在本次会话期间被替换过**：`Probe_Voyager_v1.glb` 现为 **43,596 B / 21 mesh / 600 三角面 / 6 材质**
  （会话 21 记录的 13.8 KB / 5 mesh / 164 面已过期）。第一次标定用的是旧文件，**全部结论已按当前文件重测**。

**已验证的证据**

- 构建：`node tools/dora-build/build.mjs --all` → **47 成功 / 0 失败**。
- 单测：`Test/UnitRunner.lua` → **`SUMMARY passed=7 failed=0 total=7`**，其中 `LevelDataTest :: passed | checks=34 failures=0`。
- 接线核对（`.agent/test-results/s31-wire.txt`，逐关 buildScene + `view.stats`）：三角面
  **2620(L1) / 2700(L2) / 3324(L3) / 2620(L4) / 3404(L5) / 3004(L6)**，draws 24–29，
  **六关全部 `match=true`**（= 该关各模型面数 + 探测器 600 + 星空 1940 的精确和）；
  另附**逐资产**表：Mars/Venus/Neptune 80、Jupiter 320、Saturn 464、Sphere 120、Ring 16、
  Probe 4、Probe_Voyager_v1 600、StarShell 1800、StarShellBright 140 —— 全部与离线 GLB 解析一致。
  ⇒ 每关确实加载了指定模型（`Planet_Voyager_v1` 的 600 也是从这张表里发现旧文档写的 164 已过期）。
  单关开销远在 1 万三角面预算内（星空占 1940 / 2 draws）。
  ⚠️ 测量前提：`view.stats` 只统计**本帧画出来**的三角形，**必须** `View.frustumCulling = false`
  （L3 的机架会把探测器留到画面外，否则少算几百面）。
- 游戏内截图（**真正跑 `init.lua`**，合成鼠标驱动；全部在仓库根 `.agent/test-results/`）：
  竖屏 `s31-portrait-L1-aiming` / `s31-portrait-L1-flying`（朝向 + 拖尾：主杆拖后、尾迹在正后方）、
  `s31-portrait-L3-aiming`（Jupiter + Saturn 自带环）、`s31-portrait-L5-aiming`（三星 + 青色代用天王星 + 探测器 + 预测线）、
  `s31-portrait-L6-aiming`；横屏回归 `s31-landscape-L1-aiming`（2024×1231）。
  星空在两套形态下均可见且不遮挡轨迹/行星读数。日志依次有 `enter L1/L3/L5/L6`、`phase -> Aiming`、`result = success`。
- 标定证据：`s31-scale.txt/.png`（并排像素 + 包围盒）、`s31-orient.txt/.png` + `zoom-v1-yaw0-new.png`（俯视形状）。

**未验证 / 残留**

- ⚠️ **L3 瞄准帧里探测器几乎被挤出画面右下**（相机按“探测器+两颗行星”构图，Saturn 在 x=−26 把机架拉远）——
  这是 S2 相机取景的既有行为，本轮未动相机。**会话 23 复核截图后确认：不是"几乎"，是完全出画**，已修正（见会话 23）。
- `probeScale=1.2` ⇒ 探测器世界长度 3.87（旧四面体 2.4），观感更大；只有截图证据，无手感结论。
- `Planet_Jupiter` 的 3 个材质被**统一染成关卡色** ⇒ 模型自带的条纹分层被染平（按任务要求“全部染色”）。
- 星空星点在竖屏偏亮偏方（几何是四边形）⇒ 交给 S3.2 调。
- 真机（手机浏览器）仍未复测；本轮截图全部是 Windows 桌面 + 合成鼠标。

**下一步**：S3.2 轨迹发光与星空调优（星点大小/亮度）→ S3.3 开场（金唱片 + `Probe_Voyager` 细节版特写 + `Sun`/`BlackHole`）。

### 会话 21 · 文档同步（含一次误删恢复）+ S3.1 资产入库

#### 1）文档同步：会话 13–20 的事实落进全部文档（提交 `f28b018`）

- **改动 7 个文件、只改文档、不动代码**：`docs/开发手册.md`（**544 → 875 行**）、`README.md`、`.agent/plan/PLAN.md`、
  `.agent/main/{MEMORY,PROJECT_MEMORY,SESSION_SUMMARY}.md`、`AGENTS.md`。
- 手册：§4.1/§4.2 按**实际文件**重建（删掉从未存在的 `game/Level.ts`，补 `Projection`/`Ui`/`Progress`）；§4.3 补结算三态与相态日志；
  §5.5–§5.9 恢复并更新；§7.2.1 新增三条实测坑（子坐标原点=位置−anchor×尺寸 / 投影空间≠绘制层空间 / PowerShell 必须 CRLF）；
  §8 补本地构建与单测入口；§9 验收表逐条对齐证据；§10 补当前进度与截止；§11 R1/R2/R3/R4/R6/R8 更新、删除残留的 R7 表格行；
  §12 设计分辨率标为已解、LICENSE 勾掉；§13 目录树补齐。
- 记忆/守则：相对拖动交互模型、触摸验收现状（桌面合成鼠标 ✅ / 手机待复测）、构建 36/36 纪律、`tools/dora-build/` 路径纠正；
  `AGENTS.md` 新增三条硬约束（anchor、视口重建、CRLF）。
- **本轮续（同一会话）**：手册 **§6 参数表按 `game/Config.ts` 逐项回填实际值**（并标明每项被哪里使用 / 被什么证据守着，
  以及 `DesignWidth/Height`、`MaxStepsPerFrame`、`CameraTiltMin/Max` 目前**已定义未被消费**）；
  `docs/DSH-vs-Dora内置Agent-能力对照.md` 按新状态对齐；§5.9 资产表加“已入库待接线”；§13 补 `.glb` 与 `GltfModelProbe`。

#### 2）事故与恢复：手册 §5.5–§5.9 曾被误删

- **事故**：提交 `31cba6e`（会话 20）用脚本做“把自适应段落并进 §5.4”的整段替换时，切片写坏，
  **把 §5.5 轨迹渲染、§5.6 关卡数据、§5.7 输入与交互、§5.8 结算判定、§5.9 视觉/适配整段删掉了**，
  而 §2/§3/§5.1/§12 里仍留着对这些小节的引用 ⇒ 手册出现**悬空引用**，且当时没有察觉（提交后无人复查章节完整性）。
- **发现方式**：会话 21 做文档同步时按引用逐个找 §5.7/§5.8/§5.9，才发现 `grep '^### 5\.'` 只剩 §5.1–§5.4。
- **恢复**：从误删前的提交 `21a5c78` 取回五节原文，再按会话 15/18/19/20 的现状改写 ——
  尤其把两处**已被推翻的历史说法**纠正：① “触摸层必须 `anchor=(0.5,0.5)`”（会话 18 证明这正是命中框只剩左下象限的根因）；
  ② “面板底板 `touch: true` 吞掉点击”（会话 15 已移除全屏独占层）。
- **教训（写入流程）**：
  1. **大段替换型文档编辑，提交前必须 `git diff --numstat` 看行数、并 `grep` 抽查被删区域的关键小节标题** ——
     本次事故的改动若当时 diff 一下行数（-200 行级别）就会立刻暴露；
  2. **跨节引用是探针**：改完文档后，把所有 “§x.y” 引用逐个验收一遍，能抓出“引用了不存在的小节”这类破坏。

#### 3）S3.1 资产入库：11 个 Blender `.glb`（提交 `ad007ca`）

- **资产**：`Assets/Model/*.glb` —— `Planet_{Earth,Mars,Venus,Neptune,Jupiter,Saturn}`、`Sun`、`BlackHole`、`Asteroid_01`、
  `Probe_Voyager`、`Probe_Voyager_v1`（土星环随 `Planet_Saturn` 模型自带）。
  **合计 11 个 / 0.21 MB（211,528 B）/ 3136 三角面 / `images=0`（零贴图）**。
- **运行时证据（`Test/GltfModelProbe.ts` → `.agent/test-results/s3-gltf.txt`）**：
  `status=PASS`、`built=11/11`、`draws=46`、`visible=46`、`triangles=3136`、`missing=`（空）；
  另逐模型记录材质数（Jupiter 3 / Saturn 2 / BlackHole 2 / Probe_Voyager 12 / Probe_Voyager_v1 5 / 其余 1）。
- **交叉验证**：用 Node 离线解析每个 GLB 的容器与 accessor 计数，得到三角面总和同为 **3136**（逐面吻合），
  各文件 80 / 80 / 80 / 80 / 320 / 464 / 80 / 656 / 20 / 1112 / 164 —— 与运行时统计一致 ⇒ 模型确实被引擎完整吃下。
- 截图 `.agent/test-results/s3-gltf.png` 已人工查看（行星 / 环 / 探测器造型与朝向正常，faceted 低多边形风格与愿景 §6 一致）。
- ⚠️ **尚未接线**：`game/Scene.ts` / `init.ts` 目前仍用代码生成的 `Sphere.gltf` / `Ring.gltf` / `Probe.gltf`；
  把 `.glb` 接进场景是 **S3.1 的活**。手册 §5.9 已标“已入库待接线”，避免读者误以为已经在用。

#### 未验证 / 下一步

- **未验证**：`.glb` 在**真实关卡**里的取景/朝向/配色（当前只有冒烟探针的陈列截图）；
  手机浏览器复测；`.glb` 与 `getMaterial(i)` 逐实例染色的接线正确性（探针里染色成功不等于场景里接线正确）。
- **下一步**：S3.1 接线 `game/Scene.ts`（行星按关卡换模型、探测器换 `Probe_Voyager_v1`、`Sun`/`BlackHole` 作引力源变体）→ 出关内截图验收 → S3.2 轨迹发光与星空。
- 另有并行线路在做**星空方案**的烟雾测试（`Test/Star*.ts`、`Test/Shader/`，未定稿）——**尚未写入手册**，等定稿再落。

### 会话 20 · 手机真机两处问题的根因与修复：视口尺寸变化没处理

**用户真机反馈（Web 导出在手机浏览器）**：「预览线又跑到别的地方了；竖屏情况下没有适配」，并建议「开发时把分辨率调竖屏」。

**根因**：所有几何（UI 层尺寸、触摸层尺寸、投影原点、相机宽高比）都在**启动时**读一次 `View.size` 就算死了；
而手机浏览器的画布尺寸在启动后还会变一次（地址栏/视口稳定、全屏切换等）⇒
容器的子坐标原点（= 位置 − anchor×尺寸）与新区域覆盖都还停在旧尺寸上：预测线整体偏移、新区域收不到触摸。
桌面端此前两次竖屏实测都是「先改成竖屏再启动」，所以没能暴露这个问题。

**修复**（`init.ts`）：

- 面板创建抽成 `buildPanels()`（可重复调用）；新增 `relayoutForViewport()`：
  隐藏旧面板与旧关卡运行时（**隐藏 + 断触摸，不销毁**）→ 更新 `viewW/viewH` →
  更新 `uiLayer` / `levelLayers[i]` 的 `size` → 重建面板 → 恢复当前状态（在关卡里则重建该关并回到 Aiming，否则回到选关）。
- 监听 `Director.entry.onAppChange(name === 'Size')` 触发重建；尺寸没变则直接返回。
- 新增开发工具 `tools/input-inject/set-window.ps1`（一键竖屏/横屏；客户区 400×710 → View.size 601×1066）。
  ⚠️ 该脚本必须 CRLF 换行：Windows PowerShell 5.1 的 here-string 在纯 LF 下解析失败（踩过）。

**验证（运行中改窗口 = 复现手机场景）**

- 日志：`started: 6 levels, unlocked=5, level select shown`（横屏 2192×1231）→ `viewport rebuilt: 601x1066`
  → `phase -> Aiming (L1)` / `enter L1 直飞`（点击用的是**竖屏坐标**，说明重建后的 UI 位置正确）。
- 截图人工查看：重建后的选关界面是 **2 列×3 行、六关全可见、底部提示归位** ✓；
  重建后进关的瞄准态：预测线**从探测器出发**笔直向上 ✓（修复前正是"跑到别的地方"）。
- 构建 36/36；临时诊断代码已全部移除。

**仍待真机复测**：Web 导出包在手机浏览器里重跑一遍（导出 → 手机打开 → 选关 → 拖 → 松手 → 结算）。

### 会话 19 · 竖屏（交付形态）实测：修掉两处布局溢出

**背景**：用户问「最后要交竖屏游戏，现在窗口还是横屏，有影响吗？」—— 影响确实有，而且是被绝对值的布局下限害的。

**实测方法**：用 Win32 MoveWindow 把引擎窗口改成竖屏手机比例（客户区 400×710），引擎渲染尺寸 View.size 随之变为 **601×1066**（= 客户区 ×1.5，引擎固定系数）；再用合成输入跑完整流程并截图（选关 / 瞄准 / 结算）。

**发现的两处溢出（有截图证据）**

| 位置 | 现象 | 原因 |
|---|---|---|
| 关卡选择 | **L6 被裁一半、底部提示「完成一关即解锁下一关」整条被挤出屏外** | 六关竖排：6×130 + 5×18 = 870 > 可用 636 |
| 结算面板 | **两个按钮横向戳出卡片外**（按钮 ≥560 vs 卡片 529） | 按钮宽写死 max(560, …) |

**修复**（game/Ui.ts + game/Hud.ts）

- 关卡选择：列数随宽高比自适应 —— **竖屏 2 列×3 行**、横屏 1 列×6 行；按钮尺寸由可用空间推算；headerH/footerH 改为视高比例（含夹紧），副标题与底部提示位置改为相对定位。
- 结算面板：按钮宽 = 卡片宽 − 60（去掉 560 硬下限）；卡片高于屏幕时先压按钮高度。
- MinButtonWidth/MinButtonHeight 从 560/130 降到 **160/72**（只保「小到点不中」的地板）。
- 手册 §5.7 第 10 条重写、新增第 13 条（View.size = 客户区 ×1.5）。

**验收证据（截图人工查看）**

- 竖屏 601×1066：选关 **2×3 全部可见**、底部提示归位 ✓；结算卡片居中、**按钮完全在卡片内** ✓；瞄准态预测线从探测器出发且正常弯曲 ✓。
- 横屏 2024×1231（回归）：选关单列六行全部可见 ✓；结算按钮在卡片内 ✓。
- 竖屏实跑闭环：点 L1 → 拖动 → phase -> Flying → **result = success（借力成功）** → 结算 ✓。
- 构建 36/36；提交后工作区 clean。

**仍待人工的设备侧验收**：Web 导出包在**手机浏览器**里的竖屏表现（本机只能模拟竖屏比例，真机的 DPR/视口与手指遮挡仍需一次实机确认）⇒ 设计分辨率待定项可关闭（布局已与分辨率解耦）。

### 会话 18 · 交互改为"相对拖动"，并修掉触摸命中框只有左下象限的问题（已修，双证据验收）

**用户新需求（2026-09-24）**：「按哪里都能瞄准；松手才发射；按下的时候预测线回到直飞，拖动才改变方向。」

**这一轮修了两件事**

#### 1）触摸命中框只剩"左下象限" —— "不是按哪里都能瞄"的真因

`createAimInput` 的根节点原本 `anchor=(0.5,0.5)`。节点的**子坐标原点是「位置 − anchor×尺寸」**，
于是整棵子树（含触摸层）被再推走半个屏幕：命中框只剩左下象限 ——
实测坐标可证：view x ≤ ~1012 与 y ≤ ~615 处按下有效，之外**完全无事件**（当时误以为是"多进程注入"问题）。

修复：`root.anchor = Vec2(0, 0)`（父层 `levelLayers[i]` 的子空间是"左下原点绝对像素"，
取 (0,0) 后命中框正好等于整屏，且 `touch.location` 与 `localToOffset` 的假设一致）。

**证据（六点网格实测，每点都重新进关）**

| 按点（view） | 结果 |
|---|---|
| (200,200) 左下 | `began view=199,199 local=199,199` |
| (1800,200) 右下 | `began view=1800,199 local=1800,199` |
| (200,1000) 左上 | `began view=199,1000 local=199,1000` |
| (1800,1000) 右上 | `began view=1800,1000 local=1800,1000` |
| (1012,615) 中心 | `began view=1011,615 local=1011,615` |
| (600,400) 偏左 | `began view=600,430 local=600,430` |

#### 2）瞄准语义改为"相对拖动（虚拟摇杆）"

旧模型：方向 =「探测器 → 手指」，力度 = 按下点到探测器的距离 —— 按下瞬间就已经按距离拿到力度，
方向也由按下点决定，手感与预期不符（用户原话："按下的地方也不是飞行器所在的地方"）。

新模型（手册 §5.7 已同步）：**按下点 = 摇杆零点**；按下瞬间瞄准归零到"直飞"（正对目标、最小力度）；
之后的**位移**决定方向与力度（位移方向 = 发射方向，长度 = 力度，夹紧 min/max）；松手才发射。
实现上复用 `computeAim`：把按下点当作它的 `probeOffset`；程序化缝隙 `handleOffset/handleLocal` 的参数
语义同步改为"相对按下点的位移"。

**证据（合成输入 + 截图 + 日志）**

- 按下不动（在 view≈(1350,675) 远离探测器处按住）：截图显示预测线**从探测器笔直向上**（直飞）✓
- 向右拖动：截图显示预测线**水平指向右侧**；日志 `ended unit=1.00,-0.00 power=1.00`（方向=右、力度满）✓
- 松手：日志 `phase -> Flying (L1)` ✓（松手才发射）
- 干净构建端到端（无诊断代码）：进关 → 拖动 → `phase -> Flying` → `result = missed` → `phase -> Result` ✓
- 单测：`SUMMARY passed=7 failed=0 total=7` ✓（`computeAim` 纯函数语义未变，HudTest 17 断言全过）

**工具链教训**：`.temp/` 下留过一份 `mousectl.ps1` 旧副本，参数不一致导致脚本**静默失败**
（报的是 `A parameter cannot be found`，但输出被 Out-Null 吞掉，白跑一轮）。旧副本已删除，
仓库版 `tools/input-inject/mousectl.ps1` 为唯一入口，并新增 `press/move/release` 与 `-HoldMs` 支持分段验证。

### 会话 17 · 预测线整体平移半个屏幕：绘制层的坐标空间变了（已修，视觉+单测双验收）

**用户真机反馈**：「线不是从飞行器位置发射出去的；鼠标按下的地方也不是飞行器所在的地方」——
会话 16 修好接线后暴露出来的第二个问题（当时拖动已能响应，只是画错了地方）。

**根因（用标记点实测出来的，不靠推**）**：S2.2 把 2D 层从"直接挂 `Director.ui`"改成"挂 `levelLayers[i]` / `uiLayer` 容器"，
**绘制层的坐标空间随之改变**：

- `project()` 输出 = **中心原点偏移**（+Y 向上）—— 瞄准数学与 `Trajectory` 都按这个约定写；
- 而 `levelLayers[i]`（`size=(W,H)`、`anchor=(0.5,0.5)`、`position=(0,0)`）的实际子空间是 **左下原点绝对像素 [0,W]×[0,H]**。

实测方法：在该层画 (0,0) / (W/2,H/2) / (W/2,H/2-530) 三个标记点后截图 ——
红点落在屏幕左下角、绿点落在正中心、黄点**正好压在探测器模型上**；而探测器投影值本身是 (0,-530)。
结论：预测线被整体平移 (+W/2, +H/2) 半个屏幕 —— 静止时整条线在画面外（截图里根本看不到线），拖动时才出现在错误位置。

**修复**：`game/Trajectory.ts` 的 `projectPolyline()` 增加**显式**的层原点参数 `originX/originY`；
`TrajectoryOptions` 增加 `layerOriginX/layerOriginY`（`defaultOptions()` 取半个 `View.size`，附实测依据）。
不再把"这一层是什么空间"当成隐式全局 —— S2.2 的错位正是这么来的。

**验收证据**

- **视觉**：`App.saveScreenshot` → PIL 转 PNG → 人工看图：预测线**从探测器出发**笔直向上 ✓（修复前同角度截图里没有线）。
- **单测**：新增回归断言 `layer-origin-is-half-view`（默认层原点必须等于半个视图）；TrajectoryTest 10 → **11** 断言；
  全套 `SUMMARY passed=7 failed=0 total=7` ✓。
  这条断言有判别力：第一版改动（读全局 `View.size` 而非显式参数）当场被 `basis-matches-project` 判失败，确认测试抓得住。
- **端到端**：点选关 → `phase -> Flying`（拖动松手）→ `result = missed` → `phase -> Result` ✓。

### 会话 16 · 真机"进关卡拖不动"的真正根因：瞄准层没接到状态机（已修，已自动验收）

**上一轮的结论是错的，如实纠正**：会话 15 判断为"S2.2 的全屏吞触摸层独占点击"，据此移除了两块全屏底板的
`touch: true` 并加了"隐藏即断触摸"的兜底。那些加固本身是对的（与引擎自身 UI 写法一致），但**不是这次故障的原因**。

**真正的根因**：`init.ts` 在 S2.2 重写时**漏掉了把瞄准层接到状态机的两行**。旧版（`7cb72b0`）里有
`aim.onDrag((a) => game.onAimDrag(a))` 与 `aim.onRelease((a) => game.launch(a.velocity))`，新版没有。
后果：触摸能到达瞄准层，但拖动不更新 `core.aim`（预测线不跟手）、松手也不发射 —— 玩家的感受就是"进关卡拖不动飞行器"。

**怎么找到的（新增能力：合成鼠标输入注入）**：Dora 的 `Touch` 同时代表鼠标点击，用 Win32 合成鼠标事件驱动窗口
即可复现真实触摸路径。先实测几何：`View.size = 2024×1230`（逻辑坐标，UI 用它），窗口客户区 1349×820，
`client_x = view_x·(clientW/2024)`、`client_y = (1230−view_y)·(clientH/1230)`。
随后在 `init.ts` 临时挂一层最顶层监听层（`swallowTouches=false`）记录每次触摸，并在瞄准层回调里打点 ——
一次拖动就同时拿到"事件是否到达"与"瞄准层是否收到"。

**证据（真实日志）**

- 修复前：`[aim] tapBegan enabled=Y nodeTouch=Y view=1011,480` → `[aim] tapEnded enabled=Y dragging=Y`，
  但**没有任何 `phase ->` 变化** —— 触摸到了、状态机没动（接线缺失的指纹）。
- 修复后（干净构建、已移除全部诊断代码）：点选关 `enter L1` → 拖动松手 `phase -> Flying (L1)` →
  `result = missed` / `phase -> Result` → 点「重试本关」`phase -> Aiming (L1)` →
  再拖再发射 `phase -> Flying (L1)` → `result = missed` / `phase -> Result`。

**新增工具（已入库）**：`tools/input-inject/mousectl.ps1` + README（坐标换算、常用点位、回归流程模板）。
触摸类改动不再必须人工点一次；真机多点触控/手势差异仍建议抽查。`AGENTS.md` 的验证章节同步更新。

### 会话 15 · 真机验收发现的触摸 bug：全屏"吞触摸层"独占点击（已修，待复测）

**用户真机反馈**：「进入关卡不能拖动飞行器了」。日志可见用户确实点进了 L1：
`built L1 L1 直飞 / phase -> Aiming (L1) / enter L1 直飞`（`log.txt` 21:51:08）—— 即**关卡能进、瞄准收不到触摸**。

**根因（代码定位）**：S2.2 给结算面板与关卡选择各加了一层**全屏、`touchEnabled + swallowTouches`** 的底板
（`createPanel(..., { touch: true })`），用意是"吞掉落在面板上的点击"。问题在于：

- 这两层在节点树里排在**瞄准层之后**（`init.ts` 先建 `levelLayers` 再建 `uiLayer`），全屏 + `swallowTouches`
  意味着它们会独占覆盖范围内的点击；
- `hide()` 只关 `visible`，**没有关 `touchEnabled`** —— 选关界面隐藏后仍参与命中，
  于是瞄准层永远收不到触摸，表现就是"进关卡拖不动"。
- 为什么之前没发现：探针用 `handleOffset` 程序化驱动瞄准，**完全绕过引擎命中判定**；
  `Touch` 是私有构造，无头注入不了真实触摸 —— 这正是"人工触摸验收"不可省的原因。

**修复（`game/Hud.ts`）**：两块全屏底板**都不再设 `touch: true`**（面板不需要代劳吞点击：
结算态瞄准层本就 `setEnabled(false)`，选关期间没有任何关卡处于 Aiming）；并做兜底 ——
`hide()` 里一并 `setEnabled(false)` 面板按钮/六个关卡按钮，任何"隐藏但仍命中"的行为都不会再吞掉拖动。

**已验证的证据**

- `node tools/dora-build/build.mjs --all` → **36/36 成功**；编译产物 `game/Hud.lua` 里
  `swallowTouches = true` **只剩瞄准层一处**（`touchEnabled` 写入也只剩瞄准层的创建与 `setEnabled`）——
  即全屏独占层已被彻底移除。
- 整项目 `POST /run init.lua` → `running=true`，日志 `started: 6 levels, unlocked=0, level select shown`，
  `POST /stop` → `running=false`（启动路径未破坏）。

**未验证**：真实触摸复测（需用户再点一次）——本次修复的判定依据是"移除全屏独占层"，
真实命中判定无法无头执行。
### 会话 14 · S2.2 结算面板 + S2.3 关卡选择与解锁进度

**已实现（源码）**

- `game/Ui.ts`（新）— 视图空间 2D 原语：`createPanel` / `createLabel` / `createButton`
  （自身即可点节点：底色 + 居中 Label + `touchEnabled`/`swallowTouches`/`onTapEnded` + 按下换底色）。
  配色、字体名、触屏下限（高 ≥ 130 / 宽 ≥ 560）集中在这个文件；颜色通道用除法而非位移运算。
  节点统一 `anchor = (0,0)`、局部绘制 `[0,w]×[0,h]` —— d.ts 没写明 anchor 与命中矩形的关系，
  `anchor = 0` 时两种解释重合，画出来的矩形与命中矩形必然一致。
- `game/Progress.ts`（新）— 解锁进度：`clampUnlocked` / `advanceUnlocked`（纯函数；只有 success 解锁，
  重玩旧关不回退）+ `loadProgress` / `saveProgress`（一行 `unlocked=N`，损坏即 0，**不抛错**）。
  ⚠️ 任务简报写的是 `App.writablePath`，但 v1.9.3 的 d.ts 里**只有** `Content.writablePath`，已按引擎声明改。
- `game/Hud.ts`（扩展，277 → 586 行）— `createResultPanel`（半透明全屏底 + 0.88 视宽卡片 +
  4 行内容 + `重试本关` / `返回关卡选择`）与 `createLevelSelect`（`选择任务` / `已解锁 N / 6` /
  六关竖排 / `完成一关即解锁下一关`；未解锁整块不可点）。
  **顺带修掉一个多关并存的真坑**：`AimInput.setEnabled` 现在同步 `touchLayer.touchEnabled` ——
  `swallowTouches` 的全屏层会独占触摸，未激活关卡的层会把整个屏幕的点击吞掉。
  （另注意 `onTap*` 注册时会把 `touchEnabled` 置回 true，初始关闭必须写在注册之后。）
- `game/Game.ts`（改）— `GamePhase` 增加 `'LevelSelect'`；新增 `coreBackToSelect`（**仅 Result 态**）
  与 `Game.backToSelect` / `Game.startLevel`。`coreLaunch`/`coreUpdate`/`coreRetry` 的语义未改。
- `init.ts`（改，129 → 266 行）— 启动即 LevelSelect；`ensureLevel(i)` **惰性**建每关运行时
  （`Node3D()` 容器 → `buildScene` → 相机/机架/轨迹/矄准 → `createGame`），切关只切 `visible`
  + `Director.pushCamera` + `startLevel`，**不销毁节点**；每关 2D 层先建、UI 叠层最后建
  （后建的画在上面 ⇒ 面板永远盖住轨迹线）；仍然只有一个 `threadLoop`，只驱动当前激活关。
- `Test/ProgressTest.ts`（新，36 断言）已加进 `Test/UnitRunner.lua` 的 modules；
  `Test/UiProbe.ts`（新运行时探针，5 张截图 + 文本化视觉判定）。

**已验证的证据**

- **编译（引擎）**：`Dora.exe cli build -p <proj>` → 69 个文件全部 `Compilation complete`；
  `[error]` **69 条全部**是 `Duplicate compiler file: lualib_bundle.lua`（已知噪音），
  TS 诊断 0 条（`nonLualibErrors=0`、`tsDiagnostics=0`）。本地 tstl 全量 36/36 通过。
- **单测**：`Test/UnitRunner.lua`（`POST /run`）标记文件 `.agent/test-results/unit-summary.txt`：
  `Test.ProgressTest :: passed | checks=36 failures=0`，`SUMMARY passed=7 failed=0 total=7`。
  覆盖：clamp 非法输入（NaN / ±Infinity / 负数 / 关卡数 0 / 非整数）、advanceUnlocked（success 解锁 /
  missed、crashed 不解锁 / 最后一关不越界 / 不回退）、存档往返（含垃圾内容、多行、越界夹紧，跑完还原）、
  `coreBackToSelect` 的 Aiming / Flying / Result / 重复调用四种相态。
- **运行时探针**（`Test/UiProbe.lua`，标记 `.agent/test-results/s22-ui.txt`）：`RESULT=PASS`，failures=0，
  5 张截图落盘（均为 2024×1230×4 = 9,958,098 字节）：
  `s22-result-success.tga` / `s22-result-missed.tga` / `s22-result-crashed.tga` /
  `s22-levelselect.tga`（任务要求的四张）+ `s22-nopanel.tga`（同机位对照帧），全部在
  `.agent/test-results/`。
  自动判定三条：截图可 TGA 解析；面板帧区域检测非 NONE（文字真的渲染了）；
  面板/选关帧平均亮度低于同机位无面板基线（24.3 / 21.1 < 26.2 ⇒ **面板确实画在场景与轨迹之上**）。
  报告里可直接读到卡片 bbox =(120,228)-(1908,996)、900×156 的主按钮亮块、
  6 个 828×~136 的关卡按钮、以及标题/副标题/说明行的连通域位置 —— 与布局计算逐项吻合。
- **关卡切换**（同一探针内）：照 `init.ts` 的调用序列再建第二关并 L1 → L2 → L1 切回，
  `switchProblems=0`，两关都回到 `Aiming`（覆盖“惰性建关 + visible / pushCamera / startLevel”这条真风险路径）。
- **整体入口**：`POST /run {file: init.lua, asProj: true, projectRoot: <proj>}` 运行约 7 秒无崩溃，
  日志三行：`progress file: %APPDATA%\IppClub\DoraSSR\escape-velocity.progress` /
  `progress loaded: unlocked=0` / `started: 6 levels, unlocked=0, level select shown`；
  `POST /stop` 后 `running=false`。
- **存档落盘**：`%APPDATA%\IppClub\DoraSSR\escape-velocity.progress`，10 字节，内容 `unlocked=0`
  （**在项目之外**，不污染仓库）。

**未验证**

- **真机触摸**：按钮点击与拖拽矄准的真实 `touch.location` 仍无实机标定（`Touch` 是私有构造，
  无头注入不可能）。探针走的是程序化调用路径，触摸坐标系仍需人工点一次（手册 §12 已记为待办）。
- **一次完整真人对局**（选关 → 拖 → 松手 → 飞行 → 结算 → 解锁 → 返回选关）未人工跑过；
  “success 解锁并写盘”目前由 `ProgressTest` 的纯函数断言 + `saveProgress`/`loadProgress` 往返守着，
  尚未在真实对局里贯穿。
- **视觉美观**：Agent 只能做几何/亮度层面的自检；卡片留白、字号、按钮配色需人工看图
  （`.agent/test-results/s22-*.tga` 需转 PNG）。

**下一步**：人工验收（转 PNG 看四张截图 + 真机点一次按钮）→ 关掉 S2 → 进 S3 视觉。

### 会话 13 · 工具链与通路（改用 DSH 接管开发）

**背景**：内置 Agent 的会话上下文已涨到 **40–52 万 tokens/请求**，其自动压缩（`[Memory] compression tool-calling attempt 1/5…3/5`）连续被服务端 524 掉（证据：引擎 `log.txt`）。开发方式改为**外部 Coding Agent（DSH）+ 引擎本体**：DSH 负责读写代码、编译、驱动引擎与验证，引擎只当运行时。

**已实现（工具链，均已实测）**

- **引擎 API 通路**：关掉引擎窗口设置里的「访问验证 / Auth Required」（`Script/Dev/Entry.lua:1026` 的 `HttpServer.authRequired`）后，8866 端口 API 无鉴权可用。实测：`POST /status` → 200；`POST /run`（项目入口）→ `running:true runId:3` 且日志出现 `game started: L1 直飞`；`POST /stop` 后 `run/status` → `running:false`；`POST /log` 可取引擎日志。
- **构建两条路**：① 引擎侧 `Dora.exe cli build -p .` → 全量 `Compiling … Compilation complete`，0 诊断（`[error] Duplicate compiler file: lualib_bundle.lua` 为已知噪音）；② 本地 tstl 工具（`build.mjs`，不依赖引擎与浏览器）。
- **本地构建标定**：**32/32 个文件与仓库已提交的 `.lua` 逐字节一致**（含 16 KB 的 `Test/Vision.lua`）。关键参数：`typescript-to-lua@1.37.1` + `typescript@5.9.3`（**必须 `npm i --legacy-peer-deps`；TS 6.0.2 会静默产出 `Math:sqrt(...)` 错码**）、`luaTarget=Lua55`、`luaLibImport=Require`、TAB 缩进、`luaExternalModules:['Dora']`；`-- [ts]: file` 与行尾 `-- <行号>` 标记属 IDE 后处理（已复刻）。
- **单测回归入口**：新增 `Test/UnitRunner.lua`（独立入口需显式 `require("Dora")`），批跑 6 个单测模块 → `.agent/test-results/unit-summary.txt`。**基线：6 模块 127 断言 0 失败**。
- **视觉验证**：引擎截图是未压缩 TGA（不支持直接读），改用 Python PIL 转 PNG 后由 DSH 原生看图；已实际查看 `s21-steady.tga`。
- **许可补齐（S4.4 提前完成）**：`LICENSE` 换为 gnu.org 官方全文（**34,523 B / 661 行，SHA256 双侧一致**）；版权通知移入 `README.md`，补作者 **Dragonzhi**、引擎版本、活动链接；已测设备填 **Web 浏览器**。
- **内置 Agent 提示词存档**：`.agent/dora-agent-prompts.md`（摘录 `DEFAULT_AGENT_PROMPT_PACK` 全文 + 工具与其余提示词位置索引）。附带发现：内置 Agent **其实支持 `/compact` 与 `/clear`**（`DoraAgent.ts:688`），只是界面没暴露。

**未验证 / 风险**

- 关闭「访问验证」后，同一局域网内其他设备也可无鉴权访问引擎 API（本机开发可接受，勿在不安全网络下长期关闭）。
- 本地构建工具目前在 `.temp/dora-build/`（gitignore 内），**尚未纳入仓库**；是否提升为 `tools/dora-build/` 待定。
- 引擎内置 tstl fork 的具体版本号无据可查，等价性由 32 个文件逐字节验证支撑。

**下一步**：S2.2 结算面板 + S2.3 关卡选择与解锁（进行中）。

### 会话 12 · 修复预测线垂直镜像（用户反馈）

**用户反馈**：“预测线渲染很奇怪，并不是一个准确的从探测器出发的线段。”

**根因（经多轮诊断定位）**：

- `View3D.getRayDirection` 的 viewPoint 是 **左下原点 +Y 向上**；
  S0.3（R4）标定时误判为“左上原点 +Y 向下”（中心点检验对 Y 翻转不敏感）。
- `project()` 继承了该镜像空间，`toOverlay()` 又“按图像坐标”多翻一次 y，
  ⇒ **所有 2D 覆盖层相对于真实渲染垂直镜像于屏幕中心**。
- 次要 bug：预测线只在拖动时重画，重试后相机 lerp 回矄准视图期间线会冻结在半途。

**诊断方法（严格实证，不靠猜）**：

1. `Test/ClearTest.ts` — 先排除“DrawNode.clear() 失效”假说（实测 clear() 正常）。
2. `Test/ProjCheckProbe.ts` — 对照我的 project() 输出与引擎 `getRayDirection`：
   射线完全一致（说明朝向正确），但用 `pick` 与截图位置对不上。
3. `Test/VerdictProbe.ts` — **颜色标记球最终裁决**：探测器染绿、火星染红、
   注视点放白球。结果：白球精确渲染在窗口中心（主点正确），
   而绿/红球与 project() 输出**恰好关于屏幕中心镜像** → 定案。

**修复**：

- `game/Projection.ts`：`toOverlay()` 改为恒等变换；头部约定改为“左下原点 +Y 向上”。
- `game/Trajectory.ts`：`projectPolyline` 不再翻转 y。
- `game/Hud.ts`：`localToOffset/offsetToLocal` 统一为 +Y 向上（`local.y - H/2`）；
  ⚠️ `computeAim` 的 `uy = -dy/len` **保留负号**（平面 y 轴与偏移 y 轴反向）。
- `game/Game.ts`：矄准态每帧重画预测线（不只在拖动时）。
- `Test/HudTest.ts`：坐标换算与方向断言按修正后语义更新。

**已验证的证据**：

- **编译**：全量 `build` 33/33 通过。
- **单测**：`TrajectoryTest` 10、`HudTest` 17、`GameTest` 30、`LevelDataTest` 34 —— 全过。
- **运行时**：`LineDirProbe` 两张 ASCII 图显示预测线现在**从探测器（屏幕下方）
  朝目标（上方）延伸**；`GameProbe` 完整循环 `RESULT=PASS`；
  `init.ts` 加载 L1 运行 3 秒干净退出。
- **副收获**：修正后屏幕方向语义 = 世界 +z（靠近相机）在屏幕**下方**
  （与真实相机一致，近景在画面下方）。游戏里探测器在下方、目标在上方，向上发射。

**待办**：S2.2 结算三态面板、S2.3 关卡选择与解锁进度。

### 会话 11 · S2.1 六关数据与目标判定

**已实现（源码）**

- `game/LevelData.ts`（227 行，纯数据 + 纯函数，不 import 'Dora'）：
  - 六关完整定义（愿景 §5 定稿曲线，每关只引入一个新旋钮）：
    1 直飞（无引力）/ 2 第一次弯曲 / 3 从背后抄过去（必须借力）/
    4 它动了（公转+时机）/ 5 两连弹 / 6 贴着过去（容差收窄）
  - 每关含：任务简报（金唱片/1977 风味）、行星物理+视觉、目标规格、边界与步数
  - `findGoalIndex` — 飞行采样点中找第一个进入目标容差的索引
    （目标行星移动时逐点用 t 时刻位置判定）
  - `scaledPlanets` / `getLevel` / `levelCount`
- `game/Game.ts` — 目标判定接入：
  - `resolveResult(outcome, goalIndex, goal)` 替代 `resolveOutcome`
    （优先级：到达目标 > 逃逸达成 > 撞毁 > 错过）
  - **结算在发射瞬间即完全确定**（轨迹+goalIndex+outcome 都已知）
  - 到达目标后飞行在到达点截断；回放时间吸附到终点（冻结帧停在到达瞬间）
- `init.ts` — 从 LevelData 加载第一关（S2.3 接入关卡选择）
- `Test/GameTest.ts` 扩到 30 断言；新增 `Test/LevelDataTest.ts`（34 断言）

**已验证的证据**

- **编译**：全量 `build` 28/28 通过。
- **单测**：`GameTest` = `passed checks=30`；`LevelDataTest` = `passed checks=34`
  （结构有效性、容差>半径、findGoalIndex 静止/移动目标、**每关可玩性硬门**）。
- **入口**：`init.ts` 加载 `L1 直飞` 运行 3 秒干净退出。

**调参过程（数据驱动）**

- 初版可玩性扫掠（轴向 5×5 网格）报 L3/L5 不可达 → 诊断扫掠发现两关其实
  各有 6 个成功解，只是解在斜向速度上（如 v=(-16,-14)）→ **测试扫掠改为
  角度×力度采样（12 方向 × 4 档）**，真实覆盖玩家连续输入空间。
- 回放每帧跳 4 个索引会越过 goalIndex → 收束时吸附 `flightTime = endIdx * dt`。

**未验证 / 待办**

- S2.2 结算三态面板（当前仍是最小 Label）。
- S2.3 关卡选择与解锁进度（含持久化）。
- 关卡手感（难度曲线）需真人试玩校准。

### 会话 10 · S1.5 状态机与主循环（S1 完成）

**已实现（源码）**

- `game/Game.ts`（280 行）— 状态机 + 主循环逻辑：
  - `GameCore`（纯逻辑可单测）：`coreLaunch`（发射时预推演整段飞行）/
    `coreUpdate`（回放推进 + 结局判定）/ `coreRetry` / `coreProbeIndex`
  - `resolveOutcome` — 物理结局 → 三态（§5.8 的 S1 简化版：escaped=success）
  - `createGame(level, deps)` — 驱动场景/相机/轨迹/矄准，回调 `onPhase`/`onResult`
  - **确定性设计**：发射瞬间用与预测线相同的 `simulate` 预推演，之后逐帧回放
    → “预测线看见的就是飞出来的”
- `init.ts` — 从 S0 静态场景改为**真实游戏入口**：组装全部模块 + 单一 `threadLoop`
  + 结果 Label + 重试点按层（仅 Result 态启用）
- `game/Config.ts` — 新增 `FlightPlayback=2`（回放速度）
- `Test/GameTest.ts`（22 断言）、`Test/GameProbe.ts`（完整循环探针）

**已验证的证据**

- **编译**：全量 `build` 26/26 通过。
- **单测**：`Test/GameTest.ts` → `passed checks=22 failures=0`
  （结局映射、发射守卫、回放时长与 FlightPlayback 一致、重试守卫与重置、
  索引夹紧、两次完整流程结局一致）。
- **运行时（`Test/GameProbe.ts`）**：完整循环 `RESULT=PASS`：
  - 拖拽 → `power=1.000`、`vel=(12.09,-18.38)` → 预测线可见（ASCII 图弯曲亮线）
  - 发射 @f20 → Flying → 飞行 6.2s（1500 步回放）→ `Result(missed)` @f395
  - 重试 @f406 → 回到 `Aiming` ✓
- **真实入口**：`init.ts` 运行 3 秒 `running=true`，`stopEntry()` 后干净退出。

**踩到的坑（本次新增）**

- **`threadLoop` 回调没有参数**：帧间隔要用 `App.deltaTime`（签名是 `(this: void) => boolean`）。
- **增量构建再次未转译 `Config.lua`**：新增 `FlightPlayback` 后运行时 nil → 全量重建解决。
- 探针脚本自身两个 bug：分析块门条件用了未赋值的 `retryFrame`（导致重试前就终止）、
  `App.elapsedTime` 在此环境恒为 0（改用帧号）。

**局限（如实记录）**

- 真实触摸的“松手发射”与“点按重试”无法无头验证（`Touch` 私有构造），
  需人工校对（与 S1.4 同一校准点 `localToOffset`）。
- 结算 UI 是最小版（一个 Label）；正式三态面板与“返回关卡选择”在 S2.2/S2.3。

### 会话 9 · S1.4 拖拽矄准与发射

**已实现（源码）**

- `game/Hud.ts`（273 行）— 拖拽矄准：
  - `computeAim(probeOffset, touchOffset, maxDragPx)` — 纯计算：方向 = 探测器→触摸点，
    力度 = 拖动距离/满力距离（夹紧），速度线性映射 [AimMinSpeed, AimMaxSpeed]
  - `localToOffset` / `offsetToLocal` — 全屏节点局部坐标 ↔ 投影偏移空间换算
  - `createAimInput(parent, viewW, viewH)` — 全屏触摸层 + `onDrag`/`onRelease`/`setEnabled`
  - `handleLocal` / `handleOffset` — 输入源可替换的缝隙（键盘降级/回放/无头测试）
- `game/Config.ts` — 新增 `AimMinSpeed=2` / `AimMaxSpeed=22` / `AimMaxDragPx=380`
- `game/Projection.ts` — 新增 `screenToPlaneY`（射线与 y=0 平面求交）
- `Test/HudTest.ts`（17 断言）、`Test/HudProbe.ts`（运行时链路探针）

**已验证的证据**

- **编译**：全量 `build` 通过。
- **单测**：`Test/HudTest.ts` → `passed checks=17 failures=0`
  （无拖动默认值、四方向语义、力度线性/夹紧/单调、投影往返、坐标换算互逆）。
- **运行时（`Test/HudProbe.ts`）**：
  - 驱动一次拖拽：`power=0.692`、`unit=(0.152, -0.988)`、`velocity=(2.41, -15.66)`
  - 该向量推演 → `outcome=crashed points=25`（直冲行星，物理正确）
  - 预测线在画面中可见（6 个区域，从探测器延伸向行星）

**关键设计修正（本次自查发现）**

初版把“探测器屏幕位置”（`project()` 输出 = **相对屏幕中心的偏移**）
与“触摸位置”（换算后 = **绝对像素**）直接相减 —— 两个空间不一致，方向会算错。
已统一为**投影偏移空间**（中心原点、+Y 向下），换算集中在 `localToOffset()`。

**局限（如实记录）**

- `Touch` 是私有构造，**无法**程序化注入真触摸事件 → 真实触摸的坐标系
  （`touch.location` 的原点/Y 方向）需一次人工校对；`localToOffset` 是唯一校准点。
- `onRelease` 回调只能由真触摸结束触发，无头环境无法验证（代码路径已由单测覆盖计算部分）。

### 会话 8 · S1.3 轨迹渲染（预测线 + 真实尾迹）

**已实现（源码）**

- `game/Trajectory.ts`（172 行）— 轨迹渲染：
  - `projectPolyline(points, y, basis)` — 批量把平面采样点投影到 2D 覆盖层坐标
  - `decimate(points, maxPoints)` — 均匀抽稀（保留首尾），控制移动端开销
  - `createTrajectoryView(parent, opts)` — 返回 `setPrediction` / `clearPrediction` / `setTrail` / `clearTrail`
  - 用 `DrawNode.drawSegment` + `drawDot`（圆头）而非 `Line`，因为 `Line` 线宽不可控
- `game/Projection.ts` — 新增 `prepareCamera` / `projectPrepared`（预计算相机基，避免每帧重算数百次）
- `Test/TrajectoryTest.ts`（10 断言）、`Test/TrajectoryProbe.ts`（运行时探针）

**已验证的证据**

- **编译**：全量 `build` 19/19 通过。
- **单测**：`Test/TrajectoryTest.ts` → `passed checks=10 failures=0`，
  含“预测线与尾迹逐点相同”（核心约束）、“预计算基与 project() 降为 float32 后逐位一致”。
- **运行时（`Test/TrajectoryProbe.ts`）**：轨迹在画面中清晰可见：
  - 区域检测从 **11 个 → 40+ 个**（改用 DrawNode 后）
  - 亮像素占比 **0.07% → 0.30%**
  - ASCII 图呈现“从上方下行、随引力向左弯曲”的曲线，符合物理推演

**踩到的坑**

- **`Director.entry` 是 `View3D`，不能挂 2D 绘制节点** → 轨迹必须挂在 `Director.ui`。
- **`Line` 线宽不可控**（约 1px），在 1080p 下几乎不可见 → 改用 `DrawNode.drawSegment`。
- **`Vec2` 是 float32**（引擎 C++ 类型），与 float64 普通对象比较会有 ~1e-8 相对误差。
- **增量构建有时不重新转译**：全量 `build` 报告成功但 `.lua` 未更新。需改一次 `.ts` 强制重编。

**未验证 / 待办**

- 轨迹尚未接入拖拽瞄准（S1.4）与主循环（S1.5）。

### 会话 7 · S1.2 场景与相机跟随

**已实现（源码）**

- `game/Scene.ts`（180 行）— 3D 场景搭建：
  - `planeToWorld(p, y)` — 平面坐标 → 世界坐标（y=0）
  - `buildScene(options)` — 方向光 + 行星（同资产染色/缩放）+ 土星环 + 探测器
  - 行星靠 `Model3D(path).getMaterial(0).baseColor` **逐实例染色**，靠 `scale` 区分大小
  - 返回 `GameScene`（`syncBodies` / `syncProbe` / `faceVelocity` / `probe` / `planets`）
- `game/CameraRig.ts`（174 行）— 单一相机 + 动态跟随（D3）：
  - `computeFit(points)` — 关键点包围盒中心 + 半对角
  - `computeRigStep(state, points, opts)` — 纯计算，不碰引擎对象
  - `createCameraRig` / `defaultRigOptions`（tilt=45, dist 25–100, lerp=0.1, fitFactor=1.6）

**已验证的证据**

- **编译**：全量 `build` 17/17 通过。
- **单测（纯逻辑）**：`Test/CameraRigTest.ts` → `passed checks=11 failures=0`
  （fit 计算、距离单调性、夹紧、倾角、平滑）。
- **运行时（`Test/SceneProbe.ts`）**：
  - `stats: draws=4 visible=4 triangles=260`（2 球 + 1 环 + 1 探测器）
  - 相机跟随：`rig distance range over flight: min=53.95 max=82.55`，`camera pulled back=true`
  - 视觉：Agent 用 `Test/Vision.ts` 自检初始帧与后期帧，两帧均检出物体
- **设计修正（有实测依据）**：初版相机用“探测器到目标的距离”作依据，
  但探测器会**飞过**目标，该距离非单调 → 实测 `first=50.41 last=48.31`（相机反而拉近）。
  改为“**关键点包围盒半对角**”后单调（`min=53.95 max=82.55`）。

**已踩并记录到手册 §7.2.1 的三个坑**

1. **对象成员函数默认带 self**：interface 成员函数生成 `obj:method(arg)` 冒号调用，
   把 `obj` 当第一个参数 → 运行时报 “field 'x' is nil”。**编译期不报错**。
   解法：`/** @noSelf **/`（用属性式函数类型**无效**）。
2. **`threadLoop` 返回值易搞反**：返回 `false` 继续、`true` 停止。
   写了 `return frame < 600` → 第 1 帧就停，看起来像“卡住”。
3. **工厂命名空间不能当类型**：用 `Vec3.Type` / `Node3D.Type`，不能写 `Vec3` / `Node3D`。

**未验证 / 待办**

- `Scene` / `CameraRig` 尚未接入完整主循环（S1.5）。
- 轨迹绘制未开始（S1.3）。

### 会话 6 · S1.1 物理内核（确定性）

**已实现（源码）**

- `game/Gravity.ts`（253 行，**零引擎依赖**，不 import 'Dora'）：
  - 类型：`P2` / `Body` / `ProbeState` / `SimOptions` / `SimResult` / `Outcome`
  - 函数：`bodyPositionAt`（公转）、`accelerationAt`（平方反比）、`step`（半隐式欧拉）、
    `collisionIndex`（撞毁）、`simulate`（**预测与真实共用**的推演）、
    `orbitalSpeed`、`applyScales`、`sub`/`length`/`distance`
- `Test/GravityTest.ts` — 10 组 / 25 项断言，首行输出 `passed`/`failed`，
  用 `requireProjectModule("Test.GravityTest")` 加载，**无需运行场景**。

**已验证的证据**

- **编译**：`game/Gravity.ts` 与 `Test/GravityTest.ts` 均通过（1/1）。
- **单测**：`checks=25 failures=0` → `passed`。
- **确定性（验收硬指标）**：同一输入连跑 5 次，轨迹 101 个采样点 **逐位相同**（bit-exact）。
- **物理正确性交叉验证**：`a(1)=100.0000`（= `gm/r²`）；`a(1)/a(2)=4.0`、`a(1)/a(4)=16.0`（平方反比）；
  圆轨道漂移 **0.000%**。
- **测试判别力（防止恒真测试）**：故意把平方反比改成线性（`invd3 → invd`），
  测试立即报 `failed failures=4`（`inverse-square`、`circular-orbit-radius`、`escape-detected`、`gravity-pulls-inward`）；
  已撤销并重跑确认 `passed`。
  - 额外发现：注入缺陷时 `determinism` **依然通过** → 确定性测试与物理正确性测试是**互补**的两类证据。

**未验证 / 待办**

- `Gravity.ts` 尚未接入渲染与玩法（S1.2–S1.5）。

### 会话 5 · 文本化视觉验证 + 关闭 R3（竖屏相机）

**背景**：用户要求优先解决“Agent 无法看图片”的问题。

**已实现（源码）**

- `Test/Vision.ts` — **文本化视觉验证工具库**：
  - 原理：`App.saveScreenshot` 输出未压缩 TGA（`type=2`，24/32bpp）；入口是引擎脚本，
    不受命令沙箱的“二进制不可读”限制，可用 `Content.load` 读字节并在引擎内解码。
  - 输出：ASCII 灰阶图 + 亮度直方图 + **列剖面** + 连通域区域检测。
  - API：`parseTga` / `luminanceAt` / `rgbAt` / `detectRegions` / `asciiMap` / `buildReport` / `captureReport`。
- `Test/VisionProbe.ts` — 视觉验证自检。
- `Test/CameraProbe.ts` — 竖屏相机覆盖计算（R3）。
- `game/Config.ts` — 补入平面→世界映射常量、相机倾角/距离安全区间。

**已验证的证据**

- **视觉工具判定力（实测）**：三物体放在 x=-6.5/0/+6.5 → 工具输出 `horizontal segments: 3`，
  三个 bbox 的 centroid 归一化 x = 0.091 / 0.498 / 0.881，与预期位置精确对应。
- **踩坑与修正（已写入代码注释）**：
  1. `saveScreenshot` 是**异步落盘**。第一次只请求后立即读，拿到的是**陈旧截图**
     （图像与上一次逐字节相同）。正确做法是“请求 → 隔几帧 → 读取”。
  2. 截图约 10 MB（2024×1230×4），**不能**把像素物化成 Lua 数组（实测失败），必须步长采样。
- **R3 关闭（决定性数据）**：用已标定的投影模块（误差 1px）对竖屏宽高比 0.5625 计算 NDC：

| 轨道朝向 | dist=30/tilt=45 时的 maxNdcX / maxNdcY | 结论 |
|---|---|---|
| 横向（沿世界 X） | 1.50 / 0.32 | ❌ 超出 1.5 倍，被裁 |
| 纵向（沿世界 Z） | 0.72 / 0.65 | ✅ 完整可见 |

  - 横向轨道需 `dist ≥ 50` 才装得下；纵向轨道 `dist ≥ 25` 即可。
  - tilt 安全区间：20–60°（maxNdcY 0.34–0.74）；>70° 贴边（≥0.86）。
  - ⇒ **物理平面必须沿屏幕纵向（世界 Z）展开**，已写入 `Config.ts` 与手册 §5.1。

**未验证 / 待办**

- 工具**不能**判断美观/可读性/手感 —— 仍需人工。
- S0.6（R6 包体积 17 MB）用户已决定暂不处理。



**背景**：用户反馈“运行游戏没有任何东西显示”。排查确认：**不是 bug，是 `init.ts` 本来就是空壳**（只有 `// @preview-file on clear` + `import {} from 'Dora'`）。

**已实现（源码）**

- `init.ts` — 从空壳改为**真实 3D 场景**（79 行）：相机、方向光、球体×2、土星环、探测器四面体，缓慢自转。既解决“看不到东西”，又充当 R1 的验证载体。

**已验证的证据**

- **编译**：`init.ts` 构建通过（1/1）。
- **运行时**：`enterEntryAsync("init.ts")` 运行 4 秒，日志输出 `[escape-velocity] draws=4 visible=4 triangles=260 view=2024x1230`；`stopEntry()` 后 `running=false`。`draws=4` ↔ 4 个模型；`triangles=260` ↔ 120×2 + 16 + 4，与网格面数完全吻合。
- **视觉（引擎内）**：截图 `.agent/vision/1790223969-446514564.png`（2024×1230）已生成，但 Agent 无图像分析工具，`visual: not_run`。
- **🔴 R1 关闭（用户实测，决定性证据）**：用 Web IDE 的「导出 HTML」，**浏览器内能看到 3 个 3D 物体**。
  - 意义：**Web 导出不需要从源码编译引擎**，也不需要本地装 Emscripten/Rust/Go 工具链。先前探测到的源码仓库缺失、`EMSDK` 未设置、无外壳能力等问题**全部不构成阻塞**。
  - 手册 §11 中 R1 的“退回 2D”回退方案**不触发**。
- **🚨 R6 缺口（用户实测）**：导出包体 **17 MB**，超 8 MB 目标。
  - 分析：包体由引擎 WASM 运行时主导，减小项目资产（三个 glTF 合计约 8 KB）几乎无影响。
  - 可能路径：① 确认“8 MB”是原始体积还是压缩后；WASM 压缩比通常 3–4 倍，17 MB 压缩后可能落入预算；② 源码构建时用 `DORA_WEB_PROFILE=core|custom` 裁剪功能。

**未验证 / 待办**

- S0.4（竖屏相机 R3）未开始。
- R6 口径与裁剪方案待定。



**背景**：`Line` 只能画 2D，而轨迹线（全场最重要视觉）需要画在 2D 覆盖层；`View3D` 无 world→screen 投影。

**已实现（源码）**

- `game/Projection.ts` — 纯函数投影模块：`project()`（世界→屏幕）、`unprojectDirection()`、已标定常量 `HANDEDNESS=1` / `FLIP_Y=false`、`toOverlay()`。
- `Test/ProjectionProbe.ts` — 自标定 + 回归测试。

**已验证的证据**

- **编译**：`game/Projection.ts` 与 `Test/ProjectionProbe.ts` 均通过（1/1）。
- **标定方法（排除猜测）**：`getRayDirection(viewPoint)` 的真值特性是“对已知世界点搜索方向点积最大的屏幕位置”。先用一个非对称相机（eye=(3,4,8)）验证：正确的 `viewPoint` 空间是 **像素坐标、原点在左上角（`[0,W]×[0,H]`，+Y 向下）**，手性 `right = cross(forward, up)`；而 `dot(getRayDirection(p), f)` 在 (1012, 614) 处为 1.000000 —— 正是 `View.size/2`。
- **投影精度（R4 关闭的决定性证据）**：回归测试 `Test/ProjectionProbe.ts` 反复输出 `RESULT=PASS`，实测：

| 世界点 | 真实屏幕位置 | 自建投影 | 误差 |
|---|---|---|---|
| 原点 | (1012, 614) | (1012.0, 615.0) | 1.00 px |
| +x (4,0,0) | (1694, 506) | (1693.3, 506.7) | 0.96 px |
| -x (-4,0,0) | (492, 698) | (492.6, 697.6) | 0.72 px |
| +y (0,3,0) | (1012, 1110) | (1012.0, 1109.2) | 0.75 px |
| -y (0,-3,0) | (1012, 238) | (1012.0, 238.2) | 0.20 px |

  最大误差 **1.00 px**（2024×1230，约 0.05%）→ **R4 关闭**。
- 早前的两种错误途径已排除并记录：`getRayOrigin` 返回的不是视点（相差 0.16），且射线不能直接反推相机基。

**未验证 / 待办**

- S0.4（竖屏相机 R3）、S0.5（Web 3D R1）、S0.6（包体积 R6）未开始。
- 投影模块尚未接入实际轨迹渲染（S1.3 再做）。



**背景**：用户启用互联网工具后，实测取物不可用：

- `fetch_url` 对 `raw.githubusercontent.com`、`cdn.jsdelivr.net`、`www.gnu.org` 三个域名均报 `failed to move downloaded file into target path`；引擎日志显示 `being used by another process`，且落盘文件经 `Content:load` 验证均为 **0 字节**。
- `git clone https://github.com/octocat/Hello-World.git` 报 `wsarecv: ... connected host has failed to respond`（超时）。
- 命令模式下的 `Content` 被沙箱限制：仅允许项目内路径，且无 `save`/`searchPaths`/`writablePath`；写文件必须通过入口（`enterEntryAsync`）。

**已实现（源码 + 资产）**

- `Test/gen_shapes.lua` — 离线几何生成器（Lua `string.pack` + 手写 base64），构建通过。
- `Assets/Model/Sphere.gltf` — 单位球（SEG=12/RING=6），61 顶点 / 120 面，base64 内嵌 2208 B buffer。
- `Assets/Model/Ring.gltf` — 扁平圆环（1.35/2.0，8 段，双面），16 顶点 / 16 面。
- `Assets/Model/Probe.gltf` — 正四面体探测器（指向 +X），12 顶点 / 4 面。
- `Test/Smoke.ts` — S0 资产加载冒烟测试（`Model3D` 加载三个资产 + `view.stats` 判定），构建通过。
- `docs/开发手册.md` §5.9/§8.1/§11/§12/§13 已同步离线资产方案、编译产物与源码同目录的注意项、R8（取物不可用）。

**已验证的证据**

- **编译**：`build` 全绿，4/4 文件（`init.ts`、`game/Config.ts`、`Test/Smoke.ts`、`Test/gen_shapes.lua`），无诊断。
- **数据正确性**：在引擎内重新计算三个网格的顶点/法线/索引并 base64 编码，与文件内容**逐字符比对全部 `MATCH=true`**（Sphere 2944、Ring 640、Probe 416 字符）。
- **运行时（已达成）**：入口释放后运行 `Test/Smoke.ts`，标记文件内容为 `status=PASS draws=3 visible=3 triangles=140 missing=`；`stopEntry()` 后 `success=true running=false`。
  - `draws=3` ↔ 三个资产各一次绘制；`triangles=140` ↔ 120+16+4，与三个网格面数精确吻合 → **`Model3D` 能加载并渲染自产 glTF**（关闭 R2 与 S0.1/S0.7）。
- **视觉**：截图已捕获（`.agent/vision/1790222441-939253569.png`，40 KB，2024×1230），但当前无图像分析工具（`read_file` 拒读二进制），**未由 Agent 目视确认** → `visual: not_run`，需人工查看。

**未验证 / 待办**

- S0.3（投影 R4）、S0.4（竖屏相机 R3）、S0.5（Web 3D R1）、S0.6（包体积 R6）均未开始。

### 会话 1 · 骨架初始化

**已实现（源码 + 文档）**

- `docs/开发手册.md` — 开发手册（决策 D1–D7、架构、物理/相机/轨迹方案、参数表、编码规范、构建与 Web 导出、验收标准与证据分级、裸测清单）。
- `README.md` — 项目入口说明与文档索引。
- `LICENSE` — AGPL-3.0 **通知头 + TODO 说明**（官方全文待补）。
- `.gitignore` — 忽略构建产物、Agent 运行时产物、临时目录。
- `Assets/.gitkeep`、`Test/.gitkeep` — 目录占位。
- `game/Config.ts` — 全局常量与调参表初版。
- `.agent/plan/PLAN.md`、`.agent/plan/PROGRESS.md` — 计划与进度。

**已验证的证据**

- 仓库基线：`git status` 显示工作区仅有 `init.ts` 与 `单程-项目愿景.md` 为未跟踪；`glob` 确认根目录只有这两个文件。
- 能力核实（读文档，非运行证据）：3D 栈存在（`Camera3D`/`Node3D`/`Model3D`/`DirectionalLight3D`/`Surface3D`/`Body3D`/`Shader`/`RenderTarget`）；TS 层**无**程序化几何工厂；`Line` 为 2D `Vec2[]`；`View3D` 无 world→screen 投影；Web 构建 `DORA_WEB_FEATURE_MODEL_3D` **默认 OFF**。
- `build`：`game/Config.ts` 与 `init.ts` 通过（2/2，`failed: 0`）。

## 阻塞项

1. 无硬阻塞。
2. **手机浏览器复测**（唯一开放的真机项）：Web 导出包需在手机上重跑一遍（选关 → 拖 → 松手 → 结算）。
   桌面侧已用合成鼠标（`tools/input-inject/mousectl.ps1`）自动验收；真机 DPR / 视口 / 手指遮挡仍需一次实测。
3. **R6 包体积 17 MB > 8 MB**：用户已决定暂缓（手册 §11 有缺口分析）。
4. 视觉/手感仍需人工参与：Agent 只能做几何、亮度、层级层面的自检（`Test/Vision.ts` + 看 PNG）。

## 下一步

1. **S3.1 接线**：把已入库的 11 个 `.glb` 接进 `game/Scene.ts`（行星按关卡换模型、探测器换 `Probe_Voyager_v1`、
   `Sun`/`BlackHole` 作引力源变体），然后出**关内**截图验收（冒烟陈列图不算）。
2. **S3.2** 轨迹发光与星空（并行线路的星空烟雾测试定稿后再落手册）。
3. **S3.3** 金唱片开场与关间简报 → **S3.4（可选）**粒子/后处理。
4. 提交前纪律：`node tools/dora-build/build.mjs --all` 必须 **36/36**；单测 `SUMMARY passed=7 failed=0 total=7`。
