extends SceneTree
var c
var a
const KIND="world_Route8_EventScript_Eli"
func _initialize(): run.call_deferred()
func fixture():
	a.clear_ui(); a.dialog=""; a.world.scenes.reset(); a.npc_program.cancel(true)
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true
	a.data.party=[a.new_mon(4,30),a.new_mon(7,30),a.new_mon(25,30)]; a.inventory.migrate()
	a.world.enabled=false; a.world.view3d.enabled=false; a.in_battle=false; a.exploring=true
	c.campaign.active=false; c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selection_controls.visible=false
	c.paused=false; c.selecting=false; c.result=""
	a.begin_battle(KIND,[],[]); c.countdown=0; c.rocks.clear()
	for f in c.player_states+c.enemy_bench.states: f.data.ability="None"; f.inv=0
func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; c.campaign.writable=false
	fixture()
	if "--qa-render" in OS.get_cmdline_user_args() or "--qa-manual" in OS.get_cmdline_user_args():
		root.size=Vector2i(1280,960); a.visible=false
		for i in 50: c.clock_time+=.04; c.update_battle(.04); c.update_effects(.04)
		c.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/double-battle.png")
		if "--qa-manual" in OS.get_cmdline_user_args(): c.switch_menu=true; c.set_process(true); return
	c.check(c.doubles.active(c) and c.allies().size()==2 and c.foes().size()==2,"Source double trainer creates two simultaneous partners per side")
	c.check(a.encounter.participants["0"]==[0,1] and a.encounter.participants["1"]==[0,1],"Both active partners participate against both opponents")
	var key=InputEventKey.new(); key.pressed=true; key.physical_keycode=KEY_B; key.keycode=KEY_B
	c._unhandled_input(key); c.check(c.switch_menu,"Physical B opens the team menu in a double battle")
	key.physical_keycode=KEY_2; key.keycode=KEY_2; c._unhandled_input(key)
	c.check(c.player_active==1 and not c.switch_menu,"Party hotkey transfers control to the active partner")
	c.request_switch(0)
	var controlled=c.player; var ally=c.allies()[1]
	c.cooldowns[0]=5.; c.request_switch(1)
	c.check(c.player==ally and c.player_active==1 and c.switch_time<0,"Selecting active ally transfers control without recall")
	c.request_switch(0); c.check(c.player==controlled and c.cooldowns[0]==5.,"Control transfer preserves each partner's cooldowns")
	c.projectile(c.player.pos,Vector2.RIGHT,300,50,10,true,Color.WHITE,{"type":"Normal"})
	c.switch_cooldown=0; c.player.movement_lock=0
	c.check(c.request_switch(2) and c.shots.size()==1,"Bench switch preserves an already committed partner attack")
	c.complete_switch(); c.countdown=0
	c.check(c.doubles.player_slots==[2,1] and c.allies()[1]==ally and c.player.double_entry==0,"Bench switch replaces only the controlled lane without a second entry lock")
	fixture(); controlled=c.player; ally=c.allies()[1]
	var reserve=c.enemy.duplicate(true); reserve.battle_slot=2; reserve.double_cooldowns=[8.,2.,0.,0.]
	c.enemy_bench.states.append(reserve); c.enemy_bench.cooldown=0
	c.check(not c.enemy_bench.request(c,1),"Enemy cannot substitute its already active partner")
	c.check(c.enemy_bench.request(c,2),"Double opponent may bring in a living reserve")
	c.enemy_bench.complete(c); c.countdown=0
	c.check(c.doubles.enemy_slots==[2,1] and c.enemy==reserve and c.enemy_cooldowns==[0.,0.,0.,0.] and c.enemy_bench.used==1,"Enemy replacement resets cooldowns and spends one shared switch")
	fixture(); ally=c.allies()[1]
	c.support.teams[0].reflect=60.
	c.check(c.support.multiplier(c,ally,{"category":"Physical"})==.5 and c.support.multiplier(c,c.enemy,{"category":"Physical"})==1.,"Screens protect both allies and neither opponent")
	c.support.reset(); c.player.pos=Vector2(400,500); ally.pos=Vector2(550,500)
	var enemy=c.foes()[0]; enemy.pos=Vector2(900,500); c.foes()[1].pos=Vector2(1000,500)
	var hp=c.allies().map(func(f):return f.hp)
	c.skills.launch(c,enemy,c.player,{"id":"solarbeam","type":"Grass","damage":8.},Vector2.LEFT,false)
	c.skills.tick(c,c.shots.back(),1.)
	c.check(c.player.hp<hp[0] and ally.hp<hp[1],"Enemy beam can damage both allied targets")
	c.shots.clear(); for f in c.allies()+c.foes(): f.inv=0
	hp=c.foes().map(func(f):return f.hp)
	c.skills.launch(c,ally,enemy,{"id":"solarbeam","type":"Grass","damage":8.},Vector2.RIGHT,true)
	c.skills.tick(c,c.shots.back(),1.)
	c.check(c.foes()[0].hp<hp[0] and c.foes()[1].hp<hp[1],"Partner beam damages both opponents")
	c.check(c.player.hp<c.player.data.hp and c.shots.back().owner==ally,"Partner cast keeps its own damage owner")
	c.shots.clear(); fixture()
	for i in 240: c.clock_time+=.04; c.update_battle(.04)
	c.check(c.allies()[1].has("last_move") and c.foes().all(func(f):return f.has("last_move")),"Ally and both enemies independently cast moves")
	fixture(); c.player.hp=0; c.doubles.settle(c,.1)
	c.check(c.player_active==1 and c.result=="","Control moves to surviving ally without ending the fight")
	c.doubles.settle(c,c.FAINT_RESULT_TIME)
	c.check(2 in c.doubles.player_slots and c.player_states[2].double_cooldowns==[0.,0.,0.,0.],"Fainted partner is replaced by a reserve with clear cooldowns")
	fixture(); var target=c.foes()[0]; target.hp=0; c.doubles.settle(c,.1)
	c.check(c.result=="" and a.encounter.rewarded.size()==1,"One opposing faint grants one reward without ending the double")
	var xp=a.data.party.map(func(mon):return mon.xp)
	c.doubles.settle(c,.1); c.check(a.data.party.map(func(mon):return mon.xp)==xp,"Repeated settle cannot duplicate EXP")
	c.check(xp[0]>0 and xp[0]==xp[1] and xp[2]==0,"Only the two participants share EXP")
	a.world.events.battle_reward(KIND,true)
	c.check(a.trainers.book.scripts.keys().filter(func(script):return a.trainers.book.scripts[script]==a.encounter.trainer_id).all(func(script):return a.field.done("trainer:"+script)),"Victory clears both paired trainer actors")
	fixture(); c.player.pos=Vector2(400,500); var last=c.foes()[0]; last.pos=Vector2(600,500); last.hp=1
	for f in c.foes().slice(1): f.hp=0
	c.projectile(c.player.pos,Vector2.RIGHT,300,50,10,true,Color.WHITE,{"type":"Normal"})
	for f in c.player_states: f.hp=0
	c.doubles.settle(c,0); c.update_resolution(5.)
	c.check(c.result=="DRAW" and c.resolution_ready(),"Committed attack resolves after total party faint and can produce a draw")
	fixture(); a.in_battle=false; a.data.party=a.data.party.slice(0,1); a.begin_battle(KIND,[],[])
	c.check(not a.in_battle and "two healthy" in a.dialog,"Double trainer requires two healthy partners")
	print("DOUBLE BATTLE CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
