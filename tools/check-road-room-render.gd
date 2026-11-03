extends SceneTree
# Render regression for source-walkable road corners and the indoor cutaway rim.
# Uses isolated in-memory progress; never loads or saves the player's adventure.
# Run with a real renderer: godot --path . --script tools/check-road-room-render.gd -- --qa-road-room
var c
var a
var w
var view
var prefix="road-room-after"
func _initialize(): run.call_deferred()
func enter(map_id: String, at: Vector2):
	w.scenes.reset(); a.clear_ui(); a.dialog=""; w.stepping=false
	w.current=map_id; w.events.refresh(); a.position_world=at*w.TILE
	for i in 5: await process_frame
func snap(label: String):
	await RenderingServer.frame_post_draw
	view.viewport.get_texture().get_image().save_png("res://captures/"+prefix+"-"+label+".png")
func rim_clearance() -> float:
	var floor_y=-INF; var clearance=INF
	for child in view.terrain.get_children():
		if child is MeshInstance3D and child.mesh is PlaneMesh: floor_y=child.position.y
	for child in view.terrain.get_children():
		if not child is MultiMeshInstance3D or child.material_override!=view.kit.material("404e4e"): continue
		var mm=child.multimesh
		for i in mm.instance_count:
			var bounds: AABB=mm.get_instance_transform(i)*mm.mesh.get_aabb()
			clearance=minf(clearance,bounds.end.y-floor_y)
	return clearance
func run():
	if DisplayServer.get_name()=="headless":
		push_error("This visual regression needs a real renderer; omit --headless.")
		quit(2); return
	if "--qa-before" in OS.get_cmdline_user_args(): prefix="road-room-before"
	root.size=Vector2i(1280,860)
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame
	c.set_process(false); c.selecting=false; c.selection_controls.visible=false
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.campaign.writable=false
	a=c.adventure; a.save_allowed=false; a.loaded=true; a.enter(); a.choose_starter(4)
	a.data.avatar=a.avatar.DEFAULT.duplicate(true); a.exploring=true; a.in_battle=false
	w=a.world; w.enabled=true; view=w.view3d; view.enabled=true
	await enter("MAP_VIRIDIAN_CITY",Vector2(30.5,24.5))
	var clear_roads=true
	for tile in [Vector2i(20,19),Vector2i(22,22),Vector2i(30,22),Vector2i(32,22),Vector2i(39,22)]:
		var index=tile.y*int(w.room().width)+tile.x
		c.check(not int(w.room().cells[index])&0xc00,"Reproduction road tile is source-walkable "+str(tile))
		clear_roads=clear_roads and view.catalog[w.current].tiles[index] in ["lawn","path"]
	c.check(clear_roads,"Viridian road corners render as flat ground")
	await snap("viridian")
	for spec in [["MAP_PALLET_TOWN_PLAYERS_HOUSE_1F",Vector2(2.5,4.5),4], ["MAP_PALLET_TOWN_RIVALS_HOUSE",Vector2(2.5,4.5),4], ["MAP_VIRIDIAN_CITY_POKEMON_CENTER_1F",Vector2(4.5,5.5),3]]:
		await enter(spec[0],spec[1]); await snap(str(spec[0])+"-start")
		var gap=rim_clearance()
		c.check(is_finite(gap) and gap>.02,"Rendered cutaway rim clears floor depth "+str(spec[0])+" gap="+str(gap))
		w.heading=Vector2.DOWN
		for step in int(spec[2]):
			w.step_target=a.position_world+Vector2.DOWN*w.TILE; w.stepping=true
			var tile=Vector2i(w.step_target/w.TILE); var index=tile.y*int(w.room().width)+tile.x
			c.check(not int(w.room().cells[index])&0xc00,"Walking test stays on an open source tile")
			while w.stepping:
				w.advance_step(1.0/60.0); await process_frame
			await snap(str(spec[0])+"-down-"+str(step))
		c.check(w.current==spec[0],"Walking toward the cutaway wall stays in the room")
	print("ROAD / ROOM RENDER CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
