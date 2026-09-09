extends AudioStreamPlayer
## Short nonverbal syllables. No spoken words or narration; reusable per speaker.
static var tones := {}
var rng := RandomNumberGenerator.new()
func _ready() -> void:
	rng.randomize()
	if AudioServer.get_bus_index("Dialogue")<0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1,"Dialogue")
	bus="Dialogue"
	volume_db=-20
func syllable(character: String) -> void:
	if not tones.has(character): tones[character]=make_tone(character)
	stream=tones[character]
	pitch_scale=rng.randf_range(.93,1.09)
	play()
static func make_tone(character: String) -> AudioStreamWAV:
	var rate := 22050
	var duration := .105 if character=="pupil" else .135
	var base := 230.0 if character=="pupil" else 125.0
	var bytes := PackedByteArray()
	var count := int(rate*duration)
	bytes.resize(count*2)
	var phase := 0.0
	for i in count:
		var t := float(i)/rate
		var progress := t/duration
		var envelope := smoothstep(0,.012,t)*(1-smoothstep(duration*.45,duration,t))
		phase+=TAU*base*(1.0+.12*sin(progress*PI))/rate
		var vowel := sin(phase)*.48+sin(phase*2)*.25+sin(phase*3)*.12+sin(phase*5)*.06
		vowel*=envelope*(.82+.18*sin(TAU*27*t))
		bytes.encode_s16(i*2,int(clampf(vowel,-1,1)*24000))
	var sound := AudioStreamWAV.new()
	sound.format=AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate=rate
	sound.data=bytes
	return sound
