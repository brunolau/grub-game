extends SceneTree
## Scratch micro benchmark of GDScript costs that matter for the tick loop (development only).

class E:
	extends Node2D
	var sim_active: bool = true
	var sim_pos: Vector2i = Vector2i.ZERO
	var on_screen: bool = false
	var box_w: int = 16
	var box_h: int = 16
	var box_xo: int = 8

	func tick(_phase: int) -> void:
		pass

	func tick_body(_phase: int) -> void:
		if not sim_active:
			return
		var level: Object = null
		if level != null:
			return


func _initialize() -> void:
	var list: Array = []
	for i: int in 200:
		var e: E = E.new()
		e.sim_active = false
		list.append(e)
	var n: int = 2000
	var start: int = Time.get_ticks_usec()
	for r: int in n:
		var count: int = list.size()
		for i: int in count:
			var entity: E = list[i]
			if entity != null and entity.sim_active:
				entity.tick(1)
	var skip_us: float = float(Time.get_ticks_usec() - start) / float(n * 200)
	for e: E in list:
		e.sim_active = true
	start = Time.get_ticks_usec()
	for r: int in n:
		var count: int = list.size()
		for i: int in count:
			var entity: E = list[i]
			if entity != null and entity.sim_active:
				entity.tick(1)
	var call_us: float = float(Time.get_ticks_usec() - start) / float(n * 200)
	start = Time.get_ticks_usec()
	for r: int in n:
		var count: int = list.size()
		for i: int in count:
			var entity: E = list[i]
			if entity != null and entity.sim_active:
				entity.tick_body(1)
	var body_us: float = float(Time.get_ticks_usec() - start) / float(n * 200)
	# on_screen pass shape
	start = Time.get_ticks_usec()
	var left: int = 0
	var right: int = 320
	var top: int = 0
	var bottom: int = 180
	for r: int in n:
		for entity: E in list:
			var feet: Vector2i = entity.sim_pos
			var box_left: int = feet.x - entity.box_xo
			entity.on_screen = box_left < right and left < box_left + entity.box_w \
					and feet.y - entity.box_h < bottom and top < feet.y
	var screen_us: float = float(Time.get_ticks_usec() - start) / float(n * 200)
	# packed array scan
	var xs: PackedInt32Array = PackedInt32Array()
	xs.resize(200)
	start = Time.get_ticks_usec()
	var hits: int = 0
	for r: int in n:
		for i: int in 200:
			if xs[i] > 5000:
				hits += 1
	var scan_us: float = float(Time.get_ticks_usec() - start) / float(n * 200)
	print("per entity: skipped by flag %.3f us, empty call %.3f us, call with tiny body %.3f us, on_screen %.3f us, packed scan %.3f us" % [
		skip_us, call_us, body_us, screen_us, scan_us])
	for e: E in list:
		e.free()
	quit(0)
