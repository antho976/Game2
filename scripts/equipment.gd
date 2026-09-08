extends Node
signal changed
var game: Node
var gold := 0
var level := 1
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
	return {"version":1,"gold":gold,"level":level,"inventory":inventory.duplicate(true),"equipped":equipped.duplicate(),"next_uid":next_uid,"survival_bonus":survival_bonus,"stat_bonus":stat_bonus}
func restore(data: Dictionary) -> void:
	gold = maxi(0,int(data.get("gold",0)))
	level = maxi(1,int(data.get("level",1)))
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
		inventory.append({"uid":uid,"id":str(entry.id),"upgrade":clampi(int(entry.get("upgrade",0)),0,GearCatalog.MAX_UPGRADE)})
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
	var multiplier: float = 1+int(entry.get("upgrade",0))*(.10+stat_bonus)
	for key in ["damage","protection"]:
		if result.has(key): result[key] = snappedf(float(result[key])*multiplier,.1)
	return result
func buy_error(id: String) -> String:
	var item := GearCatalog.find(id)
	if item.is_empty(): return "Item unavailable."
	if level<item.level: return "Requires level %d."%item.level
	if gold<item.price: return "Not enough gold."
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
	gold -= int(GearCatalog.find(id).price)
	inventory.append({"uid":next_uid,"id":id,"upgrade":0})
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
func upgrade_cost(item: Dictionary) -> int:
	return int(ceil(float(GearCatalog.find(item.id).price)*.25*(int(item.upgrade)+1)))
func survival(item: Dictionary) -> float:
	if int(item.upgrade)>=GearCatalog.MAX_UPGRADE: return 1
	return clampf(GearCatalog.SURVIVAL[int(item.upgrade)]+survival_bonus,0,1)
func upgrade_error(uid: int) -> String:
	var item := owned(uid)
	if item.is_empty(): return "That item is no longer owned."
	if item.upgrade>=GearCatalog.MAX_UPGRADE: return "Maximum upgrade reached."
	if gold<upgrade_cost(item): return "Not enough gold."
	return ""
func upgrade(uid: int, expected_rank: int) -> Dictionary:
	var error := upgrade_error(uid)
	if not error.is_empty(): return {"error":error}
	var item := owned(uid)
	if item.upgrade!=expected_rank: return {"error":"This item changed. Review the new upgrade odds."}
	var before := snapshot()
	gold -= upgrade_cost(item)
	var survived := rng.randf()<survival(item)
	if survived: item.upgrade += 1
	else:
		inventory.erase(item)
		for slot in equipped.keys():
			if equipped[slot]==uid: equipped.erase(slot)
	error = commit(before)
	return {"error":error,"survived":survived}
