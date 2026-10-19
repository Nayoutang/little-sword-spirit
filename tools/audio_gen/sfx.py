"""Battle / UI sound effects and 小墨's syllable 'voice' for 小剑灵."""
import os
import numpy as np
from scipy import signal
import synth as S

SR = S.SR
rng = np.random.default_rng(11)


def norm(x, peak=0.9):
    return (x / (np.max(np.abs(x)) + 1e-9) * peak).astype(np.float32)


def mix(*parts):
    n = max(int(at * SR) + len(p) for p, at, _ in parts)
    out = np.zeros(n + int(0.6 * SR), np.float32)
    for snd, at, gain in parts:
        i = int(at * SR)
        out[i:i + len(snd)] += snd * gain
    # trim trailing silence
    nz = np.nonzero(np.abs(out) > 1e-4)[0]
    return out[: nz[-1] + 1] if len(nz) else out


def env_exp(n, tau):
    return np.exp(-np.arange(n) / (tau * SR)).astype(np.float32)


def whoosh(dur, f0, f1, q=1.5):
    w = S.noise_sweep(dur, f0, f1, q)
    n = len(w)
    shape = np.sin(np.pi * np.linspace(0, 1, n)) ** 1.5
    return norm(w * shape)


def thump(f0=140, f1=55, dur=0.18):
    return norm(S.taiko(f0, f1, dur, dur / 3))


def ring(freq, dur=0.35, tau=0.12):
    t = S.t_axis(dur)
    x = sum(np.sin(2 * np.pi * freq * p * t) / (i + 1) for i, p in enumerate((1, 2.76, 5.4)))
    return norm(x * np.exp(-t / tau))


def clang(base=520, dur=0.6):
    t = S.t_axis(dur)
    parts = [(1, 1), (2.52, 0.7), (4.25, 0.5), (6.1, 0.35), (7.3, 0.25)]
    x = sum(a * np.sin(2 * np.pi * base * p * t + rng.uniform(0, 6)) * np.exp(-t / (0.25 / (1 + i * 0.5)))
            for i, (p, a) in enumerate(parts))
    click = rng.standard_normal(len(t)) * np.exp(-t / 0.004)
    return norm(x + 0.6 * click)


def paper(dur=0.09):
    n = int(dur * SR)
    x = rng.standard_normal(n)
    b, a = signal.butter(2, [1800 / (SR / 2), 7000 / (SR / 2)], "band")
    return norm(signal.lfilter(b, a, x) * env_exp(n, 0.025))


def shimmer(freqs, step=0.045, dur=0.6):
    parts = [(S.pluck(f, dur, bright=1.6, decay=0.25), i * step, 0.6) for i, f in enumerate(freqs)]
    return norm(mix(*parts))


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def build_sfx():
    d = {}
    d["card"] = paper()
    d["click"] = norm(S.woodblock(1400, 0.05)) * 0.6
    d["hit_light"] = norm(mix((whoosh(0.13, 900, 4500), 0, 0.6), (thump(160, 70, 0.14), 0.09, 0.9), (ring(2400, 0.2, 0.05), 0.09, 0.25)))
    d["hit_heavy"] = norm(mix((whoosh(0.22, 500, 3500, 1.2), 0, 0.7), (thump(120, 45, 0.3), 0.17, 1.0), (ring(1700, 0.4, 0.12), 0.17, 0.35)))
    d["guard_hit"] = norm(mix((clang(560, 0.5), 0, 0.8), (thump(200, 120, 0.08), 0, 0.4)))
    d["shield_up"] = norm(mix((whoosh(0.3, 400, 2500, 2.0), 0, 0.35), (shimmer([hz(74), hz(78), hz(81), hz(86)], 0.05, 0.5), 0.05, 0.8)))
    d["player_hurt"] = norm(mix((whoosh(0.12, 2500, 600, 1.2), 0, 0.5), (thump(110, 40, 0.25), 0.08, 1.0)))
    d["kill"] = norm(mix((thump(90, 35, 0.5), 0, 1.0), (whoosh(0.6, 3000, 300, 0.8), 0.02, 0.6), (S.bell(hz(57), 1.2, decay=0.6), 0.02, 0.2)))
    d["combo"] = norm(S.pluck(hz(81), 0.5, bright=1.6, decay=0.2))
    d["skill"] = norm(mix((whoosh(0.7, 300, 6000, 1.0), 0, 0.6),
                          (S.bell(hz(45), 2.5, partials=(1, 1.48, 2.2, 2.9, 3.7), decay=1.5), 0.55, 0.9),
                          (shimmer([hz(m) for m in (69, 72, 74, 76, 79, 81, 84)], 0.035, 0.8), 0.5, 0.6),
                          (thump(100, 38, 0.6), 0.55, 0.8)))
    d["xiaomo_strike"] = norm(mix((S.pluck(hz(88), 0.4, bright=1.8, decay=0.12), 0, 0.5),
                                  (whoosh(0.16, 1500, 7000, 1.6), 0.02, 0.6), (ring(3100, 0.3, 0.08), 0.15, 0.35)))
    d["xiaomo_guard"] = norm(mix((shimmer([hz(m) for m in (86, 81, 79, 74)], 0.04, 0.5), 0, 0.8), (whoosh(0.25, 3000, 800, 1.5), 0, 0.3)))
    d["victory"] = norm(mix(*[(S.pluck(hz(m), 1.6, bright=1.3, decay=0.8), i * 0.07, 0.6) for i, m in enumerate((62, 64, 66, 69, 71, 74, 76, 78, 81))],
                            (S.bell(hz(50), 3.0, decay=1.8), 0.6, 0.5)))
    d["defeat"] = norm(mix(*[(S.pluck(hz(m), 2.5, bright=0.5, decay=1.6, pos=0.12), i * 0.38, 0.8) for i, m in enumerate((57, 55, 52, 45))]))
    return d


# ------------------------------------------------------------------ 小墨 syllables
VOWELS = {  # female-ish formants (F1, F2, F3)
    "a": (950, 1500, 2900), "e": (600, 2200, 3000), "i": (350, 2700, 3300),
    "o": (600, 1000, 2800), "u": (400, 900, 2700),
}


def syllable(vowel, f0=390, dur=0.11, contour=0.06, breath=0.12):
    t = S.t_axis(dur)
    n = len(t)
    f = f0 * (1 + contour * np.sin(np.pi * t / dur) - contour * 0.5 * t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    # band-limited glottal pulse: harmonics with -12dB/oct tilt
    src = sum(np.sin(k * ph) / k ** 1.2 for k in range(1, int(5000 / f0)))
    src = src + breath * rng.standard_normal(n)
    out = np.zeros(n)
    for i, fc in enumerate(VOWELS[vowel]):
        bw = 90 + 60 * i
        b, a = signal.iirpeak(fc / (SR / 2), fc / bw)
        out += signal.lfilter(b, a, src) / (1 + i * 0.8)
    e = np.ones(n)
    a_n, r_n = int(0.012 * SR), int(0.04 * SR)
    e[:a_n] = np.linspace(0, 1, a_n) ** 1.5
    e[-r_n:] *= np.linspace(1, 0, r_n) ** 1.5
    return norm(out * e, 0.8)


def build_voice():
    d = {}
    i = 0
    for v in "aeiou":
        for f0, c in ((380, 0.06), (430, -0.04)):
            d[f"xiaomo_voice_{i}"] = syllable(v, f0, 0.1 + 0.02 * (i % 3), c)
            i += 1
    return d


if __name__ == "__main__":
    os.makedirs("out/sfx", exist_ok=True)
    os.makedirs("out/voice", exist_ok=True)
    for name, x in build_sfx().items():
        S.save(f"out/sfx/{name}.ogg", x)
    for name, x in build_voice().items():
        S.save(f"out/voice/{name}.ogg", x)
    print(sorted(os.listdir("out/sfx")), len(os.listdir("out/voice")))
