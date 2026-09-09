class_name CombatRules
extends RefCounted
const DIRECTIONS := ["High","Right","Low","Left"]
const PERFECT_WINDOW := .20
static func opposite(direction: int) -> int: return (direction+2)%4
static func defence(attack_direction: int,guard: int,blocking: bool,age: float,stamina: float,cost: float) -> String:
	if not blocking or attack_direction!=guard: return "hit"
	if age<=PERFECT_WINDOW: return "perfect"
	return "block" if stamina>=cost else "break"
static func state(health: float,stamina: float) -> Dictionary:
	return {"health":health,"max_health":health,"stamina":stamina,"max_stamina":stamina,"guard":0,"blocking":false,"block_age":99.0,"phase":"idle","timer":0.0,"total":1.0,"attack_dir":0,"heavy":false,"exhaust":0.0,"regen_delay":0.0,"counter":0.0,"counter_dir":0,"critical":false}
static func xp_needed(level: int) -> int: return 100+(level-1)*40
static func skills() -> Array[Dictionary]:
	return [
		{"id":"poise","name":"Measured breath","before":"","text":"Recover stamina 12% faster. Opens the counter branch."},
		{"id":"riposte","name":"Turning edge","before":"poise","text":"After a perfect block, strike from the opposite direction for a 65% critical damage bonus."},
		{"id":"footwork","name":"Economy of motion","before":"","text":"Quickstep costs 5 less stamina. Opens the heavy attack branch."},
		{"id":"breaker","name":"Breaking stroke","before":"footwork","text":"Heavy attacks against a guard cause 50% more exhaustion."},
		{"id":"resolve","name":"Tempered resolve","before":"riposte","text":"Gain 12 maximum stamina."},
		{"id":"pursuit","name":"Pursuing cut","before":"breaker","text":"A light attack just after a quickstep has a shorter windup and 20% more damage."}]
