import { Audio } from 'Dora';

export type SoundCue = 'ui_click' | 'aim_stretch' | 'aim_cancel' | 'launch' | 'slingshot_whoosh' | 'gate_reach' | 'crash' | 'star_1' | 'star_2' | 'star_3';

const AudioRoot = 'Assets/Audio/';
let musicStarted = false;

/** 从应用启动时开始的单条循环配乐；关卡切换与重试不重启。 */
export function startBackgroundMusic(): void {
	if (musicStarted) return;
	musicStarted = true;
	Audio.playStream(AudioRoot + 'bgm_deep_space.ogg', true, 1.2);
	print('[escape-velocity] audio: background music started');
}

/** 播放一个已打包的 WAV 音效。 */
export function playSound(cue: SoundCue): void {
	Audio.play(AudioRoot + cue + '.wav');
}
