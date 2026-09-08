extends Node
signal changed
signal finished(message: String)
var game: Node
var completed: Dictionary = {}
var projects: Dictionary = {}
var journal: Array = []
var saved_at := 0.0
var tick := 0.0
func snapshot() -> Dictionary:
	return {"version":1,"completed":completed.duplicate(true),"projects":projects.duplicate(true),"journal":journal.duplicate(true),"saved_at":Time.get_unix_time_from_system()}
func restore(data: Dictionary) -> void:
	completed.clear()
	projects.clear()
	journal = data.get("journal",[]).duplicate(true)
	saved_at = maxf(0,float(data.get("saved_at",0)))
	for def in ResearchCatalog.all():
		if def.wip: continue
		var rank := clampi(int(data.get("completed",{}).get(def.id,0)),0,def.ranks)
		if rank>0: completed[def.id] = rank
		var project: Dictionary = data.get("projects",{}).get(def.id,{})
		if not project.is_empty() and rank<def.ranks:
			projects[def.id] = {"rank":rank+1,"remaining":clampf(float(project.get("remaining",def.times[rank])),0,def.times[rank]),"paused":bool(project.get("paused",false))}
	# Recover an overfull imported save without discarding paid work.
	var running := 0
	for id in projects:
		if not projects[id].paused:
			running+=1
			if running>slots(): projects[id].paused=true
	tick = 0
	changed.emit()
func bonus(key: String) -> float:
	var total := 0.0
	for id in completed:
		var def := ResearchCatalog.find(id)
		if not def.is_empty(): total += float(def.effects.get(key,0))*int(completed[id])
	return total
func slots() -> int: return mini(4,2+int(bonus("slots")))
func running_count() -> int:
	var count := 0
	for project in projects.values():
		if not project.paused: count+=1
	return count
func offline_rate() -> float: return minf(.5,.25+bonus("offline"))
func player_stats() -> Dictionary:
	return {"health":100+bonus("health"),"stamina":100+bonus("stamina"),"stamina_recovery_multiplier":1+bonus("recovery")}
func start_error(id: String) -> String:
	var def := ResearchCatalog.find(id)
	if def.is_empty(): return "Unknown study."
	if def.wip: return "This hub branch is still being designed."
	if projects.has(id): return "This study is already active or paused."
	var rank := int(completed.get(id,0))
	if rank>=def.ranks: return "All ranks completed."
	for prerequisite in def.requires:
		if int(completed.get(prerequisite,0))<int(def.requires[prerequisite]): return "Complete the prerequisite studies first."
	if running_count()>=slots(): return "All research slots are in use. Pause a project to free a slot."
	if game.equipment.gold<int(def.gold[rank]): return "Not enough gold."
	if game.equipment.diamonds<int(def.diamonds[rank]): return "Not enough diamonds."
	return ""
func persist(before: Dictionary,gold_before: int,diamonds_before: int) -> String:
	if game.menus.save_game()!=OK:
		game.equipment.gold = gold_before
		game.equipment.diamonds = diamonds_before
		restore(before)
		return "Could not save. Research and currency were left unchanged."
	changed.emit()
	return ""
func start(id: String) -> String:
	var error := start_error(id)
	if not error.is_empty(): return error
	var before := snapshot()
	var gold_before: int = game.equipment.gold
	var diamonds_before: int = game.equipment.diamonds
	var def := ResearchCatalog.find(id)
	var rank := int(completed.get(id,0))
	game.equipment.gold -= int(def.gold[rank])
	game.equipment.diamonds -= int(def.diamonds[rank])
	projects[id] = {"rank":rank+1,"remaining":float(def.times[rank]),"paused":false}
	return persist(before,gold_before,diamonds_before)
func set_paused(id: String,paused: bool) -> String:
	if not projects.has(id): return "That study has already finished."
	if projects[id].paused==paused: return ""
	if not paused and running_count()>=slots(): return "All research slots are in use."
	var before := snapshot()
	projects[id].paused = paused
	return persist(before,game.equipment.gold,game.equipment.diamonds)
func advance(seconds: float,offline := false) -> String:
	if seconds<=0: return ""
	var before := snapshot()
	var notices: Array[String] = []
	# Event stepping applies an offline-speed study only after its completion.
	var time_left := seconds
	while time_left>0 and running_count()>0:
		var rate := offline_rate() if offline else 1.0
		var step := time_left
		for project in projects.values():
			if not project.paused: step=minf(step,float(project.remaining)/rate)
		for id in projects.keys():
			var project: Dictionary = projects[id]
			if project.paused: continue
			project.remaining = maxf(0,float(project.remaining)-step*rate)
			if project.remaining<=.00001:
				completed[id] = project.rank
				var message: String = "%s · rank %d complete"%[ResearchCatalog.find(id).name,project.rank]
				journal.push_front({"message":message,"time":Time.get_unix_time_from_system(),"unread":true})
				if journal.size()>40: journal.pop_back()
				notices.append(message)
				projects.erase(id)
		time_left-=step
	if not notices.is_empty() or offline:
		var error := persist(before,game.equipment.gold,game.equipment.diamonds)
		if not error.is_empty(): return error
		if not notices.is_empty(): finished.emit("Research complete\n"+"\n".join(notices))
	return ""
func apply_offline() -> String:
	if saved_at<=0: return ""
	return advance(maxf(0,Time.get_unix_time_from_system()-saved_at),true)
func acknowledge() -> void:
	var before := snapshot()
	for entry in journal: entry.unread=false
	persist(before,game.equipment.gold,game.equipment.diamonds)
func _process(delta: float) -> void:
	if not is_instance_valid(game.menus) or not game.menus.started or game.menus.home: return
	tick+=delta
	if tick>=.25:
		var elapsed := tick
		tick=0
		advance(elapsed)
