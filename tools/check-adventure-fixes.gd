extends SceneTree
var c
var a
var w

func _initialize(): run.call_deferred()

func fixture(map_id: String):
	a.clear_ui(); w.scenes.reset(); a.dialog=""; a.in_battle=false; a.exploring=true; a.visible=true
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true; a.data.party=[a.new_mon(4,15)]; a.inventory.migrate()
	w.enabled=true; w.current=map_id; w.events.refresh(); w.stepping=false; w.warp_latch=""
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selecting=false; c.paused=false

func key(code):
	var event=InputEventKey.new(); event.physical_keycode=code; event.pressed=true; a.handle_input(event)

func snap(name):
	a.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/fixes-"+name+".png")

func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame
	c.set_process(false); a=c.adventure; a.save_allowed=false; a.loaded=true; w=a.world; w.view3d.enabled=true
	fixture("MAP_ROUTE1")
	var grass=-1
	for i in w.events.catalog[w.current].behavior.size():
		if int(w.events.catalog[w.current].behavior[i])==2: grass=i; break
	a.position_world=Vector2(grass%int(w.room().width)+.5,int(grass/int(w.room().width))+.5)*48; w.heading=Vector2.DOWN
	key(KEY_SPACE); c.check(not a.in_battle,"Space on grass cannot start an encounter")
	key(KEY_X); c.check(c.controls.run_active,"X enables run toggle")
	key(KEY_X); c.check(not c.controls.run_active,"X disables run toggle")
	key(KEY_E); c.check(a.in_battle and a.encounter.kind=="wild","E starts a manual habitat encounter")
	fixture("MAP_VIRIDIAN_CITY_POKEMON_CENTER_1F")
	var room=w.room(); var behavior=w.events.catalog[w.current].behavior; var pc=-1
	for i in behavior.size():
		if int(behavior[i]) in [0x83,0x97]: pc=i; break
	c.check(pc>=0,"Center has an interactable source PC")
	var pc_at=Vector2(pc%int(room.width)+.5,int(pc/int(room.width))+.5)*48
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		if not w.blocked(pc_at-direction*48): a.position_world=pc_at-direction*48; w.heading=direction; break
	key(KEY_SPACE); c.check(a.modal.begins_with("PC /"),"Space on the map PC opens actual storage")
	await snap("pc"); a.clear_ui()
	a.position_world=Vector2(7.5,4.5)*48; w.heading=Vector2.UP; a.data.party[0].hp=.3
	key(KEY_SPACE); c.check(a.data.party[0].hp==1.0,"Nurse heals across the counter")
	a.dialog=""; var exit=w.room().warps[0]; a.position_world=w.events.point(exit)+Vector2.UP*48
	var map_before=w.current; key(KEY_SPACE); c.check(w.current==map_before,"Talking beside an exit never activates a nearby warp")
	fixture("MAP_MT_MOON_B2F")
	var miguel=w.actors().filter(func(n):return str(n.script).ends_with("_Miguel"))[0]
	a.position_world=miguel.pos+Vector2.RIGHT*48; w.heading=Vector2.LEFT
	key(KEY_SPACE); c.check(w.scenes.active,"Talking to fossil guard starts his introduction")
	w.scenes.finish(); c.check(a.in_battle and a.encounter.ids==[88,100,109] and a.encounter.levels==[12,12,12],"Miguel battle has the original three level-12 Pokemon")
	a.in_battle=false; a.exploring=true; a.visible=true
	w.events.battle_reward("world_MtMoon_B2F_EventScript_Miguel",true); a.dialog=""; key(KEY_SPACE)
	c.check(not w.scenes.active and not a.in_battle,"Defeated fossil guard cannot demand another fight")
	fixture("MAP_PALLET_TOWN")
	c.check(not w.quest_actors().any(func(n):return n[2]=="rival"),"Blue no longer waits for repeat fights in Pallet")
	fixture("MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB")
	c.check(not w.actors().any(func(n):return n.graphics_id=="OBJ_EVENT_GFX_BLUE"),"Blue leaves the lab after the first rival battle")
	w.events.finish("parcel_received"); a.position_world=Vector2(6.5,4.5)*48; w.heading=Vector2.UP
	key(KEY_SPACE); c.check(w.scenes.active and not w.events.done("parcel_delivered"),"Oak begins a scene before handing over the Pokedex")
	w.scenes.tick(3); w.scenes.tick(.8); w.scenes.tick(.65); w.scenes.tick(.2)
	c.check(w.scenes.positions.get("quest:oak")==Vector2(5.5,2.5)*48,"Oak walks to the Pokedex desk")
	await snap("oak-desk")
	c.check(w.actors().filter(func(n):return n.graphics_id=="OBJ_EVENT_GFX_PROF_OAK").is_empty(),"Moving quest Oak never leaves a duplicate at his original tile")
	for i in 8: w.scenes.tick(4)
	c.check(w.events.done("parcel_delivered") and not w.actors().any(func(n):return n.graphics_id=="OBJ_EVENT_GFX_POKEDEX"),"Completed handoff grants the Pokedex and removes the desk devices")
	await snap("lab")
	a.menu(); await snap("menu"); a.inventory.bag(); a.back_ui(); c.check(a.modal=="ADVENTURE MENU","Bag Back returns to the Adventure menu")
	a.clear_ui(); a.collection.dex_entry(4); await snap("pokedex")
	var high=a.new_mon(4,40); var low=a.new_mon(4,5)
	c.check(a.xp_needed(high)>a.xp_needed(low)*20,"Higher levels require appropriately more experience")
	c.check(a.experience.reward(19,2,false)==16 and a.experience.reward(19,10,false)==81,"Wild XP scales with defeated level and species yield")
	var legacy={"id":4,"level":20,"xp":70}; a.experience.migrate(legacy)
	c.check(legacy.level==20 and absf(float(legacy.xp)/a.xp_needed(legacy)-.5)<.01,"Old save migration preserves level and half-filled XP bar")
	var migrated=legacy.xp; a.experience.migrate(legacy); c.check(legacy.xp==migrated,"XP migration is idempotent")
	fixture("MAP_ROUTE1"); a.position_world=w.walkable(Vector2(10,10)*48); await snap("route-trees-ledges")
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var npc={"pos":a.position_world-direction*144,"script":"qa_approach","graphics_id":"OBJ_EVENT_GFX_BOY","battle":{"name":"Tester","party":[[19,3]]}}
		w.scenes.start_trainer(npc); w.scenes.completion=Callable()
		w.scenes.tick(.7); w.scenes.tick(.1)
		c.check(w.scenes.actor.look==direction and w.scenes.actor.walking,"Approaching trainer faces his actual walking direction "+str(direction))
		w.view3d.move_actor(w.view3d.actors.player,a.position_world,direction,true)
		c.check(w.view3d.actors.player.basis.z.dot(Vector3(direction.x,0,direction.y))>.99,"3D model face matches world direction "+str(direction))
		w.scenes.reset()
	for map_id in ["MAP_PALLET_TOWN_PLAYERS_HOUSE_1F","MAP_PALLET_TOWN_PLAYERS_HOUSE_2F"]:
		fixture(map_id); a.position_world=w.walkable(Vector2(5.5,6.5)*48); await snap(map_id.to_lower())
	for spec in [["MAP_PEWTER_CITY_GYM","brock"],["MAP_CERULEAN_CITY_GYM","misty"]]:
		fixture(spec[0])
		var leader=w.quest_actors().filter(func(n):return n[2]==spec[1])[0]
		a.position_world=leader[0]+Vector2.DOWN*48; w.heading=Vector2.UP
		key(KEY_SPACE); c.check(a.in_battle and a.encounter.kind==spec[1],"Talking to quest gym leader starts battle: "+spec[1])
	fixture("MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB")
	a.position_world=Vector2(6.5,4.5)*48; w.heading=Vector2.UP
	key(KEY_SPACE); c.check(not a.dialog.is_empty(),"Oak still responds before parcel delivery")

	fixture("MAP_ROUTE22")
	a.position_world=Vector2(33.5,5.5)*48
	c.check(w.scenes.route22_rival() and w.scenes.active,"Route22 west approach triggers Blue")
	w.scenes.tick(1)
	await snap("route22-blue")
	w.scenes.finish()
	c.check(a.in_battle and a.encounter.ids==[16,7] and a.encounter.levels==[9,9] and c.opponent_identity=="blue","Route22 Blue has the matching level-9 party")
	a.in_battle=false; w.events.battle_reward("world_Route22_EarlyRival",true)
	c.check(not w.scenes.route22_rival(),"Defeated Route22 Blue never repeats")
	fixture("MAP_ROUTE22_NORTH_ENTRANCE")
	c.check(not w.events.allow_step(Vector2(7.5,2.5)*48),"Boulder guard blocks his original checkpoint")
	c.check(not w.events.allow_door("MAP_ROUTE23"),"Boulder requirement also guards the exit")
	a.data.badge=true; a.dialog=""
	c.check(w.events.allow_step(Vector2(7.5,2.5)*48) and w.events.allow_door("MAP_ROUTE23"),"Boulder Badge opens its checkpoint")
	fixture("MAP_ROUTE23")
	for gate in w.events.badge_checkpoints.MAP_ROUTE23:
		c.check(not w.events.allow_step((Vector2(gate[0],gate[1])+Vector2.ONE*.5)*48),"Missing badge blocks checkpoint "+str(gate))
	c.check(not w.events.allow_door("MAP_VICTORY_ROAD_1F") and not w.events.allow_door("MAP_INDIGO_PLATEAU_EXTERIOR"),"Cannot bypass badges through map transitions")

	a.data.badge=true; a.data.cascade=true; a.Story.state(a)["thunder"]=true
	for badge in ["rainbow","soul","marsh","volcano","earth"]: a.Finale.state(a)[badge]=true
	for gate in w.events.badge_checkpoints.MAP_ROUTE23:
		c.check(w.events.allow_step((Vector2(gate[0],gate[1])+Vector2.ONE*.5)*48),"Earned badge opens checkpoint "+str(gate))
	c.check(w.events.allow_door("MAP_VICTORY_ROAD_1F"),"Eight badges open Victory Road")
	var visual: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/world-3d.json"))
	for id in w.maps:
		var tiles=visual[id].tiles
		for i in tiles.size():
			if tiles[i]=="fence": c.check((int(w.maps[id].cells[i])&0xC00)!=0,"Fence matches source collision "+str(id)+":"+str(i))
	fixture("MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB")
	a.data.starter=0; a.data.rival=false
	w.scenes.entrance()
	c.check(not w.scenes.active and a.modal=="","Early lab visit cannot give a starter")
	c.check(not w.quest_actors().any(func(n):return n[2]=="oak") and not w.actors().any(func(n):return n.graphics_id=="OBJ_EVENT_GFX_PROF_OAK"),"Oak absent before rescue")
	w.current="MAP_PALLET_TOWN"; w.events.refresh(); a.position_world=Vector2(12.5,1.5)*48
	c.check(w.scenes.check_oak_intro(),"Oak triggers on the original Pallet exit row")
	c.check(w.scenes.active and w.scenes.sequence.size()>4,"Oak escorts the player along a real walking path")
	for step in w.scenes.sequence:
		if step.has("player_to"): c.check(not w.terrain_blocked(step.player_to),"Oak escort stays on walkable ground")
	w.scenes.finish()
	c.check(w.current=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB" and w.events.done("oak_intro") and w.scenes.active,"Escort enters lab and starts the introduction")
	w.scenes.finish()
	c.check(a.modal!="","Starter choice opens after escort")
	fixture("MAP_VIRIDIAN_CITY")
	c.check(not w.events.allow_door("MAP_ROUTE2"),"Viridian north blocked before second Blue fight")
	c.check(w.events.allow_door("MAP_ROUTE22"),"West path to Blue stays open")
	w.events.battle_reward("world_Route22_EarlyRival",true)
	c.check(w.events.allow_door("MAP_ROUTE2"),"Second Blue victory opens north")
	var town=visual.MAP_VIRIDIAN_CITY
	c.check(town.buildings.any(func(b):return b[0]==24 and b[1]==15),"Viridian school is a building")
	c.check(town.tiles[16*int(w.room().width)+25]=="foundation","School roof is not foliage")
	print("ADVENTURE FIX CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
