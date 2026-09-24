## Project Memory

### Project Facts

- 项目：《单程》Escape Velocity。Dora SSR × Agent 社区小游戏征集的参赛项目（AtomGit 公开仓库）。
- 形态：竖屏 1080×1920 设计分辨率（待定稿）、单指触屏、六关、一次性发射的物理规划小游戏。
- 技术：TypeScript（编译为 Lua）+ Dora SSR；low poly 3D + 纯色 flat 零贴物；**物理 2D 平面积分，渲染 3D**。
- 许可：AGPL-3.0-only。
- 唯一事实来源：`docs/开发手册.md`；产品愿景：`单程-项目愿景.md`；计划：`.agent/plan/`。

### Build And Run

- 入口：项目根 `init.ts`（当前仅占位）。需启动 Dora SSR 并保持 Web IDE 可用。
- Web 导出：`Tools/build-scripts/build_web.sh` → `result/dora-web-player`；冒烟 `node Tools/build-scripts/check_web_browser.mjs result/dora-web-player`。
- 🔴 **本项目必须用 `DORA_WEB_FEATURE_MODEL_3D=ON` 构建 Web 版**；该开关默认 OFF，不开则 Web 版本无 3D 渲染。工具链版本固定在 `Projects/Web/toolchain.env`。

### Files And Architecture

- `docs/开发手册.md`：架构分层与模块清单、参数表、编码规范、验收标准与证据分级。
- `game/Config.ts`：全局常量与调参表。
- `game/Projection.ts`：**已标定**的 3D→2D 投影（纯函数）。手性 `right=cross(forward,up)`；viewPoint 为左上角像素坐标（`[0,W]×[0,H]`，+Y 向下）；用 `toOverlay()` 转成 Dora 2D 坐标。
- `Assets/Model/`：离线生成的自包含 glTF（`Sphere.gltf` / `Ring.gltf` / `Probe.gltf`）。
- `Test/gen_shapes.lua`：离线几何生成器（写 `Assets/Model/*.gltf`）。
- `Test/Smoke.ts`：S0 资产加载冒烟测试。
- `Test/ProjectionProbe.ts`：投影标定与回归测试（输出 `RESULT=PASS/FAIL`）。
- `Test/Vision.ts`：**文本化视觉验证工具库**（TGA→ASCII/统计/区域检测）。让 Agent 无需人工看截图即可验证“物体是否渲染、几个、在哪”。
- `Test/VisionProbe.ts`：视觉验证自检（目前场景为三物体水平分离）。

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
- `Line` 只能画 2D；`View3D` 无 world→screen 投影 → **已自建并标定**（`game/Projection.ts`，误差 1 px）。
- **`View3D.getRayOrigin` 返回的不是视点**（相差 0.16），不要用它反推相机；用 `getRayDirection` 搜索法标定。
- `LICENSE` 目前是 AGPL-3.0 通知 + 官方全文链接，**尚未包含全文**，提交前必须补全。
- 网络取物不可用（`fetch_url` 落盘 0 字节、`git clone` 超时）。
- 🚨 **R6：Web 导出实测 17 MB**，超 8 MB 目标。不能靠项目侧优化解决（包体由引擎 WASM 主导）；只能靠压缩口径确认或源码构建裁剪。
- 🔴 **环境事实**：引擎是**预编译发行版**（`Dora.exe` + `wa.dll` + `LICENSES`），**无源码**；工具链（`Tools/`、`Projects/`）不存在；`os.execute`/`io` 不可用 → 无法从源码构建 Web 版。但 **Web IDE 的「导出 HTML」可直接导出且 3D 正常**。
