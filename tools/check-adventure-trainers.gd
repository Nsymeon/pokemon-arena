extends SceneTree
# Real spawned source parties, starter/story branches, finite bag and held gear.
var c
var a
var checked_actors=0

func _initialize(): run.call_deferred()

func fixture():
	a.clear_ui(); a.world.scenes.reset(); a.dialog=""
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true
	a.data.party=[a.new_mon(6,70),a.new_mon(9,70)]; a.inventory.migrate()
	a.world.enabled=true; a.world.current="MAP_ROUTE1"; a.world.view3d.enabled=false
	a.in_battle=false; a.exploring=true; c.campaign.active=false
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.paused=false
	c.selecting=true; c.result=""

func start(kind):
	a.in_battle=false; a.exploring=true
	a.begin_battle(kind,[19],[1])
	c.countdown=0
	c.check(a.in_battle,"Source encounter starts: "+kind)

func check_party(id):
	var expected=a.trainers.book.trainers[id]
	c.check(a.encounter.get("trainer_id","")==id,"Correct source identity: "+id)
	c.check(c.enemy_party.size()==expected.party.size() and c.enemy_bench.states.size()==expected.party.size(),"Exact live party size: "+id)
	c.check(a.encounter.trainer_items==expected.items,"Original trainer bag: "+id)
	for i in mini(c.enemy_bench.states.size(),expected.party.size()):
		var f=c.enemy_bench.states[i]; var mon=expected.party[i]
		c.check(int(f.data.id)==int(mon.id) and int(f.data.level)==int(mon.level),"Species/level in source slot: "+id+" / "+str(i))
		c.check(f.data.moves.map(func(m):return m.id)==mon.moves,"Exact ordered custom/default moves: "+id+" / "+str(i))
		c.check(f.data.get("held_item","")==mon.held_item,"Source held item: "+id+" / "+str(i))

func snap(name):
	if "--qa-render" not in OS.get_cmdline_user_args(): return
	c.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/trainer-"+name+".png")

func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; c.campaign.writable=false
	fixture(); var source_before=a.trainers.book.duplicate(true); var presets=c.league.trainers.duplicate(true)
	var daily_before=[]
	for stage in 13: daily_before.append(c.campaign.daily.opponent(c,stage).duplicate(true))
	for id in a.trainers.book.trainers:
		var team=a.trainers.book.trainers[id]
		c.check(team.party.size()>0 and team.party.size()<=6,"Source build has legal party size: "+id)
		for mon in team.party:
			var definitions=a.trainers.definitions(mon.moves)
			c.check(definitions.size()>0 and definitions.size()<=4 and definitions.all(func(m):return m.has("kind") and m.has("damage") and m.has("cost")),"Complete source move definitions: "+id)
		for item in team.items: c.check(item in ["superpotion","hyperpotion","fullheal","fullrestore"],"Supported source trainer item: "+id)
	for map_id in a.world.maps:
		for object in a.world.maps[map_id].objects:
			if not object.has("battle"): continue
			var kind="world_"+str(object.script); var id=a.trainers.resolve(kind)
			c.check(id!="" and a.trainers.book.trainers.has(id),"Mapped source actor: "+str(object.script))
			if id=="": continue
			start(kind); check_party(id); checked_actors+=1
	print("TRAINER ACTOR COVERAGE: ",checked_actors)
	c.check(checked_actors==443,"Every imported trainer actor reaches its source build")
	# All seven rival chapters, all three starters, including direct actor aliases.
	for starter in [1,4,7]:
		fixture(); a.data.starter=starter
		var suffix={1:"CHARMANDER",4:"SQUIRTLE",7:"BULBASAUR"}[starter]
		for kind in a.trainers.RIVALS:
			start(kind); check_party("TRAINER_RIVAL_"+a.trainers.RIVALS[kind]+"_"+suffix)
			c.check(c.opponent_identity=="blue" and c.opponent_name()=="Blue","Rival uses Blue name/presentation instead of source placeholder name")
		for rematch in [false,true]:
			if rematch: a.Finale.state(a).champion=true; a.sevii.finish("network")
			for stage in 5:
				var id="TRAINER_ELITE_FOUR_"+["LORELEI","BRUNO","AGATHA","LANCE"][stage]+("_2" if rematch else "") if stage<4 else "TRAINER_CHAMPION_"+("REMATCH_" if rematch else "FIRST_")+suffix
				start("late_league_"+str(stage)); check_party(id)
	fixture(); a.Finale.state(a).champion=true
	c.check(a.trainers.league_id(0)=="TRAINER_ELITE_FOUR_LORELEI","Champion alone does not unlock rematch teams")
	a.Finale.state(a).champion=false; a.sevii.finish("network")
	c.check(a.trainers.league_id(0)=="TRAINER_ELITE_FOUR_LORELEI","Network flag alone does not unlock rematch teams")
	fixture()
	for kind in a.trainers.STORY:
		start(kind); check_party("TRAINER_"+a.trainers.STORY[kind])
	# Actual legacy/story entry points must not overwrite the source build afterward.
	fixture(); a.Finale.state(a).lift_key=true; a.Finale.start_task(a,"hideout_boss")
	check_party("TRAINER_BOSS_GIOVANNI")
	fixture(); a.Finale.state(a).silph_blue=true; a.Finale.start_task(a,"silph_boss")
	check_party("TRAINER_BOSS_GIOVANNI_2")
	c.check(a.encounter.ids==[33,115,111,31],"Silph Giovanni uses source Kangaskhan/Rhyhorn order")
	fixture(); a.Story.state(a).thunder=true; a.Finale.start_task(a,"dojo")
	check_party("TRAINER_BLACK_BELT_KOICHI")
	# Independent spot checks for default moves and formerly missing custom Dive.
	fixture(); a.data.rival=false; start("rival")
	c.check(c.enemy.data.id==7 and c.enemy.data.level==5 and c.enemy.data.moves.map(func(m):return m.id)==["tackle","tailwhip"],"Oak rival Squirtle has its two FireRed starting moves")
	start("late_silph_boss")
	c.check(c.enemy.data.moves.map(func(m):return m.id)==["poisonsting","hornattack","helpinghand","furyattack"],"Nidorino source default moves are generated at level 37")
	start("late_league_0"); c.enemy_bench.activate(c,1); c.countdown=0
	c.check(c.enemy.data.moves.map(func(m):return m.id)==["spikes","protect","hail","dive"],"Lorelei Cloyster includes the exact custom Dive slot")
	c.check(c.use_move(c.enemy,c.player,3,Vector2.LEFT,false),"Source Dive can actually be cast")
	# Trainers approach and begin their existing single battle without extra rewards.
	fixture(); a.world.current="MAP_VIRIDIAN_FOREST"
	var actor=a.world.room().objects.filter(func(o):return o.get("script","")=="ViridianForest_EventScript_Rick")[0].duplicate(true)
	actor.pos=a.world.events.point(actor); a.position_world=actor.pos+Vector2.DOWN*96
	a.world.scenes.start_trainer(actor); a.world.scenes.finish()
	c.check(a.encounter.kind=="world_ViridianForest_EventScript_Rick","Trainer approach launches source battle with original completion key")
	check_party("TRAINER_BUG_CATCHER_RICK")
	a.world.events.battle_reward(a.encounter.kind,true)
	c.check(a.field.done("trainer:ViridianForest_EventScript_Rick"),"Victory retains the existing one-time trainer flag")
	# Full Restore uses a finite shared trainer inventory, unlike held berries.
	fixture(); start("late_league_0"); c.enemy.hp=c.enemy.data.hp*.2; c.enemy.ailment="toxic"; c.enemy.toxic_tick=5; c.enemy.volatile.confusion=2
	var bag=a.data.bag.duplicate(true); c.ai_timer=0; c.enemy_bench.cooldown=20; c.shots.clear()
	c.update_ai(.01)
	c.check(c.enemy.hp==c.enemy.data.hp and c.enemy.ailment=="" and not c.enemy.volatile.has("confusion") and c.enemy.toxic_tick==0,"Actual League AI uses Full Restore to heal and cure")
	c.check(a.encounter.trainer_items==["","fullrestore"] and c.enemy.action_lock==1 and c.enemy.movement_lock==1,"Full Restore spends exactly one item and one action")
	c.check(a.data.bag==bag and c.shots.is_empty(),"CPU never spends player items or attacks while using its item")
	await snap("lorelei-full-restore")
	c.Conditions.init(c.enemy); c.enemy.hp=1
	c.check(not a.trainer_items.try_item(),"Second Full Restore is reserved while five allies are alive")
	for i in range(2,c.enemy_bench.states.size()): c.enemy_bench.states[i].hp=0
	c.check(a.trainer_items.try_item() and a.encounter.trainer_items==["",""],"Second Full Restore becomes available with two partners")
	c.enemy_bench.activate(c,1); c.countdown=0; c.enemy.hp=1
	c.check(not a.trainer_items.try_item(),"Switching never replenishes trainer bag")
	# Source rematch berries are typed cures, not universal Lum Berries.
	for entry in [["cheriberry","paralysis"],["chestoberry","sleep"],["persimberry","confusion"]]:
		fixture(); start("late_league_0"); var f=c.enemy
		f.data.held_item=entry[0]; f.ailment="burn"; c.gear.tick(f,c.player,.1)
		c.check(f.data.held_item==entry[0] and f.ailment=="burn","Typed berry ignores other status: "+entry[0])
		if entry[1]=="confusion": f.volatile.confusion=2
		else: f.ailment=entry[1]; f.ailment_time=3
		c.player["copied_ability"]="Unnerve"; c.gear.tick(f,c.player,.1)
		c.check(f.data.held_item==entry[0],"Unnerve blocks source berry: "+entry[0])
		c.player.erase("copied_ability"); c.gear.tick(f,c.player,.1)
		c.check(f.data.held_item=="" and (not f.volatile.has("confusion") if entry[1]=="confusion" else f.ailment==""),"Source berry cures once: "+entry[0])
	fixture(); start("late_dojo")
	var move={"id":"test","type":"Fighting","category":"Physical"}
	c.enemy.data.held_item=""; var base=c.damage_amount(c.enemy,c.player,40,move)
	c.enemy.data.held_item="blackbelt"; var enhanced=c.damage_amount(c.enemy,c.player,40,move)
	c.check(absf(enhanced-base*1.1)<.11,"Source Black Belt boosts Fighting damage by ten percent")
	move.type="Normal"; enhanced=c.damage_amount(c.enemy,c.player,40,move); c.enemy.data.held_item=""
	c.check(is_equal_approx(c.damage_amount(c.enemy,c.player,40,move),enhanced),"Black Belt does not boost other move types")
	# Other modes and wild encounters keep their own teams/items/rules.
	fixture(); start("wild")
	c.check(c.enemy.data.id==19 and c.enemy.data.level==1 and not a.encounter.has("trainer_items"),"Wild encounters cannot inherit a trainer team or inventory")
	c.check(not a.trainer_items.try_item(),"Wild Pokemon have no trainer item action")
	for kind in ["post_tower","post_rematch:lorelei","post_elite:0"]:
		start(kind); c.check(not a.encounter.has("trainer_id"),"Custom Champion Challenge remains separate: "+kind)
	a.in_battle=false
	c.check(c.league.trainers==presets,"Free Battle presets remain unchanged")
	for stage in 13: c.check(c.campaign.daily.opponent(c,stage)==daily_before[stage],"Daily fixed teams unchanged: "+str(stage))
	c.check(a.trainers.book==source_before,"Live battles and item consumption never mutate imported source data")
	# Direct original Gym scripts must not bypass the existing badge gate.
	fixture(); a.data.badge=true
	var brock_script=""
	for script in a.trainers.book.scripts:
		if a.trainers.book.scripts[script]=="TRAINER_LEADER_BROCK": brock_script=script; break
	a.begin_battle("world_"+brock_script,[74,95],[12,14])
	c.check(brock_script!="" and not a.in_battle,"Raw source Gym actor cannot bypass an already-earned badge")
	print("ADVENTURE TRAINER CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
