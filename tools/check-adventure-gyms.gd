extends SceneTree
# Exercise real Adventure entry points and live fighters, with no player saves.
var c
var a
const GYMS=[
	["brock","MAP_PEWTER_CITY_GYM","brock"],
	["misty","MAP_CERULEAN_CITY_GYM","misty"],
	["surge","MAP_VERMILION_CITY_GYM","story_surge"],
	["late_erika","MAP_CELADON_CITY_GYM","late_task_erika"],
	["late_koga","MAP_FUCHSIA_CITY_GYM","late_task_koga"],
	["late_sabrina","MAP_SAFFRON_CITY_GYM","late_task_sabrina"],
	["late_blaine","MAP_CINNABAR_ISLAND_GYM","late_task_blaine"],
	["late_giovanni","MAP_VIRIDIAN_CITY_GYM","late_task_giovanni"]]

func _initialize(): run.call_deferred()

func fixture(kind="misty"):
	a.clear_ui(); a.world.scenes.reset(); a.dialog=""
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true
	a.data.party=[a.new_mon(6,70),a.new_mon(9,70)]; a.inventory.migrate()
	a.in_battle=false; a.exploring=true; a.world.enabled=true
	a.world.current=GYMS.filter(func(g):return g[0]==kind)[0][1]; a.world.events.refresh()
	a.Story.state(a)["switch"]=2
	a.Finale.state(a).merge({"silph_saved":true,"secret_key":true,"quiz":true,"flute":true})
	if kind=="late_giovanni":
		a.data.badge=true; a.data.cascade=true; a.Story.state(a).thunder=true
		for badge in ["rainbow","soul","marsh","volcano"]: a.Finale.state(a)[badge]=true
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.campaign.active=false
	c.selecting=true; c.result=""; c.paused=false

func start(kind="misty"):
	fixture(kind)
	var entry=GYMS.filter(func(g):return g[0]==kind)[0]
	a.interact_npc(entry[2]); c.countdown=0
	c.check(a.in_battle and a.encounter.kind==kind,"Gym interaction starts correct battle: "+kind)

func snap(name):
	if "--qa-render" not in OS.get_cmdline_user_args(): return
	c.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/gym-"+name+".png")

func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; a.world.view3d.enabled=false; c.campaign.writable=false
	var presets=c.league.trainers.duplicate(true)
	var daily=c.campaign.daily
	var daily_before=[]
	for stage in 13: daily_before.append(daily.opponent(c,stage).duplicate(true))
	for spec in GYMS:
		start(spec[0]); var source=a.gyms.leaders[spec[0]]
		c.check(c.opponent_identity==source.identity,"Leader appearance: "+spec[0])
		c.check(a.encounter.gym_items==source.items,"Original trainer item inventory: "+spec[0])
		c.check(c.enemy_party.size()==source.party.size() and c.enemy_bench.states.size()==source.party.size(),"No extra or missing fighters: "+spec[0])
		for i in source.party.size():
			c.enemy_bench.activate(c,i); var f=c.enemy; var expected=source.party[i]
			c.check(int(f.data.id)==int(expected.id) and int(f.data.level)==int(expected.level),"Live species and level: "+spec[0]+" / "+str(i))
			c.check(f.data.moves.map(func(m):return m.id)==expected.moves,"Exact source moves and ordering, no filler: "+spec[0]+" / "+str(i))
			c.check(f.data.get("held_item","")=="","No inherited preset held item: "+spec[0]+" / "+str(i))
			for index in f.data.moves.size():
				c.Conditions.init(f); c.Conditions.init(c.player); c.support.reset(); c.shots.clear()
				f.hp=f.data.hp; f.energy=100; f.dash_time=0; f.dash_move={}
				c.player.hp=c.player.data.hp; c.enemy_cooldowns=[0.,0.,0.,0.]; c.countdown=0; c.result=""
				c.use_move(f,c.player,index,Vector2.LEFT,false)
				c.check(f.action_lock>0,"Source move can be attempted: "+f.data.moves[index].id)
		# Neither victory/badge state nor the player's inventory changes at entry.
		c.check(not a.progression.gym_cleared(spec[0]),"Gym is not cleared by starting it: "+spec[0])
	start("brock")
	c.check(c.enemy.data.moves.size()==2 and c.enemy_bench.states[1].data.moves.map(func(m):return m.id)==["tackle","bind","rocktomb"],"Brock retains two/three slots and Rock Tomb")
	c.enemy.hp=1; c.check(not a.gyms.try_item(),"Brock has no healing item")
	await snap("brock")
	start("late_giovanni")
	c.check(c.enemy_party[-1].id==111 and c.enemy_party[-1].level==50,"Giovanni ends with Rhyhorn level 50")
	# Item use goes through actual AI decisions, spends one shared inventory,
	# respects action/recovery gates, and never resets when switching partners.
	start(); var before=a.data.duplicate(true); var inventory=a.encounter.gym_items.duplicate()
	c.check(not a.gyms.try_item() and a.encounter.gym_items==inventory,"Healthy partner does not consume Super Potion")
	c.enemy.hp=c.enemy.data.hp*.1; c.enemy.action_lock=.5
	c.check(not a.gyms.try_item(),"Cannot use item during attack recovery")
	c.enemy.action_lock=0; c.enemy.charge_left=.5
	c.check(not a.gyms.try_item(),"Cannot use item during charging")
	c.enemy.charge_left=0; c.enemy.volatile.underground=1
	c.check(not a.gyms.try_item(),"Cannot use item during Dig")
	c.enemy.volatile.clear(); c.countdown=1
	c.check(not a.gyms.try_item(),"Cannot use item during send-out")
	c.countdown=0; c.paused=true; c.check(not a.gyms.try_item(),"Pause preserves item inventory"); c.paused=false
	c.enemy_bench.timer=0; c.check(not a.gyms.try_item(),"Cannot use item during switch"); c.enemy_bench.timer=-1
	c.result="SWITCH"; c.check(not a.gyms.try_item(),"Cannot use item during faint resolution"); c.result=""
	c.ai_timer=0; c.enemy_bench.cooldown=20; c.shots.clear(); c.update_ai(.01)
	c.check(is_equal_approx(c.enemy.hp,c.enemy.data.hp*.6),"AI really uses Super Potion at shared player healing strength")
	c.check(a.encounter.gym_items==[""] and c.enemy.action_lock==1 and c.enemy.movement_lock==1,"One item consumed with one-second action and movement recovery")
	c.check(c.shots.is_empty() and a.data==before,"Item action fires no simultaneous move and does not spend player's items")
	await snap("misty-potion")
	c.Conditions.init(c.enemy); c.enemy.hp=1
	c.check(not a.gyms.try_item(),"Consumed potion cannot be reused")
	c.enemy_bench.activate(c,1); c.countdown=0; c.enemy.hp=1
	c.check(not a.gyms.try_item() and a.encounter.gym_items==[""],"Switching does not restock trainer items")
	start(); c.enemy.hp=1; c.check(a.gyms.try_item(),"New battle after a defeat gets a fresh trainer inventory")
	# Later slots are reserved according to living team size, like the source.
	start("surge"); c.enemy.ailment="sleep"; c.enemy.ailment_time=2
	c.check(not a.gyms.try_item(),"Surge reserves his second item with three partners alive")
	c.enemy_bench.states[2].hp=0; c.enemy.volatile.confusion=2
	c.check(a.gyms.try_item() and c.enemy.ailment=="" and not c.enemy.volatile.has("confusion"),"Full Heal cures sleep and confusion when available")
	c.check(a.encounter.gym_items==["superpotion",""] and c.enemy.hp==c.enemy.data.hp,"Full Heal neither spends the potion nor heals HP")
	for status in ["poison","toxic","paralysis","burn","freeze"]:
		start("surge"); c.enemy_bench.states[2].hp=0; c.enemy.ailment=status; c.enemy.ailment_time=3; c.enemy.toxic_tick=4
		c.check(a.gyms.try_item() and c.enemy.ailment=="" and c.enemy.ailment_time==0 and c.enemy.toxic_tick==0,"Full Heal cures "+status)
	start("late_koga"); c.enemy.hp=1; c.check(a.gyms.try_item(),"Koga uses first Hyper Potion")
	c.Conditions.init(c.enemy); c.enemy.hp=1
	c.check(not a.gyms.try_item(),"Koga reserves second potion with four partners alive")
	c.enemy_bench.states[3].hp=0
	c.check(a.gyms.try_item() and a.encounter.gym_items==["","","fullheal"],"Second identical potion has its own finite inventory slot")
	# Source definitions and the other modes cannot acquire consumed items or edits.
	c.check(a.gyms.leaders.late_koga.items==["hyperpotion","hyperpotion","fullheal"],"Runtime consumption never mutates source inventory")
	start("late_erika"); c.enemy.data.moves.clear()
	start("late_erika"); c.check(c.enemy.data.moves.size()==4,"Live move edits cannot mutate future trainer builds")
	a.in_battle=false; c.enemy.hp=1
	c.check(not a.gyms.try_item(),"Adventure inventory cannot leak into Free/Daily battles")
	c.check(c.league.trainers==presets,"Free Battle presets are unchanged")
	for stage in 13: c.check(daily.opponent(c,stage)==daily_before[stage],"Daily full level-50 teams unchanged: "+str(stage))
	# All eight badge guards still apply, including a save JSON round trip.
	for spec in GYMS:
		fixture(spec[0])
		if spec[0]=="brock": a.data.badge=true
		elif spec[0]=="misty": a.data.cascade=true
		elif spec[0]=="surge": a.Story.state(a).thunder=true
		else: a.Finale.state(a)[a.Finale.TASKS[spec[0].trim_prefix("late_")].flag]=true
		a.data=JSON.parse_string(JSON.stringify(a.data)); var snapshot=a.data.duplicate(true)
		a.begin_battle(spec[0],[25],[100])
		c.check(not a.in_battle and a.data==snapshot,"Existing badge/save blocks rematch: "+spec[0])
	print("ADVENTURE GYM CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
