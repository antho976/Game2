extends Node3D
# Duel sounds synthesised at start-up: the repository ships no sword recordings, and short
# shaped noise and ringing partials read clearly for whooshes, clangs, thuds and footwork.
# Hits carry a sub-bass layer and a wet burst so a landed cut is felt, not just heard.
const RATE := 22050
var game: Node
var streams := {}
var rng := RandomNumberGenerator.new()
func _ready() -> void:
	rng.seed=7
	if DisplayServer.get_name()=="headless": return
	streams["whoosh"]=render(.26,func(t: float,u: float) -> float: return noise()*envelope(u,.08,.45)*.9)
	streams["heavy_whoosh"]=render(.46,func(t: float,u: float) -> float: return (noise()*envelope(u,.16,.5)+sin(TAU*(70+40*u)*t)*envelope(u,.2,.6)*.35))
	streams["clang"]=render(.55,func(t: float,u: float) -> float: return (partials(t,[2140,3310,5170,7020],[1,.55,.35,.18],[9,12,15,22])+noise()*exp(-t*70)*.6)*.6)
	streams["parry"]=render(.75,func(t: float,u: float) -> float: return (partials(t,[1720,2590,4180,6240,8650],[1,.7,.45,.28,.15],[5,6,8,11,15])+noise()*exp(-t*90)*.7)*.7)
	streams["thud"]=render(.42,func(t: float,u: float) -> float: return (sin(TAU*(52+70*exp(-t*18))*t)*exp(-t*9)+noise()*exp(-t*28)*.5+sin(TAU*38*t)*exp(-t*6)*.5)*.9)
	streams["slam"]=render(.6,func(t: float,u: float) -> float: return (sin(TAU*(44+60*exp(-t*14))*t)*exp(-t*6)+noise()*exp(-t*18)*.6+sin(TAU*30*t)*exp(-t*4)*.6)*.95)
	streams["flesh"]=render(.3,func(t: float,u: float) -> float: return (noise()*exp(-t*34)*.8+sin(TAU*(140+90*exp(-t*30))*t)*exp(-t*22)*.6)*.85)
	streams["crack"]=render(.5,func(t: float,u: float) -> float: return (noise()*exp(-t*22)+partials(t,[620,940,1480],[1,.5,.3],[8,10,14])*.5)*.8)
	streams["step"]=render(.16,func(t: float,u: float) -> float: return noise()*envelope(u,.05,.6)*.35)
	streams["stomp"]=render(.28,func(t: float,u: float) -> float: return (noise()*exp(-t*30)*.5+sin(TAU*60*t)*exp(-t*12)*.7)*.8)
	streams["bind"]=render(.6,func(t: float,u: float) -> float: return (partials(t,[1180,1960,3020,4400],[1,.6,.4,.2],[6,7,9,12])+noise()*exp(-t*40)*.5)*.6)
	streams["raise"]=render(.2,func(t: float,u: float) -> float: return (noise()*envelope(u,.04,.5)*.5+partials(t,[2900,4300],[.5,.3],[18,24])*.4)*.6)
	streams["tick"]=render(.08,func(t: float,u: float) -> float: return partials(t,[3400,5100],[1,.5],[40,55])*.9)
	streams["deny"]=render(.18,func(t: float,u: float) -> float: return (sin(TAU*(180-60*u)*t)*exp(-t*20)+noise()*exp(-t*60)*.3)*.7)
func noise() -> float: return rng.randf_range(-1,1)
func envelope(u: float,peak: float,tail: float) -> float:
	return smoothstep(0,peak,u)*(1.0-smoothstep(tail,1.0,u))
func partials(t: float,freqs: Array,gains: Array,decays: Array) -> float:
	var total := 0.0
	for i in freqs.size(): total+=sin(TAU*freqs[i]*t)*gains[i]*exp(-t*decays[i])
	return total/2.2
func render(seconds: float,shape: Callable) -> AudioStreamWAV:
	var count := int(seconds*RATE)
	var data := PackedByteArray()
	data.resize(count*2)
	var previous := 0.0
	for i in count:
		var t := float(i)/RATE
		var raw: float=shape.call(t,t/seconds)
		# A gentle one-pole low-pass keeps the noise bursts from hissing.
		previous=previous*.55+raw*.45
		var sample := int(clampf(previous,-1,1)*32000)
		data.encode_s16(i*2,sample)
	var wav := AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=RATE
	wav.stereo=false
	wav.data=data
	return wav
func play(id: String,pos: Vector3,volume := -12.0,pitch := 1.0) -> void:
	if not streams.has(id) or game.muted or game.test_mode: return
	var player := AudioStreamPlayer3D.new()
	player.stream=streams[id]
	player.position=pos
	player.volume_db=volume
	player.pitch_scale=pitch*rng.randf_range(.94,1.06)
	player.max_distance=24
	player.unit_size=5
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
