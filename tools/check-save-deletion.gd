extends SceneTree
var c
var a
var slots
var render=false
func _initialize(): run.call_deferred()
func write(path: String, value: String):
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(value); file.close()
func click(text: String):
	for child in c.frontend.layer.get_children():
		if child is Button and child.text==text and not child.is_queued_for_deletion():
			child.pressed.emit(); return
	c.check(false,"Expected button exists: "+text)
func snap(label: String):
	await process_frame; await process_frame
	if not render: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/save-delete-"+label+".png")
func run():
	render="--qa-render" in OS.get_cmdline_user_args(); root.size=Vector2i(1280,960)
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.save_allowed=false; a.loaded=true; a.exploring=false; a.in_battle=false; a.world.view3d.enabled=false
	c.campaign.writable=false; slots=c.save_slots
	var stem="user://qa-delete-"+str(Time.get_ticks_usec())
	slots.paths=[stem+"-1.json",stem+"-2.json",stem+"-3.json"]
	var data=a.INITIAL_DATA.duplicate(true); data.starter=4; data.party=[a.new_mon(4,8)]; data.player_name="DELETE TEST"
	var encoded=JSON.stringify(data); var campaign=c.campaign.data.duplicate(true)
	write(slots.paths[0],encoded); write(slots.paths[0]+".bak",encoded); write(slots.paths[0]+".tmp","temporary")
	write(slots.paths[0]+".before-reset-123",encoded); write(slots.paths[0]+".before-reset-123.bak",encoded)
	write(slots.paths[1],encoded); write(slots.paths[1]+".bak",encoded)
	write(slots.paths[2],'{"version":99}')
	var unrelated=slots.paths[0]+"0.before-reset-123"; write(unrelated,"must survive")
	c.check(slots.select_slot(0,false),"Fixture loads current slot")
	slots.show(); await snap("slots")
	c.check(not slots.delete_confirmed() and slots.slot_files(0).size()==5,"Delete requires explicit confirmation")
	click("DELETE"); await snap("confirmation")
	click("CANCEL / KEEP SAVE"); await process_frame
	c.check(slots.slot_files(0).size()==5 and not slots.delete_confirmed(),"Cancel preserves save, backup and reset archives")
	slots.confirm_delete(0); c.gamepad.back_frontend()
	c.check(c.frontend.page=="slots" and slots.pending_delete==-1,"Controller Back cancels deletion and returns one level")
	slots.confirm_delete(0)
	var escape=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true; c._unhandled_input(escape)
	c.check(c.frontend.page=="slots" and slots.pending_delete==-1,"Escape cancels deletion")
	slots.confirm_delete(0); a.in_battle=true
	c.check(not slots.delete_confirmed(),"Deletion is blocked during combat"); a.in_battle=false
	a.exploring=true; c.check(not slots.delete_confirmed(),"Deletion is blocked while autosaving exploration is active"); a.exploring=false
	slots.show(); click("DELETE"); await process_frame
	click("DELETE SLOT 1 PERMANENTLY"); await snap("deleted")
	c.check(slots.slot_files(0).is_empty() and slots.info(0).status=="NEW ADVENTURE","Confirmed deletion clears all recovery paths and empties the slot")
	c.check(not a.save_allowed and not a.loaded and a.data.party.is_empty(),"Deletion discards cached active progress")
	c.check(not a.save() and slots.slot_files(0).is_empty(),"A stray autosave cannot resurrect deleted progress")
	c.check(FileAccess.get_file_as_string(slots.paths[1])==encoded and FileAccess.get_file_as_string(slots.paths[1]+".bak")==encoded,"Other save and backup stay byte-identical")
	c.check(FileAccess.get_file_as_string(unrelated)=="must survive" and c.campaign.data==campaign,"Prefix neighbors and daily progress are untouched")
	c.check(slots.select_slot(0,false) and a.data.starter==0 and a.data.party.is_empty() and a.save_allowed,"Deleted slot can start a fresh adventure")
	slots.show(); slots.confirm_delete(2)
	c.check(slots.delete_confirmed() and slots.info(2).playable,"Incompatible save can be deleted without loading it")
	write(slots.paths[2],"{broken"); slots.confirm_delete(2)
	c.check(slots.delete_confirmed(),"Corrupt save can be deleted")
	write(slots.paths[2]+".bak",encoded); slots.confirm_delete(2)
	c.check(slots.delete_confirmed() and slots.slot_files(2).is_empty(),"Backup-only slot cannot return after deletion")
	write(slots.paths[2]+".before-reset-456",encoded); slots.confirm_delete(2)
	c.check(slots.delete_confirmed(),"Recovery-only copies can be explicitly cleared")
	slots.confirm_delete(-1); c.check(not slots.delete_confirmed(),"Out-of-range slot cannot be deleted")
	c.check(slots.select_slot(1,true) and a.exploring,"Remaining save still enters Adventure")
	a.management_menu()
	var management=a.ui.get_children().filter(func(node):return node is Button and node.text=="MANAGE / DELETE SAVE SLOTS")
	c.check(management.size()==1,"Adventure menu provides save management")
	if not management.is_empty(): management[0].pressed.emit()
	c.check(not a.exploring and c.frontend.page=="slots" and FileAccess.file_exists(slots.paths[1]),"In-game management saves progress before returning to slots")
	for i in slots.paths.size():
		for path in slots.slot_files(i): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(unrelated))
	print("SAVE DELETION CHECK: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
