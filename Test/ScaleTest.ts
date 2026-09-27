/**
 * S5 单测：物理尺度的推导（game/Scale.ts）。
 *
 * 为什么值得单测：这一份是**所有**天体半径 / gm / 周期的上游。它错一点，六关的物理就整体错，
 * 而且错得很像「手感问题」而不是「bug」—— 归正前的 SunGm 与 KeplerK 互相矛盾 42.7 倍，
 * 就是这么活了好几轮的。所以这里把**每一个锚点与自检值都钉死**。
 *
 * 判据全部是「与真实天文数据的对照」或「与解析公式的对照」，
 * 没有一个是「跑一遍看它等于自己」。
 * 输出格式：首行为 passed 或 failed（与其他测试模块一致）。
 */
import {
	EarthGm, EarthRadius, GmFactor, KmPerSecPerUnit, KmPerUnit,
	MoonGm, MoonOrbitRadius, MoonRadius, RealSpeedAtAu, SecPerGameSec, SunGm,
	SunRadius, UnitsPerAu, circularSpeed, escapeSpeed, hillRadius, period,
	trueGm, trueOrbit, trueRadius,
} from 'game/Scale';

interface Failure {
	name: string;
	detail: string;
}

const failures: Failure[] = [];
let checks = 0;

function check(name: string, ok: boolean, detail: string): void {
	checks += 1;
	if (!ok) failures.push({ name, detail });
}

/**
 * 科学计数法字符串。**不能写 toExponential** —— tstl 不支持（手册 §7.1 的同族坑：
 * Math.hypot / Math.imul / toExponential，编译期不报错、运行时报错）。
 */
function sci(x: number): string {
	if (x === 0) return '0';
	let e = 0;
	let m = x < 0 ? -x : x;
	while (m >= 10) { m /= 10; e += 1; }
	while (m < 1) { m *= 10; e -= 1; }
	return (x < 0 ? '-' : '') + m.toFixed(4) + 'e' + e;
}

/** 相对误差判定（跨 10 个数量级的尺度量，绝对误差没有意义）。 */
function near(name: string, got: number, want: number, relTol: number): void {
	const d = Math.abs(got - want);
	const tol = Math.abs(want) * relTol;
	check(name, d <= tol, 'got=' + got + ' want=' + want + ' |d|=' + sci(d) + ' tol=' + sci(tol));
}

/** 1) 尺度常量：三个锚点必须与真实天文数据自洽，且量纲关系成立。 */
function testConstants(): void {
	near('km-per-unit', KmPerUnit, 1.495978707e8 / 80, 1e-12);
	check('units-per-au', UnitsPerAu === 80, 'UnitsPerAu=' + UnitsPerAu);
	near('real-speed-1au', RealSpeedAtAu, 29.7847, 1e-4);
	near('km-per-sec-per-unit', KmPerSecPerUnit, 29.7846918317 / 30, 1e-9);
	near('sec-per-game-sec', SecPerGameSec, 1.883491e6, 1e-5);
	near('gm-factor', GmFactor, 5.425264e-7, 1e-5);
	// 量纲自洽：GmFactor 必须**恰好**等于 tau^2/L^3（不是另一条路凑出来的近似值）
	near('gm-factor-is-tau2-over-l3', GmFactor, (SecPerGameSec * SecPerGameSec) / (KmPerUnit * KmPerUnit * KmPerUnit), 1e-12);
	// 1 游戏秒 = 21.8 天：这条同时钉住「一天在游戏里有多长」这个全局手感
	check('sec-per-game-sec-is-21-8-days', Math.abs(SecPerGameSec / 86400 - 21.8) < 0.05,
		'1 game-sec = ' + (SecPerGameSec / 86400).toFixed(3) + ' days (want ~21.8)');
}

/** 2) 换算函数：正向、往返、退化输入。 */
function testConversions(): void {
	near('true-radius-earth', trueRadius(6371), 0.003407, 1e-5);
	near('true-radius-sun', trueRadius(695700), 0.372037, 1e-5);
	near('true-gm-earth', trueGm(3.986004418e5), 0.2162513, 1e-6);
	near('true-orbit-1au', trueOrbit(1), 80, 1e-12);
	near('true-orbit-jupiter', trueOrbit(5.202887), 416.2310, 1e-6);
	near('roundtrip-radius', trueRadius(6371) * KmPerUnit, 6371, 1e-9);
	near('roundtrip-gm', trueGm(1.32712440018e11) / GmFactor, 1.32712440018e11, 1e-9);
	check('degenerate-radius-zero', trueRadius(0) === 0, 'trueRadius(0)=' + trueRadius(0));
}

/** 3) 太阳：trueGm 必须**恰好**落回归正前手填的 72000 —— 病根诊断的落点。 */
function testSun(): void {
	near('sun-gm-is-72000', SunGm, 72000, 1e-9);
	near('sun-radius', SunRadius, 0.3720374, 1e-5);
	// 归正前「显示半径 = 撞毁半径 = 28」；物理半径现在只有 0.372（视觉半径另见 Tuning）
	check('sun-radius-shrunk-70x', SunRadius < 28 / 70, 'sunRadius=' + SunRadius.toFixed(4));
	// 速度锚点：1 AU 处圆轨速度恰好 30
	near('anchor-v-circ-80-is-30', circularSpeed(SunGm, 80), 30, 1e-9);
	near('earth-orbit-speed-anchor', circularSpeed(SunGm, trueOrbit(1.00000011)), 30, 1e-6);
}

/** 4) 开普勒第三定律：周期必须与真实行星周期同构（比值 = a^1.5）。 */
function testKepler(): void {
	const earthA = trueOrbit(1.00000011);
	const jupA = trueOrbit(5.202887);
	near('earth-period', period(earthA, SunGm), 16.7552, 1e-4);
	near('venus-period', period(trueOrbit(0.72333199), SunGm), 10.3075, 1e-4);
	near('jupiter-period', period(jupA, SunGm), 198.8452, 1e-4);
	near('saturn-period', period(trueOrbit(9.53667594), SunGm), 493.4511, 1e-4);
	near('uranus-period', period(trueOrbit(19.18916464), SunGm), 1408.4217, 1e-4);
	near('neptune-period', period(trueOrbit(30.06992276), SunGm), 2762.7849, 1e-4);
	// 比值判据：T_jup/T_earth 必须**恰好**是 (a_jup/a_earth)^1.5。
	// ⚠️ 分母要用实际轨道半径（地球是 1.00000011 AU ⇒ 80.000009，不是 80），
	//    拿 AU 标称比 5.202887 去比会差 1.6e-7 —— 那不是代码错，是期望值错（已踩过）。
	near('kepler-ratio-jupiter-over-earth', period(jupA, SunGm) / period(earthA, SunGm), Math.pow(jupA / earthA, 1.5), 1e-9);
	near('kepler-ratio-neptune-over-earth', period(trueOrbit(30.06992276), SunGm) / period(earthA, SunGm),
		Math.pow(trueOrbit(30.06992276) / earthA, 1.5), 1e-9);
	// 月球：mu 必须是**地球**的 gm（中心天体），不是月球自己的
	near('moon-period-around-earth', period(MoonOrbitRadius, EarthGm), 1.2593, 1e-4);
	near('moon-orbits-per-earth-year', period(earthA, SunGm) / period(MoonOrbitRadius, EarthGm), 13.31, 2e-3);
	check('real-moon-orbits-13-4', Math.abs(period(earthA, SunGm) / period(MoonOrbitRadius, EarthGm) - 13.37) < 0.2,
		'got=' + (period(earthA, SunGm) / period(MoonOrbitRadius, EarthGm)).toFixed(3) + ' (真实 13.37)');
	check('degenerate-period-zero', period(0, SunGm) === 0 && period(80, 0) === 0, 'period(0,mu)/period(a,0) 必须为 0');
}

/** 5) 判别力：把 KeplerK 那条错公式拿来对照，差 42.7 倍必须**被测出来**。 */
function testKeplerKIsGone(): void {
	const earthA = trueOrbit(1.00000011);
	const wrong = Math.pow(earthA, 1.5); // 归正前的 T = KeplerK * r^1.5（KeplerK = 1）
	const right = period(earthA, SunGm);
	const ratio = wrong / right;
	check('kepler-k-would-be-42-7x-off', Math.abs(ratio - 42.7) < 0.5, 'ratio=' + ratio.toFixed(2) + ' (want ~42.7)');
	check('kepler-k-not-reintroduced', right < 20, 'T_earth=' + right.toFixed(3) + 's (KeplerK 会让它是 715s)');
}

/** 6) 希尔球与逃逸速度：L1「探测器绕地球」的物理可行性判据。 */
function testHillAndEscape(): void {
	const earthA = trueOrbit(1.00000011);
	near('hill-radius-earth', hillRadius(earthA, EarthGm, SunGm), 0.800310, 1e-5);
	near('hill-radius-ratio', hillRadius(earthA, EarthGm, SunGm) / earthA, 0.010004, 1e-4);
	// L1 的探测器驻留轨道 r = 0.1 ⇒ 占希尔球 12.5%：稳定，但也不是随便就能再放大
	const parking = 0.1;
	const frac = parking / hillRadius(earthA, EarthGm, SunGm);
	check('parking-inside-hill', frac > 0.05 && frac < 0.2, 'r/r_H=' + frac.toFixed(4) + ' (want 0.125)');
	near('parking-period', period(parking, EarthGm), 0.42727, 1e-4);
	near('parking-v-circ', circularSpeed(EarthGm, parking), 1.47055, 1e-5);
	near('parking-v-escape', escapeSpeed(EarthGm, parking), 2.07968, 1e-5);
	near('escape-is-sqrt2-circular', escapeSpeed(EarthGm, parking) / circularSpeed(EarthGm, parking), 1.4142135623730951, 1e-12);
	// 月球轨道的圆轨速度（真实 1.022 km/s ⇒ 1.026 单位/秒）
	near('moon-orbit-v-circ', circularSpeed(EarthGm, MoonOrbitRadius), 1.02566, 1e-4);
	check('degenerate-hill-zero', hillRadius(80, 0, SunGm) === 0 && hillRadius(0, EarthGm, SunGm) === 0, 'hillRadius 退化输入必须为 0');
}

/** 7) 派生常量与真实数据表一致（防止有人在表里改了数、派生值没跟着走）。 */
function testDerived(): void {
	near('earth-gm', EarthGm, 0.2162513, 1e-6);
	near('earth-radius', EarthRadius, 0.0034070, 1e-5);
	near('moon-gm', MoonGm, 0.0026599, 1e-5);
	near('moon-radius', MoonRadius, 0.00092910, 1e-5);
	near('moon-orbit-radius', MoonOrbitRadius, 0.2055644, 1e-6);
	// 月球轨道半径必须等于 60.3 个地球半径（真实比值）
	near('moon-orbit-over-earth-radius', MoonOrbitRadius / EarthRadius, 60.34, 1e-3);
	// 六关全部用这一份表：金星 / 木星 / 土星 / 天王星 / 海王星的半径与真实比值对照
	near('jupiter-radius-over-earth', trueRadius(69911) / EarthRadius, 10.97, 2e-3);
	near('saturn-radius-over-earth', trueRadius(58232) / EarthRadius, 9.14, 2e-3);
	near('sun-radius-over-earth', SunRadius / EarthRadius, 109.2, 2e-3);
}

export function runTests(): string {
	testConstants();
	testConversions();
	testSun();
	testKepler();
	testKeplerKIsGone();
	testHillAndEscape();
	testDerived();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push('checks=' + checks + ' failures=' + failures.length);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push('FAIL ' + failures[i].name + ': ' + failures[i].detail);
	}
	return lines.join(String.fromCharCode(10));
}
