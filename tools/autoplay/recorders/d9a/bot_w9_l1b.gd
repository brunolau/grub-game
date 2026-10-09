extends "res://tools/autoplay/recorders/d9a/botlib.gd"
## The Expert club route of w9_l1b Thunderhead Glide (D9a), recorded by probe_work.gd --bot.
## The glider is flown by a closed loop (player.gd _steer_glider): hold the flight direction; to hold a target height
## that depends on x, climb with UP while there is lift (4 px per tick once the nose is up), then dive with DOWN while
## still rising (the dive's full gravity first eats the climb) until the lift is refilled (5 per tick at full speed,
## up to 5 x the speed), and glide (neutral, 1 px per tick down) while above the target.


func header() -> String:
	return "# route: level=w9_l1b difficulty=expert ends=exit after=tally expect=hurts:0,min_checkpoints:2,painting:13,glider:true\n" \
		+ "# The Expert club route of Thunderhead Glide (designer D9a; recorded from closed-loop macros, build/d9a): the\n" \
		+ "# glider from the runway, the first crossing high over the storm pterodactyls past the lightning, checkpoint 2 on\n" \
		+ "# the landing cloud, a run-up and a climb on lift to the high cloud of the Cave Painting (index 13), off its edge\n" \
		+ "# into the second crossing to the last landing cloud and the exit totem (no hit taken).\n"


## Target feet y (px) along x: [[x, y], ...] (linear in between).
func _target_y(plan: Array, x: int, dir: int) -> int:
	var pts: Array = plan
	var prev: Array = pts[0]
	if (x - int(prev[0])) * dir <= 0:
		return int(prev[1])
	for point: Array in pts:
		if (x - int(point[0])) * dir <= 0:
			var t: float = float(x - int(prev[0])) / float(int(point[0]) - int(prev[0])) if point[0] != prev[0] else 1.0
			return int(lerpf(float(prev[1]), float(point[1]), t))
		prev = point
	return int(prev[1])


## Fly while gliding until the hero stands again.
func fly_fn(plan: Array, dir: int = 1, land: Vector2i = Vector2i(-1, -1)) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var gliding: bool = int(h.get(&"glide")) & 1 != 0
		if n > 3 and h.is_grounded() and not gliding:
			return -1
		if n > 3000:
			return -1
		var move: int = R if dir > 0 else L
		if not gliding:
			return move
		if land.x >= 0 and h.sim_pos.x >= land.x and h.sim_pos.x <= land.y:
			# over the landing: dive onto it
			return move | D
		var lift: int = int(h.get(&"glider_lift"))
		var speed: int = absi(h.xvel) >> 4
		var full: int = maxi(1, mini(20, speed * 5))
		var err: int = h.sim_pos.y - _target_y(plan, h.sim_pos.x, dir)
		var mode: String = str(st.get("mode", "glide"))
		match mode:
			"climb":
				if lift <= 0:
					mode = "dive" if err > -40 else "glide"
				elif err < 0:
					mode = "glide"
			"dive":
				if lift >= full:
					mode = "climb" if err > -8 else "glide"
				elif err < -48:
					mode = "glide"
			_:
				if err > 16:
					mode = "climb" if lift > 6 else "dive"
		st["mode"] = mode
		if mode == "climb":
			return move | U
		if mode == "dive":
			return move | D
		return move


## Walk carrying the glider and take off once the run-up counts (24 ticks at speed).
func takeoff_fn(dir: int = 1) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var move: int = R if dir > 0 else L
		if int(h.get(&"glide")) & 1 != 0:
			return -1
		if n > 400:
			return -1
		if int(h.get(&"glider_runup")) >= 24 and h.is_grounded():
			return move | U
		return move


func build() -> Array:
	var f: Dictionary = {"fight": true}
	var p: Array = []
	# the runway: the glider, checkpoint 1, take off
	p.append(["go", cx(10), f])
	p.append(["go", cx(3), f])
	p.append(["fn", takeoff_fn()])
	p.append(["fn", fly_fn([[300, 120], [1300, 110], [1450, 130], [1560, 150]], 1, Vector2i(1570, 1860))])
	# the landing cloud: checkpoint 2, run-up, climb to the high cloud
	p.append(["go", cx(97), f])
	p.append(["fn", takeoff_fn()])
	p.append(["fn", fly_fn([[1750, 100], [2000, 10], [2170, 10]], 1, Vector2i(2186, 2250))])
	p.append(["go", cx(139), f])
	# off the high cloud's edge into the second crossing
	p.append(["run", cx(143)])
	p.append(["fn", fly_fn([[2300, 110], [2900, 130], [3000, 160]], 1, Vector2i(3070, 3700))])
	p.append(["go", cx(239), f])
	p.append(["hold", R])
	return [p]
