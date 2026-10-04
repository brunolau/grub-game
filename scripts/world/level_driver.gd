class_name LevelDriver
extends SimEntity
## The level's own slot in the simulation (ARCHITECTURE.md 4.2): the world module's work in the phases WORLD
## (wind script, darkness fade), CAMERA (camera follow) and POST (time limit, respawn curtain). Owner: world.
##
## The level is not a SimEntity itself, so it adds one of these as its first child: being registered first, the
## level's steps run before every entity's steps of the same phase. Invisible, never on screen.

var _world_step: Callable = Callable()
var _camera_step: Callable = Callable()
var _post_step: Callable = Callable()


func _init() -> void:
	set_box(Vector3i.ZERO)
	visible = false


## Connect the three phase steps (called by the level before the driver enters the tree).
func setup(world_step: Callable, camera_step: Callable, post_step: Callable) -> void:
	_world_step = world_step
	_camera_step = camera_step
	_post_step = post_step


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.WORLD, Defs.Phase.CAMERA, Defs.Phase.POST])


func _sim_tick(phase: int) -> void:
	match phase:
		Defs.Phase.WORLD:
			if _world_step.is_valid():
				_world_step.call()
		Defs.Phase.CAMERA:
			if _camera_step.is_valid():
				_camera_step.call()
		Defs.Phase.POST:
			if _post_step.is_valid():
				_post_step.call()
