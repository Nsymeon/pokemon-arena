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

func install(adventure):
	a=adventure
	for id in maps: names[maps[id].name]=id

func activate():
	enabled=true
	current=a.data.get("world_map",names.get(LEGACY[int(a.data.map)],"MAP_PALLET_TOWN"))
	if not maps.has(current): current="MAP_PALLET_TOWN"
	if not a.data.has("world_map"):
		a.position_world=walkable(Vector2(12,16)*TILE)
	else: a.position_world=walkable(Vector2(a.data.x,a.data.y))
	a.data["world_map"]=current
	update_camera()

func room() -> Dictionary:
	return maps[current]

func size() -> Vector2:
	return Vector2(room().width,room().height)*TILE

func blocked(p: Vector2) -> bool:
	var x=floori(p.x/TILE); var y=floori(p.y/TILE)
	if x<0 or y<0 or x>=room().width or y>=room().height: return true
	return (int(room().cells[y*int(room().width)+x])&0xC00)!=0

func walkable(p: Vector2) -> Vector2:
	var best=Vector2(TILE*1.5,TILE*1.5)
	var distance=INF
	for y in range(int(room().height)):
		for x in range(int(room().width)):
			var candidate=Vector2(x+0.5,y+0.5)*TILE
			if not blocked(candidate) and candidate.distance_squared_to(p)<distance:
				best=candidate; distance=candidate.distance_squared_to(p)
	return best

func update_camera():
	var extent=size()-Vector2(1280,700)
	a.camera=Vector2(clampf(a.position_world.x-640,minf(0,extent.x/2),maxf(0,extent.x)),clampf(a.position_world.y-350,minf(0,extent.y/2),maxf(0,extent.y)))

func enter(id: String, at: Vector2):
	if not maps.has(id): return
	current=id
	a.data["world_map"]=id
	var logical=LEGACY.find(room().name)
	if logical>=0: a.data.map=logical
	a.position_world=walkable(at)
	a.c.click_move=false
	a.dialog=room().name.replace("_"," / ")+" / Approach a person or Pokemon and press "+a.c.controls.text("interact")+"."
	update_camera()
	a.save()

func tick(dt):
	a.time+=dt
	if a.dialog=="" and a.modal=="":
		var direction=a.c.movement_input()
		var motion=direction*(220 if a.c.controls.held("sprint") else 160)*minf(dt,0.05)
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
					a.dialog="Speak to Professor Oak and choose a starter before leaving Pallet Town."
					return
				enter(link.map,target); return
		if not blocked(a.position_world+Vector2(motion.x,0)): a.position_world.x+=motion.x
		if not blocked(a.position_world+Vector2(0,motion.y)): a.position_world.y+=motion.y
		a.autosave+=dt
		if a.autosave>=5: a.autosave=0; a.save()
	update_camera()
	a.queue_redraw()

func actors() -> Array:
	var result=[]
	var quests=quest_actors()
	for object in room().objects:
		if object.get("graphics_id","").contains("ITEM_BALL") or object.get("graphics_id","").contains("BOULDER"): continue
		var npc=object.duplicate(true)
		npc["pos"]=Vector2(float(object.x)+0.5,float(object.y)+0.5)*TILE
		if quests.any(func(q):return q[0].distance_to(npc.pos)<TILE*0.5): continue
		result.append(npc)
	return result

func quest_actors() -> Array:
	var logical={"PewterCity_Gym":4,"CeruleanCity_Gym":8,"PalletTown_ProfessorOaksLab":0,"Route25_SeaCottage":27,"PalletTown_PlayersHouse_1F":0}.get(room().name,LEGACY.find(room().name))
	var result=[]
	# Existing campaign interactions remain available, without automatic encounters.
	if logical>=0:
		var previous=a.data.map
		a.data.map=logical
		for npc in a.base_npcs()+a.Finale.npcs(a):
			if str(npc[2]).begins_with("late_enter_"): continue
			var action=str(npc[2])
			if action=="oak" and room().name!="PalletTown_ProfessorOaksLab": continue
			if action=="rival" and room().name!="PalletTown": continue
			if action=="heal" and room().name!="PalletTown_PlayersHouse_1F" and logical!=28: continue
			if action=="shop": continue
			if action=="brock" and room().name!="PewterCity_Gym": continue
			if action=="misty" and room().name!="CeruleanCity_Gym": continue
			var copy=npc.duplicate(true)
			copy[0]=walkable(Vector2(npc[0])*size()/Vector2(1600,1000))
			var graphic={"oak":"PROF_OAK","brock":"BROCK","misty":"MISTY","heal":"MOM","story_bill":"BILL","story_surge":"LT_SURGE","late_task_erika":"ERIKA","late_task_koga":"KOGA","late_task_sabrina":"SABRINA","late_task_blaine":"BLAINE","late_task_giovanni":"GIOVANNI"}.get(action,"")
			for original in room().objects:
				if graphic!="" and original.get("graphics_id","")=="OBJ_EVENT_GFX_"+graphic:
					copy[0]=Vector2(float(original.x)+0.5,float(original.y)+0.5)*TILE
			result.append(copy)
		a.data.map=previous
	return result

func wild() -> Array:
	if room().type not in ["MAP_TYPE_ROUTE","MAP_TYPE_UNDERGROUND"]: return []
	var logical=LEGACY.find(room().name)
	if logical<0: return []
	var source=a.Kanto.wild_spawns(logical,a.wild_cycle) if a.Kanto.WILD.has(logical) else []
	if a.WILD.has(logical):
		var pool=a.WILD[logical]
		for i in range(3): source.append([Vector2(450+i*300,500),pool[(a.wild_cycle+i)%pool.size()],{1:4,3:6,5:10,6:12,7:14}.get(logical,6)+(1 if i==1 else 0)])
	for spawn in source: spawn[0]=walkable(spawn[0]*size()/Vector2(1600,1000))
	return source

func interact() -> bool:
	for door in room().warps:
		var at=Vector2(float(door.x)+0.5,float(door.y)+0.5)*TILE
		if a.position_world.distance_to(at)>TILE*1.4: continue
		var dest=door.dest_map
		if not maps.has(dest):
			if dest=="MAP_DYNAMIC" and a.data.has("world_return"):
				var back=a.data.world_return
				enter(str(back.map),Vector2(float(back.x),float(back.y)))
			else: a.dialog="This passage is outside Kanto."
			return true
		var index=int(door.dest_warp_id)
		var target=Vector2(TILE*2,TILE*2)
		if index>=0 and index<maps[dest].warps.size():
			var exit=maps[dest].warps[index]
			target=Vector2(float(exit.x)+0.5,float(exit.y)+1.5)*TILE
		if maps[dest].warps.any(func(w): return w.dest_map=="MAP_DYNAMIC"):
			a.data["world_return"]={"map":current,"x":a.position_world.x,"y":a.position_world.y}
		enter(dest,target)
		return true
	for npc in quest_actors():
		if a.position_world.distance_to(npc[0])<=100: return false
	for npc in actors():
		if a.position_world.distance_to(npc.pos)>TILE*1.5: continue
		var gfx=str(npc.get("graphics_id",""))
		if gfx.contains("PROF_OAK"):
			a.starter_menu() if a.data.starter==0 else a.heal()
		elif gfx.contains("NURSE"): a.heal()
		elif room().name.contains("Mart"): a.inventory.shop()
		elif npc.has("battle"):
			var ids=[]; var levels=[]
			for member in npc.battle.party: ids.append(member[0]); levels.append(member[1])
			a.begin_battle("world_"+str(npc.script),ids,levels)
		else: a.dialog="Welcome to "+room().name.replace("_"," / ")+". Explore the marked doors and passages."
		return true
	return false

func guide():
	var list=a.inventory.page("KANTO / "+room().name.replace("_"," / "))
	for link in room().connections:
		if maps.has(link.map): a.Finale.info_row(list,str(link.direction).to_upper()+" > "+maps[link.map].name)
	var destinations=[]
	for door in room().warps:
		if maps.has(door.dest_map) and door.dest_map not in destinations:
			destinations.append(door.dest_map)
			a.Finale.info_row(list,"DOOR / STAIRS > "+maps[door.dest_map].name)
	a.Finale.info_row(list,"Approach a door or stairs and press "+a.c.controls.text("interact")+". Battles begin only when you interact.")

func tests():
	var before=a.data.duplicate(true)
	var location=a.position_world
	var old_enabled=enabled
	var old_current=current
	var old_camera=a.camera
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
	current="MAP_PALLET_TOWN"
	a.position_world=walkable(Vector2(12,16)*TILE)
	a.data["world_map"]=current
	a.data.x=a.position_world.x; a.data.y=a.position_world.y
	a.c.check(not blocked(a.position_world) and a.valid(a.data),"Canonical map position is walkable and save-valid")
	a.c.check(blocked(Vector2(-1,-1)),"Canonical world prevents leaving collision bounds")
	current="MAP_VIRIDIAN_FOREST"
	a.c.check(not wild().is_empty(),"Canonical forest keeps visible manual wild encounters")
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
	for name in LEGACY: a.c.check(names.has(name),"Canonical migration destination: "+name)
	enabled=old_enabled
	current=old_current
	a.data=before
	a.position_world=location
	a.camera=old_camera
	a.dialog=old_dialog
	a.save_allowed=old_save_allowed

func draw():
	if not textures.has(current): textures[current]=ImageTexture.create_from_image(Image.load_from_file(room().image))
	a.draw_rect(Rect2(0,0,1280,960),Color("152f32"))
	a.draw_set_transform(Vector2(0,90)-a.camera)
	a.draw_texture_rect(textures[current],Rect2(Vector2.ZERO,size()),false)
	for door in room().warps:
		var p=Vector2(float(door.x)+0.5,float(door.y)+0.5)*TILE
		if a.position_world.distance_to(p)<TILE*1.5: a.words(a.c.controls.text("interact")+" / ENTER",p+Vector2(-35,-22),14,Color("fff0b0"))
	for npc in actors():
		person(npc.pos,str(npc.get("graphics_id","OBJ_EVENT_GFX_WOMAN_1")).trim_prefix("OBJ_EVENT_GFX_"))
		if a.position_world.distance_to(npc.pos)<TILE*1.5: a.words(a.c.controls.text("interact")+" / "+(str(npc.battle.name) if npc.has("battle") else "TALK"),npc.pos+Vector2(-35,-65),14,Color("fff0b0"))
	for npc in quest_actors():
		var identity={"oak":"prof_oak","rival":"blue","heal":"nurse","shop":"man","brock":"brock","misty":"misty","bug":"bug_catcher","rocket":"rocket_m","guide":"man","story_bill":"bill","story_surge":"lt_surge","late_task_erika":"erika","late_task_koga":"koga","late_task_sabrina":"sabrina","late_task_blaine":"blaine","late_task_giovanni":"giovanni","late_task_flute":"mr_fuji","late_task_hideout_boss":"giovanni","late_task_silph_boss":"giovanni","late_task_silph_blue":"blue","late_league":"lorelei"}.get(npc[2],"scientist")
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
	a.words("Move: WASD / right click   Talk / doors: "+a.c.controls.text("interact")+"   Team: P   Bag: I   Menu: Esc",Vector2(24,910),17)
	if a.save_error!="": a.words(a.save_error,Vector2(24,950),14,Color("ff9999"))
	if a.dialog!="":
		a.draw_rect(Rect2(80,630,1120,145),Color("10252f"))
		a.draw_multiline_string(a.font,Vector2(105,665),a.wrapped(a.dialog),HORIZONTAL_ALIGNMENT_LEFT,1060,20,4,Color("eef4de"))

func person(at: Vector2, identity: String, player: bool=false):
	var key=identity.to_lower().replace("_","")
	if not actor_paths.has(key): key="boy"
	if not actor_textures.has(key): actor_textures[key]=ImageTexture.create_from_image(Image.load_from_file(actor_paths[key]))
	var texture=actor_textures[key]
	var frame=0
	var flip=false
	if player:
		frame=1 if heading.y<0 else 2 if absf(heading.x)>0.1 else 0
		flip=frame==2 and heading.x>0
		if (a.c.click_move or a.c.controls.held("up") or a.c.controls.held("down") or a.c.controls.held("left") or a.c.controls.held("right")): frame=3+frame*2+int(a.walk_age*8)%2
	frame=mini(frame,int(texture.get_width()/16)-1)
	var extent=Vector2(48,texture.get_height()*3)
	a.draw_texture_rect_region(texture,Rect2(at+Vector2(24 if flip else -24,-extent.y+24),Vector2(-48 if flip else 48,extent.y)),Rect2(frame*16,0,16,texture.get_height()))
