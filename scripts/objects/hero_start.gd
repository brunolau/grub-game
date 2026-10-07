class_name HeroStart
extends SimEntity
## `objects/hero_start slot=<2..4>` (DESIGN.md D.5): where player `slot` (counted from 1, as the level files write it)
## starts in a co-op file. A marker of the level loader: Level._place_party_starts reads its cell into
## LevelBase.start_positions and the loader never spawns it; a single-player game ignores it. The scene exists for the
## level preview and editor tools (ASSET_MANIFEST: hero_start, frame = slot - 1, the slot digit in the player's
## colour) and so that `Spawner.exists` knows the id. Spawned anyway (by a tool), it takes no phase and does nothing.

## Player number 2..Defs.MAX_PLAYERS (`slot`); the hero of player slot `slot - 1` starts here.
var slot: int = 2


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	set_box(Vector3i(16, 16, 8))


func _apply_params(params: Dictionary) -> void:
	slot = clampi(int(params.get("slot", slot)), 2, Defs.MAX_PLAYERS)
	var sprite: Sprite2D = get_node_or_null(^"Sprite") as Sprite2D
	if sprite != null:
		sprite.frame = clampi(slot - 1, 0, sprite.hframes - 1)
