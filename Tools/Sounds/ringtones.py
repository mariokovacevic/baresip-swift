#!/usr/bin/env python3
"""Writes the sample app's ringtones, made here so the repository ships no recordings: Chime (a
two-note door chime), Bells (a bright arpeggio) and Classic (a telephone's double ring). Mono
16-bit WAV at 22.05 kHz, each a few seconds that CallKit repeats while the call rings.

Usage: ringtones.py <output directory>"""

import math
import os
import struct
import sys
import wave

RATE = 22050


def bell(freq: float, seconds: float, decay: float = 3.0) -> list[float]:
    """A struck tone: fast attack, exponential decay, a few inharmonic partials."""
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        env = min(1.0, t / 0.005) * math.exp(-decay * t)
        v = (math.sin(2 * math.pi * freq * t)
             + 0.45 * math.sin(2 * math.pi * freq * 2.0 * t) * math.exp(-2 * t)
             + 0.25 * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-4 * t))
        out.append(env * v)
    return out


def ring(seconds: float) -> list[float]:
    """A telephone ring: 440 and 480 Hz together, warbling at 20 Hz."""
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        env = min(1.0, t / 0.01, (seconds - t) / 0.01)
        warble = 0.6 + 0.4 * math.sin(2 * math.pi * 20 * t)
        out.append(env * warble * (math.sin(2 * math.pi * 440 * t) + math.sin(2 * math.pi * 480 * t)))
    return out


def silence(seconds: float) -> list[float]:
    return [0.0] * int(RATE * seconds)


def mix_at(base: list[float], start: float, part: list[float]) -> None:
    offset = int(RATE * start)
    if len(base) < offset + len(part):
        base.extend([0.0] * (offset + len(part) - len(base)))
    for i, value in enumerate(part):
        base[offset + i] += value


def note(midi: int) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def chime() -> list[float]:
    out: list[float] = []
    mix_at(out, 0.0, bell(note(76), 1.6, 2.2))   # E5
    mix_at(out, 0.7, bell(note(72), 2.2, 1.8))   # C5
    return out + silence(3.6 - len(out) / RATE)


def bells() -> list[float]:
    out: list[float] = []
    for n, midi in enumerate([84, 88, 91, 96, 91, 88]):  # C6 E6 G6 C7 G6 E6
        mix_at(out, n * 0.16, bell(note(midi), 0.9, 4.0))
    return out + silence(3.0 - len(out) / RATE)


def classic() -> list[float]:
    return ring(0.4) + silence(0.2) + ring(0.4) + silence(2.0)


def write(path: str, samples: list[float]) -> None:
    peak = max(abs(s) for s in samples) or 1.0
    frames = b"".join(struct.pack("<h", int(s / peak * 0.7 * 32767)) for s in samples)
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)


def main(directory: str) -> None:
    for name, samples in (("Chime", chime()), ("Bells", bells()), ("Classic", classic())):
        write(os.path.join(directory, f"{name}.wav"), samples)


if __name__ == "__main__":
    main(sys.argv[1])
