extends Node
class_name AudioKit
## The village's sound library and mixer.
##
## Files live in assets/audio as <id>_NN.wav|ogg|mp3 and are picked up by name, so a new
## variation is a new file and nothing else. `play` chooses a variation (never the one just
## played), randomises pitch a little, honours a per-id cooldown, and routes to a bus.
## Loops are owned by their caller through `loop`/`stop`, so a purr or a pour ends with the
## activity that started it. Ambience beds crossfade on the day's daylight value.
const BUSES := ["Music","Ambience","SFX","UI","Dialogue"]
const SOUND_DIR := "res://assets/audio/"
var game: Node
var library := {} # id -> Array[AudioStream]
var last_pick := {} # id -> int
var cooldowns := {} # id -> msec
var loops := {} # key -> AudioStreamPlayer / AudioStreamPlayer3D
var beds := {} # id -> AudioStreamPlayer for daylight crossfades
var voices := 0
var rng := RandomNumberGenerator.new()
var duck_target := 0.0
var duck := 0.0
const MAX_VOICES := 40

func _ready() -> void:
	rng.randomize()
	name = "AudioKit"
	build_buses()
	scan()

func build_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	# A low-pass on Ambience and SFX lets menus and slow motion pull the world back.
	for bus in ["Ambience","SFX"]:
		var index := AudioServer.get_bus_index(bus)
		if AudioServer.get_bus_effect_count(index) == 0:
			var filter := AudioEffectLowPassFilter.new()
			filter.cutoff_hz = 20500
			AudioServer.add_bus_effect(index,filter)
			AudioServer.set_bus_effect_enabled(index,0,false)

func scan() -> void:
	library.clear()
	var dir := DirAccess.open(SOUND_DIR)
	if dir == null: return
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		var ext := file.get_extension().to_lower()
		if ext in ["wav","ogg","mp3"]:
			var base := file.get_basename()
			# <id>_NN: strip the two-digit variation suffix.
			var id := base
			var parts := base.rsplit("_",true,1)
			if parts.size() == 2 and parts[1].is_valid_int(): id = parts[0]
			if not library.has(id): library[id] = []
			library[id].append(SOUND_DIR+file)
		file = dir.get_next()
	dir.list_dir_end()
	for id in library: library[id].sort()

func has(id: String) -> bool: return library.has(id)

func stream(id: String) -> AudioStream:
	if not library.has(id): return null
	var options: Array = library[id]
	var pick := 0
	if options.size() > 1:
		pick = rng.randi_range(0,options.size()-2)
		if pick >= int(last_pick.get(id,-1)): pick += 1
	last_pick[id] = pick
	var resource = options[pick]
	if resource is String:
		var loaded := load(resource)
		options[pick] = loaded
		return loaded
	return resource

func silenced() -> bool:
	return DisplayServer.get_name() == "headless" or (game != null and (game.muted or game.test_mode))

## One-shot at a world position. Returns the player, or null when nothing played.
func play(id: String,pos: Vector3,volume := -12.0,options := {}) -> AudioStreamPlayer3D:
	if silenced() or not has(id) or voices >= MAX_VOICES: return null
	var cooldown: float = float(options.get("cooldown",0.0))
	if cooldown > 0:
		var now := Time.get_ticks_msec()
		if now < int(cooldowns.get(id,0)): return null
		cooldowns[id] = now+int(cooldown*1000)
	var node := AudioStreamPlayer3D.new()
	node.stream = stream(id)
	node.position = pos
	node.volume_db = volume
	node.bus = str(options.get("bus","SFX"))
	var spread: float = float(options.get("pitch_spread",.05))
	node.pitch_scale = float(options.get("pitch",1.0))*rng.randf_range(1.0-spread,1.0+spread)
	node.max_distance = float(options.get("max_distance",22.0))
	node.unit_size = float(options.get("unit_size",4.0))
	node.attenuation_filter_cutoff_hz = 12000
	voices += 1
	add_child(node)
	node.finished.connect(func(): voices -= 1; node.queue_free())
	node.play()
	return node

## One-shot with no position: interface, stingers, the player's own breath.
func play_2d(id: String,volume := -12.0,options := {}) -> AudioStreamPlayer:
	if silenced() or not has(id) or voices >= MAX_VOICES: return null
	var cooldown: float = float(options.get("cooldown",0.0))
	if cooldown > 0:
		var now := Time.get_ticks_msec()
		if now < int(cooldowns.get(id,0)): return null
		cooldowns[id] = now+int(cooldown*1000)
	var node := AudioStreamPlayer.new()
	node.stream = stream(id)
	node.volume_db = volume
	node.bus = str(options.get("bus","UI"))
	var spread: float = float(options.get("pitch_spread",.03))
	node.pitch_scale = float(options.get("pitch",1.0))*rng.randf_range(1.0-spread,1.0+spread)
	voices += 1
	add_child(node)
	node.finished.connect(func(): voices -= 1; node.queue_free())
	node.play()
	return node

## Interface shorthand: routed to UI, quiet, never spatial.
func ui(id: String,volume := -14.0) -> void:
	play_2d(id,volume,{"bus":"UI","cooldown":.04})

## A looping sound owned by `key`. Calling again with the same key restarts nothing.
func loop(key: String,id: String,pos,volume := -18.0,options := {}) -> Node:
	if loops.has(key) and is_instance_valid(loops[key]): return loops[key]
	if DisplayServer.get_name() == "headless" or not has(id): return null
	var source := stream(id)
	if source is AudioStreamOggVorbis: source.loop = true
	elif source is AudioStreamWAV: source.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif source is AudioStreamMP3: source.loop = true
	var node: Node
	if pos is Vector3:
		var spatial := AudioStreamPlayer3D.new()
		spatial.position = pos
		spatial.max_distance = float(options.get("max_distance",14.0))
		spatial.unit_size = float(options.get("unit_size",4.0))
		spatial.bus = str(options.get("bus","Ambience"))
		node = spatial
		if options.has("parent"): options.parent.add_child(node)
		else: game.world.add_child(node)
	else:
		var flat := AudioStreamPlayer.new()
		flat.bus = str(options.get("bus","Ambience"))
		node = flat
		add_child(node)
	node.stream = source
	node.volume_db = volume if not options.get("fade_in",false) else -60.0
	node.pitch_scale = float(options.get("pitch",1.0))
	node.play()
	if options.get("fade_in",false):
		create_tween().tween_property(node,"volume_db",volume,float(options.get("fade",.6)))
	loops[key] = node
	return node

## Fade a loop out and free it.
func stop(key: String,fade := .3) -> void:
	if not loops.has(key): return
	var node = loops[key]
	loops.erase(key)
	if not is_instance_valid(node): return
	if fade <= 0 or DisplayServer.get_name() == "headless":
		node.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(node,"volume_db",-60.0,fade)
	tween.tween_callback(node.queue_free)

func set_loop_volume(key: String,volume: float,seconds := .5) -> void:
	if not loops.has(key) or not is_instance_valid(loops[key]): return
	create_tween().tween_property(loops[key],"volume_db",volume,seconds)

## Ambience beds are 2D loops that the day cycle weights by daylight. `weight` is 0..1.
func bed(id: String,volume: float,weight: float) -> void:
	if DisplayServer.get_name() == "headless" or not has(id): return
	var node: AudioStreamPlayer = beds.get(id)
	if node == null:
		node = AudioStreamPlayer.new()
		node.bus = "Ambience"
		var source := stream(id)
		if source is AudioStreamOggVorbis: source.loop = true
		elif source is AudioStreamWAV: source.loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif source is AudioStreamMP3: source.loop = true
		node.stream = source
		node.volume_db = -60
		add_child(node)
		node.play()
		beds[id] = node
	node.volume_db = linear_to_db(clampf(weight,0,1)*db_to_linear(volume)+.0001)

## Menus, pause and slow motion pull the world behind a low-pass and drop the music.
func set_ducked(on: bool) -> void:
	duck_target = 1.0 if on else 0.0

func _process(delta: float) -> void:
	if is_equal_approx(duck,duck_target): return
	duck = move_toward(duck,duck_target,delta*4)
	var cutoff := lerpf(20500,900,duck)
	for bus in ["Ambience","SFX"]:
		var index := AudioServer.get_bus_index(bus)
		if AudioServer.get_bus_effect_count(index) == 0: continue
		var filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(index,0)
		filter.cutoff_hz = cutoff
		AudioServer.set_bus_effect_enabled(index,0,duck > .01)
	var music := AudioServer.get_bus_index("Music")
	var base: float = float(volumes.get("Music",1.0))
	AudioServer.set_bus_volume_db(music,linear_to_db(maxf(base,.0001))-4.0*duck)

var volumes := {}
## Persisted per-bus volume, 0..1. Master is bus 0.
func set_volume(bus: String,value: float) -> void:
	volumes[bus] = value
	var index := 0 if bus == "Master" else AudioServer.get_bus_index(bus)
	if index < 0: return
	AudioServer.set_bus_volume_db(index,linear_to_db(maxf(value,.0001)))
	if bus == "Master": AudioServer.set_bus_mute(0,value <= .0001)
