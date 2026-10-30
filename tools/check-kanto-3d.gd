extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame
	c.set_process(false); c.frontend.layer.visible=false; c.campaign.layer.visible=false
	var a=c.adventure; a.save_allowed=false; a.loaded=true; a.enter(); a.choose_starter(4)
	a.data.avatar={"gender":"boy","shirt":"df6367","pants":"48779d","hair":"714737","shoes":"efe5ce"}
	a.exploring=true; a.in_battle=false; a.dialog=""; a.modal=""; a.world.enabled=true
	var w=a.world; w.scenes.reset(); w.view3d.enabled=true
	for spec in [["MAP_PALLET_TOWN",Vector2(12,10)],["MAP_VIRIDIAN_CITY",Vector2(18,20)],["MAP_VIRIDIAN_FOREST",Vector2(15,20)],["MAP_MT_MOON_1F",Vector2(15,15)],["MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB",Vector2(6,9)],["MAP_CERULEAN_CITY",Vector2(20,20)],["MAP_VIRIDIAN_CITY_POKEMON_CENTER_1F",Vector2(7,7)],["MAP_SAFFRON_CITY_GYM",Vector2(9,9)],["MAP_ROUTE19",Vector2(10,15)]]:
		w.current=spec[0]; w.events.refresh(); a.position_world=(spec[1]+Vector2(.5,.5))*48; w.update_camera()
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/3d-"+str(spec[0])+".png")
		var point=w.view3d.screen_point(a.position_world)
		c.check(w.view3d.ground_point(point).distance_to(a.position_world)<.1,"3D right-click projection roundtrip "+str(spec[0]))
		print("3D MAP ",spec[0]," BUILD MS ",w.view3d.map_build_ms," BATCHES ",w.view3d.terrain.get_child_count())
	# Compile every visual scene, including the small rooms and Sevii maps.
	var total=0; var max_ms=0
	for key in w.maps:
		w.current=key; w.events.refresh(); a.position_world=w.walkable(Vector2(5,5)*48)
		await process_frame; await process_frame
		c.check(w.view3d.loaded==key,"3D map loaded "+key)
		max_ms=maxi(max_ms,w.view3d.map_build_ms); total+=1
		if total%50==0: print("3D COVERAGE ",total," maps")
	print("3D COVERAGE COMPLETE ",total," MAX BUILD MS ",max_ms)
	w.current="MAP_PALLET_TOWN"; w.events.refresh(); a.position_world=Vector2(12.5,10.5)*48
	await process_frame; await process_frame
	var before=a.data.duplicate(true)
	w.view3d.set_enabled(false); await process_frame
	c.check(a.data==before,"Classic fallback leaves progress unchanged")
	w.view3d.set_enabled(true); await process_frame
	c.check(w.view3d.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"Modern map resumes after fallback")
	var old_actor=w.view3d.actors.player.get_instance_id()
	a.data.avatar.shirt="407ac5"; w.view3d.sync_actors()
	c.check(w.view3d.actors.player.get_instance_id()!=old_actor,"Changing avatar/save slot updates the existing map's trainer")
	a.in_battle=true; await process_frame
	c.check(w.view3d.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"World rendering sleeps in battle")
	print("3D CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
