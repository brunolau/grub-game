#!/usr/bin/env python3
"""reference_sim.py - integer reference simulation of the hero's movement.

Companion of docs/spec/PHYSICS.md. This is our own, table-driven implementation of the rules written down in
that document (sections 2-11); it copies no code from any other project. It produces
docs/spec/PHYSICS_REFERENCE.json: the expected values the Godot build is unit-tested against.

Usage:
    python reference_sim.py            # run the self-checks, write PHYSICS_REFERENCE.json next to this file
    python reference_sim.py --out X    # write somewhere else
    python reference_sim.py --print    # also dump the JSON to stdout

Model scope (what is and is not simulated):
  * simulated: state selection, all hero state handlers (idle, walk, jump, strike, crawl, crouch, hurt),
    x/y integration, the tile collision of PHYSICS.md 11.2 for FLAT tiles (floor / hatch / wall / ceiling),
    landing rules, timers, hit timer, club-box bookkeeping, the horizontal camera of 12.1;
  * not simulated: slopes (HEIGHT profiles), platforms, glider, wind (wind = 0), enemies (their effect on the
    hero is injected with Hero.hurt() / Hero.bounce() / Hero.pogo()), vertical camera.

Units: tick = one logic frame; px = one logical pixel (320x200 screen); v16 = 1/16 px per tick.
Axes: +x right, +y DOWN. "height" values in the JSON are positive UP (take-off y minus current y).
All state is integer. floor16(v) = v >> 4 (rounds towards minus infinity).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass, field

# ---------------------------------------------------------------------------------------------------------------
# Constant sheet (PHYSICS.md Appendix A). Every rule below reads its numbers from here.
# ---------------------------------------------------------------------------------------------------------------

PIT_HZ = 1193182.0            # PC timer input clock
PIT_DIVISOR = 0x4000          # the game's timer reload
GOVERNOR_TICKS = 3            # timer interrupts per game frame
TICK_HZ = PIT_HZ / PIT_DIVISOR / GOVERNOR_TICKS

C = {
    "tile": 16,
    "screen_w": 320, "screen_h": 200, "playfield_h": 176, "view_cols": 20, "view_rows": 11,
    "x_min": 8, "x_max_excl": 4088,
    "accel": 16,                  # v16 per tick, shifted right by ice
    "friction": 12,               # v16 per tick, shifted right by ice
    "walk_cap": 80,
    "crawl_cap": 32,
    "jump_held_cap": 48,
    "left_floor": -96,            # applied by WIND
    "jump_impulses": [-65, -51, -35, -20, -10, -5, -2, -1, 0],
    "gravity": 16,
    "terminal": 192,
    "no_jump_ticks": 6,
    "idle_air_second_wind_after_jump_ticks": 4,
    "soft_landing_max_fall_ticks": 4,
    "drop_min_px": 32, "drop_min_yvel": 80,
    "hard_landing_min_fall_ticks_excl": 10, "hard_landing_hop": -32,
    "shake_min_fall_ticks": 20, "shake_min_yvel_excl": 160, "shake_value": 8,
    "wall_probe": 9,
    "corner_slip": 2,
    "drop_timer": 4,
    "charge_step": 2, "charge_step_max_at": 48, "charge_multiplier": 4,
    "hit_timer": 44, "hit_stun_min": 22,
    "hurt_yvel": -128, "hurt_xvel_factor": -4,
    "energy_start": 3, "lives_start": 2,
    "bounce_yvel": -64, "bounce_yvel_up": -224,
    "pogo_yvel": -80,
    "stomp_min_yvel": 128,
    "death_anim_ticks": 60,
    "feast_ticks": 660,
    "cam_right_start": 16, "cam_left_start": 4, "cam_right_stop": 5, "cam_left_stop": 15,
    "cam_idle_split": 10, "cam_step_px": 16,
}

# State table (PHYSICS.md 4.3). Index = RIGHT<<4 | LEFT<<3 | UP<<2 | DOWN<<1 | FIRE.
STATE_LUT = [
    0, 3, 5, 7, 2, 6, 0, 0,     # no direction
    1, 3, 4, 7, 2, 6, 1, 0,     # LEFT
    1, 3, 4, 7, 2, 6, 0, 0,     # RIGHT
    0, 0, 0, 0, 0, 0, 0, 0,     # LEFT + RIGHT
]
STATE_NAME = {0: "idle", 1: "walk", 2: "jump", 3: "strike", 4: "crawl", 5: "crouch", 6: "high_strike",
              7: "low_strike", 8: "hurt"}

# Strike frame scripts (PHYSICS.md 8.1): one entry per tick, the last one carries the "end" mark.
STRIKE_SCRIPT = {
    3: ["fwd_windup"] * 2 + ["overhead"] * 2 + ["fwd_front"] * 3,
    6: ["high_lowback"] * 3 + ["high_backup"] * 3 + ["high_front"] * 3,
    7: ["low_back"] * 3 + ["overhead"] * 3 + ["low_front"] * 3,
}
STRIKE_HOP = {3: -32, 6: 0, 7: -48}           # added to yvel on the last tick (not on a platform)
STRIKE_FRONT_FRAME = {3: "fwd_front", 6: "high_front", 7: "low_front"}

# Club boxes of the default club, hero facing right, relative to the feet point *after this tick's
# integration* (PHYSICS.md 8.2): x0..x1, y0..y1 (y negative = above the feet), plus the box origin used by
# the hidden-tile test of 8.3.
CLUB_BOX = {
    "fwd_windup":   {"x": [-19, -3], "y": [-35, -16], "origin": [-11, -16]},
    "overhead":     {"x": [-19, 5],  "y": [-43, -25], "origin": [-7, -25]},
    "fwd_front":    {"x": [11, 35],  "y": [-15, -2],  "origin": [23, -2]},
    "high_lowback": {"x": [-19, -3], "y": [-19, -3],  "origin": [-11, -3]},
    "high_backup":  {"x": [-16, 0],  "y": [-37, -21], "origin": [-8, -21]},
    "high_front":   {"x": [10, 26],  "y": [-43, -27], "origin": [18, -27]},
    "low_back":     {"x": [-16, 0],  "y": [-33, -18], "origin": [-8, -18]},
    "low_front":    {"x": [-3, 21],  "y": [-5, 10],   "origin": [9, 10]},
}

# Weapons (PHYSICS.md 8.1): power, swing_lock L, thrown?
WEAPON = [
    {"name": "club",         "power": 25, "lock": 2,  "thrown": False},
    {"name": "hammer",       "power": 30, "lock": 6,  "thrown": False},
    {"name": "axe",          "power": 20, "lock": 6,  "thrown": True},
    {"name": "swirling_axe", "power": 30, "lock": 12, "thrown": True},
]

# Vertical camera speed curves (PHYSICS.md 12.2), as (first_d, last_d, px_per_tick) runs; 132 entries each.
# First curve: screens whose visible tiles are all opaque. Second curve: a backdrop shows through somewhere.
CAM_V_RUNS = [(0, 5, 1), (6, 23, 2), (24, 50, 3), (51, 63, 4), (64, 72, 5), (73, 79, 6), (80, 85, 7),
              (86, 88, 8), (89, 91, 9), (92, 93, 10), (94, 95, 11), (96, 96, 12), (97, 97, 13), (98, 98, 14),
              (99, 131, 16)]
CAM_V_RUNS_FAST = [(0, 3, 1), (4, 7, 2), (8, 9, 3), (10, 11, 4), (12, 12, 5), (13, 13, 6), (14, 14, 7),
                   (15, 15, 8), (16, 19, 9), (20, 26, 10), (27, 35, 11), (36, 48, 12), (49, 65, 13),
                   (66, 89, 14), (90, 99, 15), (100, 131, 16)]

# Sprite-box heights used only for the body probes of 11.2 step 8.
BODY_H_STAND = 35
BODY_H_CROUCH = 30


def floor16(v: int) -> int:
    """v / 16 rounded towards minus infinity (arithmetic shift)."""
    return v >> 4


# ---------------------------------------------------------------------------------------------------------------
# World: a logical tile grid with independent FLOOR / SIDE / CEIL properties (PHYSICS.md 11.1), flat tiles only.
# ---------------------------------------------------------------------------------------------------------------

class World:
    def __init__(self, floor_fn, side_fn=None, ceil_fn=None, max_camera_column=236, level_flag_bit0=False):
        self._floor = floor_fn
        self._side = side_fn or (lambda c, r: 0)
        self._ceil = ceil_fn or (lambda c, r: 0)
        self.max_camera_column = max_camera_column
        self.level_flag_bit0 = level_flag_bit0

    def floor(self, col, row):   # 0 empty, 1 floor, 2-4 ice 1-3, 5 hatch, 6 deadly
        return self._floor(col, row) if row >= 0 else 0

    def side(self, col, row):    # 0 passable, 1 wall, 2 deadly
        return self._side(col, row) if row >= 0 else 0

    def ceil(self, col, row):    # 0 none, 1 ceiling, 2 deadly ceiling
        return self._ceil(col, row) if row >= 0 else 0


GROUND_ROW = 20                 # default flat ground: floor tiles from row 20 down (surface y = 320)
START_X = 1000                  # column 62, px 8 inside the tile


def flat_world(ground_row=GROUND_ROW, floor_type=1, **kw) -> World:
    """Solid ground: every tile with row >= ground_row has FLOOR = floor_type and SIDE = 1."""
    return World(lambda c, r: floor_type if r >= ground_row else 0,
                 side_fn=lambda c, r: 1 if r >= ground_row else 0, **kw)


def ledge_world(edge_col, drop_tiles, upper_row=GROUND_ROW, **kw) -> World:
    """Solid ground (FLOOR 1, SIDE 1) from `upper_row` down for col < edge_col and from `upper_row + drop_tiles`
    down for col >= edge_col: a cliff whose face is a wall."""
    def top(c):
        return upper_row if c < edge_col else upper_row + drop_tiles
    return World(lambda c, r: 1 if r >= top(c) else 0, side_fn=lambda c, r: 1 if r >= top(c) else 0, **kw)


# ---------------------------------------------------------------------------------------------------------------
# Hero
# ---------------------------------------------------------------------------------------------------------------

@dataclass
class Inp:
    left: bool = False
    right: bool = False
    up: bool = False
    down: bool = False
    fire: bool = False


@dataclass
class Hero:
    world: World
    x: int = START_X
    y: int = GROUND_ROW * 16
    xvel: int = 0
    yvel: int = 0
    facing: int = 1
    ice: int = 0
    jump_ticks: int = 0
    fall_ticks: int = 0
    no_jump: int = 0
    last_ground_y: int = GROUND_ROW * 16
    drop_timer: int = 0
    charge: int = 0
    swing_lock: int = 0
    attack_gate: bool = False
    hit_timer: int = 0
    shake: int = 0
    idle_timer: int = 0
    energy: int = C["energy_start"]
    weapon: int = 0
    on_platform: bool = False       # never set here (no platforms); kept because rules read it
    wind: int = 0
    dead: bool = False
    # animation bookkeeping needed by the rules
    anim_num: int = 0               # which state's animation is loaded (strike restarts when it differs)
    strike_idx: int = 0             # next entry of the strike script
    club_power: int = 0
    # club box created during this tick (tested in the weapon pass of the NEXT tick), or None
    club_box: dict | None = None
    # per-tick report
    state: int = 0                  # state selected by the table + overrides 1-2 of 4.3
    handler: int = 0                # handler that actually ran (differs from state under the strike gate / no_jump)
    grounded: bool = True
    events: list = field(default_factory=list)
    lr_held: bool = False

    # ---- primitives (5.1, 6.2) ----
    def _accel(self, limit: int) -> None:
        step = ((self.facing * C["accel"]) >> self.ice) if self.lr_held else 0
        v = self.xvel + step
        if v >= limit:
            v = limit
        elif v <= -limit:
            v = -limit
        self.xvel = v

    def _friction(self) -> None:
        mag = abs(self.xvel) - (C["friction"] >> self.ice)
        if mag < 0:
            mag = 0
        self.xvel = -mag if self.xvel < 0 else mag

    def _wind(self) -> None:
        self.xvel -= self.wind >> 3
        if self.xvel < C["left_floor"]:
            self.xvel = C["left_floor"]

    def _gravity(self) -> None:
        v = self.yvel + C["gravity"]
        self.yvel = C["terminal"] if v >= C["terminal"] else v

    # ---- state handlers (5.2, 6.1, 8) ----
    def _h_idle(self) -> None:
        if self.attack_gate:
            return self._h_strike(self.anim_num)
        self.handler = 0
        self._wind()
        self._friction()
        if not self.on_platform and self.yvel != 0:
            if self.jump_ticks > C["idle_air_second_wind_after_jump_ticks"]:
                self._wind()
            return
        self.anim_num = 0

    def _h_walk(self) -> None:
        if self.attack_gate:
            return self._h_strike(self.anim_num)
        self.handler = 1
        self.idle_timer = min(self.idle_timer + 1, 255)
        self._accel(C["walk_cap"])
        self._wind()
        self.anim_num = 1

    def _h_jump(self) -> None:
        if self.attack_gate:
            return self._h_strike(self.anim_num)
        if self.no_jump != 0:
            return self._h_idle()
        self.handler = 2
        self.on_platform = False
        n = self.jump_ticks
        self.jump_ticks = (self.jump_ticks + 1) & 0xFF
        if n < len(C["jump_impulses"]):
            self.yvel += C["jump_impulses"][n]
        else:
            self._gravity()
        if (self.xvel & 0xFFFF) < C["jump_held_cap"]:        # unsigned compare: every negative xvel brakes
            self._accel(C["jump_held_cap"])
        else:
            self._friction()
        self.anim_num = 2
        self._wind()
        self._wind()

    def _h_strike(self, kind: int) -> None:
        self.handler = kind
        if self.anim_num != kind:
            self.anim_num = kind
            self.strike_idx = 0
        script = STRIKE_SCRIPT[kind]
        if self.strike_idx >= len(script):                   # loop marker
            self.strike_idx = 0
        frame = script[self.strike_idx]
        last = self.strike_idx == len(script) - 1
        self.strike_idx += 1
        self._friction()
        self.idle_timer = min(self.idle_timer + 1, 255)
        w = WEAPON[self.weapon]
        self.club_power = w["power"] * (C["charge_multiplier"] if self.charge != 0 else 1)
        self.attack_gate = not last
        if last:
            self.swing_lock = w["lock"]
            self.events.append("strike_end")
            if not self.on_platform:
                self.yvel += STRIKE_HOP[kind]
            if w["thrown"]:
                self.events.append("throw")
                return                                      # projectile spawned, no club box this tick
            if self.fall_ticks != 0:
                return                                      # descending in the air: no club box this tick
        b = CLUB_BOX[frame]
        s = self.facing
        nx = self.x + floor16(self.xvel)
        ny = self.y + floor16(self.yvel)
        xs = sorted((nx + s * b["x"][0], nx + s * b["x"][1]))
        self.club_box = {"frame": frame, "x": xs, "y": [ny + b["y"][0], ny + b["y"][1]],
                         "origin": [nx + s * b["origin"][0], ny + b["origin"][1]], "power": self.club_power}

    def _add_charge(self) -> None:
        if self.charge <= C["charge_step_max_at"]:
            self.charge += C["charge_step"]

    def _h_crawl(self) -> None:
        if self.attack_gate:
            return self._h_strike(self.anim_num)
        self.handler = 4
        self.idle_timer = 0
        self.drop_timer = C["drop_timer"]
        self._add_charge()
        if abs(self.xvel) > C["crawl_cap"]:
            return self._h_idle()
        self._accel(C["crawl_cap"])
        self.anim_num = 4

    def _h_crouch(self) -> None:
        if self.attack_gate:
            return self._h_strike(self.anim_num)
        self.handler = 5
        self.drop_timer = C["drop_timer"]
        self.anim_num = 5
        self._friction()
        self._add_charge()

    def _h_hurt(self) -> None:
        self.handler = 8
        self._wind()
        self._friction()
        self.anim_num = 8

    # ---- tile collision (11.2), flat tiles ----
    def _airborne_step(self) -> None:
        self._accel(C["walk_cap"])
        self._gravity()
        if self.yvel > 0:
            self.no_jump = C["no_jump_ticks"]

    def _soft_land(self) -> None:
        self.yvel = 0
        self.no_jump = max(self.no_jump - 1, 0)
        self.jump_ticks = 0
        self.last_ground_y = self.y

    def _land(self) -> bool:
        """LAND of 11.2 step 4. Returns True when the hero is airborne after it."""
        self.ice = 0
        if self.yvel < 0:
            return True                                     # floors are one-way
        self.y -= self.y % C["tile"]
        if self.fall_ticks > C["soft_landing_max_fall_ticks"]:
            self.events.append("dust")
            if self.y - self.last_ground_y >= C["drop_min_px"] and self.yvel >= C["drop_min_yvel"]:
                self.last_ground_y = self.y
                if self.fall_ticks >= C["shake_min_fall_ticks"] and self.yvel > C["shake_min_yvel_excl"]:
                    self.shake = C["shake_value"]
                    self.events.append("shake")
                if self.fall_ticks > C["hard_landing_min_fall_ticks_excl"]:
                    if not self.world.level_flag_bit0:
                        self.yvel = C["hard_landing_hop"]
                    self.fall_ticks = 0
                    self.events.append("land_hard")
                    return False
        if self.yvel > 0 or not self.grounded:
            self.events.append("land_soft")
        self._soft_land()
        return False

    def _collide(self, body_h: int) -> None:
        w = self.world
        T = C["tile"]
        col, row = self.x >> 4, self.y >> 4
        edge = C["wall_probe"] if self.xvel > 0 else (-C["wall_probe"] if self.xvel < 0 else 0)
        airborne = False
        above_map = self.y <= -1
        if above_map:
            self._airborne_step()
        else:
            f = w.floor(col, row)
            if f == 0:
                airborne = True
            elif 1 <= f <= 5:
                if f == 5 and self.drop_timer != 0:
                    self.ice = 0
                    airborne = True
                else:
                    airborne = self._land()
                    if f in (2, 3, 4):
                        self.ice = f - 1
            elif f == 6:
                self.dead = True
                self.events.append("death_floor")
            # ceiling block: rising or grounded, never while falling
            if row >= 2 and self.yvel <= 0:
                cflag = w.ceil(col, row - 2)
                if cflag == 1:
                    if self.yvel != 0:
                        self.yvel = 0
                        self.y = (self.y - self.y % T) + T
                        self.events.append("head_bump")
                elif cflag == 2:
                    self.dead = True
                    self.events.append("death_ceiling")
                if (w.side(col, row - 1) & 1) and self.y > 0:
                    d = -1 if self.xvel > 0 else 1
                    if w.side(col + d, row - 1) == 0:
                        self.x += C["corner_slip"] * d
                    elif w.side(col - d, row - 1) == 0:
                        self.x -= C["corner_slip"] * d
        if airborne:
            self._airborne_step()
            if self.yvel > 0:
                self.fall_ticks += 1
        else:
            self.fall_ticks = 0
        self.grounded = not airborne and not above_map
        if self.y > 0:
            s = w.side((self.x + edge) >> 4, row - 1)
            if s == 1:
                self.x -= floor16(self.xvel)
                self.xvel = 0
                self.events.append("wall")
            elif s == 2:
                self.dead = True
            k, r = 1, row - 2
            while r >= 0 and body_h - T * k > 0:
                if w.side((self.x + edge) >> 4, r) == 2:
                    self.dead = True
                k += 1
                r -= 1

    # ---- one tick: PHYSICS.md section 3, steps 8 and 14 ----
    def tick(self, inp: Inp) -> None:
        self.events = []
        self.club_box = None                                 # 8a
        self.lr_held = inp.left or inp.right                 # 8b
        if inp.right and not inp.left:
            self.facing = 1
        elif inp.left and not inp.right:
            self.facing = -1
        mask = (inp.right << 4) | (inp.left << 3) | (inp.up << 2) | (inp.down << 1) | int(inp.fire)   # 8c
        if self.swing_lock != 0:
            mask = 0
        st = STATE_LUT[mask]
        if self.hit_timer >= C["hit_stun_min"]:
            st = 8
        self.state = st
        body_h = BODY_H_CROUCH if st in (4, 5) else BODY_H_STAND
        {0: self._h_idle, 1: self._h_walk, 2: self._h_jump, 4: self._h_crawl, 5: self._h_crouch,     # 8d
         8: self._h_hurt}.get(st, lambda: self._h_strike(st))()
        nx = self.x + floor16(self.xvel)                     # 8e
        if C["x_min"] <= nx < C["x_max_excl"] and nx < (self.world.max_camera_column + C["view_cols"]) * 16:
            self.x = nx
        self.y += floor16(self.yvel)                         # 8f
        self._collide(body_h)                                # 8g
        for name in ("charge", "swing_lock", "shake", "drop_timer"):                                # 8i
            v = getattr(self, name)
            if v > 0:
                setattr(self, name, v - 1)
        if self.hit_timer > 0:                               # step 14 (draw)
            self.hit_timer -= 1

    # ---- effects injected by other systems (run outside the hero update) ----
    def hurt(self) -> None:
        """Enemy contact that is not a bounce (10.1); belongs to step 9 of the tick."""
        self.hit_timer = C["hit_timer"]
        self.attack_gate = False
        self.yvel = C["hurt_yvel"]
        self.xvel = C["hurt_xvel_factor"] * self.xvel
        self.energy -= 1
        if self.energy < 0:
            self.dead = True

    def bounce(self, up_held: bool, depth: int = 0) -> None:
        """Enemy bounce (section 9); step 9 of the tick."""
        self.yvel = C["bounce_yvel_up"] if up_held else C["bounce_yvel"]
        self.fall_ticks = 0
        self.y -= depth

    def pogo(self) -> None:
        """Club box hit something (weapon pass, step 2 of the NEXT tick's start)."""
        if self.yvel != 0:
            self.yvel = C["pogo_yvel"]


# ---------------------------------------------------------------------------------------------------------------
# Horizontal camera (12.1)
# ---------------------------------------------------------------------------------------------------------------

@dataclass
class CamH:
    col: int = 0
    dir: int = 0                    # 0 idle, 1 right, 2 left

    def step(self, hero: Hero) -> None:
        sc = (hero.x >> 4) - self.col
        if sc < C["view_cols"] and not hero.on_platform and hero.xvel == 0:
            self.dir = 0
            return
        if self.dir == 0:
            right = hero.xvel > 0 if hero.xvel != 0 else sc >= C["cam_idle_split"]
            if right:
                if sc >= C["cam_right_start"]:
                    self.dir = 1
            elif sc <= C["cam_left_start"]:
                self.dir = 2
        elif self.dir == 1:
            if sc <= C["cam_right_stop"] or self.col >= hero.world.max_camera_column:
                self.dir = 0
            else:
                self.col += 1
        else:
            if sc >= C["cam_left_stop"] or self.col == 0:
                self.dir = 0
            else:
                self.col -= 1


def cam_v_speed(d: int, fast: bool = False):
    for a, b, v in (CAM_V_RUNS_FAST if fast else CAM_V_RUNS):
        if a <= d <= b:
            return v
    return None


# ---------------------------------------------------------------------------------------------------------------
# Scenario helpers
# ---------------------------------------------------------------------------------------------------------------

def run(hero: Hero, script, ticks: int, stop=None):
    """Run `ticks` ticks; script(t) -> Inp for tick t (1-based). Returns per-tick rows."""
    x0, y0 = hero.x, hero.y
    rows = []
    for t in range(1, ticks + 1):
        hero.tick(script(t))
        rows.append({"tick": t, "x": hero.x - x0, "height": y0 - hero.y, "xvel": hero.xvel, "yvel": hero.yvel,
                     "state": STATE_NAME[hero.state], "grounded": hero.grounded, "events": list(hero.events),
                     "fall_ticks": hero.fall_ticks, "no_jump": hero.no_jump,
                     "club_box": hero.club_box})
        if stop and stop(hero, t):
            break
    return rows


def col(rows, key):
    return [r[key] for r in rows]


def hold(**kw):
    i = Inp(**kw)
    return lambda t: i


def first_landing(rows):
    """First tick (>= 2) on which a landing event happened."""
    for r in rows:
        if r["tick"] >= 2 and ("land_soft" in r["events"] or "land_hard" in r["events"]):
            return r
    return None


def running_hero(direction: int, world=None) -> Hero:
    h = Hero(world or flat_world())
    h.facing = direction
    h.xvel = direction * C["walk_cap"]
    return h


# ---------------------------------------------------------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------------------------------------------------------

def sc_walk():
    out = {}
    for name, d in (("right", 1), ("left", -1)):
        h = Hero(flat_world())
        rows = run(h, hold(right=d > 0, left=d < 0), 8)
        top = next(r["tick"] for r in rows if abs(r["xvel"]) == C["walk_cap"])
        out[name] = {"xvel": col(rows, "xvel"), "x": col(rows, "x"), "ticks_to_top_speed": top,
                     "px_to_top_speed": abs(rows[top - 1]["x"]), "top_speed_v16": C["walk_cap"],
                     "top_speed_px_per_tick": abs(rows[-1]["x"] - rows[-2]["x"])}
    return out


def sc_stop():
    out = {}
    for name, d in (("right", 1), ("left", -1)):
        h = running_hero(d)
        rows = run(h, hold(), 10)
        stop_tick = next(r["tick"] for r in rows if r["xvel"] == 0)
        out[name] = {"xvel": col(rows, "xvel"), "x": col(rows, "x"), "ticks_until_xvel_zero": stop_tick,
                     "distance_px": abs(rows[-1]["x"])}
    return out


def sc_reverse():
    out = {}
    for name, d in (("from_right", 1), ("from_left", -1)):
        h = running_hero(d)
        rows = run(h, hold(right=d < 0, left=d > 0), 12)
        zero = next(r["tick"] for r in rows if r["xvel"] == 0)
        full = next(r["tick"] for r in rows if r["xvel"] == -d * C["walk_cap"])
        xs = col(rows, "x")
        out[name] = {"xvel": col(rows, "xvel"), "x": xs, "ticks_to_zero": zero, "ticks_to_full_reverse": full,
                     "overshoot_px": max(abs(v) for v in xs[:zero])}
    return out


def sc_crawl():
    out = {}
    for name, d in (("right", 1), ("left", -1)):
        h = Hero(flat_world())
        rows = run(h, hold(right=d > 0, left=d < 0, down=True), 6)
        out[name] = {"xvel": col(rows, "xvel"), "x": col(rows, "x"),
                     "ticks_to_cap": next(r["tick"] for r in rows if abs(r["xvel"]) == C["crawl_cap"]),
                     "cap_px_per_tick": abs(rows[-1]["x"] - rows[-2]["x"])}
    h = running_hero(1)                                   # entering a crawl at full walking speed slides first
    rows = run(h, hold(right=True, down=True), 12)
    out["enter_at_full_speed_right"] = {"xvel": col(rows, "xvel"), "x": col(rows, "x")}
    return out


def sc_ice():
    out = {}
    for ice in (0, 1, 2, 3):
        w = flat_world(floor_type=1 + ice)
        h = Hero(w)
        h.ice = ice
        rows = run(h, hold(right=True), 60)
        up = next(r["tick"] for r in rows if r["xvel"] == C["walk_cap"])
        h = running_hero(1, w)
        h.ice = ice
        rows2 = run(h, hold(), 120)
        down = next(r["tick"] for r in rows2 if r["xvel"] == 0)
        out[f"ice_{ice}"] = {"accel_v16": C["accel"] >> ice, "friction_v16": C["friction"] >> ice,
                             "ticks_0_to_cap": up, "px_0_to_cap": rows[up - 1]["x"],
                             "ticks_cap_to_0": down, "slide_px_right": rows2[-1]["x"]}
    return out


def jump_script(k=None, right=False, left=False):
    """UP held for the first k ticks (None = always); direction held throughout."""
    def s(t):
        return Inp(up=(k is None or t <= k), right=right, left=left)
    return s


def summarize_jump(rows):
    land = first_landing(rows)
    hs = col(rows, "height")
    apex = max(hs)
    apex_ticks = [r["tick"] for r in rows if r["height"] == apex and r["tick"] <= land["tick"]]
    return {"apex_px": apex, "apex_first_tick": apex_ticks[0], "apex_last_tick": apex_ticks[-1],
            "landing_tick": land["tick"], "airborne_ticks": land["tick"] - 1,
            "landing_type": "hard" if "land_hard" in land["events"] else "soft",
            "x_at_landing": land["x"]}


def sc_standing_jump():
    h = Hero(flat_world())
    rows = run(h, jump_script(), 60)
    s = summarize_jump(rows)
    n = s["landing_tick"]
    # earliest tick on which the jump handler runs again while UP stays held
    again = next(r["tick"] for r in rows if r["tick"] > n and r["height"] > 0)
    s.update({
        "height": col(rows[:n], "height"), "yvel_after_tick": col(rows[:n], "yvel"),
        "peak_rise_px_in_one_tick": max(b - a for a, b in zip([0] + col(rows[:n], "height"), col(rows[:n], "height"))),
        "next_takeoff_tick_if_up_held": again, "jump_period_ticks_if_up_held": again - 1,
        "grounded_lockout_ticks": again - n,
    })
    return s


def sc_variable_jump():
    out = {}
    for k in range(1, 15):
        h = Hero(flat_world())
        rows = run(h, jump_script(k), 60)
        s = summarize_jump(rows)
        out[f"up_held_{k}_ticks"] = {"apex_px": s["apex_px"], "landing_tick": s["landing_tick"],
                                     "airborne_ticks": s["airborne_ticks"]}
    h = Hero(flat_world())
    rows = run(h, jump_script(1), 60)
    n = first_landing(rows)["tick"]
    out["tap_height"] = col(rows[:n], "height")
    h = Hero(flat_world())
    rows = run(h, jump_script(9), 60)
    n = first_landing(rows)["tick"]
    out["release_after_9_height"] = col(rows[:n], "height")
    return out


def sc_running_jump():
    out = {}
    for name, d in (("right", 1), ("left", -1)):
        kw = {"right": d > 0, "left": d < 0}
        h = running_hero(d)
        rows = run(h, jump_script(None, **kw), 60)
        s = summarize_jump(rows)
        n = s["landing_tick"]
        out[f"hold_up_{name}"] = {"x": col(rows[:n], "x"), "height": col(rows[:n], "height"),
                                  "xvel_after_tick": col(rows[:n], "xvel"), "landing_tick": n,
                                  "distance_px": abs(s["x_at_landing"]), "apex_px": s["apex_px"],
                                  "px_per_tick_steady": abs(rows[5]["x"] - rows[4]["x"])}
        rel = {}
        for k in range(1, 12):
            h = running_hero(d)
            rows = run(h, jump_script(k, **kw), 60)
            s = summarize_jump(rows)
            rel[f"k_{k}"] = {"distance_px": abs(s["x_at_landing"]), "landing_tick": s["landing_tick"],
                             "apex_px": s["apex_px"]}
            if k == 9:
                n = s["landing_tick"]
                out[f"release_up_after_9_{name}"] = {"x": col(rows[:n], "x"), "height": col(rows[:n], "height"),
                                                     "landing_tick": n, "distance_px": abs(s["x_at_landing"]),
                                                     "apex_px": s["apex_px"]}
        out[f"release_up_after_k_{name}"] = rel
        h = Hero(flat_world())
        rows = run(h, jump_script(None, **kw), 60)
        s = summarize_jump(rows)
        n = s["landing_tick"]
        out[f"standing_start_hold_up_{name}"] = {"x": col(rows[:n], "x"), "landing_tick": n,
                                                 "distance_px": abs(s["x_at_landing"])}
    # UP + RIGHT held for three consecutive jumps: ground lock-out brakes the hero between jumps
    h = running_hero(1)
    rows = run(h, jump_script(None, right=True), 90)
    takeoffs = [r["tick"] for i, r in enumerate(rows) if r["height"] > 0 and (i == 0 or rows[i - 1]["height"] == 0)]
    landings = [r["tick"] for r in rows if "land_soft" in r["events"]]
    out["hold_up_right_repeated"] = {"takeoff_ticks": takeoffs[:3], "landing_ticks": landings[:3],
                                     "x_at_landings": [rows[t - 1]["x"] for t in landings[:3]],
                                     "xvel_on_ground_between_jumps": col(rows[21:27], "xvel")}
    return out


def sc_free_fall():
    """Walk right at full speed off a ledge; tick 1 = the tick the feet point leaves the floor."""
    edge_col = 70
    out = {"per_tick_fall_px": None, "by_drop_tiles": {}}
    for n in range(1, 17):
        w = ledge_world(edge_col, n)
        h = running_hero(1, w)
        h.x = edge_col * 16 - 5                             # one 5 px step puts the feet point on the edge column
        y0 = h.y
        rows = run(h, hold(right=True), 80)
        land = first_landing(rows)
        t = land["tick"]
        before = rows[t - 2]                                # the tick before touchdown
        typ = "hard" if "land_hard" in land["events"] else "soft"
        after = rows[t - 1:]
        rise = max(r["height"] for r in after) - land["height"]
        settle = next((r["tick"] for r in after if r["tick"] > t and "land_soft" in r["events"]), t)
        out["by_drop_tiles"][f"{n}"] = {
            "drop_px": n * 16, "landing_tick": t, "fall_ticks_at_touchdown": before["fall_ticks"],
            "yvel_at_touchdown": before["yvel"], "px_per_tick_at_touchdown": floor16(before["yvel"]),
            "landing_type": typ, "dust": "dust" in land["events"], "shake": "shake" in land["events"],
            "x_travel_px_at_touchdown": land["x"] - 5,
            "hop_rise_px": rise, "settle_tick": settle,
        }
        if n == 16:
            fall = [-(r["height"]) for r in rows[:t - 1]]
            out["per_tick_fall_px"] = [b - a for a, b in zip([0] + fall, fall)]
            out["cumulative_fall_px"] = fall
            out["yvel_after_tick"] = col(rows[:t - 1], "yvel")
    first_term = next(i + 1 for i, v in enumerate(out["yvel_after_tick"]) if v == C["terminal"])
    out["terminal_yvel_reached_after_tick"] = first_term
    out["first_tick_moving_at_terminal"] = first_term + 1
    out["px_fallen_when_first_moving_at_terminal"] = out["cumulative_fall_px"][first_term]
    out["no_jump_armed_on_tick"] = 1
    return out


def sc_impulses():
    """Rise produced by a yvel override applied between two ticks, nothing held."""
    out = {}
    for v in (-32, -48, -64, -80, -96, -128, -144, -160, -224):
        h = Hero(flat_world())
        h.yvel = v
        rows = run(h, hold(), 60)
        s = summarize_jump(rows)
        out[str(v)] = {"rise_px": s["apex_px"], "landing_tick": s["landing_tick"]}
    return out


def sc_hurt():
    out = {}
    for name, d in (("standing", 0), ("moving_right", 1), ("moving_left", -1)):
        h = Hero(flat_world())
        if d:
            h.facing = d
            h.xvel = d * C["walk_cap"]
        h.hurt()
        h.hit_timer -= 1                                    # the draw step of the hit tick
        rows = run(h, hold(), 50)
        land = first_landing(rows)
        xs = col(rows, "x")
        stun = [r["tick"] for r in rows if r["state"] == "hurt"]
        out[name] = {"x": xs[:land["tick"]], "height": col(rows[:land["tick"]], "height"),
                     "x_per_tick": [b - a for a, b in zip([0] + xs, xs)][:8],
                     "knockback_px": xs[-1], "rise_px": max(col(rows, "height")), "landing_tick": land["tick"],
                     "stun_ticks": len(stun), "first_tick_with_control": stun[-1] + 1}
    # invulnerability: enemy contact is tested only while hit_timer == 0 (step 9, after the hero update)
    h = Hero(flat_world())
    h.hurt()
    h.hit_timer -= 1
    t = 0
    while h.hit_timer != 0:
        t += 1
        h.tick(Inp())
    out["hit_timer_start"] = C["hit_timer"]
    out["ticks_after_hit_tick_until_contact_tested_again"] = t + 1
    out["immune_contact_passes"] = t
    out["hits_survived_from_full_energy"] = C["energy_start"]
    return out


def strike_timeline(kind: int, weapon: int = 0):
    h = Hero(flat_world())
    h.weapon = weapon
    key = {3: {"fire": True}, 6: {"fire": True, "up": True}, 7: {"fire": True, "down": True}}[kind]
    rows = run(h, hold(**key), 40)
    n = len(STRIKE_SCRIPT[kind])
    front = STRIKE_FRONT_FRAME[kind]
    ends = [r["tick"] for r in rows if "strike_end" in r["events"]]
    created = [r["tick"] for r in rows[:n] if r["club_box"] and r["club_box"]["frame"] == front]
    y0 = GROUND_ROW * 16
    per_tick = []
    for r in rows[:ends[1] - 1]:
        b = r["club_box"]
        rel = None
        if b:
            hx, hy = START_X + r["x"], y0 - r["height"]
            rel = {"frame": b["frame"], "x": [b["x"][0] - hx, b["x"][1] - hx], "y": [b["y"][0] - hy, b["y"][1] - hy]}
        per_tick.append({"tick": r["tick"], "state": r["state"], "club_box": rel, "height": r["height"],
                         "grounded": r["grounded"]})
    lock = WEAPON[weapon]["lock"]
    return {
        "weapon": WEAPON[weapon]["name"], "length_ticks": n, "script": STRIKE_SCRIPT[kind],
        "startup_ticks": created[0] - 1 if created else n - 1,
        "front_box_created_on_ticks": created,
        "front_box_hit_tested_on_ticks": [t + 1 for t in created],
        "swing_lock_set": lock, "input_ignored_ticks": list(range(n + 1, n + lock)),
        "auto_repeat_period_ticks": ends[1] - ends[0], "next_strike_first_tick": ends[0] + lock,
        "hop_v16": STRIKE_HOP[kind], "hop_rise_px": max(col(rows[:ends[1] - 1], "height")),
        "airborne_ticks_first_strike": [r["tick"] for r in rows[:ends[1] - 1] if not r["grounded"]],
        "per_tick": per_tick,
    }


def sc_attack():
    out = {"forward": strike_timeline(3), "high": strike_timeline(6), "low": strike_timeline(7),
           "club_box_default_club_facing_right": CLUB_BOX, "weapons": WEAPON, "repeat_period_forward": {}}
    for i, w in enumerate(WEAPON):
        out["repeat_period_forward"][w["name"]] = strike_timeline(3, i)["auto_repeat_period_ticks"]
    # charge: crouch k ticks, then hold FIRE; which ticks of the forward strike create a charged box?
    ch = {}
    for k in (1, 2, 4, 5, 6, 7, 10, 60):
        h = Hero(flat_world())
        run(h, hold(down=True), k)
        after = h.charge
        rows = run(h, hold(fire=True), 7)
        powers = [r["club_box"]["power"] if r["club_box"] else None for r in rows]
        ch[f"crouch_{k}_ticks"] = {"charge_after_crouch": after, "box_power_per_strike_tick": powers,
                                   "charged_front_frames": sum(1 for p in powers[4:7] if p == 100)}
    out["charge"] = ch
    h = Hero(flat_world())
    run(h, hold(down=True), 80)
    hi = h.charge
    t = 0
    while h.charge != 0:
        h.tick(Inp())
        t += 1
    out["charge"]["saturation_value_after_long_crouch"] = hi
    out["charge"]["ticks_until_zero_after_standing_up"] = t
    return out


def sc_lockout():
    """Walk off a 1-tile step: jump is refused while airborne and for the grounded lock-out afterwards."""
    w = ledge_world(70, 1)
    h = running_hero(1, w)
    h.x = 70 * 16 - 5
    rows = run(h, lambda t: Inp(right=True, up=t >= 2), 40)
    land = first_landing(rows)
    jump = next(r["tick"] for r in rows if r["tick"] > land["tick"] and r["state"] == "jump" and r["yvel"] < 0)
    h2 = running_hero(1, w)
    h2.x = 70 * 16 - 5
    rows2 = run(h2, hold(right=True, up=True), 3)
    return {"coyote_ticks": 0, "landing_tick": land["tick"], "first_tick_jump_handler_runs_again": jump,
            "grounded_ticks_before_jump": jump - land["tick"],
            "up_pressed_on_the_floor_loss_tick_still_jumps": rows2[0]["yvel"] < 0}


def sc_collision():
    out = {}
    # wall: flat ground, wall tiles from column 70, rows above the ground
    wall_col = 70
    w = World(lambda c, r: 1 if r >= GROUND_ROW else 0, side_fn=lambda c, r: 1 if (c >= wall_col and r < GROUND_ROW) else 0)
    h = running_hero(1, w)
    x_start = wall_col * 16 - 40
    h.x = x_start
    rows = run(h, hold(right=True), 12)
    out["walk_into_wall_right"] = {"x_abs": [x_start + r["x"] for r in rows], "xvel": col(rows, "xvel"),
                                   "rest_x_abs": h.x, "wall_left_edge_x": wall_col * 16,
                                   "gap_px_feet_to_wall": wall_col * 16 - h.x}
    wl = 60
    w = World(lambda c, r: 1 if r >= GROUND_ROW else 0, side_fn=lambda c, r: 1 if (c <= wl and r < GROUND_ROW) else 0)
    h = running_hero(-1, w)
    h.x = (wl + 1) * 16 + 40
    run(h, hold(left=True), 12)
    out["walk_into_wall_left"] = {"rest_x_abs": h.x, "wall_right_edge_x": (wl + 1) * 16,
                                  "gap_px_wall_to_feet": h.x - (wl + 1) * 16}
    # ceiling: ceiling tile row `clear` rows above the ground row
    ce = {}
    for gap_rows in (2, 3, 4, 5):
        crow = GROUND_ROW - gap_rows
        w = World(lambda c, r: 1 if r >= GROUND_ROW else 0, ceil_fn=lambda c, r, crow=crow: 1 if r == crow else 0)
        h = Hero(w)
        rows = run(h, jump_script(), 40)
        s = summarize_jump(rows)
        bump = next((r["tick"] for r in rows if "head_bump" in r["events"]), None)
        ce[f"ceiling_bottom_{(gap_rows - 1) * 16}_px_above_feet"] = {
            "head_bump_tick": bump, "apex_px": s["apex_px"], "landing_tick": s["landing_tick"]}
    out["standing_jump_under_ceiling"] = ce
    # hatch: crouching on a hatch tile falls through
    w = World(lambda c, r: 5 if r == GROUND_ROW else (1 if r >= GROUND_ROW + 4 else 0))
    h = Hero(w)
    rows = run(h, lambda t: Inp(down=t <= 3), 40)
    out["hatch_drop"] = {"first_airborne_tick": next(r["tick"] for r in rows if not r["grounded"]),
                         "landing_tick": first_landing(rows)["tick"]}
    return out


def sc_camera():
    out = {"constants": {k: C[k] for k in ("cam_right_start", "cam_left_start", "cam_right_stop",
                                           "cam_left_stop", "cam_idle_split", "cam_step_px")}}
    for name, d in (("walk_right", 1), ("walk_left", -1)):
        h = running_hero(d)
        cam = CamH(col=(h.x >> 4) - 10)
        cols, scs = [], []
        start = stop = None
        for t in range(1, 80):
            h.tick(Inp(right=d > 0, left=d < 0))
            prev = cam.dir
            cam.step(h)
            if prev == 0 and cam.dir != 0 and start is None:
                start = t
            if prev != 0 and cam.dir == 0 and stop is None:
                stop = t
            cols.append(cam.col)
            scs.append((h.x >> 4) - cam.col)
        moved = [t + 1 for t in range(1, len(cols)) if cols[t] != cols[t - 1]]
        out[name] = {"start_camera_col": (START_X >> 4) - 10, "hero_screen_col_start": 10,
                     "page_decided_on_tick": start, "first_camera_move_tick": moved[0],
                     "page_ends_on_tick": stop, "camera_moves_in_first_page": sum(1 for m in moved if m < stop),
                     "hero_screen_col_when_page_ends": scs[stop - 1],
                     "camera_col_per_tick": cols[:stop + 2], "hero_screen_col_per_tick": scs[:stop + 2]}
    out["vertical_speed_px_per_tick_by_distance"] = [cam_v_speed(d) for d in range(132)]
    out["vertical_speed_px_per_tick_by_distance_backdrop_visible"] = [cam_v_speed(d, True) for d in range(132)]
    out["vertical_target_rows"] = {"airborne_sr_ge_9": 3, "airborne_sr_le_2": 8, "grounded_sr_ge_10": 9,
                                   "grounded_sr_le_3": 8, "grounded_flag0_sr_ge_8": 7, "grounded_flag0_sr_le_5": 6}
    return out


def airborne_hero(xvel=0, facing=1, above_px=400) -> Hero:
    """A hero already falling (yvel > 0, no_jump armed) high above flat ground."""
    h = Hero(flat_world())
    h.y -= above_px
    h.facing = facing
    h.xvel = xvel
    h.yvel = C["gravity"]
    h.no_jump = C["no_jump_ticks"]
    h.fall_ticks = 1
    h.grounded = False
    return h


def sc_air_control():
    """Horizontal control while falling (UP released unless the case name says otherwise)."""
    out = {}
    cap = C["walk_cap"]
    cases = {
        "from_rest_hold_right": (0, 1, {"right": True}),
        "from_rest_hold_left": (0, -1, {"left": True}),
        "full_speed_right_release": (cap, 1, {}),
        "full_speed_left_release": (-cap, -1, {}),
        "full_speed_right_hold_left": (cap, 1, {"left": True}),
        "full_speed_right_hold_right": (cap, 1, {"right": True}),
        "full_speed_left_hold_left": (-cap, -1, {"left": True}),
        "from_rest_hold_up_and_right": (0, 1, {"right": True, "up": True}),
        "full_speed_right_hold_up_and_right": (cap, 1, {"right": True, "up": True}),
        "full_speed_left_hold_up_and_left": (-cap, -1, {"left": True, "up": True}),
    }
    for name, (xv, f, keys) in cases.items():
        h = airborne_hero(xv, f)
        rows = run(h, hold(**keys), 10)
        out[name] = {"xvel_after_tick": col(rows, "xvel"), "x": col(rows, "x")}
    return out


def sc_thrown():
    """Thrown weapons (8.4): per-tick displacement after the spawn tick; x is mirrored when facing left."""
    out = {}
    for name, yv0, dyv in (("axe", -64, 32), ("swirling_axe", -32, -16)):
        yv, dx, dy = yv0, [], []
        for _ in range(12):
            dx.append(floor16(208))
            dy.append(floor16(yv))
            yv += dyv
        out[name] = {"xvel": 208, "yvel_start": yv0, "yvel_change_per_tick": dyv, "dx_per_tick": dx,
                     "dy_per_tick": dy, "spawn_offset_from_reference": [floor16(208), floor16(yv0)]}
    out["max_in_flight"] = 4
    return out


KEYMAP = {"L": "left", "R": "right", "U": "up", "D": "down", "F": "fire"}


def script_from_runs(runs):
    """runs = [[ticks, "RU"], ...] -> (script(t), total ticks)."""
    seq = []
    for n, keys in runs:
        seq.extend([Inp(**{KEYMAP[k]: True for k in keys})] * n)
    return (lambda t: seq[t - 1]), len(seq)


TRACE_DEFS = {
    "walk_jump_reverse": {
        "world": {"type": "flat", "ground_row": GROUND_ROW},
        "inputs": [[10, "R"], [12, "RU"], [16, "R"], [12, "L"], [4, "LU"], [20, "L"], [10, ""]],
    },
    "strike_mix": {
        "world": {"type": "flat", "ground_row": GROUND_ROW},
        "inputs": [[9, "F"], [3, ""], [8, "D"], [12, "DF"], [6, ""], [12, "UF"], [5, "R"], [9, "RF"],
                   [6, "RU"], [10, "RUF"], [14, ""]],
    },
    "crawl_and_tap_jumps": {
        "world": {"type": "flat", "ground_row": GROUND_ROW},
        "inputs": [[8, "RD"], [6, "R"], [1, "RU"], [14, "R"], [3, "LU"], [20, "L"], [6, "LD"], [5, "LR"],
                   [10, ""]],
    },
    "ledge_drop_4_tiles": {
        "world": {"type": "ledge", "edge_col": 64, "drop_tiles": 4, "upper_row": GROUND_ROW},
        "inputs": [[14, "R"], [10, ""], [6, "L"], [12, "RU"], [8, ""]],
    },
    "ledge_drop_12_tiles_air_control": {
        "world": {"type": "ledge", "edge_col": 64, "drop_tiles": 12, "upper_row": GROUND_ROW},
        "inputs": [[9, "R"], [6, "L"], [5, "RU"], [10, "R"], [14, ""]],
    },
}


def sc_traces():
    """Golden traces: feed the same inputs to the Godot hero and compare the full state after every tick."""
    out = {"_format": ("inputs_run_length = [ticks, keys], keys from L R U D F. Arrays hold the ABSOLUTE state at "
                       "the end of each tick (y axis down, tile 16 px). World 'flat': every tile with row >= "
                       "ground_row is solid ground (FLOOR 1, SIDE 1). World 'ledge': solid ground from upper_row "
                       "down for col < edge_col and from upper_row + drop_tiles down for col >= edge_col (the cliff "
                       "face is a wall). No ceilings, slopes, wind or enemies. state = state number selected by "
                       "the table of PHYSICS.md 4.3 after overrides 1-2; handler = handler that actually ran (0 "
                       "idle, 1 walk, 2 jump, 3/6/7 strike, 4 crawl, 5 crouch, 8 hurt); counters are the values "
                       "after the timer step; club_box_frame = frame of the club box created on that tick ('' = "
                       "none).")}
    for name, d in TRACE_DEFS.items():
        wd = d["world"]
        if wd["type"] == "flat":
            w = flat_world(wd["ground_row"])
        else:
            w = ledge_world(wd["edge_col"], wd["drop_tiles"], wd["upper_row"])
        h = Hero(w)
        script, n = script_from_runs(d["inputs"])
        keys = ("x", "y", "xvel", "yvel", "state", "handler", "facing", "fall_ticks", "no_jump", "jump_ticks",
                "swing_lock", "charge")
        tr = {k: [] for k in keys}
        tr["grounded"], tr["club_box_frame"] = [], []
        for t in range(1, n + 1):
            h.tick(script(t))
            for k in keys:
                tr[k].append(getattr(h, k))
            tr["grounded"].append(1 if h.grounded else 0)
            tr["club_box_frame"].append(h.club_box["frame"] if h.club_box else "")
        out[name] = {"world": wd, "start": {"x": START_X, "y": GROUND_ROW * 16, "facing": 1},
                     "inputs_run_length": d["inputs"], "ticks": n, **tr}
    return out


# ---------------------------------------------------------------------------------------------------------------
# Build + self-check
# ---------------------------------------------------------------------------------------------------------------

def build() -> dict:
    hz = TICK_HZ
    ref = {
        "meta": {
            "title": "Club & Grub - hero physics reference values",
            "generated_by": "docs/spec/reference_sim.py",
            "spec": "docs/spec/PHYSICS.md",
            "tick_hz": round(hz, 6),
            "tick_dt_ms": round(1000.0 / hz, 6),
            "tick_dt_s": round(1.0 / hz, 9),
            "tick_hz_derivation": "1193182 Hz / 16384 (timer reload) / 3 (timer ticks per frame)",
            "tick_hz_status": ("nominal rate of the original frame governor; the rate on real 1993 hardware is "
                               "not verifiable, so TICK_HZ must stay one tunable project constant. Every other "
                               "value in this file is in ticks / px / v16 and does not depend on it."),
            "tick_hz_of_other_ports": {"pre2_port_native_runner": round(70.0 / 3.0, 4), "blues": round(1000.0 / 33.0, 3)},
            "source_disagreements": ("where the two reference sources disagree the rules follow pre2_port "
                                     "(PHYSICS.md 14.1), e.g. the unsigned xvel test of the jump handler, which "
                                     "gives 5 px/tick when jumping left with UP held"),
            "units": {
                "tick": "one simulation step (1 / tick_hz seconds)",
                "px": "logical pixel of the 320x200 screen; tile = 16 px",
                "v16": "velocity in 1/16 px per tick; position += v16 >> 4 (floor), no sub-pixel",
                "height": "px above the take-off point, positive up (world y axis points down)",
                "x": "px relative to the start position, positive right",
            },
            "conventions": {
                "tick_numbering": "tick 1 is the first tick on which the described input is held",
                "arrays": "element i is the value at the END of tick i+1",
                "landing_tick": "tick on which the feet are snapped back onto a floor",
                "airborne_ticks": "landing_tick - 1",
                "world": "flat floor, no wind, ice 0 unless a scenario says otherwise",
            },
            "px_per_second_per_px_per_tick": round(hz, 4),
            "px_per_second_per_v16": round(hz / 16.0, 4),
            "px_per_second2_per_v16_per_tick": round(hz * hz / 16.0, 3),
        },
        "constants": C,
        "state_table": {"index": "RIGHT<<4 | LEFT<<3 | UP<<2 | DOWN<<1 | FIRE", "lut": STATE_LUT,
                        "names": {str(k): v for k, v in STATE_NAME.items()}},
        "walk": sc_walk(),
        "stop": sc_stop(),
        "reverse": sc_reverse(),
        "crawl": sc_crawl(),
        "ice": sc_ice(),
        "standing_jump_hold_up": sc_standing_jump(),
        "variable_jump": sc_variable_jump(),
        "running_jump": sc_running_jump(),
        "fall": sc_free_fall(),
        "impulse_rise": sc_impulses(),
        "hurt": sc_hurt(),
        "attack": sc_attack(),
        "jump_lockout": sc_lockout(),
        "air_control": sc_air_control(),
        "thrown_weapons": sc_thrown(),
        "collision": sc_collision(),
        "camera": sc_camera(),
        "traces": sc_traces(),
    }
    hz_r = ref["meta"]["tick_hz"]
    ref["headline"] = {
        "tick_hz": hz_r,
        "walk_top_speed_px_per_tick": 5, "walk_top_speed_px_per_s": round(5 * hz, 1),
        "ticks_to_top_speed": ref["walk"]["right"]["ticks_to_top_speed"],
        "px_to_top_speed": ref["walk"]["right"]["px_to_top_speed"],
        "stop_distance_px_right": ref["stop"]["right"]["distance_px"],
        "stop_distance_px_left": ref["stop"]["left"]["distance_px"],
        "stop_ticks": ref["stop"]["right"]["ticks_until_xvel_zero"],
        "jump_apex_px_hold": ref["standing_jump_hold_up"]["apex_px"],
        "jump_airborne_ticks_hold": ref["standing_jump_hold_up"]["airborne_ticks"],
        "jump_airtime_s_hold": round(ref["standing_jump_hold_up"]["airborne_ticks"] / hz, 3),
        "jump_apex_px_tap": ref["variable_jump"]["up_held_1_ticks"]["apex_px"],
        "jump_apex_px_max": max(v["apex_px"] for k, v in ref["variable_jump"].items() if k.startswith("up_held")),
        "running_jump_px_hold_right": ref["running_jump"]["hold_up_right"]["distance_px"],
        "running_jump_px_hold_left": ref["running_jump"]["hold_up_left"]["distance_px"],
        "running_jump_px_release9_right": ref["running_jump"]["release_up_after_9_right"]["distance_px"],
        "running_jump_px_release9_left": ref["running_jump"]["release_up_after_9_left"]["distance_px"],
        "terminal_px_per_tick": C["terminal"] >> 4, "terminal_px_per_s": round((C["terminal"] >> 4) * hz, 1),
        "fall_4_tiles_landing_tick": ref["fall"]["by_drop_tiles"]["4"]["landing_tick"],
        "strike_forward_ticks": ref["attack"]["forward"]["length_ticks"],
        "strike_forward_front_box_ticks": ref["attack"]["forward"]["front_box_created_on_ticks"],
        "hurt_stun_ticks": ref["hurt"]["standing"]["stun_ticks"],
        "hurt_contact_immunity_ticks": ref["hurt"]["immune_contact_passes"],
    }
    return ref


def self_check(ref: dict) -> list:
    """Hand-derived anchors (PHYSICS.md sections 5.3, 6.4, 6.5, 8.1, 10.1). Returns a list of failures."""
    fails = []

    def eq(name, got, want):
        if got != want:
            fails.append(f"{name}: got {got!r}, expected {want!r}")

    eq("floor16(-1)", floor16(-1), -1)
    eq("floor16(-68)", floor16(-68), -5)
    eq("floor16(68)", floor16(68), 4)
    eq("walk right x", ref["walk"]["right"]["x"][:6], [1, 3, 6, 10, 15, 20])
    eq("walk left x", ref["walk"]["left"]["x"][:6], [-1, -3, -6, -10, -15, -20])
    eq("stop right x", ref["stop"]["right"]["x"][:7], [4, 7, 9, 11, 12, 12, 12])
    eq("stop left x", ref["stop"]["left"]["x"][:7], [-5, -9, -12, -14, -16, -17, -17])
    eq("reverse x", ref["reverse"]["from_right"]["x"][:10], [4, 7, 9, 10, 10, 9, 7, 4, 0, -5])
    j = ref["standing_jump_hold_up"]
    eq("jump height", j["height"], [5, 12, 20, 28, 36, 43, 49, 54, 58, 60, 60, 59, 57, 54, 50, 45, 39, 32, 24, 15, 5, 0])
    eq("jump yvel", j["yvel_after_tick"][:11], [-49, -84, -103, -107, -101, -90, -76, -61, -45, -13, 19])
    eq("jump landing tick", j["landing_tick"], 22)
    eq("fall per tick", ref["fall"]["per_tick_fall_px"][:15], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 12])
    eq("impulse rises", {k: v["rise_px"] for k, v in ref["impulse_rise"].items()},
       {"-32": 3, "-48": 6, "-64": 10, "-80": 15, "-96": 21, "-128": 36, "-144": 45, "-160": 55, "-224": 105})
    eq("strike lengths", [ref["attack"][k]["length_ticks"] for k in ("forward", "high", "low")], [7, 9, 9])
    eq("cam v table length", len(ref["camera"]["vertical_speed_px_per_tick_by_distance"]), 132)
    eq("cam v fast table", (len(ref["camera"]["vertical_speed_px_per_tick_by_distance_backdrop_visible"]),
                            sum(ref["camera"]["vertical_speed_px_per_tick_by_distance_backdrop_visible"])),
       (132, 1632))
    eq("cam v table sum", sum(ref["camera"]["vertical_speed_px_per_tick_by_distance"]), 964)
    eq("tick hz", round(TICK_HZ, 3), 24.275)
    return fails


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "PHYSICS_REFERENCE.json"))
    ap.add_argument("--print", action="store_true", help="dump the JSON to stdout")
    args = ap.parse_args(argv)
    ref = build()
    fails = self_check(ref)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(ref, f, indent=1)
        f.write("\n")
    if args.print:
        json.dump(ref, sys.stdout, indent=1)
        print()
    print(f"wrote {args.out}")
    for k, v in ref["headline"].items():
        print(f"  {k}: {v}")
    if fails:
        print("SELF-CHECK FAILED:")
        for m in fails:
            print("  " + m)
        return 1
    print("self-check: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
