extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame
	c.set_process(false); c.selecting=false; c.selection_controls.visible=false; c.frontend.layer.visible=false; c.campaign.layer.visible=false
	var a=c.adventure; a.save_allowed=false; a.loaded=true
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true; a.data.party=[a.new_mon(4,15)]; a.inventory.migrate()
	a.exploring=true; a.visible=true; a.in_battle=false; a.dialog=""; a.modal=""
	var w=a.world; w.enabled=true; w.view3d.enabled=true; w.scenes.reset()
	for spec in [["MAP_PALLET_TOWN",Vector2(12,10)],["MAP_VIRIDIAN_CITY",Vector2(25,20)],["MAP_ROUTE22",Vector2(33,5)],["MAP_VIRIDIAN_FOREST",Vector2(15,20)],["MAP_PALLET_TOWN_PLAYERS_HOUSE_1F",Vector2(6,6)],["MAP_PALLET_TOWN_PLAYERS_HOUSE_2F",Vector2(6,6)],["MAP_MT_MOON_1F",Vector2(15,15)]]:
		w.current=spec[0]; w.events.refresh(); a.position_world=w.walkable((spec[1]+Vector2.ONE*.5)*48); w.update_camera()
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/art-pass-"+str(spec[0])+".png")
		print("ART PREVIEW ",spec[0]," ",w.view3d.map_build_ms," ms / ",w.view3d.terrain.get_child_count()," batches")
	quit()
