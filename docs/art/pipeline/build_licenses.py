"""Copy one licence text per source pack that is actually used into assets/licenses/ and collect
the credit data (author, URL, licence) used by CREDITS.md and assets/licenses/README.md."""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import *  # noqa

OWN_FILES = ["REPO_LICENSE_CC0.txt", "OFL.txt", "INFO.txt", "License.txt", "LICENSE.txt", "_LICENSE.txt", "LICENSE & CREDITS.txt",
             "license cc0 - public domain.txt", "README.txt"]

# hand-checked overrides / additions (title, author, url, licence, tier, used for)
META = {
    "superpowers-prehistoric-platformer": ("Superpowers Asset Packs - Prehistoric Platformer", "Pixel-boy (Sparklin Labs)",
        "https://github.com/sparklinlabs/superpowers-asset-packs/tree/master/prehistoric-platformer", "CC0 1.0", "A",
        "hero, enemies, bosses, NPCs, all terrain and props, parallax layers, native items, FX, HUD, bitmap fonts"),
    "superpowers_asset-packs-audio": ("Superpowers Asset Packs - prehistoric-platformer sound effects", "Pixel-boy (Sparklin Labs)",
        "https://github.com/sparklinlabs/superpowers-asset-packs", "CC0 1.0", "A", "dinosaur voices, wood knock, boss chest-beat"),
    "oga_aroach_16x16-food": ("16x16 Food", "ARoachIFoundOnMyPillow", "https://opengameart.org/content/16x16-food", "CC0 1.0", "A",
        "40 food sprites, chili, coconut"),
    "oga_aroach_16x16-rpg-items-db32": ("16x16 RPG Items (DB32)", "ARoachIFoundOnMyPillow", "https://opengameart.org/content/16x16-rpg-items-db32",
        "CC0 1.0", "A", "gems, rings, goblet, torch, bucket"),
    "ghostpixxells_free-pixel-foods": ("Free Pixel foods", "ghostpixxells", "https://ghostpixxells.itch.io/pixelfood", "CC0 1.0", "A",
        "seven giant bonus foods"),
    "pixelfrog_treasure-hunters": ("Treasure Hunters", "Pixel Frog", "https://pixelfrog-assets.itch.io/treasure-hunters", "CC0 1.0", "A",
        "carved-stone touch buttons"),
    "ansimuz_explosion-animations-pack": ("Explosion Animations Pack", "ansimuz (Luis Zuno)", "https://ansimuz.itch.io/explosion-animations-pack",
        "CC0 1.0", "A", "explosion.png, explosion_big.png"),
    "ansimuz_sunny-land": ("Sunny Land", "ansimuz (Luis Zuno)", "https://ansimuz.itch.io/sunny-land-pixel-game-art", "CC0 1.0", "A", "hit_stars.png"),
    "googlefonts_pressstart2p": ("Press Start 2P", "CodeMan38 / The Press Start 2P Project Authors", "https://fonts.google.com/specimen/Press+Start+2P",
        "SIL Open Font License 1.1", "B", "press_start_2p.ttf"),
    "googlefonts_pixelifysans": ("Pixelify Sans", "Stefie Justprince / The Pixelify Sans Project Authors", "https://fonts.google.com/specimen/Pixelify+Sans",
        "SIL Open Font License 1.1", "B", "pixelify_sans.ttf"),
    "juhani-junkala_512-retro-sfx": ("The Essential Retro Video Game Sound Effects Collection [512 sounds]", "Juhani Junkala (SubspaceAudio)",
        "https://opengameart.org/content/512-sound-effects-8-bit-style", "CC0 1.0", "A", "most sound effects"),
    "juhani-junkala_5-chiptunes-action": ("5 Chiptunes (Action) / Retro Game Music Pack", "Juhani Junkala (SubspaceAudio)",
        "https://opengameart.org/content/5-chiptunes-action", "CC0 1.0", "A", "title, cave, ice, spare level and ending music"),
    "juhani-junkala_4-chiptunes-adventure": ("4 Chiptunes (Adventure) / Chiptune Adventures", "Juhani Junkala (SubspaceAudio)",
        "https://opengameart.org/content/4-chiptunes-adventure", "CC0 1.0", "A", "jungle, volcano, boss and bonus music"),
    "juhani-junkala_12-music-loops": ("12 Music Loops", "Juhani Junkala (SubspaceAudio)", "https://opengameart.org/content/12-music-loops",
        "CC0 1.0", "A", "world map, level select, final boss, credits, spare level music"),
    "mintodog_8bit-action-jingles": ("8bit Action Jingle & Mini Loop", "MintoDog", "https://opengameart.org/content/8bit-action-jingle-mini-loop",
        "CC0 1.0", "A", "level complete, death, game over and feast-mode jingles"),
    "wolfgang_8bit-loops": ("Bonus Round - 8bit / 8-Bit Victory Loop", "Wolfgang_ (Ted Kerr)", "https://opengameart.org/content/bonus-round-8bit",
        "CC0 1.0", "A", "bonus stage alternate, tally loop"),
    "moxiecat_8bit-platformer-sfx": ("8-bit Platformer SFX", "MoxieCat", "https://opengameart.org/content/8-bit-platformer-sfx-0", "CC0 1.0", "A",
        "head bounce / spring"),
    "basto_nes-sounds": ("NES Sounds", "Basto", "https://opengameart.org/content/nes-sounds", "CC0 1.0", "A", "splash, exit chime"),
    "rubberduck_40-cc0-water-splash-slime-sfx": ("40 CC0 water / splash / slime SFX", "rubberduck",
        "https://opengameart.org/content/40-cc0-water-splash-slime-sfx", "CC0 1.0", "A", "lava bubbling loop"),
    "rubberduck_80-cc0-creature-sfx": ("80 CC0 creature SFX", "rubberduck", "https://opengameart.org/content/80-cc0-creature-sfx", "CC0 1.0", "A",
        "feast-mode chomp"),
    "antumdeluge_fire-crackling": ("Fire Crackling", "AntumDeluge", "https://opengameart.org/content/fire-crackling", "CC0 1.0", "A", "campfire loop"),
    "ignasd_ice-shatters": ("Ice breaking/shattering", "IgnasD", "https://opengameart.org/content/ice-breakingshattering", "CC0 1.0", "A",
        "ice block smash"),
    "misc-cc0-level-themes": ("Icy Heights (wind ambience)", "Ecrivain", "https://opengameart.org/content/icy-heights", "CC0 1.0", "A",
        "blizzard wind loop (only ecrivain_icy-heights_wind.ogg is used from this staging folder)"),
}


def used_packs():
    load_registry()
    blob = json.dumps(REGISTRY)
    out = {}
    for cat in sorted(os.listdir(CAND)):
        d = os.path.join(CAND, cat)
        if not os.path.isdir(d):
            continue
        for p in sorted(os.listdir(d)):
            if os.path.isdir(os.path.join(d, p)) and not p.startswith("_") and p in blob:
                out[p] = os.path.join(d, p)
    return out


def evidence(md):
    """Keep the header and the licence / evidence sections of a scout LICENSE_INFO.md."""
    keep = []; on = True
    for ln in md.splitlines():
        if ln.startswith("## "):
            t = ln[3:].lower()
            on = t.startswith(("exact", "evidence", "licen", "notes / flags", "flags"))
        if on:
            keep.append(ln)
    return "\n".join(keep).strip() + "\n"


def build_licenses():
    packs = used_packs()
    dst = os.path.join(ASSETS, "licenses")
    os.makedirs(dst, exist_ok=True)
    rows = []
    for p, folder in packs.items():
        title, author, url, lic, tier, use = META[p]
        parts = ["%s\n%s\n" % (title, "=" * len(title)),
                 "Author: %s\nSource: %s\nLicence: %s (tier %s)\nUsed in Club & Grub for: %s\nStaging folder: .tools/asset_candidates/%s/%s\n"
                 % (author, url, lic, tier, use, os.path.basename(os.path.dirname(folder)), p)]
        info = os.path.join(folder, "LICENSE_INFO.md")
        if os.path.exists(info):
            parts.append("---- Licence evidence recorded when the pack was downloaded ----\n\n" + evidence(open(info, encoding="utf-8").read()))
        for d, _, files in os.walk(folder):
            depth = os.path.relpath(d, folder).count(os.sep)
            if depth > 2:
                continue
            for f in files:
                if f in OWN_FILES and not (f == "REPO_LICENSE_CC0.txt"):
                    try:
                        txt = open(os.path.join(d, f), encoding="utf-8", errors="replace").read()
                    except OSError:
                        continue
                    if len(txt) < 20000:
                        parts.append("---- %s (shipped by the author) ----\n\n%s\n" % (f, txt.strip()))
        name = p.replace("-", "_") + ".txt"
        open(os.path.join(dst, name), "w", encoding="utf-8").write("\n".join(parts))
        rows.append({"pack": p, "file": "assets/licenses/" + name, "title": title, "author": author, "url": url, "license": lic, "tier": tier, "use": use})
    cc0 = open(os.path.join(SP, "REPO_LICENSE_CC0.txt"), encoding="utf-8").read()
    open(os.path.join(dst, "cc0_1.0_legal_code.txt"), "w", encoding="utf-8").write(cc0)
    json.dump(rows, open(os.path.join(ROOT, "docs", "art", "pipeline", "credits.json"), "w", encoding="utf-8"), indent=1)
    return rows


if __name__ == "__main__":
    rows = build_licenses()
    for r in rows:
        print(r["tier"], r["license"], "|", r["author"], "|", r["title"])
    print(len(rows), "packs")
