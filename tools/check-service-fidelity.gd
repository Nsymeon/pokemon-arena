extends SceneTree
var c
var a
func _initialize(): run.call_deferred()
func fixture():
	a.clear_ui(); a.dialog=""; a.world.scenes.reset(); a.npc_program.cancel(true)
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true
	a.data.party=[a.new_mon(4,20),a.new_mon(7,20)]; a.inventory.migrate()
	a.world.enabled=false; a.world.view3d.enabled=false; a.in_battle=false; a.exploring=true
	c.campaign.active=false; c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selection_controls.visible=false
	c.selecting=true; c.result=""; c.paused=false
func snap(name):
	if "--qa-render" not in OS.get_cmdline_user_args(): return
	a.visible=true; c.queue_redraw(); a.queue_redraw()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/service-"+name+".png")
func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; c.campaign.writable=false; fixture()
	var r=a.move_reminder; a.data.bag={"bigmushroom":1,"tinymushroom":2}; a.data.party[0].moves=["scratch","growl"]
	r.menu(); r.partners("bigmushroom"); r.moves(0,"bigmushroom"); r.replace(0,"ember","bigmushroom"); a.back_ui()
	c.check(a.data.bag.bigmushroom==1 and "ember" not in a.data.party[0].moves,"Move Reminder cancellation preserves payment and moves")
	c.check(not r.learn(0,"hydropump",0,"bigmushroom") and a.data.bag.bigmushroom==1,"Move Reminder rejects ineligible species moves")
	c.check(r.learn(0,"ember",2,"bigmushroom") and a.data.bag.bigmushroom==0 and a.data.party[0].moves[2]=="ember","One Big Mushroom purchases a past level-up move")
	c.check(not r.learn(0,"ember",0,"tinymushroom") and a.data.bag.tinymushroom==2,"Already known move cannot spend mushrooms twice")
	c.check(r.learn(0,"metalclaw",3,"tinymushroom") and a.data.bag.tinymushroom==0,"Two Tiny Mushrooms are an alternative payment")
	r.menu(); await snap("reminder")
	fixture(); c.check(not a.fame_checker.owns(),"Fame Checker is unavailable before Cerulean rival gift")
	a.Story.reward(a,"bridge_blue"); c.check(a.fame_checker.owns(),"Cerulean rival awards Fame Checker")
	c.check(a.fame_checker.book.size()==16 and a.fame_checker.book.values().all(func(person):return person.facts.size()==6),"All 16 people have six imported facts")
	a.npc_program.start({"script":"PalletTown_ProfessorOaksLab_EventScript_Aide3"})
	var count=0
	while a.npc_program.active and count<100:
		if a.npc_program.waiting_choice: a.npc_program.choose(127,a.npc_program.generation)
		else: a.advance_dialogue()
		count+=1
	c.check(a.fame_checker.known("FAMECHECKER_OAK",2),"Source NPC conversation unlocks its Fame Checker fact")
	for i in 6: a.field.finish("source:FAME:FAMECHECKER_OAK:"+str(i))
	a.fame_checker.person_page("FAMECHECKER_OAK"); await snap("fame")
	c.check(a.fame_checker.count("FAMECHECKER_OAK")==6,"Completion letter requires all six facts")
	fixture(); a.world.current="MAP_VIRIDIAN_CITY"; a.position_world=Vector2(20.5,8.5)*48
	c.check(not a.teachy_tv.trigger(),"Old man tutorial waits for Oak's parcel")
	a.field.finish("parcel_delivered"); var before=a.data.duplicate(true)
	c.check(a.teachy_tv.trigger(),"Source approach tile triggers the catching lesson automatically")
	await snap("teachy")
	c.check(a.data.party==before.party and a.data.balls==before.balls and a.data.money==before.money,"Demonstration never consumes actual balls or changes party")
	a.back_ui(); c.check(a.teachy_tv.owns() and not a.teachy_tv.trigger(),"Leaving the demonstration awards Teachy TV once")
	for topic in 6: a.teachy_tv.show(topic); c.check(a.modal.begins_with("TEACHY TV"),"Teachy TV lesson opens: "+str(topic)); a.back_ui()
	fixture(); a.field.finish("coin_case"); a.data.money=15000
	a.services.buy_coins(500); c.check(a.services.state().coins==500 and a.data.money==5000,"500-coin bundle costs exactly $10000")
	a.services.buy_coins(499); c.check(a.services.state().coins==500,"Invalid bundle cannot buy discounted coins")
	a.services.prize_mon(63,1); a.services.prize_tm("TM13",1)
	c.check(a.services.state().coins==500 and a.data.party.size()==2,"Prize calls enforce source prices")
	a.services.state().coins=9999
	for item in a.services.ITEM_PRIZES: a.services.prize_item(item)
	c.check(a.data.bag.yellowflute==1 and a.data.bag.smokeball==1 and a.services.state().coins==4599,"All five source held-item/flute prizes are available")
	a.services.prize_mon(63,180); c.check(a.data.party.back().id==63 and a.data.party.back().level==9 and a.data.pokedex["63"].caught,"Prize Pokemon uses FireRed level and registers in Pokedex")
	c.check(not a.services.npc({"script":"CeladonCity_GameCorner_PrizeRoom_EventScript_BaldingMan"}),"Prize-room patrons retain their own dialogue")
	var machine=load("res://game_corner_slots.gd").new(); machine.a=a; root.add_child(machine)
	var grid=["7","7","7","7","7","7","7","7","7"]
	c.check(machine.payout(machine.book,grid,1)==300 and machine.payout(machine.book,grid,2)==900 and machine.payout(machine.book,grid,3)==1500,"Slot pay lines obey 1/2/3-coin bet")
	c.check(machine.payout(machine.book,["X","CHERRIES","X","X","CHERRIES","X","X","X","X"],1)==6,"Two leading cherries pay six without requiring a third")
	var coins=a.services.state().coins; machine.start(3); machine.start(3)
	c.check(a.services.state().coins==coins-3,"Spinning bet is charged only once")
	machine.indices=[0,0,0]; for i in 3: machine.stop(i)
	coins=a.services.state().coins; for i in 3: machine.stop(i)
	c.check(a.services.state().coins==coins and machine.paid,"Stopped reels cannot duplicate payouts")
	machine.queue_free(); a.services.spin(); await snap("slots")
	fixture(); a.services.state().safari=true; a.services.state().safari_balls=30; a.services.state().safari_steps=600
	a.services.safari_encounter({"id":113,"level":25})
	c.check(a.services.catch_factor==2 and a.services.shake_threshold()==30840,"Chansey uses source integer catch factor and shake threshold")
	var expected=maxi(2,int(a.services.rates["113"].flee)*100/1275)
	a.services.bait=2; c.check(a.services.flee_chance()==maxi(1,expected/4)*5,"Bait truncates flee factor before converting to percent")
	a.services.bait=0; a.services.angry=1; a.services.catch_factor=20
	a.services.safari_watch(); c.check(a.services.catch_factor==2,"Rock effect expiry restores base catch factor")
	a.services.bait=1; a.services.catch_factor=3; a.services.safari_watch()
	c.check(a.services.catch_factor==3,"Bait catch-factor reduction persists after eating finishes")
	var xp=a.data.party.map(func(mon):return mon.xp); var money=a.data.money
	a.services.caught_safari()
	c.check(a.data.party.size()==3 and a.data.pokedex["113"].caught and a.modal.begins_with("NEW POKEDEX"),"Safari catch immediately shows a new Pokedex entry")
	c.check(a.data.party[0].xp>xp[0] and a.data.party[1].xp==xp[1] and a.data.money==money,"Safari capture EXP goes to lead, no bench EVs or money")
	c.check(a.valid(JSON.parse_string(JSON.stringify(a.data))),"New service items and progress survive save validation")
	print("SERVICE FIDELITY CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
