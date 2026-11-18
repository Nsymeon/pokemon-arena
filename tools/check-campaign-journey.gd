extends SceneTree
# A single persistent campaign, not independent flag fixtures. Battles are
# resolved by the test harness; this verifies progression, not player balance.
var c
var a
var w
var checkpoints=[]
var battles=0
func _initialize():
	DirAccess.make_dir_recursive_absolute("res://captures")
	create_timer(90).timeout.connect(func(): push_error("Campaign test timed out"); quit(2))
	run.call_deferred()
func flush():
	for i in 250:
		if w.scenes.active: w.scenes.finish(); continue
		if a.npc_program.active:
			if a.npc_program.waiting_choice: a.npc_program.choose(0,a.npc_program.generation)
			else: a.advance_dialogue()
			continue
		if a.modal=="HALL OF FAME": a.progression.hall_scene.advance(); continue
		if not a.evolutions.is_empty(): a.next_evolution(); continue
		break
	a.clear_ui(); a.dialog=""
func visit(map):
	flush(); w.enter(map,Vector2(6.5,8.5)*48); flush()
func checkpoint(label):
	a.data.x=a.position_world.x; a.data.y=a.position_world.y
	var snapshot=JSON.parse_string(JSON.stringify(a.data))
	c.check(a.valid(snapshot),"Campaign checkpoint validates: "+label)
	if "--qa-snapshots" in OS.get_cmdline_user_args():
		var file=FileAccess.open("res://captures/journey-"+label.to_lower().replace(" ","-").replace(",","")+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(snapshot,"\t"))
	checkpoints.append({"name":label,"map":w.current,"badges":a.Finale.badges(a),"battles":battles})
	# Reload the same accumulated state rather than manufacturing unlock flags.
	a.data=snapshot; a.inventory.migrate(); w.events.refresh()
	print("JOURNEY: ",label," / badges ",a.Finale.badges(a))
func lab_defeat_branch():
	var saved=a.data.duplicate(true); var money=a.data.money
	w.scenes.starter_battle(); flush(); c.countdown=0; c.player.hp=0; c.shots.clear(); c.result="DEFEAT"; c.result_time=10
	a.return_world(); flush()
	c.check(a.data.rival and w.current=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB" and a.data.money==money and a.data.party[0].hp==1. and a.modal!="BLACKOUT","Losing the lab tutorial heals in place, keeps money and unlocks departure")
	a.data=saved; w.events.refresh()
func npc(script):
	flush()
	var objects=w.room().objects.filter(func(o):return str(o.get("script",""))==script)
	c.check(not objects.is_empty(),"Source NPC exists: "+script)
	if objects.is_empty(): return
	var object=objects[0]
	if not w.events.npc_interact(object):
		if not a.npc_program.start(object):
			if a.trainers.resolve("world_"+script)!="": a.begin_battle("world_"+script,[],[])
			else: c.check(false,"No runtime interaction for "+script)
	flush()
func action(id):
	flush()
	if not w.scenes.quest(id): a.interact_npc(id)
	flush()
func win():
	c.check(a.in_battle,"Story interaction starts a battle at "+w.current+" / "+a.dialog)
	if not a.in_battle: return
	var kind=str(a.encounter.kind); battles+=1; c.countdown=0; c.shots.clear()
	for i in a.encounter.ids.size():
		c.enemy_active=i; c.enemy=c.enemy_bench.states[i]; c.enemy.hp=0
		a.mark_participant_for(i); a.record_knockout(true)
	c.result="VICTORY"; c.result_time=10
	a.return_world(); flush()
	c.check(not a.in_battle,"Battle returns to field: "+kind)
func battle(kind):
	a.begin_battle(kind,[],[]); win()
func item(key):
	var matches=w.events.catalog[w.current].items.filter(func(o):return str(o.item)==key)
	c.check(matches.size()==1,"Unique source item: "+w.current+" / "+key)
	if matches.size()==1: w.events.pickup(matches[0]); flush()
func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; w=a.world; a.loaded=true; a.save_allowed=false; c.campaign.writable=false
	a.data=a.INITIAL_DATA.duplicate(true); a.inventory.migrate(); a.exploring=true; w.enabled=true; w.view3d.enabled=false
	a.data.player_name="QA"; a.data.avatar=a.avatar.config().duplicate(true)
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selection_controls.visible=false
	visit("MAP_PALLET_TOWN_PLAYERS_HOUSE_2F"); visit("MAP_PALLET_TOWN_PLAYERS_HOUSE_1F")
	c.check(a.field.done("scene:mom_intro"),"First downstairs visit completes Mom introduction")
	visit("MAP_PALLET_TOWN"); a.position_world=Vector2(10.5,1.5)*48
	c.check(w.scenes.check_oak_intro(),"North grass approach summons Oak"); flush()
	c.check(w.current=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB" and a.data.starter==0,"Oak escorts player into lab before starter")
	for id in [1,4,7]: w.scenes.inspect_starter(id); a.clear_ui()
	a.choose_starter(7); flush(); lab_defeat_branch(); w.scenes.starter_battle(); flush(); c.player.hp*=.4; win()
	c.check(a.data.party[0].hp==1.,"Winning the lab tutorial also heals the starter")
	checkpoint("starter and first rival")
	visit("MAP_VIRIDIAN_CITY")
	c.check(not w.events.allow_door("MAP_ROUTE2"),"North exit locked before parcel")
	visit("MAP_VIRIDIAN_CITY_MART"); npc("ViridianCity_Mart_EventScript_Clerk")
	visit("MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB"); npc("PalletTown_ProfessorOaksLab_EventScript_ProfOak")
	c.check(a.field.done("parcel_delivered") and a.data.balls==5,"Parcel hands both rivals the Dex and five balls")
	visit("MAP_ROUTE22"); battle("world_Route22_EarlyRival")
	visit("MAP_VIRIDIAN_CITY"); c.check(w.events.allow_door("MAP_ROUTE2"),"Early rival opens requested north gate")
	a.teachy_tv.old_man(); a.teachy_tv.received(); flush()
	visit("MAP_VIRIDIAN_FOREST")
	for name in ["Rick","Doug","Sammy"]: npc("ViridianForest_EventScript_"+name); win()
	visit("MAP_PEWTER_CITY_GYM"); action("brock"); win(); checkpoint("Boulder Badge")
	visit("MAP_MT_MOON_B2F"); npc("MtMoon_B2F_EventScript_Miguel"); win(); a.field.choose_fossil("helix"); flush()
	c.check(a.field.done("fossil:helix"),"One fossil chosen after Miguel")
	visit("MAP_CERULEAN_CITY_GYM"); action("misty"); win()
	visit("MAP_CERULEAN_CITY"); battle("bridge_blue")
	visit("MAP_ROUTE24")
	for name in ["Cale","Ali","Timmy","Reli","Ethan"]: npc("Route24_EventScript_"+name); win()
	npc("Route24_EventScript_Rocket"); win()
	visit("MAP_ROUTE25_SEA_COTTAGE"); action("story_bill"); action("story_console")
	c.check(a.Story.state(a).get("ticket",false),"Bill transporter awards ticket")
	visit("MAP_SS_ANNE_2F_CORRIDOR"); action("story_shipblue"); win()
	visit("MAP_SS_ANNE_CAPTAINS_ROOM"); action("story_captain")
	c.check(a.field.can_use("cut"),"Captain and Cascade Badge unlock Cut tool")
	visit("MAP_VERMILION_CITY_GYM"); w.events.trash(1)
	w.events.trash(int(w.events.state().trash_first)); w.events.trash(int(w.events.state().trash_second))
	a.dialog=""; action("story_surge"); win(); checkpoint("Thunder Badge and Cut")
	visit("MAP_CELADON_CITY_GYM"); action("late_task_erika"); win()
	visit("MAP_CELADON_CITY_CONDOMINIUMS_1F"); npc("CeladonCity_Condominiums_1F_EventScript_TeaWoman")
	c.check(a.progression.gate("MAP_SAFFRON_CITY")=="","Tea opens Saffron")
	visit("MAP_ROCKET_HIDEOUT_B4F")
	for name in ["Grunt1","Grunt2","Grunt3"]: npc("RocketHideout_B4F_EventScript_"+name); win()
	a.Finale.start_task(a,"hideout_boss"); win()
	c.check(a.Finale.has(a,"scope"),"Hideout Giovanni awards Silph Scope")
	visit("MAP_POKEMON_TOWER_6F"); a.field.ghost(); flush(); win()
	visit("MAP_POKEMON_TOWER_7F")
	for name in ["Grunt1","Grunt2","Grunt3"]: npc("PokemonTower_7F_EventScript_"+name); win()
	npc("PokemonTower_7F_EventScript_MrFuji"); npc("LavenderTown_VolunteerPokemonHouse_EventScript_MrFuji")
	c.check(a.Finale.has(a,"flute"),"Fuji rescue awards Poke Flute at home")
	checkpoint("Rocket Hideout and Pokemon Tower")
	visit("MAP_ROUTE12"); npc("Route12_EventScript_Snorlax"); win()
	visit("MAP_FUCHSIA_CITY_GYM"); action("late_task_koga"); win()
	visit("MAP_FUCHSIA_CITY_SAFARI_ZONE_ENTRANCE"); a.services.start_safari()
	c.check(a.services.state().safari,"Safari admission starts a paid visit")
	visit("MAP_SAFARI_ZONE_WEST"); item("GOLD_TEETH")
	visit("MAP_SAFARI_ZONE_SECRET_HOUSE"); npc("SafariZone_SecretHouse_EventScript_Attendant")
	visit("MAP_FUCHSIA_CITY_WARDENS_HOUSE"); npc("FuchsiaCity_WardensHouse_EventScript_Warden")
	a.inventory.replace_menu(0,"surf",""); a.inventory.teach(0,"surf",0,""); flush()
	c.check(a.field.can_use("surf") and a.field.can_use("strength"),"Safari rewards enable Surf and Strength with badges")
	checkpoint("Soul Badge, Surf and Strength")
	visit("MAP_SILPH_CO_5F"); item("CARD_KEY")
	visit("MAP_SILPH_CO_7F"); a.Finale.start_task(a,"silph_blue"); win(); npc("SilphCo_7F_EventScript_LaprasGuy")
	visit("MAP_SILPH_CO_11F"); a.Finale.start_task(a,"silph_boss"); win(); npc("SilphCo_11F_EventScript_President")
	c.check(a.Finale.has(a,"silph_saved") and a.data.bag.get("masterball",0)==1,"President awards one Master Ball")
	visit("MAP_SAFFRON_CITY_GYM"); action("late_task_sabrina"); win()
	checkpoint("Silph Co. and Marsh Badge")
	visit("MAP_POKEMON_MANSION_B1F"); item("SECRET_KEY")
	visit("MAP_CINNABAR_ISLAND_GYM")
	for i in range(1,7): w.events.answer(i,bool(w.events.QUIZZES[i-1][1])); flush()
	a.Finale.start_task(a,"blaine"); win()
	visit("MAP_CINNABAR_ISLAND"); flush()
	c.check(a.sevii.done("tri_pass") and w.current=="MAP_ONE_ISLAND_POKEMON_CENTER_1F","Bill trip follows Volcano Badge")
	visit("MAP_TWO_ISLAND_JOYFUL_GAME_CORNER"); npc("TwoIsland_JoyfulGameCorner_EventScript_LostellesDaddy")
	visit("MAP_THREE_ISLAND")
	for i in 4: a.sevii.bikers(); flush(); win()
	visit("MAP_THREE_ISLAND_BERRY_FOREST"); npc("ThreeIsland_BerryForest_EventScript_Lostelle"); win()
	c.check(a.sevii.done("lostelle_returned"),"Lostelle returns to her father after Hypno")
	visit("MAP_ONE_ISLAND_POKEMON_CENTER_1F"); npc("OneIsland_PokemonCenter_1F_EventScript_Bill")
	c.check(a.sevii.done("initial_trip_complete") and w.current=="MAP_CINNABAR_ISLAND","Bill ends the first Sevii trip")
	checkpoint("Lostelle and first Sevii visit")
	visit("MAP_VIRIDIAN_CITY_GYM"); action("late_task_giovanni"); win()
	visit("MAP_ROUTE22"); a.Finale.start_task(a,"league_rival"); win()
	c.check(a.Finale.badges(a)==8,"All eight badges earned through battles")
	for map in w.events.LEAGUE:
		c.check(w.events.allow_door(map),"Earned League chamber entry: "+map)
		visit(map); a.Finale.start_league(a); win()
	c.check(a.Finale.has(a,"champion") and a.data.has("hall_of_fame") and w.current=="MAP_PALLET_TOWN_PLAYERS_HOUSE_2F","Champion ceremony records actual team and returns home")
	checkpoint("Champion and Hall of Fame")
	# National Dex needs caught species. Exercise actual capture registration
	# using source encounter species/levels, deterministic successful ball rolls.
	for map in w.scenes.encounters:
		for table in w.scenes.encounters[map].values():
			for mon in table:
				if a.progression.caught_kanto()>=60: break
				if int(mon.id)>151 or a.data.pokedex.get(str(int(mon.id)),{}).get("caught",false): continue
				visit(map); a.inventory.buy("balls",a.inventory.unit_price("balls")); flush()
				a.begin_battle("wild",[int(mon.id)],[int(mon.get("min",mon.get("level",5)))]); c.countdown=0; c.player.action_lock=0; c.enemy.hp=1; c.rng.seed=1
				a.throw_ball(); a.tick_capture(4.); flush()
				c.check(not a.in_battle,"Source encounter captured for National Dex")
	visit("MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB"); npc("PalletTown_ProfessorOaksLab_EventScript_ProfOak")
	c.check(a.progression.national(),"Sixty historical catches unlock National Dex")
	visit("MAP_ONE_ISLAND_POKEMON_CENTER_1F"); npc("OneIsland_PokemonCenter_1F_EventScript_Celio")
	visit("MAP_MT_EMBER_EXTERIOR")
	for name in ["Grunt1","Grunt2"]: npc("MtEmber_Exterior_EventScript_"+name); win()
	c.check(a.sevii.gate("MAP_MT_EMBER_RUBY_PATH_B1F"),"Both Rocket guards open Ruby path")
	visit("MAP_MT_EMBER_RUBY_PATH_B5F"); npc("MtEmber_RubyPath_B5F_EventScript_Ruby")
	visit("MAP_ONE_ISLAND_POKEMON_CENTER_1F"); npc("OneIsland_PokemonCenter_1F_EventScript_Celio")
	c.check(a.sevii.done("ruby_delivered"),"Ruby delivery grants Rainbow Pass")
	visit("MAP_FOUR_ISLAND_ICEFALL_CAVE_1F"); item("HM07")
	visit("MAP_FOUR_ISLAND_ICEFALL_CAVE_BACK"); npc("FourIsland_IcefallCave_Back_EventScript_Lorelei"); win()
	c.check(a.sevii.gate("MAP_SIX_ISLAND_DOTTED_HOLE_1F"),"Lorelei rescue opens Dotted Hole")
	visit("MAP_SIX_ISLAND_DOTTED_HOLE_SAPPHIRE_ROOM"); npc("SixIsland_DottedHole_SapphireRoom_EventScript_Sapphire")
	visit("MAP_FIVE_ISLAND_ROCKET_WAREHOUSE")
	for name in ["Admin1","Admin2"]: npc("FiveIsland_RocketWarehouse_EventScript_"+name); win()
	npc("FiveIsland_RocketWarehouse_EventScript_Gideon"); win()
	visit("MAP_ONE_ISLAND_POKEMON_CENTER_1F"); npc("OneIsland_PokemonCenter_1F_EventScript_Celio")
	c.check(a.sevii.done("network") and a.progression.legendary_requirement(150)=="","Sapphire delivery unlocks Network Machine and Mewtwo")
	checkpoint("Sevii Network Machine ending")
	print("CAMPAIGN JOURNEY CHECK: ",c.test_failures," / ",battles," battles / ",checkpoints.size()," checkpoints")
	quit(0 if c.test_failures.is_empty() else 1)
