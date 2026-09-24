/**
 * 微测试：DrawNode.clear() 是否真的能清除已绘制内容。
 *
 * 背景：预测线旧帧残留（用户报告“不是从探测器出发的准确线段”，
 * 诊断探针发现新旧两条线同时存在）——怀疑 clear() 无效。
 *
 * 步骤：画一条亮线 → 截图 A → clear() → 等几帧 → 截图 B。
 * 若 B 中线仍在 → clear() 失效，需要换方案。
 *
 * 产出：.agent/test-results/s21-clear-test.txt
 */
import { App, BlendFunc, BlendOp, Color, Content, Director, DrawNode, Path, Vec2, threadLoop } from 'Dora';
import { captureReport } from 'Test/Vision';

const root = Content.searchPaths[0];
const outDir = Path(root, '.agent', 'test-results');
if (!Content.exist(outDir)) Content.mkdir(outDir);
const marker = Path(outDir, 's21-clear-test.txt');

const lines: string[] = [];
function flush(final: boolean): void {
	Content.save(marker, lines.join('\n') + (final ? '\nphase=done' : ''));
}
lines.push('phase=started');
flush(false);

const draw = DrawNode();
draw.blendFunc = BlendFunc(BlendOp.One, BlendOp.One);
Director.ui.addChild(draw);

// 画一条明显的横线（屏幕上半部，overlay +Y 向上 → y=+300 在上方）
const white = Color(255, 255, 255, 255);
draw.drawSegment(Vec2(-300, 300), Vec2(300, 300), 6, white);
draw.drawDot(Vec2(0, 300), 10, white);

let frame = 0;
let shotA = '';
let shotB = '';
let cleared = false;

threadLoop(() => {
	frame += 1;

	// 帧 5：线已画好 → 截图 A
	if (frame === 5) {
		shotA = App.saveScreenshot(Path(outDir, 's21-clear-before'));
		lines.push(`shot A (line drawn) @f${frame}`);
		flush(false);
	}

	// 帧 8：调用 clear()，之后不再画任何东西
	if (frame === 8 && !cleared) {
		cleared = true;
		draw.clear();
		lines.push(`clear() called @f${frame}`);
		flush(false);
	}

	// 帧 15：截图 B —— 线应该消失了
	if (frame === 15) {
		shotB = App.saveScreenshot(Path(outDir, 's21-clear-after'));
		lines.push(`shot B (after clear) @f${frame}`);
		flush(false);
	}

	if (frame === 20) {
		lines.push('');
		lines.push('--- BEFORE clear (line should be visible at upper area) ---');
		lines.push(captureReport(shotA, ['expect: bright horizontal line at upper area']));
		lines.push('');
		lines.push('--- AFTER clear (line should be GONE) ---');
		lines.push(captureReport(shotB, ['expect: empty (no line)']));
		lines.push('');
		lines.push('RESULT=DONE');
		flush(true);
		return true;
	}

	return false;
});
