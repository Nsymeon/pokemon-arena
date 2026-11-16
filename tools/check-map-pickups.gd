extends SceneTree
var c
var a

func _initialize(): run.call_deferred()

func fixture():
	a.clear_ui(); a.dialog=""; a.world.scenes.reset(); a.npc_program.cancel(true)
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true
	a.data.party=[a.new_mon(4,12),a.new_mon(7,12)]; a.inventory.migrate()
	a.world.enabled=true; a.world.current="MAP_ROUTE1"; a.world.view3d.enabled=false
	a.in_battle=false; a.exploring=true; c.campaign.active=false
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selection_controls.visible=false; c.selecting=true; c.result=""

func check_pickup(item):
	var key=a.world.current+"item"+str(item.id)
	a.world.events.pickup(item)
	c.check(a.world.events.done(key),"Map item can be collected: "+key+" / "+str(item.item))
	var before=a.data.duplicate(true)
	a.world.events.pickup(item)
	c.check(a.data==before,"Collected item cannot be duplicated: "+key)

func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; c.campaign.writable=false
	fixture()
	var visible=0; var hidden=0
	for map in a.world.maps:
		a.world.current=map
		for item in a.world.events.catalog[map].items:
			check_pickup(item); visible+=1
		for item in a.progression.hidden_items():
			check_pickup(item); hidden+=1
	c.check(visible>100 and hidden>100,"Audit exercises the real visible and hidden item records")
	c.check(a.valid(JSON.parse_string(JSON.stringify(a.data))),"Collected items and flags survive save validation")
	fixture()
	for id in ["POKE_BALL","GREAT_BALL","ULTRA_BALL","TM01","POTION"]:
		var key=id.to_lower().replace("_","")
		if id=="POKE_BALL": a.data.balls=999
		elif id.begins_with("TM"): a.data.tms[id]=999
		else: a.data.bag[key]=999
		var item={"id":"qa_"+id,"item":id}
		a.world.events.pickup(item)
		c.check(not a.world.events.done(a.world.current+"item"+item.id),"Full pocket leaves pickup on map: "+id)
		if id=="POKE_BALL": a.data.balls=998
		elif id.begins_with("TM"): a.data.tms[id]=998
		else: a.data.bag[key]=998
		check_pickup(item)
		var amount=a.data.balls if id=="POKE_BALL" else a.data.tms[id] if id.begins_with("TM") else a.data.bag[key]
		c.check(amount==999,"Retry after making room preserves correct item: "+id)
	fixture(); a.world.events.pickup({"id":"great","item":"GREAT_BALL"}); a.world.events.pickup({"id":"ultra","item":"ULTRA_BALL"})
	c.check(a.data.balls==0 and a.data.bag.greatball==1 and a.data.bag.ultraball==1,"Special balls never turn into ordinary balls")
	a.data.bag.sacredash=1
	a.extras.targets("sacredash"); c.check(a.data.bag.sacredash==1,"Sacred Ash kept when no fainted partners")
	for mon in a.data.party: mon.hp=0.; mon.ailment="poison"
	a.extras.targets("sacredash"); c.check(a.data.bag.sacredash==0 and a.data.party.all(func(mon):return mon.hp==1 and mon.ailment==""),"Sacred Ash revives all fainted partners once")
	a.data.party[0].moves=["recover"]; a.data.bag.ppmax=1
	a.extras.pp_up(0,"recover","ppmax"); c.check(a.data.party[0].ppups.recover==3 and a.data.bag.ppmax==0,"PP Max grants all recovery PP increases once")
	var mon=a.data.party[0]; mon.friendship=70; mon.held_item="soothebell"
	a.extras.friendship(mon,5); c.check(mon.friendship==77,"Soothe Bell rounds a 50% friendship bonus down")
	a.extras.friendship(mon,1); c.check(mon.friendship==78,"Soothe Bell does not invent fractional walking bonus")
	c.pick(25,7); c.enemy.data.ability="Torrent"
	for pair in [["cheriberry","paralysis"],["chestoberry","sleep"],["pechaberry","toxic"],["rawstberry","burn"],["aspearberry","freeze"]]:
		c.player.data.held_item=pair[0]; c.player.ailment=pair[1]
		c.gear.tick(c.player,c.enemy,.1)
		c.check(c.player.ailment=="" and c.player.data.held_item=="","Held berry cures and consumes: "+pair[0])
	c.player.data.held_item="oranberry"; c.player.hp=c.player.data.hp*.4; var hp=c.player.hp
	c.gear.tick(c.player,c.enemy,.1); c.check(is_equal_approx(c.player.hp,minf(c.player.data.hp,hp+10)),"Oran restores ten HP")
	c.player.data.held_item="leppaberry"; c.player.energy=0
	c.gear.tick(c.player,c.enemy,.1); c.check(c.player.energy==40 and c.player.data.held_item=="","Leppa supports arena energy exhaustion")
	c.player.data.held_item="rawstberry"; c.player.ailment="burn"; c.enemy.data.ability="Unnerve"
	c.gear.tick(c.player,c.enemy,.1); c.check(c.player.ailment=="burn" and c.player.data.held_item=="rawstberry","Unnerve blocks new berries without consuming them")
	print("MAP PICKUP CHECK: ",c.test_failures," / ",visible," visible / ",hidden," hidden")
	quit(0 if c.test_failures.is_empty() else 1)

