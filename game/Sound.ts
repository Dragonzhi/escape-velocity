import { Audio, AudioSource, Content, Director } from 'Dora';

export type SoundCue = 'ui_click' | 'aim_stretch' | 'aim_cancel' | 'launch' | 'slingshot_whoosh' | 'gate_reach' | 'crash' | 'star_1' | 'star_2' | 'star_3';

const AudioRoot = 'Assets/Audio/';
let music: AudioSource.Type | undefined = undefined;
let musicStarts = 0;

/** 从应用启动时开始的单条循环配乐；关卡切换与重试不重启。 */
export function startBackgroundMusic(): void {
	if (music !== undefined && music.playing) return;
	const path = AudioRoot + 'bgm_galactic_temple.ogg';
	if (!Content.exist(path)) { print('[escape-velocity] audio: missing music ' + path); return; }
	const source = AudioSource(path, false);
	if (source === undefined) { print('[escape-velocity] audio: music load failed ' + path); return; }
	source.looping = true;
	source.volume = 0.5;
	source.setProtected(true);
	Director.entry.addChild(source);
	if (!source.playBackground()) {
		source.removeFromParent();
		print('[escape-velocity] audio: music playback failed ' + path);
		return;
	}
	music = source;
	musicStarts += 1;
	print('[escape-velocity] audio: Galactic Temple playing=' + source.playing + ' loop=' + source.looping + ' volume=' + source.volume);
}

/** Read-only probe: no lifecycle or playback changes. */
export function backgroundMusicState(): string {
	return music === undefined ? 'missing' : 'playing=' + music.playing + ' loop=' + music.looping + ' volume=' + music.volume + ' starts=' + musicStarts;
}

/** 播放一个已打包的 WAV 音效。 */
export function playSound(cue: SoundCue): void {
	Audio.play(AudioRoot + cue + '.wav');
}
