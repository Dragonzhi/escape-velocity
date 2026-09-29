"""Generate the original optimistic goal-completion cue (standard library only).

Run from the repository root: python tools/gen_success_cue.py
No external recording, samples, or runtime dependency. D-major rising bell arpeggio.
"""
import math
from pathlib import Path
import struct
import wave

RATE = 44100
DURATION = 0.85
NOTES = [(0.00, 587.3295), (0.10, 739.9888), (0.20, 880.0), (0.32, 1174.6591)]


def generate(destination: Path) -> None:
    samples = []
    for i in range(round(RATE * DURATION)):
        t = i / RATE
        value = 0.0
        for onset, frequency in NOTES:
            age = t - onset
            if age < 0:
                continue
            attack = min(1.0, age / 0.008)
            release = min(1.0, max(0.0, (DURATION - t) / 0.10))
            envelope = attack * math.exp(-age * 5.8) * release
            phase = 2 * math.pi * frequency * age
            value += envelope * (math.sin(phase) + 0.18 * math.sin(2 * phase) + 0.04 * math.sin(3 * phase))
        samples.append(value)
    gain = 0.72 / max(abs(value) for value in samples)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(destination), 'wb') as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b''.join(struct.pack('<hh', round(value * gain * 32767), round(value * gain * 32767)) for value in samples))
    print(f'{destination}: {DURATION:.2f}s, stereo PCM16, {RATE}Hz, peak 0.72')


if __name__ == '__main__':
    generate(Path(__file__).resolve().parents[1] / 'Assets/Audio/gate_reach.wav')
