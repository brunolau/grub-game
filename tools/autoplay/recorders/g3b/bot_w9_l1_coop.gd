extends "res://tools/autoplay/recorders/d9a/bot_w9_l1_coop.gd"
## G3b integrator (wf10): D9a's two-stream bot of w9_l1_coop with one repair of its geyser "ride" macro.
## The macro ends when the hero "stands again higher than he started" and takes the start height on its first tick;
## when the sync before it releases while the geyser already has him in the air (the pulley gate's new timing does
## that at shelf CP5), the start height was his height in the air and the macro then waited out its 600-tick limit
## standing on the landing shelf - 427 ticks without input, which the idle rule of the route proofs refuses
## (LEVEL_DESIGN 15.7.9); here P1 stood on P2's head over the vent when it began. The start height is now the floor
## under him whenever he is in the air or on his partner.


func _run(s: int, cmd: Array) -> int:
	if str(cmd[0]) == "ride" and not _st[s].has("y0"):
		var h: PlayerBase = hero(s)
		var y0: int = h.sim_pos.y
		var other: PlayerBase = hero(1 - s)
		var gap: int = other.sim_pos.y - h.sim_pos.y if other != null else 0
		var on_partner: bool = other != null and absi(other.sim_pos.x - h.sim_pos.x) <= 20 and gap >= 16 and gap <= 56
		if not h.is_grounded() or on_partner:
			var col: int = h.sim_pos.x >> 4
			var row: int = h.sim_pos.y >> 4
			while row < level.grid.rows and not TileGrid.is_ground(level.grid.floor_at(col, row)):
				row += 1
			y0 = row * 16
		_st[s]["y0"] = y0
		print("RIDE t=%d P%d starts at %s grounded %s: floor %d" % [t, s + 1, h.sim_pos, h.is_grounded(), y0])
	return super._run(s, cmd)
