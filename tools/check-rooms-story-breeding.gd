extends SceneTree
var c
var a
var w
var render=false
func _initialize(): run.call_deferred()
func check(value,label): c.check(value,label)
func fixture(map_id="MAP_PALLET_TOWN"):
	a.clear_ui(); w.scenes.reset(); a.in_battle=false; a.exploring=true; a.visible=true; a.dialog=""
	a.data=a.INITIAL_DATA.duplicate(true); a.inventory.migrate(); a.data.avatar=a.avatar.DEFAULT.duplicate(true)
	w.enabled=true; w.current=map_id; w.events.refresh(); w.stepping=false; w.warp_latch=""
	a.position_world=w.walkable(Vector2(6.5,6.5)*48); a.data.x=a.position_world.x; a.data.y=a.position_world.y
	c.frontend.layer.visible=false; c.selection_controls.visible=false; c.campaign.layer.visible=false; c.campaign.active=false; c.selecting=true
func snap(name):
	if not render: return
	a.queue_redraw()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/update54-"+name+".png")
func run():
	render="--qa-render" in OS.get_cmdline_user_args(); root.size=Vector2i(1280,960)
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; w=a.world; a.loaded=true; a.save_allowed=false; c.campaign.writable=false; w.view3d.enabled=render
	fixture(); w.activate()
	check(w.current=="MAP_PALLET_TOWN_PLAYERS_HOUSE_2F","New adventure begins in the player's bedroom")
	a.save_path="res://captures/update54-test-save.json"; a.save_allowed=true
	a.avatar.show_creator(a); a.avatar.name_input.text="NIKOS"; a.avatar.confirm(); a.save_allowed=false
	check(a.data.player_name=="NIKOS" and w.scenes.active,"Name and avatar lead to bedroom opening scene")
	w.scenes.reset(); a.clear_ui(); w.current="MAP_PALLET_TOWN_PLAYERS_HOUSE_1F"; w.events.refresh(); w.scenes.entrance()
	check(w.scenes.active and "MOM:" in str(w.scenes.sequence[0].text),"Mom's first-floor introduction starts automatically")
	w.scenes.finish(); w.scenes.entrance(); check(not w.scenes.active,"Mom opening is one-shot")
	fixture(); a.position_world=Vector2(12.5,.5)*48
	check(w.scenes.check_oak_intro(),"Oak rescues player at the north exit")
	w.scenes.finish(); check(w.current=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB","Oak escort ends in the laboratory")
	w.scenes.finish()
	var balls=w.actors().filter(func(o):return w.scenes.starter_id(o)>0)
	check(balls.size()==3 and a.modal=="","All three starter balls are individually inspectable")
	await snap("oak-lab")
	for ball in balls:
		a.position_world=ball.pos+Vector2.DOWN*48; w.heading=Vector2.UP; w.stepping=false
		check(w.interact() and a.modal.contains(a.mon_name(w.scenes.starter_id(ball)).to_upper()),"Interact with the starter ball on its table")
		a.clear_ui(); a.dialog=""
	a.choose_starter(4); check(not a.in_battle and a.data.starter==4,"Choosing starter does not start a premature fight")
	w.scenes.finish(); a.dialog=""
	check(w.actors().filter(func(o):return w.scenes.starter_id(o)>0).size()==1,"Chosen and rival starter balls leave the table")
	var exits=w.room().warps.filter(func(d):return d.dest_map=="MAP_PALLET_TOWN")
	for door in exits:
		a.position_world=w.events.point(door); w.warp_latch=""
		if not w.center_door(door): check(not w.try_warp(),"Side exit tile cannot trigger a warp")
	var center=exits.filter(func(d):return w.center_door(d))[0]
	a.position_world=w.events.point(center); w.warp_latch=""; w.try_warp()
	check(w.scenes.active and "Wait!" in w.scenes.sequence[0].text,"Blue interrupts attempted lab exit")
	w.scenes.finish(); check(a.in_battle and c.enemy.data.id==7,"First rival battle uses the counter starter")
	a.in_battle=false; a.exploring=true; a.visible=true; c.selection_controls.visible=false; c.selecting=true; a.data.rival=true; w.scenes.reset()
	w.events.finish("parcel_received"); w.scenes.pokedex_delivery(); w.scenes.tick(.1)
	check(w.scenes.positions.has("scene_blue") and w.scenes.sequence.any(func(s):return "each received" in str(s.get("text",""))),"Blue attends the Pokedex handoff")
	await snap("pokedex-handoff"); w.scenes.finish(); check(w.events.done("parcel_delivered"),"Pokedex scene finishes its saved quest flag")
	fixture("MAP_ROUTE1"); var sign=w.room().signs.filter(func(s):return str(s.get("script","")).ends_with("RouteSign"))[0]
	a.position_world=w.events.point(sign)+Vector2.DOWN*48; w.heading=Vector2.UP
	check(w.interact() and a.dialog!="","Ordinary route sign responds to interaction")
	a.clear_ui(); a.dialog=""; var money=int(a.data.bag.get("potion",0))
	a.npc_scripts.npc({"script":"Route1_EventScript_MartClerk"}); a.npc_scripts.npc({"script":"Route1_EventScript_MartClerk"})
	check(int(a.data.bag.get("potion",0))==money+1,"Route 1 clerk gives one Potion, with no duplicate reward")
	a.npc_scripts.npc({"script":"SaffronCity_MrPsychicsHouse_EventScript_MrPsychic"}); a.npc_scripts.npc({"script":"SaffronCity_MrPsychicsHouse_EventScript_MrPsychic"})
	check(int(a.data.tms.get("TM29",0))==1,"Mr Psychic gives TM29 exactly once")
	fixture("MAP_FOUR_ISLAND"); a.data.starter=4; a.data.money=20000
	var mom=a.new_mon(4,20); mom.gender="F"; mom.ivs=c.ivs.uniform(31)
	var dad=a.new_mon(4,20); dad.gender="M"; dad.ivs=c.ivs.uniform(30); dad.moves=["scratch","dragonclaw","dragondance","flamethrower"]
	check(a.breeding.compatibility([mom,dad])==50,"Same-species parents of same OT: 50% compatibility")
	dad.ot="npc:other"; check(a.breeding.compatibility([mom,dad])==70,"Same species from different OTs: 70% compatibility")
	var ditto=a.new_mon(132,20)
	check(a.breeding.compatibility([ditto,ditto])==0 and a.breeding.compatibility([mom,a.new_mon(144,50)])==0,"Ditto pairs and Undiscovered parents cannot breed")
	check(a.breeding.compatibility([mom,ditto])==20,"Same OT with Ditto: 20% compatibility")
	var egg=a.breeding.offspring([mom,dad])
	check(egg.id==4 and egg.level==5 and egg.hp==0 and egg.is_egg,"FRLG Egg species, level and non-battling state")
	check(egg.moves.has("dragondance") and egg.moves.has("dragonclaw"),"Egg inherits the father's egg move and legal TM")
	check(egg.ivs.values().filter(func(value):return value in [30,31]).size()>=3,"Egg inherits at least three parental IVs")
	a.data.party=[a.new_mon(7,20),mom,dad]; a.breeding.deposit(2); a.breeding.deposit(1)
	check(a.breeding.state().parents.size()==2 and a.data.party.size()==1,"Four Island stores two exact parent identities")
	a.breeding.state().pending=egg; a.breeding.take_egg(); a.clear_ui(); a.dialog=""
	check(a.data.party.size()==2 and a.breeding.state().pending.is_empty(),"Collecting an egg consumes the pending egg once")
	a.data.pokedex.erase("4"); a.collection.register(a.data.party[1])
	check(not a.data.pokedex.get("4",{}).get("caught",false) and a.data.party[1].is_egg,"An Egg alone does not reveal its species in the Pokedex")
	a.heal(); check(a.data.party[1].hp==0,"Pokemon Center cannot make an Egg battle-ready")
	a.data.bag.revive=1; check(not a.inventory.use_item("revive",1),"Revive cannot target an Egg")
	a.data.x=a.position_world.x; a.data.y=a.position_world.y
	check(a.valid(JSON.parse_string(JSON.stringify(a.data))),"Parents and Egg survive validated save round-trip")
	a.data.party[1].egg_steps=1; a.clear_ui(); a.dialog=""; a.breeding.step(); a.breeding.tick()
	await create_timer(1.8).timeout
	check(not a.data.party[1].is_egg and a.data.party[1].hp==1,"Walking hatches an Egg into a healthy Pokemon")
	check(a.data.pokedex.get("4",{}).get("caught",false),"Hatching registers the revealed species in the Pokedex")
	await snap("egg-hatched"); a.breeding.hatching=false; a.clear_ui()
	fixture("MAP_FIVE_ISLAND_WATER_LABYRINTH"); a.data.starter=7; a.data.party=[a.new_mon(7,20)]; a.data.party[0].friendship=249
	a.npc_scripts.togepi_egg(); check(a.data.party.size()==1,"Water Labyrinth Egg requires high friendship")
	a.data.party[0].friendship=250; a.npc_scripts.togepi_egg(); a.npc_scripts.togepi_egg()
	check(a.data.party.size()==2 and a.data.party[1].is_egg and a.data.party[1].id==175,"Gentleman's Togepi Egg is awarded only once")
	check(a.valid(JSON.parse_string(JSON.stringify(a.data))),"Gift Egg survives validated save round-trip")
	for id in [201,351,386]:
		for form in c.forms.count(id):
			for shiny in [false,true]: check(not c.art.entry_for({"id":id,"form":form,"shiny":shiny}).is_empty(),"Form art "+str(id)+":"+str(form)+":"+str(shiny))
	var deoxys=a.battle_mon(386,50,{"id":386,"form":1,"ivs":c.ivs.uniform(0)})
	check(deoxys.form==1 and deoxys.base_stats.atk>deoxys.base_stats.def*5,"FireRed Deoxys uses Attack Form stats")
	var castform=c.player.duplicate(true); castform.data=a.battle_mon(351,30,{"id":351,"ability":"Forecast"}); castform.hp=castform.data.hp
	for weather in ["sun","rain","hail",""]:
		c.weather.kind=weather; c.weather.suppressed=false; c.abilities.tick(castform,.01)
		check(castform.data.form=={"sun":1,"rain":2,"hail":3}.get(weather,0),"Castform visual follows "+weather)
	c.weather.kind="sun"; c.weather.suppressed=true; c.abilities.tick(castform,.01)
	check(castform.data.form==0 and castform.forecast_types==["Normal"],"Suppressed weather restores Normal Castform")
	c.weather.kind=""; c.weather.suppressed=false
	if render:
		for spec in [["MAP_PALLET_TOWN_PLAYERS_HOUSE_2F",Vector2(8,5)],["MAP_PALLET_TOWN_PLAYERS_HOUSE_1F",Vector2(5,6)],["MAP_PALLET_TOWN_RIVALS_HOUSE",Vector2(6,6)],["MAP_VIRIDIAN_CITY_MART",Vector2(5,5)],["MAP_VIRIDIAN_CITY_POKEMON_CENTER_1F",Vector2(7,6)],["MAP_ROUTE2",Vector2(6,12)]]:
			fixture(spec[0]); a.data.starter=4; a.data.rival=true; a.data.party=[a.new_mon(4,5)]; a.position_world=w.walkable((spec[1]+Vector2.ONE*.5)*48)
			await snap(spec[0])
			if "HOUSE_" in spec[0] or "POKEMON_CENTER" in spec[0]: check(int(w.view3d.terrain.get_meta("stair_count",0))==1,"One coherent stair flight in "+spec[0])
		fixture("MAP_ROUTE1"); a.data.starter=4; a.data.rival=true; a.data.party=[a.new_mon(4,5)]
		for i in 180: await process_frame
		check(w.view3d.map_cache.has("MAP_VIRIDIAN_CITY") and w.view3d.map_cache["MAP_VIRIDIAN_CITY"].get_meta("ready",false),"Neighbor finishes incremental preloading")
		print("STREAMING MAX CHUNK US ",w.view3d.max_stream_slice_us)
	print("ROOMS / STORY / BREEDING CHECK: ",c.test_failures); quit(0 if c.test_failures.is_empty() else 1)
