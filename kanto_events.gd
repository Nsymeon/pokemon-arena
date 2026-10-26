extends RefCounted
# Explicit supported events; never execute source assembly as game code.
var world_ref: WeakRef
var w:
	get: return world_ref.get_ref()
var a
var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/events.json"))
var patches={}
var textures={}
var spin=Vector2.ZERO
var spin_clock=0.0
var flowing=false
const LEAGUE=["MAP_POKEMON_LEAGUE_LORELEIS_ROOM","MAP_POKEMON_LEAGUE_BRUNOS_ROOM","MAP_POKEMON_LEAGUE_AGATHAS_ROOM","MAP_POKEMON_LEAGUE_LANCES_ROOM","MAP_POKEMON_LEAGUE_CHAMPIONS_ROOM"]
const QUIZZES=[
	["Does Caterpie evolve into Metapod?",true],
	["Are there nine official Kanto Gym Badges?",false],
	["Does Poliwag evolve three times?",false],
	["Do Electric attacks affect Ground-type Pokemon?",false],
	["Can identical species at the same level have different stats?",true],
	["Does TM28 teach Tombstony?",false]]

func install(world):
	world_ref=weakref(world); a=world.a

func state() -> Dictionary:
	if not a.data.has("world_events"): a.data.world_events={"done":{},"rocks":{},"mansion":false}
	return a.data.world_events

func done(key: String) -> bool:
	return bool(state().done.get(key,false))

func finish(key: String):
	state().done[key]=true

func point(o) -> Vector2:
	return Vector2(float(o.x)+0.5,float(o.y)+0.5)*w.TILE

func geometry(label: String):
	for tile in catalog[w.current].patches.get(label,[]): patches[Vector2i(int(tile.x),int(tile.y))]=tile

func refresh():
	patches.clear()
	var name=str(w.room().name)
	if name=="MtEmber_Exterior" and a.sevii.done("network_quest"): geometry("MtEmber_Exterior_EventScript_OpenCave")
	if name=="SixIsland_RuinValley" and a.field.can_use("cut"): geometry("SixIsland_RuinValley_EventScript_OpenDottedHoleDoor")
	if name=="FiveIsland_Meadow" and a.sevii.done("sapphire_stolen"): geometry("FiveIsland_Meadow_EventScript_SetWarehouseDoorUnlocked")
	if name.begins_with("SeafoamIslands_") and done("calm:"+w.current): geometry("calm")
	if name=="CeladonCity_GameCorner": geometry(name+"_EventScript_"+("OpenRocketHideout" if done("poster") else "HideRocketHideout"))
	if name=="RocketHideout_B4F":
		var cleared=done("trainer:RocketHideout_B4F_EventScript_Grunt2") and done("trainer:RocketHideout_B4F_EventScript_Grunt3")
		geometry(name+"_EventScript_"+("RemoveBarrier" if cleared else "SetBarrier"))
	if name=="VermilionCity_Gym":
		if int(a.Story.state(a).get("switch",0))==2: geometry(name+"_EventScript_SetBeamsOff")
		elif int(a.Story.state(a).get("switch",0))==1: geometry(name+"_EventScript_SetOneBeamOff")
	if name.begins_with("PokemonMansion_"):
		geometry("PokemonMansion_EventScript_"+("PressSwitch_" if state().mansion else "ResetSwitch_")+name.trim_prefix("PokemonMansion_"))
	if name=="CinnabarIsland_Gym":
		for i in range(1,7):
			if done("quiz"+str(i)) or a.Finale.has(a,"volcano"): geometry(name+"_EventScript_OpenDoor"+str(i))
	if name.begins_with("SilphCo_"):
		for label in catalog[w.current].patches:
			if str(label).begins_with("EventScript_Close"):
				geometry(str(label).replace("Close","Open") if done(w.current+str(label)) else label)
	if name.begins_with("VictoryRoad_"):
		for label in catalog[w.current].patches:
			if "SetRockBarrier" in label:
				var open=str(label).replace("SetRockBarrier","FloorSwitch")
				geometry(open if done(open) else label)

func collision(p: Vector2) -> int:
	var cell=Vector2i(floori(p.x/w.TILE),floori(p.y/w.TILE))
	var index=cell.y*int(w.room().width)+cell.x
	if index>=0 and index<catalog[w.current].behavior.size():
		var behavior=int(catalog[w.current].behavior[index])
		if behavior==0x13: return 1 # Waterfall is traversed only through its field action.
		if behavior in [0x10,0x11,0x12,0x15,0x50,0x51,0x52,0x53] and not a.field.can_use("surf"): return 1
	for item in catalog[w.current].items:
		if Vector2i(int(item.x),int(item.y))==cell and not done(w.current+"item"+str(item.id)): return 1
	for rock in rocks():
		if Vector2i(rock.x,rock.y)==cell: return 1
	for o in w.room().objects:
		var gfx=str(o.graphics_id); var script=str(o.get("script",""))
		var present=not a.field.hidden(o) and not (script.ends_with("EeveeBall") and done("gift:eevee"))
		if present and (gfx.contains("FOSSIL") or gfx.contains("OLD_AMBER") or script.ends_with("EeveeBall") or gfx in ["OBJ_EVENT_GFX_ARTICUNO","OBJ_EVENT_GFX_ZAPDOS","OBJ_EVENT_GFX_MEWTWO","OBJ_EVENT_GFX_MOLTRES"]) and Vector2i(int(o.x),int(o.y))==cell: return 1
		if "Snorlax" in str(o.get("script","")) and not done("snorlax:"+w.current) and Vector2i(int(o.x),int(o.y))==cell: return 1
		if "ROCK_SMASH_ROCK" in str(o.graphics_id) and not done(a.field.smash_key(o)) and Vector2i(int(o.x),int(o.y))==cell: return 1
		if "CUT_TREE" in str(o.graphics_id) and not done(w.current+"tree"+str(o.x)+":"+str(o.y)) and Vector2i(int(o.x),int(o.y))==cell: return 1
	if patches.has(cell): return int(patches[cell].solid)
	return -1

func rocks() -> Array:
	var result=[]
	for i in range(w.room().objects.size()):
		var o=w.room().objects[i]
		if not "BOULDER" in str(o.graphics_id): continue
		var key=w.current+":"+str(i)
		if done("fallen:"+key): continue
		if w.current=="MAP_VICTORY_ROAD_2F" and str(o.get("flag","")).contains("VICTORY_ROAD_2F_BOULDER") and not done("arrived:"+key): continue
		if w.current.begins_with("MAP_SEAFOAM_ISLANDS_"):
			var initial=w.current=="MAP_SEAFOAM_ISLANDS_1F" or (w.current=="MAP_SEAFOAM_ISLANDS_B3F" and not str(o.get("flag","")).ends_with("_1") and not str(o.get("flag","")).ends_with("_2"))
			if not initial and not done("arrived:"+key): continue
		var at=state().rocks.get(key,{"x":o.x,"y":o.y})
		result.append({"x":int(at.x),"y":int(at.y),"key":key})
	return result

func push(rock):
	if not a.field.can_use("strength"):
		a.dialog="A heavy boulder. Obtain Power Gloves from the Warden and the Rainbow Badge."; return
	var delta=point(rock)-a.position_world
	var step=Vector2i(signi(int(delta.x)),0) if absf(delta.x)>absf(delta.y) else Vector2i(0,signi(int(delta.y)))
	var next=Vector2i(rock.x,rock.y)+step
	if w.blocked((Vector2(next)+Vector2.ONE*0.5)*w.TILE):
		a.dialog="The boulder cannot move that way. M lets you reset this room's boulders."; return
	state().rocks[rock.key]={"x":next.x,"y":next.y}
	if fall_boulder(rock,next): refresh(); a.save(); return
	a.sevii.boulder_puzzle()
	for trigger in catalog[w.current].triggers:
		if "FloorSwitch" in str(trigger.get("script","")) and next==Vector2i(int(trigger.x),int(trigger.y)):
			finish(trigger.script)
			a.Finale.state(a)["victory_boulder"]=true
			a.dialog="The boulder presses the floor switch. The rock barrier opens!"
	refresh(); a.save()

func reset_rocks():
	if w.current.begins_with("MAP_VICTORY_ROAD_"):
		for key in state().done.keys():
			if str(key).begins_with("fallen:MAP_VICTORY_ROAD") or str(key).begins_with("arrived:MAP_VICTORY_ROAD"): state().done.erase(key)
		for key in state().rocks.keys():
			if str(key).begins_with("MAP_VICTORY_ROAD"): state().rocks.erase(key)
	if w.current.begins_with("MAP_SEAFOAM_ISLANDS_"):
		for key in state().done.keys():
			if str(key).begins_with("fallen:MAP_SEAFOAM") or str(key).begins_with("arrived:MAP_SEAFOAM") or str(key).begins_with("calm:MAP_SEAFOAM"): state().done.erase(key)
		for key in state().rocks.keys():
			if str(key).begins_with("MAP_SEAFOAM"): state().rocks.erase(key)
	for key in state().rocks.keys():
		if str(key).begins_with(w.current+":"): state().rocks.erase(key)
	a.clear_ui(); a.dialog="Boulders returned to their starting positions. Victory Road switches stay open; Seafoam resets all floors."
	refresh(); a.save()

func trash(index: int):
	var s=a.Story.state(a)
	if int(s.get("switch",0))>=2: a.dialog="Both electric locks are already off."; return
	if not state().has("trash_first"): state().trash_first=randi_range(1,15)
	var phase=int(s.get("switch",0))
	if phase==0 and index==int(state().trash_first):
		s["switch"]=1
		var adjacent=[]
		for candidate in range(1,16):
			if absi((candidate-1)%5-(index-1)%5)+absi(int((candidate-1)/5)-int((index-1)/5))==1: adjacent.append(candidate)
		state().trash_second=adjacent.pick_random()
		a.dialog="First lock off! The second switch is in an adjacent bin."
	elif phase==1 and index==int(state().get("trash_second",0)):
		s["switch"]=2; a.dialog="Both locks are off! The electric barrier is open."
	else:
		a.dialog="Only trash." if phase==0 else "Wrong bin! Both locks reset. Search again."
		s["switch"]=0
		if phase==1: state().trash_first=randi_range(1,15)
	refresh(); a.save()

func quiz(index: int):
	if done("quiz"+str(index)): a.dialog="Quiz cleared. The door is open."; return
	a.panel("CINNABAR / QUIZ "+str(index))
	a.ui_label(QUIZZES[index-1][0],Vector2(180,270),22)
	a.ui_button("YES",Vector2(200,400),Vector2(360,65),answer.bind(index,true))
	a.ui_button("NO",Vector2(650,400),Vector2(360,65),answer.bind(index,false))

func answer(index: int, yes: bool):
	a.clear_ui()
	if yes==QUIZZES[index-1][1]:
		finish("quiz"+str(index)); a.dialog="Correct! The door opens."
		var complete=true
		for i in range(1,7): complete=complete and done("quiz"+str(i))
		if complete: a.Finale.state(a)["quiz"]=true
	else:
		var trainer=["Quinn","Avery","Ramon","Derek","Dusty","Zac"][index-1]
		var candidates=w.room().objects.filter(func(o):return o.has("battle") and str(o.battle.name).to_lower()==trainer.to_lower())
		if not candidates.is_empty():
			var o=candidates[0]
			a.begin_battle("world_"+str(o.script),o.battle.party.map(func(m):return m[0]),o.battle.party.map(func(m):return m[1]))
		else: a.dialog="Incorrect. Reconsider your answer and try again."
	refresh(); a.save()

func pickup(item):
	var key=w.current+"item"+str(item.id)
	if done(key): return
	var id=str(item.item)
	var story={"CARD_KEY":"card_key","SECRET_KEY":"secret_key","LIFT_KEY":"lift_key","GOLD_TEETH":"gold_teeth"}
	if id=="HM07": a.field.finish("field:waterfall")
	elif story.has(id): a.Finale.state(a)[story[id]]=true
	elif id.begins_with("TM") and a.inventory.book.tms.has(id): a.data.tms[id]=mini(999,int(a.data.tms.get(id,0))+1)
	elif id in ["POKE_BALL","GREAT_BALL","ULTRA_BALL"]: a.data.balls=mini(999,int(a.data.balls)+1)
	else:
		var bag_id=id.to_lower().replace("_","")
		if not a.inventory.ITEMS.has(bag_id):
			a.dialog=id.replace("_"," ")+": this item is not usable in this build yet."; return
		if int(a.data.bag.get(bag_id,0))>=999: a.dialog="No room for more of this item."; return
		a.data.bag[bag_id]=int(a.data.bag.get(bag_id,0))+1
	finish(key); a.dialog="Found "+id.replace("_"," ")+"!"; a.save()

func interact() -> bool:
	if str(w.room().name).ends_with("_Elevator"):
		elevator(); return true
	var nearby=[]
	for sign in w.room().signs:
		var script=str(sign.get("script",""))
		if "_Poster" in script or "TrashCan" in script or "_Quiz" in script or "_Statue" in script or (str(w.room().name).begins_with("SilphCo_") and "_Door" in script): nearby.append({"pos":point(sign),"kind":"sign","data":sign})
	for item in catalog[w.current].items:
		if not done(w.current+"item"+str(item.id)): nearby.append({"pos":point(item),"kind":"item","data":item})
	for rock in rocks(): nearby.append({"pos":point(rock),"kind":"rock","data":rock})
	for o in w.room().objects:
		if "ROCK_SMASH_ROCK" in str(o.graphics_id) and not done(a.field.smash_key(o)): nearby.append({"pos":point(o),"kind":"smash","data":o})
		if "CUT_TREE" in str(o.graphics_id) and not done(w.current+"tree"+str(o.x)+":"+str(o.y)): nearby.append({"pos":point(o),"kind":"tree","data":o})
	# Object interaction uses the adjacent tile in front, never a diagonal or through a wall.
	nearby=nearby.filter(func(event):return Vector2(event.pos).distance_to(a.position_world+w.heading*w.TILE)<w.TILE*0.2)
	nearby.sort_custom(func(x,y):return a.position_world.distance_squared_to(x.pos)<a.position_world.distance_squared_to(y.pos))
	if nearby.is_empty() or a.position_world.distance_to(nearby[0].pos)>w.TILE*1.45: return false
	var event=nearby[0]; var o=event.data
	match event.kind:
		"item": pickup(o)
		"rock": push(o)
		"smash": a.field.smash(o)
		"tree":
			if a.field.can_use("cut"):
				finish(w.current+"tree"+str(o.x)+":"+str(o.y)); a.dialog="Cut cleared the tree!"; a.save()
			else: a.dialog="A small tree blocks the way. Obtain Cut Shears from the Captain and the Cascade Badge."
		"sign":
			var script=str(o.script)
			if "_Poster" in script:
				finish("poster"); refresh(); a.dialog="A hidden switch! Stairs to the Rocket Hideout appear."; a.save()
			elif "TrashCan" in script: trash(int(script.split("TrashCan")[1]))
			elif "_Quiz" in script: quiz(int(script.split("_Quiz")[1].left(1)))
			elif "_Statue" in script:
				state().mansion=not state().mansion; a.Finale.state(a)["mansion_switch"]=true
				refresh(); a.dialog="The statue's eyes change. Some doors open; others close."; a.save()
			elif "_Door" in script:
				if not a.Finale.has(a,"card_key"): a.dialog="Locked. Find the Card Key on Silph Co. 5F."
				else:
					finish(w.current+"EventScript_Close"+str(w.room().name).trim_prefix("SilphCo_")+"Door"+script.split("_Door")[1])
					refresh(); a.dialog="Card Key accepted. Door unlocked."; a.save()
	return true

func draw():
	if w.current=="MAP_FOUR_ISLAND_ICEFALL_CAVE_1F":
		for key in state().done:
			if str(key).begins_with("sevii:ice:"):
				var coordinates=str(key).split(":"); var at=(Vector2(int(coordinates[2]),int(coordinates[3]))+Vector2.ONE*0.5)*w.TILE
				a.draw_polyline(PackedVector2Array([at+Vector2(-18,-18),at+Vector2(6,-4),at+Vector2(-4,8),at+Vector2(18,18)]),Color("466b92"),3)
	for tile in patches.values():
		if not textures.has(tile.image): textures[tile.image]=ImageTexture.create_from_image(Image.load_from_file(tile.image))
		a.draw_texture_rect(textures[tile.image],Rect2(Vector2(tile.x,tile.y)*w.TILE,Vector2.ONE*w.TILE),false)
	for o in w.room().objects:
		if "ROCK_SMASH_ROCK" in str(o.graphics_id) and not done(a.field.smash_key(o)):
			var p=point(o)
			a.draw_circle(p+Vector2(0,7),18,Color("343d40"))
			a.draw_circle(p,17,Color("ad9980"))
			a.draw_polyline(PackedVector2Array([p+Vector2(-4,-15),p+Vector2(4,-5),p+Vector2(-3,2),p+Vector2(7,13)]),Color("514b48"),3)
		if "CUT_TREE" in str(o.graphics_id) and not done(w.current+"tree"+str(o.x)+":"+str(o.y)):
			var p=point(o)
			a.draw_rect(Rect2(p+Vector2(-5,0),Vector2(10,20)),Color("947347"))
			a.draw_circle(p-Vector2(0,8),21,Color("397e43"))
			a.draw_circle(p-Vector2(5,14),13,Color("6da950"))
	for rock in rocks():
		var p=point(rock)
		a.draw_circle(p+Vector2(0,9),22,Color("343d40"))
		a.draw_circle(p,21,Color("92918a"))
		a.draw_arc(p,16,3.5,5.8,12,Color("c9c7ae"),4)
	for item in catalog[w.current].items:
		if done(w.current+"item"+str(item.id)): continue
		var p=point(item)
		a.draw_circle(p,10,Color("f5eee0")); a.draw_arc(p,9,PI,TAU,12,Color("e75151"),9)
		a.draw_line(p-Vector2(10,0),p+Vector2(10,0),Color("25333c"),3)


func allow_door(destination: String) -> bool:
	if not a.sevii.gate(destination): return false
	if destination.begins_with("MAP_SAFARI_ZONE") and not a.services.state().safari:
		a.services.safari_menu(); return false
	if destination=="MAP_POKEMON_TOWER_7F" and a.field.ghost(): return false
	if destination in LEAGUE:
		var need=a.Finale.missing(a,["eight","league_rival"])
		if need!="": a.dialog="League entry requires "+need+"."; return false
		if LEAGUE.find(destination)>int(a.Finale.state(a).get("league",0)):
			a.dialog="Defeat the trainer in this chamber before continuing."; return false
	if destination=="MAP_POKEMON_LEAGUE_HALL_OF_FAME" and not a.Finale.has(a,"champion"):
		a.dialog="Defeat Champion Blue first."; return false
	if destination=="MAP_ROCKET_HIDEOUT_B1F" and w.current=="MAP_CELADON_CITY_GAME_CORNER" and not done("poster"):
		a.dialog="Search the poster for a hidden switch."; return false
	if destination=="MAP_VERMILION_CITY_GYM" and not a.field.can_use("cut"):
		a.dialog="The Gym entrance requires Cut Shears and the Cascade Badge."; return false
	var needed={"MAP_SS_ANNE_1F_CORRIDOR":"ticket","MAP_CINNABAR_ISLAND_GYM":"secret_key","MAP_CERULEAN_CAVE_1F":"champion"}.get(destination,"")
	if needed!="" and not (a.Story.state(a).get(needed,false) or a.Finale.has(a,needed)):
		a.dialog="This entrance requires "+str(needed).replace("_"," ")+"."; return false
	if destination=="MAP_SAFFRON_CITY_GYM" and not a.Finale.has(a,"silph_saved"):
		a.dialog="Team Rocket blocks the Gym. Rescue Silph Co. first."; return false
	return true


func elevator():
	var name=str(w.room().name)
	if name.begins_with("RocketHideout") and not a.Finale.has(a,"lift_key"):
		a.dialog="The lift requires the Lift Key."; return
	var prefix=name.trim_suffix("Elevator")
	var destinations=[]
	for id in w.maps:
		if str(w.maps[id].name).begins_with(prefix) and not str(w.maps[id].name).ends_with("Elevator"):
			if w.maps[id].warps.any(func(door):return door.dest_map==w.current): destinations.append(id)
	destinations.sort()
	var list=a.inventory.page("ELEVATOR / choose a floor")
	for id in destinations:
		var button=Button.new(); button.text=w.maps[id].name
		button.pressed.connect(elevator_go.bind(id)); list.add_child(button)
	var cancel=Button.new(); cancel.text="Cancel"; cancel.pressed.connect(a.clear_ui); list.add_child(cancel)

func elevator_go(id: String):
	var exits=w.maps[id].warps.filter(func(door):return door.dest_map==w.current)
	if exits.is_empty(): return
	a.clear_ui(); w.enter(id,point(exits[0])+Vector2(0,w.TILE))

func battle_reward(kind: String, victory: bool):
	if not victory or not kind.begins_with("world_"): return
	var script=kind.trim_prefix("world_")
	finish("trainer:"+script)
	if script.begins_with("CinnabarIsland_Gym_"):
		for i in range(6):
			if script.ends_with("_"+["Quinn","Avery","Ramon","Derek","Dusty","Zac"][i]): finish("quiz"+str(i+1))
		var complete=true
		for i in range(1,7): complete=complete and done("quiz"+str(i))
		if complete: a.Finale.state(a)["quiz"]=true
	refresh()


func tests():
	var before=a.data.duplicate(true)
	var old=w.current
	var old_position=a.position_world
	var old_dialog=a.dialog
	var old_allowed=a.save_allowed
	a.save_allowed=false
	a.data.erase("world_events")
	a.inventory.migrate()
	var old_heading=w.heading
	w.current="MAP_MT_MOON_1F"; refresh()
	var item=catalog[w.current].items.filter(func(i):return i.item=="POTION")[0]
	var item_at=point(item)
	a.c.check(w.blocked(item_at),"Uncollected item ball blocks its tile")
	a.position_world=item_at+Vector2.DOWN*w.TILE; w.heading=Vector2.DOWN
	interact()
	a.c.check(not done(w.current+"item"+str(item.id)),"Cannot collect an item behind the player")
	a.position_world=item_at+Vector2.ONE*w.TILE; w.heading=Vector2.UP
	interact()
	a.c.check(not done(w.current+"item"+str(item.id)),"Cannot collect an item diagonally")
	a.position_world=item_at+Vector2.DOWN*w.TILE; w.heading=Vector2.UP
	var count=int(a.data.bag.get("potion",0))
	interact()
	a.c.check(not w.blocked(item_at) and int(a.data.bag.get("potion",0))==count+1,"Facing item pickup grants it and frees the tile")
	pickup(item)
	a.c.check(int(a.data.bag.get("potion",0))==count+1,"Collected items cannot be picked up twice")
	w.current="MAP_CELADON_CITY"; refresh()
	var tree=w.room().objects.filter(func(o):return str(o.graphics_id).contains("CUT_TREE") and int(o.x)>=0)[0]
	var tree_at=point(tree)
	a.Story.state(a)["cut"]=false
	a.position_world=tree_at+Vector2.DOWN*w.TILE; w.heading=Vector2.UP
	interact()
	a.c.check(w.blocked(tree_at),"Tree remains solid without Cut")
	a.Story.state(a)["cut"]=true; a.data.cascade=true
	interact()
	a.c.check(not w.blocked(tree_at),"Cut removes the tree collision")
	w.current="MAP_CERULEAN_CAVE_1F"; refresh()
	var smash=w.room().objects.filter(func(o):return str(o.graphics_id).contains("ROCK_SMASH_ROCK"))[0]
	a.c.check(w.blocked(point(smash)),"Rock Smash rocks block walking")
	a.c.check(not w.actors().any(func(o):return str(o.graphics_id).contains("ROCK_SMASH_ROCK")),"Rock Smash rocks never render as fallback people")
	w.current="MAP_VICTORY_ROAD_1F"; refresh()
	var solid_rock=rocks()[0]
	a.c.check(w.blocked(point(solid_rock)),"Strength boulder blocks its current position")
	var occupied=point(solid_rock)
	var item_block=catalog[w.current].items[0]
	state().rocks[solid_rock.key]={"x":int(item_block.x)-1,"y":int(item_block.y)}
	a.position_world=point(item_block)-Vector2(2*w.TILE,0)
	a.Finale.state(a)["strength"]=true; a.Finale.state(a)["rainbow"]=true
	push(rocks().filter(func(r):return r.key==solid_rock.key)[0])
	a.c.check(int(state().rocks[solid_rock.key].x)==int(item_block.x)-1,"Strength cannot push onto an item ball")
	state().rocks.erase(solid_rock.key)
	a.c.check(w.blocked(occupied),"Restored boulder retains collision")
	w.heading=old_heading
	w.current="MAP_VERMILION_CITY_GYM"
	a.Story.state(a)["switch"]=0
	state().trash_first=7
	trash(7)
	a.c.check(int(a.Story.state(a).switch)==1,"Trash puzzle finds first lock")
	var second=int(state().trash_second)
	a.c.check(second in [2,6,8,12],"Second trash switch is orthogonally adjacent")
	trash(15)
	a.c.check(int(a.Story.state(a).switch)==0,"Wrong second trash switch resets both locks")
	state().trash_first=7; trash(7); trash(int(state().trash_second))
	a.c.check(collision(Vector2(5.5,6.5)*w.TILE)==0,"Surge barrier physically opens")
	w.current="MAP_CINNABAR_ISLAND_GYM"
	for i in range(1,7): answer(i,QUIZZES[i-1][1])
	a.c.check(a.Finale.has(a,"quiz") and patches.size()>25,"All six quiz doors open and permit Blaine")
	w.current="MAP_POKEMON_MANSION_1F"
	state().mansion=false; refresh()
	var closed=collision(Vector2(23.5,10.5)*w.TILE)
	state().mansion=true; refresh()
	a.c.check(closed==1 and collision(Vector2(23.5,10.5)*w.TILE)==0,"Mansion toggle changes actual passage collision")
	w.current="MAP_SILPH_CO_5F"; refresh()
	var label="EventScript_Close5FDoor1"
	var edits=catalog[w.current].patches[label]
	var opened=catalog[w.current].patches["EventScript_Open5FDoor1"]
	var tile=edits.filter(func(t):return int(t.solid)==1 and opened.any(func(o):return o.x==t.x and o.y==t.y and int(o.solid)==0))[0]
	var pos=point(tile)
	a.c.check(collision(pos)==1,"Silph door initially blocks travel")
	finish(w.current+label); refresh()
	a.c.check(collision(pos)==0,"Unlocked Silph door permits travel")
	var saved=JSON.parse_string(JSON.stringify(a.data))
	a.c.check(saved.world_events.done[w.current+label],"Event progress survives JSON save round trip")
	w.current="MAP_VICTORY_ROAD_1F"
	a.Finale.state(a)["strength"]=true; a.Finale.state(a)["rainbow"]=true
	var rock=rocks()[0]
	state().rocks[rock.key]={"x":19,"y":16}
	a.position_world=Vector2(18.5,16.5)*w.TILE
	refresh(); push(rocks()[0])
	a.c.check(done("VictoryRoad_1F_EventScript_FloorSwitch"),"Strength boulder activates original floor switch")
	a.c.check(collision(Vector2(12.5,14.5)*w.TILE)==0,"Victory Road floor switch removes rock barrier")
	w.current="MAP_VICTORY_ROAD_2F"; refresh()
	a.c.check(rocks().size()==2,"Victory Road lower boulder stays hidden until it falls")
	w.current="MAP_VICTORY_ROAD_3F"; refresh()
	var falling=rocks().filter(func(r):return int(r.x)==33 and int(r.y)==18)[0]
	a.c.check(fall_boulder(falling,Vector2i(34,18)),"Victory Road upper boulder falls through the original hole")
	w.current="MAP_VICTORY_ROAD_2F"; refresh()
	a.c.check(rocks().size()==3,"Victory Road fallen boulder arrives on 2F")
	reset_rocks()
	a.c.check(rocks().size()==2,"Victory Road reset restores both floors without duplicating the boulder")
	w.current="MAP_SEAFOAM_ISLANDS_1F"
	var sea_rock=rocks()[0]
	a.c.check(fall_boulder(sea_rock,Vector2i(21,8)),"Seafoam boulder falls through original hole")
	a.c.check(done("fallen:"+str(sea_rock.key)),"Fallen boulder disappears from upper floor")
	w.current="MAP_SEAFOAM_ISLANDS_B1F"
	a.c.check(rocks().size()==1,"Fallen boulder appears on next Seafoam floor")
	w.current="MAP_SEAFOAM_ISLANDS_B3F"
	var lower_rocks=rocks()
	a.c.check(fall_boulder(lower_rocks[0],Vector2i(6,18)) and fall_boulder(lower_rocks[1],Vector2i(9,18)),"Seafoam lower boulders descend through both holes")
	a.c.check(done("calm:MAP_SEAFOAM_ISLANDS_B4F"),"Two lower boulders stop Seafoam bottom-floor current")
	w.current="MAP_SEAFOAM_ISLANDS_B4F"; refresh()
	a.c.check(not patches.is_empty(),"Stopped current uses original calm-water layout")
	a.data.badge=true; a.data.cascade=true; a.Story.state(a)["thunder"]=true
	for badge in a.Finale.BADGES: a.Finale.state(a)[badge]=true
	a.Finale.state(a)["league_rival"]=true; a.Finale.state(a)["league"]=0
	a.c.check(not allow_door(LEAGUE[1]),"League prevents skipping Lorelei")
	a.Finale.state(a)["league"]=1
	a.c.check(allow_door(LEAGUE[1]),"Lorelei victory unlocks Bruno chamber")
	w.current="MAP_ROCKET_HIDEOUT_B2F"
	var arrows=catalog[w.current].behavior
	var arrow_index=-1
	for i in range(arrows.size()):
		if int(arrows[i])==0x54: arrow_index=i; break
	a.c.check(arrow_index>=0,"Rocket Hideout imports original spin tiles")
	if arrow_index>=0:
		a.position_world=Vector2(arrow_index%int(w.room().width)+0.5,int(arrow_index/int(w.room().width))+0.5)*w.TILE
		tick(0.01)
		a.c.check(spin==Vector2.RIGHT,"Arrow tile starts forced movement")
	spin=Vector2.ZERO; flowing=false; spin_clock=0
	for mid in catalog:
		for action in catalog[mid].patches.values():
			for edit in action: a.c.check(FileAccess.file_exists(edit.image),"Event metatile image exists")
	a.data=before; a.save_allowed=old_allowed; a.position_world=old_position; a.dialog=old_dialog
	w.current=old; refresh()


func tick(dt: float) -> bool:
	var cell=Vector2i(floori(a.position_world.x/w.TILE),floori(a.position_world.y/w.TILE))
	var index=cell.y*int(w.room().width)+cell.x
	var behavior=int(catalog[w.current].behavior[index]) if index>=0 and index<catalog[w.current].behavior.size() else 0
	var arrows={0x54:Vector2.RIGHT,0x55:Vector2.LEFT,0x56:Vector2.UP,0x57:Vector2.DOWN}
	if flowing and behavior not in [0x50,0x51,0x52,0x53]: spin=Vector2.ZERO; flowing=false
	if arrows.has(behavior): spin=arrows[behavior]; flowing=false
	elif behavior in [0x50,0x51,0x52,0x53] and w.current.begins_with("MAP_SEAFOAM") and not done("calm:"+w.current): spin=[Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN][behavior-0x50]; flowing=true
	elif behavior==0x58: spin=Vector2.ZERO
	if spin==Vector2.ZERO: return false
	spin_clock+=dt
	if spin_clock>=0.10:
		spin_clock=0
		var target=(Vector2(cell)+Vector2.ONE*0.5+spin)*w.TILE
		if w.blocked(target): spin=Vector2.ZERO
		else: a.position_world=target; w.heading=spin
	return true


func npc_interact(npc) -> bool:
	if a.field.npc(npc): return true
	var script=str(npc.get("script",""))
	if w.current in LEAGUE and str(npc.get("graphics_id","")).trim_prefix("OBJ_EVENT_GFX_") in ["LORELEI","BRUNO","AGATHA","LANCE","BLUE"]:
		if LEAGUE.find(w.current)==int(a.Finale.state(a).get("league",0)): a.Finale.start_league(a)
		else: a.dialog="This chamber is cleared. Continue through the next door."
		return true
	if w.current=="MAP_VIRIDIAN_CITY_MART" and not done("parcel_received"):
		finish("parcel_received"); a.dialog="The clerk gives you Oak's Parcel. Take it back to Professor Oak in Pallet Town."; a.save(); return true
	if "PROF_OAK" in str(npc.get("graphics_id","")) and a.data.starter!=0 and done("parcel_received") and not done("parcel_delivered"):
		finish("parcel_delivered"); a.dialog="Oak receives his parcel and gives you a Pokedex for your journey!"; a.save(); return true
	if "Snorlax" in script:
		var key="snorlax:"+w.current
		if done(key): a.dialog="The road is clear."; return true
		if not a.Finale.has(a,"flute"): a.dialog="Snorlax is asleep. Find Mr. Fuji and the Poke Flute."; return true
		a.begin_battle("wild",[143],[30])
		if a.in_battle: state()["pending_snorlax"]=key
		return true
	return false

func result(kind: String, victory: bool, caught: bool):
	a.field.battle_result(kind,victory,caught)
	if kind=="wild" and state().has("pending_snorlax"):
		if victory or caught:
			finish(str(state().pending_snorlax)); a.Finale.state(a)["snorlax"]=true
		state().erase("pending_snorlax")
	if victory and kind=="world_RocketHideout_B4F_EventScript_Grunt1": a.Finale.state(a)["lift_key"]=true


func valid(data: Dictionary) -> bool:
	if not data.has("world_events"): return true
	var s=data.world_events
	if not s is Dictionary or not s.get("done") is Dictionary or not s.get("rocks") is Dictionary or not s.get("mansion") is bool: return false
	for flag in s.done.values():
		if not flag is bool: return false
	for location in s.rocks.values():
		if not location is Dictionary: return false
		for axis in ["x","y"]:
			if not (location.get(axis) is int or location.get(axis) is float): return false
			if not is_finite(float(location[axis])) or location[axis]<0 or location[axis]>500: return false
	for key in ["trash_first","trash_second"]:
		if s.has(key) and (not (s[key] is float or s[key] is int) or s[key]<1 or s[key]>15): return false
	return true


func fall_boulder(rock, cell: Vector2i) -> bool:
	if not w.current.begins_with("MAP_SEAFOAM_ISLANDS_") and w.current!="MAP_VICTORY_ROAD_3F": return false
	var index=cell.y*int(w.room().width)+cell.x
	if index<0 or index>=catalog[w.current].behavior.size() or int(catalog[w.current].behavior[index])!=0x66: return false
	for warp in w.room().warps:
		if Vector2i(int(warp.x),int(warp.y))!=cell or not w.maps.has(warp.dest_map): continue
		var destination=w.maps[warp.dest_map]
		var arrival=destination.warps[int(warp.dest_warp_id)]
		var nearest=-1; var distance=INF
		for i in range(destination.objects.size()):
			var obj=destination.objects[i]
			if not "BOULDER" in str(obj.graphics_id): continue
			var d=point(obj).distance_squared_to(point(arrival))
			if d<distance: distance=d; nearest=i
		if nearest<0: return false
		finish("fallen:"+str(rock.key))
		var key=str(warp.dest_map)+":"+str(nearest)
		finish("arrived:"+key)
		state().done.erase("fallen:"+key)
		var obj=destination.objects[nearest]
		state().rocks[key]={"x":obj.x,"y":obj.y}
		if warp.dest_map in ["MAP_SEAFOAM_ISLANDS_B3F","MAP_SEAFOAM_ISLANDS_B4F"]:
			var both=true
			for i in range(destination.objects.size()):
				var flag=str(destination.objects[i].get("flag",""))
				if "BOULDER" in flag and (flag.ends_with("_1") or flag.ends_with("_2")): both=both and done("arrived:"+str(warp.dest_map)+":"+str(i))
			if both: finish("calm:"+str(warp.dest_map))
		a.dialog="The boulder drops to the floor below. Push it onto the switch on 2F." if w.current=="MAP_VICTORY_ROAD_3F" else "The boulder drops to the floor below. Two boulders block each current."
		return true
	return false
