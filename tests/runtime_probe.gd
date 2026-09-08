extends Node
var last_report := 0
var draws := 0
func _ready() -> void:
	RenderingServer.frame_post_draw.connect(func(): draws += 1)
	print("RUNTIME_PROBE_READY backend=",DisplayServer.get_name())
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now-last_report >= 2000:
		last_report = now
		print("RUNTIME_PROBE ",JSON.stringify({"ms":now,"process":Engine.get_process_frames(),"physics":Engine.get_physics_frames(),"draws":draws,"fps":Engine.get_frames_per_second(),"focus":DisplayServer.window_is_focused(),"position":str(get_parent().player.position)}))
