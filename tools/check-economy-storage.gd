extends SceneTree
var c
var a

func _initialize(): run.call_deferred()

func fixture():
	a.clear_ui(); a.dialog=""; a.world.scenes.reset(); a.npc_program.cancel(true)
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true
	a.data.party=[a.new_mon(4,10),a.new_mon(7,10)]; a.inventory.migrate()
	a.world.enabled=true; a.world.current="MAP_ROUTE1"; a.world.view3d.enabled=false
	a.in_battle=false; a.exploring=true; c.campaign.active=false; a.collection.pc_box=0
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selection_controls.visible=false; c.selecting=true; c.result=""

func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; c.campaign.writable=false
	fixture()
	c.check(a.INITIAL_DATA.money==3000 and a.INITIAL_DATA.balls==0,"Original initial money and pre-Pokedex ball count")
	c.check(a.data.bag.is_empty() and a.data.pc_items=={"potion":1},"New game starts with an empty bag and one Potion in the PC")
	a.inventory.transfer_pc_item("potion",false)
	c.check(a.data.bag.potion==1 and a.data.pc_items.is_empty(),"Bedroom PC Potion withdraws once")
	a.inventory.transfer_pc_item("potion",false); c.check(a.data.bag.potion==1,"Repeated withdrawal cannot duplicate item")
	a.inventory.transfer_pc_item("potion",true); c.check(a.data.bag.is_empty() and a.data.pc_items.potion==1,"Item deposit round trip preserves counts")
	a.world.current="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB"; a.world.scenes.pokedex_delivery(); a.world.scenes.finish()
	c.check(a.data.balls==5,"Oak supplies five balls with the Pokedex")
	a.world.scenes.pokedex_delivery(); c.check(a.data.balls==5,"Oak handoff cannot repeat reward")
	c.check(a.inventory.ITEMS.potion.price==300 and a.inventory.ITEMS.superpotion.price==700 and a.inventory.ITEMS.revive.price==1500,"Source medicine prices")
	a.inventory.shop_script=""
	for script in a.economy.book.shops:
		for id in a.economy.book.shops[script]: c.check(id=="balls" or a.inventory.ITEMS.has(id) or a.inventory.book.tms.has(id),"Every source shop product supported: "+id)
	var cash=a.data.money; var balls=a.data.balls; a.inventory.buy("balls",200)
	c.check(a.data.money==cash-200 and a.data.balls==balls+1,"One ball costs 200")
	cash=a.data.money; a.inventory.buy("balls",1); c.check(a.data.money==cash and a.data.balls==balls+1,"Stale/wrong-price purchase cannot undercharge")
	a.data.balls=999; a.inventory.buy("balls",200); c.check(a.data.money==cash,"Full bag purchase does not charge")
	a.inventory.shop("PewterCity_Mart_EventScript_Clerk"); a.inventory.buy("ultraball",1200)
	c.check(a.data.money==cash and int(a.data.bag.get("ultraball",0))==0,"Shop cannot sell another city's stock")
	a.inventory.shop("CeladonCity_DepartmentStore_2F_EventScript_ClerkTMs")
	c.check("TM15" in a.inventory.stock(a.inventory.shop_script) and "potion" not in a.inventory.stock(a.inventory.shop_script),"Department Store clerks have separate stocks")
	a.data.bag.potion=1; cash=a.data.money; a.inventory.sell("potion")
	c.check(a.data.bag.potion==0 and a.data.money==cash+150,"Selling pays half the source price")
	for pair in [["TRAINER_LEADER_BROCK",1400],[a.trainers.resolve("rival"),80]]:
		a.encounter={"kind":"test","trainer_id":pair[0]}; c.check(a.economy.prize()==pair[1],"Original payout: "+pair[0])
		a.encounter={"kind":"brock","trainer_id":"TRAINER_LEADER_BROCK"}
	c.check(a.economy.prize(true)==2800,"Participating Amulet Coin doubles source prize")
	a.encounter.kind="wild"; c.check(a.economy.prize(true)==0,"Wild Pokemon never give money")
	for trainer in a.trainers.book.trainers.values(): c.check(a.economy.book.trainer_classes.has(trainer.trainer_class),"Source prize class exists: "+trainer.trainer_class)
	# Legacy unlimited boxes are redistributed deterministically, preserving every mon.
	fixture(); a.data.erase("storage_layout")
	for i in 100:
		var mon=a.new_mon(19,5); mon.nickname="Old "+str(i); mon.box=0; a.data.storage.append(mon)
	var original=a.data.storage.duplicate(true)
	c.check(a.valid(a.data),"Legacy 100-mon overflowing box is accepted for migration")
	a.collection.sync()
	c.check(a.collection.box_count(0)==30 and a.collection.box_count(1)==30 and a.collection.box_count(2)==30 and a.collection.box_count(3)==10,"Legacy overflow occupies free original-size boxes")
	for i in 100:
		var expected=original[i].duplicate(true); expected.box=a.data.storage[i].box
		c.check(a.data.storage[i]==expected,"Migration preserves species, moves and individual data: "+str(i))
	var migrated=a.data.duplicate(true); a.collection.sync(); c.check(a.data==migrated,"Storage migration is idempotent")
	c.check(a.valid(JSON.parse_string(JSON.stringify(a.data))),"Migrated save round trip is valid")
	a.collection.pc_box=0; c.check(not a.collection.can_deposit(0),"Selected full box blocks deposit")
	var box_before=a.data.storage[99].box; a.collection.move_box(99,0)
	c.check(a.data.storage[99].box==box_before,"Moving into full box preserves original slot")
	for i in range(100,a.collection.STORAGE_CAPACITY): c.check(a.collection.store(a.new_mon(19,5)),"Store within 420 capacity")
	c.check(a.data.storage.size()==420 and not a.collection.store(a.new_mon(25,5)),"Exactly 420 Pokemon fit")
	for box in a.collection.BOX_COUNT: c.check(a.collection.box_count(box)==30,"Box capacity: "+str(box))
	c.check(a.valid(a.data),"Full 14-box save validates")
	var broken=a.data.duplicate(true); broken.storage[30].box=0
	c.check(not a.valid(broken),"New overfilled-box saves are rejected")
	broken=a.data.duplicate(true); broken.storage[0].box=14
	c.check(not a.valid(broken),"Invalid box number rejected")
	fixture()
	for i in 30: a.collection.store(a.new_mon(19,5))
	var mon=a.new_mon(25,5); c.check(a.collection.store(mon) and mon.box==1,"Capture/gift storage advances to next available box")
	a.collection.pc_box=13; a.collection.deposit(0)
	c.check(a.data.party.size()==1 and a.collection.box_count(13)==1,"Box 14 deposit works")
	fixture(); a.begin_battle("wild",[19],[5]); c.countdown=0; c.player.action_lock=0; c.enemy.hp=c.enemy.data.hp
	var normal=a.catch_chance(); var great=a.catch_chance("greatball"); var ultra=a.catch_chance("ultraball")
	c.check(great>normal and ultra>great,"Great and Ultra Ball capture bonuses work")
	a.collection.register({"id":19}); c.check(a.catch_chance("repeatball")>ultra,"Repeat Ball checks caught Pokedex history")
	a.encounter.battle_seconds=30; c.check(a.catch_chance("timerball")>ultra,"Timer Ball improves with active battle seconds")
	a.data.bag.greatball=2; var old_balls=a.data.balls; a.throw_ball(false,"greatball")
	c.check(a.data.bag.greatball==1 and a.data.balls==old_balls and a.capture_time>0,"Special ball consumes correct inventory and starts capture")
	print("ECONOMY / STORAGE CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
