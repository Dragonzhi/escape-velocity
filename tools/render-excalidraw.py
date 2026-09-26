#!/usr/bin/env python3
"""把 .excalidraw（JSON）渲染成 PNG —— 让 Agent 能"看见"用户的参考图/示意图。

为什么需要：Excalidraw 文件是纯 JSON，Agent 读得到坐标却看不到画面；用户画的比例尺/构图草图
恰恰是"说不清、画得清"的东西。这个脚本把矩形/椭圆/菱形/线/箭头/文字画出来，缩放到一张 PNG。

用法：python tools/render-excalidraw.py <file.excalidraw> [out.png]
"""
import json, sys, os, math
from PIL import Image, ImageDraw, ImageFont


def font(size):
    for p in (r"C:\\Windows\\Fonts\\msyh.ttc", r"C:\\Windows\\Fonts\\simhei.ttf", r"C:\\Windows\\Fonts\\arial.ttf"):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, int(size))
            except Exception:
                pass
    return ImageFont.load_default()


def main():
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(src)[0] + ".png"
    data = json.load(open(src, encoding="utf-8"))
    els = [e for e in data.get("elements", []) if not e.get("isDeleted")]
    if not els:
        print("no elements")
        return
    xs, ys, xe, ye = [], [], [], []
    for e in els:
        xs.append(e["x"]); ys.append(e["y"])
        xe.append(e["x"] + e.get("width", 0)); ye.append(e["y"] + e.get("height", 0))
    x0, y0, x1, y1 = min(xs), min(ys), max(xe), max(ye)
    W = max(x1 - x0, 1.0); H = max(y1 - y0, 1.0)
    maxpx = 1500.0
    s = min(maxpx / W, maxpx / H, 3.0)
    pad = 40
    img = Image.new("RGB", (int(W * s) + 2 * pad, int(H * s) + 2 * pad), (255, 255, 255))
    d = ImageDraw.Draw(img)

    def P(x, y):
        return ((x - x0) * s + pad, (y - y0) * s + pad)

    def col(c, dflt):
        if c in (None, "transparent"):
            return dflt
        return c

    for e in els:
        t = e.get("type")
        x, y, w, h = e["x"], e["y"], e.get("width", 0), e.get("height", 0)
        stroke = col(e.get("strokeColor"), (30, 30, 30))
        bg = col(e.get("backgroundColor"), None)
        lw = max(1, int(e.get("strokeWidth", 1) * s))
        box = [P(x, y), P(x + w, y + h)]
        if t == "rectangle":
            d.rectangle([box[0], box[1]], outline=stroke, width=lw, fill=bg)
        elif t == "ellipse":
            d.ellipse([box[0], box[1]], outline=stroke, width=lw, fill=bg)
        elif t == "diamond":
            cx, cy = (box[0][0] + box[1][0]) / 2, (box[0][1] + box[1][1]) / 2
            d.polygon([(cx, box[0][1]), (box[1][0], cy), (cx, box[1][1]), (box[0][0], cy)], outline=stroke, fill=bg)
        elif t in ("line", "arrow", "freedraw"):
            pts = [P(x + px, y + py) for px, py in e.get("points", [])]
            if len(pts) >= 2:
                d.line(pts, fill=stroke, width=lw, joint="curve")
                if t == "arrow":
                    (ax, ay), (bx, by) = pts[-2], pts[-1]
                    ang = math.atan2(by - ay, bx - ax); L = 10 + 3 * lw
                    for da in (math.radians(155), math.radians(-155)):
                        d.line([(bx, by), (bx + L * math.cos(ang + da), by + L * math.sin(ang + da))], fill=stroke, width=lw)
        elif t == "text":
            size = e.get("fontSize", 20) * s
            f = font(size)
            txt = e.get("text", "")
            lh = size * 1.28
            tx, ty = P(x, y)
            for i, line in enumerate(txt.split("\n")):
                d.text((tx, ty + i * lh), line, fill=stroke, font=f)

    img.save(out)
    kinds = {}
    for e in els:
        kinds[e.get("type")] = kinds.get(e.get("type"), 0) + 1
    print("rendered", out, img.size, "elements:", kinds)


if __name__ == "__main__":
    main()
