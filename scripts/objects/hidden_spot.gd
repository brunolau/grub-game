class_name HiddenSpot
extends SceneryHittable
## `objects/hidden_spot` (GAMEPLAY.md 4.4, ARCHITECTURE.md 7.7): a cell that looks like ordinary scenery until
## the club or a thrown weapon hits it.
##
## Parameters: `kind=small|big` [small]; small: `count` 1..64 [3] items thrown out, one per hit (at most one every
## Tuning.HIDDEN_SPOT_HIT_COOLDOWN ticks); big: `hits` 1..128 [3], the hits only puff, then one giant bonus falls
## from Tuning.GIANT_BONUS_DROP_PX above the spot; `contents` [random] (cycled for a small spot, all of them
## dropped for a big one; `random` = a random bonus of the level's tier, or a random giant bonus for a big spot);
## `look=plain|inset|block` [plain] for solid cells; `prop=<biome>/<name>` picture for air cells.
## Used up, it opens every hidden cell that touches it (flood fill in HittableBase).

const KIND_SMALL: StringName = &"small"
const KIND_BIG: StringName = &"big"
const DEFAULT_COUNT: int = 3
const MAX_COUNT: int = 64
const MAX_BIG_HITS: int = 128
const LOOKS: Dictionary = {
	"plain": ObjTuning.ATLAS_AUTO, "inset": ObjTuning.ATLAS_INSET, "block": ObjTuning.ATLAS_BLOCK,
}
const ID_STAR_PUFF: StringName = &"fx/star_puff"
## Props that hang from a ceiling are anchored top-centre at the top of their cell (ARCHITECTURE.md 7.5).
const CEILING_PROPS: Array[String] = ["stalactite", "drips", "drip_cap", "icicle", "vine_a", "vine_b", "moss_fringe"]

## What it throws out / drops.
var contents: ItemContents = null
## Atlas tile drawn on the cell until it is opened (ObjTuning.ATLAS_AUTO = ordinary terrain).
var look: int = ObjTuning.ATLAS_AUTO
## Items thrown out so far (small spot).
var thrown: int = 0

var _prop: Sprite2D = null


func _init() -> void:
	super()
	joins_flood = true


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	if spot_kind != KIND_BIG:
		spot_kind = KIND_SMALL
		hits_left = clampi(int(params.get("count", DEFAULT_COUNT)), 1, MAX_COUNT)
	else:
		hits_left = clampi(int(params.get("hits", DEFAULT_COUNT)), 1, MAX_BIG_HITS)
	hits_total = hits_left
	var random_item: String = "giant_bonus" if spot_kind == KIND_BIG else "random_bonus"
	var contents_text: String = str(params.get("contents", ItemContents.TOKEN_RANDOM))
	contents = ItemContents.parse(contents_text, random_item)
	if contents.is_empty() and contents_text != ItemContents.TOKEN_NONE:
		contents = ItemContents.parse(ItemContents.TOKEN_RANDOM, random_item)
	look = int(LOOKS.get(str(params.get("look", "plain")), ObjTuning.ATLAS_AUTO))
	_prop = get_node_or_null(^"Sprite") as Sprite2D
	if _prop != null:
		_prop.texture = null
		if params.has("prop"):
			_set_prop(str(params["prop"]))


func _ready() -> void:
	if look != ObjTuning.ATLAS_AUTO and Game.level != null and not opened:
		Game.level.set_cell_look(cell.x, cell.y, look)


func _on_hit(_power: int, _source: SimEntity) -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	wobble(_prop)
	spray(level_debris_kind(), ObjTuning.SPOT_HIT_DEBRIS, get_hit_point())
	if spot_kind == KIND_SMALL:
		_throw_one(level)


func _on_opened() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	if look != ObjTuning.ATLAS_AUTO:
		level.set_cell_look(cell.x, cell.y, ObjTuning.ATLAS_AUTO)
	spray(level_debris_kind(), ObjTuning.SPOT_OPEN_DEBRIS, get_hit_point())
	if spot_kind == KIND_BIG and not opened_by_flood:
		_drop_from_sky(level)


## 2.0 versus refill (HittableBase.refill): the items start again from the first token, the inset / block look is back.
func _on_refilled() -> void:
	thrown = 0
	if look != ObjTuning.ATLAS_AUTO and Game.level != null:
		Game.level.set_cell_look(cell.x, cell.y, look)
	if Game.level != null:
		Game.level.spawn_fx(ID_STAR_PUFF, get_hit_point())


## One item out of a small spot: the next token of the contents, thrown away from the strike.
func _throw_one(level: LevelBase) -> void:
	var out: Vector4i = emerge(strike_dir * ObjTuning.SPOT_THROW_XVEL, ObjTuning.SPOT_THROW_YVEL)
	var at: Vector2i = Vector2i(out.x, out.y)
	contents.spawn(level, thrown, at, out.z, out.w)
	thrown += 1
	level.spawn_fx(ID_POOF, Vector2i(at.x, at.y - Tuning.TILE / 2))


## The reward of a big spot: every token of the contents falls from high above the spot.
func _drop_from_sky(level: LevelBase) -> void:
	var x: int = cell.x * Tuning.TILE + Tuning.TILE / 2
	var y: int = ItemEffects.sky_drop_y(x, cell.y * Tuning.TILE)
	var count: int = contents.size()
	for i: int in count:
		contents.spawn(level, i, Vector2i(x, y), (i - (count >> 1)) * ObjTuning.SKY_DROP_XVEL_STEP, 0)
	level.spawn_fx(ID_STAR_PUFF, Vector2i(x, y - Tuning.TILE))
	Audio.play_sfx(Sfx.GIANT_BONUS)


func _set_prop(prop: String) -> void:
	var path: String = Spawner.prop_texture_path(StringName("props/" + prop))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("objects/hidden_spot: unknown prop '%s'" % prop)
		return
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return
	_prop.texture = texture
	_prop.hframes = 1
	_prop.vframes = 1
	var size: Vector2 = texture.get_size()
	var half_w: float = floorf(size.x * 0.5)
	if CEILING_PROPS.has(prop.get_file()):
		# Hangs from the top of the cell: the feet point is the cell bottom, the cell top is one tile higher.
		_prop.offset = Vector2(-half_w, -float(Tuning.TILE_ART))
	else:
		_prop.offset = Vector2(-half_w, -size.y)
