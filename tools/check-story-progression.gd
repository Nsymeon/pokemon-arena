extends SceneTree
var c
var a
var w
var rendered=false

func _initialize(): run.call_deferred()

func fixture(map_id="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB"):
	a.clear_ui(); w.scenes.reset(); a.dialog=""; a.in_battle=false; a.exploring=true; a.visible=true
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true; a.data.party=[a.new_mon(4,15)]; a.inventory.migrate()
	w.enabled=true; w.current=map_id; a.position_world=Vector2(6.5,8.5)*48; w.events.refresh(); w.stepping=false
	a.evolutions.clear(); c.campaign.active=false; c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selection_controls.visible=false
	c.selecting=true; c.result=""; c.paused=false

func scene_done():
	if w.scenes.active: w.scenes.finish()

func npc(script):
	w.events.npc_interact({"script":script})
	scene_done()

func caught(count):
	a.data.pokedex={}
	for id in range(1,count+1): a.collection.register({"id":id})

func snap(name):
	if not rendered: return
	c.queue_redraw(); a.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/story-"+name+".png")

func run():
	rendered="--qa-render" in OS.get_cmdline_user_args()
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame
	c.set_process(false); a=c.adventure; a.loaded=true; a.save_allowed=false; a.save_path="user://story-qa-isolated.json"; w=a.world
	c.campaign.path="user://daily-qa-isolated.json"; c.campaign.writable=false
	fixture()
	# All eight badges lock the battle entry itself, not just the dialogue.
	for kind in ["brock","misty","surge","late_erika","late_koga","late_sabrina","late_blaine","late_giovanni"]:
		fixture()
		c.check(not a.progression.gym_cleared(kind),"Unwon Gym is available: "+kind)
		if kind=="brock": a.data.badge=true
		elif kind=="misty": a.data.cascade=true
		elif kind=="surge": a.Story.state(a).thunder=true
		else: a.Finale.state(a)[a.Finale.TASKS[kind.trim_prefix("late_")].flag]=true
		var before=a.data.duplicate(true); a.begin_battle(kind,[25],[100])
		c.check(not a.in_battle and a.data==before,"Badge blocks repeat battle without rewards or data changes: "+kind)
		a.data=JSON.parse_string(JSON.stringify(a.data)); a.begin_battle(kind,[25],[100])
		c.check(not a.in_battle,"Badge remains locked after save round trip: "+kind)
	fixture(); a.Finale.state(a).champion=true
	for id in a.expansion.REMATCHES.slice(0,8):
		a.expansion.start_rematch(id); c.check(not a.in_battle and a.expansion.state().pending=="","No Adventure Gym rematch via postgame menu: "+id)
	fixture(); a.data.party.append(a.new_mon(25,15)); a.data.party[0].held_item="amuletcoin"
	a.encounter={"kind":"world_test","participants":{"0":[0],"1":[1]}}; var prize_before=a.data.money
	a.reward(true); c.check(a.data.money==prize_before+300,"Amulet Coin counts participation against earlier opponents")
	# Automatic blackout, original money formula and exact indoor healing checkpoint.
	fixture("MAP_VIRIDIAN_CITY_POKEMON_CENTER_1F")
	a.position_world=w.walkable(Vector2(7.5,6.5)*48); a.heal(); var heal_spot=a.data.heal_spot.duplicate()
	a.data.party=[a.new_mon(4,15),a.new_mon(25,20)]; a.data.money=1000
	c.check(a.progression.blackout_cost()==160,"FireRed loss uses highest level times four times badge multiplier")
	a.data.money=25; c.check(a.progression.blackout_cost()==25,"Loss is capped at current money")
	a.data.money=0; c.check(a.progression.blackout_cost()==0,"Empty wallet never becomes negative")
	a.data.money=1000; w.enter("MAP_ROUTE1",Vector2(8.5,10.5)*48); a.dialog=""
	a.begin_battle("wild",[19],[5]); c.countdown=0
	var restart=InputEventKey.new(); restart.physical_keycode=KEY_R; restart.keycode=KEY_R; restart.pressed=true
	c.player.hp-=7; var hp=c.player.hp; c._unhandled_input(restart)
	c.check(c.player.hp==hp and c.countdown==0,"R cannot restart an Adventure fight")
	c.player.hp=0; c.finish_round(); c.shots.clear(); c.result_time=10
	c.check(c.can_continue_team() and a.modal!="BLACKOUT","One faint with a living reserve does not black out")
	for fighter in c.player_states: fighter.hp=0
	c.result=""; c.finish_round(); c.result_time=10; c._process(.01)
	c.check(a.modal=="BLACKOUT" and not a.in_battle,"Whole-party defeat automatically starts blackout without keypress")
	c.check(a.data.money==840 and a.data.party.all(func(m):return m.hp==1 and m.ailment==""),"Blackout charges once and fully heals party")
	c.check(w.current==heal_spot.map and a.position_world==Vector2(heal_spot.x,heal_spot.y),"Blackout returns to exact last indoor heal spot")
	a.return_world(); c.check(a.data.money==840,"Repeated result input cannot charge money twice")
	a.blackout_scene.set_process(false); a.blackout_scene.age=2.5; a.blackout_scene.queue_redraw(); await snap("blackout")
	a.handle_input(restart); c.check(a.modal=="BLACKOUT","Blackout cannot be bypassed by restart")
	a.blackout_scene.finish(); c.check(a.modal=="","Blackout ends with restored exploration")
	a.data.x=a.position_world.x; a.data.y=a.position_world.y
	c.check(a.valid(JSON.parse_string(JSON.stringify(a.data))),"Exact heal checkpoint survives save validation")
	var invalid_spot=a.data.duplicate(true); invalid_spot.heal_spot.x=INF
	c.check(not a.valid(invalid_spot),"Invalid heal coordinates are rejected")
	# Oak counts historical caught species, including released Pokemon, not seen.
	fixture(); caught(59); a.Finale.state(a).champion=true; a.field.finish("visited:MAP_ONE_ISLAND")
	a.collection.register({"id":60},false)
	c.check(not a.progression.national_ready(),"59 caught plus a seen entry cannot unlock National Dex")
	a.collection.register({"id":60}); c.check(a.progression.national_ready(),"Champion, One Island and 60 caught unlock Oak upgrade")
	a.Finale.state(a).champion=false; c.check(not a.progression.national_ready(),"60 caught cannot bypass the League")
	a.Finale.state(a).champion=true; a.progression.national_scene(); c.check(w.scenes.active and not a.progression.national(),"National upgrade is a scene before reward")
	scene_done(); c.check(a.progression.national(),"National upgrade persists after scene")
	for script in a.progression.AIDES:
		npc(script)
		c.check(a.progression.done("aide:"+script),"Oak aide reward works: "+script)
		var bag=a.data.bag.duplicate(); npc(script); c.check(a.data.bag==bag,"Oak aide reward is one-time: "+script)
	c.check(a.field.owns("flash") and a.field.owns("itemfinder"),"Aides grant functional field tools")
	a.data.party=[a.new_mon(4,15)]; a.data.party[0].held_item="everstone"; a.grant_xp(a.xp_needed(a.data.party[0]))
	c.check(a.data.party[0].id==4 and a.evolutions.is_empty(),"Everstone prevents level evolution")
	a.data.party[0].held_item=""; a.grant_xp(a.xp_needed(a.data.party[0])); c.check(a.data.party[0].id==5,"Removing Everstone permits next level evolution")
	# Actual main-story actors and key gates.
	fixture("MAP_ROUTE24"); npc("Route24_EventScript_Rocket"); c.check(not a.in_battle,"Recruiter waits for five actual bridge trainers")
	for name in ["Cale","Ali","Timmy","Reli","Ethan"]: w.events.battle_reward("world_Route24_EventScript_"+name,true)
	npc("Route24_EventScript_Rocket"); c.check(a.in_battle and a.encounter.kind=="bridge_rocket","Actual bridge victories unlock recruiter")
	fixture("MAP_CERULEAN_CITY")
	var trigger=w.events.catalog[w.current].triggers.filter(func(t):return "RivalTrigger" in str(t.get("script","")))[0]
	a.position_world=w.events.point(trigger); c.check(a.progression.main_rival(),"Source Cerulean trigger starts Blue scene")
	scene_done(); c.check(a.in_battle and a.encounter.kind=="bridge_blue","Cerulean scene launches correct rival")
	for starter in [1,4,7]:
		fixture("MAP_SILPH_CO_7F"); a.data.starter=starter
		a.begin_battle("late_silph_blue",[],[])
		c.check(a.encounter.ids[-1]=={1:6,4:9,7:3}[starter] and a.encounter.ids[0]==18 and a.encounter.levels[0]==37,"Silph uses source Pidgeot and correct evolved rival starter: "+str(starter))
	fixture("MAP_POKEMON_TOWER_2F")
	trigger=w.events.catalog[w.current].triggers.filter(func(t):return "RivalTrigger" in str(t.get("script","")))[0]
	a.position_world=w.events.point(trigger); a.progression.main_rival(); scene_done()
	c.check(a.in_battle and a.encounter.ids.size()==5 and c.opponent_identity=="blue","Tower 2F rival scene starts the source five-Pokemon team")
	a.progression.after_battle("story_tower_blue",true); a.in_battle=false
	c.check(not a.progression.main_rival(),"Tower rival cannot repeat after victory")
	fixture("MAP_ROUTE22"); a.data.badge=true; a.data.cascade=true; a.Story.state(a).thunder=true
	for badge in a.Finale.BADGES: a.Finale.state(a)[badge]=true
	a.field.finish("trainer:Route22_EarlyRival"); a.position_world=Vector2(33.5,5.5)*48
	c.check(w.scenes.route22_rival(),"Eight badges trigger late rival on Route 22 even after early victory")
	scene_done(); c.check(a.in_battle and a.encounter.kind=="late_league_rival","Late rival needs eight badges, not phantom Victory Road trainer")
	fixture("MAP_POKEMON_TOWER_7F"); npc("PokemonTower_7F_EventScript_MrFuji")
	c.check(w.current=="MAP_POKEMON_TOWER_7F","Fuji cannot be rescued before three guards")
	for id in ["Grunt1","Grunt2","Grunt3"]: w.events.battle_reward("world_PokemonTower_7F_EventScript_"+id,true)
	npc("PokemonTower_7F_EventScript_MrFuji"); c.check(w.current=="MAP_LAVENDER_TOWN_VOLUNTEER_POKEMON_HOUSE","Rescue takes Fuji and player home")
	npc("LavenderTown_VolunteerPokemonHouse_EventScript_MrFuji"); c.check(a.Finale.has(a,"flute"),"Fuji gives Poke Flute at his house")
	fixture(); c.check(a.progression.gate("MAP_SAFFRON_CITY")!="","Tea gate blocks Saffron")
	npc("CeladonCity_Condominiums_1F_EventScript_TeaWoman"); c.check(a.progression.gate("MAP_SAFFRON_CITY")=="","Tea opens Saffron")
	a.Finale.complete(a,"silph_saved"); a.Finale.complete(a,"silph_saved")
	c.check(a.data.bag.masterball==1,"Silph President gives one Master Ball")
	a.begin_battle("wild",[150],[70]); c.countdown=0; c.player.action_lock=0; a.throw_ball(true)
	c.check(a.capture_time>0 and a.capture_success and a.data.bag.masterball==0,"Master Ball consumes once and guarantees capture")
	a.capture_time=0
	# Sevii travel, the Ruby/Sapphire quest and static legendaries.
	fixture("MAP_CINNABAR_ISLAND"); a.progression.bill_visit(); c.check(not w.scenes.active,"Bill trip waits for Volcano Badge")
	a.Finale.state(a).volcano=true; a.progression.bill_visit(); scene_done()
	c.check(a.sevii.done("tri_pass") and w.current=="MAP_ONE_ISLAND_POKEMON_CENTER_1F","Bill trip grants Tri-Pass and visits Celio")
	a.Finale.state(a).champion=true; npc("OneIsland_PokemonCenter_1F_EventScript_Celio")
	c.check(not a.sevii.done("network_quest"),"Champion alone cannot start Network quest")
	caught(60); a.progression.national_scene(); scene_done(); npc("OneIsland_PokemonCenter_1F_EventScript_Celio")
	c.check(a.sevii.done("network_quest"),"National Dex starts Network quest")
	c.check(not a.sevii.gate("MAP_MT_EMBER_RUBY_PATH_B1F"),"Ruby path waits for both guards")
	for name in ["Grunt1","Grunt2"]:
		var kind="world_MtEmber_Exterior_EventScript_"+name; w.events.battle_reward(kind,true); a.progression.after_battle(kind,true)
	c.check(a.sevii.gate("MAP_MT_EMBER_RUBY_PATH_B1F"),"Both guards open Ruby path and first password")
	npc("MtEmber_RubyPath_B5F_EventScript_Ruby"); npc("OneIsland_PokemonCenter_1F_EventScript_Celio")
	c.check(a.sevii.done("ruby_delivered"),"Ruby grants Rainbow Pass")
	c.check(not a.sevii.gate("MAP_SIX_ISLAND_DOTTED_HOLE_1F"),"Dotted Hole waits for Lorelei and Cut")
	a.sevii.result("sevii_lorelei",true); a.Story.state(a).cut=true; a.data.cascade=true
	c.check(a.sevii.gate("MAP_SIX_ISLAND_DOTTED_HOLE_1F"),"Lorelei rescue and Cut open Dotted Hole")
	npc("SixIsland_DottedHole_SapphireRoom_EventScript_Sapphire")
	c.check(a.sevii.gate("MAP_FIVE_ISLAND_ROCKET_WAREHOUSE"),"Two passwords open Warehouse")
	npc("FiveIsland_RocketWarehouse_EventScript_Gideon"); c.check(not a.in_battle,"Gideon waits for Rocket Admins")
	for name in ["Admin1","Admin2"]: w.events.battle_reward("world_FiveIsland_RocketWarehouse_EventScript_"+name,true)
	npc("FiveIsland_RocketWarehouse_EventScript_Gideon"); c.check(a.in_battle and a.encounter.kind=="sevii_sapphire","Admin victories unlock Gideon")
	a.in_battle=false; a.sevii.result("sevii_sapphire",true)
	c.check(a.progression.legendary_requirement(150)!="","Mewtwo remains locked while Sapphire is undelivered")
	npc("OneIsland_PokemonCenter_1F_EventScript_Celio")
	c.check(a.progression.legendary_requirement(150)=="","Completed Network Machine unlocks Mewtwo")
	a.data.x=a.position_world.x; a.data.y=a.position_world.y
	c.check(a.valid(JSON.parse_string(JSON.stringify(a.data))),"Full progression and key items survive save validation")
	# Classic evolution keyframes; the saved individual is untouched by presentation.
	fixture(); a.evolutions=[[4,5,false],[129,130,true]]; var party_before=a.data.party.duplicate(true); a.show_evolution()
	for t in [0.3,1.9,3.4,5.8,7.4]:
		a.evolution_scene.age=t; a.evolution_scene.set_process(false); a.evolution_scene._process(0); await snap("evolution-"+str(t))
	c.check(a.data.party==party_before,"Evolution presentation never mutates saved stats or moves")
	a.evolution_scene.advance(); c.check(a.evolutions.size()==1,"Continue advances exactly one evolution")
	a.evolution_scene.advance(); a.evolution_scene.advance(); c.check(a.modal=="" and a.evolutions.is_empty(),"Queued shiny evolution closes cleanly")
	# Automatic Oak ceremony and recorded team, including shiny state.
	fixture("MAP_POKEMON_LEAGUE_CHAMPIONS_ROOM")
	a.data.party=[a.new_mon(6,63),a.new_mon(9,61),a.new_mon(3,62),a.new_mon(94,60),a.new_mon(25,65),a.new_mon(149,63)]
	a.data.party[3].shiny=true; a.Finale.state(a).league=4; a.encounter={"kind":"late_league_4"}
	a.Finale.reward(a,true); a.progression.after_battle("late_league_4",true)
	c.check(w.scenes.active and a.progression.done("champion_pending"),"Blue victory starts automatic Oak ceremony")
	scene_done(); scene_done(); c.check(a.modal=="HALL OF FAME" and a.progression.hall_scene.party.size()==6,"Ceremony displays actual six-member winning team")
	a.progression.hall_scene.age=9; a.progression.hall_scene.set_process(false); a.progression.hall_scene._process(0); await snap("hall-of-fame")
	a.progression.hall_scene.advance(); c.check(w.current=="MAP_PALLET_TOWN_PLAYERS_HOUSE_2F" and not a.progression.done("champion_pending"),"Completed ceremony returns home without replay loop")
	c.check(a.data.hall_of_fame[3].shiny,"Hall record preserves shiny individual")
	# Daily mode: deterministic player party; fixed opponents and actual Lv.50 combat.
	fixture(); a.exploring=false; a.visible=false
	var campaign=c.campaign; campaign.day_override="2026-11-01"; campaign.daily_enabled=true; campaign.refresh_day()
	var today=campaign.data.team.duplicate(); var adventure_before=a.data.duplicate(true)
	c.check(today.size()==6 and today.all(func(id):return today.count(id)==1),"Daily team has six distinct available Pokemon")
	for stage in 13:
		var enemy=campaign.daily.opponent(c,stage)
		c.check(enemy.size()==6 and enemy.all(func(mon):return mon.level==50 and mon.moves.size()==4),"Leader has six level-50 Pokemon with four moves: "+campaign.NAMES[stage])
	c.check(campaign.valid(campaign.data,c.roster.map(func(m):return int(m.id))),"Daily save validates")
	var changed=campaign.data.duplicate(true); changed.team[0]=1
	c.check(not campaign.valid(changed,c.roster.map(func(m):return int(m.id))),"Daily save rejects species replacement")
	campaign.data.cleared=3; campaign.refresh_day(); c.check(campaign.data.team==today and campaign.data.cleared==3,"Same day retains progress and team")
	var opponent_before=campaign.daily.opponent(c,0); campaign.day_override="2026-11-02"; campaign.refresh_day()
	c.check(campaign.data.team!=today and campaign.data.cleared==0 and campaign.daily.opponent(c,0)==opponent_before,"Next day changes only player's team and resets daily progress")
	campaign.show_hub(); await snap("daily-league")
	campaign.choose(0); c.start_match()
	c.check(c.player_states.size()==6 and c.player_states.all(func(f):return f.data.level==50 and f.hp==f.data.hp),"Daily match really scales and heals all six player fighters")
	c.check(c.enemy_party.size()==6 and c.enemy_party.all(func(m):return m.level==50),"Daily match uses fixed full opponent party")
	c.enemy.hp=0; c.finish_round(); c.shots.clear(); c.result_time=c.FAINT_RESULT_TIME; campaign.record_result()
	c.check(campaign.data.cleared==0,"First of six KOs cannot award daily badge")
	for i in range(1,6):
		c.advance_team(); c.enemy.hp=0; c.finish_round(); c.shots.clear(); c.result_time=c.FAINT_RESULT_TIME; campaign.record_result()
	c.check(campaign.data.cleared==1,"Defeating all six daily opponents awards exactly one badge")
	var saved=load("res://league_campaign.gd").new(); saved.path="user://daily-check-"+str(Time.get_ticks_usec())+".json"; saved.data=campaign.data.duplicate(true)
	c.check(saved.save(),"Daily checkpoint writes to isolated save")
	var readback=load("res://league_campaign.gd").new(); readback.path=saved.path; readback.read_progress(c.roster.map(func(m):return int(m.id)))
	c.check(readback.writable and readback.data.get("day","")==saved.data.day and readback.data.team==saved.data.team and readback.data.cleared==1,"Daily date, generated team and badge survive real save/reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved.path))
	c.check(a.data==adventure_before,"Daily mode leaves Adventure save unchanged")
	print("STORY / DAILY CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
