class_name CombatRules
extends RefCounted
# Pure, deterministic sword-duel rules shared by the live bout and the test suite.
# Lanes are read from the player's point of view: High, the player's Right, Low, the player's Left.
const DIRECTIONS := ["High","Right","Low","Left"]
const PERFECT_WINDOW := .20
const REARM_LOCK := .32
const CHAIN_WINDOW := 1.8
const FEINT_LIMIT := .50 # Fraction of the windup during which a swing can still change lane.
const PULL_LIMIT := .45 # Fraction of the windup during which a swing can still be pulled back to guard.
const CLASH_LIMIT := .50 # A defender this far into their own swing meets the attack blade on blade.
const INTERRUPT_LIMIT := .40 # A light hit stops a swing that has not yet reached this point.
const WINDED := .20 # Fraction of maximum stamina below which a fighter is winded.
static func opposite(direction: int) -> int: return (direction+2)%4
static func defence(attack_direction: int,guard: int,blocking: bool,age: float,stamina: float,cost: float) -> String:
	if not blocking or attack_direction!=guard: return "hit"
	if age<=PERFECT_WINDOW: return "perfect"
	return "block" if stamina>=cost else "break"
static func state(health: float,stamina: float) -> Dictionary:
	return {"health":health,"max_health":health,"stamina":stamina,"max_stamina":stamina,"guard":0,"blocking":false,"block_age":99.0,"phase":"idle","timer":0.0,"total":1.0,"attack_dir":0,"heavy":false,"exhaust":0.0,"regen_delay":0.0,"counter":0.0,"counter_dir":0,"critical":false,"pursuit":false,"riposte":false,"feinted":false,"feint_at":-1.0,"chain":[],"chain_time":0.0,"combo":"","whiff":false,"pain":0.0,"flash":0.0,"damage_taken":0.0,"read_timer":-1.0,"parry_ready":false,"followup":false,"resting":false,"strafe":1.0,"strafe_time":0.0}
static func xp_needed(level: int) -> int: return 100+(level-1)*40
# Is a fighter's swing still early enough to feint or pull?
static func progress(fighter: Dictionary) -> float:
	return 1.0-fighter.timer/maxf(fighter.total,.001)
# A hit interrupts an early or unfinished light swing; heavy strikes stop anything.
static func interrupts(defender_phase: String,defender_progress: float,heavy: bool) -> bool:
	if defender_phase!="windup": return true
	return heavy or defender_progress<INTERRUPT_LIMIT
# Both blades meet when the defender is already committed to a swing in the same lane.
static func clashes(defender_phase: String,defender_progress: float,attack_direction: int,defender_direction: int) -> bool:
	return defender_phase=="windup" and defender_progress>=CLASH_LIMIT and attack_direction==defender_direction
static func windup(heavy: bool,speed: float,pursuit: bool,riposte: bool,winded: bool) -> float:
	var base: float=.65 if heavy else (.22 if pursuit else .34)
	base/=maxf(speed,.1)
	if riposte and not heavy: base*=.78
	if winded: base*=1.15
	return base
static func recovery(heavy: bool,whiff: bool) -> float:
	return (.60 if heavy else .38)+(.14 if whiff else 0.0)
# Sword forms: sequences of connecting cuts whose final stroke gains a property.
static func combos() -> Array[Dictionary]:
	return [
		{"id":"crossing","name":"Crossing cut","steps":[3,1,0],"pierce":true,"damage":1.3,"exhaust":20.0,"text":"Left, Right, High. The final high cut forces its way through a held guard."},
		{"id":"serpent","name":"Serpent's coil","steps":[2,0,2],"pierce":false,"damage":1.5,"exhaust":30.0,"text":"Low, High, Low. The final thrust lands harder and wears down a blocking guard."}]
# The form completed by appending `direction` to the chain, or empty.
static func finisher(chain: Array,direction: int) -> Dictionary:
	var candidate: Array=chain.duplicate()
	candidate.append(direction)
	for combo in combos():
		var steps: Array=combo.steps
		if candidate.size()<steps.size(): continue
		if candidate.slice(candidate.size()-steps.size())==steps: return combo
	return {}
# Longest form prefix already matched by the tail of the chain: {"combo":…, "step":n}.
static func combo_progress(chain: Array) -> Dictionary:
	var best := {"combo":{},"step":0}
	for combo in combos():
		var steps: Array=combo.steps
		for n in range(mini(chain.size(),steps.size()-1),0,-1):
			if chain.slice(chain.size()-n)==steps.slice(0,n):
				if n>best.step: best={"combo":combo,"step":n}
				break
	return best
# The sparring partner grows with the player, but stays readable at every level.
static func partner(level: int) -> Dictionary:
	var rank: int=maxi(0,level-1)
	return {
		"health":140.0+rank*12,
		"damage":18.0+rank*1.2,
		"read_delay_min":maxf(.10,.16-rank*.015),
		"read_delay_max":maxf(.18,.34-rank*.02),
		"read_chance":minf(.85,.40+rank*.08),
		"feint_chance":0.0 if rank<1 else minf(.40,.18+(rank-1)*.05),
		"double_chance":minf(.45,.15+rank*.04),
		"heavy_chance":.30,
		"parry_chance":0.0 if rank<2 else minf(.25,.10+(rank-2)*.03),
		"decision_min":maxf(.6,.9-rank*.05),
		"decision_max":maxf(1.0,1.6-rank*.06),
		"windup_light":maxf(.58,.78-rank*.03),
		"windup_heavy":maxf(.85,1.05-rank*.03)}
static func skills() -> Array[Dictionary]:
	return [
		{"id":"poise","name":"Measured breath","before":"","text":"Recover stamina 12% faster. Opens the counter branch."},
		{"id":"riposte","name":"Turning edge","before":"poise","text":"After a perfect block, strike from the opposite direction for a 65% critical damage bonus."},
		{"id":"footwork","name":"Economy of motion","before":"","text":"Quickstep costs 5 less stamina. Opens the heavy attack branch."},
		{"id":"breaker","name":"Breaking stroke","before":"footwork","text":"Heavy attacks against a guard cause 50% more exhaustion."},
		{"id":"resolve","name":"Tempered resolve","before":"riposte","text":"Gain 12 maximum stamina."},
		{"id":"pursuit","name":"Pursuing cut","before":"breaker","text":"A light attack just after a quickstep has a shorter windup and 20% more damage."}]
