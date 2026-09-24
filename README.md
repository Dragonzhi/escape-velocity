# 《单程》Escape Velocity

> 用一次发射，借行星的力，把一枚探测器送出太阳系。

竖屏、单指触屏、六关的物理规划小游戏。玩家在发射前调整方向与力度、观察被引力掰弯的预测轨迹；松手后不可修正，只能看着探测器按物理飞出去。

## 状态

✅ **S0 裸测、S1 核心循环、S2 关卡与结算全部已交付**：六关数据与目标判定、结算三态面板（借力成功 / 错过目标 / 信号中断）、
关卡选择与**解锁存档**（`%APPDATA%/IppClub/DoraSSR/escape-velocity.progress`）都可玩；手机端两轮真机问题（触摸命中框、视口变化）已修。
**下一步 S3 视觉**（星球造型、轨迹发光与星空、金唱片开场）；S4 素材与提交待做。⚠️ 手机 Web 版**待复测**。

## 操作说明

- **瞄准（相对拖动 / 虚拟摇杆）**：在屏幕**任意位置**按下 —— 按下瞬间预测线回到**直飞**（正对目标、最小力度）；
  之后拖着手指移动，**位移方向 = 发射方向、位移长度 = 力度**，预测线实时跟着变。
  ⇒ 按在哪里都能瞄，不需要去抓飞行器。
- **发射**：**松开手指才发射**，此后不可修正。
- **结算**：飞行结束后给出「借力成功 / 错过目标 / 信号中断」，可「重试本关」或「返回关卡选择」。
- **进度**：解锁制 —— 只有借力成功才解锁下一关，写入本地存档（一行 `unlocked=N`，存在引擎的可写目录，不在仓库内）。

## 文档

| 文档 | 内容 |
|---|---|
| [`单程-项目愿景.md`](./单程-项目愿景.md) | 产品愿景：题材、核心体验、关卡曲线、风险 |
| [`docs/开发手册.md`](./docs/开发手册.md) | **唯一事实来源**：决策记录、架构、物理与相机方案、编码规范、构建与 Web 导出、验收标准 |
| [`docs/DSH-vs-Dora内置Agent-能力对照.md`](./docs/DSH-vs-Dora内置Agent-能力对照.md) | 开发环境说明：引擎 API / 鉴权 / 构建链路事实，与外部 Agent 的能力对照 |
| [`.agent/plan/PLAN.md`](./.agent/plan/PLAN.md) | 实施计划（分步、依赖、验收判据） |
| [`.agent/plan/PROGRESS.md`](./.agent/plan/PROGRESS.md) | 实施进度与证据 |
| [`AGENTS.md`](./AGENTS.md) | **仓库级 Agent 守则**：硬约束（构建、触摸、坐标）与验证纪律 |
| [`tools/dora-build/README.md`](./tools/dora-build/README.md) | 本地 TS→Lua 构建工具（安装、用法、版本钉死、一致性门禁） |
| [`tools/input-inject/README.md`](./tools/input-inject/README.md) | 合成鼠标输入：坐标换算、常用点位、触摸回归模板 |
| [`.dsh/skills/dora-ssr-engine/SKILL.md`](./.dsh/skills/dora-ssr-engine/SKILL.md) | Dora SSR 引擎操作手册（DSH 技能：引擎路径/端口/API/构建/探针） |

## 技术栈

- 引擎：**Dora SSR v1.9.3**（引擎自报 1.9.3.6）
- 语言：TypeScript（编译为 Lua 后由引擎执行）
- 渲染：low poly 3D + 纯色 flat 材质，零贴图
- 物理：**2D 平面积分 + 3D 渲染**（见开发手册 §5.1）

## 快速开始

1. 启动 Dora SSR 引擎，并保持 Web IDE 可用。
2. 用 Web IDE 打开本项目，入口为 `init.ts`。
3. **开发时保持竖屏窗口**（交付形态就是竖屏；运行中改窗口也能正确重建）：

```powershell
powershell -File tools/input-inject/set-window.ps1 -Shape portrait    # 客户区 400×710 → View.size 601×1066
```

4. 修改 TypeScript 源码后执行构建，检查每个文件的编译诊断。两种构建方式：
   - **本地（推荐，不依赖引擎与浏览器）**：

```bash
cd tools/dora-build && npm i --legacy-peer-deps    # 版本钉死 tstl 1.37.1 + TS 5.9.3，必须带该参数
node build.mjs --all                              # 整项目构建，提交前应 36/36 全绿
```

   - 引擎侧：`Dora.exe cli build -p <项目目录>`（**需要 Web IDE 已连接**，TS 编译实际发生在浏览器里）
5. 单元测试（引擎内执行）：运行入口 `Test/UnitRunner.lua`，结果写入 `.agent/test-results/unit-summary.txt`；
   基线 `SUMMARY passed=7 failed=0 total=7`（7 个模块 / 164 条断言）。新增单测模块要加进它的 `modules` 列表。
6. 桌面触摸回归（可选）：`tools/input-inject/mousectl.ps1` 用合成鼠标事件驱动真实命中判定与状态机，用法见该目录 README。

Web 导出见开发手册 §8.2：用 **Web IDE 自带的「导出 HTML」**即可，浏览器内 3D 正常（**不需要**从源码编译引擎）。
⚠️ 仅当你要**从源码**构建 Web 运行时，才需要显式开启 `DORA_WEB_FEATURE_MODEL_3D=ON`（该开关默认为 `OFF`）。

**已测设备**：**桌面 Web 浏览器** 通过 —— Web 导出版本完整跑通：选关、拖动瞄准、松手发射、飞行、结算。

**手机 Web 导出：待复测**。手机浏览器上暴露过两处真机问题，均已修复并有截图 / 日志证据：

1. **触摸命中框只剩左下象限** —— 全屏容器 `anchor` 用了 (0.5,0.5)，子坐标原点被推走半个屏幕；已改为 (0,0)（六个方位的实测网格全通过）。
2. **视口尺寸变化没重建** —— 手机浏览器画布在启动后还会变一次；现在监听 `onAppChange === 'Size'` 并整体重建（预测线不再跑偏、新区域能收到触摸）。

⇒ 还需要在手机上把「导出 → 选关 → 拖 → 松手 → 结算」重跑一遍（真机 DPR / 视口 / 手指遮挡）。

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
