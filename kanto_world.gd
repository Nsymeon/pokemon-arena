extends RefCounted

const TILE=48.0
const LEGACY=["PalletTown","Route1","ViridianCity","ViridianForest","PewterCity","Route3","MtMoon_1F","Route4","CeruleanCity","Route5","SaffronCity","Route6","VermilionCity","Route8","LavenderTown","Route7","CeladonCity","Route17","FuchsiaCity","Route19","CinnabarIsland","Route21_North","Route22","IndigoPlateau_Exterior","Route9","Route12","Route24","Route25","SSAnne_1F_Corridor","VermilionCity_Gym","CeladonCity_Gym","RocketHideout_B4F","PokemonTower_7F","FuchsiaCity_Gym","SafariZone_Center","FuchsiaCity_WardensHouse","SilphCo_11F","SaffronCity_Gym","SaffronCity_Dojo","PokemonMansion_B1F","CinnabarIsland_Gym","ViridianCity_Gym","VictoryRoad_3F","PokemonLeague_LoreleisRoom","SeafoamIslands_1F","PowerPlant","DiglettsCave_B1F","CeruleanCave_1F","UndergroundPath_NorthSouthTunnel","UndergroundPath_EastWestTunnel","Route11","Route2","Route10","CinnabarIsland_PokemonLab_Entrance","VermilionCity_PokemonFanClub","PokemonLeague_HallOfFame","SafariZone_SecretHouse"]
var maps: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/maps.json"))
var names={}
var textures={}
var a
var enabled=false
var current="MAP_PALLET_TOWN"
var actor_paths: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/actors.json"))
var actor_textures={}
var heading=Vector2.DOWN
var stepping=false
var jumping=false
var jump_start=Vector2.ZERO
var pending_interact=false
var step_target=Vector2.ZERO
var events=preload("res://kanto_events.gd").new()
var scenes=preload("res://kanto_scenes.gd").new()
var warp_latch=""

func install(adventure):
	a=adventure
	events.install(self)
	scenes.install(self)
	for id in maps: names[maps[id].name]=id

func activate():
	a.field.riding=false
	a.field.pending_static=""
	pending_interact=false
	scenes.reset()
	warp_latch=""
	stepping=false
	jumping=false
	enabled=true
	current=a.data.get("world_map",names.get(LEGACY[int(a.data.map)],"MAP_PALLET_TOWN"))
	if not maps.has(current): current="MAP_PALLET_TOWN"
	events.refresh()
	if not a.data.has("world_map"):
		a.position_world=walkable(Vector2(12,16)*TILE,true)
	else: a.position_world=walkable(Vector2(a.data.x,a.data.y),true)
	a.data["world_map"]=current
	if a.field.outdoor(): a.field.finish("visited:"+current)
	events.refresh()
	update_camera()

func room() -> Dictionary:
	return maps[current]

func size() -> Vector2:
	return Vector2(room().width,room().height)*TILE

func occupied_tiles() -> Dictionary:
	# Use the same visible actors and scene positions as rendering; hidden NPCs leave no obstacle.
	var occupied={}
	for npc in actors(): occupied[Vector2i((Vector2(npc.pos)/TILE).floor())]=true
	for npc in quest_actors(): occupied[Vector2i((Vector2(npc[0])/TILE).floor())]=true
	return occupied

func blocked(p: Vector2) -> bool:
	return terrain_blocked(p) or occupied_tiles().has(Vector2i((p/TILE).floor()))

func terrain_blocked(p: Vector2) -> bool:
	var x=floori(p.x/TILE); var y=floori(p.y/TILE)
	if x<0 or y<0 or x>=room().width or y>=room().height: return true
	var override=events.collision(p)
	if override>=0: return override!=0
	return (int(room().cells[y*int(room().width)+x])&0xC00)!=0

func walkable(p: Vector2, avoid_actors: bool=false) -> Vector2:
	# Search nearby rings instead of scanning every map tile for each NPC every frame.
	# Keep exact nearest-distance selection and consult live puzzle collision.
	# NPC placement uses terrain only to avoid recursive actor placement. Arrivals also avoid people.
	var occupied=occupied_tiles() if avoid_actors else {}
	var width=int(room().width); var height=int(room().height)
	var origin=Vector2i(clampi(floori(p.x/TILE),0,width-1),clampi(floori(p.y/TILE),0,height-1))
	var center=(Vector2(origin)+Vector2.ONE*0.5)*TILE
	var offset=maxf(absf(p.x-center.x),absf(p.y-center.y))
	var best=Vector2(TILE*1.5,TILE*1.5)
	var distance=INF
	for radius in range(maxi(width,height)):
		for y in range(maxi(0,origin.y-radius),mini(height-1,origin.y+radius)+1):
			for x in range(maxi(0,origin.x-radius),mini(width-1,origin.x+radius)+1):
				if maxi(absi(x-origin.x),absi(y-origin.y))!=radius: continue
				var candidate=Vector2(x+0.5,y+0.5)*TILE
				var squared=candidate.distance_squared_to(p)
				if squared>distance: continue
				if not terrain_blocked(candidate) and not occupied.has(Vector2i(x,y)) and (squared<distance or candidate.y<best.y or (candidate.y==best.y and candidate.x<best.x)):
					best=candidate; distance=squared
		# Any unvisited center is at least this far away along one axis.
		var remaining=maxf(0,(radius+1)*TILE-offset)
		if distance<remaining*remaining: return best
	return best

func update_camera():
	var extent=size()-Vector2(1280,700)
	a.camera=Vector2(clampf(a.position_world.x-640,minf(0,extent.x/2),maxf(0,extent.x)),clampf(a.position_world.y-350,minf(0,extent.y/2),maxf(0,extent.y)))

func enter(id: String, at: Vector2):
	if not maps.has(id): return
	var previous=current
	var previous_position=a.position_world
	if current in events.LEAGUE and id not in events.LEAGUE and id!="MAP_POKEMON_LEAGUE_HALL_OF_FAME": a.Finale.state(a)["league"]=0
	scenes.reset()
	pending_interact=false
	stepping=false
	jumping=false
	current=id
	events.spin=Vector2.ZERO
	events.refresh()
	a.data["world_map"]=id
	var logical=LEGACY.find(room().name)
	if logical>=0: a.data.map=logical
	a.position_world=walkable(at,true)
	a.field.entered(previous,previous_position)
	a.c.click_move=false
	a.dialog=""
	warp_latch=warp_key(a.position_world)
	update_camera()
	a.save()
	if OS.get_cmdline_user_args().is_empty(): scenes.entrance()

func tick(dt):
	a.time+=dt
	if scenes.tick(dt):
		update_camera(); a.queue_redraw(); return
	if a.dialog=="" and a.modal=="":
		if stepping:
			advance_step(dt)
			update_camera(); a.queue_redraw(); return
		if try_warp(): return
		if scenes.detect_trainer(): return
		if events.tick(dt):
			update_camera(); a.queue_redraw(); return
		var direction=cardinal(a.c.movement_input(),a.c.click_move)
		var motion=direction*TILE
		if direction!=Vector2.ZERO:
			heading=direction
			a.walk_age+=dt
			if direction.x!=0: a.facing=signf(direction.x)
		else: a.walk_age=0
		var proposed: Vector2=a.position_world+motion
		for link in room().connections:
			if not maps.has(link.map): continue
			var next=maps[link.map]
			var offset=float(link.offset)*TILE
			var target=proposed
			var crossing=false
			match link.direction:
				"up":
					crossing=proposed.y<TILE*0.5 and direction.y<0
					target=Vector2(proposed.x-offset,(next.height-1.5)*TILE)
				"down":
					crossing=proposed.y>size().y-TILE*0.5 and direction.y>0
					target=Vector2(proposed.x-offset,TILE*1.5)
				"left":
					crossing=proposed.x<TILE*0.5 and direction.x<0
					target=Vector2((next.width-1.5)*TILE,proposed.y-offset)
				"right":
					crossing=proposed.x>size().x-TILE*0.5 and direction.x>0
					target=Vector2(TILE*1.5,proposed.y-offset)
			if crossing and target.x>=0 and target.y>=0 and target.x<next.width*TILE and target.y<next.height*TILE:
				if a.data.starter==0:
					scenes.oak_rescue()
					return
				enter(link.map,target); return
		if direction!=Vector2.ZERO:
			step_target=a.position_world+motion
			if a.sevii.waterfall(direction): return
			if try_ledge(direction):
				advance_step(dt)
			elif not blocked(step_target):
				stepping=true
				advance_step(dt)
			elif try_warp(false,step_target): return
			elif a.c.click_move: a.c.click_move=false
		a.autosave+=dt
		if a.autosave>=5: a.autosave=0; a.save()
	update_camera()
	a.queue_redraw()

func actors() -> Array:
	var result=[]
	var quests=quest_actors()
	for object in room().objects:
		if (object.get("graphics_id","").contains("ITEM_BALL") and not str(object.get("script","")).ends_with("EeveeBall")) or object.get("graphics_id","").contains("BOULDER") or object.get("graphics_id","").contains("CUT_TREE") or object.get("graphics_id","").contains("ROCK_SMASH_ROCK"): continue
		if "Snorlax" in str(object.get("script","")) and events.done("snorlax:"+current): continue
		if a.field.hidden(object) or (str(object.get("script","")).ends_with("EeveeBall") and a.field.done("gift:eevee")): continue
		var npc=object.duplicate(true)
		npc["pos"]=scenes.positions.get(str(object.get("script","")),Vector2(float(object.x)+0.5,float(object.y)+0.5)*TILE)
		if quests.any(func(q):return q[0].distance_to(npc.pos)<TILE*0.5): continue
		result.append(npc)
	return result

func quest_actors() -> Array:
	var logical={"PewterCity_Gym":4,"CeruleanCity_Gym":8,"PalletTown_ProfessorOaksLab":0,"Route25_SeaCottage":27,"PalletTown_PlayersHouse_1F":0,"SSAnne_CaptainsRoom":28,"SSAnne_2F_Corridor":28}.get(room().name,LEGACY.find(room().name))
	var result=[]
	# Existing campaign interactions remain available, without automatic encounters.
	if logical>=0:
		var previous=a.data.map
		a.data.map=logical
		for npc in a.base_npcs()+a.Finale.npcs(a):
			if str(npc[2]).begins_with("late_enter_"): continue
			var action=str(npc[2])
			if action.begins_with("story_switch") or action in ["late_warp","late_quiz","late_task_mansion_switch","late_task_card_key","late_task_secret_key","late_task_victory_boulder","late_task_snorlax","late_task_seafoam_boulder","late_league"]: continue
			if action in ["story_bill","story_console"] and room().name!="Route25_SeaCottage": continue
			if action=="story_captain" and room().name!="SSAnne_CaptainsRoom": continue
			if action=="story_shipblue" and room().name!="SSAnne_2F_Corridor": continue
			if action=="oak" and room().name!="PalletTown_ProfessorOaksLab": continue
			if action=="rival" and room().name!="PalletTown": continue
			if action=="heal" and room().name!="PalletTown_PlayersHouse_1F" and logical!=28: continue
			if action=="shop": continue
			if action=="brock" and room().name!="PewterCity_Gym": continue
			if action=="misty" and room().name!="CeruleanCity_Gym": continue
			var copy=npc.duplicate(true)
			copy[0]=walkable(Vector2(npc[0])*size()/Vector2(1600,1000))
			var graphic={"oak":"PROF_OAK","brock":"BROCK","misty":"MISTY","heal":"MOM","story_captain":"CAPTAIN","story_shipblue":"BLUE","late_task_flute":"MR_FUJI","late_task_hideout_boss":"GIOVANNI","late_task_silph_boss":"GIOVANNI","story_bill":"BILL","story_surge":"LT_SURGE","late_task_erika":"ERIKA","late_task_koga":"KOGA","late_task_sabrina":"SABRINA","late_task_blaine":"BLAINE","late_task_giovanni":"GIOVANNI"}.get(action,"")
			for original in room().objects:
				if graphic!="" and original.get("graphics_id","")=="OBJ_EVENT_GFX_"+graphic:
					copy[0]=Vector2(float(original.x)+0.5,float(original.y)+0.5)*TILE
			copy[0]=scenes.positions.get("quest:"+action,copy[0])
			result.append(copy)
		a.data.map=previous
	return result

func wild() -> Array:
	return []

func interact() -> bool:
	if stepping: pending_interact=true; return true
	if events.interact(): return true
	if try_warp(true): return true
	for npc in quest_actors():
		if a.position_world.distance_to(npc[0])<=100:
			if scenes.quest(str(npc[2])): return true
			if npc[2]=="oak" and events.npc_interact({"graphics_id":"OBJ_EVENT_GFX_PROF_OAK"}): return true
			if npc[2]=="late_task_sabrina": a.Finale.state(a)["warp"]=true
			return false
	for npc in actors():
		if not can_talk(npc.pos): continue
		if events.npc_interact(npc): return true
		var gfx=str(npc.get("graphics_id",""))
		if gfx.contains("PROF_OAK"):
			a.starter_menu() if a.data.starter==0 else a.heal()
		elif gfx.contains("NURSE"): a.heal()
		elif room().name.contains("Mart") or (room().name.contains("DepartmentStore") and gfx.contains("CLERK")): a.inventory.shop()
		elif npc.has("battle"):
			if events.done("trainer:"+str(npc.script)):
				a.dialog="We already battled. Good luck on your journey!"; return true
			var ids=[]; var levels=[]
			for member in npc.battle.party: ids.append(member[0]); levels.append(member[1])
			a.begin_battle("world_"+str(npc.script),ids,levels)
		else: a.dialog=a.sevii.dialogue.get(str(npc.get("script","")),"Welcome to "+room().name.replace("_"," / ")+". Explore the marked doors and passages.")
		return true
	return scenes.seek_wild()

func guide():
	var list=a.inventory.page("KANTO / "+room().name.replace("_"," / "),a.expansion.journal)
	a.inventory.row(list,"QUEST JOURNAL",a.expansion.journal)
	var destination=a.expansion.target()
	if destination!="":
		for step in a.expansion.route(destination): a.inventory.row(list,step,func():pass,true)
	if a.sevii.at_port(): a.inventory.row(list,"SEAGALLOP FERRY / SEVII",a.sevii.ferry_menu)
	a.inventory.row(list,"SEVII QUEST JOURNAL",a.sevii.journal)
	if not events.rocks().is_empty():
		var reset=Button.new()
		reset.text="Reset Seafoam boulders and currents on ALL floors" if current.begins_with("MAP_SEAFOAM_ISLANDS_") else "Reset this room's boulders"
		reset.pressed.connect(events.reset_rocks)
		list.add_child(reset)
	for link in room().connections:
		if maps.has(link.map): a.Finale.info_row(list,str(link.direction).to_upper()+" > "+maps[link.map].name)
	var destinations=[]
	for door in room().warps:
		if maps.has(door.dest_map) and door.dest_map not in destinations:
			destinations.append(door.dest_map)
			a.Finale.info_row(list,"DOOR / STAIRS > "+maps[door.dest_map].name)
	a.Finale.info_row(list,"Walk onto doors/stairs. Trainers approach on sight. Press "+a.c.controls.text("interact")+" in grass, water or caves to seek a wild Pokemon.")

func tests():
	var before=a.data.duplicate(true)
	var location=a.position_world
	var old_enabled=enabled
	var old_current=current
	var old_camera=a.camera
	var old_heading=heading
	var old_stepping=stepping
	var old_target=step_target
	var old_dialog=a.dialog
	var old_save_allowed=a.save_allowed
	a.save_allowed=false
	enabled=true
	for id in maps:
		current=id
		a.c.check(room().cells.size()==int(room().width)*int(room().height),"FRLG collision dimensions: "+id)
		a.c.check(FileAccess.file_exists(room().image),"FRLG artwork: "+id)
		for npc in room().objects:
			if npc.has("battle"):
				for member in npc.battle.party: a.c.check(a.c.roster.any(func(mon):return int(mon.id)==int(member[0])),"FRLG trainer species supported")
	for cave in ["MAP_MT_MOON_1F","MAP_VICTORY_ROAD_3F","MAP_CERULEAN_CAVE_1F"]:
		current=cave; events.refresh()
		for target in [Vector2(12.1,16.9)*TILE,Vector2(1.5,1.5)*TILE,Vector2(-2,5)*TILE]:
			var expected=Vector2(TILE*1.5,TILE*1.5)
			var nearest=INF
			for y in range(int(room().height)):
				for x in range(int(room().width)):
					var cell=Vector2(x+0.5,y+0.5)*TILE
					if not terrain_blocked(cell) and cell.distance_squared_to(target)<nearest:
						expected=cell; nearest=cell.distance_squared_to(target)
			a.c.check(walkable(target)==expected,"Nearby search matches exhaustive nearest walkable tile: "+cave)
	current="MAP_ROUTE1"; events.refresh()
	var tested_ledge=false
	for y in range(1,int(room().height)-2):
		if tested_ledge: break
		for x in range(1,int(room().width)-1):
			if int(events.catalog[current].behavior[y*int(room().width)+x])!=0x3B: continue
			a.position_world=Vector2(x+0.5,y-0.5)*TILE
			if blocked(a.position_world) or blocked(a.position_world+Vector2.DOWN*TILE*2): continue
			var destination=a.position_world+Vector2.DOWN*TILE*2
			a.c.check(not try_ledge(Vector2.UP) and try_ledge(Vector2.DOWN),"Ledge jumps only in its original permitted direction")
			for i in range(9): advance_step(0.05)
			a.c.check(not jumping and not stepping and a.position_world==destination,"Ledge lands on the next floor tile")
			tested_ledge=true; break
	a.c.check(tested_ledge,"Route 1 ledge fixture exists")
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		a.position_world=Vector2(500,500); step_target=a.position_world+direction*TILE; stepping=true
		for i in range(11): advance_step(0.02)
		a.c.check(not stepping and a.position_world==Vector2(500,500)+direction*TILE,"All four directions finish one equal-sized step")
	current="MAP_PALLET_TOWN"
	events.refresh()
	a.position_world=walkable(Vector2(12,16)*TILE,true)
	a.data["world_map"]=current
	a.data.x=a.position_world.x; a.data.y=a.position_world.y
	a.c.check(not blocked(a.position_world) and a.valid(a.data),"Canonical map position is walkable and save-valid")
	a.c.check(blocked(Vector2(-1,-1)),"Canonical world prevents leaving collision bounds")
	current="MAP_VIRIDIAN_FOREST"
	a.c.check(scenes.encounters.has(current),"Canonical forest has manual habitat encounter slots")
	current="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB"
	a.c.check(quest_actors().any(func(q):return q[2]=="oak"),"Starter interaction exists inside Oak lab")
	current="MAP_PEWTER_CITY_GYM"
	a.c.check(quest_actors().any(func(q):return q[2]=="brock"),"Brock badge encounter remains in canonical gym")
	current="MAP_PALLET_TOWN"
	var lab_door=room().warps.filter(func(w):return w.dest_map=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB")[0]
	a.position_world=Vector2(float(lab_door.x)+0.5,float(lab_door.y)+0.5)*TILE
	a.c.check(interact() and current=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB","Canonical door enters Oak lab")
	a.c.check(not blocked(a.position_world),"Interior arrival is walkable")
	var outside=room().warps.filter(func(w):return w.dest_map=="MAP_PALLET_TOWN")[0]
	a.position_world=Vector2(float(outside.x)+0.5,float(outside.y)+0.5)*TILE
	a.c.check(interact() and current=="MAP_PALLET_TOWN","Canonical lab exit returns to Pallet")
	for input in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
		var chosen=cardinal(input)
		a.c.check(chosen.length()==1.0 and (chosen.x==0 or chosen.y==0),"Overworld diagonal input resolves to one cardinal direction")
	current="MAP_PALLET_TOWN"; events.refresh()
	a.position_world=Vector2(12.5,16.5)*TILE
	var start=a.position_world
	step_target=start+Vector2.RIGHT*TILE; stepping=true
	advance_step(0.03)
	a.c.check(a.position_world.y==start.y and a.position_world.x>start.x and a.position_world.x<step_target.x,"Walking interpolates one horizontal tile")
	for i in range(12): advance_step(0.03)
	a.c.check(a.position_world==step_target and not stepping,"Walking stops exactly on tile center without overshoot")
	current="MAP_VIRIDIAN_CITY_POKEMON_CENTER_1F"; events.refresh()
	a.position_world=Vector2(7.5,4.5)*TILE; heading=Vector2.UP
	var nurse=Vector2(7.5,2.5)*TILE
	a.c.check(can_talk(nurse),"Nurse reachable across original counter metatile")
	a.c.check(interact() and a.dialog.contains("fully healed"),"Interacting across Center counter actually heals")
	heading=Vector2.DOWN
	a.c.check(not can_talk(nurse),"Counter conversation requires facing the NPC")
	a.position_world=Vector2(6.5,4.5)*TILE; heading=Vector2.UP
	a.c.check(not can_talk(nurse),"Counter conversation cannot reach diagonally")
	current="MAP_VIRIDIAN_CITY_MART"; events.refresh()
	a.position_world=Vector2(4.5,3.5)*TILE; heading=Vector2.LEFT
	a.c.check(can_talk(Vector2(2.5,3.5)*TILE),"Mart clerk reachable across horizontal counter")
	a.position_world=Vector2(4.5,2.5)*TILE
	a.c.check(not can_talk(Vector2(2.5,2.5)*TILE+Vector2(0,TILE*3)),"Interaction cannot reach a distant NPC through walls")
	current="MAP_PALLET_TOWN"; events.refresh()
	var civilian=actors().filter(func(n):return not n.has("battle") and not terrain_blocked(n.pos))[0]
	var npc_position=Vector2(civilian.pos)
	a.c.check(blocked(npc_position),"Visible civilian occupies its walking tile")
	a.c.check(not blocked(walkable(npc_position,true)),"Old saves and arrivals relocate off an occupied NPC tile")
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		a.position_world=npc_position-direction*TILE; heading=direction
		a.c.check(can_talk(npc_position),"Solid NPC remains reachable from adjacent tile")
	var scene_key=str(civilian.get("script",""))
	var saved_positions=scenes.positions.duplicate(true)
	var shifted=walkable(npc_position+Vector2.RIGHT*TILE*3,true)
	scenes.positions[scene_key]=shifted
	a.c.check(blocked(shifted) and not occupied_tiles().has(Vector2i((npc_position/TILE).floor())),"NPC collision follows scene movement and releases its old tile")
	scenes.positions=saved_positions
	current="MAP_PEWTER_CITY_GYM"; events.refresh()
	var brock=quest_actors().filter(func(n):return n[2]=="brock")[0]
	a.c.check(blocked(brock[0]),"Quest trainers occupy their visible tile")
	current="MAP_VIRIDIAN_FOREST"; events.refresh()
	var trainer=actors().filter(func(n):return n.has("battle"))[0]
	a.c.check(blocked(trainer.pos),"Battle trainers block walking before being challenged")
	for name in LEGACY: a.c.check(names.has(name),"Canonical migration destination: "+name)
	enabled=old_enabled
	current=old_current
	a.data=before
	a.position_world=location
	a.camera=old_camera
	heading=old_heading
	stepping=old_stepping
	step_target=old_target
	events.refresh()
	a.dialog=old_dialog
	a.save_allowed=old_save_allowed

func draw():
	if not textures.has(current): textures[current]=ImageTexture.create_from_image(Image.load_from_file(room().image))
	a.draw_rect(Rect2(0,0,1280,960),Color("152f32"))
	a.draw_set_transform(Vector2(0,90)-a.camera)
	a.draw_texture_rect(textures[current],Rect2(Vector2.ZERO,size()),false)
	events.draw()
	for door in room().warps:
		var p=Vector2(float(door.x)+0.5,float(door.y)+0.5)*TILE
		if a.position_world.distance_to(p)<TILE*1.5: a.words("ENTER",p+Vector2(-35,-22),14,Color("fff0b0"))
	for npc in actors():
		if str(npc.get("graphics_id","")).contains("FOSSIL") or str(npc.get("graphics_id","")).contains("OLD_AMBER"):
			a.draw_circle(npc.pos,15,Color("c7a46e")); a.draw_arc(npc.pos,9,0,TAU*0.8,20,Color("685141"),3)
		elif str(npc.get("graphics_id","")).trim_prefix("OBJ_EVENT_GFX_") in ["ARTICUNO","ZAPDOS","MEWTWO","MOLTRES"]:
			var species={"ARTICUNO":144,"ZAPDOS":145,"MEWTWO":150,"MOLTRES":146}[str(npc.graphics_id).trim_prefix("OBJ_EVENT_GFX_")]
			a.draw_texture_rect(a.c.portraits[species],Rect2(npc.pos-Vector2(38,60),Vector2(76,76)),false)
		elif str(npc.get("script","")).ends_with("EventScript_Ruby") or str(npc.get("script","")).ends_with("EventScript_Sapphire"):
			var gem=Color("eb5568") if str(npc.script).ends_with("Ruby") else Color("629df5")
			a.draw_colored_polygon(PackedVector2Array([npc.pos+Vector2(0,-22),npc.pos+Vector2(14,0),npc.pos+Vector2(0,14),npc.pos+Vector2(-14,0)]),gem)
		elif str(npc.get("script","")).ends_with("EeveeBall"):
			a.draw_circle(npc.pos,10,Color("f5eee0")); a.draw_arc(npc.pos,9,PI,TAU,12,Color("e75151"),9)
		elif "Snorlax" in str(npc.get("script","")):
			a.draw_texture_rect(a.c.portraits[143],Rect2(npc.pos-Vector2(38,60),Vector2(76,76)),false)
		else: person(npc.pos,str(npc.get("graphics_id","OBJ_EVENT_GFX_WOMAN_1")).trim_prefix("OBJ_EVENT_GFX_"),false,scenes.trainer_direction(npc))
		if can_talk(npc.pos): a.words(a.c.controls.text("interact")+" / "+(str(npc.battle.name) if npc.has("battle") else "TALK"),npc.pos+Vector2(-35,-65),14,Color("fff0b0"))
	for npc in quest_actors():
		var identity={"oak":"prof_oak","rival":"blue","heal":"nurse","shop":"man","brock":"brock","misty":"misty","bug":"bug_catcher","rocket":"rocket_m","guide":"man","story_captain":"captain","story_shipblue":"blue","story_bill":"bill","story_surge":"lt_surge","late_task_erika":"erika","late_task_koga":"koga","late_task_sabrina":"sabrina","late_task_blaine":"blaine","late_task_giovanni":"giovanni","late_task_flute":"mr_fuji","late_task_hideout_boss":"giovanni","late_task_silph_boss":"giovanni","late_task_silph_blue":"blue","late_league":"lorelei"}.get(npc[2],"scientist")
		if npc[2]=="late_league": identity=["lorelei","bruno","agatha","lance","blue"][clampi(int(a.Finale.state(a).get("league",0)),0,4)]
		person(npc[0],identity)
		a.words(npc[1],npc[0]+Vector2(-45,20),12)
	for spawn in wild():
		a.draw_texture_rect(a.c.portraits[spawn[1]],Rect2(spawn[0]-Vector2(24,40),Vector2(48,48)),false)
		a.words(a.mon_name(spawn[1])+" Lv."+str(spawn[2]),spawn[0]+Vector2(-35,22),12)
	person(a.position_world,"red_normal",true)
	a.draw_set_transform(Vector2.ZERO)
	a.draw_rect(Rect2(0,0,1280,90),Color("112b32"))
	a.words(room().name.replace("_"," / "),Vector2(24,32),24,Color("ffe19a"))
	a.words("KANTO ADVENTURE / %d badges / %d Poke Balls / $%d / M: local connections"%[a.Finale.badges(a),a.data.balls,a.data.money],Vector2(24,65),16)
	a.draw_rect(Rect2(0,790,1280,170),Color("112b32"))
	for i in range(a.data.party.size()):
		var mon=a.data.party[i]
		a.draw_texture_rect(a.c.portrait(mon),Rect2(24+i*205,810,48,48),false)
		a.words(a.mon_name(mon.id),Vector2(76+i*205,830),14)
		a.words("Lv.%d / HP %d%%"%[mon.level,roundi(mon.hp*100)],Vector2(76+i*205,852),12)
		a.draw_rect(Rect2(34+i*205,862,180,5),Color("354c50"))
		a.draw_rect(Rect2(34+i*205,862,180*mon.hp,5),Color("77e2b0"))
		a.draw_rect(Rect2(34+i*205,875,180,4),Color("354c50"))
		a.draw_rect(Rect2(34+i*205,875,180*a.xp_ratio(mon),4),Color("79aaff"))
	if not scenes.pool().is_empty(): a.words(a.c.controls.text("interact")+" / SEARCH FOR A WILD POKEMON",Vector2(24,780),16,Color("ffe19a"))
	a.words("Move: WASD / right click   Talk / search: "+a.c.controls.text("interact")+"   Team: P   Bag: I   Menu: Esc",Vector2(24,910),17)
	if a.save_error!="": a.words(a.save_error,Vector2(24,950),14,Color("ff9999"))
	if a.dialog!="":
		a.draw_rect(Rect2(80,630,1120,145),Color("10252f"))
		a.draw_multiline_string(a.font,Vector2(105,665),a.wrapped(a.dialog),HORIZONTAL_ALIGNMENT_LEFT,1060,20,4,Color("eef4de"))
	if a.services.state().safari: a.words("SAFARI / "+str(a.services.state().safari_steps)+" steps / "+str(a.services.state().safari_balls)+" balls",Vector2(820,32),18,Color("ffe19a"))
	a.field.draw()
	scenes.draw()

func person(at: Vector2, identity: String, player: bool=false, look: Vector2=Vector2.ZERO):
	var key=identity.to_lower().replace("_","")
	if not actor_paths.has(key): key="boy"
	if not actor_textures.has(key): actor_textures[key]=ImageTexture.create_from_image(Image.load_from_file(actor_paths[key]))
	var texture=a.avatar.texture(a.avatar.config()) if player and a.data.has("avatar") else actor_textures[key]
	var frame=0
	var flip=false
	if not player and look!=Vector2.ZERO:
		frame=1 if look.y<0 else 2 if absf(look.x)>0.1 else 0
		flip=frame==2 and look.x>0
	if player:
		frame=1 if heading.y<0 else 2 if absf(heading.x)>0.1 else 0
		flip=frame==2 and heading.x>0
		if stepping or events.spin!=Vector2.ZERO: frame=3+frame*2+int(a.walk_age*8)%2
	frame=mini(frame,int(texture.get_width()/16)-1)
	var extent=Vector2(48,texture.get_height()*3)
	if player and jumping: at.y-=sin(clampf(a.position_world.distance_to(jump_start)/(2*TILE),0,1)*PI)*22
	if flip:
		if player and a.data.has("avatar"):
			texture=a.avatar.texture(a.avatar.config(),false,true)
		else:
			var mirrored_key=key+":right"
			if not actor_textures.has(mirrored_key):
				var pixels=texture.get_image()
				pixels.flip_x()
				actor_textures[mirrored_key]=ImageTexture.create_from_image(pixels)
			texture=actor_textures[mirrored_key]
		# Mirroring the strip also reverses its frame order.
		frame=int(texture.get_width()/16)-1-frame
	# Every direction shares the same foot anchor and positive-sized destination.
	a.draw_texture_rect_region(texture,Rect2(at+Vector2(-24,-extent.y+24),extent),Rect2(frame*16,0,16,texture.get_height()))


func try_ledge(direction: Vector2) -> bool:
	var target=a.position_world+direction*TILE
	var cell=Vector2i(floori(target.x/TILE),floori(target.y/TILE))
	if cell.x<0 or cell.y<0 or cell.x>=room().width or cell.y>=room().height: return false
	var behavior=int(events.catalog[current].behavior[cell.y*int(room().width)+cell.x])
	var jump_direction={0x38:Vector2.RIGHT,0x39:Vector2.LEFT,0x3A:Vector2.UP,0x3B:Vector2.DOWN}.get(behavior,Vector2.ZERO)
	if direction==Vector2.ZERO or direction!=jump_direction: return false
	var landing=target+direction*TILE
	if blocked(landing): return false
	jump_start=a.position_world; step_target=landing; stepping=true; jumping=true
	return true

func cardinal(input: Vector2, mouse: bool=false) -> Vector2:
	if input==Vector2.ZERO: return Vector2.ZERO
	if mouse:
		var delta=a.c.click_destination-a.position_world
		# Finish one axis before the other instead of alternating diagonal micro-steps.
		if absf(delta.x)>=TILE*0.5: return Vector2(signf(delta.x),0)
		if absf(delta.y)>=TILE*0.5: return Vector2(0,signf(delta.y))
		a.c.click_move=false
		return Vector2.ZERO
	if absf(input.y)>=absf(input.x): return Vector2(0,signf(input.y))
	return Vector2(signf(input.x),0)

func advance_step(dt: float):
	var speed=480.0 if a.field.riding and a.field.outdoor() else 360.0 if a.c.controls.held("sprint") else 240.0
	a.position_world=a.position_world.move_toward(step_target,speed*minf(dt,0.05))
	a.walk_age+=dt
	a.autosave+=dt
	if a.position_world.is_equal_approx(step_target):
		a.position_world=step_target
		stepping=false
		jumping=false
		var habitat=scenes.habitat()
		a.c.audio.step("water" if habitat=="water_mons" else "cave" if room().type=="MAP_TYPE_UNDERGROUND" else "grass" if habitat=="land_mons" else "floor")
		a.services.steps()
		if a.sevii.on_step(): return
		if int(a.data.get("repel_steps",0))>0:
			a.data.repel_steps-=1
			if a.data.repel_steps==0: a.dialog="Repel wore off."
		if pending_interact:
			pending_interact=false
			a.interact()
		if a.autosave>=5: a.autosave=0; a.save()

func can_talk(at: Vector2) -> bool:
	var delta=at-a.position_world
	var direction=cardinal(delta)
	if direction==Vector2.ZERO: return true
	if heading.dot(direction)<0.5: return false
	var sideways=absf(delta.x) if direction.y!=0 else absf(delta.y)
	if sideways>TILE*0.35: return false
	var distance=absf(delta.y) if direction.y!=0 else absf(delta.x)
	if distance<=TILE*1.3: return true
	if distance>TILE*2.25: return false
	var counter=a.position_world+direction*TILE
	var x=floori(counter.x/TILE); var y=floori(counter.y/TILE)
	if x<0 or y<0 or x>=room().width or y>=room().height: return false
	return int(events.catalog[current].behavior[y*int(room().width)+x])==0x80


func warp_key(at: Vector2) -> String:
	return current+":"+str(floori(at.x/TILE))+":"+str(floori(at.y/TILE))

func try_warp(nearby: bool=false, probe: Vector2=Vector2.INF) -> bool:
	if probe==Vector2.INF: probe=a.position_world
	var key=warp_key(probe)
	if not nearby and key==warp_latch: return false
	if warp_key(a.position_world)!=warp_latch: warp_latch=""
	for door in room().warps:
		var at=Vector2(float(door.x)+0.5,float(door.y)+0.5)*TILE
		if probe.distance_to(at)>(TILE*1.4 if nearby else TILE*0.35): continue
		warp_latch=key
		var dest=door.dest_map
		if not maps.has(dest):
			if dest=="MAP_DYNAMIC" and a.data.has("world_return"):
				var back=a.data.world_return
				enter(str(back.map),Vector2(float(back.x),float(back.y)))
			else: a.dialog="This passage is outside Kanto."
			return true
		if not events.allow_door(dest): return true
		var index=int(door.dest_warp_id)
		var target=Vector2(TILE*2,TILE*2)
		if index>=0 and index<maps[dest].warps.size():
			var exit=maps[dest].warps[index]
			target=Vector2(float(exit.x)+0.5,float(exit.y)+1.5)*TILE
		if maps[dest].warps.any(func(w): return w.dest_map=="MAP_DYNAMIC"):
			a.data["world_return"]={"map":current,"x":a.position_world.x,"y":a.position_world.y}
		enter(dest,target)
		return true
	return false
