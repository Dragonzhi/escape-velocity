# 《单程》Escape Velocity

> 用一次发射，借行星的力，把一枚探测器送出太阳系。

竖屏、单指触屏、六关的物理规划小游戏。玩家在发射前调整方向与力度、观察被引力掰弯的预测轨迹；松手后不可修正，只能看着探测器按物理飞出去。

## 状态

🚧 **前期搭建中**。当前仓库只有产品愿景、开发手册与工程骨架，尚无游戏玩法实现。

## 文档

| 文档 | 内容 |
|---|---|
| [`单程-项目愿景.md`](./单程-项目愿景.md) | 产品愿景：题材、核心体验、关卡曲线、风险 |
| [`docs/开发手册.md`](./docs/开发手册.md) | **唯一事实来源**：决策记录、架构、物理与相机方案、编码规范、构建与 Web 导出、验收标准 |
| [`.agent/plan/PLAN.md`](./.agent/plan/PLAN.md) | 实施计划（分步、依赖、验收判据） |
| [`.agent/plan/PROGRESS.md`](./.agent/plan/PROGRESS.md) | 实施进度与证据 |

## 技术栈

- 引擎：[Dora SSR](https://dora-ssr.net/)
- 语言：TypeScript（编译为 Lua 后由引擎执行）
- 渲染：low poly 3D + 纯色 flat 材质，零贴图
- 物理：**2D 平面积分 + 3D 渲染**（见开发手册 §5.1）

## 快速开始

1. 启动 Dora SSR 引擎，并保持 Web IDE 可用。
2. 用 Web IDE 打开本项目，入口为 `init.ts`。
3. 修改 TypeScript 源码后执行构建，检查每个文件的编译诊断。

Web 导出见开发手册 §8.2。⚠️ 本项目是 3D 游戏，Web 构建**必须显式开启** `DORA_WEB_FEATURE_MODEL_3D=ON`（默认为 `OFF`）。

## 许可

AGPL-3.0-only。见 [`LICENSE`](./LICENSE)。
