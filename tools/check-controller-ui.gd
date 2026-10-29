extends SceneTree
func _initialize(): run.call_deferred()
func snap(c,name):
	c.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/"+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute("res://captures")
	var c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame
	c.set_process(false); c.adventure.save_allowed=false
	c.frontend.show_title(); await process_frame
	root.warp_mouse(Vector2(640,730)); await process_frame
	c.gamepad.active=true; c.gamepad.press(JOY_BUTTON_A); await process_frame
	c.check(c.frontend.page=="modes","Controller pointer clicks Play through the real GUI")
	c.save_slots.show(); await snap(c,"save-slots")
	c.gamepad.show_settings(); await snap(c,"controller-settings")
	c.gamepad.press(JOY_BUTTON_B); await process_frame
	c.check(c.frontend.page=="settings","Controller Back returns to parent Settings")
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.pick(25,7); c.selecting=false; c.countdown=0; c.paused=false
	c.gamepad.active=true; c.gamepad.press(JOY_BUTTON_A); await process_frame
	c.check(c.player.has("last_move"),"Controller A casts a battle move through event dispatch")
	c.controls.run_active=false; c.gamepad.press(JOY_BUTTON_RIGHT_SHOULDER); await process_frame
	c.check(c.controls.run_active,"Controller shoulder toggles sprint")
	c.gamepad.press(JOY_BUTTON_START); await process_frame
	c.check(c.paused,"Controller Start pauses combat")
	c.gamepad.press(JOY_BUTTON_B); await process_frame
	c.check(not c.paused,"Controller Back resumes combat")
	c.ivs.open(c.roster[0],true,0); await process_frame
	c.gamepad.press(JOY_BUTTON_B); await process_frame
	c.check(not c.ivs.window.visible,"Controller Back closes the embedded IV window")
	var a=c.adventure; a.loaded=true; a.enter(); a.choose_starter(4); a.dialog=""
	a.begin_battle("wild",[19],[3]); c.countdown=0; c.player.action_lock=0
	c.gamepad.press(JOY_BUTTON_BACK); await process_frame
	c.check(a.modal.begins_with("BAG"),"Controller opens the battle Bag")
	await snap(c,"controller-bag")
	var edit=LineEdit.new(); edit.max_length=4; edit.text="A"; a.ui.add_child(edit)
	c.gamepad.open_keyboard(edit); c.gamepad.type_letter("B"); c.gamepad.close_keyboard(true)
	c.check(edit.text=="AB","Controller screen keyboard writes to the selected text field")
	c.gamepad.open_keyboard(edit); c.gamepad.type_letter("C"); c.gamepad.close_keyboard(false)
	c.check(edit.text=="AB","Controller screen keyboard Cancel leaves text unchanged")
	var stream=AudioStreamMP3.new(); stream.data=FileAccess.get_file_as_bytes("res://assets/audio/music/lavender-lets-go.mp3")
	print("LAVENDER AUDIO SECONDS: ",stream.get_length())
	c.check(stream.get_length()>600,"Downloaded Lavender track is a complete decodable extended recording")
	print("CONTROLLER GUI CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
