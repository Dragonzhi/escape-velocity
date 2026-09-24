## Core Memory

### User Preferences

- 回复用简体中文；希望 Agent 少长篇思考、多动手。
- 对不确定的问题，必须先问再动手。

### Stable Facts

- 当前项目：《单程》Escape Velocity（Dora SSR 竖屏 3D 小游戏）。仓库位于工作区根，唯一事实来源 `docs/开发手册.md`。
- 形态：竖屏、单指触屏、六关、一次性发射的物理规划小游戏；物理 2D 平面积分、渲染 3D。
- 许可：AGPL-3.0-only。

### Known Decisions

- 七项产品/技术决策 D1–D7 已冻结，记录于 `docs/开发手册.md` §2。
- 3D 资产采用**代码生成自包含 glTF**（`Test/gen_shapes.lua`），不依赖外部下载。

### Known Issues

- LICENSE 缺 AGPL-3.0 官方全文（提交前补）。
- **环境限制**：`fetch_url` 落盘为 0 字节、`git clone` 到 github 超时 → 网络取物不可用。
- **Agent 无图像分析工具**：`read_file` 拒读二进制。**已用 `Test/Vision.ts` 文本化视觉验证绕过**（见下）。
- 🚨 **R6 包体积缺口**：Web 导出实测 **17 MB**，超 8 MB 目标（用户已决定暂不处理）。

### Visual Verification Capability

- **Agent 能自己做视觉验证了**（无需人工看截图）。
- 工具：`Test/Vision.ts` — `App.saveScreenshot` 输出未压缩 TGA → 引擎内解码 → ASCII 灰阶图 + 亮度直方图 + 列剖面 + 连通域检测。
- ⚠️ 两个已踩的坑（已写入代码注释与手册 §9.1）：
  1. `saveScreenshot` 是**异步落盘**，必须“请求 → 隔几帧 → 读取”，否则拿到陈旧截图。
  2. 截图约 10 MB，必须**步长采样**，不能物化像素数组（会失败）。
- 已实测：三个物体放在 x=-6.5/0/+6.5 → 正确输出 `segments: 3` 且三点位与预期对得上。
- **能力边界**：只能验证“物体有没有、几个、在哪、多大”，**不能**判断美观/可读性/手感。