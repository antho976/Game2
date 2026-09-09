extends Control
signal finished
var data: Dictionary
var elapsed := 0.0
var audio: AudioStreamPlayer
var page: ColorRect
var ink: ShaderMaterial
var subtitles: Label
var title: Label
var fade: ColorRect
var stage: Control
var chapter_index := -1
var done := false
var export_video := false
var base_dir: String
var capture_times: Array = []
var forced_time := -1.0
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	base_dir=get_script().resource_path.get_base_dir()+"/"
	data=JSON.parse_string(FileAccess.get_file_as_string(base_dir+"timeline.json"))
	export_video="--export-video" in OS.get_cmdline_user_args()
	if "--capture-intro" in OS.get_cmdline_user_args(): capture_times=[2.0,8.0,25.0,43.0,62.0,76.0]
	var black:=ColorRect.new()
	black.color=Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	stage=Control.new()
	stage.size=Vector2(1280,720)
	add_child(stage)
	page=ColorRect.new()
	page.size=Vector2(1280,720)
	ink=ShaderMaterial.new()
	ink.shader=load(base_dir+"page.gdshader")
	page.material=ink
	stage.add_child(page)
	var shade:=ColorRect.new()
	shade.position=Vector2(0,608)
	shade.size=Vector2(1280,112)
	shade.color=Color(.025,.019,.012,.86)
	stage.add_child(shade)
	var font: Font=load(base_dir+"serif.ttf")
	subtitles=Label.new()
	subtitles.position=Vector2(95,619)
	subtitles.size=Vector2(1090,70)
	subtitles.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitles.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitles.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	subtitles.add_theme_font_override("font",font)
	subtitles.add_theme_font_size_override("font_size",25)
	subtitles.add_theme_color_override("font_color",Color(.94,.89,.78))
	stage.add_child(subtitles)
	title=Label.new()
	title.position=Vector2(60,32)
	title.size=Vector2(1160,35)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font",font)
	title.add_theme_font_size_override("font_size",17)
	title.add_theme_color_override("font_color",Color(.93,.85,.66))
	title.add_theme_color_override("font_shadow_color",Color(.05,.03,.01,.9))
	title.add_theme_constant_override("shadow_offset_y",2)
	stage.add_child(title)
	fade=ColorRect.new()
	fade.size=Vector2(1280,720)
	fade.color=Color.BLACK
	fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(fade)
	if not export_video:
		var skip:=Button.new()
		skip.text="Skip intro"
		skip.position=Vector2(1122,683)
		skip.size=Vector2(135,30)
		skip.flat=true
		skip.pressed.connect(finish)
		stage.add_child(skip)
	audio=AudioStreamPlayer.new()
	audio.stream=load(base_dir+"narration.mp3")
	add_child(audio)
	layout_stage()
	get_viewport().size_changed.connect(layout_stage)
	update_frame(0)
func layout_stage() -> void:
	if not is_instance_valid(stage): return
	var view:=get_viewport_rect().size
	var factor:=minf(view.x/1280.,view.y/720.)
	stage.scale=Vector2.ONE*factor
	stage.position=(view-Vector2(1280,720)*factor)*.5
func _process(delta: float) -> void:
	if done:return
	elapsed+=delta
	if not audio.playing and elapsed>=1.2 and elapsed<2.0: audio.play()
	var clock:=elapsed
	if not export_video and audio.playing:
		clock=1.2+maxf(0,audio.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency())
	if forced_time>=0:clock=forced_time
	update_frame(clock)
	if not capture_times.is_empty() and clock>=capture_times[0]:
		var stamp: float=capture_times.pop_front()
		capture.call_deferred(stamp)
	if elapsed>=float(data.duration):finish()
func update_frame(time: float) -> void:
	var chapters: Array=data.chapters
	var index:=0
	for i in chapters.size():
		if time>=float(chapters[i].start):index=i
	var info: Dictionary=chapters[index]
	if index!=chapter_index:
		chapter_index=index
		ink.set_shader_parameter("illustration",load(base_dir+info.image))
		ink.set_shader_parameter("chapter",int(info.kind))
		title.text=info.title
	var local:=time-float(info.start)
	var length:=float(info.end)-float(info.start)
	ink.set_shader_parameter("clock",time)
	ink.set_shader_parameter("reveal",clampf(local/3.4,0,1.4))
	ink.set_shader_parameter("progress",clampf(local/length,0,1))
	title.modulate.a=smoothstep(.5,1.5,local)*(1-smoothstep(4.,6.,local))
	subtitles.text=""
	for cue in data.cues:
		if time>=float(cue.start) and time<float(cue.end):
			subtitles.text=cue.text
			break
	# Fade through black between illustrations, and linger after the last line.
	var alpha:=1.0-smoothstep(0.,.8,local)
	alpha=maxf(alpha,smoothstep(length-.65,length,local))
	fade.color.a=alpha
func capture(stamp: float) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(base_dir+"frame-%.1f.png"%stamp)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		finish()
func finish() -> void:
	if done:return
	done=true
	audio.stop()
	finished.emit()
	if get_parent()==get_tree().root:
		get_tree().quit()
	else:queue_free()
