#!/usr/bin/env python3
"""Writes the sample app's music on hold: a calm, looping tune of soft bell tones, made here so
the repository ships no recording. Mono 16-bit WAV at the given sample rate; the app bundles it
at 16 kHz as SampleApp/Sounds/HoldMusic.wav.

Usage: hold_music.py <output.wav> [sample rate, default 16000]"""

import math
import struct
import sys
import wave

BEAT = 0.5  # seconds

# (MIDI note, beats): I - vi - IV - V in C major, arpeggiated, then a resolving phrase.
TUNE = [
    (60, 1), (64, 1), (67, 1), (72, 1),
    (57, 1), (60, 1), (64, 1), (69, 1),
    (53, 1), (57, 1), (60, 1), (65, 1),
    (55, 1), (59, 1), (62, 1), (67, 1),
    (64, 2), (62, 2), (60, 3), (0, 1),
]


def tone(note: int, seconds: float, rate: int) -> list[float]:
    count = int(rate * seconds)
    if note == 0:
        return [0.0] * count
    freq = 440.0 * 2 ** ((note - 69) / 12)
    out = []
    for i in range(count):
        t = i / rate
        # A soft attack and a long decay, with a quiet octave for a bell-like colour.
        envelope = min(1.0, t / 0.02) * math.exp(-2.5 * t)
        value = math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(4 * math.pi * freq * t)
        out.append(envelope * value)
    return out


def main(path: str, rate: int) -> None:
    samples: list[float] = []
    for note, beats in TUNE:
        samples += tone(note, beats * BEAT, rate)
    peak = max(abs(s) for s in samples) or 1.0
    frames = b"".join(struct.pack("<h", int(s / peak * 0.5 * 32767)) for s in samples)
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(frames)


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 16000)
