/** Small native render/audio probe, independent of the flight simulation. */
import { App, Content, Director, Node, Path, Size, Vec2, View, threadLoop } from 'Dora';
let root = Path(Content.writablePath, 'escape-velocity');
for (let i = 0; i < Content.searchPaths.length; i++) {
	const p = Content.searchPaths[i];
	if (Content.exist(Path(p, 'game', 'Ui.lua')) && Content.exist(Path(p, 'init.lua'))) { root = p; break; }
}
Content.addSearchPath(root);
const Ui = require('game/Ui') as typeof import('game/Ui');
const Vision = require('Test/Vision') as typeof import('Test/Vision');
const marker = Path(root, '.agent', 'test-results', 'presentation-probe.txt');
Content.save(marker, 'phase=running');
const icons: import('game/Ui').ButtonIcon[] = ['pause', 'play', 'slow', 'fast', 'launch', 'cancel', 'retry', 'back', 'camera', 'stop', 'minus', 'plus', 'fit'];
const buttons: import('game/Ui').UiButton[] = [];
const layer = Node(); layer.size = Size(View.size.width, View.size.height); layer.anchor = Vec2(0, 0);
layer.position = Vec2(-View.size.width / 2, -View.size.height / 2); Director.ui.addChild(layer);
for (let i = 0; i < icons.length; i++) {
	const b = Ui.createButton(layer, { w: 72, h: 72, text: '', icon: icons[i], fontSize: 20, bgHex: 0x142334, fgHex: 0xeaf4ff, borderHex: 0x4e7b9e, onTap: (): void => {} });
	b.root.position = Vec2(24 + (i % 5) * 80, View.size.height - 120 - Math.floor(i / 5) * 80); buttons.push(b);
}
buttons[2].setEnabled(false); buttons[4].setSelected(true);
let elapsed = 0;
let updated = false;
let shot = '';
threadLoop((): boolean => {
	elapsed += App.deltaTime;
	if (elapsed < 0.5) return false;
	if (!updated) { buttons[0].setIcon('play'); updated = true; }
	if (elapsed < 1) return false;
	if (shot === '') { shot = App.saveScreenshot(Path(root, '.agent', 'test-results', 'presentation-buttons')); return false; }
	if (elapsed < 1.3) return false;
	const report = Vision.captureReport(shot, ['dynamic pause changed to play; compare first two buttons']);
	Content.save(marker, 'iconSize=' + buttons[0].root.width + 'x' + buttons[0].root.height + '\ndisabledTouch=' + buttons[2].root.touchEnabled + '\n' + report + '\nphase=done');
	return true;
});
