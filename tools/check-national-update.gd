extends SceneTree
var c
var a
var w
var render=false
func _initialize(): run.call_deferred()
func check(value,label): c.check(value,label)
func fixture():
	a.clear_ui(); a.world.scenes.reset(); a.in_battle=false; a.exploring=true; a.visible=true
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true; a.data.party=[a.new_mon(6,60)]; a.inventory.migrate()
	w.enabled=true; w.current="MAP_ROUTE1"; w.events.refresh(); a.position_world=Vector2(7.5,7.5)*48; a.dialog=""
	c.campaign.active=false; c.campaign.layer.visible=false; c.frontend.layer.visible=false; c.selection_controls.visible=false; c.selecting=true
func scene_done():
	if w.scenes.active: w.scenes.finish()
func run():
	render="--qa-render" in OS.get_cmdline_user_args()
	if render: root.size=Vector2i(1280,960)
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; w=a.world; a.save_allowed=false; a.loaded=true; c.campaign.writable=false
	w.view3d.enabled=render; fixture()
	check(c.roster.size()==388 and c.art.library.size()==388 and c.art.shiny_library.size()==388,"Complete portraits and animated National roster")
	for mon in c.roster:
		check(c.art.library.has(int(mon.id)) and c.art.library[int(mon.id)].has("Walk"),"Walk animation "+mon.name)
		check(a.inventory.starting(int(mon.id),50).size()>0,"Adventure learnset "+mon.name)
	a.expansion.state(); a.postgame.state()
	check(a.valid(JSON.parse_string(JSON.stringify(a.data))),"Legacy challenge and legendary save blocks coexist and round-trip")
	a.postgame.activate(); check(a.postgame.state().roamer.is_empty(),"Roamer waits for Network Machine")
	a.sevii.finish("network"); a.progression.finish("national_dex"); a.Finale.state(a).champion=true
	for pair in [[1,244],[4,245],[7,243]]:
		a.data.starter=pair[0]; a.postgame.state().roamer={}; a.postgame.activate()
		check(a.postgame.state().roamer.mon.id==pair[1],"Starter-dependent roaming species")
	var r=a.postgame.state().roamer
	var terrain=w.events.catalog[w.current].behavior
	for i in terrain.size():
		if int(terrain[i])==2: a.position_world=Vector2(i%int(w.room().width)+.5,int(i/int(w.room().width))+.5)*48; break
	r.map=w.current
	for i in 100:
		if a.postgame.try_roamer(): break
	check(a.in_battle and a.postgame.pending,"Manual habitat search starts a roaming encounter")
	var ivs=c.enemy.data.ivs.duplicate(true)
	c.enemy.hp=c.enemy.data.hp*.3; c.enemy.ailment="burn"; c.countdown=0; c.player.action_lock=0; c.player.charge_left=0; c.result=""
	a.return_world(false,true)
	check(not a.in_battle and is_equal_approx(float(r.mon.hp),.3) and r.mon.ailment=="burn" and not r.ended,"Roamer persists wounds after fleeing")
	r.map=w.current
	for i in 100:
		if a.postgame.try_roamer(): break
	check(c.enemy.data.ivs==ivs and is_equal_approx(c.enemy.hp/c.enemy.data.hp,.3),"Roamer reuses identity and HP on next encounter")
	a.return_world(true); check(r.ended,"Capture retires roaming encounter")
	check(a.valid(JSON.parse_string(JSON.stringify(a.data))),"Caught roamer state survives JSON reload")
	a.clear_ui(); a.sevii.finish("tri_pass"); a.sevii.finish("ruby_delivered"); w.current="MAP_VERMILION_CITY"; w.events.refresh()
	check(not a.postgame.can_sail(0),"Event island requires its ticket")
	a.postgame.claim_tickets(); scene_done(); check(a.postgame.can_sail(0) and a.postgame.can_sail(1),"Mystery Gift unlocks both event tickets")
	a.postgame.sail(1); scene_done(); check(w.current=="MAP_BIRTH_ISLAND_HARBOR","Ferry arrives at Birth Island harbor")
	w.enter("MAP_BIRTH_ISLAND_EXTERIOR",Vector2(15.5,23.5)*48)
	a.postgame.triangle(); a.postgame.state().steps=5; a.postgame.triangle(); check(a.postgame.state().triangle==0,"Triangle resets on excess steps")
	for i in 11:
		a.postgame.state().steps=0 if i==0 else a.postgame.book.caps[i-1]
		a.postgame.triangle()
	scene_done(); check(a.in_battle and c.enemy.data.id==386 and c.enemy.data.level==30,"Solved source triangle summons Deoxys Lv.30")
	a.return_world(true); check(a.field.done("static:Deoxys"),"Deoxys is a one-shot capture")
	a.clear_ui(); w.current="MAP_NAVEL_ROCK_SUMMIT"; w.events.refresh(); a.postgame.legendary(250,"HoOh"); scene_done()
	check(a.in_battle and c.enemy.data.id==250 and c.enemy.data.level==70,"Navel Rock summons Ho-Oh Lv.70")
	a.return_world(true); a.clear_ui(); w.current="MAP_NAVEL_ROCK_BASE"; w.events.refresh(); a.postgame.legendary(249,"Lugia"); scene_done()
	check(a.in_battle and c.enemy.data.id==249 and c.enemy.data.level==70,"Navel Rock summons Lugia Lv.70")
	a.return_world(true); a.clear_ui()
	for i in 5: check(a.postgame.league_team(i).all(func(mon):return mon.level>=63),"Source postgame League stage "+str(i))
	for pair in [[152,16,153],[280,20,281],[371,30,372]]: check(a.evolution_rules.level_target(a.new_mon(pair[0],pair[1]))==pair[2],"National level evolution")
	w.current="MAP_SEVEN_ISLAND_TANOBY_RUINS_MONEAN_CHAMBER"; w.events.refresh(); a.position_world=Vector2(6.5,5.5)*48
	check(w.scenes.pool().is_empty(),"Unown waits for Tanoby Key puzzle")
	a.sevii.finish("tanoby"); check(not w.scenes.encounters[w.current].land_mons.is_empty(),"Unown has source chamber encounter slots after puzzle")
	var scyther=a.new_mon(123,40); scyther.held_item="metalcoat"; check(a.evolution_rules.item_target(scyther,"linkcable")==212,"Held-item trade evolution")
	var eevee=a.new_mon(133,40); check(a.evolution_rules.item_target(eevee,"waterstone")==134,"Stone evolution preserved")
	c.campaign.active=true
	var id=26; var key=c.move_editor.identity(c.roster[c.Dex.find_id(c.roster,id)],true,0)
	c.gear.choices[key]="leftovers"; c.ivs.natures[key]="Adamant"; c.abilities.choices[key]="Lightning Rod"
	var member=c.move_editor.configured(c.roster[c.Dex.find_id(c.roster,id)],true,0)
	check(member.level==50 and member.nature=="Hardy" and member.get("held_item","")=="" and member.ability_slot==0,"Daily preview overrides external item, nature and ability choices")
	for stage in 13: check(c.campaign.daily.opponent(c,stage).all(func(mon):return mon.level==50 and mon.nature=="Hardy" and mon.get("held_item","")=="" and mon.ability_slot==0),"Opponent challenge lock "+str(stage))
	c.campaign.active=false
	fixture(); w.current="MAP_PALLET_TOWN"; w.events.refresh(); a.position_world=Vector2(12.5,.5)*48; w.heading=Vector2.UP
	if render:
		for i in 12: await process_frame
		check(w.view3d.map_cache.has("MAP_ROUTE1") and w.view3d.map_cache.MAP_ROUTE1.visible,"Adjacent Route 1 is rendered before crossing")
		var link=w.room().connections.filter(func(l):return l.map=="MAP_ROUTE1")[0]
		var before=w.view3d.focus; var offset=w.view3d.connection_offset(w.current,link)
		await snap("national-map-before")
		w.view3d.rebase(w.current,link)
		check(w.view3d.focus.is_equal_approx(before-offset),"Connection rebases camera without screen-space jump")
		var target=(a.position_world/48-Vector2(offset.x,offset.z)+Vector2.UP)*48
		w.enter(link.map,target)
		check(w.current=="MAP_ROUTE1" and a.position_world.is_equal_approx(target),"Exact connection alignment preserves tile position")
		await snap("national-map-seam")
		var model=w.view3d.actors.player; var rig=preload("res://kanto_character_models.gd").new()
		for i in 32:
			rig.pose(model,i*TAU/32,1)
			for leg in ["LeftLeg","RightLeg"]:
				var foot=model.get_node(leg+"/Knee/Foot")
				check(foot.global_position.y>=.065,"Foot stays above ground through stride")
		for i in 4:
			w.heading=[Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.RIGHT][i]
			for j in 12:
				w.view3d.age+=.02
				w.view3d.move_actor(model,a.position_world+Vector2(j*2,0),w.heading,true)
			await snap("national-walk-"+str(i))
	a.menu()
	var buttons=a.ui.get_children().filter(func(node):return node is Button and node.text=="SAVE & MAIN MENU")
	check(buttons.size()==1,"Main menu button exists")
	if render:
		await process_frame
		root.warp_mouse(buttons[0].get_global_rect().get_center()); await process_frame
		c.gamepad.click(MOUSE_BUTTON_LEFT)
	else: buttons[0].pressed.emit()
	await process_frame
	check(not a.exploring and c.frontend.layer.visible and a.modal=="","Main menu button actually returns to mode selector")
	print("NATIONAL UPDATE: PASS" if c.test_failures.is_empty() else c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
func snap(name):
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/"+name+".png")
