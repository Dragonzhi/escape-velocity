# 《单程》Escape Velocity

> 用一次发射，借行星的力，把一枚探测器送出太阳系。

竖屏、单指触屏、六关的物理规划小游戏。玩家在发射前调整方向与力度、观察被引力掰弯的预测轨迹；松手后不可修正，只能看着探测器按物理飞出去。

## 状态

🚧 **核心循环已可玩**。S0 裸测、S1 核心循环（拖动瞄准 → 松手发射 → 飞行观赏 → 结算）已完成；S2.1 六关数据与目标判定已交付，**S2.2 结算面板 / S2.3 关卡选择进行中**；S3 视觉与 S4 提交素材待做。

## 操作说明

- **瞄准**：按住并拖动屏幕（从探测器指向手指的方向即发射方向，拖动距离决定力度）。
- **发射**：松开手指即发射，此后不可修正。
- **结算**：飞行结束后给出「借力成功 / 错过目标 / 信号中断」，可「重试本关」或「返回关卡选择」。
- **进度**：只记录已解锁关卡，解锁后写入本地存档（`unlockedLevel`）。

## 文档

| 文档 | 内容 |
|---|---|
| [`单程-项目愿景.md`](./单程-项目愿景.md) | 产品愿景：题材、核心体验、关卡曲线、风险 |
| [`docs/开发手册.md`](./docs/开发手册.md) | **唯一事实来源**：决策记录、架构、物理与相机方案、编码规范、构建与 Web 导出、验收标准 |
| [`docs/DSH-vs-Dora内置Agent-能力对照.md`](./docs/DSH-vs-Dora内置Agent-能力对照.md) | 开发环境说明：引擎 API / 鉴权 / 构建链路事实，与外部 Agent 的能力对照 |
| [`.agent/plan/PLAN.md`](./.agent/plan/PLAN.md) | 实施计划（分步、依赖、验收判据） |
| [`.agent/plan/PROGRESS.md`](./.agent/plan/PROGRESS.md) | 实施进度与证据 |

## 技术栈

- 引擎：**Dora SSR v1.9.3**（引擎自报 1.9.3.6）
- 语言：TypeScript（编译为 Lua 后由引擎执行）
- 渲染：low poly 3D + 纯色 flat 材质，零贴图
- 物理：**2D 平面积分 + 3D 渲染**（见开发手册 §5.1）

## 快速开始

1. 启动 Dora SSR 引擎，并保持 Web IDE 可用。
2. 用 Web IDE 打开本项目，入口为 `init.ts`。
3. 修改 TypeScript 源码后执行构建，检查每个文件的编译诊断。两种构建方式：
   - 引擎侧：`Dora.exe cli build -p <项目目录>`（需要 Web IDE 已连接）
   - 本地：`node tools/dora-build/build.mjs --all`（不依赖引擎与浏览器；产物与引擎逐字节一致）
4. 单元测试（引擎内执行）：运行入口 `Test/UnitRunner.lua`，结果写入 `.agent/test-results/unit-summary.txt`。

Web 导出见开发手册 §8.2。⚠️ 本项目是 3D 游戏，Web 构建**必须显式开启** `DORA_WEB_FEATURE_MODEL_3D=ON`（默认为 `OFF`）。

**已测设备**：Web 浏览器（桌面浏览器运行 Web 导出版本）。

## 许可与版权

本项目以 **AGPL-3.0-only** 授权。[`LICENSE`](./LICENSE) 为 GNU Affero 通用公共许可证第 3 版的**官方全文**（自 <https://www.gnu.org/licenses/agpl-3.0.txt> 取得，未做任何改动）。

> 《单程》Escape Velocity
> Copyright (C) 2026 Dragonzhi
>
> This program is free software: you can redistribute it and/or modify
> it under the terms of the GNU Affero General Public License as published
> by the Free Software Foundation, either version 3 of the License, or
> (at your option) any later version.
>
> This program is distributed in the hope that it will be useful,
> but WITHOUT ANY WARRANTY; without even the implied warranty of
> MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
> GNU Affero General Public License for more details.
>
> You should have received a copy of the GNU Affero General Public License
> along with this program.  If not, see <https://www.gnu.org/licenses/>.

- 作者/团队：**Dragonzhi**
- 引擎：[Dora SSR](https://github.com/IppClub/Dora-SSR) v1.9.3
- 活动：Dora SSR × Agent 社区小游戏征集 · [活动页](https://atompie.osgame.org/events/minigame-2026)
