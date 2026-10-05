"""Measure every music and SFX file and derive the per-file volume_db of scripts/core/audio_table.gd.

    .tools/venv/Scripts/python.exe -m pip install soundfile pyloudnorm scipy      (once, into the project venv)
    .tools/venv/Scripts/python.exe tools/audio_loudness.py            print the table (Markdown, for the manifest)
    .tools/venv/Scripts/python.exe tools/audio_loudness.py --write    also rewrite the "db" values of audio_table.gd

Measures (files are decoded to float exactly as an Ogg Vorbis / WAV decoder delivers them, so values above 0 dBFS
are visible):
  peak   sample peak, dBFS
  tp     true peak, dBTP (4x oversampled)
  lufs   integrated loudness (ITU-R BS.1770-4 / EBU R128 gating), music and loops only
  short  loudest short-window loudness: K-weighted like LUFS, over the loudest 200 ms of the file (a sound shorter
         than that is measured with the silence after it, roughly how the ear integrates very short sounds; the
         EBU 400 ms momentary window over-rates the boost very short clicks need)

Mix rules (all at a user volume of 1.0 and buses at 0 dB):
  music   integrated loudness MUSIC_TARGET; jingles (non-looping) the same
  sfx     short loudness SFX_TARGET (+ the per-file offset of OFFSETS: footsteps and ambience loops sit well below
          the music, the biggest events a little above the other effects); ambience loops by integrated loudness
  every   volume is lowered further when needed so that the true peak stays at or below PEAK_CEILING dBTP
"""

from __future__ import annotations

import math
import os
import re
import sys

import numpy as np
import pyloudnorm
import soundfile
from scipy.signal import resample_poly

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "assets", "audio")
TABLE = os.path.join(ROOT, "scripts", "core", "audio_table.gd")

MUSIC_TARGET = -18.0
SFX_TARGET = -14.0
SHORT_WINDOW = 0.2
PEAK_CEILING = -1.0
# Per-file offsets in LU against SFX_TARGET (by role, see ASSET_MANIFEST 13.1).
OFFSETS = {
    "footstep_a.wav": -10.0, "footstep_b.wav": -10.0,  # every few ticks while running: a soft tick
    "fire_loop_a.ogg": -12.0, "lava_bubble_loop_a.ogg": -12.0,  # ambience beds under the music
    "ice_wind_loop_a.ogg": -8.0,  # the blizzard: a bed that should be felt
    "menu_move_a.wav": -3.0,  # the cursor: frequent, small
    "tally_tick_a.wav": -4.0,  # rapid-fire during the tally
    "club_hit_wood_a.wav": -2.0,  # scenery hits are frequent
    "explosion_big_a.wav": 2.0, "boss_roar_a.wav": 2.0,  # the loudest events of the game
}
LOOPS = {"fire_loop_a.ogg", "ice_wind_loop_a.ogg", "lava_bubble_loop_a.ogg"}


def load(path: str) -> tuple[np.ndarray, int]:
    data, rate = soundfile.read(path, dtype="float64", always_2d=True)
    return data, rate


def true_peak_db(data: np.ndarray) -> float:
    over = resample_poly(data, 4, 1, axis=0)
    peak = float(np.max(np.abs(over))) if over.size else 0.0
    return 20.0 * math.log10(peak) if peak > 0 else -math.inf


def sample_peak_db(data: np.ndarray) -> float:
    peak = float(np.max(np.abs(data))) if data.size else 0.0
    return 20.0 * math.log10(peak) if peak > 0 else -math.inf


def short_max(meter: pyloudnorm.Meter, data: np.ndarray, rate: int) -> float:
    window = int(SHORT_WINDOW * rate)
    if data.shape[0] < window:
        data = np.concatenate([data, np.zeros((window - data.shape[0], data.shape[1]))])
    # K-weighting once, then the mean square of every window (10 ms hop), summed over channels.
    filtered = data.copy()
    for _name, filt in meter._filters.items():
        filtered = filt.apply_filter(filtered)
    power = filtered ** 2
    cumulative = np.cumsum(np.concatenate([np.zeros((1, power.shape[1])), power]), axis=0)
    hop = max(1, int(0.01 * rate))
    best = 0.0
    for start in range(0, data.shape[0] - window + 1, hop):
        mean = (cumulative[start + window] - cumulative[start]) / window
        best = max(best, float(np.sum(mean)))
    return -0.691 + 10.0 * math.log10(best) if best > 0 else -math.inf


def measure(path: str, integrated: bool) -> dict:
    data, rate = load(path)
    meter = pyloudnorm.Meter(rate)
    result = {
        "seconds": data.shape[0] / rate,
        "peak": sample_peak_db(data),
        "tp": true_peak_db(data),
        "short": short_max(meter, data, rate),
        "lufs": None,
    }
    if integrated and data.shape[0] >= int(0.4 * rate):
        result["lufs"] = float(meter.integrated_loudness(data))
    return result


def gain_for(name: str, kind: str, m: dict) -> float:
    if kind == "music":
        gain = MUSIC_TARGET - m["lufs"]
    elif name in LOOPS:
        gain = SFX_TARGET + OFFSETS.get(name, 0.0) - m["lufs"]
    else:
        gain = SFX_TARGET + OFFSETS.get(name, 0.0) - m["short"]
    gain = min(gain, PEAK_CEILING - m["tp"])
    return round(gain, 1)


def fmt(value: float | None) -> str:
    if value is None:
        return "-"
    return "%+.1f" % value if value != 0 else "+0.0"


def main() -> None:
    write = "--write" in sys.argv
    rows = []
    for kind in ("music", "sfx"):
        folder = os.path.join(AUDIO, kind)
        for name in sorted(os.listdir(folder)):
            if not name.endswith((".ogg", ".wav")):
                continue
            m = measure(os.path.join(folder, name), kind == "music" or name in LOOPS)
            gain = gain_for(name, kind, m)
            rows.append((kind, name, m, gain))
    print("| File | Seconds | Peak dBFS | True peak dBTP | Integrated LUFS | Short (200 ms) LUFS | volume_db | Played at |")
    print("|---|---|---|---|---|---|---|---|")
    for kind, name, m, gain in rows:
        measured = m["lufs"] if (kind == "music" or name in LOOPS) else m["short"]
        label = "LUFS" if (kind == "music" or name in LOOPS) else "LUFS short"
        print("| `audio/%s/%s` | %.2f | %s | %s | %s | %s | %s | %s %s, %s dBTP |" % (
            kind, name, m["seconds"], fmt(m["peak"]), fmt(m["tp"]), fmt(m["lufs"]), fmt(m["short"]), fmt(gain),
            fmt(measured + gain), label, fmt(m["tp"] + gain)))
    if write:
        rewrite_table({name: gain for _kind, name, _m, gain in rows})


def rewrite_table(gains: dict[str, float]) -> None:
    with open(TABLE, encoding="utf-8") as handle:
        text = handle.read()

    def sfx(match: re.Match) -> str:
        files = re.findall(r'"([^"]+)"', match.group(1))
        values = ", ".join("%.1f" % gains[f] for f in files)
        return '"files": [%s],%s"db": [%s]' % (match.group(1), match.group(2), values)

    # Entries list quoted file names; the doc comment that describes the format ("files": [variants]) does not.
    text = re.sub(r'"files": \[((?:\s*"[^"]+",?)+\s*)\],(\s*)"db": \[[^\]]*\]', sfx, text)

    def music(match: re.Match) -> str:
        return '{"file": "%s", "db": %.1f' % (match.group(1), gains[match.group(1)])

    text = re.sub(r'\{"file": "([^"]+)", "db": -?[0-9.]+', music, text)
    with open(TABLE, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("rewrote", TABLE)


if __name__ == "__main__":
    main()
