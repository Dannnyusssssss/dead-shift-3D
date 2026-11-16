"""Sonidos y música del juego.

Uso: blender --background --factory-startup --python tools/blender/audio.py

Usa el módulo de audio de Blender (aud) para leer los OGG de Kenney (CC0) y numpy para el
resto. Escribe WAV mono de 22 050 Hz y 16 bits en assets/audio/<grupo>/<id>.wav (Godot los
comprime con QOA al importar) y assets/audio/sounds.json con la lista. Todo se normaliza al
mismo pico (sin sonidos que destaquen de golpe) y lo sintetizado usa una semilla fija:
mismo script, mismo resultado (el WAV no lleva fechas ni números aleatorios).

Sintetizado aquí (no hay CC0 en las fuentes permitidas): disparos, voces de cada tipo de
enemigo, crepitar del contador Geiger, rotor del helicóptero, ambiente de cada piso y música
mínima (tensión, jefe y espera del rescate).
"""

import json
import os
import sys
import wave

import aud
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
THIRD = os.path.join(ROOT, "assets", "third_party")
OUT = os.path.join(ROOT, "assets", "audio")
RATE = 22050
PEAK = 0.7  # -3 dB: margen para que varios sonidos juntos no saturen.

# id -> (grupo, archivos de Kenney que se juntan como variantes una detrás de otra no; cada
# variante es un id con sufijo _N).
KENNEY = {
    "step_concrete": ("steps", "kenney-impact-sounds", "footstep_concrete_00%d.ogg", 5),
    "step_wood": ("steps", "kenney-impact-sounds", "footstep_wood_00%d.ogg", 5),
    "step_metal": ("steps", "kenney-impact-sounds", "impactPlate_light_00%d.ogg", 5),
    "step_carpet": ("steps", "kenney-impact-sounds", "footstep_carpet_00%d.ogg", 5),
    "hit_flesh": ("combat", "kenney-impact-sounds", "impactPunch_heavy_00%d.ogg", 5),
    "hit_wood": ("combat", "kenney-impact-sounds", "impactWood_heavy_00%d.ogg", 5),
    "hit_metal": ("combat", "kenney-impact-sounds", "impactMetal_medium_00%d.ogg", 5),
    "hit_glass": ("world", "kenney-impact-sounds", "impactGlass_heavy_00%d.ogg", 5),
    "hit_soft": ("world", "kenney-impact-sounds", "impactSoft_medium_00%d.ogg", 5),
    "hit_plank": ("world", "kenney-impact-sounds", "impactPlank_medium_00%d.ogg", 5),
    "knife_slice": ("combat", "kenney-rpg-audio", "knifeSlice%s.ogg", ["", "2"]),
    "swing": ("combat", "kenney-rpg-audio", "cloth%d.ogg", [1, 2, 3, 4]),
    "reload_click": ("combat", "kenney-rpg-audio", "metalClick.ogg", None),
    "reload_latch": ("combat", "kenney-rpg-audio", "metalLatch.ogg", None),
    "pickup": ("items", "kenney-rpg-audio", "handleSmallLeather%s.ogg", ["", "2"]),
    "bag": ("items", "kenney-rpg-audio", "clothBelt%s.ogg", ["", "2"]),
    "door_open": ("world", "kenney-rpg-audio", "doorOpen_%d.ogg", [1, 2]),
    "door_close": ("world", "kenney-rpg-audio", "doorClose_%d.ogg", [1, 2]),
    "creak": ("world", "kenney-rpg-audio", "creak%d.ogg", [1, 2, 3]),
    "zap": ("world", "kenney-sci-fi-sounds", "forceField_00%d.ogg", [0, 1, 2]),
    "power_down": ("world", "kenney-sci-fi-sounds", "spaceEngineLow_00%d.ogg", [0]),
    "power_up": ("world", "kenney-sci-fi-sounds", "engineCircular_00%d.ogg", [0]),
    "ui_click": ("ui", "kenney-interface-sounds", "click_00%d.ogg", [1, 2]),
    "ui_select": ("ui", "kenney-interface-sounds", "select_00%d.ogg", [1, 2]),
    "ui_back": ("ui", "kenney-interface-sounds", "back_00%d.ogg", [1]),
    "ui_error": ("ui", "kenney-interface-sounds", "error_00%d.ogg", [1]),
    "ui_confirm": ("ui", "kenney-interface-sounds", "confirmation_00%d.ogg", [1]),
}


def write_wav(path: str, samples: np.ndarray) -> None:
    data = np.clip(samples, -1.0, 1.0)
    pcm = (data * 32767.0).round().astype("<i2")
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def normalize(samples: np.ndarray, peak: float = PEAK) -> np.ndarray:
    top = float(np.abs(samples).max()) if samples.size else 0.0
    return samples * (peak / top) if top > 1e-6 else samples


def fade(samples: np.ndarray, seconds: float = 0.01) -> np.ndarray:
    n = min(int(seconds * RATE), samples.size // 2)
    if n > 0:
        ramp = np.linspace(0.0, 1.0, n)
        samples[:n] *= ramp
        samples[-n:] *= ramp[::-1]
    return samples


def load_kenney(pack: str, filename: str) -> np.ndarray:
    sound = aud.Sound(os.path.join(THIRD, pack, filename)).resample(RATE, True)
    data = sound.data()
    mono = data.mean(axis=1) if data.ndim == 2 else data
    return mono.astype(np.float64)


def loop_seam(samples: np.ndarray, seconds: float = 0.25) -> np.ndarray:
    """Funde el final con el principio para que el bucle no haga clic."""
    n = int(seconds * RATE)
    head = samples[:n].copy()
    tail = samples[-n:]
    ramp = np.linspace(0.0, 1.0, n)
    samples[:n] = head * ramp + tail * (1.0 - ramp)
    return samples[:-n]


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def lowpass(x: np.ndarray, amount: float) -> np.ndarray:
    """Filtro de paso bajo de un polo (amount 0..1: más alto, más apagado)."""
    out = np.empty_like(x)
    acc = 0.0
    a = 1.0 - amount
    for i in range(x.size):
        acc += a * (x[i] - acc)
        out[i] = acc
    return out


# ---------------------------------------------------------------- sintetizados


def gunshot(rng, seconds: float, body: float, crack: float) -> np.ndarray:
    t = t_axis(seconds)
    noise = rng.standard_normal(t.size)
    env = np.exp(-t * crack)
    thump = np.sin(2 * np.pi * (body * (1 + 2 * np.exp(-t * 40))) * t) * np.exp(-t * 12)
    tail = lowpass(noise, 0.92) * np.exp(-t * 6) * 0.6
    return fade(noise * env * 0.8 + thump + tail, 0.002)


def groan(rng, seconds: float, base: float, rasp: float, wobble: float) -> np.ndarray:
    t = t_axis(seconds)
    pitch = base * (1 + 0.12 * np.sin(2 * np.pi * wobble * t) + 0.05 * np.sin(2 * np.pi * 0.7 * t))
    phase = 2 * np.pi * np.cumsum(pitch) / RATE
    voice = np.sign(np.sin(phase)) * 0.3 + np.sin(phase * 2) * 0.3 + np.sin(phase * 3) * 0.15
    noise = lowpass(rng.standard_normal(t.size), 0.6) * rasp
    env = np.minimum(1.0, t * 6) * np.minimum(1.0, (seconds - t) * 4)
    return fade(lowpass(voice + noise, 0.55) * env)


def shriek(rng, seconds: float) -> np.ndarray:
    t = t_axis(seconds)
    pitch = 900 + 500 * np.sin(np.pi * t / seconds) + 40 * np.sin(2 * np.pi * 23 * t)
    phase = 2 * np.pi * np.cumsum(pitch) / RATE
    voice = np.sin(phase) + 0.3 * np.sin(phase * 2.01)
    noise = rng.standard_normal(t.size) * 0.35
    env = np.minimum(1.0, t * 12) * np.minimum(1.0, (seconds - t) * 5)
    return fade((voice + noise) * env)


def hiss(rng, seconds: float) -> np.ndarray:
    t = t_axis(seconds)
    noise = rng.standard_normal(t.size)
    bright = noise - lowpass(noise, 0.7)
    env = np.minimum(1.0, t * 20) * np.exp(-np.maximum(t - 0.2, 0) * 3)
    return fade(bright * env)


def radio_static(rng, seconds: float) -> np.ndarray:
    t = t_axis(seconds)
    noise = rng.standard_normal(t.size)
    band = lowpass(noise, 0.3) - lowpass(noise, 0.85)
    gate = (np.sin(2 * np.pi * 7 * t) > -0.2).astype(float)
    return fade(band * gate * np.minimum(1.0, (seconds - t) * 6))


def geiger(rng, seconds: float, rate: float) -> np.ndarray:
    t = t_axis(seconds)
    out = np.zeros(t.size)
    click = np.exp(-np.arange(int(0.004 * RATE)) / (0.0007 * RATE))
    click = click * np.sign(np.sin(np.arange(click.size) * 1.9))
    pos = 0
    while True:
        pos += int(rng.exponential(1.0 / rate) * RATE) + 40
        if pos + click.size >= t.size:
            break
        out[pos:pos + click.size] += click * (0.6 + 0.4 * rng.random())
    return out


def rotor(seconds: float) -> np.ndarray:
    t = t_axis(seconds)
    rng = np.random.default_rng(7)
    noise = lowpass(rng.standard_normal(t.size), 0.8)
    beat = np.maximum(0, np.sin(2 * np.pi * 9.0 * t)) ** 6
    whine = np.sin(2 * np.pi * 410 * t) * 0.05
    return noise * (0.25 + beat) + whine


def ambience(seconds: float, hum: float, noise_amount: float, seed: int, wind: bool) -> np.ndarray:
    t = t_axis(seconds)
    rng = np.random.default_rng(seed)
    noise = rng.standard_normal(t.size)
    if wind:
        gust = 0.6 + 0.4 * np.sin(2 * np.pi * 0.11 * t) * np.sin(2 * np.pi * 0.037 * t + 1)
        body = lowpass(noise, 0.97) * gust * 6
    else:
        body = lowpass(noise, 0.95) * noise_amount * 4
        body += 0.12 * np.sin(2 * np.pi * hum * t) + 0.05 * np.sin(2 * np.pi * hum * 2 * t)
    return body


def music(seconds: float, root: float, pulse: float, seed: int) -> np.ndarray:
    """Música mínima: dron grave con un latido; sin melodía (no distrae ni tapa avisos)."""
    t = t_axis(seconds)
    rng = np.random.default_rng(seed)
    drone = (np.sin(2 * np.pi * root * t) * 0.5 + np.sin(2 * np.pi * root * 1.5 * t) * 0.2
             + np.sin(2 * np.pi * root * 2.003 * t) * 0.15)
    drone *= 0.7 + 0.3 * np.sin(2 * np.pi * t / seconds)
    beat_phase = (t * pulse) % 1.0
    beat = np.exp(-beat_phase * 9) * np.sin(2 * np.pi * root * 0.5 * t) * 0.9
    air = lowpass(rng.standard_normal(t.size), 0.98) * 1.5
    return drone + beat + air


def synthesize() -> dict:
    rng = np.random.default_rng(20261115)
    out = {}
    out["gun_pistol"] = ("combat", gunshot(rng, 0.45, 120, 35))
    out["gun_shotgun"] = ("combat", gunshot(rng, 0.8, 80, 18))
    out["gun_empty"] = ("combat", fade(np.concatenate([np.exp(-t_axis(0.03) * 300) * np.sign(np.sin(t_axis(0.03) * 9000)), np.zeros(int(0.05 * RATE))])))
    for i in range(3):
        out["voice_walker_%d" % i] = ("enemies", groan(rng, 1.4 + 0.2 * i, 85 + 8 * i, 0.5, 2.0 + i))
        out["voice_police_%d" % i] = ("enemies", groan(rng, 1.2 + 0.2 * i, 75 + 6 * i, 0.7, 1.5 + i)
                                      + radio_static(rng, 1.2 + 0.2 * i) * 0.25)
        out["voice_stalker_%d" % i] = ("enemies", hiss(rng, 0.6 + 0.1 * i))
        out["voice_boss_%d" % i] = ("enemies", groan(rng, 1.8 + 0.2 * i, 55 + 5 * i, 0.9, 1.0 + i))
    for i in range(2):
        out["voice_listener_%d" % i] = ("enemies", shriek(rng, 0.9 + 0.2 * i))
    out["geiger_loop"] = ("enemies", geiger(rng, 4.0, 14.0))
    out["helicopter_loop"] = ("world", loop_seam(rotor(4.25)))
    out["amb_ground"] = ("ambience", loop_seam(ambience(8.25, 50, 0.5, 1, False)))
    out["amb_level_1"] = ("ambience", loop_seam(ambience(8.25, 60, 0.6, 2, False)))
    out["amb_level_2"] = ("ambience", loop_seam(ambience(8.25, 45, 0.8, 3, False)))
    out["amb_rooftop"] = ("ambience", loop_seam(ambience(8.25, 0, 0, 4, True)))
    out["music_tension"] = ("music", loop_seam(music(16.25, 55.0, 0.5, 5)))
    out["music_boss"] = ("music", loop_seam(music(16.25, 49.0, 1.5, 6)))
    out["music_rescue"] = ("music", loop_seam(music(16.25, 62.0, 1.0, 7)))
    return out


def main() -> int:
    sounds = {}
    for sound_id, (group, pack, pattern, variants) in sorted(KENNEY.items()):
        if variants is None:
            files = [pattern]
        elif isinstance(variants, int):
            files = [pattern % i for i in range(variants)]
        else:
            files = [pattern % v for v in variants]
        for index, filename in enumerate(files):
            key = sound_id if len(files) == 1 else "%s_%d" % (sound_id, index)
            sounds[key] = (group, fade(load_kenney(pack, filename), 0.003))
    sounds.update(synthesize())
    listing = {}
    for key in sorted(sounds):
        group, samples = sounds[key]
        folder = os.path.join(OUT, group)
        os.makedirs(folder, exist_ok=True)
        peak = PEAK * (0.6 if group in ("ambience", "music") else 1.0)
        write_wav(os.path.join(folder, key + ".wav"), normalize(samples, peak))
        listing[key] = "%s/%s.wav" % (group, key)
    with open(os.path.join(OUT, "sounds.json"), "w", encoding="ascii", newline="\n") as handle:
        json.dump(listing, handle, indent=1, sort_keys=True)
        handle.write("\n")
    print("audio: %d sonidos" % len(listing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
