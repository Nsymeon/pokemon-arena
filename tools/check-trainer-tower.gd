extends SceneTree
var c
var a
var tower
func _initialize(): run.call_deferred()
func fixture():
	a.clear_ui(); a.dialog=""; a.world.scenes.reset(); a.npc_program.cancel(true)
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true
	a.data.party=[a.new_mon(6,50),a.new_mon(9,70),a.new_mon(3,60)]; a.inventory.migrate()
	a.world.enabled=true; a.world.view3d.enabled="--qa-render" in OS.get_cmdline_user_args(); a.world.current="MAP_TRAINER_TOWER_LOBBY"
	a.in_battle=false; a.exploring=true; c.campaign.active=false
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selection_controls.visible=false
	c.selecting=true; c.result=""; c.paused=false
func check_paths():
	var w=a.world; var occupied=w.occupied_tiles(); var start=Vector2i((a.position_world/w.TILE).floor())
	var reached={start:true}; var queue=[start]; var cursor=0
	while cursor<queue.size():
		var cell=queue[cursor]; cursor+=1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next=cell+direction
			if reached.has(next) or occupied.has(next) or w.terrain_blocked((Vector2(next)+Vector2.ONE*0.5)*w.TILE): continue
			reached[next]=true; queue.append(next)
	for actor in w.actors():
		var tile=Vector2i((actor.pos/w.TILE).floor()); var accessible=false
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if reached.has(tile+direction): accessible=true
		c.check(accessible,"Tower challenger reachable: "+w.current+" / "+str(actor.script))
	for warp in w.room().warps:
		# Source floor 2-8 elevator warps sit behind solid walls. The original
		# elevator is only usable from the roof and returns to the lobby.
		if warp.dest_map=="MAP_TRAINER_TOWER_ELEVATOR" and tower.floor_number(w.current)<9: continue
		var tile=Vector2i(int(warp.x),int(warp.y)); var accessible=reached.has(tile)
		# Doors on solid wall tiles warp on the attempted cardinal step.
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if reached.has(tile+direction): accessible=true
		c.check(accessible,"Tower stairs reachable: "+w.current+" -> "+str(warp.dest_map))
func run():
	if "--qa-render" in OS.get_cmdline_user_args(): root.size=Vector2i(1280,960)
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; c.campaign.writable=false; tower=a.trainer_tower; fixture()
	var clerk="TrainerTower_Lobby_EventScript_MartClerk"
	c.check(tower.npc({"script":clerk}) and a.inventory.shop_script==clerk and a.inventory.stock(clerk).has("ultraball"),"Lobby clerk opens original tower shop stock")
	a.clear_ui()
	c.check(tower.gate("MAP_TRAINER_TOWER_1F")!="" and tower.gate("MAP_TRAINER_TOWER_ROOF")!="","Unstarted challenge cannot skip reception or reach prize roof")
	var fights=0
	for mode in tower.MODES:
		fixture(); tower.start(mode); var s=tower.state()
		if "--qa-render" in OS.get_cmdline_user_args():
			a.visible=true; a.queue_redraw(); c.queue_redraw()
			for i in 6: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://captures/tower-"+mode+".png")
		c.check(s.active and s.format==mode and a.world.current=="MAP_TRAINER_TOWER_1F","Reception starts "+mode)
		for floor_index in 8:
			a.world.enter("MAP_TRAINER_TOWER_"+str(floor_index+1)+"F",Vector2(4.5,6.5)*48)
			check_paths()
			c.check(s.floor==floor_index,"Previous floor completion unlocks the next")
			c.check(tower.gate("MAP_TRAINER_TOWER_"+str(floor_index+2)+"F")!="","Cannot skip an uncleared floor")
			var floor=tower.current_floor(); var count=3 if floor.type=="knockout" else 1
			var actors=a.world.actors().filter(func(o):return str(o.get("script","")).begins_with("TrainerTower_EventScript_"))
			c.check(actors.size()==(2 if floor.type=="double" else 1),"Only the selected floor format's source actors appear")
			for trainer in count:
				var expected=tower.build(); tower.fight(); c.countdown=0; fights+=1
				c.check(a.in_battle and a.encounter.kind=="trainer_tower" and s.pending,"Tower trainer begins actual arena battle")
				c.check(c.doubles.active(c)==(floor.type=="double"),"Tower double format uses simultaneous battles")
				c.check(c.enemy_party.size()==expected.size() and c.enemy_party.all(func(mon):return mon.level==70),"Source floor party scales to highest non-egg level")
				for i in expected.size():
					var mon=c.enemy_party[i]; var source=expected[i]
					c.check(mon.id==source.id and mon.moves.map(func(m):return m.id)==source.moves and mon.held_item==source.held_item and mon.ivs==source.ivs and mon.nature==source.nature,"Tower build preserves species, four moves, item, IVs and nature")
				var previous=a.data.party.duplicate(true); var money=a.data.money
				c.enemy.hp=0; a.record_knockout(true); a.reward(true)
				c.check(a.data.party==previous and a.data.money==money,"Tower victory gives no EXP, EVs or money")
				a.in_battle=false; a.exploring=true; c.selecting=true
			tower.tick(10.)
		c.check(s.floor==8 and tower.gate("MAP_TRAINER_TOWER_ROOF")=="","All eight floors unlock the owner")
		a.world.enter("MAP_TRAINER_TOWER_ROOF",Vector2(4.5,6.5)*48); check_paths(); tower.complete()
		var prize=tower.book.floors[tower.book.formats[mode][0]].prize
		c.check(not s.active and s.records[mode]==80. and s.prizes[mode] and a.data.bag[prize]==1,"Format records time and awards its original one-time prize")
		tower.complete(); c.check(a.data.bag[prize]==1,"Repeated owner conversation cannot duplicate prize")
		var saved=a.data.duplicate(true); saved.x=a.position_world.x; saved.y=a.position_world.y
		c.check(a.valid(JSON.parse_string(JSON.stringify(saved))),"Tower records round-trip through save validation")
	fixture(); tower.start("double"); tower.fight(); c.countdown=0
	for f in c.enemy_bench.states: f.hp=0
	c.doubles.settle(c,4.); c.update_resolution(5.); var money=a.data.money
	a.return_world(); c.check(a.exploring and not a.in_battle and tower.state().floor==1 and a.data.money==money,"Actual double battle result returns to the same tower floor")
	tower.state().floor=1; a.world.current="MAP_TRAINER_TOWER_2F"; tower.fight(); c.countdown=0
	for f in c.player_states: f.hp=0
	c.doubles.settle(c,4.); c.shots.clear(); c.update_resolution(5.); a.return_world()
	c.check(not tower.state().active and a.world.current=="MAP_TRAINER_TOWER_LOBBY" and a.data.money==money and a.data.party.all(func(mon):return mon.hp==1.),"Tower defeat returns healed to lobby without blackout money loss")
	fixture(); tower.start("single"); tower.fight(); a.in_battle=false; tower.recover()
	c.check(not tower.state().active and not tower.state().pending,"Interrupted battle invalidates timed run on recovery")
	var bad=a.data.duplicate(true); bad.trainer_tower.floor=9; c.check(not tower.valid(bad),"Corrupt tower floor rejected")
	fixture(); tower.start("single"); a.world.current="MAP_TRAINER_TOWER_ELEVATOR"
	a.world.events.elevator_go("MAP_TRAINER_TOWER_8F")
	c.check(a.world.current=="MAP_TRAINER_TOWER_ELEVATOR" and tower.state().floor==0,"Tower elevator cannot bypass challenge floors")
	a.world.events.elevator_go("MAP_TRAINER_TOWER_LOBBY")
	c.check(a.world.current=="MAP_TRAINER_TOWER_LOBBY" and not tower.state().active,"Tower elevator safely ends a run at the lobby")
	print("TRAINER TOWER CHECK: ",c.test_failures," / ",fights," source battles")
	quit(0 if c.test_failures.is_empty() else 1)
