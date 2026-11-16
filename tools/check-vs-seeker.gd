extends SceneTree
var c
var a
var v
const BEN="Route3_EventScript_Ben"
const BASE="TRAINER_YOUNGSTER_BEN"

func _initialize(): run.call_deferred()

func fixture():
	a.clear_ui(); a.dialog=""; a.world.scenes.reset(); a.npc_program.cancel(true)
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true
	a.data.party=[a.new_mon(4,40),a.new_mon(7,40)]; a.inventory.migrate()
	a.world.enabled=true; a.world.current="MAP_ROUTE3"; a.world.view3d.enabled=false
	a.in_battle=false; a.exploring=true; c.campaign.active=false
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selection_controls.visible=false; c.selecting=true; c.result=""

func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; c.campaign.writable=false; v=a.vs_seeker
	fixture()
	v.step(); c.check(not a.data.has("vs_seeker"),"Walking before the gift does not charge the device")
	c.check(v.npc({"script":v.GIVER}) and v.owns() and v.state().charge==0,"Vermilion giver awards the device once")
	for i in 30: v.step()
	v.npc({"script":v.GIVER}); c.check(v.state().charge==30,"Repeated giver dialogue preserves charge")
	c.check(v.book.rematches.size()==221,"All source rematch ladders loaded")
	c.check(v.target(BASE)=="TRAINER_YOUNGSTER_BEN_2","First rematch uses first replacement team")
	v.state().defeated["TRAINER_YOUNGSTER_BEN_2"]=true
	c.check(v.target(BASE)=="TRAINER_YOUNGSTER_BEN_2","Later team remains gated before Fuchsia")
	a.field.finish("visited:MAP_FUCHSIA_CITY")
	c.check(v.target(BASE)=="TRAINER_YOUNGSTER_BEN_3","Fuchsia unlocks next unplayed team")
	v.state().defeated["TRAINER_YOUNGSTER_BEN_3"]=true
	c.check(v.target(BASE)=="TRAINER_YOUNGSTER_BEN_3","Champion team remains gated")
	a.Finale.state(a).champion=true
	c.check(v.target(BASE)=="TRAINER_YOUNGSTER_BEN_4","Champion unlocks final Ben team")
	# Exercise each ladder, including SKIP slots and repeating original teams.
	for base in v.book.rematches:
		v.state().defeated.clear()
		for id in v.book.rematches[base].parties:
			if id!="": v.state().defeated[id]=true
		for gate in ["visited:MAP_CELADON_CITY","visited:MAP_FUCHSIA_CITY","sevii:network"]: a.field.finish(gate)
		c.check(v.target(base) in v.book.rematches[base].parties and v.target(base)!="","Every ladder resolves a real team: "+base)
	fixture(); v.npc({"script":v.GIVER}); a.clear_ui(); a.dialog=""
	var npc=a.world.actors().filter(func(o):return o.get("script","")==BEN)[0]
	a.position_world=npc.pos+Vector2(48,0)
	v.activate(); c.check(v.state().charge==0 and v.state().ready.is_empty(),"Uncharged activation cannot start a rematch")
	for i in 100: v.step()
	c.check(v.state().charge==100,"Device charges from 100 walking steps")
	v.activate(); c.check(v.state().charge==0 and v.state().ready.is_empty(),"Unbeaten trainers cannot grant stronger rematches")
	a.field.finish("trainer:"+BEN)
	# Deterministic seed search tests acceptance without probabilistic test failure.
	for trial in 40:
		v.state().charge=100; v.random.seed=trial; v.activate()
		if v.ready(BEN): break
	c.check(v.ready(BEN) and v.state().remaining==100,"A defeated nearby trainer accepts a charged invitation")
	var before=a.data.duplicate(true)
	c.check(a.valid(JSON.parse_string(JSON.stringify(before))),"Charge, response and progression serialize")
	var broken=before.duplicate(true); broken.vs_seeker.charge=101
	c.check(not a.valid(broken),"Invalid charge is rejected")
	broken=before.duplicate(true); broken.vs_seeker.ready["TRAINER_LEADER_BROCK"]=true
	c.check(not a.valid(broken),"Gym leaders cannot enter rematch state")
	for i in 99: v.step()
	c.check(v.ready(BEN),"Response lasts through 99 steps")
	v.step(); c.check(not v.ready(BEN),"Response expires after 100 steps")
	a.data=before.duplicate(true); a.world.current="MAP_ROUTE4"; v.entered()
	c.check(v.state().ready.is_empty() and v.state().charge==before.vs_seeker.charge,"Map exit clears responses but preserves charge")
	a.data=before.duplicate(true); a.world.current="MAP_ROUTE3"
	c.check(v.npc(npc) and a.in_battle and a.encounter.trainer_id=="TRAINER_YOUNGSTER_BEN_2","Talking starts exact source rematch battle")
	c.check(not v.ready(BEN) and not a.progression.gym_cleared(a.encounter.kind),"Invitation consumed once without modifying Gym completion")
	var team=a.trainers.book.trainers[a.encounter.trainer_id].party
	for i in team.size(): c.check(c.enemy_party[i].moves.map(func(m):return m.id)==team[i].moves,"Rematch preserves source moves")
	v.result(false); c.check(v.state().defeated.is_empty(),"Defeat does not advance trainer ladder")
	v.result(true); c.check(v.state().defeated.has("TRAINER_YOUNGSTER_BEN_2"),"Victory advances only the fought team")
	a.in_battle=false; a.data.badge=true; a.begin_battle("brock",[],[])
	c.check(not a.in_battle,"Obtaining Vs. Seeker cannot bypass completed Gym guard")
	a.world.current="MAP_PEWTER_CITY_GYM"; v.state().charge=100; v.activate()
	c.check(v.state().charge==100 and not a.in_battle,"Indoor use is refused without wasting charge")
	print("VS SEEKER CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
