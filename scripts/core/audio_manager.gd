extends Node
## Autoload `Audio`: sound effects by event name, music by context (docs/ARCHITECTURE.md 3.9).
##
## CONTRACT FILE. Owner: core. Public methods are frozen.
##
## Bus layout (default_bus_layout.tres): Master <- Music, Master <- SFX <- UI. Volumes are user settings
## ("audio/master", "audio/music", "audio/sfx") applied by Settings. Unlike the original (one channel, a new cue
## cuts the previous one) this is a small mixer (GAMEPLAY.md 12.4). Audio never affects the simulation: calls
## may be made from inside a tick, nothing is ever read back.
##
## push_music() / pop_music() remember where the interrupted track was, so the level music continues after a
## feast or a boss instead of starting over. hold_music() / release_music() (2.0) are the same for music that several
## holders share (the feast music while any hero of a party feasts). set_suspended() halts everything while the
## application is in the background (called by Flow).

## The music context changed ("" = silence).
signal music_changed(context: StringName)

const SFX_VOICES: int = 10
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_started_frame: Dictionary = {}   # event -> frame number it was last started
var _sfx_variant: Dictionary = {}         # event -> next variant index
var _loops: Dictionary = {}               # event -> AudioStreamPlayer
var _streams: Dictionary = {}             # path -> AudioStream (null when missing)
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _music_context: StringName = &""
var _music_stack: Array[StringName] = []
## Parallel to _music_stack: where each interrupted track continues (seconds).
var _music_resume: Array[float] = []
## hold_music(): context -> {holder instance id: true}. Cleared with the stack (play_music, play_jingle, shutdown).
var _music_holds: Dictionary = {}
var _music_after_jingle: StringName = &""
var _fade: Tween = null
var _next_voice: int = 0
## True without an audio device (headless runs: tests, CI, servers): streams are still loaded and all state is
## tracked, but nothing is started, so no playback can outlive a forced exit.
var _silent: bool = false
## True while the application is in the background (set_suspended).
var _suspended: bool = false
# Clock of the current track for silent runs, where no player reports a position.
var _clock_base: float = 0.0     # position when the clock was last started or stopped
var _clock_since_msec: int = -1  # Time.get_ticks_msec() when it was started; -1 = standing still
var _clock_length: float = 0.0   # length of the track (0 = unknown)
var _clock_loops: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	for i: int in SFX_VOICES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	preload_sfx()


func _exit_tree() -> void:
	# Forced exits (window manager kill, --quit-after) arrive here without the grace period of
	# Flow.shutdown_and_quit(): stop everything, then give the audio thread a few mix cycles to release its
	# playbacks so the engine reports no leaked instances.
	var was_audible: bool = _is_anything_playing()
	shutdown()
	if was_audible:
		OS.delay_msec(120)


## Stop every sound and release every stream. Called automatically when the application closes. When quitting
## from code, call it and wait about a quarter of a second before `get_tree().quit()`: the audio thread needs a
## couple of mix cycles to let go of playbacks that were started moments ago (otherwise the engine reports leaks).
func shutdown() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_music_stack.clear()
	_music_resume.clear()
	_music_holds.clear()
	_music_after_jingle = &""
	_music_context = &""
	_suspended = false
	_stop_clock()
	for player: AudioStreamPlayer in _sfx_players:
		player.stop()
		player.stream = null
	for event: StringName in _loops:
		var loop_player: AudioStreamPlayer = _loops[event]
		loop_player.stop()
		loop_player.stream = null
		loop_player.queue_free()
	_loops.clear()
	for player: AudioStreamPlayer in [_music_a, _music_b]:
		if player != null:
			player.stop()
			player.stream = null
	_streams.clear()


## Load every sound effect of AudioTable.SFX now (about 1 MB; called once at boot). Effects are started from inside
## simulation ticks, and loading a file there on first use stalls the tick (a visible hitch on phones).
func preload_sfx() -> void:
	for event: StringName in AudioTable.SFX:
		var entry: Dictionary = AudioTable.SFX[event]
		for file: Variant in entry["files"]:
			_get_stream(AudioTable.SFX_DIR + str(file), bool(entry.get("loop", false)))


## Load the track of a music context ahead of time without playing it: for music that starts inside a tick (feast
## mode, a boss fight), which the level loads with itself. Unknown contexts are ignored.
func preload_music(context: StringName) -> void:
	var entry: Dictionary = AudioTable.MUSIC.get(context, {})
	if not entry.is_empty():
		_get_stream(AudioTable.MUSIC_DIR + str(entry["file"]), bool(entry["loop"]))


## Release the tracks of every music context except `contexts`, the one playing and the interrupted ones
## (push_music). The level loader calls it once its music runs, so that a session does not keep every track it has
## ever played in memory (1 to 4 MB each). Sound effects are never released.
func retain_music(contexts: Array[StringName]) -> void:
	var keep: Dictionary = {}
	var wanted: Array[StringName] = contexts.duplicate()
	wanted.append_array(_music_stack)
	wanted.append(_music_context)
	for context: StringName in wanted:
		var entry: Dictionary = AudioTable.MUSIC.get(context, {})
		if not entry.is_empty():
			keep[AudioTable.MUSIC_DIR + str(entry["file"])] = true
	for path: Variant in _streams.keys():
		if str(path).begins_with(AudioTable.MUSIC_DIR) and not keep.has(path):
			_streams.erase(path)


## Play a sound effect by event name (Sfx.*). `variant` picks one of several files (-1 = cycle through them).
## `volume_offset_db` is added to the table value. The same event is started at most once per rendered frame.
func play_sfx(event: StringName, variant: int = -1, volume_offset_db: float = 0.0) -> void:
	var entry: Dictionary = AudioTable.SFX.get(event, {})
	if entry.is_empty():
		push_error("Audio.play_sfx: unknown event '%s'" % event)
		return
	if _suspended:
		# Nobody is listening; a cue must not wait for the player to come back.
		return
	var frame: int = Engine.get_process_frames()
	if int(_sfx_started_frame.get(event, -1)) == frame:
		return
	_sfx_started_frame[event] = frame
	var files: Array = entry["files"]
	var index: int = variant
	if index < 0 or index >= files.size():
		index = int(_sfx_variant.get(event, 0)) % files.size()
		_sfx_variant[event] = index + 1
	var stream: AudioStream = _get_stream(AudioTable.SFX_DIR + str(files[index]), false)
	if stream == null:
		return
	var player: AudioStreamPlayer = _free_voice()
	player.stream = stream
	player.bus = StringName(str(entry.get("bus", BUS_SFX)))
	player.volume_db = float(entry["db"][index]) + volume_offset_db
	if not _silent:
		player.play()


## Start an ambience loop (Sfx.LOOP_*). No effect when it already plays.
func start_loop(event: StringName) -> void:
	if _loops.has(event):
		return
	var entry: Dictionary = AudioTable.SFX.get(event, {})
	if entry.is_empty():
		push_error("Audio.start_loop: unknown event '%s'" % event)
		return
	var stream: AudioStream = _get_stream(AudioTable.SFX_DIR + str(entry["files"][0]), true)
	if stream == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = BUS_SFX
	player.stream = stream
	player.volume_db = float(entry["db"][0])
	add_child(player)
	_start(player, 0.0)
	_loops[event] = player


## Stop an ambience loop.
func stop_loop(event: StringName) -> void:
	if not _loops.has(event):
		return
	var player: AudioStreamPlayer = _loops[event]
	_loops.erase(event)
	player.stop()
	player.queue_free()


## Stop every ambience loop (level change).
func stop_all_loops() -> void:
	for event: StringName in _loops.keys():
		stop_loop(event)


## Play the music of a context (Sfx.MUSIC_*). No effect when that context already plays, unless `restart`.
## Clears the push / pop stack.
func play_music(context: StringName, fade_seconds: float = 0.4, restart: bool = false) -> void:
	_music_stack.clear()
	_music_resume.clear()
	_music_holds.clear()
	_music_after_jingle = &""
	_switch_music(context, fade_seconds, restart)


## Play a non-looping jingle (level complete, game over, death) and continue with `then_context` when it ends
## ("" = silence afterwards).
func play_jingle(context: StringName, then_context: StringName = &"") -> void:
	_music_stack.clear()
	_music_resume.clear()
	_music_holds.clear()
	_switch_music(context, 0.1, true)
	_music_after_jingle = then_context


## Temporarily replace the music (feast mode, boss fight). [method pop_music] returns to the previous context.
func push_music(context: StringName, fade_seconds: float = 0.2) -> void:
	if context == _music_context:
		return
	_music_stack.append(_music_context)
	_music_resume.append(get_music_position())
	_switch_music(context, fade_seconds, false)


## Undo the last [method push_music]: the previous track continues where it was interrupted.
func pop_music(fade_seconds: float = 0.4) -> void:
	if _music_stack.is_empty():
		return
	var previous: StringName = _music_stack.pop_back()
	var position: float = _music_resume.pop_back()
	_switch_music(previous, fade_seconds, false, position)


## [method push_music] shared by several holders (2.0, TECH_AUDIT.md 3.17): music that plays while ANY of them wants
## it, e.g. the feast music while any hero of a party feasts. `holder` (a hero, any Object) joins the holders of
## `context`; the context is pushed when it does not play yet. Holding twice is holding once. Single-player keeps
## push_music / pop_music; one holder behaves exactly like them.
func hold_music(context: StringName, holder: Object, fade_seconds: float = 0.2) -> void:
	if holder == null:
		return
	var holders: Dictionary = _music_holds.get(context, {})
	holders[holder.get_instance_id()] = true
	_music_holds[context] = holders
	push_music(context, fade_seconds)


## `holder` lets go of `context` ([method hold_music]). When no holder is left (holders that were freed meanwhile do
## not count) and `context` is still the music that plays, the interrupted track comes back ([method pop_music]).
## Releasing a context one does not hold does nothing.
func release_music(context: StringName, holder: Object, fade_seconds: float = 0.4) -> void:
	if holder == null or not _music_holds.has(context):
		return
	var holders: Dictionary = _music_holds[context]
	if not holders.erase(holder.get_instance_id()):
		return
	for id: int in holders.keys():
		if not is_instance_id_valid(id):
			holders.erase(id)
	if not holders.is_empty():
		return
	_music_holds.erase(context)
	if _music_context == context:
		pop_music(fade_seconds)


## True while `holder` holds `context` ([method hold_music]).
func is_music_held_by(context: StringName, holder: Object) -> bool:
	if holder == null or not _music_holds.has(context):
		return false
	var holders: Dictionary = _music_holds[context]
	return holders.has(holder.get_instance_id())


## Fade the music out and forget the stack.
func stop_music(fade_seconds: float = 0.4) -> void:
	play_music(&"", fade_seconds)


## Context of the music that is playing ("" = none).
func get_music_context() -> StringName:
	return _music_context


## Playback position of the current music in seconds (0 = silence). In runs without an audio device a clock
## stands in for the player, so the value behaves the same everywhere.
func get_music_position() -> float:
	if _music_context == &"":
		return 0.0
	if _silent:
		return _clock_position()
	return _music_a.get_playback_position()


## Suspend (true) or resume (false) all sound: the application lost the focus or went to the background.
## Music and ambience loops halt and later continue at the same position; sound effects are cut and, while
## suspended, new ones are dropped. Music changes made meanwhile take effect on resume.
func set_suspended(suspended: bool) -> void:
	if _suspended == suspended:
		return
	if suspended:
		_clock_base = _clock_position()
		_clock_since_msec = -1
		for player: AudioStreamPlayer in _sfx_players:
			player.stop()
	elif _music_context != &"":
		_clock_since_msec = Time.get_ticks_msec()
	_suspended = suspended
	for event: StringName in _loops:
		var loop_player: AudioStreamPlayer = _loops[event]
		loop_player.stream_paused = suspended
	_music_a.stream_paused = suspended
	_music_b.stream_paused = suspended


## True between set_suspended(true) and set_suspended(false).
func is_suspended() -> bool:
	return _suspended


## Stop all sound effects and loops at once (scene change).
func stop_all_sfx() -> void:
	for player: AudioStreamPlayer in _sfx_players:
		player.stop()
	stop_all_loops()


## Linear volume 0..1 of a bus ("Master", "Music", "SFX").
func get_bus_volume(bus_name: StringName) -> float:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func _is_anything_playing() -> bool:
	if (_music_a != null and _is_active(_music_a)) or (_music_b != null and _is_active(_music_b)):
		return true
	for player: AudioStreamPlayer in _sfx_players:
		if player.playing:
			return true
	return not _loops.is_empty()


## True while a player holds a playback: `playing` alone reads false for a paused stream.
func _is_active(player: AudioStreamPlayer) -> bool:
	return player.playing or player.stream_paused


## Start a player at `from_position` seconds, honouring the silent and the suspended state.
func _start(player: AudioStreamPlayer, from_position: float) -> void:
	if _silent:
		return
	player.play(from_position)
	if _suspended:
		# The pause flag belongs to the playback, not to the player: set it after every play().
		player.stream_paused = true


func _start_clock(from_position: float, stream: AudioStream, loops: bool) -> void:
	_clock_base = from_position
	_clock_since_msec = -1 if _suspended else Time.get_ticks_msec()
	_clock_length = stream.get_length() if stream != null else 0.0
	_clock_loops = loops


func _stop_clock() -> void:
	_clock_base = 0.0
	_clock_since_msec = -1
	_clock_length = 0.0
	_clock_loops = false


func _clock_position() -> float:
	var position: float = _clock_base
	if _clock_since_msec >= 0:
		position += float(Time.get_ticks_msec() - _clock_since_msec) / 1000.0
	if _clock_length > 0.0:
		position = fposmod(position, _clock_length) if _clock_loops else minf(position, _clock_length)
	return position


func _make_music_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = BUS_MUSIC
	player.finished.connect(_on_music_finished.bind(player))
	add_child(player)
	return player


func _switch_music(context: StringName, fade_seconds: float, restart: bool, from_position: float = 0.0) -> void:
	if context == _music_context and not restart:
		return
	var stream: AudioStream = null
	var target_db: float = 0.0
	var loops: bool = false
	if context != &"":
		var entry: Dictionary = AudioTable.MUSIC.get(context, {})
		if entry.is_empty():
			push_error("Audio.play_music: unknown context '%s'" % context)
			return
		loops = bool(entry["loop"])
		stream = _get_stream(AudioTable.MUSIC_DIR + str(entry["file"]), loops)
		target_db = float(entry["db"])
	_music_context = context
	# Cross-fade: _music_a is always the incoming player.
	var outgoing: AudioStreamPlayer = _music_a
	_music_a = _music_b
	_music_b = outgoing
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_music_a.stop()
	_stop_clock()
	if stream != null:
		var start_at: float = _resume_point(stream, loops, from_position)
		_music_a.stream = stream
		_music_a.volume_db = target_db
		_start(_music_a, start_at)
		_start_clock(start_at, stream, loops)
		if _silent and not loops:
			# No device: a jingle "ends" at once so that flows waiting for it still continue.
			_on_music_finished.call_deferred(_music_a)
	if _is_active(outgoing):
		if fade_seconds <= 0.0 or _suspended:
			outgoing.stop()
		else:
			_fade = create_tween()
			_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_fade.tween_property(outgoing, "volume_db", -60.0, fade_seconds)
			_fade.tween_callback(outgoing.stop)
	music_changed.emit(context)


## Where to start `stream` so that it continues at `position`: inside the track for a loop; a jingle that was
## interrupted at its very end starts over.
func _resume_point(stream: AudioStream, loops: bool, position: float) -> float:
	var length: float = stream.get_length()
	if position <= 0.0 or length <= 0.0:
		return maxf(position, 0.0)
	if loops:
		return fposmod(position, length)
	return position if position < length else 0.0


func _on_music_finished(player: AudioStreamPlayer) -> void:
	if player != _music_a:
		return
	# A non-looping track ended: continue with the context queued by play_jingle().
	var next: StringName = _music_after_jingle
	_music_after_jingle = &""
	_music_context = &""
	_stop_clock()
	if next != &"":
		_switch_music(next, 0.0, true)
	else:
		music_changed.emit(&"")


func _free_voice() -> AudioStreamPlayer:
	for i: int in SFX_VOICES:
		var player: AudioStreamPlayer = _sfx_players[(_next_voice + i) % SFX_VOICES]
		if not player.playing:
			_next_voice = (_next_voice + i + 1) % SFX_VOICES
			return player
	# All voices busy: steal the oldest.
	var stolen: AudioStreamPlayer = _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	return stolen


func _get_stream(path: String, loop: bool) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		push_warning("Audio: missing audio file %s" % path)
	elif stream is AudioStreamOggVorbis:
		var ogg: AudioStreamOggVorbis = stream
		ogg.loop = loop
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		if loop:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	_streams[path] = stream
	return stream
