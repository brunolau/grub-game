class_name CameraLockZone
extends ZoneBase
## `zones/camera_lock` (PHYSICS.md 12.4): while the hero's feet are inside, the camera stays inside the
## rectangle (a rectangle no larger than the view fixes the screen). Leaving it releases the lock, unless
## something else locked the camera meanwhile. Owner: world. Parameters: `rect`, `name`.


func _on_hero_entered(level: LevelBase, _hero: PlayerBase) -> void:
	level.lock_camera(rect)


func _on_hero_exited(level: LevelBase, _hero: PlayerBase) -> void:
	if level.is_camera_locked() and level.get_camera_lock() == rect:
		level.unlock_camera()
