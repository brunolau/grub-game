class_name Bone
extends CollectibleBase
## `items/bone`: an energy fragment. Six bones restore one heart (GAMEPLAY.md 4.2). Bones fly out of enemies that
## stole a heart and out of the hero when a skull or a boss hits him; they spin while they fly.
## 2.0 co-op (GAMEPLAY.md 13.9.2): a bone picked up at full energy flies to the partner when he is below full energy
## (the first such hatched hero in slot order); otherwise it goes to the collector as in 1.0.

const SPIN_FRAMES: int = 4
const ID_STAR_PUFF: StringName = &"fx/star_puff"


func _init() -> void:
	super()
	item_id = &"items/bone"
	set_box(Vector3i(12, 12, 6))


func _apply(hero: PlayerBase) -> bool:
	# The collector's own energy (2.0: his PlayerRun; P1's run is Game's, so Game.add_bones() in 1.0).
	var target: PlayerBase = hero
	var level: LevelBase = Game.level
	if ObjTuning.coop_rules(level) and hero.run.is_full_energy():
		# The PartyDriver (world-A) gives it to a partner below full energy (and shows his pop-up); without a driver
		# the first such partner in slot order gets it here.
		var driver: SimEntity = level.party_driver
		if driver != null and driver.has_method(&"bones_to_partner"):
			if int(driver.call(&"bones_to_partner", hero, 1)) > 0:
				Audio.play_sfx(Sfx.HEART)
				return true
		else:
			var partner: PlayerBase = partner_below_full(level, hero)
			if partner != null:
				target = partner
				level.spawn_fx(ID_STAR_PUFF, Vector2i(partner.sim_pos.x, partner.sim_pos.y - (partner.box_h >> 1)))
	if target.run.add_bones(1) > 0:
		Audio.play_sfx(Sfx.HEART)
		var at: Vector2i = Vector2i(sim_pos.x, sim_pos.y - box_h) if target == hero \
				else Vector2i(target.sim_pos.x, target.sim_pos.y - target.box_h)
		Events.popup_requested.emit(&"heart", 1, at)
	return true


## The first hatched hero of the party other than `hero` whose energy is below full, or null.
static func partner_below_full(level: LevelBase, hero: PlayerBase) -> PlayerBase:
	if level == null:
		return null
	for other: PlayerBase in level.contact_order():
		if other != hero and other.is_party_targetable() and not other.run.is_full_energy():
			return other
	return null


func _move_tick() -> void:
	super._move_tick()
	if dropped and not resting:
		show_cell(ObjTuning.anim_frame(age, ObjTuning.BONE_SPIN_FPS) % SPIN_FRAMES)


func _update_look() -> void:
	show_cell(0)
