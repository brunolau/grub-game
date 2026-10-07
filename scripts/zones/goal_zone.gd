class_name GoalZone
extends ZoneBase
## `zones/goal rect=c,r,w,h team=1|2` (DESIGN.md E.4 / E.5, LEVEL_DESIGN.md 15.4 / 15.8): a Clubball goal mouth of a
## versus arena - the OWN goal of team `team` (the other team scores in it). Owner: world.
##
## Data only: the zone has no effect on a hero. The coconut asks for the goal its centre is in
## (Coconut.goal_team() reads `spawn_params["team"]` and `rect` of every ZONE entity) and the Clubball referee falls
## back on the file's records (VersusClubball.zones), with the same rectangle - so the scene only gives the record
## an entity (no "no scene" warning on load) and changes no outcome.

## Level-file parameter `team` (1 or 2; 0 when missing).
var team: int = 0


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	team = int(params.get("team", 0))
