"""Generate the placeholder chiptune music and sound effects (original, synthesized).

Run from the project root:  python tools/gen_audio.py   (needs numpy)
Everything lands in assets/audio/:
  bgm_<id>.wav   loops (a WAV 'smpl' chunk marks the loop, Godot loops it on import)
  sfx_<id>.wav   one-shots
22050 Hz mono 16-bit. Godot compresses them on import (QOA, see the .import files).
Replace any file with real audio of the same name later; the game picks it up.

Music is written as note lists below: "C5:4" = C in octave 5 for 4 sixteenth steps,
"-:4" = rest. Every bar must add up to 16 steps.
"""
import struct
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050
RNG = np.random.default_rng(20261117)

NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
              "Bb": 10, "Eb": 3, "Ab": 8, "Db": 1, "Gb": 6}


def freq(name):
    """'A4' -> 440.0"""
    pitch, octave = name[:-1], int(name[-1])
    n = NOTE_INDEX[pitch] + 12 * (octave + 1)
    return 440.0 * 2 ** ((n - 69) / 12)


# ------------------------------------------------------------------ oscillators
def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def pulse(f, dur, duty=0.5):
    ph = (t_axis(dur) * f) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def triangle(f, dur):
    ph = (t_axis(dur) * f) % 1.0
    return 4.0 * np.abs(ph - 0.5) - 1.0


def sine(f, dur):
    return np.sin(2 * np.pi * f * t_axis(dur))


def sweep(f0, f1, dur, shape="square"):
    t = t_axis(dur)
    f = np.linspace(f0, f1, t.size)
    ph = np.cumsum(f) / SR
    if shape == "sine":
        return np.sin(2 * np.pi * ph)
    if shape == "tri":
        return 4.0 * np.abs((ph % 1.0) - 0.5) - 1.0
    return np.where((ph % 1.0) < 0.5, 1.0, -1.0)


def noise(dur):
    return RNG.uniform(-1, 1, int(SR * dur))


def env(x, attack=0.005, decay=0.08, sustain=0.6, release=0.04):
    n = x.size
    e = np.full(n, sustain)
    a = min(n, int(SR * attack))
    d = min(n - a, int(SR * decay))
    r = min(n, int(SR * release))
    if a:
        e[:a] = np.linspace(0, 1, a)
    if d:
        e[a:a + d] = np.linspace(1, sustain, d)
    if r:
        e[n - r:] *= np.linspace(1, 0, r)
    return x * e


def decay_env(x, k):
    return x * np.exp(-np.arange(x.size) / (SR * k))


def lowpass(x, a=0.2):
    """One-pole low-pass (softens square waves and noise)."""
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


# ------------------------------------------------------------------ drums
def kick():
    return decay_env(sweep(140, 45, 0.16, "sine"), 0.05)


def snare():
    n = decay_env(noise(0.14), 0.035)
    return 0.7 * n + 0.4 * decay_env(sine(190, 0.14), 0.03)


def hat():
    n = noise(0.035)
    n = n - np.concatenate(([0.0], n[:-1]))  # crude high-pass
    return decay_env(n, 0.008) * 0.6


DRUMS = {"k": kick, "s": snare, "h": hat}


# ------------------------------------------------------------------ tracker
def parse(seq):
    """'C5:4 -:2 E5:2' -> [(freq or None, steps), ...]"""
    out = []
    for tok in seq.split():
        name, steps = tok.split(":")
        out.append((None if name == "-" else freq(name), int(steps)))
    return out


def render_song(bpm, bars, lead, bass, chords, drums, lead_shape, vol):
    """bars: count. lead/bass: note strings (whole song). chords: list of chord note lists per bar
    (arpeggiated). drums: 16-char pattern per bar type, cycled."""
    step = 60.0 / bpm / 4
    total = int(SR * step * 16 * bars)
    tail = SR  # room for release tails, wrapped back to the start
    mix = np.zeros(total + tail)

    def place(sig, start_step, gain):
        i = int(round(start_step * step * SR))
        mix[i:i + sig.size] += sig[: mix.size - i] * gain

    def voice(seq, make, gain):
        pos = 0
        for f, steps in parse(seq):
            if f is not None:
                place(make(f, steps * step), pos, gain)
            pos += steps
        assert pos == bars * 16, f"sequence is {pos} steps, expected {bars * 16}"

    shapes = {
        "box": lambda f, d: env(decay_env(pulse(f, d + 0.25, 0.5), 0.22) * 0.8
                                + decay_env(sine(f * 2, d + 0.25), 0.12) * 0.2, 0.004, 0.0, 1.0, 0.03),
        "lead": lambda f, d: env(pulse(f, d, 0.25), 0.004, 0.06, 0.55, 0.03),
        "drive": lambda f, d: env(pulse(f, d, 0.125), 0.002, 0.04, 0.6, 0.02),
    }
    voice(lead, shapes[lead_shape], vol["lead"])
    voice(bass, lambda f, d: env(triangle(f, d), 0.003, 0.05, 0.85, 0.02), vol["bass"])
    for b, chord in enumerate(chords):  # 8th-note arpeggio
        fs = [freq(n) for n in chord]
        for k in range(8):
            f = fs[k % len(fs)]
            place(env(pulse(f, step * 1.6, 0.5), 0.002, 0.05, 0.3, 0.03), b * 16 + k * 2, vol["arp"])
    for b in range(bars):
        pat = drums[b % len(drums)]
        for k, ch in enumerate(pat):
            if ch in DRUMS:
                place(DRUMS[ch](), b * 16 + k, vol["drums"] * (0.6 if ch == "h" else 1.0))
    mix[:tail] += mix[total:total + tail]  # seamless loop
    mix = lowpass(mix[:total], 0.55)
    return mix / max(1e-6, np.max(np.abs(mix))) * 0.8


# ------------------------------------------------------------------ songs
def song_home():
    """Title / home: a warm music-box tune. F major, 92 BPM, 8 bars."""
    lead = (
        "A4:4 C5:4 F5:6 E5:2 "
        "D5:4 C5:4 A4:8 "
        "Bb4:4 D5:4 F5:4 D5:4 "
        "E5:6 D5:2 C5:8 "
        "A4:4 C5:4 F5:4 G5:4 "
        "A5:6 G5:2 F5:4 D5:4 "
        "D5:4 F5:4 E5:4 G5:4 "
        "F5:12 -:4"
    )
    roots = ["F2", "D2", "A#1", "C2", "F2", "D2", "A#1", "F2"]
    fifths = ["C3", "A2", "F2", "G2", "C3", "A2", "F2", "C3"]
    bass = " ".join(f"{r}:4 {f}:4 {r[:-1] + str(int(r[-1]) + 1)}:4 {f}:4" for r, f in zip(roots, fifths))
    chords = [["F4", "A4", "C5"], ["D4", "F4", "A4"], ["A#3", "D4", "F4"], ["C4", "E4", "G4"],
              ["F4", "A4", "C5"], ["D4", "F4", "A4"], ["A#3", "D4", "F4"], ["F4", "A4", "C5"]]
    drums = ["k---h---k---h---"]
    return render_song(92, 8, lead, bass, chords, drums, "box",
                       {"lead": 0.30, "bass": 0.30, "arp": 0.05, "drums": 0.10})


def song_town():
    """Office and destinations: bouncy work theme. C major, 112 BPM, 16 bars (A + B)."""
    lead = (
        "E5:2 G5:2 -:2 G5:2 A5:2 G5:2 E5:4 "
        "C5:2 E5:2 -:2 E5:2 D5:2 C5:2 A4:4 "
        "F4:2 A4:2 C5:2 F5:2 E5:4 C5:4 "
        "D5:2 E5:2 D5:2 B4:2 G4:8 "
        "E5:2 G5:2 -:2 G5:2 C6:2 B5:2 G5:4 "
        "A5:2 G5:2 E5:2 C5:2 E5:4 -:4 "
        "F5:2 E5:2 D5:2 F5:2 A5:4 F5:4 "
        "G5:4 F5:2 E5:2 D5:8 "
        "A5:4 G5:2 F5:2 C5:4 F5:4 "
        "G5:4 F5:2 E5:2 D5:4 B4:4 "
        "E5:2 G5:2 B5:4 A5:2 G5:2 E5:4 "
        "C5:2 E5:2 A5:4 G5:4 E5:4 "
        "D5:2 F5:2 A5:4 C6:4 A5:4 "
        "B5:4 A5:2 G5:2 F5:4 D5:4 "
        "E5:2 D5:2 C5:2 E5:2 G5:4 E5:4 "
        "C5:8 -:8"
    )
    roots = ["C2", "A1", "F1", "G1", "C2", "A1", "D2", "G1", "F1", "G1", "E2", "A1", "D2", "G1", "C2", "C2"]
    bass = " ".join(f"{r}:2 -:2 {r[:-1] + str(int(r[-1]) + 1)}:2 -:2 {r}:2 -:2 {r[:-1] + str(int(r[-1]) + 1)}:2 -:2"
                    for r in roots)
    C, Am, F, G, Dm, Em = ["C4", "E4", "G4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"], \
        ["D4", "F4", "A4"], ["E4", "G4", "B4"]
    chords = [C, Am, F, G, C, Am, Dm, G, F, G, Em, Am, Dm, G, C, C]
    drums = ["k---s---k-k-s---", "k---s---k---s-hh"]
    return render_song(112, 16, lead, bass, chords, drums, "lead",
                       {"lead": 0.24, "bass": 0.34, "arp": 0.05, "drums": 0.16})


def song_drive():
    """Driving minigame: energetic. A minor, 140 BPM, 16 bars."""
    lead = (
        "A4:2 C5:2 E5:2 A5:4 G5:2 E5:4 "
        "F5:2 E5:2 C5:2 A4:4 C5:2 F5:4 "
        "G5:2 F5:2 D5:2 B4:4 D5:2 G5:4 "
        "E5:6 D5:2 B4:4 G4:4 "
        "A4:2 C5:2 E5:2 A5:4 B5:2 C6:4 "
        "C6:2 A5:2 F5:2 C5:4 F5:2 A5:4 "
        "B5:2 G5:2 D5:2 B4:4 D5:2 G5:4 "
        "G#5:4 E5:4 B4:4 E5:4 "
        "F5:4 A5:4 C6:4 A5:4 "
        "G5:4 B5:4 D6:4 B5:4 "
        "C6:2 B5:2 A5:2 E5:2 A5:8 "
        "-:4 E5:2 A5:2 C6:2 E6:2 C6:4 "
        "F5:2 G5:2 A5:2 C6:2 A5:4 F5:4 "
        "G5:2 A5:2 B5:2 D6:2 B5:4 G5:4 "
        "G#5:2 B5:2 E6:4 D6:2 B5:2 G#5:4 "
        "E5:8 -:8"
    )
    roots = ["A1", "F1", "G1", "E1", "A1", "F1", "G1", "E1", "F1", "G1", "A1", "A1", "F1", "G1", "E1", "E1"]
    bass = " ".join(" ".join(f"{r if k % 2 == 0 else r[:-1] + str(int(r[-1]) + 1)}:2" for k in range(8)) for r in roots)
    Am, F, G, Em, E = ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"], ["E3", "G3", "B3"], ["E3", "G#3", "B3"]
    chords = [Am, F, G, Em, Am, F, G, E, F, G, Am, Am, F, G, E, E]
    drums = ["k-h-s-h-k-k-s-h-", "k-h-s-h-k-h-s-ss"]
    return render_song(140, 16, lead, bass, chords, drums, "drive",
                       {"lead": 0.22, "bass": 0.34, "arp": 0.04, "drums": 0.2})


# ------------------------------------------------------------------ sound effects
def seq_notes(notes, dur, shape="square", duty=0.5, gap=0.0, last=None):
    parts = []
    for i, n in enumerate(notes):
        d = last if (last and i == len(notes) - 1) else dur
        f = freq(n)
        tone = pulse(f, d, duty) if shape == "square" else triangle(f, d)
        parts.append(env(tone, 0.002, 0.03, 0.6, min(0.05, d / 3)))
        if gap:
            parts.append(np.zeros(int(SR * gap)))
    return np.concatenate(parts)


def sfx():
    s = {}
    s["blip"] = env(pulse(1500, 0.018, 0.5), 0.001, 0.005, 0.5, 0.008) * 0.35
    s["select"] = env(pulse(1046, 0.035, 0.25), 0.001, 0.01, 0.6, 0.015) * 0.5
    s["confirm"] = np.concatenate([env(pulse(784, 0.04, 0.25), 0.001, 0.01, 0.6, 0.01),
                                   env(pulse(1175, 0.07, 0.25), 0.001, 0.02, 0.6, 0.03)]) * 0.5
    s["cancel"] = np.concatenate([env(pulse(659, 0.04, 0.25), 0.001, 0.01, 0.6, 0.01),
                                  env(pulse(440, 0.07, 0.25), 0.001, 0.02, 0.6, 0.03)]) * 0.5
    s["pop"] = decay_env(sweep(600, 1100, 0.07, "sine"), 0.03) * 0.6
    s["coin"] = np.concatenate([env(pulse(988, 0.05, 0.25), 0.001, 0.01, 0.7, 0.005),
                                decay_env(pulse(1319, 0.3, 0.25), 0.09)]) * 0.45
    s["bad"] = env(sweep(220, 110, 0.25), 0.003, 0.05, 0.7, 0.06) * 0.4
    s["warn"] = seq_notes(["E5", "E5"], 0.06, gap=0.04) * 0.45
    s["levelup"] = seq_notes(["C5", "E5", "G5", "C6", "E6"], 0.07, duty=0.25, last=0.4) * 0.45
    s["jingle_good"] = seq_notes(["G4", "C5", "E5", "G5"], 0.09, duty=0.25, last=0.45) * 0.45
    s["jingle_bad"] = seq_notes(["E4", "D#4", "D4"], 0.16, duty=0.5, last=0.4) * 0.4
    thud = decay_env(sweep(160, 40, 0.18, "sine"), 0.05)
    s["stamp"] = (np.concatenate([thud, np.zeros(SR // 10)])
                  + np.concatenate([lowpass(decay_env(noise(0.06), 0.015), 0.4), np.zeros(int(SR * 0.22))])[: thud.size + SR // 10]) * 0.8
    wh = noise(0.3) * np.sin(np.linspace(0, np.pi, int(SR * 0.3)))
    s["door"] = lowpass(wh, 0.08) * 0.9
    s["crash"] = (lowpass(decay_env(noise(0.3), 0.08), 0.3) * 0.9
                  + np.concatenate([decay_env(sweep(120, 40, 0.2, "sine"), 0.06), np.zeros(int(SR * 0.1))])) * 0.6
    s["star"] = seq_notes(["E6", "G#6", "B6", "E7"], 0.035, duty=0.25, last=0.15) * 0.35
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * 18 * t_axis(0.3))
    s["repair"] = env(sweep(400, 1300, 0.3, "tri"), 0.005, 0.05, 0.8, 0.05) * trem * 0.5
    nom = decay_env(sweep(320, 180, 0.08, "sine"), 0.04)
    s["nom"] = np.concatenate([nom, np.zeros(int(SR * 0.04)), nom * 0.8]) * 0.7
    s["ticket"] = np.concatenate([env(pulse(1568, 0.06, 0.5), 0.001, 0.01, 0.6, 0.01), np.zeros(int(SR * 0.04)),
                                  env(pulse(1568, 0.06, 0.5), 0.001, 0.01, 0.6, 0.01), np.zeros(int(SR * 0.05)),
                                  lowpass(noise(0.25), 0.25) * 0.5]) * 0.4
    s["alarm"] = seq_notes(["E6", "C6"] * 4, 0.07, gap=0.02) * 0.35
    s["sleep"] = seq_notes(["G5", "E5", "C5", "G4"], 0.22, shape="tri", last=0.7) * 0.5
    s["engine"] = env(sweep(60, 140, 0.45) * 0.5 + noise(0.45) * 0.2, 0.02, 0.1, 0.7, 0.15) * 0.4
    return s


# ------------------------------------------------------------------ output
def write_wav(path, data, loop=False):
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    if loop:  # append a 'smpl' chunk with one forward loop over the whole file
        body = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        body += struct.pack("<6I", 0, 0, 0, pcm.size - 1, 0, 0)
        chunk = b"smpl" + struct.pack("<I", len(body)) + body
        raw = bytearray(path.read_bytes())
        raw += chunk
        struct.pack_into("<I", raw, 4, len(raw) - 8)
        path.write_bytes(bytes(raw))


if __name__ == "__main__":
    for name, fn in (("home", song_home), ("town", song_town), ("drive", song_drive)):
        data = fn()
        write_wav(OUT / f"bgm_{name}.wav", data, loop=True)
        print(f"bgm_{name}.wav  {data.size / SR:.1f}s")
    for name, data in sfx().items():
        peak = max(1e-6, np.max(np.abs(data)))
        data = data / peak * min(peak, 0.9)
        fade_in, fade_out = min(data.size, int(SR * 0.001)), min(data.size, int(SR * 0.006))
        data[:fade_in] *= np.linspace(0, 1, fade_in)  # no clicks at either end
        data[data.size - fade_out:] *= np.linspace(1, 0, fade_out)
        write_wav(OUT / f"sfx_{name}.wav", data)
    print("audio written to", OUT)
