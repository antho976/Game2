extends Node
signal changed
var game: Node
var gold := 0
var diamonds := 0
var level := 1
var xp := 0
var skill_points := 0
var combat_skills: Array[String] = []
var inventory: Array[Dictionary] = []
var equipped := {}
var next_uid := 1
# Research owns these bonuses later. They are not awarded by the blacksmith.
var survival_bonus := 0.0
var stat_bonus := 0.0
var rng := RandomNumberGenerator.new()
func _ready() -> void:
	rng.randomize()
func snapshot() -> Dictionary:
	return {"version":3,"xp":xp,"skill_points":skill_points,"combat_skills":combat_skills.duplicate(),"gold":gold,"diamonds":diamonds,"level":level,"inventory":inventory.duplicate(true),"equipped":equipped.duplicate(),"next_uid":next_uid,"survival_bonus":survival_bonus,"stat_bonus":stat_bonus}
func restore(data: Dictionary) -> void:
	gold = maxi(0,int(data.get("gold",0)))
	diamonds = maxi(0,int(data.get("diamonds",0)))
	level = maxi(1,int(data.get("level",1)))
	xp = maxi(0,int(data.get("xp",0)))
	skill_points = maxi(0,int(data.get("skill_points",level-1)))
	combat_skills.clear()
	for skill in CombatRules.skills():
		if skill.id in data.get("combat_skills",[]) and (skill.before.is_empty() or skill.before in combat_skills): combat_skills.append(skill.id)
	next_uid = maxi(1,int(data.get("next_uid",1)))
	survival_bonus = clampf(float(data.get("survival_bonus",0)),0,1)
	stat_bonus = maxf(0,float(data.get("stat_bonus",0)))
	inventory.clear()
	equipped.clear()
	var seen := {}
	for entry in data.get("inventory",[]):
		if not entry is Dictionary: continue
		var uid := int(entry.get("uid",0))
		if uid<=0 or seen.has(uid) or GearCatalog.find(str(entry.get("id",""))).is_empty(): continue
		seen[uid] = true
		var rank := clampi(int(entry.get("upgrade",0)),0,8)
		inventory.append({"uid":uid,"id":str(entry.id),"upgrade":rank,"earned_gain":maxf(0,float(entry.get("earned_gain",rank*(.10+stat_bonus))))})
		next_uid = maxi(next_uid,uid+1)
	for slot in GearCatalog.SLOTS:
		var entry := owned(int(data.get("equipped",{}).get(slot,0)))
		if not entry.is_empty() and GearCatalog.find(entry.id).slot==slot: equipped[slot] = entry.uid
	changed.emit()
func owned(uid: int) -> Dictionary:
	for item in inventory:
		if item.uid==uid: return item
	return {}
func stats(entry: Dictionary) -> Dictionary:
	var result := GearCatalog.find(entry.id).duplicate()
	var multiplier: float = 1+float(entry.get("earned_gain",int(entry.get("upgrade",0))*.10))
	for key in ["damage","protection"]:
		if result.has(key): result[key] = snappedf(float(result[key])*multiplier,.1)
	return result
func buy_error(id: String) -> String:
	var item := GearCatalog.find(id)
	if item.is_empty(): return "Item unavailable."
	if level<item.level: return "Requires level %d."%item.level
	if gold<purchase_price(id): return "Not enough gold."
	return ""
func commit(before: Dictionary) -> String:
	if game.menus.save_game()!=OK:
		restore(before)
		return "Could not save. Nothing was changed."
	changed.emit()
	return ""
func buy(id: String) -> String:
	var error := buy_error(id)
	if not error.is_empty(): return error
	var before := snapshot()
	gold -= purchase_price(id)
	inventory.append({"uid":next_uid,"id":id,"upgrade":0,"earned_gain":0.0})
	next_uid += 1
	return commit(before)
func equip(uid: int) -> String:
	var item := owned(uid)
	if item.is_empty(): return "That item is no longer owned."
	var def := GearCatalog.find(item.id)
	if level<def.level: return "Your level is too low."
	var before := snapshot()
	equipped[def.slot] = uid
	return commit(before)
func unequip(slot: String) -> String:
	var before := snapshot()
	equipped.erase(slot)
	return commit(before)
func research_bonus(key: String) -> float:
	return game.research.bonus(key) if is_instance_valid(game.research) else 0.0
func purchase_price(id: String) -> int:
	return maxi(1,int(ceil(float(GearCatalog.find(id).price)*(1-clampf(research_bonus("shop_discount"),0,.75)))))
func max_upgrade() -> int: return mini(8,GearCatalog.MAX_UPGRADE+int(research_bonus("upgrade_cap")))
func next_gain() -> float: return .10+stat_bonus+research_bonus("potency")
func next_stats(item: Dictionary) -> Dictionary:
	var next := item.duplicate()
	next.earned_gain = float(item.get("earned_gain",int(item.upgrade)*.10))+next_gain()
	next.upgrade = int(item.upgrade)+1
	return stats(next)
func upgrade_cost(item: Dictionary) -> int:
	return maxi(1,int(ceil(float(GearCatalog.find(item.id).price)*.25*(int(item.upgrade)+1)*(1-clampf(research_bonus("forge_discount"),0,.75)))))
func survival(item: Dictionary) -> float:
	var rank := int(item.upgrade)
	var bases := [.85,.72,.60,.48,.35,.28,.22,.16]
	return clampf(bases[clampi(rank,0,7)]+survival_bonus+research_bonus("survival"),0,1.0 if rank<3 else .95)
func upgrade_error(uid: int) -> String:
	var item := owned(uid)
	if item.is_empty(): return "That item is no longer owned."
	if item.upgrade>=max_upgrade(): return "Maximum upgrade reached."
	if gold<upgrade_cost(item): return "Not enough gold."
	return ""
func upgrade_quote(item: Dictionary) -> Dictionary:
	return {"rank":int(item.upgrade),"cost":upgrade_cost(item),"survival":survival(item),"gain":next_gain()}
func upgrade(uid: int, expected_rank: int,quote: Dictionary = {}) -> Dictionary:
	var error := upgrade_error(uid)
	if not error.is_empty(): return {"error":error}
	var item := owned(uid)
	if item.upgrade!=expected_rank: return {"error":"This item changed. Review the new upgrade odds."}
	if not quote.is_empty() and quote!=upgrade_quote(item): return {"error":"Research changed this upgrade. Review the new cost and odds."}
	var before := snapshot()
	gold -= upgrade_cost(item)
	var survived := rng.randf()<survival(item)
	if survived:
		item.earned_gain = float(item.get("earned_gain",int(item.upgrade)*.10))+next_gain()
		item.upgrade += 1
	else:
		inventory.erase(item)
		for slot in equipped.keys():
			if equipped[slot]==uid: equipped.erase(slot)
	error = commit(before)
	return {"error":error,"survived":survived}

func award_combat(amount: int,reward_gold: int) -> String:
	var before := snapshot()
	var old_level := level
	xp+=maxi(0,amount)
	gold+=maxi(0,reward_gold)
	while xp>=CombatRules.xp_needed(level):
		xp-=CombatRules.xp_needed(level)
		level+=1
		skill_points+=1
	var error := commit(before)
	if error.is_empty() and level>old_level: game.toast("Level %d. +%d skill point(s). Press K to learn combat skills."%[level,level-old_level])
	return error
func learn_combat(id: String) -> String:
	for skill in CombatRules.skills():
		if skill.id!=id: continue
		if id in combat_skills: return "Already learned."
		if skill_points<1: return "You need a skill point."
		if not skill.before.is_empty() and not skill.before in combat_skills: return "Learn the preceding skill first."
		var before := snapshot()
		skill_points-=1
		combat_skills.append(id)
		return commit(before)
	return "Unknown combat skill."
