# Galactic Temple

- 作者：yd
- 原始发布：https://opengameart.org/content/galactic-temple
- 原始压缩包：https://opengameart.org/sites/default/files/GalacticTemple.zip
- 许可：CC0 1.0 Universal（作者发布页明确标示CC0）
- 许可文本：https://creativecommons.org/publicdomain/zero/1.0/legalcode
- 下载日期：2026-09-29
- 来源工程：`Source/GalacticTemple.mmpz`，从作者压缩包原样保存。
- 游戏文件：`bgm_galactic_temple.ogg`，44.1kHz双声道Vorbis，173.143946秒。
- 处理：仅对原音频做峰值0.88的整体增益并重新编码为Vorbis；保留完整时长。原始首尾差小于0.00003，无需裁剪或交叉淡化。

此音乐使用自身的CC0许可，项目代码的AGPL-3.0-only许可保持不变。CC0不要求署名，仍在此记录作者和来源。

## 原创目标完成音效

`gate_reach.wav` 由仓库内 `tools/gen_success_cue.py` 合成，不引用录音或第三方采样。0.85秒，44.1kHz双声道PCM16，峰值0.72；以D大调上行琶音表达完成，短起音与柔和衰减避免失败感。运行 `python tools/gen_success_cue.py` 可重建，与项目其余原创内容采用相同许可。
