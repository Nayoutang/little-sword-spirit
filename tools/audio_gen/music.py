"""Compose seamless BGM loops for 小剑灵 (pentatonic, guzheng / guqin / xiao / taiko)."""
import numpy as np
import synth as S

MAJOR = {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11}


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def jianpu(text, do_midi):
    """Parse jianpu tokens -> list of (start_beat, beats, midi or None).
    '3' one beat, '3_' half, '3__' quarter, "5'" octave up, '6,' octave down, '-' extend, '0' rest, '|' ignored."""
    notes = []
    beat = 0.0
    for tok in text.split():
        if tok == "|":
            continue
        if tok == "-":
            if notes:
                s, d, m = notes[-1]
                notes[-1] = (s, d + 1, m)
            beat += 1
            continue
        length = 1.0 / (2 ** tok.count("_"))
        core = tok.replace("_", "")
        if core == "0":
            notes.append((beat, length, None))
        else:
            deg = int(core[0])
            octave = core.count("'") - core.count(",")
            notes.append((beat, length, do_midi + MAJOR[deg] + 12 * octave))
        beat += length
    return notes, beat


def place_melody(track, notes, spb, maker, gain, pan=0.0, offset=0.0):
    for start, beats, m in notes:
        if m is None:
            continue
        snd = maker(midi_hz(m), beats * spb)
        track.add(snd, offset + start * spb, gain, pan)


def guzheng(f, d):
    return S.pluck(f, max(1.6, d + 1.2), bright=1.3, decay=1.1, vib=0.004 if d > 0.6 else 0.0)


def guqin(f, d):
    return S.pluck(f, max(3.0, d + 2.0), bright=0.55, decay=2.2, pos=0.12, slide=0.012)


def xiao_note(f, d):
    return S.xiao(f, d * 0.98 + 0.05)


# ----------------------------------------------------------------------------- home
def home():
    tempo, do = 72, 62  # D 宫
    spb = 60 / tempo
    mel = """3 5 6 1' | 6 5 3 - | 2 3 5 3 | 2 1 2 - |
             3 5 6 1' | 2' 1' 6 5 | 6 5 3 2 | 1 - - - |
             5 6 1' 2' | 3' - 2' 1' | 6 1' 6 5 | 3 - 5 - |
             6 5 3 5 | 6 1' 6 5 | 3 2 3 5 | 1 - - - |"""
    notes, beats = jianpu(mel, do)
    tr = S.Track(beats * spb, tail=4)
    place_melody(tr, notes, spb, guzheng, 0.55, pan=0.15)
    roots = [1, 6, 5, 5, 1, 4, 6, 1, 4, 1, 6, 1, 6, 4, 5, 1]
    for bar, r in enumerate(roots):
        root = do - 24 + MAJOR[r]
        pattern = [0, 7, 12, 14, 12, 7, 12, 16 if r in (1, 4) else 15]
        for i, iv in enumerate(pattern):
            tr.add(S.pluck(midi_hz(root + iv), 1.8, bright=0.9, decay=0.9), (bar * 4 + i * 0.5) * spb, 0.22, -0.25)
        if bar % 2 == 0:
            tr.add(S.pad(midi_hz(root - 12 if root > 45 else root), 8 * spb), bar * 4 * spb, 0.10)
    return tr.render(2.8, 0.32, 0.75)


# ----------------------------------------------------------------------------- menu
def menu():
    tempo, do = 58, 60  # C do, 羽调 on A
    spb = 60 / tempo
    mel = """6, - 1 2 | 3 - - 2 | 1 2 6, - | - - 0 0 |
             3 5 6 5 | 3 - 2 1 | 2 - 3 - | 6, - - 0 |
             1 2 3 5 | 6 - 5 3 | 2 - 1 6, | 6, - - - |"""
    notes, beats = jianpu(mel, do)
    tr = S.Track(beats * spb, tail=5)
    place_melody(tr, notes, spb, xiao_note, 0.42, pan=0.1)
    roots = [6, 6, 4, 3, 1, 6, 5, 3, 4, 1, 5, 6]
    for bar, r in enumerate(roots):
        root = do - 24 + MAJOR[r]
        tr.add(guqin(midi_hz(root), 2), bar * 4 * spb, 0.5, -0.2)
        tr.add(guqin(midi_hz(root + 7), 1.5), (bar * 4 + 2) * spb, 0.32, -0.3)
        if bar % 3 == 2:
            tr.add(guqin(midi_hz(root + 12), 1), (bar * 4 + 3) * spb, 0.25, 0.3)
    # wind bed
    wind = S.noise_sweep(beats * spb, 300, 600, q=0.8)
    wind *= 0.5 + 0.5 * np.sin(np.linspace(0, 2 * np.pi * 3, len(wind)))
    tr.add(wind / np.max(np.abs(wind)), 0, 0.015)
    return tr.render(3.4, 0.4, 0.72)


# ----------------------------------------------------------------------------- journey
def journey():
    tempo, do = 100, 62
    spb = 60 / tempo
    mel = """1 2_ 3_ 5 3 | 2 1_ 2_ 3 - | 5 6_ 5_ 3 2 | 1_ 2_ 3_ 5_ 2 - |
             3 5_ 6_ 1' 6 | 5 3_ 5_ 6 - | 1' 6_ 5_ 3 5 | 2_ 3_ 2_ 1_ 1 - |
             5 - 6_ 1'_ 6 | 5 3 2 - | 3 5 6_ 5_ 3 | 2 - - - |
             1 2_ 3_ 5 3 | 2 1_ 2_ 3 - | 5 6_ 5_ 3 2 | 1 - - - |"""
    notes, beats = jianpu(mel, do)
    tr = S.Track(beats * spb, tail=3)
    place_melody(tr, notes, spb, guzheng, 0.5, pan=0.2)
    roots = [1, 6, 4, 5, 1, 4, 6, 1, 4, 5, 6, 5, 1, 6, 4, 1]
    hd, wb = S.handdrum(), S.woodblock()
    for bar, r in enumerate(roots):
        root = do - 24 + MAJOR[r]
        b0 = bar * 4
        for beat, iv in [(0, 0), (1, 7), (2, 12), (3, 7)]:
            tr.add(S.pluck(midi_hz(root + iv), 1.4, bright=0.8, decay=0.7), (b0 + beat) * spb, 0.25, -0.3)
        for beat, g in [(0, 0.45), (1.5, 0.25), (2, 0.35), (3.5, 0.25)]:
            tr.add(hd, (b0 + beat) * spb, g, -0.1)
        for beat in (1, 3):
            tr.add(wb, (b0 + beat) * spb, 0.12, 0.4)
    return tr.render(1.8, 0.22, 0.78)


# ----------------------------------------------------------------------------- battle
def battle(boss=False):
    tempo = 150 if boss else 138
    do = 53 if boss else 60  # 羽调: D (boss, lower) / A
    spb = 60 / tempo
    mel = """6 - 1' 6 | 5 3 5 - | 6 1' 2' 3' | 2' 1' 6 - |
             3' - 2' 1' | 6 5 6 - | 1' 6 5 3 | 6 - - - |
             6 1'_ 2'_ 3' 2' | 1' 6 5 - | 3 5 6 1' | 2' - 3' - |
             5' 3'_ 2'_ 1' 2' | 3' - 2' 1' | 6 5 3 5 | 6 - - - |"""
    notes, beats = jianpu(mel, do)
    tr = S.Track(beats * spb, tail=3)
    place_melody(tr, notes, spb, guzheng, 0.5, pan=0.15)
    if boss:
        place_melody(tr, notes, spb, lambda f, d: S.xiao(f / 2, d * 0.95 + 0.05), 0.22, pan=-0.15)
    roots = [6, 6, 5, 3, 6, 6, 4, 6, 6, 5, 4, 3, 1, 3, 5, 6]
    big, small = S.taiko(105, 45, 0.9, 0.35), S.taiko(150, 80, 0.5, 0.15)
    gong = S.bell(midi_hz(do - 24 + 9), 3.5, partials=(1, 1.48, 2.2, 2.9, 3.7), decay=2.2)
    for bar, r in enumerate(roots):
        root = do - 24 + MAJOR[r]
        b0 = bar * 4
        ost = [0, 0, 7, 0, 10, 0, 7, 12] if not boss else [0, 0, 12, 0, 7, 0, 10, 0]
        for i, iv in enumerate(ost):
            tr.add(S.pluck(midi_hz(root + iv), 0.9, bright=1.1, decay=0.35), (b0 + i * 0.5) * spb, 0.26, -0.3)
        pattern = [(0, big, 0.7), (1.5, small, 0.35), (2, big, 0.55), (3, small, 0.4), (3.5, small, 0.45)]
        if boss:
            pattern += [(1, big, 0.45), (2.75, small, 0.3)]
        for beat, snd, g in pattern:
            tr.add(snd, (b0 + beat) * spb, g, 0.0)
        if bar % 4 == 0:
            tr.add(gong, b0 * spb, 0.22 if boss else 0.12, 0.2)
    return tr.render(1.6, 0.2, 0.82)


if __name__ == "__main__":
    import os
    os.makedirs("out/music", exist_ok=True)
    for name, fn in [("menu", menu), ("home", home), ("journey", journey), ("battle", battle), ("boss", lambda: battle(True))]:
        data = fn()
        S.save(f"out/music/{name}.ogg", data)
        print(name, round(len(data) / S.SR, 1), "s")
