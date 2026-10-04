class_name ArenaZone
extends ZoneBase
## `zones/arena` (ARCHITECTURE.md 6.2, 7.7): a boss room. When the hero's feet enter it while a living boss whose
## `arena` parameter equals this zone's `name` exists, the camera is locked to the rectangle and the fight starts
## (BossBase.start_fight: energy bar and boss music). The boss releases the lock when it is defeated; a respawn
## releases it too, and the fight starts again when the hero comes back. Owner: world.
##
## Parameters: `rect`, `name`, `music` (a Sfx music context; when given it replaces the boss's own fight music).

## Music context of the fight when the level file names one (&"" = the boss's own choice).
var music: StringName = &""


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	music = StringName(str(params.get("music", "")))


func _on_hero_entered(level: LevelBase, _hero: PlayerBase) -> void:
	var bosses: Array[SimEntity] = level.get_kind(Defs.Kind.BOSS)
	var started: bool = false
	for i: int in bosses.size():
		var boss: BossBase = bosses[i] as BossBase
		if boss == null or boss.dead or boss.arena != zone_name or zone_name == &"":
			continue
		if not started:
			level.lock_camera(rect)
			started = true
		if music != &"" and AudioTable.MUSIC.has(music):
			boss.music = music
		boss.start_fight()
