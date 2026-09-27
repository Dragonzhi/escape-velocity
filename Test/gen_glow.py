"""
光晕贴图生成器：Assets/Image/glow.png（径向渐变，中心暖白 → 边缘透明）。

为什么要有它（S3.12，用户会话 44 原话："太阳本身不发光就算了，还有点过于小了"）：
引擎不做后处理，太阳又只是一颗被光照亮的球 —— 唯一能表达"它在发光"的手段是一张
**朝向相机的自发光面片**（Assets/Model/StarQuad.gltf）+ 这张贴图。
材质配方（见 game/Scene.ts 的 buildSunGlow）：alphaMode=Blend + baseColor 留黑 + emissive 贴图，
理由与星空背板一致（只加光、不吃光照、不挡后面的星点）。

只用 PIL，和 Test/gen_star_assets.py 同一套路（不引第三方素材）。
用法：python Test/gen_glow.py
"""
import os
import math


def make_glow(path, size=256, core=0.14, falloff=3.0):
	from PIL import Image
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	px = img.load()
	c = (size - 1) / 2.0
	total = 0.0
	for y in range(size):
		for x in range(size):
			dx = (x - c) / c
			dy = (y - c) / c
			d = math.sqrt(dx * dx + dy * dy)
			if d >= 1.0:
				px[x, y] = (0, 0, 0, 0)
				continue
			# 核心（d < core）几乎全亮，往外按 falloff 次幂衰减
			a = 1.0 if d <= core else (1.0 - (d - core) / (1.0 - core)) ** falloff
			# 暖白：核心偏白、外圈偏黄（真实日冕的观感）
			warm = 1.0 - d
			r = int(255 * a)
			g = int((236 + 19 * warm) * a)
			b = int((190 + 45 * warm) * a)
			px[x, y] = (r, g, b, int(255 * a))
			total += a
	img.save(path)
	return "glow.png %dx%d 平均亮度 %.3f" % (size, size, total / (size * size))


def make_sun_tex(path, size=64):
	"""太阳本体的自发光贴图：暖白，中心到边缘略降（拟"临边昏暗"）。

	⚠️ 为什么必须有这张（S3.12 实测）：引擎的 Material3D.emissive 只有在**配了自发光贴图**
	时才看得出来（星空背板就是这么用的）。太阳原来是靠场景方向光照亮才显得亮，
	一旦它自己变成光源（点光源在它内部 ⇒ 表面法线朝外、照不到），就只剩一颗**灰球**。
	"""
	from PIL import Image
	img = Image.new("RGB", (size, size))
	px = img.load()
	c = (size - 1) / 2.0
	for y in range(size):
		for x in range(size):
			dx = (x - c) / c
			dy = (y - c) / c
			d = min(1.0, (dx * dx + dy * dy) ** 0.5)
			k = 1.0 - 0.18 * d
			px[x, y] = (int(255 * k), int(246 * k), int(228 * k))
	img.save(path)
	return "sun_tex.png %dx%d" % (size, size)


def main():
	root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
	assets = os.path.join(root, "Assets")
	os.makedirs(os.path.join(assets, "Image"), exist_ok=True)
	print(make_glow(os.path.join(assets, "Image", "glow.png")))
	print(make_sun_tex(os.path.join(assets, "Image", "sun_tex.png")))


if __name__ == "__main__":
	main()
