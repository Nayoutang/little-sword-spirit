"""Small numpy synth for 小剑灵 placeholder audio: plucked strings, xiao flute, drums, bells, noise FX."""
import numpy as np
from scipy import signal

SR = 44100
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_ad(n, attack=0.003, release=0.02):
    e = np.ones(n, np.float32)
    a = max(1, int(attack * SR)); r = max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    if r < n:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def pluck(freq, dur=2.5, bright=1.0, decay=1.4, vib=0.0, pos=0.18, inharm=0.0004, slide=0.0):
    """Additive plucked string (guzheng when bright, guqin when dark/long)."""
    t = t_axis(dur)
    n = len(t)
    # pitch: optional slide into the note and late vibrato (揉弦)
    ramp = np.clip((t - 0.25) / 0.4, 0, 1)
    mod = 1 + vib * ramp * np.sin(2 * np.pi * 5.2 * t)
    if slide:
        mod *= 1 + slide * np.exp(-t / 0.06)
    base_phase = 2 * np.pi * np.cumsum(freq * mod) / SR
    out = np.zeros(n)
    kmax = int(min(40, 9000 / freq))
    for k in range(1, kmax + 1):
        amp = abs(np.sin(np.pi * k * pos)) / k ** (1.6 - 0.5 * bright)
        d = decay / (1 + 0.35 * (k - 1) ** 1.3 / bright)
        out += amp * np.exp(-t / d) * np.sin(k * np.sqrt(1 + inharm * k * k) * base_phase + rng.uniform(0, 6.28))
    # pluck noise
    nn = int(0.012 * SR)
    noise = rng.standard_normal(nn) * np.exp(-np.arange(nn) / (0.003 * SR))
    b, a = signal.butter(2, [min(freq * 2, 8000) / (SR / 2), min(freq * 8, 18000) / (SR / 2)], "band")
    out[:nn] += 0.15 * bright * signal.lfilter(b, a, noise)
    out *= env_ad(n, 0.002, 0.05)
    return (out / max(1e-9, np.max(np.abs(out)))).astype(np.float32)


def xiao(freq, dur, vib=0.006, breath=0.04):
    """Breathy end-blown flute."""
    t = t_axis(dur)
    n = len(t)
    mod = 1 + vib * np.clip((t - 0.15) / 0.3, 0, 1) * np.sin(2 * np.pi * 4.8 * t)
    ph = 2 * np.pi * np.cumsum(freq * mod) / SR
    tone = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    noise = rng.standard_normal(n)
    b, a = signal.butter(2, [freq * 0.8 / (SR / 2), min(freq * 3.5, 15000) / (SR / 2)], "band")
    tone += breath * 4 * signal.lfilter(b, a, noise)
    e = env_ad(n, 0.09, min(0.25, dur * 0.4))
    swell = 0.85 + 0.15 * np.sin(np.pi * np.clip(t / dur, 0, 1))
    out = tone * e * swell
    return (out / max(1e-9, np.max(np.abs(out)))).astype(np.float32)


def pad(freq, dur, voices=3):
    t = t_axis(dur)
    out = np.zeros(len(t))
    for v in range(voices):
        f = freq * (1 + (v - 1) * 0.003)
        out += np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t) + 0.1 * np.sin(6 * np.pi * f * t)
    out *= env_ad(len(t), min(1.5, dur / 3), min(1.5, dur / 3))
    return (out / max(1e-9, np.max(np.abs(out)))).astype(np.float32)


def taiko(f0=110, f1=48, dur=0.9, tight=0.35):
    t = t_axis(dur)
    f = f1 + (f0 - f1) * np.exp(-t / 0.05)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / tight)
    hit = rng.standard_normal(len(t)) * np.exp(-t / 0.012)
    b, a = signal.butter(2, 2500 / (SR / 2))
    out = body + 0.35 * signal.lfilter(b, a, hit)
    return (out / np.max(np.abs(out))).astype(np.float32)


def woodblock(freq=900, dur=0.12):
    t = t_axis(dur)
    out = (np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 2.7 * t)) * np.exp(-t / 0.025)
    return (out / np.max(np.abs(out))).astype(np.float32)


def handdrum(dur=0.3):
    return taiko(260, 160, dur, 0.09)


def bell(freq, dur=3.0, partials=(1, 2.32, 4.25, 5.43, 6.8), decay=1.6):
    t = t_axis(dur)
    out = np.zeros(len(t))
    for i, p in enumerate(partials):
        out += np.exp(-t / (decay / (1 + i * 0.7))) * np.sin(2 * np.pi * freq * p * t) / (1 + i * 0.6)
    out *= env_ad(len(t), 0.002, 0.1)
    return (out / np.max(np.abs(out))).astype(np.float32)


def noise_sweep(dur, f_start, f_end, q=1.2, curve=1.0):
    """Band-passed noise whose centre frequency sweeps (whoosh)."""
    n = int(dur * SR)
    noise = rng.standard_normal(n)
    out = np.zeros(n)
    block = 256
    zi = None
    for s in range(0, n, block):
        x = (s / n) ** curve
        fc = f_start * (f_end / f_start) ** x
        lo, hi = fc / (1 + 1 / q), min(fc * (1 + 1 / q), SR / 2 - 100)
        b, a = signal.butter(2, [lo / (SR / 2), hi / (SR / 2)], "band")
        if zi is None or len(zi) != max(len(a), len(b)) - 1:
            zi = signal.lfilter_zi(b, a) * 0
        out[s:s + block], zi = signal.lfilter(b, a, noise[s:s + block], zi=zi)
    return out.astype(np.float32)


def reverb(x, seconds=2.2, wet=0.3, stereo=True, damp=6000):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    chans = []
    for c in range(2 if stereo else 1):
        ir = rng.standard_normal(n) * np.exp(-t * 6.9 / seconds)
        b, a = signal.butter(1, damp / (SR / 2))
        ir = signal.lfilter(b, a, ir)
        ir[: int(0.012 * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2))
        src = x[:, c] if x.ndim == 2 else x
        chans.append(signal.fftconvolve(src, ir)[: len(src)])
    w = np.stack(chans, 1) if stereo else chans[0]
    dry = x if x.ndim == 2 or not stereo else np.stack([x, x], 1)
    return (1 - wet) * dry + wet * w


class Track:
    """Stereo timeline that wraps its tail so the loop is seamless."""

    def __init__(self, seconds, tail=4.0):
        self.loop = int(seconds * SR)
        self.buf = np.zeros((self.loop + int(tail * SR), 2), np.float32)

    def add(self, sound, at, gain=1.0, pan=0.0):
        i = int(at * SR)
        if i >= self.loop:
            i -= self.loop
        end = min(len(self.buf), i + len(sound))
        seg = sound[: end - i] * gain
        self.buf[i:end, 0] += seg * np.sqrt(0.5 * (1 - pan))
        self.buf[i:end, 1] += seg * np.sqrt(0.5 * (1 + pan))

    def render(self, rev_seconds=2.4, rev_wet=0.3, level=0.8):
        full = reverb(self.buf, rev_seconds, rev_wet)
        out = full[: self.loop].copy()
        tail = full[self.loop:]
        out[: len(tail)] += tail
        out /= np.max(np.abs(out)) + 1e-9
        return (out * level).astype(np.float32)


def save(path, data):
    import subprocess, tempfile, os
    from scipy.io import wavfile
    tmp = tempfile.mktemp(suffix=".wav")
    wavfile.write(tmp, SR, (np.clip(data, -1, 1) * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    os.remove(tmp)
