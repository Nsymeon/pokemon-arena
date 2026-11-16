extends SceneTree
var c
var a

func _initialize(): run.call_deferred()

func fixture():
	a.clear_ui(); a.dialog=""; a.world.scenes.reset(); a.npc_program.cancel(true)
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true
	a.data.party=[a.new_mon(4,12),a.new_mon(7,12),a.new_mon(25,12)]; a.inventory.migrate()
	a.world.enabled=true; a.world.current="MAP_FOUR_ISLAND"; a.world.view3d.enabled=false
	a.in_battle=false; a.exploring=true; c.campaign.active=false
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selection_controls.visible=false; c.selecting=true; c.result=""

func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; c.campaign.writable=false
	fixture()
	var mon=a.data.party[0]; mon.moves=["scratch","growl","ember","smokescreen"]; mon.xp=a.xp_needed(mon)-1
	var ivs=mon.ivs.duplicate(); a.services.deposit(0); a.clear_ui(); a.services.steps()
	c.check(mon.level==12 and mon.moves==["scratch","growl","ember","smokescreen"],"Stored parent keeps original level/moves until withdrawal")
	var preview=a.services.projected(mon,1)
	c.check(preview.level==13 and preview.moves==["growl","ember","smokescreen","metalclaw"],"Day Care new move replaces first move in order")
	a.data.money=199; a.services.withdraw(); c.check(not a.services.state().daycare.is_empty(),"Insufficient retrieval fee keeps parent")
	a.data.money=200; a.services.withdraw()
	c.check(a.data.party[-1].level==13 and a.data.party[-1].moves==preview.moves and a.data.party[-1].ivs==ivs and a.data.money==0,"Withdrawal applies growth once and preserves individual IVs")
	a.services.withdraw(); c.check(a.data.money==0,"Repeated withdrawal cannot charge twice")
	var evolving=a.new_mon(4,15); evolving.xp=a.xp_needed(evolving)-1
	preview=a.services.projected(evolving,1); c.check(preview.id==4 and preview.level==16,"Day Care does not evolve at the normal evolution level")
	preview=a.services.projected(evolving,1000000000); c.check(preview.level==100 and preview.xp==0,"Large stored step count respects level cap")
	fixture(); a.breeding.deposit(0); a.clear_ui()
	var parent=a.breeding.state().parents[0]; parent.mon.xp=a.xp_needed(parent.mon)-1; var original_moves=parent.mon.moves.duplicate()
	a.breeding.step(); c.check(parent.mon.level==12 and parent.mon.moves==original_moves and parent.xp_steps==1,"Four Island also defers growth while breeding")
	a.breeding.withdraw(0); c.check(a.data.party[-1].level==13 and "metalclaw" in a.data.party[-1].moves,"Four Island withdrawal applies same learning rules")
	fixture(); var legacy=a.new_mon(4,20)
	a.services.state().daycare={"mon":legacy,"start_level":18,"deposited":0}
	c.check(a.services.fee()==300,"Previously gained levels in legacy Day Care retain their fee without re-granting EXP")
	a.services.withdraw(); c.check(a.data.party[-1].level==20,"Legacy deposited partner retains level")
	fixture(); var egg=a.new_mon(175,5); a.breeding.prepare_egg(egg,175); egg.egg_cycles=1
	a.data.party.append(egg); a.breeding.state().hatch_phase=253
	a.breeding.step(); c.check(egg.egg_cycles==1,"Egg cycles do not decrease between cycle boundaries")
	a.breeding.step(); c.check(egg.egg_cycles==0 and egg.egg_steps>0,"First boundary consumes cycle without early hatch")
	for i in 255: a.breeding.step()
	c.check(egg.egg_steps>0,"Egg waits until following boundary")
	a.breeding.step(); c.check(egg.egg_steps==0,"Zero-cycle egg becomes ready on the next shared boundary")
	a.breeding.step(); c.check(egg.egg_steps==0,"Ready egg cannot regain remaining steps")
	c.check(a.valid(JSON.parse_string(JSON.stringify(a.data))),"New egg phase and deferred Day Care data survive save validation")
	var broken=a.data.duplicate(true); broken.breeding.hatch_phase=256; c.check(not a.valid(broken),"Invalid hatch phase rejected")
	print("DAY CARE FIDELITY CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
