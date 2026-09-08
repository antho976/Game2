class_name GearCatalog
extends RefCounted
const SLOTS := ["weapon","helmet","chest","gloves","boots"]
const MAX_UPGRADE := 5
const SURVIVAL := [.85,.72,.60,.48,.35]
static func items() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{"id":"warden_blade","name":"Warden Greatsword","slot":"weapon","style":0,"price":180,"level":1,"damage":28,"speed":1.05,"stamina":18,"description":"A straight, balanced blade. The least demanding greatsword in the forge."},
		{"id":"pilgrim_blade","name":"Pilgrim Greatsword","slot":"weapon","style":1,"price":320,"level":3,"damage":35,"speed":.90,"stamina":24,"description":"A longer blade with a swept guard. Greater reach in silhouette, with a slower swing."},
		{"id":"citadel_blade","name":"Citadel Greatsword","slot":"weapon","style":2,"price":600,"level":6,"damage":46,"speed":.72,"stamina":32,"description":"A broad, dark blade with a reinforced guard. Heavy damage and a demanding stamina cost."}]
	for style in 2:
		for i in 4:
			var slot: String = SLOTS[i+1]
			list.append({"id":["warden_","citadel_"][style]+slot,"name":["Warden ","Citadel "][style]+["Helm","Cuirass","Gauntlets","Greaves"][i],"slot":slot,"style":style,"price":[90,180,70,80][i]*(1 if style==0 else 2),"level":1 if style==0 else 4,"protection":[5,14,4,6][i]*(1 if style==0 else 1.5),"weight":[2.5,7.0,1.8,3.2][i]*(1 if style==0 else 1.4),"description":"Articulated full plate. " + ("Bright steel with restrained brass edging; the lighter of the two suits." if style==0 else "Dark steel, heavier overlapping plates, and broad shoulder guards.")})
	return list
static func find(id: String) -> Dictionary:
	for item in items():
		if item.id==id: return item
	return {}
