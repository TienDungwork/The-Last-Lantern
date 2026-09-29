"""Đổi nhạc MIDI của bản gốc (cb..ch.mid = track 0..6, class_4.field_37 = tài nguyên 54..60) ra WAV cho Godot.
Godot không phát MIDI; máy không có fluidsynth nên tự tổng hợp kiểu chiptune bằng numpy (hợp chất game điện thoại).
Chạy: python tools/midi_to_wav.py   -> assets/music/track_<n>.wav
"""

import struct
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
SRC, OUT = ROOT.parent / "darkest_fear_2_grim_243556", ROOT / "assets" / "music"
TRACKS = ["cb", "cc", "cd", "ce", "cf", "cg", "ch"]
SR = 22050
RELEASE = 0.25


def vlq(b: bytes, i: int) -> tuple[int, int]:
    v = 0
    while True:
        c = b[i]
        i += 1
        v = (v << 7) | (c & 127)
        if c < 128:
            return v, i


def parse(path: Path) -> list[tuple[float, float, int, int, int, int, int]]:
    """-> [(bắt đầu s, kết thúc s, kênh, nốt, velocity, program, volume)]."""
    b = path.read_bytes()
    _, ntr, div = struct.unpack(">HHH", b[8:14])
    events, tempos, i = [], [(0, 500000)], 14
    for _ in range(ntr):
        end = i + 8 + struct.unpack(">I", b[i + 4 : i + 8])[0]
        j, tick, status = i + 8, 0, 0
        while j < end:
            d, j = vlq(b, j)
            tick += d
            c = b[j]
            if c == 0xFF:
                ln, k = vlq(b, j + 2)
                if b[j + 1] == 0x51:
                    tempos.append((tick, int.from_bytes(b[k : k + 3], "big")))
                j = k + ln
                continue
            if c in (0xF0, 0xF7):
                ln, k = vlq(b, j + 1)
                j = k + ln
                continue
            if c & 0x80:
                status, j = c, j + 1
            hi, ch = status & 0xF0, status & 15
            n = 1 if hi in (0xC0, 0xD0) else 2
            events.append((tick, hi, ch, b[j], b[j + 1] if n == 2 else 0))
            j += n
        i = end
    tempos.sort()

    def seconds(tick: int) -> float:
        s, last_tick, us = 0.0, 0, 500000
        for t, tempo in tempos:
            if t >= tick:
                break
            s += (t - last_tick) * us / div / 1e6
            last_tick, us = t, tempo
        return s + (tick - last_tick) * us / div / 1e6

    prog, vol, on, notes = [0] * 16, [100] * 16, {}, []
    for tick, hi, ch, a, v in sorted(events, key=lambda e: e[0]):
        if hi == 0xC0:
            prog[ch] = a
        elif hi == 0xB0 and a == 7:
            vol[ch] = v
        elif hi == 0x90 and v > 0:
            on[(ch, a)] = (seconds(tick), v, prog[ch], vol[ch])
        elif hi in (0x80, 0x90) and (ch, a) in on:
            st, vel, p, vo = on.pop((ch, a))
            notes.append((st, max(seconds(tick), st + 0.03), ch, a, vel, p, vo))
    return notes


def envelope(n: int, held: int, attack: float, decay: float, sustain: float, release: float) -> np.ndarray:
    t = np.arange(n) / SR
    env = np.where(t < attack, t / max(attack, 1e-4), sustain + (1 - sustain) * np.exp(-(t - attack) / max(decay, 1e-4)))
    rel = np.arange(n) >= held
    env[rel] *= np.exp(-(t[rel] - held / SR) / release)
    return env


def smooth(x: np.ndarray, k: int) -> np.ndarray:
    return np.convolve(x, np.ones(k) / k, mode="same") if k > 1 else x


def drum(note: int, rng: np.random.Generator) -> np.ndarray:
    t = np.arange(int(SR * 0.4)) / SR
    noise = rng.uniform(-1, 1, t.size)
    if note in (35, 36):  # kick: sin trượt tần số
        return np.sin(2 * np.pi * np.cumsum(40 + 90 * np.exp(-t * 30)) / SR) * np.exp(-t * 9)
    if note in (38, 40):  # snare
        return (0.7 * noise + 0.4 * np.sin(2 * np.pi * 180 * t)) * np.exp(-t * 18)
    if note in (42, 44, 46):  # hi-hat: nhiễu cao (hiệu hai mẫu kề)
        return np.diff(noise, prepend=0) * 0.5 * np.exp(-t * (40 if note != 46 else 10))
    return smooth(noise, 3) * np.exp(-t * 12)


def voice(p: int, f: float, n: int, held: int, rng: np.random.Generator) -> np.ndarray:
    ph = f * np.arange(n) / SR
    tri = 2 * np.abs(2 * (ph % 1) - 1) - 1
    saw = 2 * (ph % 1) - 1
    if p < 8 or 40 <= p < 48:  # piano / EP / harp: gảy
        return tri * envelope(n, held, 0.005, 0.5, 0.15, 0.3)
    if 32 <= p < 40:  # bass
        return tri * envelope(n, held, 0.005, 0.3, 0.6, 0.08) * 1.2
    if 24 <= p < 32:  # guitar
        return np.sign(np.sin(2 * np.pi * ph)) * envelope(n, held, 0.005, 0.4, 0.5, 0.1) * 0.35
    if 80 <= p < 88:  # lead
        return smooth(saw, 3) * envelope(n, held, 0.01, 0.3, 0.7, 0.1) * 0.5
    if p >= 120:  # hiệu ứng (sóng biển, vỗ tay): nhiễu lọc, lên xuống chậm
        return smooth(rng.uniform(-1, 1, n), 24) * envelope(n, held, 0.4, 1.0, 0.8, 0.6) * 1.5
    # pad / FX: hai saw lệch tông, mở và tắt chậm
    saw2 = 2 * ((ph * 1.004) % 1) - 1
    return smooth((saw + saw2) / 2, 6) * envelope(n, held, 0.25, 1.0, 0.8, 0.6) * 0.4


def render(notes: list, seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    total = int((max(n[1] for n in notes) + 1.5) * SR)
    mix = np.zeros(total)
    for st, en, ch, note, vel, p, vol in notes:
        s0, held = int(st * SR), int((en - st) * SR)
        if ch == 9:
            w = drum(note, rng) * 0.6
        else:
            n = held + int(0.6 * SR)
            w = voice(p, 440.0 * 2 ** ((note - 69) / 12), n, held, rng)
        w = w[: total - s0] * (vel / 127) * (vol / 127)
        mix[s0 : s0 + w.size] += w
    mix = np.tanh(mix / (np.percentile(np.abs(mix), 99.9) + 1e-9) * 0.9)  # chuẩn hóa + nén mềm
    return (mix * 0.85 * 32767).astype(np.int16)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for i, name in enumerate(TRACKS):
        pcm = render(parse(SRC / f"{name}.mid"), i)
        with wave.open(str(OUT / f"track_{i}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        print(f"track_{i} <- {name}.mid  {pcm.size / SR:.1f}s")


if __name__ == "__main__":
    main()
