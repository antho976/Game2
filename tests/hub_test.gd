extends Node
var failures := 0
func check(ok: bool,text: String) -> void:
	if ok: print("PASS: ",text)
	else:
		failures += 1
		push_error("FAIL: "+text)

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func run(game: Node) -> void:
	await frames(30)
	check(game.player.is_on_floor(),"Unarmed player stands on the hub floor")
	check(game.player.find_children("*sword*","Node",true,false).is_empty(),"No weapon attached to the hub character")
	for action in ["idle","walk","pet","feed","water","sit"]:
		var found := false
		for clip in game.player.animation.get_animation_list():
			if clip.ends_with("_"+action): found = true
		check(found,"Authored skeletal animation: "+action)
	check(game.kit.life.navigation_ready,"Animal navigation built from live collision")
	var start: Vector3 = game.player.position
	game.player.position = Vector3(-13.7,.1,6.0)
	Input.action_press("up")
	await frames(270)
	Input.action_release("up")
	check(game.player.position.z < -3.8,"Pond bench leaves the western house lane open")
	game.player.position = start
	game.player.velocity = Vector3.ZERO
	Input.action_press("right")
	await frames(40)
	Input.action_release("right")
	check(game.player.position.x>start.x+1,"WASD moves the character")
	await frames(15)
	check(Vector2(game.player.velocity.x,game.player.velocity.z).length()<.03,"Releasing input stops movement")
	for point in game.activities.points:
		var path = game.kit.life.route(start,point.pos)
		check(path.size()>1,"Reachable activity: "+point.id)
	for service in game.world.interactions:
		check(game.kit.life.route(start,service.pos).size()>1,"Reachable location: "+service.id)
	var cat: Dictionary
	for animal in game.kit.life.animals:
		if animal.kind == "cat" and animal.friendly:
			cat = animal
			break
	for i in 4:
		var paws = cat.model.find_children("Paw"+str(i),"Node3D",true,false)
		check(not paws.is_empty() and paws[0].get_parent().name == "Leg"+str(i),"Cat paw follows limb pivot "+str(i))
	var cat_start: Vector3 = cat.body.position
	game.player.position = cat.body.position+Vector3(0,0,1.15)
	await frames(4)
	check(game.nearest.begins_with("cat:"),"Pet prompt selects the nearby cat")
	Input.action_press("interact")
	await frames(3)
	Input.action_release("interact")
	await frames(30)
	check(cat.pets == 1 and cat.state == "petted","Petting reaches a visible animal state")
	check(cat.body.position.distance_to(cat_start)<.15,"Petted cat stays beside the player")
	check(game.player.current.ends_with("_pet"),"Interaction input plays the pet animation")
	game.activities.interact("feed")
	await frames(180)
	var gather := Vector3(-10.3,.085,8.7)
	var close := 0
	for duck in game.activities.ducks:
		if duck.model.position.distance_to(gather)<1.4: close+=1
	check(close>=2,"Feeding draws multiple ducks toward the dock")
	game.activities.interact("water")
	check(game.activities.watered,"Garden records being watered")
	game.activities.interact("water")
	check(game.activities.watered,"Repeated watering does not reset the garden action")
	await frames(210)
	game.player.position = Vector3(5.4,.05,10.1)
	game.activities.interact("sit")
	await frames(15)
	check(game.player.current.ends_with("_sit") and game.player.activity=="sit","Bench uses the sitting pose")
	Input.action_press("up")
	await frames(15)
	Input.action_release("up")
	await frames(10)
	check(game.player.activity.is_empty() and game.player.is_on_floor(),"Leaving the bench restores movement and collision")
	var bird: Dictionary
	for animal in game.kit.life.animals:
		if animal.kind == "bird":
			bird = animal
			break
	var original_home: Vector3 = bird.home
	game.player.position = bird.body.position+Vector3(.6,0,0)
	await frames(4)
	check(bird.state in ["takeoff","cruise","land"],"Bird takes flight when approached")
	game.player.position = Vector3(0,.1,12)
	await frames(1000)
	check(bird.landings>0 and bird.home.distance_to(original_home)>2,"Bird lands at a different feeding patch")
	check(game.activities.ducks.size()==4,"Four ducks remain in the pond")
	print("HUB CHECKS COMPLETE: ",failures," failure(s)")
	get_tree().quit(1 if failures else 0)
