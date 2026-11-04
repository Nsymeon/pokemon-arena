extends RefCounted
var c
var selected=0
var pending_delete=-1
# Slot 1 deliberately keeps the original path: no migration or replacement of existing progress.
var paths=["user://adventure-v1.json","user://adventure-slot-2.json","user://adventure-slot-3.json"]

func info(slot) -> Dictionary:
	var exists=false
	for suffix in ["",".bak"]:
		if not FileAccess.file_exists(paths[slot]+suffix): continue
		exists=true
		var parser=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(paths[slot]+suffix))!=OK: continue
		var value=parser.data
		if value is Dictionary and value.get("version",1)!=1: return {"status":"INCOMPATIBLE SAVE", "playable":false,"existing":true}
		if c.adventure.valid(value):
			var place=c.adventure.MAPS[int(value.map)]
			if value.has("world_map"): place=c.adventure.world.maps[value.world_map].name.replace("_"," ")
			var team=value.party
			var lead="Choose your starter" if team.is_empty() else c.adventure.mon_name(int(team[0].id))+" Lv."+str(int(team[0].level))
			return {"status":place+" / "+lead+(" / BACKUP RECOVERY" if suffix!="" else ""),"playable":true,"existing":true}
	return {"status":"SAVE DAMAGED / preserved" if exists else "NEW ADVENTURE", "playable":not exists,"existing":exists}

func slot_files(slot: int) -> Array:
	if slot<0 or slot>=paths.size(): return []
	var files=[]; var path=str(paths[slot]); var directory=DirAccess.open(path.get_base_dir())
	if directory:
		for file in directory.get_files():
			if file.begins_with(path.get_file()+".before-reset-"): files.append(path.get_base_dir().path_join(file))
	# Remove recovery files first so a deleted primary cannot be auto-restored.
	for suffix in [".tmp",".bak",""]:
		if FileAccess.file_exists(path+suffix): files.append(path+suffix)
	return files

func show(notice: String=""):
	pending_delete=-1
	c.frontend.background(); c.frontend.page="slots"
	c.frontend.label("ADVENTURE / SAVE SLOTS",Vector2(255,100),42,Color("f9d86b"))
	c.frontend.label("Each slot has its own trainer, Pokemon, story and backup.",Vector2(250,170),21)
	for i in range(paths.size()):
		var summary=info(i)
		var button=Button.new(); button.position=Vector2(160,265+i*155); button.size=Vector2(730,115)
		button.text="SLOT %d%s\n%s" % [i+1," / CURRENT" if i==selected else "",summary.status]
		button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size",22); button.disabled=not summary.playable
		button.pressed.connect(select_slot.bind(i,true)); c.frontend.layer.add_child(button)
		var erase=Button.new(); erase.text="DELETE"; erase.position=Vector2(920,290+i*155); erase.size=Vector2(200,65)
		erase.add_theme_font_size_override("font_size",22); erase.add_theme_color_override("font_color",Color("ffafa6"))
		erase.disabled=slot_files(i).is_empty(); erase.pressed.connect(confirm_delete.bind(i)); c.frontend.layer.add_child(erase)
	c.frontend.label(notice if notice!="" else "Delete clears only that slot and its backups. You will be asked to confirm.",Vector2(160,765),19,Color("77e2b0"))
	c.frontend.button("BACK",Rect2(490,835,300,60),c.frontend.show_modes)

func confirm_delete(slot: int):
	if slot<0 or slot>=paths.size() or c.adventure.exploring or c.adventure.in_battle: return
	if slot_files(slot).is_empty(): show("That slot is already empty."); return
	pending_delete=slot; c.frontend.background(); c.frontend.page="delete_save"
	c.frontend.label("DELETE ADVENTURE / SLOT "+str(slot+1)+"?",Vector2(220,150),38,Color("ffafa6"))
	var summary=Label.new(); summary.text=str(info(slot).status); summary.position=Vector2(180,265); summary.size=Vector2(920,90)
	summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; summary.add_theme_font_size_override("font_size",24); c.frontend.layer.add_child(summary)
	c.frontend.label("Permanently remove this trainer, Pokemon, items and story progress,\nincluding automatic backups and copies made before a reset.\nThis cannot be undone. Other slots and modes are unaffected.",Vector2(180,390),23)
	c.frontend.button("CANCEL / KEEP SAVE",Rect2(180,590,920,70),show)
	c.frontend.button("DELETE SLOT "+str(slot+1)+" PERMANENTLY",Rect2(180,700,920,65),delete_confirmed)

func delete_confirmed() -> bool:
	var a=c.adventure; var slot=pending_delete
	if slot<0 or slot>=paths.size() or c.frontend.page!="delete_save" or not c.frontend.layer.visible or a.exploring or a.in_battle: return false
	for path in slot_files(slot):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path))!=OK:
			show("Could not finish deleting Slot "+str(slot+1)+". Close other game windows and try again."); return false
	if a.save_path==paths[slot]:
		# Discard the cached adventure too: a later save call must not resurrect it.
		a.save_allowed=false; a.loaded=false; a.save_error=""; a.data=a.INITIAL_DATA.duplicate(true)
		a.position_world=Vector2(a.data.x,a.data.y); a.autosave=0; a.progress_time=0
		a.clear_ui(); a.dialog=""; a.encounter.clear(); a.evolutions.clear(); a.progress_lines.clear()
		a.world.scenes.reset(); a.world.enabled=false
	show("Slot "+str(slot+1)+" deleted. Select it to start a new adventure.")
	return true

func select_slot(slot,enter_world=true) -> bool:
	var a=c.adventure
	if slot<0 or slot>=paths.size() or a.in_battle or a.exploring or not info(slot).playable: return false
	selected=slot; a.save_path=paths[slot]; a.save_allowed=true; a.save_error=""
	a.data=a.INITIAL_DATA.duplicate(true); a.position_world=Vector2(a.data.x,a.data.y)
	a.clear_ui(); a.dialog=""; a.encounter.clear(); a.evolutions.clear(); a.progress_lines.clear()
	a.progress_time=0; a.capture_time=0; a.wild_cycle=0; a.autosave=0
	a.world.scenes.reset(); a.world.enabled=false; a.collection.pc_box=0; a.collection.search=""; a.collection.shiny_only=false
	a.load_save()
	if enter_world:
		c.frontend.layer.visible=false; a.enter()
	return true

func tests():
	var a=c.adventure
	var old_paths=paths.duplicate(); var old_selected=selected; var state={}
	for key in ["data","save_path","save_allowed","save_error","loaded","position_world","in_battle","exploring"]:
		var value=a.get(key); state[key]=value.duplicate(true) if value is Dictionary else value
	var old_world=a.world.enabled; a.in_battle=false; a.exploring=false
	paths=["user://qa-slot-1.json","user://qa-slot-2.json","user://qa-slot-3.json"]
	for i in range(3):
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(paths[i]+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(paths[i]+suffix))
	for i in range(2):
		var value=a.INITIAL_DATA.duplicate(true); value.money=111*(i+1)
		var file=FileAccess.open(paths[i],FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()
	c.check(select_slot(0,false) and a.data.money==111,"Slot 1 loads its own adventure")
	c.check(select_slot(1,false) and a.data.money==222,"Slot 2 loads independently")
	a.data.money=333; c.check(a.save(),"Selected slot saves successfully")
	c.check(select_slot(0,false) and a.data.money==111,"Saving slot 2 cannot overwrite slot 1")
	c.check(select_slot(2,false) and a.data.starter==0 and a.data.party.is_empty(),"Empty slot starts a fresh adventure")
	var broken=FileAccess.open(paths[1],FileAccess.WRITE); broken.store_string("{broken"); broken.close()
	c.check(info(1).playable and select_slot(1,false) and a.data.money==222,"A slot recovers only from its own valid backup")
	broken=FileAccess.open(paths[2],FileAccess.WRITE); broken.store_string("{broken"); broken.close()
	c.check(not info(2).playable and not select_slot(2,false),"Damaged slot without backup is protected from overwrite")
	a.in_battle=true; c.check(not select_slot(0,false),"Cannot switch saves during a fight"); a.in_battle=false
	for path in paths:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	paths=old_paths; selected=old_selected
	for key in state: a.set(key,state[key])
	a.world.enabled=old_world
