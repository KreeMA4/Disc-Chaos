#!/usr/bin/env python3
"""Synthesizes every DISC CHAOS sound effect and music loop from scratch (numpy only).
Deterministic: re-running produces identical files. Output: assets/audio/{sfx,music}/*.wav"""
import numpy as np, wave, os, sys
SR = 22050
rng = np.random.default_rng(1234)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, d=0.1, s=0.0, r=0.05, total=None):
    total = total or n / SR
    tt = np.arange(n) / SR
    e = np.where(tt < a, tt / max(a, 1e-6), 1.0)
    e *= np.where(tt > a, np.exp(-(tt - a) / max(d, 1e-6)) * (1 - s) + s, 1.0)
    rel = np.clip((total - tt) / max(r, 1e-6), 0, 1)
    return e * rel
def sine(f, d, ph=0): return np.sin(2 * np.pi * np.cumsum(np.broadcast_to(f, (int(SR * d),))) / SR + ph)
def tri(f, d):
    p = np.cumsum(np.broadcast_to(f, (int(SR * d),))) / SR
    return 2 * np.abs(2 * (p % 1) - 1) - 1
def sq(f, d, duty=0.5):
    p = np.cumsum(np.broadcast_to(f, (int(SR * d),))) / SR
    return np.where((p % 1) < duty, 1.0, -1.0)
def saw(f, d):
    p = np.cumsum(np.broadcast_to(f, (int(SR * d),))) / SR
    return 2 * (p % 1) - 1
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def lp(x, a):  # one-pole lowpass, a in (0,1]
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc); y[i] = acc
    return y
def hp(x, a): return x - lp(x, a)
def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak
def write(path, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
def sfx(name, x, peak=0.85): write(os.path.join(OUT, "sfx", name + ".wav"), norm(x, peak))
def mix(*parts):
    n = max(len(p) for p in parts); y = np.zeros(n)
    for p in parts: y[:len(p)] += p
    return y
def pad(x, d):
    x = np.asarray(x, dtype=float); y = np.zeros(int(SR * d)); n = min(len(x), len(y)); y[:n] = x[:n]; return y
def place(buf, seg, pos):
    o = int(pos * SR)
    if o >= len(buf): return
    e = min(len(buf), o + len(seg)); buf[o:e] += seg[:e-o]

# ----------------------------------------------------------------- SFX
d = 0.09; x = lp(noise(d), 0.25) * env(int(SR*d), 0.002, 0.03); sfx("step", x, 0.5)
d = 0.25; f = np.linspace(260, 520, int(SR*d)); sfx("jump", tri(f, d) * env(int(SR*d), 0.005, 0.12) * 0.8 + lp(noise(d), 0.1) * env(int(SR*d), 0.001, 0.03) * 0.3, 0.6)
d = 0.12; sfx("grab", mix(sine(np.linspace(500, 700, int(SR*d)), d) * env(int(SR*d), 0.002, 0.04), lp(noise(d), 0.5) * env(int(SR*d), 0.001, 0.015) * 0.6), 0.6)
d = 0.06; sfx("click", mix(sq(2400, d, 0.3) * env(int(SR*d), 0.0005, 0.008), hp(noise(d), 0.3) * env(int(SR*d), 0.0005, 0.01)), 0.7)
d = 0.35; sfx("disc_in", mix(hp(noise(d), 0.2) * env(int(SR*d), 0.001, 0.06) * 0.5, sine(1800, d) * env(int(SR*d), 0.001, 0.12) * 0.4, pad(sq(3000, 0.03, 0.3) * env(int(SR*0.03), 0.0005, 0.006), d)[::-1][::-1] * 0.8), 0.75)
d = 0.22; sfx("case_open", mix(lp(noise(d), 0.35) * env(int(SR*d), 0.001, 0.05), sq(np.linspace(900, 500, int(SR*d)), d, 0.2) * env(int(SR*d), 0.0005, 0.02) * 0.5), 0.6)
d = 0.18; sfx("case_close", mix(lp(noise(d), 0.4) * env(int(SR*d), 0.0005, 0.02), sq(600, d, 0.25) * env(int(SR*d), 0.0005, 0.012) * 0.7), 0.75)
d = 0.2; sfx("flip", mix(hp(noise(d), 0.3) * env(int(SR*d), 0.01, 0.06) * 0.6, sine(np.linspace(900, 1500, int(SR*d)), d) * env(int(SR*d), 0.002, 0.07) * 0.4), 0.55)
# satisfying shelf snap: clack + thump
d = 0.25; sfx("snap", mix(sq(1400, d, 0.3) * env(int(SR*d), 0.0005, 0.01), lp(noise(d), 0.3) * env(int(SR*d), 0.0005, 0.03), sine(140, d) * env(int(SR*d), 0.001, 0.06) * 0.8), 0.8)
d = 0.7
good = mix(sq(1400, 0.25, 0.3) * env(int(SR*0.25), 0.0005, 0.01), lp(noise(0.25), 0.3) * env(int(SR*0.25), 0.0005, 0.03))
chime = np.zeros(int(SR*d))
for i, fq in enumerate([1046.5, 1318.5, 1568.0]):
    seg = (sine(fq, d - i*0.06) * 0.6 + sine(fq*2, d - i*0.06) * 0.15) * env(int(SR*(d - i*0.06)), 0.003, 0.25)
    place(chime, seg, i * 0.06)
sfx("snap_good", mix(good, chime * 0.7), 0.85)
d = 0.15; sfx("place", mix(lp(noise(d), 0.25) * env(int(SR*d), 0.001, 0.03), sine(220, d) * env(int(SR*d), 0.001, 0.05) * 0.6), 0.6)
d = 0.18; sfx("pop", sine(np.linspace(300, 900, int(SR*d)), d) * env(int(SR*d), 0.001, 0.05), 0.6)
d = 0.9; arp = np.zeros(int(SR*d))
for i, fq in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5]):
    seg = tri(fq, 0.4) * env(int(SR*0.4), 0.003, 0.15)
    place(arp, seg, i * 0.07)
sfx("reveal", mix(arp, lp(noise(d), 0.05) * env(int(SR*d), 0.05, 0.3) * 0.3), 0.7)
d = 0.3; sfx("bonk", mix(sine(np.linspace(420, 180, int(SR*d)), d) * env(int(SR*d), 0.001, 0.12), lp(noise(d), 0.2) * env(int(SR*d), 0.001, 0.02) * 0.5), 0.8)
d = 0.8; f = np.linspace(900, 120, int(SR*d)) * (1 + 0.04*np.sin(2*np.pi*12*t(d)))
sfx("slip", mix(sine(f, d) * env(int(SR*d), 0.005, 0.5) * 0.8, hp(noise(d), 0.2) * env(int(SR*d), 0.002, 0.15) * 0.4, pad(lp(noise(0.2), 0.2) * env(int(SR*0.2), 0.001, 0.05), d)[::-1] * 0.7), 0.8)
d = 0.35; sfx("whoosh", lp(hp(noise(d), 0.15), 0.35) * np.sin(np.pi * t(d) / d) ** 2, 0.6)
for i, fq in enumerate([2600, 3100, 3700]):
    d = 0.25; sfx("clink%d" % i if i else "clink", mix(sine(fq, d) * env(int(SR*d), 0.0005, 0.05), sine(fq*1.51, d) * env(int(SR*d), 0.0005, 0.03) * 0.5, hp(noise(d), 0.5) * env(int(SR*d), 0.0002, 0.004) * 0.6), 0.5)
d = 0.2; sfx("thud", mix(sine(np.linspace(160, 80, int(SR*d)), d) * env(int(SR*d), 0.001, 0.06), lp(noise(d), 0.15) * env(int(SR*d), 0.001, 0.04) * 0.7), 0.7)
d = 0.3; sfx("error", mix(sq(180, 0.12, 0.5) * env(int(SR*0.12), 0.002, 0.08), pad(np.zeros(int(SR*0.13)).tolist() + list(sq(150, 0.15, 0.5) * env(int(SR*0.15), 0.002, 0.08)), d)) * 0.5, 0.45)
d = 0.6; f = 600 + 500 * np.sin(2*np.pi*6*t(d)); sfx("scanner", mix(sine(f, d) * env(int(SR*d), 0.01, 0.3, 0.3, 0.1) * 0.6, sq(f*2, d, 0.1) * env(int(SR*d), 0.01, 0.2) * 0.15), 0.55)
d = 0.4; sfx("emote", mix(tri(np.linspace(600, 900, int(SR*d)), d) * env(int(SR*d), 0.005, 0.15)), 0.45)
d = 0.25; sfx("chat", mix(sine(880, 0.1) * env(int(SR*0.1), 0.002, 0.05), pad(np.zeros(int(SR*0.09)).tolist() + list(sine(1320, 0.14) * env(int(SR*0.14), 0.002, 0.06)), d)), 0.45)
d = 0.07; sfx("ui_tap", mix(sine(1200, d) * env(int(SR*d), 0.001, 0.02), sq(2400, d, 0.2) * env(int(SR*d), 0.0005, 0.005) * 0.3), 0.5)
d = 0.12; sfx("ui_back", sine(np.linspace(900, 500, int(SR*d)), d) * env(int(SR*d), 0.001, 0.05), 0.45)
d = 1.2; rnd = np.zeros(int(SR*d))
for i in range(14):
    fq = 400 * 2 ** (rng.integers(0, 12) / 12)
    seg = sq(fq, 0.06, 0.3) * env(int(SR*0.06), 0.001, 0.02)
    place(rnd, seg * 0.6, i * 0.07)
tada = np.zeros(int(SR*d)); seg = (tri(523.25, 0.25) + tri(659.25, 0.25) + tri(783.99, 0.25)) * env(int(SR*0.25), 0.005, 0.15)
place(tada, seg, 0.98)
sfx("randomize", mix(rnd, tada), 0.6)
# level complete jingle
bpm = 150; beat = 60 / bpm; notes = [(0, 523.25, 1), (1, 659.25, 1), (2, 783.99, 1), (3, 1046.5, 2), (5, 987.77, 1), (6, 1046.5, 3)]
jl = np.zeros(int(SR * beat * 10))
for st_, fq, ln in notes:
    dd = beat * ln; seg = (sq(fq, dd, 0.25) * 0.4 + tri(fq / 2, dd) * 0.5) * env(int(SR*dd), 0.005, dd * 0.6, 0.2, 0.05)
    place(jl, seg, st_ * beat)
for k, fq in enumerate([261.63, 329.63, 392.0]):
    seg = tri(fq, beat * 4) * env(int(SR*beat*4), 0.01, 0.8, 0.3, 0.2) * 0.3
    place(jl, seg, 6 * beat)
sfx("jingle", jl, 0.8)

# ----------------------------------------------------------------- MUSIC
NOTE = lambda n: 440.0 * 2 ** ((n - 69) / 12)
def kick(d=0.25): return sine(np.linspace(120, 45, int(SR*d)), d) * env(int(SR*d), 0.001, 0.09)
def snare(d=0.2): return mix(hp(noise(d), 0.35) * env(int(SR*d), 0.001, 0.06) * 0.7, tri(190, d) * env(int(SR*d), 0.001, 0.04) * 0.4)
def hat(d=0.06, o=False): return hp(noise(d), 0.6) * env(int(SR*d), 0.0005, 0.03 if o else 0.012)
def song(name, bpm, prog, scale, style, bars=16, seed=0):
    r = np.random.default_rng(seed)
    beat = 60 / bpm; L = bars * 4 * beat
    mel = np.zeros(int(SR * L)); bass = np.zeros_like(mel); chords = np.zeros_like(mel); drums = np.zeros_like(mel)
    for b in range(bars):
        root = prog[b % len(prog)]
        t0 = b * 4 * beat
        triad = [root, root + (3 if style.get("minor") and b % 2 else 4), root + 7]
        # chords
        cd = 4 * beat
        if style["pad"] == "tri":
            for n in triad:
                place(chords, tri(NOTE(n + 12), cd) * env(int(SR*cd), 0.05, cd, 0.6, 0.2) * 0.12, t0)
        elif style["pad"] == "saw":
            for n in triad:
                x = lp(saw(NOTE(n + 12) * 1.003, cd) + saw(NOTE(n + 12) * 0.997, cd), 0.08)
                place(chords, x * env(int(SR*cd), 0.2, cd, 0.7, 0.3) * 0.07, t0)
        elif style["pad"] == "keys":
            for k in range(4):
                for n in triad:
                    dd = beat * 0.9
                    place(chords, (sine(NOTE(n + 12), dd) + 0.3 * sine(NOTE(n + 24), dd)) * env(int(SR*dd), 0.003, 0.35) * 0.1, t0 + k * beat + (0.5 * beat if k % 2 else 0))
        elif style["pad"] == "box":   # music box
            for k in range(8):
                n = triad[k % 3] + 24
                dd = beat
                place(chords, (sine(NOTE(n), dd) + 0.4 * sine(NOTE(n) * 3, dd)) * env(int(SR*dd), 0.001, 0.25) * 0.1, t0 + k * beat * 0.5)
        # bass
        for k in range(4 if style["bass"] != "busy" else 8):
            step = beat if style["bass"] != "busy" else beat / 2
            n = root - 12 + (7 if (k % 4 == 2 and style["bass"] == "walk") else 0) + (12 if k % 2 and style["bass"] == "busy" else 0)
            dd = step * 0.9
            src = tri(NOTE(n), dd) if style.get("bass_tone") != "sq" else lp(sq(NOTE(n), dd, 0.4), 0.2)
            place(bass, src * env(int(SR*dd), 0.003, dd * 0.6, 0.3, 0.03) * 0.35, t0 + k * step)
        # melody (pentatonic, phrases repeat every 4 bars with variation)
        phrase_seed = (b % 4) + (100 if b >= bars // 2 else 0)
        pr = np.random.default_rng(seed * 1000 + phrase_seed)
        pos = 0.0
        while pos < 4 * beat - 1e-6:
            ln = pr.choice([0.5, 0.5, 1.0, 1.0, 1.5, 2.0]) * beat
            if pos + ln > 4 * beat: ln = 4 * beat - pos
            if pr.random() < style.get("rest", 0.2):
                pos += ln; continue
            deg = int(pr.integers(0, len(scale)))
            n = root + 12 + scale[deg] + (12 if pr.random() < 0.15 else 0)
            dd = ln * 0.92
            if style["lead"] == "sq":
                src = sq(NOTE(n), dd, 0.25) * 0.5 + tri(NOTE(n), dd) * 0.5
            elif style["lead"] == "bell":
                src = sine(NOTE(n), dd) + 0.25 * sine(NOTE(n) * 2.01, dd)
            elif style["lead"] == "flute":
                src = sine(NOTE(n) * (1 + 0.004 * np.sin(2 * np.pi * 5 * t(dd))), dd) + 0.1 * tri(NOTE(n), dd)
            else:
                src = lp(saw(NOTE(n), dd), 0.3)
            place(mel, src * env(int(SR*dd), 0.01, dd * 0.7, 0.4, 0.05) * style.get("lead_vol", 0.18), t0 + pos)
            pos += ln
        # drums
        dstyle = style["drums"]
        for k in range(4):
            tb = t0 + k * beat
            if dstyle == "none":
                continue
            if dstyle in ("pop", "four"):
                if k % 2 == 0 or dstyle == "four": place(drums, kick() * 0.7, tb)
                if k % 2 == 1: place(drums, snare() * 0.45, tb)
                place(drums, hat() * 0.25, tb + beat / 2); place(drums, hat() * 0.18, tb)
            elif dstyle == "lofi":
                if k in (0,) or (k == 2 and b % 2): place(drums, lp(kick(), 0.5) * 0.6, tb)
                if k in (1, 3): place(drums, lp(snare(), 0.25) * 0.35, tb + 0.02)
                place(drums, lp(hat(), 0.5) * 0.15, tb + beat * 0.55)
            elif dstyle == "soft":
                if k == 0: place(drums, kick() * 0.4, tb)
                place(drums, hat() * 0.1, tb + beat / 2)
    # crackle for lofi
    out = mel + bass + chords + drums
    if style.get("crackle"):
        cr = np.zeros_like(out); idx = r.integers(0, len(out), int(L * 25)); cr[idx] = r.uniform(-0.15, 0.15, len(idx))
        out += lp(cr, 0.5) + lp(noise(L)[:len(out)], 0.02) * 0.01
    # gentle loop fade at edges to avoid clicks
    fade = int(SR * 0.01); out[:fade] *= np.linspace(0, 1, fade); out[-fade:] *= np.linspace(1, 0, fade)
    write(os.path.join(OUT, "music", name + ".wav"), norm(out, 0.7))
    print("music", name, round(L, 1), "s")

MAJ_P = [0, 2, 4, 7, 9]; MIN_P = [0, 3, 5, 7, 10]
song("menu", 118, [60, 65, 67, 60, 57, 65, 67, 67], MAJ_P, {"pad": "keys", "bass": "walk", "lead": "sq", "drums": "pop", "rest": 0.25}, 16, 1)
song("level1", 84, [62, 57, 59, 55], MAJ_P, {"pad": "keys", "bass": "plain", "lead": "bell", "drums": "lofi", "rest": 0.35, "crackle": True, "lead_vol": 0.15}, 16, 2)
song("level2", 104, [57, 62, 64, 57, 53, 55, 64, 64], MIN_P, {"pad": "keys", "bass": "busy", "lead": "sq", "drums": "pop", "rest": 0.3, "minor": True}, 16, 3)
song("level3", 96, [57, 53, 60, 55], MIN_P, {"pad": "saw", "bass": "busy", "bass_tone": "sq", "lead": "saw", "drums": "four", "rest": 0.3, "minor": True, "lead_vol": 0.13}, 16, 4)
song("level4", 76, [60, 57, 53, 55], MAJ_P, {"pad": "box", "bass": "plain", "lead": "flute", "drums": "soft", "rest": 0.45, "lead_vol": 0.12}, 16, 5)
song("level5", 122, [60, 57, 62, 67, 60, 64, 65, 67], MAJ_P, {"pad": "keys", "bass": "walk", "lead": "bell", "drums": "pop", "rest": 0.2}, 16, 6)
song("level6", 128, [57, 57, 53, 55], MIN_P, {"pad": "saw", "bass": "busy", "bass_tone": "sq", "lead": "sq", "drums": "four", "rest": 0.3, "minor": True}, 16, 7)
print("done")
