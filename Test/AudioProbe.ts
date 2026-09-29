/** Native background music lifecycle probe; longer than one complete loop. */
import { App, Content, Path, threadLoop } from 'Dora';
let root = Path(Content.writablePath, 'escape-velocity');
for (let i = 0; i < Content.searchPaths.length; i++) {
	const p = Content.searchPaths[i];
	if (Content.exist(Path(p, 'game', 'Sound.lua')) && Content.exist(Path(p, 'init.lua'))) { root = p; break; }
}
Content.addSearchPath(root);
const Sound = require('game/Sound') as typeof import('game/Sound');
const marker = Path(root, '.agent', 'test-results', 'audio-probe.txt');
const lines = ['phase=running'];
Content.save(marker, lines.join('\n'));
Sound.startBackgroundMusic();
let elapsed = 0, stage = 0, failed = false;
threadLoop((): boolean => {
	elapsed += App.deltaTime;
	const deadlines = [1, 30, 176];
	if (elapsed < deadlines[stage]) return false;
	const state = Sound.backgroundMusicState();
	lines.push('t=' + elapsed.toFixed(2) + ' ' + state);
	if (state !== 'playing=true loop=true volume=0.5 starts=1') failed = true;
	if (stage === 0) { Sound.startBackgroundMusic(); Sound.startBackgroundMusic(); }
	stage++;
	if (stage < deadlines.length) { Content.save(marker, lines.join('\n')); return false; }
	lines.push('RESULT=' + (failed ? 'FAIL' : 'PASS')); lines.push('phase=done');
	Content.save(marker, lines.join('\n')); return true;
});
