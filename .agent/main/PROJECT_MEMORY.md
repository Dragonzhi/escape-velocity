## Project Memory

### Project Facts

- 项目：《单程》Escape Velocity。Dora SSR × Agent 社区小游戏征集的参赛项目（AtomGit 公开仓库）。
- 形态：竖屏 1080×1920 设计分辨率、单指触屏、六关、一次性发射的物理规划小游戏。
- 技术：TypeScript（编译为 Lua）+ Dora SSR；low poly 3D + 纯色 flat 零贴物；**物理 2D 平面积分，渲染 3D**。
- 许可：AGPL-3.0-only。
- 唯一事实来源：`docs/开发手册.md`；产品愿景：`单程-项目愿景.md`；计划：`.agent/plan/`。

### Build And Run

- 入口：项目根 `init.ts`（当前为真实 3D 场景：球×2 + 环 + 探测器）。需启动 Dora SSR 并保持 Web IDE 可用。
- 🔴 **Web 导出**：用 **Web IDE 自带的「导出 HTML」**即可，**浏览器内 3D 正常**（用户实测）。
  **无需**从源码编译引擎 —— 引擎是预编译发行版（只有 `Dora.exe`/`wa.dll`/`LICENSES`），`Tools/`、`Projects/` 不存在。
- 纯逻辑单测：`requireProjectModule("Test.GravityTest").runTests()`（无需运行场景）。
- 运行时探针：`enterEntryAsync({fileName="Test/SceneProbe.ts"})` + 轮询标记文件到 `phase=done`。
- 🚨 **包体积**：Web 导出实测 **17 MB** > 8 MB 目标（用户已决定暂不处理）。

### Files And Architecture

- `docs/开发手册.md`：架构分层与模块清单、参数表、编码规范、验收标准与证据分级。
- `game/Config.ts`：全局常量与调参表（平面映射、相机安全区）。
- `game/Gravity.ts`：**零引擎依赖**的物理内核（固定步长、平方反比、`simulate` 预测与真实共用）。
- `game/Projection.ts`：**已标定**的 3D→2D 投影（纯函数）。手性 `right=cross(forward,up)`；viewPoint 为左上角像素坐标（`[0,W]×[0,H]`，+Y 向下）；用 `toOverlay()` 转成 Dora 2D 坐标。
- `game/Scene.ts`：3D 场景搭建（同球体资产逐实例染色/缩放、土星环、探测器朝向）。
- `game/CameraRig.ts`：单一相机 + 动态跟随（包围盒半对角驱动，已实测单调）。
- `Assets/Model/`：离线生成的自包含 glTF（`Sphere.gltf` / `Ring.gltf` / `Probe.gltf`）。
- `Test/gen_shapes.lua`：离线几何生成器（写 `Assets/Model/*.gltf`）。
- `Test/Smoke.ts`：S0 资产加载冒烟测试。
- `Test/GravityTest.ts`：物理单测（25 断言，`requireProjectModule("Test.GravityTest").runTests()`）。
- `Test/CameraRigTest.ts`：相机机架单测（11 断言）。
- `Test/ProjectionProbe.ts`：投影标定与回归测试（输出 `RESULT=PASS/FAIL`）。
- `Test/Vision.ts`：**文本化视觉验证工具库**（TGA→ASCII/统计/区域检测）。
- `Test/SceneProbe.ts`：场景+相机运行时探针。
- 仓库骨架：`README.md`、`.gitignore`、`LICENSE`、`Assets/`、`Test/`、`game/`、`.agent/plan/PLAN.md`。

### Decisions

- D1 引力弹弓：行星公转 + 真实弹弓（相对速度自然产生加速/减速），行星轨道速度调到肉眼可见。
- D2 时间：瞄准时全局冻结；松手瞬间行星从相位 0 开始公转、探测器同时发射。
- D3 相机：单一 Camera3D + 动态跟随拉远，不做视角硬切。
- D4 世界观：借真实天体名与视觉，但不守真实轨道比例。
- D5 失败流程：重试本关 / 返回关卡选择；进度只记已解锁关卡，无星级。
- D6 几何资产：代码能生成就用代码，其余用公开 low poly 素材。**实际落地为：无网络，全部用 `Test/gen_shapes.lua` 代码生成。**
- D7 文档双落点：手册 + `.agent/plan/`。

### Camera And Layout Facts (S0 实测)

- **竖屏 1080×1920（宽高比 0.5625）**；`View.fieldOfView` = 45°（垂直 FOV）。
- **物理平面必须沿屏幕纵向（世界 Z）展开**：横向展开的轨道在竖屏下 `maxNdcX=1.50` 被裁；
  纵向展开 `maxNdcX=0.72` / `maxNdcY=0.65` 完整可见（dist=30/tilt=45）。
- **倾角安全区间 20–60°**（>70° 贴边）；**纵向轨道 `dist ≥ 25` 即可框住整条轨道**。
- 已写入 `game/Config.ts`（`PlaneToWorldX/Z`、`CameraTilt*`、`CameraMin/MaxDistance`）。
- ⚠️ 运行时**无法**切窗口尺寸（`View.size` 只读），竖屏验证靠已标定投影模块算 NDC 完成。

### Known Issues

- Dora TS 层**无**程序化几何工厂（无 `Sphere()`/自定义顶点网格），模型只能 `Model3D(path)` 加载 → 已用代码生成 glTF 解决。
- `Line` 只能画 2D（仅接受 `Vec2[]`）；`View3D` 无 world→screen 投影 → **已自建并标定**（`game/Projection.ts`，误差 1 px）。
- **`View3D.getRayOrigin` 返回的不是视点**（相差 0.16），不要用它反推相机；用 `getRayDirection` 搜索法标定。
- 🔴 **TSTL 三大坑（编译期不报错，运行时报错）**：
  1. **对象/接口成员函数默认带 self** → 生成 `obj:method(arg)` 冒号调用，参数错位，报 “field 'x' is nil”。
     解法：`/** @noSelf **/`（**属性式函数类型无效**）。
  2. **`threadLoop` 返回 `false` 继续、`true` 停止**（易搞反；写反了看着像“卡住”）。
  3. **工厂命名空间不是类型**：标注用 `Vec3.Type` / `Node3D.Type`，不能写 `Vec3` / `Node3D`。
  4. 另：`saveScreenshot` 是**异步落盘**（需隔几帧再读）；不支持 `toExponential`。详见手册 §7.2.1。
- `LICENSE` 目前是 AGPL-3.0 通知 + 官方全文链接，**尚未包含全文**，提交前必须补全。
- 网络取物不可用（`fetch_url` 落盘 0 字节、`git clone` 超时）。
- 🚨 **R6：Web 导出实测 17 MB**，超 8 MB 目标。不能靠项目侧优化解决（包体由引擎 WASM 主导）。