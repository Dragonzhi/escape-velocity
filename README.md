<a href="https://dora-ssr.net/">
  <img src="https://dora-ssr.net/img/site/dora.svg" alt="Dora SSR" width="96" />
</a>

# 《单程》Escape Velocity

[![License: AGPL-3.0-only](https://img.shields.io/badge/License-AGPL--3.0--only-527A35?style=for-the-badge)](LICENSE)
[![Dora SSR QQ 群：512620381](https://img.shields.io/badge/QQ%E7%BE%A4-512620381-12B7F5&style=for-the-badge&logo=qq&logoColor=white)](https://qm.qq.com/q/VnzYhvCDgy)

用一次发射，借行星的力，把一枚探测器送出太阳系。

本作品使用 **[Dora SSR](https://dora-ssr.net/)** 游戏引擎开发，参与原子派社区小游戏征集活动。

项目发布于 AtomGit，并在 [GitHub](https://github.com/Dragonzhi/escape-velocity) 保留同步镜像；当前仓库配置的 Git 远端为 GitHub。

**发布与展示平台：[原子派](https://atompie.osgame.org/)**  
**活动页面：[社区小游戏征集活动](https://atompie.osgame.org/events/minigame-2026)**

## 游戏介绍

- 核心目标：在三段街机尺度的太阳系旅程中规划一次点火，让探测器借天体引力抵达目标区域。L1 从地球出发掠过月球，L2 从日心轨道借金星减速后飞掠水星，L3 借木星和土星驶向太阳系外。进入目标环即可完成，沿途绿色光点提供可选加分。
- 操作方式：竖屏单指触控，桌面端也支持鼠标。规划阶段拖动探测器调整点火方向和力度，点发射开始飞行；时间按钮可以减速、暂停或加速。飞行后可切换2D/3D视图；在3D空白处拖动可旋转镜头，滚轮可缩放，也可点选探测器、行星或总览作为观察中心。
- 玩法特色：固定步长的引力模拟驱动预测轨迹和实际飞行；发射后轨迹不可修正，玩家可以观察航线如何被行星弯折。每关有目标环和可选得分点，过关后仍可继续观看飞行。
- 作者／团队：Dragonzhi

## 开发环境

- 引擎：Dora SSR v1.9.3（引擎自报 1.9.3.6）
- 编程语言：TypeScript（经 TypeScriptToLua 编译为 Lua 后由引擎执行；仓库中 `.ts` 与编译产物 `.lua` 同目录共存，修改 `.ts` 后必须重新构建才会生效）
- 官方文档：https://dora-ssr.net/docs/tutorial/quick-start/
- 引擎源码：https://github.com/IppClub/Dora-SSR

## 运行项目

1. 安装与本项目相匹配版本的 Dora SSR（v1.9.3），启动并打开引擎显示的 Web IDE 地址。
2. 将本仓库完整源码与资源放入 Dora SSR 工作空间的独立项目目录。
3. 打开项目入口 `init.ts` 并在 Web IDE 编译运行；引擎执行由 TypeScript 生成的 `init.lua`。
4. 保持竖屏以呈现预期布局；运行时改变窗口尺寸会自动重建界面。修改 TypeScript 后须重新生成同目录的 Lua：首次进入 `tools/dora-build` 并安装构建工具依赖（`npm i --legacy-peer-deps`），之后在该目录执行 `node build.mjs --all`；也可在 Web IDE 中编译。
5. 游戏运行不需要第三方 npm 依赖、API Key、密码或其他密钥。解锁与得分保存在引擎可写目录，不存入仓库。

提交前请从一个干净目录重新取得仓库内容，确认他人能按照以上步骤运行。

## Web（HTML）版本与测试

- 导出方法：在 Dora SSR Web IDE 打开项目根目录，点击“导出”并选择“导出 HTML”。若 IDE 编译缓存报错，可在项目根目录运行 `node tools/export-web.mjs --engine "Dora.exe 所在目录"`，先全量构建和检查 Lua 一致性，再调用已安装引擎的官方 HTML 打包器。
- 当前导出包：[`escape-velocity-web-html.zip`](./escape-velocity-web-html.zip)，Dora SSR 1.9.3，约 23 MB；已在桌面浏览器实测可玩。
- 启动方法：完整解压并通过 HTTPS 或 localhost 打开 `index.html`，保留全部配套资源；`file://` 方式不受支持。
- 测试结果：全量构建 60/60，UnitRunner 15 个模块、648 项检查通过；Web 包已核对完整性并在桌面浏览器实测。手机触控回归尚待单独复测。

## 项目内容

仓库包含游戏源码（`init.ts`、`game/*.ts` 及对应 `.lua`）、运行资源（`Assets/`）、单元测试（`Test/`）、构建和素材工具（`tools/`）、比赛素材（`submission/`）、Web 导出包及项目文档（`docs/`）。界面字体由 Dora SSR 提供，本项目未单独打包字体文件。

- 应用图标：[`submission/icon-1024.png`](./submission/icon-1024.png)，1024×1024 PNG。
- 封面：[`submission/cover-1080x1920.jpg`](./submission/cover-1080x1920.jpg)，1080×1920 JPG。
- 演示视频：[`submission/demo-1080x1920.mp4`](./submission/demo-1080x1920.mp4)，1080×1920 H.264 MP4，60 秒。
- 可玩 Web 版本：[`escape-velocity-web-html.zip`](./escape-velocity-web-html.zip)，解压后按上面的说明启动。

## 素材与第三方组件

| 内容 | 作者／来源 | 许可证 | 使用说明 |
| --- | --- | --- | --- |
| Dora SSR 引擎（运行时随 Web 导出包分发） | [IppClub/Dora-SSR](https://github.com/IppClub/Dora-SSR) | MIT | 保留引擎原有版权与许可声明；本项目代码许可证不替代引擎许可 |
| 天体与探测器 3D 模型（`Assets/Model/*.glb`） | 团队自制（Blender 制作） | 随本项目 AGPL-3.0-only | 无第三方素材 |
| 行星 / 太阳 / 探测器贴图（`Assets/Image/*.jpg`、`*.png`） | 团队自制 | 随本项目 AGPL-3.0-only | 无第三方素材 |
| 星空、光晕、轨道圈等贴图 | 仓库内脚本程序化生成（`Test/gen_*.py`、`Test/gen_shapes.lua`） | 随本项目 AGPL-3.0-only | 不引入第三方素材 |
| 游戏音效（`Assets/Audio/*.wav`） | 项目制作 | 随本项目 AGPL-3.0-only | 完成提示音由 `tools/gen_success_cue.py` 生成 |
| 背景音乐 `bgm_galactic_temple.ogg` | yd，[OpenGameArt](https://opengameart.org/content/galactic-temple) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 使用来源、处理方式和工程文件见 [MUSIC_LICENSE.md](./Assets/Audio/MUSIC_LICENSE.md) |

保留 Dora SSR 与第三方组件原有的版权及许可声明。第三方素材按其各自授权使用，本项目代码许可证不替代第三方素材许可证。

## 仓库文档

| 文档 | 内容 |
|---|---|
| [docs/单程_数据驱动街机引力弹弓_设计案.md](./docs/单程_数据驱动街机引力弹弓_设计案.md) | 当前三关玩法、目标、视听和关卡数据设计 |
| [docs/开发手册.md](./docs/开发手册.md) | 唯一工程事实来源：决策记录、系统架构、物理与相机方案、构建规范 |
| [docs/提交物清单.md](./docs/提交物清单.md) | 比赛交付物检查清单（图标、封面、演示视频、Web 导出） |
| [AGENTS.md](./AGENTS.md) | 仓库级开发守则：硬约束与验证纪律 |

## 开源协议

本项目原创代码使用 **GNU Affero General Public License v3.0 only（AGPL-3.0-only）**，完整协议见 [LICENSE](LICENSE)。

Copyright (C) 2026 Dragonzhi

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see https://www.gnu.org/licenses/.

---

使用 Dora SSR 创作 · 在原子派分享
[Dora SSR](https://dora-ssr.net/) · [原子派](https://atompie.osgame.org/)

原子派为活动及展示平台；上述平台署名不改变作品实际作者及著作权归属。
