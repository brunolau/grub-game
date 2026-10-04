class_name Jackpot
extends GiantBonus
## `items/jackpot`: the treasure chest worth 100 000 points that drops from above the hero when the bonus word
## G-R-U-B-S is completed (GAMEPLAY.md 4.3). It falls and bounces off the hero like a giant bonus and never blinks
## away.


func _init() -> void:
	super()
	item_id = &"items/jackpot"
	expires = false
	set_box(Vector3i(24, 18, 12))


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	if not params.has("points"):
		points = Tuning.LETTERS_JACKPOT


func _update_look() -> void:
	show_cell(0)
