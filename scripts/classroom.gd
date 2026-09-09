extends Control
signal finished
var chatter: AudioStreamPlayer
var speech_clock := 0.0
var game: Node3D
var lesson_mode := true
var active := true
var room: Node3D
var camera: Camera3D
var heading: Label
var panel: PanelContainer
var col: VBoxContainer
var choices: VBoxContainer
var dialogue: Label
var speaker: Label
var advance_button: Button
var shade: ColorRect
var line_index := 0
var reveal := 0.0
var elapsed := 0.0
var mode := "lesson"
var entered := false
var camera_focus := Vector3(-.3,1.2,-2.8)
var lines := [
 ["THE TEACHER", "That is where the chronicle ends. Leave your books open a moment."],
 ["THE TEACHER", "The names change from one account to the next. The bargain does not. We are still living beneath it."],
 ["A PUPIL", "Then the sacrifice did nothing?"],
 ["THE TEACHER", "You woke this morning. There was bread on your table. Someone expected you here. Do not mistake an unfinished rescue for a worthless one."],
 ["A PUPIL", "But someone else has to pay for it."],
 ["THE TEACHER", "Yes. That is the part people leave out when they tell this as a victory."],
 ["THE TEACHER", "There are homes beyond the gates. People who set a place at the table. People who wait for someone to return."],
 ["THE TEACHER", "We take a little, and leave enough for life to recover. That is how the expeditions can return. It does not mean nothing was lost."],
 ["A PUPIL", "Did anyone ever find another way?"],
 ["THE TEACHER", "Many have looked. I have no answer I can honestly give you. Only records, and a fair number of missing pages."],
 ["THE TEACHER", "That is enough for today. You are due at the forge, but there is no need to rush out with half a question in your head."],
 ["THE TEACHER", "Stay if you wish. When you are ready, the door is behind you."]
]
var questions := [
 ["Why do we have to keep harvesting?", "The gods still demand their share. The gates changed where we find it, not what we owe. Each collection buys us more time. It has never bought us freedom."],
 ["What happens to the other worlds?", "They lose something living, just as we would. Take too much and there may be nothing left to recover. Even a careful expedition leaves people with less than they had before."],
 ["What do we know about the one who refused?", "Less than the statues would have you believe. The accounts agree that he lived among us, loved someone here, and gave his life to stay the harvest. Beyond that, I would rather admit what I do not know."],
 ["Has anyone tried to end the bargain?", "Yes. Some searched the old records. Some crossed the gates looking for answers. Not everyone returned. If you mean to ask the same question, begin at the archive. Learn what was tried before you."],
 ["Why am I going to the blacksmith?", "To learn what the village can provide, and what it cannot. Ask about the equipment. Then speak with the scholar at the archive. Preparation is work you can do here, while mistakes are still inexpensive."]
]
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	room=game.school
	camera=room.camera
	chatter=preload("res://scripts/dialogue_sounds.gd").new()
	add_child(chatter)
	build_dialogue()
	if lesson_mode:
		game.menus.reset_player(room.to_global(Vector3(0,.1,1.5)))
		room.pupils[2].show()
		enter_dialogue()
		show_line()
	else:
		ask()
func enter_dialogue() -> void:
	active=true
	heading.show()
	panel.show()
	game.input_blocked=true
	if lesson_mode and mode=="lesson": game.player.hide()
	else: game.player.show()
	game.ui.hide()
	game.sync_camera_mouse()
	camera.make_current()
	camera.position=Vector3(3.1,2.3,3.4)
	camera.look_at(room.to_global(Vector3(-.3,1.2,-2.8)))
func show_line() -> void:
	speaker.text=lines[line_index][0]
	set_text(lines[line_index][1])
	advance_button.text="Continue  ·  Space" if line_index<lines.size()-1 else "Stand up"
func set_text(text: String) -> void:
	chatter.stop()
	speech_clock=0
	dialogue.text=text
	dialogue.visible_characters=0
	reveal=0
func ask() -> void:
	enter_dialogue()
	mode="questions"
	speaker.text="THE TEACHER"
	dialogue.text="What would you like to ask?"
	dialogue.visible_characters=-1
	advance_button.hide()
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	for i in questions.size():
		var button:=Button.new()
		button.text=questions[i][0]
		button.set_meta("asked",i in game.menus.asked_teacher_questions)
		if i in game.menus.asked_teacher_questions:
			button.add_theme_color_override("font_color",Color(.48,.51,.48))
			button.add_theme_color_override("font_hover_color",Color(.70,.73,.68))
			button.tooltip_text="Already discussed. You can ask again."
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y=33
		button.pressed.connect(func(): answer(i))
		choices.add_child(button)
	var leave:=Button.new()
	leave.text="That's all for now."
	leave.pressed.connect(begin_roam)
	choices.add_child(leave)
	choices.show()
func answer(index: int) -> void:
	if index not in game.menus.asked_teacher_questions:
		game.menus.asked_teacher_questions.append(index)
		game.menus.save_game()
	mode="answer"
	choices.hide()
	advance_button.show()
	advance_button.text="Another question"
	set_text(questions[index][1])
func begin_roam() -> void:
	chatter.stop()
	mode="roam"
	active=false
	panel.hide()
	heading.hide()
	room.pupils[2].hide()
	game.player.show()
	game.input_blocked=false
	game.ui.show()
	game.camera.make_current()
	game.sync_camera_mouse()
	entered=true
	game.toast("Take your time. F near the teacher to ask questions. Walk through the door when ready.")
func advance() -> void:
	if not active or elapsed<.4 or mode=="questions": return
	if dialogue.visible_characters>=0 and dialogue.visible_characters<dialogue.text.length():
		dialogue.visible_characters=-1
		chatter.stop()
		return
	if mode=="answer":
		ask()
		return
	line_index+=1
	if line_index>=lines.size():begin_roam()
	else:show_line()
func _process(delta: float) -> void:
	elapsed+=delta
	shade.color.a=1-smoothstep(0.,.8,elapsed)
	if active and dialogue.visible_characters>=0:
		reveal+=delta*42
		var previous := dialogue.visible_characters
		dialogue.visible_characters=mini(int(reveal),dialogue.text.length())
		speech_clock-=delta
		if dialogue.visible_characters>previous and speech_clock<=0:
			var letter := dialogue.text.substr(maxi(0,dialogue.visible_characters-1),1)
			if letter not in [" ",".",",","?","!",":",";"]:
				chatter.syllable("pupil" if speaker.text=="A PUPIL" else "teacher")
				speech_clock=.13
			else: speech_clock=.18
	if entered and not active and not room.contains(game.player.position):
		finished.emit()
		queue_free()
func _input(event: InputEvent) -> void:
	if not active:return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_F]:
		get_viewport().set_input_as_handled()
		advance()

func build_dialogue() -> void:
	heading=Label.new()
	heading.text="THE SCHOOLHOUSE"
	heading.position=Vector2(42,30)
	heading.add_theme_font_size_override("font_size",16)
	heading.add_theme_color_override("font_color",Color(.95,.86,.65))
	add_child(heading)
	panel=PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical=Control.GROW_DIRECTION_BEGIN
	panel.offset_left=40
	panel.offset_right=-40
	panel.offset_top=-260
	panel.offset_bottom=-30
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(.035,.047,.039,.96)
	style.border_color=Color(.56,.48,.31)
	style.set_border_width_all(1)
	style.content_margin_left=28
	style.content_margin_right=28
	style.content_margin_top=18
	style.content_margin_bottom=16
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	col=VBoxContainer.new()
	col.add_theme_constant_override("separation",10)
	panel.add_child(col)
	speaker=Label.new()
	speaker.add_theme_font_size_override("font_size",15)
	speaker.add_theme_color_override("font_color",Color(.86,.72,.45))
	col.add_child(speaker)
	dialogue=Label.new()
	dialogue.custom_minimum_size.y=62
	dialogue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dialogue.add_theme_font_size_override("font_size",23)
	dialogue.add_theme_color_override("font_color",Color(.93,.91,.83))
	col.add_child(dialogue)
	advance_button=Button.new()
	advance_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	advance_button.custom_minimum_size=Vector2(200,35)
	advance_button.pressed.connect(advance)
	col.add_child(advance_button)
	choices=VBoxContainer.new()
	choices.add_theme_constant_override("separation",6)
	col.add_child(choices)
	shade=ColorRect.new()
	shade.color=Color.BLACK
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade)
