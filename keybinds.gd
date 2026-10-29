extends Node

const SAVE = "user://controls-v1.json"
# Context masks: battle=1, adventure exploration=2, shared=3.
const DEFINITIONS = [
	["up","Move up",3,KEY_W,KEY_UP], ["down","Move down",3,KEY_S,KEY_DOWN],
	["left","Move left",3,KEY_A,KEY_LEFT], ["right","Move right",3,KEY_D,KEY_RIGHT],
	["sprint","Sprint / run",3,KEY_E,0], ["click_move","Move to cursor",3,-2,0],
	["move1","Attack 1",1,KEY_Q,-1], ["move2","Attack 2",1,KEY_SPACE,0],
	["move3","Attack 3",1,KEY_F,0], ["move4","Attack 4",1,KEY_C,0],
	["switch","Switch team menu",1,KEY_B,0], ["roster","Roster / league hub",1,KEY_TAB,0],
	["restart","Restart battle",1,KEY_R,0], ["capture","Throw Poke Ball",1,KEY_G,0],
	["bag","Bag",3,KEY_I,0], ["interact","Interact / talk",2,KEY_SPACE,0],
	["party","Adventure team",2,KEY_P,0], ["map","Kanto guide",2,KEY_M,0],
	["save","Save adventure",2,KEY_F5,0],
	["slot1","Pokemon slot 1",1,KEY_1,0], ["slot2","Pokemon slot 2",1,KEY_2,0],
	["slot3","Pokemon slot 3",1,KEY_3,0], ["slot4","Pokemon slot 4",1,KEY_4,0],
	["slot5","Pokemon slot 5",1,KEY_5,0], ["slot6","Pokemon slot 6",1,KEY_6,0]
]
var gamepad
var bindings = {}
var capturing = ""
var capture_slot = 0
var callback: Callable
var persistent = false
var run_toggle = true
var run_active = false
const RUN_SAVE = "user://run-settings.json"

func install():
	reset_defaults(false)
	persistent = OS.get_cmdline_user_args().is_empty()
	if persistent and FileAccess.file_exists(SAVE):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		load_bindings(data)
	if persistent and FileAccess.file_exists(RUN_SAVE):
		var run_data=JSON.parse_string(FileAccess.get_file_as_string(RUN_SAVE))
		if run_data is Dictionary and run_data.get("toggle") is bool: run_toggle=run_data.toggle

func valid_code(code: int) -> bool:
	return code != KEY_ESCAPE and (code==0 or code in [-1,-2,-3,-8,-9] or (code>=32 and code<0x800000))

func reset_defaults(write=true):
	bindings.clear()
	for def in DEFINITIONS: bindings[def[0]]=[def[3],def[4]]
	if write:
		save()
		set_run_toggle(true)

func save(path: String = SAVE) -> bool:
	if not persistent: return true
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(bindings))
	return true

func assign(action: String, slot: int, code: int, write=true) -> String:
	if not valid_code(code): return "Use a keyboard key or mouse button. Esc is reserved."
	var context=0
	for def in DEFINITIONS:
		if def[0]==action: context=def[2]
	if code!=0:
		for def in DEFINITIONS:
			if (int(def[2]) & context)==0: continue
			for i in range(2):
				if def[0]==action and i==slot: continue
				if bindings[def[0]][i]==code: return "Already used by " + def[1] + ". Clear that binding first."
	bindings[action][slot]=code
	if write and not save(): return "Applied, but could not save controls to disk."
	return ""

func code_of(event) -> int:
	if event is InputEventKey: return event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if event is InputEventMouseButton: return -event.button_index
	return 0

func matches(event, action: String) -> bool:
	if event.has_meta("controller_action"): return event.pressed and event.get_meta("controller_action")==action
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.pressed: return false
	if event is InputEventKey and event.echo: return false
	var code=code_of(event)
	return code!=0 and code in bindings[action]

func held(action: String) -> bool:
	if action=="sprint" and run_toggle: return run_active
	if action=="sprint" and gamepad!=null and gamepad.sprint_held(): return true
	for code in bindings[action]:
		if code>0 and Input.is_physical_key_pressed(code): return true
		if code<0 and Input.is_mouse_button_pressed(-code): return true
	return false

func set_run_toggle(enabled: bool):
	run_toggle=enabled; run_active=false
	if persistent:
		var file=FileAccess.open(RUN_SAVE,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify({"toggle":run_toggle}))

func handle_run(event):
	if run_toggle and matches(event,"sprint"): run_active=not run_active

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: run_active=false

func key_name(code: int) -> String:
	if code==0: return "Unbound"
	if code<0: return {-1:"LMB",-2:"RMB",-3:"MMB",-8:"Mouse 4",-9:"Mouse 5"}.get(code,"Mouse")
	return OS.get_keycode_string(code)

func text(action: String) -> String:
	var names=[]
	for code in bindings[action]:
		if code!=0: names.append(key_name(code))
	return " / ".join(names) if not names.is_empty() else "Unbound"

func _input(event):
	if capturing=="": return
	if not (event is InputEventKey or event is InputEventMouseButton): return
	get_viewport().set_input_as_handled()
	if not event.pressed or (event is InputEventKey and event.echo): return
	if event is InputEventKey and event.keycode==KEY_ESCAPE:
		capturing=""
		callback.call("")
		return
	var code=0 if event is InputEventKey and event.keycode==KEY_BACKSPACE else code_of(event)
	var error=assign(capturing,capture_slot,code)
	if error=="": capturing=""
	callback.call(error)

func tests(c):
	var original=bindings.duplicate(true)
	var old_toggle=run_toggle; var old_active=run_active
	run_toggle=true; run_active=false
	var run_event=InputEventKey.new(); run_event.physical_keycode=bindings.sprint[0]; run_event.pressed=true
	handle_run(run_event); c.check(held("sprint"),"Toggle run starts on first press")
	run_event.echo=true; handle_run(run_event); c.check(held("sprint"),"Held key repeat does not toggle run")
	run_event.echo=false; run_event.pressed=false; handle_run(run_event); c.check(held("sprint"),"Toggle run survives release")
	run_event.pressed=true; handle_run(run_event); c.check(not held("sprint"),"Second press stops toggle run")
	run_toggle=false; handle_run(run_event); c.check(not run_active,"Hold mode does not latch run")
	run_toggle=old_toggle; run_active=old_active
	reset_defaults(false)
	var event=InputEventKey.new()
	event.physical_keycode=KEY_Q
	event.pressed=true
	c.check(matches(event,"move1"),"Default attack binding")
	c.check(assign("move1",0,KEY_Z,false)=="","Rebind attack")
	c.check(not matches(event,"move1"),"Old key stops triggering action")
	event.physical_keycode=KEY_Z
	c.check(matches(event,"move1"),"New key triggers attack")
	c.check(assign("move2",0,KEY_Z,false)!="","Same-context duplicate rejected")
	c.check(assign("interact",0,KEY_Z,false)=="","Battle and world bindings can share a key")
	c.check(assign("move2",0,KEY_ESCAPE,false)!="","Escape stays available to close dialogs")
	c.check(assign("move1",1,-3,false)=="","Mouse binding supported")
	var mouse=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_MIDDLE
	mouse.pressed=true
	c.check(matches(mouse,"move1"),"Mouse action matching")
	reset_defaults(false)
	c.check(bindings.move1==[KEY_Q,-1],"Restore includes primary and alternate defaults")
	c.check(bindings.sprint==[KEY_E,0] and bindings.move2==[KEY_SPACE,0] and bindings.interact==[KEY_SPACE,0],"Restore defaults swaps E and Space for running, attack 2 and interaction")
	var saved=bindings.duplicate(true)
	saved.up=[KEY_Z,KEY_UP]
	saved.move1=[KEY_W,-1]
	load_bindings(JSON.parse_string(JSON.stringify(saved)))
	c.check(bindings.up[0]==KEY_Z and bindings.move1[0]==KEY_W,"Saved key swaps load together without default conflicts")
	var invalid=saved.duplicate(true)
	invalid.move2=[KEY_W,0]
	load_bindings(invalid)
	c.check(bindings==saved,"Invalid saved conflicts leave current controls intact")
	var was_persistent=persistent
	persistent=true
	var test_path="user://controls-regression-test.json"
	c.check(save(test_path),"Controls save to disk")
	reset_defaults(false)
	load_bindings(JSON.parse_string(FileAccess.get_file_as_string(test_path)))
	c.check(bindings==saved,"Controls survive a disk save/load round trip")
	DirAccess.remove_absolute(test_path)
	persistent=was_persistent
	bindings=original

func load_bindings(data):
	if not data is Dictionary: return
	var original=bindings.duplicate(true)
	for def in DEFINITIONS:
		var pair=data.get(def[0],[])
		if not pair is Array or pair.size()!=2: return
		for code in pair:
			if not (code is float or code is int) or float(code)!=int(code) or not valid_code(int(code)): return
	# Validate the complete candidate, not against temporary default conflicts.
	for def in DEFINITIONS: bindings[def[0]]=[int(data[def[0]][0]),int(data[def[0]][1])]
	for def in DEFINITIONS:
		for slot in range(2):
			if assign(def[0],slot,bindings[def[0]][slot],false)!="":
				bindings=original
				return
