extends Node2D

const SAVE_PATH = "user://adventure-v1.json"
const Finale = preload("res://adventure_finale.gd")
const Story = preload("res://adventure_story.gd")
const Kanto = preload("res://adventure_kanto.gd")
var MAPS = ["PALLET TOWN", "ROUTE 1", "VIRIDIAN CITY", "VIRIDIAN FOREST", "PEWTER CITY", "ROUTE 3", "MT. MOON", "ROUTE 4", "CERULEAN CITY"] + Kanto.EXTRA_MAPS + Story.MAPS + Finale.MAPS
const STARTERS = [1,4,7]
const WILD = {1:[16,19],3:[10,13,25,16],5:[21,39,29,32],6:[41,74,46,35],7:[19,21,23,27]}
const EVOLUTIONS = {1:[16,2],2:[32,3],4:[16,5],5:[36,6],7:[16,8],8:[36,9],10:[7,11],11:[10,12],13:[7,14],14:[10,15],16:[18,17],17:[36,18],19:[20,20],21:[20,22],23:[22,24],27:[22,28],29:[16,30],32:[16,33],41:[22,42],43:[21,44],46:[24,47],48:[31,49],50:[26,51],52:[28,53],54:[33,55],56:[28,57],60:[25,61],63:[16,64],66:[28,67],69:[21,70],72:[30,73],74:[25,75],77:[40,78],79:[37,80],81:[30,82],84:[31,85],86:[34,87],88:[38,89],92:[25,93],96:[26,97],98:[28,99],100:[30,101],104:[28,105],109:[35,110],111:[42,112],116:[32,117],118:[33,119],129:[20,130],138:[40,139],140:[40,141],147:[30,148],148:[55,149]}
const INITIAL_DATA = {"version":1,"map":0,"x":800.0,"y":780.0,"starter":0,"party":[],"storage":[],"balls":10,"money":300,"rival":false,"bug_catcher":false,"badge":false,"healing_map":0}
var data = INITIAL_DATA.duplicate(true)
var save_path = SAVE_PATH
var save_error = ""
var save_allowed = true
var c
var expansion=preload("res://adventure_expansion.gd").new()
var collection=preload("res://pokemon_collection.gd").new()
var extras=preload("res://adventure_items.gd").new()
var sevii=preload("res://adventure_sevii.gd").new()
var services=preload("res://adventure_services.gd").new()
var field=preload("res://adventure_field.gd").new()
var avatar=preload("res://adventure_avatar.gd").new()
var world=preload("res://kanto_world.gd").new()
var inventory = preload("res://adventure_inventory.gd").new()
var exploring = false
var in_battle = false
var position_world = Vector2(800,780)
var camera = Vector2.ZERO
var time = 0.0
var walk_age = 0.0
var facing = 1.0
var autosave = 0.0
var dialog_pages: Array = []
var dialog = "":
	set(value):
		dialog=value
		dialog_pages.clear()
var modal = ""
var ui_back=Callable()
var ui: CanvasLayer
var original = {}
var encounter = {}
var evolutions: Array = []
var progress_lines: Array = []
var progress_time = 0.0
var progress_summary=""
const CAPTURE_DURATION=3.6
const RUN_BUTTON=Rect2(1040,900,200,44)
var capture_time = 0.0
var capture_success = false
var wild_cycle = 0
var loaded = false
var font: Font

func install(context):
	c = context
	collection.a=self
	expansion.a=self
	extras.a = self
	field.a = self
	services.a = self
	sevii.a = self
	avatar.a = self
	world.install(self)
	inventory.install(self)
	font = ThemeDB.fallback_font
	z_index = 100
	visible = false
	ui = CanvasLayer.new()
	ui.layer = 50
	add_child(ui)

func valid(value) -> bool:
	if value is Dictionary and value.has("field_exit"):
		var e=value.field_exit
		if not e is Dictionary or not world.maps.has(e.get("map","")): return false
		for axis in ["x","y"]:
			if not (e.get(axis) is float or e.get(axis) is int) or not is_finite(e[axis]): return false
		if e.x<0 or e.y<0 or e.x>=world.maps[e.map].width*world.TILE or e.y>=world.maps[e.map].height*world.TILE: return false
	if value is Dictionary and value.has("avatar") and not avatar.valid(value.avatar): return false
	if value is Dictionary and not world.events.valid(value): return false
	if not value is Dictionary or value.get("version",0) != 1: return false
	for key in ["map","starter","balls","money","healing_map"]:
		if not value.get(key) is float and not value.get(key) is int: return false
		if value[key] != int(value[key]): return false
	if value.map < 0 or value.map >= MAPS.size() or int(value.healing_map) not in Kanto.HEALING_MAPS: return false
	if int(value.starter) not in [0,1,4,7] or value.balls < 0 or value.balls > 999 or value.money < 0 or value.money > 999999: return false
	for key in ["x","y"]:
		if not (value.get(key) is float or value.get(key) is int) or not is_finite(value[key]): return false
	if value.has("world_map"):
		if not value.world_map is String or not world.maps.has(value.world_map): return false
		var room=world.maps[value.world_map]
		if value.x<0 or value.y<0 or value.x>=room.width*world.TILE or value.y>=room.height*world.TILE: return false
	elif value.x < 24 or value.x > 1576 or value.y < 24 or value.y > 976: return false
	for key in ["rocket","cascade"]:
		if value.has(key) and not value[key] is bool: return false
	for key in ["rival","bug_catcher","badge"]:
		if not value.get(key) is bool: return false
	for key in ["party","storage"]:
		if not value.get(key) is Array or value[key].size() > (6 if key == "party" else 100): return false
		for mon in value[key]:
			if not mon is Dictionary: return false
			if mon.has("gender") and mon.gender not in ["M","F","N"]: return false
			if mon.has("shiny") and not mon.shiny is bool: return false
			if mon.has("ivs") and not c.ivs.valid(mon.ivs): return false
			if mon.has("ability_slot") and (not (mon.ability_slot is int or mon.ability_slot is float) or mon.ability_slot!=int(mon.ability_slot) or int(mon.ability_slot) not in [0,1]): return false
			for field in ["id","level","xp","hp"]:
				if not (mon.get(field) is float or mon.get(field) is int) or not is_finite(mon[field]): return false
			if mon.id != int(mon.id) or c.Dex.find_id(c.roster,int(mon.id)) < 0 or not c.roster.any(func(m):return int(m.id)==int(mon.id)): return false
			if mon.level != int(mon.level) or mon.level < 1 or mon.level > 100 or mon.xp < 0 or mon.xp > 100000 or mon.hp < 0 or mon.hp > 1: return false
	if value.starter != 0 and value.party.is_empty(): return false
	if value.starter == 0 and (not value.party.is_empty() or not value.storage.is_empty() or value.map != 0): return false
	if not Finale.valid(value): return false
	for member in value.get("hall_of_fame",[]):
		if not c.roster.any(func(mon):return int(mon.id)==int(member.id)): return false
	return expansion.valid(value) and collection.valid(value) and inventory.valid(value) and extras.valid(value) and Story.valid(value) and services.valid(value)

func load_save():
	loaded = true
	for suffix in ["", ".bak"]:
		if not FileAccess.file_exists(save_path+suffix): continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(save_path+suffix)) != OK: continue
		if parser.data is Dictionary and parser.data.get("version",1) != 1:
			save_error = "Save needs a different game version. Original preserved."
			save_allowed = false
			return
		if valid(parser.data):
			data = parser.data
			inventory.migrate()
			expansion.recover()
			for key in ["map","starter","balls","money","healing_map"]: data[key] = int(data[key])
			for mon in data.party + data.storage:
				c.abilities.assign(mon)
				mon.id = int(mon.id)
				mon.level = int(mon.level)
				mon.xp = int(mon.xp)
			position_world = Vector2(data.x,data.y)
			if suffix != "": save_error = "Recovered previous save backup."
			return
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak"):
		save_error = "Adventure save is damaged. Original preserved; saving disabled."
		save_allowed = false

func save() -> bool:
	collection.sync()
	if not save_allowed: return false
	data.x = position_world.x
	data.y = position_world.y
	var f = FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if f == null:
		save_error = "Could not save adventure. Check storage."
		return false
	f.store_string(JSON.stringify(data,"\t"))
	f.flush()
	var err = f.get_error()
	f.close()
	if err != OK:
		save_error = "Save write failed. Previous progress preserved."
		return false
	var path = ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		# Copy a verified old save to backup; never replace a good backup with corrupt data.
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(save_path)) == OK and valid(parser.data):
			if DirAccess.copy_absolute(path,path+".bak") != OK:
				save_error = "Could not create save backup."
				return false
		if DirAccess.remove_absolute(path) != OK:
			save_error = "Save file is locked."
			return false
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		save_error = "Save replacement failed; backup retained."
		return false
	save_error = ""
	return true

func enter():
	c.click_move = false
	if not loaded and OS.get_cmdline_user_args().is_empty(): load_save()
	inventory.migrate()
	original = {"player_team":c.player_team.duplicate(),"enemy_team":c.enemy_team.duplicate(),"player_index":c.player_index,"enemy_index":c.enemy_index,"team_slot":c.team_slot,"team_mode":c.team_mode}
	c.campaign.active = false
	c.campaign.layer.visible = false
	c.selection_controls.visible = false
	c.selecting = true
	exploring = true
	in_battle = false
	visible = true
	position_world = Vector2(data.x,data.y)
	if OS.get_cmdline_user_args().is_empty(): world.activate()
	dialog = "Welcome to Pallet Town! Find Professor Oak inside his lab and press "+c.controls.text("interact")+"." if data.starter == 0 else "Adventure loaded. " + objective()
	if world.enabled: dialog=""
	if not data.has("avatar") and OS.get_cmdline_user_args().is_empty(): avatar.show_creator(self)
	queue_redraw()

func leave():
	evolutions.clear()
	save()
	exploring = false
	visible = false
	clear_ui()
	for key in original: c.set(key,original[key])
	c.enemy_party.clear()
	c.preview_party.clear()
	c.opponent_choice.select(0)
	c.opponent_choice.disabled = false
	c.arena_choice.disabled = false
	c.weather_choice.disabled = false
	c.reset()
	c.frontend.show_modes()

func objective() -> String:
	if data.starter == 0: return "Head toward the tall grass north of Pallet Town."
	if not data.rival: return "Battle Blue in Oak's lab."
	if not data.bug_catcher: return "Travel north: Route 1, Viridian City, then the forest."
	if not data.badge: return "Reach Pewter City and defeat Brock for the Boulder Badge."
	if not data.get("rocket",false): return "Boulder Badge earned! Head north: Route 3, then Mt. Moon."
	if not data.get("cascade",false): return "Cross Route 4 to Cerulean City. Challenge Misty for the Cascade Badge."
	return Story.objective(self)

func buildings() -> Array:
	if int(data.map)>=26: return Story.buildings(int(data.map))
	if Kanto.CITIES.has(int(data.map)): return Kanto.buildings(int(data.map))
	match int(data.map):
		0: return [[Rect2(250,380,310,230),"YOUR HOME",Color("5a83ab")],[Rect2(1000,350,350,250),"OAK'S LAB",Color("b86a54")]]
		2: return [[Rect2(250,350,320,250),"POKEMON CENTER",Color("c76263")],[Rect2(1020,350,320,250),"POKE MART",Color("5596b4")]]
		4: return [[Rect2(250,380,320,230),"POKEMON CENTER",Color("c76263")],[Rect2(990,300,380,290),"PEWTER GYM",Color("968169")]]
		8: return [[Rect2(250,350,320,250),"POKEMON CENTER",Color("c76263")],[Rect2(990,300,380,290),"CERULEAN GYM",Color("529ab4")]]
	return []

func npcs() -> Array:
	if world.enabled: return world.quest_actors()
	return base_npcs()+Finale.npcs(self)

func base_npcs() -> Array:
	if int(data.map)>=26: return Story.npcs(self)
	if Kanto.CITIES.has(int(data.map)): return Kanto.npcs(int(data.map))
	match int(data.map):
		0: return [[Vector2(1120,655),"Professor Oak","oak"],[Vector2(800,230),"Blue","rival"],[Vector2(405,660),"Mom / Heal","heal"]]
		2: return [[Vector2(410,650),"Nurse Joy / Heal","heal"],[Vector2(1180,650),"Shop / 5 balls: $100","shop"]]
		3: return [[Vector2(800,330),"Bug Catcher","bug"]]
		4: return [[Vector2(410,660),"Nurse Joy / Heal","heal"],[Vector2(1180,650),"Brock / Gym battle","brock"]]
		5: return [[Vector2(800,430),"Lass / Route 3","lass"]]
		6: return [[Vector2(800,280),"Team Rocket Grunt","rocket"]]
		8: return [[Vector2(410,650),"Nurse Joy / Heal","heal"],[Vector2(1180,650),"Misty / Gym battle","misty"],[Vector2(800,470),"Shop / Supplies","shop"]]
	return []

func wild_spawns() -> Array:
	if world.enabled: return world.wild()
	if Kanto.WILD.has(int(data.map)): return Kanto.wild_spawns(int(data.map),wild_cycle)
	if not WILD.has(int(data.map)): return []
	var pool: Array = WILD[int(data.map)]
	var level = {1:4,3:6,5:10,6:12,7:14}.get(int(data.map),6)
	return [[Vector2(450,650),pool[wild_cycle%pool.size()],level],[Vector2(1100,450),pool[(wild_cycle+1)%pool.size()],level+1],[Vector2(470,270),pool[(wild_cycle+2)%pool.size()],level]]

func blocked(point: Vector2) -> bool:
	if world.enabled: return world.blocked(point)
	if data.map==29 and int(Story.state(self).get("switch",0))<2 and point.y>=310 and point.y<=340: return true
	if data.map==26 and Rect2(210,110,1180,670).has_point(point) and (point.x<705 or point.x>895): return true
	if point.x < 70 or point.x > 1530 or point.y < 45 or point.y > 955: return true
	for building in buildings():
		if building[0].grow(12).has_point(point): return true
	return false

func tick(dt):
	if not exploring: return
	if world.enabled: world.tick(dt); return
	time += dt
	if dialog == "" and modal == "":
		var direction: Vector2 = c.movement_input()
		var motion = direction * (280 if c.controls.held("sprint") else 195) * minf(dt,0.05)
		if not blocked(position_world+Vector2(motion.x,0)): position_world.x += motion.x
		if not blocked(position_world+Vector2(0,motion.y)): position_world.y += motion.y
		if direction != Vector2.ZERO:
			walk_age += dt
			if direction.x != 0: facing = signf(direction.x)
		else: walk_age = 0
		if position_world.x > 700 and position_world.x < 900:
			if position_world.y < 90: travel(1)
			elif position_world.y > 920: travel(-1)
		if position_world.y>760 and position_world.y<880:
			if position_world.x>1500: travel(2)
			elif position_world.x<100: travel(-2)
		autosave += dt
		if autosave >= 5:
			autosave = 0
			save()
	camera = (position_world-Vector2(640,350)).clamp(Vector2.ZERO,Vector2(320,300))
	queue_redraw()

func travel(step: int):
	c.click_move = false
	var destination = Kanto.destination(int(data.map),step)
	if destination < 0 or destination >= MAPS.size():
		dialog = "No passage here. Press M to see the Kanto connections."
		position_world = Vector2(800,500)
		return
	if step>0 and data.map==0 and (data.starter==0 or not data.rival):
		dialog = objective()
		position_world.y = 120
		return
	if step>0 and data.map==3 and not data.bug_catcher:
		dialog = "The Bug Catcher wants a battle before you leave the forest. Find him on the path."
		position_world.y = 120
		return
	if step>0 and ((data.map==4 and not data.badge) or (data.map==6 and not data.get("rocket",false))):
		dialog = "Defeat Brock before leaving Pewter." if data.map==4 else "Defeat Team Rocket to clear the Mt. Moon exit."
		position_world.y = 120
		return
	if destination>=9 and not data.get("cascade",false):
		dialog = "Earn Misty's Cascade Badge in Cerulean to explore the rest of Kanto."
		position_world = Vector2(800,500)
		return
	var gate = Story.gate(self,destination)
	if gate!="":
		dialog=gate
		position_world=Vector2(800,820)
		return
	var arrival = Kanto.LINKS[destination].find_key(int(data.map))
	position_world = {1:Vector2(800,140),-1:Vector2(800,860),2:Vector2(1460,820),-2:Vector2(140,820)}.get(arrival,Vector2(800,500))
	data.map = destination
	dialog = MAPS[destination] + " / " + objective()
	save()

func handle_input(event):
	if world.enabled and world.scenes.active:
		if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
			if event is InputEventKey and event.echo: return
			if event is InputEventKey and event.keycode==KEY_ESCAPE: world.scenes.finish()
			elif c.controls.matches(event,"interact") or (event is InputEventKey and event.keycode==KEY_ENTER): world.scenes.elapsed=1000.0
		return
	if c.controls.matches(event,"click_move"):
		if modal=="" and dialog=="" and Rect2(0,90,1280,700).has_point(c.get_global_mouse_position()):
			var target = c.get_global_mouse_position()-Vector2(0,90)+camera
			if (world.click_destination_allowed(target) if world.enabled else not blocked(target)):
				c.click_destination = target
				c.click_move = true
		return
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.pressed: return
	if event is InputEventKey and event.echo: return
	if modal != "":
		if modal=="CREATE YOUR TRAINER": return
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			if modal.begins_with("EVOLUTION"): next_evolution()
			else: back_ui()
		return
	if dialog != "":
		if c.controls.matches(event,"interact") or c.controls.matches(event,"sprint") or (event is InputEventKey and event.keycode in [KEY_ENTER,KEY_ESCAPE]): advance_dialogue()
		return
	c.controls.handle_run(event)
	if c.controls.matches(event,"map"): Finale.guide(self)
	elif c.controls.matches(event,"interact"): interact()
	elif c.controls.matches(event,"party"): party_menu()
	elif c.controls.matches(event,"bag"): inventory.bag()
	elif event is InputEventKey and event.keycode==KEY_ESCAPE: menu()
	elif c.controls.matches(event,"save"):
		var ok=save()
		dialog="Adventure saved." if ok else save_error

func interact():
	c.click_move = false
	if world.enabled and world.interact(): return
	for npc in npcs():
		if position_world.distance_to(npc[0]) <= 100:
			if Finale.interact(self,npc[2]) or Story.interact(self,npc[2]): return
			match npc[2]:
				"oak":
					if data.starter == 0: starter_menu()
					else: dialog = "Oak: Weaken wild Pokemon, then press "+c.controls.text("capture")+" in battle to throw a Poke Ball. Press "+c.controls.text("party")+" outside battle to manage your team."
				"guide": dialog = Kanto.CITIES[int(data.map)][2]
				"heal": heal()
				"shop": inventory.shop()
				"rival":
					if data.starter == 0: dialog = "Blue: Ask Grandpa for a Pokemon first!"
					else: begin_battle("rival",[7 if data.starter==4 else 4 if data.starter==1 else 1],[5])
				"bug": begin_battle("bug",[10,13],[6,7])
				"brock": begin_battle("brock",[74,95],[10,12])
				"lass": begin_battle("lass",[21,39],[11,12])
				"rocket": begin_battle("rocket",[19,41],[13,14])
				"misty": begin_battle("misty",[120,121],[18,21])
			return
	for wild in wild_spawns():
		if position_world.distance_to(wild[0]) <= 95:
			begin_battle("wild",[wild[1]],[wild[2]])
			return
	dialog = "Stand in grass, water or a cave and press "+c.controls.text("interact")+" to search, or face a nearby person to talk." if world.enabled else "Move closer to a person or wild Pokemon, then press "+c.controls.text("interact")+"."

func new_mon(id: int, level: int) -> Dictionary:
	var mon={"id":id,"level":level,"xp":0,"hp":1.0,"moves":inventory.starting(id,level),"pending":[],"ailment":""}
	c.abilities.assign(mon,true)
	c.ivs.assign(mon)
	collection.assign(mon,true)
	return mon

func choose_starter(id: int):
	if data.starter != 0 or id not in STARTERS: return
	data.starter = id
	data.party = [new_mon(id,5)]
	clear_ui()
	dialog = "Oak: " + mon_name(id) + " is your partner!"
	save()
	if world.enabled and world.current=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB": world.scenes.starter_battle()

func mon_name(id: int) -> String:
	return c.roster[c.Dex.find_id(c.roster,id)].name

func heal():
	for mon in data.party:
		mon.hp = 1.0
		mon.ailment = ""
	if data.map in Kanto.HEALING_MAPS: data.healing_map = int(data.map)
	dialog = "Your team is fully healed. See you again!"
	save()

func battle_mon(id: int, level: int, individual: Dictionary={}) -> Dictionary:
	if in_battle and encounter.get("kind","")=="post_tower": level=50
	var mon: Dictionary = c.roster[c.Dex.find_id(c.roster,id)].duplicate(true)
	var values=individual.get("ivs",{})
	if values.is_empty(): values=c.ivs.roll() if individual.is_empty() else c.ivs.uniform(0)
	mon["ivs"]=values.duplicate(true)
	mon.speed+=float(values.spe)/2.0+floorf(float(individual.get("training",{}).get("spe",0))/4.0)
	var scale = 0.55+level*0.06
	mon.hp = roundf(mon.hp*scale)
	for key in mon.base_stats: mon.base_stats[key] = roundf((mon.base_stats[key]+float(values[key])/2.0+floorf(float(individual.get("training",{}).get(key,0))/4.0))*scale)
	mon.hp += roundf((float(values.hp)/2.0+floorf(float(individual.get("training",{}).get("hp",0))/4.0))*scale)
	mon.moves = inventory.definitions(inventory.starting(id,level))
	mon["level"] = level
	mon["nature"]=individual.get("nature", "Hardy" if not individual.is_empty() else collection.NAMES[c.ivs.random.randi_range(0,24)])
	for stat in collection.ORDER: mon.base_stats[stat]=roundf(mon.base_stats[stat]*collection.factor(mon.nature,stat))
	mon.speed*=collection.factor(mon.nature,"spe")
	if individual.has("nickname"): mon.name=individual.nickname
	for key in ["shiny","ability_slot","gender","held_item"]:
		if individual.has(key): mon[key]=individual[key]
	c.abilities.assign(mon,individual.is_empty())
	return mon

func begin_battle(kind: String, ids: Array, levels: Array):
	if data.party.is_empty():
		dialog = "Choose a starter from Professor Oak first."
		return
	var first = -1
	for i in range(data.party.size()):
		if data.party[i].hp > 0:
			first = i
			break
	if first < 0:
		dialog = "Your team needs healing. Visit Mom or a Pokemon Center."
		return
	clear_ui()
	progress_lines.clear()
	progress_time = 0
	save()
	for species in ids: field.finish("seen:"+str(species))
	encounter = {"kind":kind,"ids":ids.duplicate(),"levels":levels.duplicate(),"rewarded":[],"participants":{}}
	exploring = false
	visible = false
	in_battle = true
	capture_time = 0
	c.campaign.active = false
	c.campaign.layer.visible = false
	c.selecting = false
	c.selection_controls.visible = false
	c.team_mode = true
	c.team_slot = 0
	c.player_team = data.party.map(func(mon): return c.Dex.find_id(c.roster,int(mon.id)))
	c.enemy_team = ids.map(func(id): return c.Dex.find_id(c.roster,int(id)))
	c.enemy_party = []
	for i in range(ids.size()): c.enemy_party.append(battle_mon(ids[i],levels[i]))
	c.opponent_identity = "wild" if kind=="wild" else "blue" if kind=="rival" else "brock" if kind=="brock" else "misty" if kind=="misty" else "giovanni" if kind=="rocket" else "bug_catcher"
	c.arena_choice.select(4 if kind=="misty" else 0 if data.map==6 else 3 if kind=="brock" else 6 if data.map==3 else 2)
	Story.prepare(self,kind)
	Finale.prepare(self,kind)
	c.weather_choice.select(0)
	c.reset()
	for i in range(data.party.size()):
		var fighter = c.player_states[i]
		fighter.data = battle_mon(int(data.party[i].id),int(data.party[i].level),data.party[i])
		fighter.data.moves = inventory.definitions(data.party[i].moves,data.party[i])
		fighter.hp = fighter.data.hp*float(data.party[i].hp)
		fighter.ailment = data.party[i].ailment
		fighter.ailment_time = 2.5 if fighter.ailment=="sleep" else 3.0 if fighter.ailment=="paralysis" else 5.0 if fighter.ailment=="freeze" else 8.0
	c.activate_player(first)
	c.horde.start(c)
	c.countdown = c.SEND_OUT_TIME

func sync_health():
	for i in range(mini(data.party.size(),c.player_states.size())):
		data.party[i].hp = clampf(c.player_states[i].hp/c.player_states[i].data.hp,0,1)
		data.party[i].ailment = c.player_states[i].ailment

func reward(victory: bool) -> String:
	if str(encounter.get("kind","")).begins_with("post_"): return expansion.reward(victory)
	var later_message=Finale.reward(self,victory)
	if not victory: return ""
	var message = later_message if later_message!="" else Story.reward(self,encounter.kind)
	if encounter.kind!="wild": data.money = mini(999999,int(data.money)+150)
	match encounter.kind:
		"rival": data.rival = true
		"bug": data.bug_catcher = true
		"rocket":
			data["rocket"] = true
			message = "Team Rocket defeated! The exit to Route 4 and Cerulean is open."
		"misty":
			if not data.get("cascade",false): data.tms["TM03"] = int(data.tms.get("TM03",0))+1
			data["cascade"] = true
			message = "Cascade Badge earned! TM03 Water Pulse is in your Bag."
		"brock":
			inventory.award_brock()
			data.badge = true
			message = "Boulder Badge earned! TM39 Rock Tomb is in your Bag. Route 3 and Mt. Moon are now open. " + message
	return message

func can_flee() -> bool:
	return in_battle and encounter.get("kind","")=="wild" and c.result=="" and c.countdown<=0 and not c.paused and not c.switch_menu and c.switch_time<0 and capture_time<=0 and c.player.hp>0 and c.enemy.hp>0 and c.player.get("action_lock",0)<=0 and c.player.get("charge_left",0)<=0

func flee():
	if not can_flee(): return
	clear_ui()
	return_world(false,true)

func return_world(caught: bool = false, escaped: bool = false):
	if not in_battle: return
	if escaped and not can_flee(): return
	if not caught and not escaped and (not c.resolution_ready() or c.can_continue_team()): return
	if not caught and not escaped: record_knockout()
	sync_health()
	var win = c.result == "VICTORY"
	var message = ""
	var new_entry={}
	if caught:
		collection.sync()
		var capture_xp=25+int(encounter.levels[c.enemy_active])*5
		var xp_message=grant_xp(capture_xp)
		var mon = new_mon(int(encounter.ids[c.enemy_active]),int(encounter.levels[c.enemy_active]))
		for key in ["shiny","ability_slot","gender"]: mon[key]=c.enemy.data.get(key, false if key=="shiny" else "N" if key=="gender" else 0)
		mon.ivs=c.enemy.data.ivs.duplicate(true)
		mon.nature=c.enemy.data.get("nature","Hardy")
		c.abilities.assign(mon)
		if not data.pokedex.get(str(int(mon.id)),{}).get("caught",false): new_entry=mon
		collection.register(mon)
		var joins_party = data.party.size() < 6
		if joins_party: data.party.append(mon)
		else: data.storage.append(mon)
		message = mon_name(mon.id)+" caught! "+("Added to your party." if joins_party else "Check Party / Storage with P.")+" +"+str(capture_xp)+" EXP. "+xp_message
	elif not escaped:
		message = reward(win)
		if world.enabled: world.events.battle_reward(str(encounter.kind),win)
		if win:
			for member in data.party:
				if member.get("ability","")=="Pickup" and c.abilities.random.randf()<0.1:
					data.bag["potion"]=mini(999,int(data.bag.get("potion",0))+1)
					message+=" Pickup found a Potion!"
		if not win:
			data.map = int(data.healing_map)
			position_world = Vector2(800,760)
			if world.enabled: world.enter(world.names.get(world.LEGACY[int(data.map)],"MAP_PALLET_TOWN"),Vector2(12,16)*world.TILE)
			for mon in data.party:
				mon.hp = 1.0
				mon.ailment = ""
			message = "Your team recovered at the last healing town. Try again!"
		elif encounter.kind=="wild": message=""
		elif message == "": message = "Battle won! Earned money and experience."
	if world.enabled: world.events.result(str(encounter.kind),win,caught)
	in_battle = false
	exploring = true
	visible = true
	c.selecting = true
	c.paused = false
	c.switch_menu = false
	c.shots.clear()
	c.click_move=false
	c.controls.run_active=false
	capture_time = 0
	wild_cycle += 1
	dialog = message
	if not new_entry.is_empty(): collection.dex_entry(int(new_entry.id),bool(new_entry.get("shiny",false)),true)
	elif not evolutions.is_empty(): show_evolution()
	save()
	queue_redraw()

func finish_capture_entry():
	clear_ui()
	if not evolutions.is_empty(): show_evolution()

func mark_participant():
	if not in_battle or encounter.is_empty(): return
	var targets=range(encounter.ids.size()) if c.horde.active(c) else [c.enemy_active]
	for slot in targets:
		if not c.horde.active(c) or slot>=c.enemy_bench.states.size() or c.enemy_bench.states[slot].hp>0: mark_participant_for(slot)

func mark_participant_for(slot):
	var key=str(slot)
	if not encounter.has("participants"): encounter["participants"]={}
	if not encounter.participants.has(key): encounter.participants[key]=[]
	if c.player_active not in encounter.participants[key]: encounter.participants[key].append(c.player_active)

func participants() -> Array:
	return encounter.get("participants",{}).get(str(c.enemy_active),[c.player_active])

func catch_chance() -> float:
	var weak = 1.0-clampf(c.enemy.hp/c.enemy.data.hp,0,1)
	return clampf(0.18+weak*0.65+(0.12 if c.enemy.ailment!="" else 0),0.1,0.95)

func throw_ball():
	if c.horde.active(c) and c.horde.living(c).size()>1:
		c.notice="HORDE / Leave one wild Pokemon before throwing a ball."; c.notice_time=2; return
	if not in_battle or encounter.kind!="wild" or c.result!="" or c.paused or c.countdown>0 or c.switch_menu or c.switch_time>=0 or capture_time>0: return
	if c.player.hp<=0 or c.enemy.hp<=0 or c.player.get("action_lock",0)>0: return
	if data.balls <= 0:
		c.notice = "NO POKE BALLS / visit Viridian's shop"
		c.notice_time = 2
		return
	if data.party.size() >= 6 and data.storage.size() >= 100: return
	data.balls -= 1
	save()
	capture_success = c.rng.randf() < catch_chance()
	capture_time = CAPTURE_DURATION
	c.notice = "POKE BALL / attempting capture..."
	c.notice_time = CAPTURE_DURATION

func capture_visual() -> Dictionary:
	var elapsed=CAPTURE_DURATION-capture_time
	var wobble=0.0
	for start in [0.95,1.65,2.35]:
		var phase=(elapsed-start)/0.35
		if phase>=0 and phase<=1: wobble=sin(phase*TAU)*sin(phase*PI)
	return {"elapsed":elapsed,"flight":clampf(elapsed/0.55,0,1),"wobble":wobble,"dark":capture_success and elapsed>=3.0 and elapsed<3.3,"hidden":elapsed>=0.55}

func tick_capture(dt):
	if c.paused: return
	capture_time = maxf(0,capture_time-dt)
	if capture_time<=0:
		if capture_success: return_world(true)
		else:
			c.notice = "Broke free! Weaken it or apply a status effect."
			c.notice_time = 2
			c.player.action_lock = 1.0

func back_ui():
	var callback=ui_back
	if callback.is_valid(): callback.call()
	else: clear_ui()

func clear_ui():
	ui_back=Callable()
	for child in ui.get_children(): child.queue_free()
	modal = ""

func panel(title: String, back=Callable()):
	c.click_move = false
	clear_ui()
	modal = title
	ui_back=back
	var bg = ColorRect.new()
	bg.color = Color(0.025,0.055,0.08,0.97)
	bg.position = Vector2(140,135)
	bg.size = Vector2(1000,690)
	ui.add_child(bg)
	ui_label(title,Vector2(180,165),28)
	ui_button("BACK / Esc" if back.is_valid() else "CLOSE / Esc",Vector2(900,755),Vector2(190,45),next_evolution if title.begins_with("EVOLUTION") else back_ui)

func ui_label(value, at, size = 19):
	var label = Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size",size)
	ui.add_child(label)

func ui_button(value, at, extent, action):
	var button = Button.new()
	button.text = value
	button.position = at
	button.size = extent
	button.pressed.connect(action)
	ui.add_child(button)

func starter_menu():
	panel("OAK'S LAB / CHOOSE YOUR PARTNER")
	ui_label("Your partner will travel, grow and battle alongside you.",Vector2(180,225))
	for i in range(3):
		var id = STARTERS[i]
		var portrait = TextureRect.new()
		portrait.texture = c.portraits[id]
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position = Vector2(220+i*300,310)
		portrait.size = Vector2(200,200)
		ui.add_child(portrait)
		ui_button(mon_name(id)+" / Lv.5",Vector2(190+i*300,550),Vector2(270,60),choose_starter.bind(id))

func party_menu():
	panel("YOUR TEAM / choose a lead Pokemon")
	for i in range(data.party.size()):
		var mon = data.party[i]
		ui_button("%s\nLv.%d  / HP %d%% / XP %d%s" % [mon_name(mon.id)+(" *" if mon.get("shiny",false) else "")+" / "+c.abilities.legal(mon.id)[int(mon.get("ability_slot",0))%c.abilities.legal(mon.id).size()],mon.level,roundi(mon.hp*100),mon.xp," / LEAD" if i==0 else ""],Vector2(180,230+i*66),Vector2(680,54),set_lead.bind(i))
	ui_button("SUMMARY / IVs / EVs",Vector2(890,470),Vector2(210,55),collection.members)
	ui_button("POKEDEX",Vector2(890,550),Vector2(210,55),collection.dex)
	ui_button("MOVESETS",Vector2(890,310),Vector2(210,55),inventory.move_party)
	ui_button("BAG / "+c.controls.text("bag"),Vector2(890,390),Vector2(210,55),inventory.bag)
	ui_button("STORAGE (%d)" % data.storage.size(),Vector2(890,230),Vector2(210,55),storage_menu)

func set_lead(slot):
	var first = data.party[0]
	data.party[0] = data.party[slot]
	data.party[slot] = first
	save()
	party_menu()

func storage_menu():
	collection.pc()

func withdraw(slot):
	if in_battle or slot<0 or slot>=data.storage.size(): return
	var mon = data.storage[slot]
	if data.party.size()>=6 and mon.hp<=0 and not data.party.slice(1).any(func(m):return m.hp>0):
		clear_ui(); dialog="Keep a healthy partner in your party."; return
	if data.party.size()>=6 and field.losing_surf(0,mon): clear_ui(); return
	if data.party.size()<6:
		data.party.append(mon)
		data.storage.remove_at(slot)
	else:
		data.storage[slot] = data.party[0]
		data.party[0] = mon
	save()
	party_menu()

func menu():
	panel("ADVENTURE / KANTO / SLOT "+str(c.save_slots.selected+1))
	ui_label(objective(),Vector2(180,240))
	ui_label("Progress saves automatically on the map and after encounters.",Vector2(180,290))
	ui_button("QUEST JOURNAL / MAP",Vector2(650,375),Vector2(400,65),expansion.journal)
	ui_button("CHAMPION CHALLENGES",Vector2(650,465),Vector2(400,65),expansion.hub)
	ui_button("YOUR TEAM",Vector2(180,375),Vector2(400,65),party_menu)
	ui_button("SAVE AND CONTINUE",Vector2(180,465),Vector2(400,65),func(): save(); clear_ui())
	ui_button("SAVE AND RETURN TO MODES",Vector2(180,555),Vector2(600,65),leave)
	ui_button("RESET THIS SAVE SLOT",Vector2(180,650),Vector2(400,55),confirm_reset)

func words(value: String, at: Vector2, size = 20, color = Color("eef4de")):
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func tree(at: Vector2):
	draw_circle(at+Vector2(8,15),38,Color(0.04,0.13,0.09,0.22))
	draw_rect(Rect2(at+Vector2(-7,-5),Vector2(14,32)),Color("72543c"))
	draw_circle(at+Vector2(0,-25),37,Color("245f48"))
	draw_circle(at+Vector2(-9,-36),29,Color("38815a"))
	draw_circle(at+Vector2(-14,-46),17,Color("579665"))

func person(at: Vector2, identity: String, direction = 1.0, bob = 0.0):
	var sprite = c.art.trainers.sprites[identity]
	var scale_factor = sprite.scale*0.65
	var extent: Vector2 = sprite.size*scale_factor
	draw_set_transform(at+Vector2(0,95)-camera,0,Vector2(1,0.3))
	draw_circle(Vector2.ZERO,19,Color(0,0,0,0.22))
	draw_set_transform(Vector2(0,90)-camera)
	draw_texture_rect(sprite.right if direction>0 else sprite.left,Rect2(at+Vector2(-extent.x/2,-sprite.bottom*scale_factor-bob),extent),false)

func _draw():
	if not exploring: return
	if world.enabled: world.draw(); return
	draw_rect(Rect2(0,0,1280,960),Color("142e32"))
	draw_set_transform(Vector2(0,90)-camera)
	var forest = data.map==3
	var cave = data.map in [6,24]
	draw_rect(Rect2(0,0,1600,1000),Color("48495e") if cave else Color("619466") if forest else Color("87b878"))
	Kanto.draw_ground(self)
	for y in range(0,1000,40):
		for x in range(0,1600,40):
			if (x/40+y/40)%3==0:
				draw_line(Vector2(x+8,y+15),Vector2(x+12,y+9),Color(0.2,0.45,0.24,0.28),2)
				draw_line(Vector2(x+12,y+17),Vector2(x+17,y+11),Color(0.2,0.45,0.24,0.28),2)
	if data.map==8:
		draw_circle(Vector2(1270,140),150,Color("3d9eb4"))
		draw_arc(Vector2(1270,140),145,0,TAU,50,Color("a6decd"),5)
	draw_rect(Rect2(710,0,180,1000),Color("6b6877") if cave else Color("cfbc87"))
	draw_rect(Rect2(725,0,150,1000),Color("85808a") if cave else Color("ddcb96"))
	if Kanto.destination(int(data.map),2)>=0 or Kanto.destination(int(data.map),-2)>=0:
		draw_rect(Rect2(0,775,1600,90),Color("ddcb96"))
	if not buildings().is_empty(): draw_rect(Rect2(360,615,900,95),Color("ddcb96"))
	for y in range(70,1000,100):
		for x in [45,145,1455,1555]:
			if cave:
				draw_circle(Vector2(x,y),58,Color("303346"))
				draw_circle(Vector2(x-8,y-14),42,Color("626477"))
			else: tree(Vector2(x,y))
	# Small gardens and path stones give the chapter maps a readable outdoor layout.
	for i in range(45):
		var flower = Vector2(210+(i*173)%1190,110+(i*97)%760)
		if flower.x>680 and flower.x<920: continue
		var covered = false
		for building in buildings():
			if building[0].grow(30).has_point(flower): covered = true
		if covered: continue
		if cave:
			draw_circle(flower,17 if i%3==0 else 7,Color("73768c"))
			continue
		draw_circle(flower,3,Color("e6cd80") if i%2==0 else Color("d6a1aa"))
		draw_line(flower+Vector2(0,3),flower+Vector2(0,8),Color("487c48"),2)
	for y in range(100,1000,115):
		draw_line(Vector2(745,y),Vector2(770,y+2),Color(0.6,0.5,0.3,0.18),2)
	if forest:
		for y in range(120,1000,160):
			for x in [260,620,1000,1320]: tree(Vector2(x,y))
	Story.draw(self)
	Finale.draw(self)
	for building in buildings():
		var r: Rect2 = building[0]
		draw_rect(Rect2(r.position+Vector2(12,15),r.size),Color(0,0,0,0.18))
		draw_rect(r,Color("e5dcc2"))
		draw_rect(Rect2(r.position,r.size*Vector2(1,0.42)),building[2])
		for y in range(4): draw_line(r.position+Vector2(0,y*23),r.position+Vector2(r.size.x,y*23),building[2].lightened(0.14),2)
		draw_rect(Rect2(r.position+Vector2(r.size.x/2-22,r.size.y-70),Vector2(44,70)),Color("4b6261"))
		for x in [35,r.size.x-80]:
			draw_rect(Rect2(r.position+Vector2(x,125),Vector2(44,44)),Color("8cc4ca"))
			draw_rect(Rect2(r.position+Vector2(x,125),Vector2(44,44)),Color("f6efd4"),false,4)
		words(building[1],r.position+Vector2(15,25),18)
	for spawn in wild_spawns():
		var p: Vector2 = spawn[0]
		draw_circle(p,45,Color(0.3,0.5,0.26,0.4))
		draw_texture_rect(c.portraits[spawn[1]],Rect2(p+Vector2(-30,-55+sin(time*2)*3),Vector2(60,60)),false)
		words(mon_name(spawn[1])+" Lv."+str(spawn[2]),p+Vector2(-65,28),16)
		if position_world.distance_to(p)<95: words("E / BATTLE",p+Vector2(-45,-75),18,Color("ffe499"))
	for npc in npcs():
		var id = "brock" if npc[2]=="brock" else "giovanni" if npc[2]=="rocket" else ("blue" if npc[2] in ["rival","bug"] else ("blaine" if npc[2]=="oak" else "misty"))
		if npc[2]=="story_surge": id="surge"
		if npc[2] in ["story_bridge","story_shipblue","story_bill"]: id="blue"
		if npc[2]=="story_bridge" and Story.state(self).get("bridge_blue",false): id="giovanni" if int(Story.state(self).get("bridge",0))==5 else "brock" if int(Story.state(self).get("bridge",0))%2==0 else "misty"
		if npc[2]=="story_captain": id="blaine"
		if npc[2]=="story_sailor": id="surge"
		if npc[2].begins_with("late_task_"):
			var task=Finale.TASKS.get(npc[2].trim_prefix("late_task_"),{})
			id=task.get("trainer",task.get("identity","blaine"))
		if npc[2]=="late_league": id=Finale.league_trainer(self).id.split("_")[0]
		if npc[2].begins_with("late_enter_"):
			draw_rect(Rect2(npc[0]+Vector2(-26,-52),Vector2(52,52)),Color("c8b17d"),false,4)
			draw_line(npc[0]+Vector2(0,-40),npc[0]+Vector2(0,-8),Color("fff0b0"),3)
		elif not npc[2].begins_with("story_switch") and npc[2]!="story_console": person(npc[0],id)
		words(npc[1],npc[0]+Vector2(-70,25),17)
		if position_world.distance_to(npc[0])<100: words("E / TALK",npc[0]+Vector2(-35,-78),18,Color("ffe499"))
	person(position_world,"red",facing,absf(sin(walk_age*12))*4)
	if c.click_move: draw_arc(c.click_destination,13,0,TAU,24,Color("ffdf92"),2)
	Kanto.draw_signs(self)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0,0,1280,90),Color("112b32"))
	words(MAPS[data.map],Vector2(30,34),26,Color("ffdf92"))
	words(objective(),Vector2(30,66),18)
	words("BALLS %d   $%d   BADGES %d/8" % [data.balls,data.money,Finale.badges(self)],Vector2(850,35),18)
	draw_rect(Rect2(0,790,1280,170),Color("112b32"))
	for i in range(data.party.size()):
		var mon = data.party[i]
		var x = 25+i*208
		draw_texture_rect(c.portrait(mon),Rect2(x,805,48,48),false)
		words(mon_name(mon.id),Vector2(x+52,825),16)
		words("Lv.%d / HP %d%%" % [mon.level,roundi(mon.hp*100)],Vector2(x+52,847),14)
		draw_rect(Rect2(x+10,862,180,5),Color("354c50"))
		draw_rect(Rect2(x+10,862,180*mon.hp,5),Color("77e2b0"))
		draw_rect(Rect2(x+10,875,180,4),Color("354c50"))
		draw_rect(Rect2(x+10,875,180*xp_ratio(mon),4),Color("79aaff"))
		words("EXP %d / %d" % [mon.xp,xp_needed(mon)] if mon.level<100 else "MAX LEVEL",Vector2(x+10,898),12,Color("79aaff"))
	words("Run: "+c.controls.text("sprint")+"   Talk: "+c.controls.text("interact")+"   Team: "+c.controls.text("party")+"   Bag: "+c.controls.text("bag")+"   Save: "+c.controls.text("save")+"   Map: "+c.controls.text("map")+"   Esc: Menu",Vector2(30,925),17)
	if save_error!="": words(save_error,Vector2(30,953),15,Color("ff9999"))
	if dialog!="":
		draw_rect(Rect2(80,630,1120,145),Color("10252f"))
		draw_rect(Rect2(80,630,1120,145),Color("d5be82"),false,2)
		draw_multiline_string(font,Vector2(105,665),wrapped(dialog),HORIZONTAL_ALIGNMENT_LEFT,1060,20,4,Color("eef4de"))
		words(c.controls.text("interact")+" / CONTINUE",Vector2(1010,750),16,Color("ffdf92"))

func tests():
	var saved_data = data.duplicate(true)
	var saved_path = save_path
	var saved_loaded = loaded
	var saved_campaign = c.campaign.data.duplicate(true)
	save_path = "user://adventure-regression-test.json"
	loaded = true
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))
	enter()
	travel(1)
	c.check(data.map==0,"Adventure requires starter and rival before Route 1")
	choose_starter(4)
	choose_starter(7)
	c.check(data.party.size()==1 and data.starter==4,"Starter cannot be claimed twice")
	begin_battle("rival",[7],[5])
	c.check(c.player_states.size()==1 and c.enemy_party.size()==1,"Adventure battles use owned party only")
	var balls_before = data.balls
	c.countdown = 0
	throw_ball()
	c.check(data.balls==balls_before,"Trainer Pokemon cannot be captured")
	c.enemy.hp = 0
	c.finish_round()
	c.shots.clear()
	c.result_time = 10
	return_world()
	c.check(data.rival and exploring,"Rival victory unlocks route and returns to world")
	travel(1)
	c.check(data.map==1,"Route unlocked after rival")
	begin_battle("rival",[7],[5]); c.countdown=0; c.player.action_lock=0
	flee(); c.check(in_battle,"Cannot flee trainer battles")
	begin_battle("wild",[19],[4]); c.countdown=0; c.player.action_lock=0; c.player.charge_left=0
	var flee_money=data.money; var flee_xp=data.party[0].xp; var flee_balls=data.balls
	var flee_position=position_world
	c.player.hp=c.player.data.hp*0.5
	capture_time=1; flee(); c.check(in_battle,"Cannot flee during a capture")
	capture_time=0; flee()
	c.check(exploring and not in_battle and position_world==flee_position,"Flee returns to the same overworld position")
	c.check(data.money==flee_money and data.party[0].xp==flee_xp and data.balls==flee_balls,"Flee gives no XP or money and consumes no balls")
	c.check(is_equal_approx(data.party[0].hp,0.5),"Flee preserves damage instead of healing")
	begin_battle("wild",[16],[4])
	c.countdown = 0
	c.player.action_lock = 0
	c.enemy.hp = c.enemy.data.hp
	var healthy_chance = catch_chance()
	var caught_ivs=c.enemy.data.ivs.duplicate(true)
	var caught_nature=c.enemy.data.nature
	c.enemy.data.shiny=true
	c.enemy.data.ability_slot=1
	c.abilities.assign(c.enemy.data)
	c.enemy.hp = 1
	c.check(catch_chance()>healthy_chance,"Weakening wild Pokemon improves capture probability")
	throw_ball()
	c.check(data.balls==balls_before-1 and capture_time>0,"Capture consumes one ball")
	capture_success = true
	capture_time=CAPTURE_DURATION-3.1
	c.check(capture_visual().dark,"Successful capture briefly darkens the ball")
	capture_success=false
	c.check(not capture_visual().dark,"Failed capture never uses success darkening")
	capture_success=true
	capture_time=CAPTURE_DURATION
	tick_capture(CAPTURE_DURATION+0.1)
	c.check(data.party.size()==2 and data.party[1].id==16 and exploring,"Captured Pokemon joins saved party")
	c.check(data.party[1].shiny and data.party[1].ability_slot==1,"Capture preserves shiny and ability identity")
	c.check(data.party[1].ivs==caught_ivs,"Capture preserves the encountered Pokemon IVs")
	c.check(data.party[1].nature==caught_nature,"Capture preserves the encountered nature")
	data.party[0].hp = 0.4
	save()
	data.money = 999
	load_save()
	c.check(data.party[1].shiny and int(data.party[1].ability_slot)==1,"Shiny and ability survive save/load")
	c.check(data.party[1].ivs==caught_ivs,"Captured IVs survive actual save/reload")
	c.check(data.money!=999 and is_equal_approx(data.party[0].hp,0.4),"Adventure save restores health and inventory")
	save()
	var corrupt = FileAccess.open(save_path,FileAccess.WRITE)
	corrupt.store_string("{damaged")
	corrupt.close()
	load_save()
	c.check(save_allowed and data.party.size()==2,"Adventure recovers valid backup")
	begin_battle("wild",[19],[5])
	for fighter in c.player_states: fighter.hp = 0
	c.finish_round()
	c.shots.clear()
	c.result_time = 10
	return_world()
	c.check(data.map==0 and data.party.all(func(mon):return mon.hp==1),"Defeat heals party at last healing town")
	data.party[0] = new_mon(4,15)
	data.party[0].xp = 109
	encounter = {"kind":"wild","levels":[5]}
	grant_xp(50)
	c.check(data.party[0].id==5 and data.party[0].level==16,"Starter evolves after level threshold")
	data.map = 3
	travel(1)
	c.check(data.map==3,"Forest trainer gates Pewter")
	data.bug_catcher = true
	travel(1)
	c.check(data.map==4,"Pewter unlocks after forest trainer")
	begin_battle("brock",[74,95],[10,12])
	c.enemy.hp = 0
	c.finish_round()
	c.shots.clear()
	c.result_time = 10
	c.check(c.can_continue_team(),"Brock retains second Pokemon")
	c.advance_team()
	c.check(c.enemy.data.id==95,"Brock sends out Onix")
	c.enemy.hp = 0
	c.finish_round()
	c.shots.clear()
	c.result_time = 10
	return_world()
	c.check(data.badge and c.campaign.data==saved_campaign,"Boulder Badge stays independent from League progress")
	inventory.tests()
	chapter_tests()
	Story.tests(self)
	Finale.tests(self)
	Kanto.tests(self)
	reset_tests()
	leave()
	c.campaign.layer.visible = false
	c.frontend.layer.visible = false
	c.check(c.player_team.size()==6,"Leaving adventure restores arena team")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))
	data = saved_data
	save_path = saved_path
	loaded = saved_loaded
	save_error = ""
	dialog = ""

func show_dialogue(text: String):
	text=text.replace("{PLAYER}","TRAINER").replace("{RIVAL}","BLUE").replace("{POKEBLOCK}","POKEBLOCK")
	var pages=[]
	for paragraph in text.split("\n\n"):
		var lines=wrapped(paragraph.replace("\n"," ")).split("\n")
		for start in range(0,lines.size(),3): pages.append(" ".join(lines.slice(start,mini(start+3,lines.size()))))
	if pages.is_empty(): return
	dialog=pages.pop_front()
	dialog_pages=pages

func advance_dialogue():
	var remaining=dialog_pages.duplicate()
	dialog="" if remaining.is_empty() else str(remaining.pop_front())
	dialog_pages=remaining

func wrapped(value: String) -> String:
	var output = ""
	var line = ""
	for word in value.split(" "):
		if font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x > 1020:
			output += line+"\n"
			line = ""
		line += word+" "
	return output+line

func show_evolution():
	if evolutions.is_empty():
		clear_ui()
		return
	var pair = evolutions[0]
	panel("EVOLUTION / "+mon_name(pair[0])+" → "+mon_name(pair[1]))
	for i in range(2):
		var picture = TextureRect.new()
		picture.texture = c.portrait({"id":pair[i],"shiny":pair[2] if pair.size()>2 else false})
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position = Vector2(240+i*500,295)
		picture.size = Vector2(220,220)
		ui.add_child(picture)
		ui_label(mon_name(pair[i]),Vector2(260+i*500,555),26)
		if i==1:
			picture.modulate = Color(1,1,1,0)
			var tween = picture.create_tween()
			tween.tween_property(picture,"modulate",Color.WHITE,0.8)
	ui_label("→",Vector2(608,390),48)
	ui_label("Your partner evolved! Learned moves are kept.",Vector2(240,625),22)
	ui_button("CONTINUE",Vector2(485,700),Vector2(300,50),next_evolution)

func next_evolution():
	evolutions.pop_front()
	show_evolution()

func grant_xp(amount: int) -> String:
	var message = ""
	for slot in range(data.party.size()):
		var mon=data.party[slot]
		if mon.hp <= 0: continue
		var earned=amount
		if in_battle:
			if slot in participants(): earned=maxi(1,amount/maxi(1,participants().size()))
			elif mon.get("held_item","")=="expshare": earned=maxi(1,amount/2)
			else: continue
		mon.xp += earned
		while mon.level < 100 and mon.xp >= 20+mon.level*6:
			mon.xp -= 20+mon.level*6
			var old_id = int(mon.id)
			mon.level += 1
			mon.hp = minf(1,mon.hp+0.2)
			message += mon_name(mon.id)+" reached Lv."+str(mon.level)+"! "
			if EVOLUTIONS.has(int(mon.id)) and mon.level >= EVOLUTIONS[int(mon.id)][0]:
				evolutions.append([int(mon.id),int(EVOLUTIONS[int(mon.id)][1]),mon.get("shiny",false)])
				collection.register(mon)
				mon.id = EVOLUTIONS[int(mon.id)][1]
				c.abilities.assign(mon)
				message += "Evolved into "+mon_name(mon.id)+"! "
			var known_before = mon.moves.duplicate()
			var pending_before = mon.pending.duplicate()
			inventory.level_up(mon,old_id,int(mon.level))
			for move in mon.moves:
				if move not in known_before: message += mon_name(mon.id)+" learned "+inventory.book.moves[move].name+"! "
			for move in mon.pending:
				if move not in pending_before: message += mon_name(mon.id)+" can learn "+inventory.book.moves[move].name+" ("+c.controls.text("party")+" / MOVESETS). "
		if mon.level>=100: mon.xp = 0
		if not mon.pending.is_empty(): message += "New moves waiting: P / MOVESETS. "
	return message

func xp_needed(mon) -> int:
	return 20+int(mon.level)*6

func xp_ratio(mon) -> float:
	return 1.0 if mon.level>=100 else clampf(float(mon.xp)/xp_needed(mon),0,1)

func record_knockout(immediate=false):
	if not in_battle or c.enemy.hp>0 or (not immediate and not c.resolution_ready()): return
	if not encounter.has("rewarded"): encounter.rewarded = []
	if c.enemy_active in encounter.rewarded: return
	encounter.rewarded.append(c.enemy_active)
	if encounter.kind=="post_tower": return
	sync_health()
	var amount = 25+int(encounter.levels[c.enemy_active])*5
	c.ivs.award_evs(int(encounter.ids[c.enemy_active]),participants())
	var old_levels=data.party.map(func(member):return int(member.level))
	var message = grant_xp(amount)
	for i in range(data.party.size()):
		var fighter = c.player_states[i]
		var mon = data.party[i]
		if not fighter.get("transformed",false):
			fighter.data = battle_mon(int(mon.id),int(mon.level),mon)
			fighter.data.moves = inventory.definitions(mon.moves,mon)
		fighter.hp = fighter.data.hp*mon.hp
	progress_lines = ["+"+str(amount)+" EXP / "+mon_name(int(encounter.ids[c.enemy_active]))+" defeated"]
	if message!="": progress_lines.append(message)
	progress_summary=progress_lines[0]
	var evs=c.ivs.ev_yields.get(str(int(encounter.ids[c.enemy_active])),{})
	var ev_text=[]
	for stat in evs:
		if int(evs[stat])>0: ev_text.append("+"+str(int(evs[stat]))+" "+stat.to_upper())
	progress_summary+=" / EV yield: "+", ".join(ev_text)
	if "learned" in message or "can learn" in message: progress_summary+=" / NEW MOVES: "+c.controls.text("party")
	var leveled=[]
	for i in range(data.party.size()):
		if data.party[i].level>old_levels[i]: leveled.append(mon_name(data.party[i].id)+" Lv."+str(data.party[i].level))
	if not leveled.is_empty(): progress_summary+=" / "+", ".join(leveled)
	progress_time = 4.0
	save()

func draw_progress():
	if data.party.is_empty(): return
	var mon = data.party[c.player_active]
	c.bar(Vector2(122,173),310,xp_ratio(mon),Color("79aaff"),4)
	c.label_at("EXP %d/%d" % [mon.xp,xp_needed(mon)] if mon.level<100 else "MAX LEVEL",Vector2(40,177),10,Color("79aaff"))
	if progress_time>0:
		# Header-only notification: never cover the playable rectangle (y=180..780).
		var text=progress_summary
		if font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x>900:
			while text.length()>0 and font.get_string_size(text+"...",HORIZONTAL_ALIGNMENT_LEFT,-1,14).x>900: text=text.left(text.length()-1)
			text+="..."
		c.draw_string(font,Vector2(40,63),text,HORIZONTAL_ALIGNMENT_LEFT,900,14,Color("b9ddff"))

func chapter_tests():
	var snapshot = data.duplicate(true)
	data.party = [new_mon(4,6)]
	data.party[0].xp = xp_needed(data.party[0])-1
	data.map = 4
	data.badge = false
	travel(1)
	c.check(data.map==4,"Brock gates Route 3")
	data.badge = true
	travel(1)
	c.check(data.map==5,"Route 3 opens after Brock")
	begin_battle("lass",[21,39],[11,12])
	c.enemy.hp = 0
	c.finish_round()
	c.shots.clear()
	c.result_time = 10
	record_knockout()
	c.check(data.party[0].level==8 and "ember" in data.party[0].moves,"First KO levels up inside trainer battle and learns Ember")
	c.check(c.player.data.level==8 and c.player.data.moves.any(func(move):return move.id=="ember"),"Live fighter gets new level and learned move before next opponent")
	c.check("learned Ember" in " ".join(progress_lines),"New skill notification names learned move")
	var experience = data.party[0].xp
	var earned_evs=data.party[0].get("training",{}).duplicate(true)
	record_knockout()
	c.check(data.party[0].xp==experience,"KO XP is credited only once")
	c.check(data.party[0].training==earned_evs,"KO EVs are credited only once")
	c.advance_team()
	c.check(c.enemy.data.id==39,"Next opponent enters after XP award")
	c.enemy.hp = 0
	c.finish_round()
	c.shots.clear()
	c.result_time = 10
	record_knockout()
	var level = data.party[0].level
	experience = data.party[0].xp
	return_world()
	c.check(data.party[0].level==level and data.party[0].xp==experience,"End-of-battle reward does not duplicate KO XP")
	data.map = 6
	data["rocket"] = false
	travel(1)
	c.check(data.map==6,"Rocket gates Mt. Moon exit")
	data.rocket = true
	travel(1)
	travel(1)
	c.check(data.map==8,"Route 4 connects to Cerulean")
	heal()
	c.check(data.healing_map==8,"Cerulean is a valid healing checkpoint")
	encounter = {"kind":"misty","levels":[18,21]}
	reward(true)
	var tms = data.tms.TM03
	reward(true)
	c.check(data.cascade and data.tms.TM03==tms,"Misty awards Cascade Badge and one Water Pulse TM")
	save()
	load_save()
	c.check(data.map==8 and data.cascade and data.rocket,"Chapter 2 progress survives save reload")
	data.party=[new_mon(25,10)]
	var gold=data.money
	begin_battle("wild",[16],[5]); c.enemy.hp=0; c.finish_round(); c.shots.clear(); c.result_time=10
	record_knockout(); var wild_evs=data.party[0].training.duplicate(true)
	return_world()
	c.check(data.money==gold,"Wild Pokemon victories award no money")
	c.check(dialog=="" and not in_battle,"Wild victories return silently to the map")
	c.check(int(data.party[0].training.spe)==1 and data.party[0].training==wild_evs,"Wild KO awards species EVs once across return to map")
	data = snapshot
	evolutions.clear()
	progress_time = 0
	clear_ui()
	save()

func confirm_reset():
	if not exploring or in_battle: return
	panel("RESET ADVENTURE?")
	ui_label("Start again in Pallet Town and choose a new starter.",Vector2(180,255),23)
	ui_label("This resets your Pokemon, storage, levels, moves, money,\nitems, TMs, adventure badges and story progress.",Vector2(180,325),21)
	ui_label("Gym Leaders progress and Free Battles are not affected.",Vector2(180,435),21)
	ui_button("CANCEL / KEEP MY ADVENTURE",Vector2(180,540),Vector2(680,65),menu)
	ui_button("YES / START A NEW ADVENTURE",Vector2(180,635),Vector2(680,65),reset_adventure)

func reset_adventure() -> bool:
	if not exploring or in_battle or modal!="RESET ADVENTURE?": return false
	# Keep a manual recovery copy, separate from the automatically loaded backup.
	var archive = save_path+".before-reset-"+str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec())
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(save_path+suffix):
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path+suffix),ProjectSettings.globalize_path(archive+suffix))!=OK:
				clear_ui()
				dialog = "Reset cancelled: could not preserve your previous save."
				return false
	var previous = data.duplicate(true)
	var previous_position = position_world
	var previous_allowed = save_allowed
	var previous_world=world.enabled
	world.enabled=false
	data = INITIAL_DATA.duplicate(true)
	inventory.migrate()
	position_world = Vector2(data.x,data.y)
	if previous_world: world.activate()
	save_allowed = true
	if not save():
		data = previous
		world.enabled=previous_world
		if previous_world: world.current=data.get("world_map","MAP_PALLET_TOWN")
		position_world = previous_position
		save_allowed = previous_allowed
		clear_ui()
		dialog = "Reset failed. Previous adventure retained. "+save_error
		return false
	# Recovery must start this new adventure too, never silently resurrect the old run.
	var backup_ok = DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path),ProjectSettings.globalize_path(save_path+".bak"))==OK
	if not backup_ok:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+".bak"))
	loaded = true
	encounter.clear()
	evolutions.clear()
	progress_lines.clear()
	progress_time = 0
	capture_time = 0
	capture_success = false
	wild_cycle = 0
	c.click_move = false
	autosave = 0
	walk_age = 0
	camera = (position_world-Vector2(640,350)).clamp(Vector2.ZERO,Vector2(320,300))
	c.shots.clear()
	c.selecting = true
	c.paused = false
	c.switch_menu = false
	clear_ui()
	dialog = "New adventure started! Find Professor Oak inside his lab and press "+c.controls.text("interact")+"."
	if not backup_ok: dialog += " Save succeeded; backup could not be refreshed."
	if OS.get_cmdline_user_args().is_empty(): avatar.show_creator(self)
	queue_redraw()
	return true

func reset_tests():
	data["avatar"] = avatar.DEFAULT.duplicate(true)
	var campaign_before = c.campaign.data.duplicate(true)
	data.party = [new_mon(4,16)]
	data.storage = [new_mon(25,12)]
	data.starter = 4
	data.badge = true
	data["cascade"] = true
	data["rocket"] = true
	data["journey"]={"champion":true,"league":2}
	data["hall_of_fame"]=[{"id":6,"level":60}]
	data.money = 9000
	data.map = 8
	data.healing_map = 8
	data.tms = {"TM03":1}
	save()
	var before = data.duplicate(true)
	confirm_reset()
	menu()
	c.check(data==before,"Cancelling Adventure reset keeps progress")
	c.check(not reset_adventure(),"Reset requires its explicit confirmation screen")
	confirm_reset()
	c.check(reset_adventure(),"Confirmed reset succeeds")
	c.check(data.party.is_empty() and data.storage.is_empty() and data.starter==0 and data.map==0 and data.money==300 and data.balls==10,"Reset restores Pallet and initial inventory")
	c.check(not data.badge and not data.get("cascade",false) and not data.get("rocket",false) and data.tms.is_empty(),"Reset clears adventure badges, TMs and story flags")
	c.check(not data.has("avatar"),"Adventure reset clears character appearance")
	c.check(not data.has("journey") and not data.has("hall_of_fame"),"Adventure reset clears full Kanto and Hall of Fame")
	c.check(c.campaign.data==campaign_before,"Adventure reset leaves Gym Leaders progress untouched")
	load_save()
	c.check(data.starter==0 and data.party.is_empty(),"New adventure persists after reload")
	var backup = JSON.parse_string(FileAccess.get_file_as_string(save_path+".bak"))
	c.check(valid(backup) and backup.starter==0 and backup.party.is_empty(),"Recovery backup belongs to the new adventure")
	# Remove only archives belonging to this isolated regression fixture.
	var directory = DirAccess.open(save_path.get_base_dir())
	for file in directory.get_files():
		if file.begins_with(save_path.get_file()+".before-reset-"):
			directory.remove(file)
	clear_ui()


func _exit_tree():
	world.scenes.reset()
