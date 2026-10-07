#!/usr/bin/env python3
"""reference_party.py - integer reference trajectories of the 2.0 rules (PHYSICS.md Appendix C).

Companion of docs/spec/PHYSICS.md Appendix C ("Party and Book II rules"). Our own code; it reuses the hero model of
reference_sim.py (PHYSICS.md 4-11) unchanged and adds the 2.0 rules on top of it. It writes
docs/spec/PARTY_REFERENCE.json: the expected values the phase-1 tests pin (mount jump table, Batter Up flights,
Shoulder Hop / Totem Ride heights, tar hop, vine leap, see-saw launches, versus knock-backs).

Usage:
    python reference_party.py            # run the self-checks, write PARTY_REFERENCE.json next to this file
    python reference_party.py --out X    # write somewhere else

Units: tick, px (logical), v16 (1/16 px per tick); +y is DOWN in the model, every "height" in the JSON is positive UP.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reference_sim as R  # noqa: E402  (the 1.0 hero model, PHYSICS.md 4-11)
from reference_sim import C, Hero, Inp, flat_world, floor16  # noqa: E402

GY = R.GROUND_ROW * 16
FULL = list(C["jump_impulses"])

# Constants of PHYSICS.md Appendix C (C.13 sheet). Every rule below reads its numbers from here.
P = {
    "totem_head_px": 35,              # carrier head = carrier feet - 35 (the 32 x 35 riding box, PHYSICS 2.1)
    "totem_rest_px": 34,              # the rider rests 1 px inside it (PHYSICS 11.4: top + 1)
    "launch_axis_cap": 288,           # every launch component is clamped to +/-288 v16 (18 px/tick, doze reach)
    "bat_line": [144, -128],
    "bat_lob": [32, -240],
    "bat_grounder_xvel": 96, "bat_grounder_ticks": 32,
    "bat_charged_num": 3, "bat_charged_den": 2,
    "hop_yvel": -224,
    "tar_impulse_ticks": 2, "tar_walk_cap": 32, "tar_air_cap": 32,
    "vine_leap": [32, -128],
    "seesaw_extra": 32, "seesaw_hard_extra": 64, "seesaw_cap": -288,
    "mount_walk_cap": 64, "mount_accel": 16, "mount_friction": 12, "mount_hop": -160,
    "vs_knock": [64, -128], "vs_charged_knock": [128, -160], "vs_charged_ice": 3, "vs_hammer_num": 3, "vs_hammer_den": 2,
    "vs_heavy_impulse_num": 3, "vs_heavy_impulse_den": 4,
}


def clamp(v: int, lo: int, hi: int) -> int:
    return lo if v < lo else hi if v > hi else v


def ballistic(yvel0: int, xvel0: int = 0) -> dict:
    """A body with no handler: integrate x, integrate y, then gravity (the hero's airborne order, PHYSICS 3 / 5.2).
    Used for every launched body that ignores input (the batted ball) and as the rise table of any launch."""
    x = y = 0
    v = yvel0
    rows = []
    for t in range(1, 400):
        x += floor16(xvel0)
        y += floor16(v)
        v = min(v + C["gravity"], C["terminal"])
        rows.append([t, x, -y])
        if t > 1 and y >= 0:
            break
    rise = max(r[2] for r in rows)
    apex = next(r[0] for r in rows if r[2] == rise)
    return {"yvel": yvel0, "xvel": xvel0, "rise_px": rise, "apex_tick": apex, "back_tick": rows[-1][0],
            "dx_at_back": rows[-1][1], "per_tick": rows}


def launches() -> list:
    return [{k: v for k, v in ballistic(y).items() if k != "per_tick"}
            for y in (-32, -48, -64, -80, -96, -128, -144, -160, -176, -192, -208, -224, -240, -256, -272, -288)]


def charged(v: int) -> int:
    return clamp((v * P["bat_charged_num"]) // P["bat_charged_den"] if v >= 0 else
                 -((-v * P["bat_charged_num"]) // P["bat_charged_den"]), -P["launch_axis_cap"], P["launch_axis_cap"])


def batter_up() -> dict:
    out = {}
    for name, (xv, yv) in (("line_drive", P["bat_line"]), ("lob", P["bat_lob"])):
        out[name] = ballistic(yv, xv)
        out[name + "_charged"] = ballistic(charged(yv), charged(xv))
    g = P["bat_grounder_xvel"]
    out["grounder"] = {"xvel": g, "ticks": P["bat_grounder_ticks"], "dx": floor16(g) * P["bat_grounder_ticks"]}
    gc = charged(g)
    out["grounder_charged"] = {"xvel": gc, "ticks": P["bat_grounder_ticks"], "dx": floor16(gc) * P["bat_grounder_ticks"]}
    # Lob onto a ledge: the ticks (and dx) during which the ball's feet are at or above a ledge of h px.
    lob = out["lob"]["per_tick"]
    out["lob_above"] = {str(h): [r[:2] for r in lob if r[2] >= h] for h in (96, 112)}
    return out


def shoulder_hop() -> dict:
    b = ballistic(P["hop_yvel"])
    head = P["totem_head_px"]
    feet = [[t, h + head] for t, _, h in b["per_tick"]]
    return {"bounce_yvel": P["hop_yvel"], "rise_from_head_px": b["rise_px"], "feet_apex_over_floor_px": b["rise_px"] + head,
            "ticks_feet_at_or_above": {str(h): sum(1 for _, f in feet if f >= h) for h in (112, 128)},
            "feet_per_tick": feet}


def _jump(impulses: list, hero: Hero, script, ticks: int = 80) -> list:
    old = C["jump_impulses"]
    C["jump_impulses"] = impulses
    rows = []
    try:
        for t in range(1, ticks):
            hero.tick(script(t))
            rows.append([t, hero.x, GY - hero.y, hero.grounded])
            if t > 1 and hero.grounded:
                break
    finally:
        C["jump_impulses"] = old
    return rows


def half_impulses() -> list:
    return [floor16(v * 8) for v in FULL]           # v >> 1, flooring (the glider's halved table, PHYSICS 13.2)


def totem() -> dict:
    """Carrier: the halved jump table (UP held). Rider: rests at carrier feet - 34 with yvel = carrier dy * 16
    (PHYSICS 11.4 ride rule, applied by the party driver after both heroes moved); presses UP on tick t0 of the
    carrier's jump and holds it k ticks."""
    carrier = _jump(half_impulses(), Hero(flat_world()), lambda t: Inp(up=True))
    cy = [0] + [r[2] for r in carrier]               # carrier feet height before tick t is cy[t-1]
    rest = P["totem_rest_px"]
    table = []
    for t0 in range(1, len(cy)):
        best = {}
        for k in (1, 2, 3, 4, 5, 9, 99):
            h = Hero(flat_world())
            h.y = GY - (cy[t0 - 1] + rest)
            dy = -(cy[t0 - 1] - cy[t0 - 2]) if t0 >= 2 else 0
            h.yvel = dy * 16
            top = h.y
            for t in range(1, 80):
                h.on_platform = t == 1
                h.tick(Inp(up=t <= k))
                top = min(top, h.y)
                if h.yvel > 0 and h.y > GY - (cy[t0 - 1] + rest) + 40:
                    break
            best[str(k)] = GY - top
        table.append({"t0": t0, "carrier_height": cy[t0 - 1], "rider_feet_apex_by_k": best})
    still = table[0]["rider_feet_apex_by_k"]
    return {"halved_impulses": half_impulses(), "carrier_heights": cy[1:], "rider_jump_from_still_carrier": still,
            "rider_jump_timed": table, "rider_high_strike_band_over_floor": [rest + 27, rest + 43]}


def tar_hop() -> dict:
    imp = FULL[:P["tar_impulse_ticks"]] + [0] * (len(FULL) - P["tar_impulse_ticks"])
    out = {}
    for name, d in (("right", 1), ("left", -1)):
        h = Hero(flat_world())
        h.xvel = P["tar_walk_cap"] * d
        h.facing = d

        def airborne(h=h):                          # PHYSICS C.5: the airborne ACCEL limit of a tar hop is 32
            h._accel(P["tar_air_cap"])
            h._gravity()
            if h.yvel > 0:
                h.no_jump = C["no_jump_ticks"]
        h._airborne_step = airborne
        x0 = h.x
        rows = _jump(imp, h, lambda t: Inp(up=True, right=d > 0, left=d < 0))
        out[name] = {"apex_px": max(r[2] for r in rows), "landing_tick": rows[-1][0], "dx": rows[-1][1] - x0}
    out["impulses"] = imp
    return out


def vine_leap() -> dict:
    out = {}
    for name, up in (("up_held", True), ("up_released", False)):
        h = Hero(flat_world())
        h.y = GY - 160
        h.xvel, h.yvel = P["vine_leap"]
        h.no_jump = C["no_jump_ticks"]
        h.grounded = False
        x0, y0 = h.x, h.y
        rows = []
        for t in range(1, 18):
            h.tick(Inp(up=up, right=True))
            rows.append([t, h.x - x0, y0 - h.y])
        out[name] = rows
    return out


def seesaw() -> list:
    """Landing yvel of a walk-off fall of n tiles (PHYSICS 6.5 table) -> launch of whoever stands on the low end."""
    falls = [(1, 96), (2, 128), (3, 160), (4, 176), (5, 192), (8, 192)]
    rows = []
    for tiles, v in falls:
        hard = tiles >= 4
        launch = max(-(v + P["seesaw_extra"]) - (P["seesaw_hard_extra"] if hard else 0), P["seesaw_cap"])
        b = ballistic(launch)
        rows.append({"walk_off_tiles": tiles, "landing_yvel": v, "hard": hard, "launch": launch, "rise_px": b["rise_px"]})
    return rows


def mount() -> dict:
    """Chomper (MountTuning): ground ACCEL 16 to 64, FRICTION 12, hop = one impulse of -160, air ACCEL(64) while a
    direction is held, gravity 16 / 192 (PHYSICS C.9)."""
    def hop(start_xvel: int, hold: bool) -> list:
        x = y = 0
        xv, yv = start_xvel, P["mount_hop"]
        rows = []
        for t in range(1, 100):
            x += floor16(xv)
            y += floor16(yv)
            if hold:
                xv = clamp(xv + P["mount_accel"], -P["mount_walk_cap"], P["mount_walk_cap"])
            yv = min(yv + C["gravity"], C["terminal"])
            rows.append([t, x, -y])
            if t > 1 and y >= 0:
                break
        return rows
    walk = []
    xv = x = 0
    for t in range(1, 9):
        xv = clamp(xv + P["mount_accel"], -P["mount_walk_cap"], P["mount_walk_cap"])
        x += floor16(xv)
        walk.append([t, xv, x])
    stop = []
    xv, x = P["mount_walk_cap"], 0
    for t in range(1, 8):
        xv = max(xv - P["mount_friction"], 0)
        x += floor16(xv)
        stop.append([t, xv, x])
    full = hop(P["mount_walk_cap"], True)
    rest = hop(0, True)
    return {"walk_from_rest": walk, "stop_from_full_speed": stop, "hop_from_full_speed": full,
            "hop_from_rest_direction_held": rest, "hop_apex_px": max(r[2] for r in full),
            "hop_landing_tick": full[-1][0], "hop_dx_full_speed": full[-1][1], "hop_dx_from_rest": rest[-1][1]}


def versus() -> dict:
    heavy = [(v * P["vs_heavy_impulse_num"]) >> 2 for v in FULL]    # x 3/4, flooring like every shift of the model
    jumps = {}
    for name, imp in (("normal", FULL), ("stack_20", heavy)):
        rows = _jump(imp, Hero(flat_world()), lambda t: Inp(up=True))
        jumps[name] = {"apex_px": max(r[2] for r in rows), "landing_tick": rows[-1][0]}
    knocks = {}
    hx = (P["vs_knock"][0] * P["vs_hammer_num"]) // P["vs_hammer_den"]
    for name, xv, yv, ice in (("hit_right", P["vs_knock"][0], P["vs_knock"][1], 0),
                              ("hit_left", -P["vs_knock"][0], P["vs_knock"][1], 0),
                              ("hammer_right", hx, P["vs_knock"][1], 0),
                              ("charged_right", P["vs_charged_knock"][0], P["vs_charged_knock"][1], P["vs_charged_ice"]),
                              ("charged_left", -P["vs_charged_knock"][0], P["vs_charged_knock"][1], P["vs_charged_ice"])):
        h = Hero(flat_world())
        h.xvel, h.yvel, h.ice, h.hit_timer, h.grounded = xv, yv, ice, 43, False
        x0 = h.x
        land = None
        for t in range(1, 40):
            h.tick(Inp())
            if land is None and t > 1 and h.grounded:
                land = t
        knocks[name] = {"xvel": xv, "yvel": yv, "ice": ice, "dx": h.x - x0, "landing_tick": land}
    return {"stack_20_impulses": heavy, "jumps": jumps, "knock_backs": knocks}


def build() -> dict:
    return {
        "_doc": "Reference trajectories of docs/spec/PHYSICS.md Appendix C, generated by reference_party.py. Heights are "
                "positive up, x positive right, in logical px; ticks are 1-based.",
        "constants": P,
        "launches": launches(),
        "batter_up": batter_up(),
        "shoulder_hop": shoulder_hop(),
        "totem_ride": totem(),
        "tar_hop": tar_hop(),
        "vine_leap": vine_leap(),
        "seesaw": seesaw(),
        "mount": mount(),
        "versus": versus(),
    }


def self_check(ref: dict) -> list:
    errors = []

    def eq(name, got, want):
        if got != want:
            errors.append(f"{name}: got {got}, want {want}")
    by_yvel = {r["yvel"]: r for r in ref["launches"]}
    eq("rise -160", by_yvel[-160]["rise_px"], 55)
    eq("rise -224", by_yvel[-224]["rise_px"], 105)
    eq("rise -288", by_yvel[-288]["rise_px"], 171)
    b = ref["batter_up"]
    eq("line drive dx", b["line_drive"]["dx_at_back"], 153)
    eq("lob rise", b["lob"]["rise_px"], 120)
    eq("lob dx", b["lob"]["dx_at_back"], 64)
    eq("grounder dx", b["grounder"]["dx"], 192)
    eq("hop feet apex", ref["shoulder_hop"]["feet_apex_over_floor_px"], 140)
    eq("totem still k5", ref["totem_ride"]["rider_jump_from_still_carrier"]["5"], 98)
    eq("tar apex", ref["tar_hop"]["right"]["apex_px"], 33)
    eq("mount apex", ref["mount"]["hop_apex_px"], 55)
    eq("mount landing", ref["mount"]["hop_landing_tick"], 21)
    eq("mount dx", ref["mount"]["hop_dx_full_speed"], 84)
    eq("seesaw cap", ref["seesaw"][-1]["launch"], -288)
    eq("stack_20 apex", ref["versus"]["jumps"]["stack_20"]["apex_px"], 38)
    return errors


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "PARTY_REFERENCE.json"))
    args = ap.parse_args(argv)
    ref = build()
    errors = self_check(ref)
    for e in errors:
        print("SELF-CHECK FAILED:", e)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(ref, f, indent=1, sort_keys=False)
        f.write("\n")
    print(("FAIL" if errors else "OK"), args.out)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
