class_name CameraLockZone
extends ZoneBase
## `zones/camera_lock` (PHYSICS.md 12.4): while the hero's feet are inside, the camera stays inside the
## rectangle (a rectangle no larger than the view fixes the screen). Leaving it releases the lock, unless
## something else locked the camera meanwhile. Owner: world. Parameters: `rect`, `name`.
## A party shares the one camera: the first hero in locks it, the last one out releases it; in co-op the lock takes
## the whole party (PHYSICS.md C.13: every other hero outside the rectangle is pulled in behind the first,
## LevelBase.pull_party_into).


func _on_first_entered(level: LevelBase, hero: PlayerBase) -> void:
	level.lock_camera(rect)
	level.pull_party_into(rect, hero)


func _on_last_exited(level: LevelBase, _hero: PlayerBase) -> void:
	if level.is_camera_locked() and level.get_camera_lock() == rect:
		level.unlock_camera()
