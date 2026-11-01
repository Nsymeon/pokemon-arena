extends SceneTree
func _initialize(): run.call_deferred()
func key(code: int, pressed: bool):
	var event=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	Input.parse_input_event(event)
func run():
	var c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame
	c.set_process(false); c.adventure.save_allowed=false; c.controls.gamepad=null
	c.frontend.layer.visible=false; c.campaign.layer.visible=false
	c.pick(25,7); c.selecting=false; c.countdown=0; c.paused=false
	c.controls.run_active=true
	c.check(not c.controls.held("battle_sprint"),"Adventure toggle does not activate battle sprint")
	key(KEY_SPACE,true); await process_frame
	c.check(c.controls.held("battle_sprint"),"Holding Space requests sprint")
	c.check(not c.player.has("last_move"),"Space does not cast attack 2")
	var energy=c.player.energy
	c.sprint_movement(Vector2.RIGHT,.1,c.controls.held("battle_sprint"))
	c.check(c.player.energy<energy,"Held sprint consumes stamina")
	key(KEY_SPACE,false); await process_frame
	c.check(not c.controls.held("battle_sprint"),"Releasing Space immediately ends sprint")
	c.check(c.controls.run_active,"Battle sprint leaves Adventure toggle untouched")
	key(KEY_E,true); await process_frame; key(KEY_E,false)
	c.check(c.player.has("last_move"),"E casts the second attack")
	print("SPRINT CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
