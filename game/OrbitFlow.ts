/**
 * 沿轨道流动的光点（S3.16）—— **纯数学、零引擎依赖**（与 Gravity.ts 同一级纪律）。
 *
 * 用户原话（会话 46）：**轨道圈看不出运动方向与快慢**。设计稿（docs/关卡舞台表.md 第二节第 5 条）
 * 的处方是：在每条行星轨道上放一串**流动的光点**——
 *   - 移动**方向** = 该天体的公转方向（`Body.orbitDirection`；全太阳系目前都是顺行 +1，
 *     但这里一律读字段，不写死 —— 将来加一颗逆行天体，光点自动反过来流）；
 *   - 移动**快慢** ∝ **角速度** ω = 2π / orbitPeriod（开普勒：内圈快、外圈慢，
 *     一眼能看出"谁跑得快"——这正是要的视觉效果）；
 *   - 位置**只由 tWorld 解析求出**（`orbitAngleAt` 与 `Gravity.bodyPositionAt` 是同一个式子），
 *     不引入第二时间源 ⇒ 拨发射日期时行星与光点一起动（AGENTS 硬约束 7）。
 *
 * ===== 为什么光点链"锚"在行星相位上 =====
 *
 * 第 k 个光点的角 = **行星此刻的角** + k·2π/N。于是：
 *   ① 整条链以角速度 ω 公转（方向与快天然等于轨道参数，不需要第二套动画时钟）；
 *   ② 第 0 个光点正好压在行星身上（被行星挡住，不损失信息）——链条"拖着"行星，
 *      看起来像它走过的痕迹与将要去的方向；
 *   ③ `flowDotPosition(b, t, 0, N) === bodyPositionAt(b, t)` 成为**可单测的不变量**：
 *      光点几何与物理几何从此不可能分家（单测 Test/OrbitFlowTest.ts 守着）。
 *
 * 渲染侧（2D 的 PlanView / 3D 的 Scene）只消费这里的函数；本模块不 import 'Dora'。
 * 参数（光点个数）也放这儿：2D 与 3D 共用同一个数，两条视图里的同一条轨道长得一样。
 */
import { Body, P2, bodyPositionAt } from 'game/Gravity';

/**
 * 每条轨道上的光点个数（2D 与 3D 共用）。
 *
 * 6 个 = 每 60° 一个：既像"一串灯"（能看出流向），又不至于密成一条实线。
 * 节点池按这个数**一次性建好**，之后每帧只改位置（AGENTS：不要每帧重建节点）。
 */
export const FlowDotsPerOrbit = 6;

/**
 * 天体在时刻 t 的轨道角（弧度）。
 *
 * ⚠️ 必须与 `Gravity.bodyPositionAt` 逐字一致（同一个 `phase0 + direction·2π·t/period`）——
 * 那是全仓库唯一的行星位置公式；这里复制它是为了让光点与行星**共用同一个角**，
 * 而不是为了发明第二种算法。单测用 `bodyPositionAt` 反守着这条等式。
 */
export function orbitAngleAt(b: Body, t: number): number {
	let angle = b.phase0;
	if (b.orbitPeriod !== 0) {
		angle += b.orbitDirection * 2 * Math.PI * (t / b.orbitPeriod);
	}
	return angle;
}

/**
 * 轨道角速度（弧度/秒）。**符号带方向**：> 0 = 逆时针（数学正向 / 顺行），< 0 = 顺时针（逆行）。
 *
 * 光点的"快慢"就是这个量的绝对值：内圈周期短 ⇒ |ω| 大 ⇒ 光点跑得快。
 * `orbitPeriod === 0`（静止天体，如第 2 关那种）返回 0 —— 没有可流动的轨道。
 */
export function orbitAngularRate(b: Body): number {
	if (b.orbitPeriod === 0) return 0;
	return (b.orbitDirection * 2 * Math.PI) / b.orbitPeriod;
}

/**
 * 第 k 个光点的轨道角（`count` 个光点均匀分布）。
 *
 * `k` 允许越界/负数（取模归一到 [0, count)）——调用方传节点池下标时不必自己夹。
 */
export function flowDotAngle(b: Body, t: number, k: number, count: number): number {
	const n = count > 0 ? count : 1;
	let idx = k % n;
	if (idx < 0) idx += n;
	return orbitAngleAt(b, t) + (idx * 2 * Math.PI) / n;
}

/**
 * 轨道**圆心**在时刻 t 的位置（平面坐标）。
 *
 * 卫星（月球绕地球）的圆心是**会动的宿主** —— 与 `bodyPositionAt` 里取圆心的方式一致。
 */
export function orbitCenterAt(b: Body, t: number): P2 {
	return b.host !== undefined ? bodyPositionAt(b.host, t) : b.orbitCenter;
}

/**
 * 第 k 个光点的**平面位置**。
 *
 * 2D 规划视图直接用它换投影；3D 场景用 `orbitCenterAt` + `orbitAngleAt` 现场算
 * （省掉每帧 36 个小对象的分配，见 Scene.syncBodies）。
 */
export function flowDotPosition(b: Body, t: number, k: number, count: number): P2 {
	const c = orbitCenterAt(b, t);
	const a = flowDotAngle(b, t, k, count);
	const r = b.orbitRadius;
	return { x: c.x + r * Math.cos(a), y: c.y + r * Math.sin(a) };
}
