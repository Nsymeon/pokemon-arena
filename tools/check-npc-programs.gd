extends SceneTree
var c
var a
var p

func _initialize(): run.call_deferred()

func fixture():
	a.npc_program.cancel(); a.clear_ui(); a.world.scenes.reset(); a.dialog=""
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true
	a.data.party=[a.new_mon(4,20)]; a.inventory.migrate()
	a.data.bag.potion=5 # Explicit gift/rollback fixture, independent of new-game resources.
	a.world.enabled=true; a.world.current="MAP_ROUTE1"; a.world.view3d.enabled=false
	a.in_battle=false; a.exploring=true; c.campaign.active=false
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selection_controls.visible=false
	c.selecting=true; c.result=""; c.paused=false

func start(script):
	c.check(p.start({"script":script}),"Source NPC supported: "+script)

func finish(answers=[]):
	var count=0
	while p.active and count<500:
		if p.waiting_choice: p.choose(answers.pop_front() if not answers.is_empty() else 127,p.generation)
		else: a.advance_dialogue()
		count+=1
	c.check(not p.active and not p.aborted,"Conversation terminates safely: "+p.label)

func snap(name):
	if "--qa-render" not in OS.get_cmdline_user_args(): return
	a.visible=true; c.queue_redraw(); a.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/npc-"+name+".png")

func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; c.campaign.writable=false; p=a.npc_program
	fixture()
	var potion=int(a.data.bag.potion)
	start("Route1_EventScript_MartClerk")
	c.check(int(a.data.bag.potion)==potion,"Opening dialogue does not grant ahead of script")
	finish(); c.check(int(a.data.bag.potion)==potion+1,"Route 1 sample grants once")
	start("Route1_EventScript_MartClerk"); finish(); c.check(int(a.data.bag.potion)==potion+1,"Repeat conversation follows already-given branch")
	fixture(); a.data.bag.potion=999; start("Route1_EventScript_MartClerk"); finish()
	c.check(not a.field.done("source:FLAG_GOT_POTION_ON_ROUTE_1"),"Full bag preserves sample availability")
	a.data.bag.potion=998; start("Route1_EventScript_MartClerk"); finish(); c.check(a.data.bag.potion==999,"Sample can be retried after making room")
	fixture(); start("VermilionCity_PokemonFanClub_EventScript_Chairman")
	c.check(p.waiting_choice and p.choices==["YES","NO"],"Chairman asks before telling story")
	var stale=p.generation; p.choose(0,stale); finish(); c.check(not a.Finale.has(a,"bicycle"),"Declining chairman gives no voucher")
	start("VermilionCity_PokemonFanClub_EventScript_Chairman"); p.choose(1,stale)
	c.check(p.waiting_choice,"Stale button cannot answer a new conversation")
	await snap("chairman-choice")
	finish([1]); c.check(a.Finale.has(a,"bicycle"),"Accepting chairman grants voucher without a badge requirement")
	start("CeruleanCity_BikeShop_EventScript_Clerk"); finish()
	c.check(a.field.done("field:bicycle") and not a.Finale.has(a,"bicycle"),"Bike exchange consumes voucher and unlocks real field bicycle")
	start("CeruleanCity_BikeShop_EventScript_Clerk"); finish(); c.check(not p.waiting_choice,"Bike clerk recognizes completed exchange")
	fixture(); start("VermilionCity_House1_EventScript_FishingGuru"); finish([0]); c.check(not a.field.owns("old_rod"),"No fishing rod without accepting")
	start("VermilionCity_House1_EventScript_FishingGuru"); finish([1]); c.check(a.field.owns("old_rod"),"Accepting unlocks usable old rod")
	fixture(); start("CeladonCity_DepartmentStore_Roof_EventScript_ThirstyGirl"); finish()
	c.check(a.data.tms.is_empty(),"Thirsty girl checks for drinks first")
	for pair in [["freshwater","TM16"],["sodapop","TM20"],["lemonade","TM33"]]:
		a.data.bag[pair[0]]=2; start("CeladonCity_DepartmentStore_Roof_EventScript_ThirstyGirl"); finish([1,0])
		c.check(int(a.data.tms.get(pair[1],0))==1 and int(a.data.bag[pair[0]])==1,"Correct one-drink exchange: "+pair[0])
		start("CeladonCity_DepartmentStore_Roof_EventScript_ThirstyGirl"); finish([1,0])
		c.check(int(a.data.tms.get(pair[1],0))==1 and int(a.data.bag[pair[0]])==1,"Repeated reward does not consume another drink")
		a.data.bag[pair[0]]=0
	fixture(); a.data.bag.freshwater=1; a.data.tms.TM16=999
	start("CeladonCity_DepartmentStore_Roof_EventScript_ThirstyGirl"); finish([1,0])
	c.check(a.data.bag.freshwater==1 and not a.field.done("source:FLAG_GOT_TM16_FROM_THIRSTY_GIRL"),"Full reward pocket rolls back drink consumption and flags")
	a.data.tms.TM16=998; start("CeladonCity_DepartmentStore_Roof_EventScript_ThirstyGirl"); finish([1,0])
	c.check(a.data.bag.freshwater==0 and a.data.tms.TM16==999,"Drink trade succeeds when space becomes available")
	fixture(); start("Route1_EventScript_MartClerk"); a.advance_dialogue(); p.cancel()
	c.check(a.data.bag.potion==5 and not a.field.done("source:FLAG_GOT_POTION_ON_ROUTE_1"),"Interrupted conversation cannot leave a partial gift")
	# Source save survives JSON load; old generic-gift markers also migrate.
	fixture(); a.field.finish("npc_gift:SaffronCity_MrPsychicsHouse_EventScript_MrPsychic")
	start("SaffronCity_MrPsychicsHouse_EventScript_MrPsychic"); finish()
	c.check(int(a.data.tms.get("TM29",0))==0,"Old save gift marker prevents duplicate reward")
	for id in range(1,51): a.collection.register({"id":id})
	for script in a.progression.AIDES:
		start(script); finish([0]); c.check(not a.progression.done("aide:"+script),"Aide allows declining Pokedex check")
		start(script); finish([1]); c.check(a.progression.done("aide:"+script),"Aide count/flag bridge: "+script)
		var bag=a.data.bag.duplicate(); start(script); finish(); c.check(a.data.bag==bag,"Aide cannot give twice")
	c.check(a.valid(JSON.parse_string(JSON.stringify(a.data))),"Source NPC gifts retain valid save schema")
	fixture(); start("Route2_EastBuilding_EventScript_Aide"); finish([1])
	c.check(not a.field.owns("flash"),"Seen or insufficient caught Pokemon do not pass aide check")
	fixture(); start("ViridianCity_School_EventScript_Blackboard"); finish([0,1,127])
	c.check(p.trace.any(func(t):return "sleep" in t.to_lower()) and p.trace.any(func(t):return "poison" in t.to_lower()),"Blackboard topics follow chosen branches and can be exited")
	fixture(); start("ViridianCity_School_EventScript_Notebook"); finish([0]); var short_count=p.trace.size()
	start("ViridianCity_School_EventScript_Notebook"); finish([1,1,1]); c.check(p.trace.size()>short_count,"Notebook respects each turn-page answer")
	fixture(); start("CeruleanCity_House1_EventScript_BadgeGuy"); finish([0,6,8])
	c.check(p.trace.any(func(t):return "WATERFALL" in t),"Badge guide supports selected topics and Exit")
	fixture(); start("SilphCo_3F_EventScript_WorkerM"); finish(); var before_rescue=p.trace.duplicate()
	a.Finale.state(a).silph_boss=true; start("SilphCo_3F_EventScript_WorkerM"); finish()
	c.check(p.trace!=before_rescue,"Silph employee recognizes completed Rocket story")
	fixture(); start("ViridianCity_EventScript_OldMan"); finish(); var before_badges=p.trace.duplicate()
	a.data.badge=true; a.data.cascade=true; a.Story.state(a).thunder=true
	for badge in ["rainbow","soul","marsh","volcano"]: a.Finale.state(a)[badge]=true
	start("ViridianCity_EventScript_OldMan"); finish(); c.check(p.trace!=before_badges,"Viridian dialogue recognizes seven badges")
	fixture(); a.data.money=1000; start("CeladonCity_DepartmentStore_Roof_EventScript_VendingMachine"); finish([0,1,2,3])
	c.check(a.data.money==150 and a.data.bag.freshwater==1 and a.data.bag.sodapop==1 and a.data.bag.lemonade==1,"Vending machine prices and Exit match source choices")
	a.data.party[0].hp=0.2; c.check(a.inventory.use_item("freshwater",0) and is_equal_approx(a.data.party[0].hp,0.7),"Bought drinks can be used as healing items")
	fixture(); a.data.money=1000; a.data.bag.lemonade=999
	start("CeladonCity_DepartmentStore_Roof_EventScript_VendingMachine"); finish([0,2])
	c.check(a.data.money==800 and a.data.bag.freshwater==1 and a.data.bag.lemonade==999,"A later full pocket preserves earlier successful purchase")
	fixture(); a.data.money=0; start("CeladonCity_DepartmentStore_Roof_EventScript_VendingMachine"); finish([0])
	c.check(a.data.money==0 and int(a.data.bag.get("freshwater",0))==0,"No purchase without the required money")
	fixture(); a.world.current="MAP_CELADON_CITY_DEPARTMENT_STORE_ROOF"; a.data.bag.freshwater=1; a.data.bag.sodapop=1; a.data.bag.lemonade=1
	var girl=a.world.actors().filter(func(o):return "ThirstyGirl" in str(o.get("script","")))[0]
	a.position_world=girl.pos+Vector2.DOWN*48; a.world.heading=Vector2.UP; a.world.stepping=false
	c.check(a.world.interact() and p.waiting_choice,"Real map actor reaches source choices")
	p.choose(1,p.generation)
	while p.active and not p.waiting_choice: a.advance_dialogue()
	c.check(p.choices.size()==4,"All three drink choices plus Exit are rendered")
	await snap("drink-choices"); finish([127]); c.check(a.data.bag.freshwater==1 and a.data.tms.is_empty(),"Cancelling actual drink menu spends nothing")
	fixture(); a.world.current="MAP_CELADON_CITY_GAME_CORNER"
	c.check(not a.services.npc({"script":"CeladonCity_GameCorner_EventScript_InfoClerk"}),"Game Corner information clerk is not a shop")
	a.world.current="MAP_FUCHSIA_CITY_SAFARI_ZONE_ENTRANCE"
	c.check(not a.services.npc({"script":"FuchsiaCity_SafariZone_Entrance_EventScript_InfoAttendant"}),"Safari information attendant keeps Yes/No explanation")
	c.check(a.services.npc({"script":"0x0"}),"Safari admission attendant still works")
	# Execute every bounded ordinary root with decline/cancel paths.
	var failures=[]
	for advanced in [false,true]:
		for script in p.book.roots:
			fixture()
			if advanced:
				a.Finale.state(a).champion=true; a.Finale.state(a).silph_boss=true; a.field.finish("coin_case")
				for id in range(1,61): a.collection.register({"id":id})
			p.start({"script":script})
			var count=0
			while p.active and count<120:
				if p.waiting_choice: p.choose(int(advanced) if p.choices==["YES","NO"] else 127,p.generation)
				else: a.advance_dialogue()
				count+=1
			if p.aborted or p.active: failures.append(script+" / "+str(advanced))
			if count%10==0: await process_frame
	c.check(failures.is_empty(),"All source ordinary roots terminate: "+str(failures))
	print("NPC PROGRAM ROOTS: ",p.book.roots.size())
	print("NPC PROGRAM CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
