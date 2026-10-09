extends "res://tools/autoplay/recorders/db2/bot_w2_l2_coop.gd"
## enemies-A (wf10, G57): DB2's w2_l2_coop bot with one change - in a Shellback pincer the striker keeps striking its
## back until it is dead (up to 8 strikes instead of 3): with one hit per strike in co-op files three strikes no longer
## take its hit points, and the bot waited forever under the Harriers. Every other macro is DB2's.


func pincer(bait: Array, striker: Array, x: int, y: int) -> void:
	bait.append(["go", x - 90, {"tol": 2}])
	striker.append(["go", x - 60, {"tol": 2}])
	striker.append(["fn", hop_fn(x + 31, 12)])
	striker.append(["go", x + 31, {"tol": 1}])
	striker.append(["face", -1])
	striker.append(["sync", "behind%d" % x])
	bait.append(["sync", "behind%d" % x])
	bait.append(["go", x - 26, {"tol": 1}])
	bait.append(["face", 1])
	striker.append(["sync", "pincer%d" % x])
	bait.append(["sync", "pincer%d" % x])
	for k: int in 8:
		striker.append(["fn", strike_unless_dead_fn(x, y)])
	striker.append(["until", until_dead_fn(x, y), 0])
