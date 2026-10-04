"""Copy the chosen sound effects and music into assets/audio and register them.

Source: the audio scout's curated set in .tools/asset_candidates/audio/_recommended (all CC0) plus four
explosion / rumble one-shots picked here from Juhani Junkala's 512-sound collection (CC0).
No audio is re-encoded here: files are byte-identical copies under game-facing names.
"""
import csv
import os
import shutil
import sys
import wave

sys.path.insert(0, os.path.dirname(__file__))
from common import *  # noqa

REC = os.path.join(AUDIO, "_recommended")

# need -> (variants to ship, game events / contexts)
SFX = {
    "jump": ("a", "hero jump (added cue, GAMEPLAY 12.4)"),
    "land": ("a", "hero lands after a fall of more than 10 ticks (dust puff)"),
    "footstep": ("ab", "optional run steps, alternate a / b"),
    "club_swing": ("ab", "a = club swing (original slot 5); b = hammer swing (slot 0)"),
    "club_hit": ("ab", "weapon connects with an enemy; a = club, b = hammer / charged 4x hit"),
    "club_hit_wood": ("a", "weapon hits scenery / a hidden spot (with the star puff)"),
    "projectile_throw": ("b", "axe / boomerang throw (slot 10)"),
    "enemy_hurt": ("a", "enemy survives a hit (flash + knock-back)"),
    "enemy_death": ("ab", "enemy killed by a weapon (slot 2); alternate a / b"),
    "spring_bounce": ("a", "head bounce on an enemy or boss (slot 3); spring pad"),
    "player_hurt": ("ab", "a = hero hurt by an enemy (slot 9); b = heavy hurt: skull item, boss hit, boss projectile, lights-off trigger (slot 1)"),
    "player_death": ("a", "hero death toss (slot 7)"),
    "food_pickup": ("abcd", "normal pick-up: food, bones, letters, feast kit, weapons, glider (slot 8); cycle a-d for variety"),
    "food_chomp": ("a", "feast mode: enemy eaten on touch"),
    "gem_pickup": ("ab", "a = big pick-up: treasure, giant bonus (slot 4); b = bonus letter / warp item"),
    "energy_refill": ("a", "heart collected, sixth bone restores a heart"),
    "one_up": ("a", "extra life (item or every 250 000 points)"),
    "bonus_reveal": ("ab", "a = hidden spot used up / secret opened; b = giant bonus or jackpot chest appears"),
    "breakable_smash": ("a", "breakable block destroyed (dirt, rock)"),
    "breakable_smash_ice": ("a", "breakable ice block destroyed"),
    "checkpoint": ("ab", "a = restart point lit; b = exit totem unlocked / level exit touched"),
    "boss_roar": ("ab", "a = boss appears / Colossus roars when hit; b = Brute chest-beat"),
    "boss_hit": ("a", "boss hit by a weapon"),
    "dino_voice": ("abcd", "enemy alert / spawn voices (dropper lands, charger rushes, plant bites, pterodactyl dives)"),
    "fireball": ("b", "Colossus spits a rock"),
    "splash": ("a", "something falls into water or lava"),
    "lava_bubble_loop": ("a", "ambience loop near lava"),
    "fire_loop": ("a", "ambience loop near a lit checkpoint fire"),
    "ice_slide": ("a", "skid on slippery ground"),
    "ice_wind_loop": ("a", "blizzard ambience loop (ice level second half)"),
    "menu_move": ("a", "menu cursor"),
    "menu_select": ("a", "menu confirm"),
    "menu_back": ("a", "menu cancel"),
    "pause_in": ("a", "pause opened"),
    "pause_out": ("a", "pause closed"),
    "tally_tick": ("a", "each item counted at the end-of-level tally"),
    "tally_end": ("a", "tally finished"),
    "password_accept": ("a", "save slot / level select accepted, code stone collected"),
    "password_reject": ("a", "locked level, invalid action"),
}
MUSIC = {
    "title": ("ab", {"a": "title picture and main menu (the original's PRESENTA)", "b": "world map between levels (CARTE)"}),
    "password_screen": ("a", {"a": "mode select / level select screens (CODE)"}),
    "level_jungle": ("a", {"a": "world 1 Jungle levels (MINES role)"}),
    "level_cave": ("a", {"a": "world 2 Cave levels (PRES role)"}),
    "level_ice": ("a", {"a": "world 3 Ice levels (GLACE)"}),
    "level_volcano": ("a", {"a": "world 4 Volcano levels (MYSTERY)"}),
    "level_extra": ("ab", {"a": "spare level theme: Cinder Shaft auto-scroll descent", "b": "spare level theme: Crystal Grotto / second stage of a world"}),
    "boss": ("a", {"a": "boss fights, starts when the boss energy bar appears (MONSTER)"}),
    "boss_final": ("a", {"a": "final boss: the Wall Colossus"}),
    "bonus_room": ("ab", {"a": "bonus stages Feast Land (KOOL), short loop", "b": "bonus stages, alternate longer loop / secret rooms"}),
    "level_complete": ("a", {"a": "level-complete jingle when the iris closes (BRAVO)"}),
    "tally_loop": ("a", {"a": "tally screen after the jingle"}),
    "player_death": ("a", {"a": "death jingle before the respawn curtain"}),
    "game_over": ("a", {"a": "game over jingle (BOULA)"}),
    "game_over_loop": ("a", {"a": "game over screen loop after the jingle"}),
    "invincible_loop": ("a", {"a": "feast mode (660 ticks): replaces the level music"}),
    "ending": ("a", {"a": "ending stage Way Home (FINAL)"}),
    "credits": ("a", {"a": "credits roll / The End"}),
}
EXTRA = [  # (out name, source rel in the Junkala pack, event)
    ("explosion_a.wav", "Explosions/Medium Length/sfx_exp_medium7.wav", "grenade / kill-all item (slot 0)"),
    ("explosion_b.wav", "Explosions/Short/sfx_exp_short_hard5.wav", "boss projectile impact, boulder smash"),
    ("explosion_big_a.wav", "Explosions/Clusters/sfx_exp_cluster8.wav", "boss defeated (bursts into bonus items)"),
    ("quake_a.wav", "Explosions/Long/sfx_exp_long2.wav", "screen shake: rising columns, Brute ground pound, feast-end warning"),
]


def wav_len(path):
    w = wave.open(path)
    return w.getnframes() / float(w.getframerate())


def build_audio():
    rows = list(csv.DictReader(open(os.path.join(REC, "MANIFEST.csv"), encoding="utf-8")))
    idx = {(r["kind"], r["need"], r["variant"]): r for r in rows}
    n = 0
    for need, (variants, event) in SFX.items():
        for v in variants:
            r = idx[("sfx", need, v)]
            ext = os.path.splitext(r["file"])[1]
            rel = "audio/sfx/%s_%s%s" % (need, v, ext)
            dst = os.path.join(ASSETS, *rel.split("/")); os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copyfile(os.path.join(REC, *r["file"].split("/")), dst)
            register(rel, kind="sfx", event=event, duration=float(r["duration_s"]), loop=(r["loop"] == "yes"),
                     volume_db=float(r["suggested_volume_db"]), author=r["author"], license=r["license"], source=r["source"])
            n += 1
    for need, (variants, events) in MUSIC.items():
        for v in variants:
            r = idx[("music", need, v)]
            ext = os.path.splitext(r["file"])[1]
            rel = "audio/music/%s_%s%s" % (need, v, ext)
            dst = os.path.join(ASSETS, *rel.split("/")); os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copyfile(os.path.join(REC, *r["file"].split("/")), dst)
            register(rel, kind="music", event=events[v], duration=float(r["duration_s"]), loop=(r["loop"] == "yes"),
                     volume_db=float(r["suggested_volume_db"]), author=r["author"], license=r["license"], source=r["source"])
            n += 1
    base = os.path.join(AUDIO, "juhani-junkala_512-retro-sfx")
    for out, src, event in EXTRA:
        rel = "audio/sfx/" + out
        dst = os.path.join(ASSETS, *rel.split("/"))
        shutil.copyfile(os.path.join(base, *src.split("/")), dst)
        register(rel, kind="sfx", event=event, duration=round(wav_len(dst), 3), loop=False, volume_db=-3.0,
                 author="Juhani Junkala (SubspaceAudio)", license="CC0", source="juhani-junkala_512-retro-sfx/" + src)
        n += 1
    return n


if __name__ == "__main__":
    load_registry()
    print("audio files:", build_audio())
    save_registry()
