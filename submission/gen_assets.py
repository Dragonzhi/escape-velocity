#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
《单程》Escape Velocity —— 比赛提交物素材生成（S4.1 图标 / S4.2 封面）

不依赖引擎、不引入第三方素材：底图全部来自仓库自有资源
  · Assets/Image/*.jpg|png                      （引擎在用的行星/太阳/星空贴图，代码生成）
  · .agent/test-results/level-*.png             （引擎实机截图，601x1066 竖屏）
  · C:/Windows/Fonts/msyh.ttc, msyhbd.ttc, seguisb.ttf   （系统字体）

用法（可从任意目录运行）：
    python submission/gen_assets.py            # 生成 icon + cover
    python submission/gen_assets.py icon       # 只生成图标
    python submission/gen_assets.py cover      # 只生成封面

产出：
    submission/icon-1024.png         1024x1024 RGB
    submission/cover-1080x1920.png   1080x1920 RGB
    submission/cover-1080x1920.jpg   1080x1920 RGB（比赛要求封面为 JPG）
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ---------------------------------------------------------------- 路径与常量

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Assets" / "Image"
SHOTS = ROOT / ".agent" / "test-results"
OUT = ROOT / "submission"
FONTS = Path("C:/Windows/Fonts")

F_HAN_BOLD = FONTS / "msyhbd.ttc"   # 微软雅黑 Bold（中文标题）
F_HAN = FONTS / "msyh.ttc"          # 微软雅黑 Regular
F_HAN_LIGHT = FONTS / "msyhl.ttc"   # 微软雅黑 Light（tagline）
F_LATIN = FONTS / "seguisb.ttf"     # Segoe UI Semibold（拉丁小标题）
F_LATIN_LIGHT = FONTS / "segoeui.ttf"

# sun.jpg 上的黑子在缩到 100px 时像脏点；x∈[150,560] 这块窗口没有黑子（已逐一核对）。
SUN_CLEAN_BOX = (150, 0, 560, 512)

SPACE_DEEP = (5, 7, 12)             # 深空底色（与游戏清屏色同族）
CYAN_TRAIL = (150, 216, 255)        # 预测线/轨迹的浅青
CYAN_GLOW = (70, 150, 220)

# ---------------------------------------------------------------- 基础工具


def load_rgb(path):
    return Image.open(path).convert("RGB")


def clean_sun():
    """太阳贴图的干净窗口 + 轻降噪（去掉 JPEG 噪点与黑子）。"""
    return load_rgb(ASSETS / "sun.jpg").crop(SUN_CLEAN_BOX).filter(ImageFilter.GaussianBlur(0.8))


def load_rgba(path):
    return Image.open(path).convert("RGBA")


def np_of(img):
    return np.asarray(img).astype(np.float32) / 255.0


def img_of(arr):
    return Image.fromarray((np.clip(arr, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8))


def over(base, color, alpha):
    """base/layer 皆为 0..1 float；alpha: (H,W,1) 或 (H,W)。"""
    if alpha.ndim == 2:
        alpha = alpha[..., None]
    col = np.asarray(color, dtype=np.float32) / 255.0
    return base * (1.0 - alpha) + col * alpha


def screen(base, glow, alpha):
    if alpha.ndim == 2:
        alpha = alpha[..., None]
    g = np.asarray(glow, dtype=np.float32) / 255.0 * alpha
    return 1.0 - (1.0 - base) * (1.0 - np.clip(g, 0.0, 1.0))


def radial_mask(w, h, cx, cy, r, power=2.0, inner=0.0):
    """以 (cx,cy) 为中心、半径 r 的径向衰减，返回 (H,W) float。inner 为实心比例。"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / max(r, 1e-6)
    m = np.clip(1.0 - d, 0.0, 1.0) ** power
    if inner > 0.0:
        m = np.clip((1.0 - d) / max(1.0 - inner, 1e-6), 0.0, 1.0) ** power
    return m.astype(np.float32)


def vgrad(h, w, y0, y1):
    """竖直方向 0→1 的线性渐变（y0 处 0，y1 处 1），返回 (H,W)。"""
    ys = np.arange(h, dtype=np.float32)[:, None]
    t = np.clip((ys - y0) / max(float(y1 - y0), 1e-6), 0.0, 1.0)
    return np.repeat(t, w, axis=1)


def vignette(w, h, strength=0.55, power=2.2):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (xx - w / 2.0) / (w / 2.0)
    ny = (yy - h / 2.0) / (h / 2.0)
    r = np.sqrt(nx * nx + ny * ny) / np.sqrt(2.0)
    return 1.0 - strength * (r ** power)


def starfield_panel(w, h, src, box, scale, gain=1.0, tint=(0.86, 0.93, 1.0), level=0.012, boost=1.9):
    """从仓库星空贴图取一块，缩放 + 调色，当作深空背景。"""
    patch = src.crop(box).resize((w, h), Image.BICUBIC)
    a = np_of(patch)
    a = np.clip((a - level) * boost * gain, 0.0, 1.0)
    a = a * np.asarray(tint, dtype=np.float32)
    return a


def tracked_text(draw, cx, cy, text, font, fill, tracking=0.0, anchor="lm"):
    """带字距的水平居中文本（逐字符绘制）。返回总宽度。"""
    widths = [font.getlength(ch) for ch in text]
    total = sum(widths) + tracking * max(len(text) - 1, 0)
    x = cx - total / 2.0
    for ch, w in zip(text, widths):
        draw.text((x, cy), ch, font=font, fill=fill, anchor=anchor)
        x += w + tracking
    return total


def dashed_arc_mask(size, cx, cy, r, a0, a1, width, dash, gap, alpha0=1.0, alpha1=1.0):
    """虚线圆弧，画进一张 L 掩膜（带首尾 alpha 渐变）。角度制，0=右侧，顺时针。"""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    span = a1 - a0
    n = max(int(round(abs(span) / (dash + gap))), 1)
    step = span / n
    for i in range(n):
        s = a0 + i * step
        e = s + step * (dash / (dash + gap))
        t = (i + 0.5) / n
        a = int(round(255 * (alpha0 + (alpha1 - alpha0) * t)))
        d.arc([cx - r, cy - r, cx + r, cy + r], s, e, fill=a, width=width)
    return m


def composite_mask(base, mask, color, blur=0.0, glow_gain=1.0):
    """把 L 掩膜当 alpha，用 color 覆盖到 base 上；blur>0 时先叠一层柔光。"""
    m = np_of(mask)
    if blur > 0:
        gm = np_of(mask.filter(ImageFilter.GaussianBlur(blur))) * glow_gain
        base = screen(base, color, gm)
    return over(base, color, m)


def sphere_disc(tex, out_px, lon0=0.0, lat0=0.0, limb=0.42, ss=2):
    """把等距柱状贴图映射成一个球面圆盘（正交视图），带边缘变暗。返回 RGBA，尺寸 out_px。"""
    D = int(out_px * ss)
    t = np_of(tex)
    th, tw, _ = t.shape
    yy, xx = np.mgrid[0:D, 0:D].astype(np.float32)
    nx = (xx + 0.5 - D / 2.0) / (D / 2.0)
    ny = -(yy + 0.5 - D / 2.0) / (D / 2.0)
    r2 = nx * nx + ny * ny
    nz = np.sqrt(np.clip(1.0 - r2, 0.0, None))
    lon = np.arctan2(nx, np.maximum(nz, 1e-6)) + lon0
    lat = np.arcsin(np.clip(ny, -1.0, 1.0)) * 0.82 + lat0
    u = (lon / (2.0 * np.pi) + 0.5) % 1.0
    v = np.clip(0.5 - lat / np.pi, 0.0, 1.0)

    fx = u * (tw - 1)
    fy = v * (th - 1)
    x0 = np.floor(fx).astype(np.int32)
    y0 = np.floor(fy).astype(np.int32)
    dx = (fx - x0)[..., None]
    dy = (fy - y0)[..., None]
    x0 = x0 % tw
    x1 = (x0 + 1) % tw
    y0 = np.clip(y0, 0, th - 1)
    y1 = np.clip(y0 + 1, 0, th - 1)
    c = (t[y0, x0] * (1 - dx) * (1 - dy) + t[y0, x1] * dx * (1 - dy)
         + t[y1, x0] * (1 - dx) * dy + t[y1, x1] * dx * dy)

    shade = (1.0 - limb * (1.0 - nz ** 0.55))[..., None]
    c = np.clip(c * shade, 0.0, 1.0)
    a = np.clip((1.0 - np.sqrt(r2)) * (D / 2.0), 0.0, 1.0)
    rgba = np.concatenate([c, a[..., None]], axis=2)
    disc = Image.fromarray((rgba * 255.0 + 0.5).astype(np.uint8))
    if ss != 1:
        disc = disc.resize((out_px, out_px), Image.LANCZOS)
    return disc


def paste_rgba(base, layer, x, y):
    """把 RGBA 图层 alpha 混合到 float base 上（x/y 为左上角，允许越界）。"""
    h, w, _ = base.shape
    lw, lh = layer.size
    y0, y1 = max(y, 0), min(y + lh, h)
    x0, x1 = max(x, 0), min(x + lw, w)
    if y0 >= y1 or x0 >= x1:
        return base
    sub = layer.crop((x0 - x, y0 - y, x1 - x, y1 - y))
    la = np_of(sub)[..., 3:4]
    lc = np_of(sub.convert("RGB"))
    region = base[y0:y1, x0:x1]
    base[y0:y1, x0:x1] = region * (1.0 - la) + lc * la
    return base


# ---------------------------------------------------------------- 图标（S4.1）

def probe_sprite(scale=1.0):
    """简易探测器图形（机体 + 太阳能板 + 天线），白/银 + 青色描边，小尺寸下也能读数。"""
    W, H = 190, 150
    ss = 3
    im = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    def s(v):
        return v * ss

    panel = (24, 34, 62)
    edge = (140, 214, 246, 255)
    for x0 in (2, 130):
        d.rectangle([s(x0), s(48), s(x0 + 58), s(100)], fill=panel + (255,), outline=edge, width=s(2))
        for i in range(1, 4):
            xx = x0 + 58 * i / 4.0
            d.line([s(xx), s(50), s(xx), s(98)], fill=(96, 158, 198, 255), width=s(1))
        d.line([s(x0 + 4), s(73), s(x0 + 54), s(73)], fill=(96, 158, 198, 255), width=s(1))
        # 支杆
        cx0 = 60 if x0 == 2 else 130
        d.line([s(cx0), s(74), s(88 if x0 == 2 else 102), s(74)], fill=(196, 208, 220, 255), width=s(3))

    body = [(95, 34), (112, 52), (112, 96), (95, 116), (78, 96), (78, 52)]
    d.polygon([(s(x), s(y)) for x, y in body], fill=(214, 224, 234, 255), outline=(255, 255, 255, 255))
    d.polygon([(s(95), s(40)), (s(106), s(54)), (s(106), s(92)), (s(95), s(108))], fill=(246, 250, 253, 255))
    d.ellipse([s(84), s(6), s(106), s(28)], fill=(232, 240, 248, 255), outline=(150, 200, 232, 255), width=s(2))
    d.ellipse([s(89), s(11), s(101), s(23)], fill=(28, 42, 60, 255))
    d.line([s(95), s(28), s(95), s(38)], fill=(210, 222, 234, 255), width=s(3))

    out = im.resize((int(W * scale), int(H * scale)), Image.LANCZOS)
    return out


def build_icon():
    S = 1024
    sf = load_rgb(ASSETS / "starfield.png")
    bg = starfield_panel(S, S, sf, (512, 0, 1024, 512), 2.0, boost=2.1, level=0.010)
    bg = bg * vignette(S, S, 0.62, 2.0)[..., None]
    base = np.clip(bg, 0.0, 1.0).copy()

    sun_c = (408.0, 452.0)
    sun_r = 232.0

    # 日冕 / 暖色光晕
    base = screen(base, (255, 148, 56), (radial_mask(S, S, sun_c[0], sun_c[1], 660, 2.8) * 0.62))
    base = screen(base, (255, 206, 130), (radial_mask(S, S, sun_c[0], sun_c[1], 420, 3.0) * 0.45))

    # 轨迹虚线（先算好掩膜，稍后连同辉光一起叠在太阳之上）
    arc_r = 348.0
    trail = dashed_arc_mask(S, sun_c[0], sun_c[1], arc_r, -74.0, 138.0, 24, 8.0, 5.0,
                            alpha0=0.40, alpha1=1.0)

    # 太阳（贴图取无黑子窗口；外缘补一圈亮边，小尺寸下更“实”）
    sun = sphere_disc(clean_sun(), int(sun_r * 2), lon0=0.0, lat0=-0.2, limb=0.34)
    base = screen(base, (255, 176, 96), radial_mask(S, S, sun_c[0], sun_c[1], sun_r + 26, 3.2) * 0.5)
    paste_rgba(base, sun, int(sun_c[0] - sun_r), int(sun_c[1] - sun_r))

    # 轨迹（叠在太阳上，表示路线从前面绕过去）
    base = composite_mask(base, trail, CYAN_TRAIL, blur=13.0, glow_gain=0.85)

    # 终点：探测器
    ang = np.deg2rad(138.0)
    px = sun_c[0] + arc_r * np.cos(ang)
    py = sun_c[1] + arc_r * np.sin(ang)
    probe = probe_sprite(1.24)
    base = paste_rgba(base, probe, int(px - probe.size[0] * 0.5), int(py - probe.size[1] * 0.5))

    # 起点：一颗小行星（示意“从地球出发”）
    ang0 = np.deg2rad(-74.0)
    ex = sun_c[0] + arc_r * np.cos(ang0)
    ey = sun_c[1] + arc_r * np.sin(ang0)
    base = screen(base, (120, 200, 255), radial_mask(S, S, ex, ey, 84, 2.6) * 0.5)
    earth = sphere_disc(load_rgb(ASSETS / "planet_earth.jpg"), 92, lon0=0.6, lat0=0.12, limb=0.5)
    base = paste_rgba(base, earth, int(ex - 46), int(ey - 46))

    base = base * vignette(S, S, 0.30, 2.6)[..., None]
    return img_of(base).convert("RGB")


# ---------------------------------------------------------------- 封面（S4.2）

COVER_W, COVER_H = 1080, 1920
# level-6.png（601x1066）里 HUD 的位置：右上按钮 y<=155，左下 Δv 文本 y<=50，
# 「发射日期」y<=155，底部引擎工具条 y>=975。裁 152..972 即得到干净画面（无任何 HUD）。
SHOT_CROP = (0, 152, 601, 972)
BAND_H = 1474


def build_cover(shot_name="level-6.png", crop=SHOT_CROP, band_h=BAND_H):
    shot = load_rgb(SHOTS / shot_name)
    band = shot.crop(crop)
    band = band.resize((COVER_W, band_h), Image.LANCZOS)

    sf = load_rgb(ASSETS / "starfield.png")
    bg = starfield_panel(COVER_W, COVER_H, sf, (300, 120, 1740, 1560), 1.4, boost=1.0, tint=(1.0, 1.0, 1.0))
    bg = bg * 0.55 + np.asarray(SPACE_DEEP, dtype=np.float32) / 255.0 * 0.45
    base = np.clip(bg, 0.0, 1.0).copy()

    # 照片左右两侧轻微压暗（电影感），并把下缘长距离溶解进深空底
    yy, xx = np.mgrid[0:band_h, 0:COVER_W].astype(np.float32)
    nx = np.abs(xx - COVER_W / 2.0) / (COVER_W / 2.0)
    shade = 1.0 - 0.16 * (nx ** 2.6)
    band_arr = np_of(band) * shade[..., None]

    fade = vgrad(COVER_H, COVER_W, 1250.0, 1478.0)     # y<1250 全照片，y>1478 全底色
    a_band = np.clip(1.0 - fade, 0.0, 1.0)[0:band_h, :, None]
    base[0:band_h] = base[0:band_h] * (1.0 - a_band) + band_arr * a_band

    # 标题区：一层很淡的冷光把底部从纯黑里托起来
    base = screen(base, (34, 58, 88), radial_mask(COVER_W, COVER_H, COVER_W * 0.5, 1720, 860, 2.4) * 0.5)

    img = img_of(base)
    d = ImageDraw.Draw(img)

    f_title = ImageFont.truetype(str(F_HAN_BOLD), 232)
    f_latin = ImageFont.truetype(str(F_LATIN), 56)
    f_tag = ImageFont.truetype(str(F_HAN_LIGHT), 48)
    f_route = ImageFont.truetype(str(F_HAN), 28)

    rule_w, rule_y = 132, 1494
    d.rectangle([COVER_W // 2 - rule_w // 2, rule_y, COVER_W // 2 + rule_w // 2, rule_y + 3],
                fill=(126, 178, 210))

    tracked_text(d, COVER_W / 2, 1618, "单程", f_title, (255, 255, 255), tracking=26)
    tracked_text(d, COVER_W / 2, 1746, "ESCAPE VELOCITY", f_latin, (176, 208, 228), tracking=14)
    tracked_text(d, COVER_W / 2, 1814, "一次没有返程的旅行", f_tag, (140, 158, 172), tracking=10)
    tracked_text(d, COVER_W / 2, 1880,
                 "月球 · 金星 · 木星 · 土星 · 天王星 · 海王星", f_route, (98, 116, 132), tracking=6)
    return img


# ---------------------------------------------------------------- 入口

def save_qa(img, name, size):
    """缩到小尺寸存一份，用来核对「缩到 100px 还认不认得出」。"""
    SHOTS.mkdir(parents=True, exist_ok=True)
    p = SHOTS / name
    img.resize(size, Image.LANCZOS).save(p, optimize=True)
    return p


def main(argv):
    OUT.mkdir(parents=True, exist_ok=True)
    what = argv[1].lower() if len(argv) > 1 else "all"
    made = []
    if what in ("all", "icon", "qa"):
        icon = build_icon()
        if what in ("all", "icon"):
            p = OUT / "icon-1024.png"
            icon.save(p, optimize=True)
            made.append(p)
        save_qa(icon, "s4-icon-100.png", (100, 100))
        save_qa(icon, "s4-icon-192.png", (192, 192))
    if what in ("all", "cover", "qa"):
        cover = build_cover()
        if what in ("all", "cover"):
            p = OUT / "cover-1080x1920.png"
            cover.save(p, optimize=True)
            made.append(p)
            pj = OUT / "cover-1080x1920.jpg"
            cover.save(pj, quality=94, subsampling=0, optimize=True)
            made.append(pj)
        save_qa(cover, "s4-cover-thumb.png", (270, 480))
    if what == "variants":
        # 候选底图对比（只写到 test-results，不进 submission/）
        for nm, crop in (("level-1.png", (0, 152, 601, 900)), ("level-4.png", (0, 152, 601, 972)),
                         ("level-6.png", SHOT_CROP)):
            v = build_cover(nm, crop, int((crop[3] - crop[1]) * COVER_W / 601.0))
            tag = nm.replace("level-", "L").replace(".png", "")
            p = SHOTS / ("s4-cover-" + tag + ".png")
            v.resize((360, 640), Image.LANCZOS).save(p, optimize=True)
            made.append(p)
    for p in made:
        print("wrote", p.relative_to(ROOT), p.stat().st_size, "bytes")


if __name__ == "__main__":
    main(sys.argv)
