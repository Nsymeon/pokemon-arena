extends SceneTree
# Unsaved fixtures for native-input QA. F6 cycles cases; never loads a player save.
var c
var a
var index=0
var cases=["MAP_ROUTE1","MAP_VIRIDIAN_CITY_POKEMON_CENTER_1F","MAP_MT_MOON_B2F","MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB"]
func _initialize(): run.call_deferred()
func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame
	a=c.adventure; a.loaded=true; a.save_allowed=false; a.world.view3d.enabled=true
	root.window_input.connect(input)
	setup()
func input(event):
	if event is InputEventKey and event.pressed and event.keycode==KEY_F6:
		index=(index+1)%cases.size(); setup()
func setup():
	a.clear_ui(); a.world.scenes.reset(); a.in_battle=false; a.exploring=true; a.visible=true
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true; a.data.party=[a.new_mon(4,15)]; a.inventory.migrate()
	a.world.enabled=true; a.world.current=cases[index]; a.world.events.refresh(); a.world.stepping=false; a.world.warp_latch=""; a.dialog=""
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selecting=false; c.selection_controls.visible=false; c.paused=false; c.campaign.active=false
	c.click_move=false; c.controls.run_active=false
	match index:
		0:
			var room=a.world.room()
			for i in a.world.events.catalog[a.world.current].behavior.size():
				if int(a.world.events.catalog[a.world.current].behavior[i])==2:
					a.position_world=Vector2(i%int(room.width)+.5,int(i/int(room.width))+.5)*48; break
		1: a.position_world=Vector2(7.5,4.5)*48; a.world.heading=Vector2.UP
		2: a.position_world=Vector2(14.5,11.5)*48; a.world.heading=Vector2.LEFT
		3: a.position_world=Vector2(6.5,4.5)*48; a.world.heading=Vector2.UP; a.world.events.finish("parcel_received")
	a.world.update_camera()
	root.title="Adventure QA (unsaved) / F6 next / "+cases[index]
