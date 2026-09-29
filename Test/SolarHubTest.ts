/**
 * SolarHub 模块纯逻辑单测：数据映射、火箭字符串格式化、天体轨道定义。
 */
import {
	HUB_STATIONS,
	LEVEL_TO_STATION_INDEX,
	formatRocketsString,
} from 'game/SolarHub';
import { getLevel, installArcadeLevels, levelCount } from 'game/LevelData';
import { Content, json } from 'Dora';

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

function testFormatRockets(): void {
	check('rockets-0', formatRocketsString(0) === '☆  ☆  ☆', '0 枚火箭显示错误');
	check('rockets-1', formatRocketsString(1) === '★  ☆  ☆', '1 枚火箭显示错误');
	check('rockets-2', formatRocketsString(2) === '★  ★  ☆', '2 枚火箭显示错误');
	check('rockets-3', formatRocketsString(3) === '★  ★  ★', '3 枚火箭显示错误');
	check('rockets-clamp-neg', formatRocketsString(-1) === '☆  ☆  ☆', '负数火箭显示错误');
	check('rockets-clamp-over', formatRocketsString(5) === '★  ★  ★', '超出火箭显示错误');
}

function testStationMappings(): void {
	const count = levelCount();
	check('mission-count-match', LEVEL_TO_STATION_INDEX.length === count, '映射关卡数量与 levelCount 不一致');

	// L2 (水手10号) 必须锚定在水星 (stIndex === 0)
	check('l2-mariner10-targets-mercury', LEVEL_TO_STATION_INDEX[1] === 0, '水手10号必须锚定在水星 (Station 0)');
	// L3 (旅行者2号) 必须锚定在海王星 (stIndex === 7)
	check('l3-voyager2-targets-neptune', LEVEL_TO_STATION_INDEX[2] === 7, '旅行者2号必须锚定在海王星 (Station 7)');

	for (let i = 0; i < count; i++) {
		const stIndex = LEVEL_TO_STATION_INDEX[i];
		if (stIndex === -1) {
			check(`lv${i + 1}-station-sun-valid`, true, '');
		} else {
			check(`lv${i + 1}-station-index-valid`, stIndex >= 0 && stIndex < HUB_STATIONS.length, `stIndex=${stIndex} 越界`);
			const st = HUB_STATIONS[stIndex];
			check(`lv${i + 1}-station-orbit>0`, st.orbit > 0, `orbit=${st.orbit}`);
			check(`lv${i + 1}-station-radius>0`, st.radius > 0, `radius=${st.radius}`);
			check(`lv${i + 1}-station-model-present`, st.model.length > 0, '模型名称为空');
		}

		const def = getLevel(i);
		check(`lv${i + 1}-def-exists`, def !== undefined, '关卡定义缺失');
		if (def !== undefined && def.mission !== undefined) {
			check(`lv${i + 1}-mission-matches`, def.mission.id === 'L' + (i + 1).toFixed(0), `mission.id=${def.mission.id}`);
		}
	}
}

export function runTests(): string {
	const levelsText = Content.exist('Assets/Levels/levels.json') ? Content.load('Assets/Levels/levels.json') : '';
	const bodiesText = Content.exist('Assets/Levels/bodies.json') ? Content.load('Assets/Levels/bodies.json') : '';
	installArcadeLevels(levelsText, bodiesText, (text: string): unknown => {
		const decoded = json.decode(text);
		if (decoded[1] !== undefined) return undefined;
		return decoded[0];
	});
	testFormatRockets();
	testStationMappings();

	const lines: string[] = [];
	lines.push(failures.length === 0 ? 'passed' : 'failed');
	lines.push(`checks=${checks} failures=${failures.length}`);
	const limit = failures.length < 12 ? failures.length : 12;
	for (let i = 0; i < limit; i++) {
		lines.push(`FAIL ${failures[i].name}: ${failures[i].detail}`);
	}
	return lines.join('\n');
}
