extends SceneTree
# UI-only playthrough launcher. All writable saves are unique QA files.
func _initialize(): start.call_deferred()
func start():
	DirAccess.make_dir_recursive_absolute("res://captures")
	var c=load("res://arena.tscn").instantiate()
	var prefix="res://captures/manual-"+str(Time.get_unix_time_from_system()).replace(".","-")
	c.save_slots.paths=[prefix+"-1.json",prefix+"-2.json",prefix+"-3.json"]
	c.adventure.save_path=c.save_slots.paths[0]
	c.campaign.path=prefix+"-daily.json"; c.campaign.writable=false
	var args=OS.get_cmdline_user_args()
	for arg in args:
		if not arg.begins_with("--snapshot="): continue
		var path=arg.trim_prefix("--snapshot=")
		if not path.begins_with("res://captures/journey-") or not FileAccess.file_exists(path): quit(2); return
		var file=FileAccess.open(c.save_slots.paths[0],FileAccess.WRITE)
		file.store_string(FileAccess.get_file_as_string(path)); file.close()
	root.add_child(c)
	c.frontend.show_title()
	# Passing a snapshot argument otherwise selects the engine's compact test
	# world. Keep this launcher on the normal 3D Adventure UI in either case.
	process_frame.connect(func():
		var a=c.adventure
		if a.exploring and not a.world.enabled:
			a.world.activate(); a.dialog=""
			if not a.data.has("avatar"): a.avatar.show_creator(a))
	DisplayServer.window_set_title("Pokemon Arena / ISOLATED PLAYTHROUGH QA")
	print("QA SAVES: ",prefix)
