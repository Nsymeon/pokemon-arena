extends Node2D

const SETTINGS="user://controller-settings.json"
const DEADZONE=0.22
var c
var active=false
var enabled=true
var device=0
var deadzone=DEADZONE
var cursor_speed=900.0
var emitting=false
var keyboard_layer: CanvasLayer
var keyboard_target: LineEdit
var keyboard_text: Label
var keyboard_draft=""
var keyboard_lower=false
var pointer: Node2D
var pointer_layer: CanvasLayer
var pointer_position=Vector2(640,480)

func install(context):
	c=context
	pointer_layer=CanvasLayer.new(); pointer_layer.layer=110; add_child(pointer_layer)
	pointer=Node2D.new(); pointer_layer.add_child(pointer); pointer.draw.connect(draw_pointer)
	if OS.get_cmdline_user_args().is_empty() and FileAccess.file_exists(SETTINGS):
		var value=JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if value is Dictionary:
			enabled=bool(value.get("enabled",true))
			if value.get("deadzone") is float: deadzone=clampf(value.deadzone,0.1,0.5)
			if value.get("cursor_speed") is float or value.get("cursor_speed") is int: cursor_speed=clampf(value.cursor_speed,300,1600)
	Input.joy_connection_changed.connect(connection_changed)

func connection_changed(id,connected):
	if not connected and device==id:
		active=false; c.controls.run_active=false

func save_settings():
	if not OS.get_cmdline_user_args().is_empty(): return
	var file=FileAccess.open(SETTINGS,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"enabled":enabled,"deadzone":deadzone,"cursor_speed":cursor_speed}))

func reset_defaults():
	enabled=true; deadzone=DEADZONE; cursor_speed=900; active=false; save_settings()

func stick(x,y) -> Vector2:
	var value=Vector2(Input.get_joy_axis(device,x),Input.get_joy_axis(device,y))
	return filtered(value)

func filtered(value: Vector2) -> Vector2:
	if value.length()<=deadzone: return Vector2.ZERO
	return value.normalized()*clampf((value.length()-deadzone)/(1.0-deadzone),0,1)

func ui_mode() -> bool:
	return is_instance_valid(keyboard_layer) or c.frontend.layer.visible or c.campaign.layer.visible or c.adventure.modal!="" or c.selecting and not c.adventure.exploring or c.switch_menu or c.paused or (is_instance_valid(c.ivs.window) and c.ivs.window.visible)

func movement() -> Vector2:
	if not enabled or not active or ui_mode(): return Vector2.ZERO
	var value=stick(JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y)
	value+=Vector2(float(Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_RIGHT))-float(Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_LEFT)),float(Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_DOWN))-float(Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_UP)))
	return value.limit_length()

func sprint_held() -> bool:
	return enabled and active and Input.is_joy_button_pressed(device,JOY_BUTTON_RIGHT_SHOULDER)

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and c!=null:
		active=false; c.controls.run_active=false

func _input(event):
	if c==null or emitting or not enabled: return
	if event is InputEventKey or event is InputEventMouseButton:
		active=false
		return
	if event is InputEventMouseMotion:
		if event.relative.length()>2 and event.position.distance_to(pointer_position)>3: active=false
		return
	if event is InputEventJoypadMotion:
		if absf(event.axis_value)>deadzone:
			active=true; device=event.device
		return
	if not event is InputEventJoypadButton: return
	active=true; device=event.device
	get_viewport().set_input_as_handled()
	if event.pressed: press(event.button_index)

func action_for(button,exploring) -> String:
	if exploring:
		return {JOY_BUTTON_A:"interact",JOY_BUTTON_X:"party",JOY_BUTTON_Y:"map",JOY_BUTTON_BACK:"bag",JOY_BUTTON_RIGHT_SHOULDER:"sprint",JOY_BUTTON_LEFT_SHOULDER:"save"}.get(button,"")
	return {JOY_BUTTON_A:"move1",JOY_BUTTON_B:"move2",JOY_BUTTON_X:"move3",JOY_BUTTON_Y:"move4",JOY_BUTTON_LEFT_SHOULDER:"switch",JOY_BUTTON_RIGHT_SHOULDER:"sprint",JOY_BUTTON_BACK:"bag"}.get(button,"")

func press(button):
	if is_instance_valid(keyboard_layer):
		if button==JOY_BUTTON_A: click(MOUSE_BUTTON_LEFT)
		elif button in [JOY_BUTTON_B,JOY_BUTTON_START]: close_keyboard(false)
		return
	if button in [JOY_BUTTON_B,JOY_BUTTON_START] and is_instance_valid(c.ivs.window) and c.ivs.window.visible:
		c.ivs.window.hide(); return
	if button==JOY_BUTTON_START:
		if c.frontend.layer.visible: back_frontend()
		else: emit_key(KEY_ESCAPE)
		return
	if ui_mode():
		if button==JOY_BUTTON_Y:
			var field=get_viewport().gui_get_focus_owner()
			if field is LineEdit: open_keyboard(field)
			return
		if button==JOY_BUTTON_A: click(MOUSE_BUTTON_LEFT)
		elif button==JOY_BUTTON_B:
			if c.frontend.layer.visible: back_frontend()
			else: emit_key(KEY_ESCAPE)
		elif button==JOY_BUTTON_DPAD_UP: click(MOUSE_BUTTON_WHEEL_UP)
		elif button==JOY_BUTTON_DPAD_DOWN: click(MOUSE_BUTTON_WHEEL_DOWN)
		elif button==JOY_BUTTON_DPAD_LEFT: emit_key(KEY_LEFT)
		elif button==JOY_BUTTON_DPAD_RIGHT: emit_key(KEY_RIGHT)
		return
	if c.result!="" and not c.adventure.exploring:
		if button==JOY_BUTTON_A: emit_key(KEY_ENTER) if c.adventure.in_battle else emit_action("restart")
		elif button==JOY_BUTTON_B: emit_action("roster")
		return
	if c.adventure.exploring and button==JOY_BUTTON_B: emit_key(KEY_ESCAPE); return
	var action=action_for(button,c.adventure.exploring)
	if action!="": emit_action(action)

func back_frontend():
	match c.frontend.page:
		"slots": c.frontend.show_modes()
		"controller", "graphics": c.frontend.show_settings()
		"title": pass
		_: c.frontend.show_title()

func emit_action(action):
	# Metadata keeps gamepad actions independent from customized/unbound keyboard bindings.
	emitting=true
	for down in [true,false]:
		var event=InputEventKey.new(); event.keycode=KEY_F24; event.physical_keycode=KEY_F24; event.pressed=down
		event.set_meta("controller_action",action); Input.parse_input_event(event)
	emitting=false

func emit_key(key):
	emitting=true
	for down in [true,false]:
		var event=InputEventKey.new(); event.keycode=key; event.physical_keycode=key; event.pressed=down; Input.parse_input_event(event)
	emitting=false

func click(button):
	emitting=true
	for down in [true,false]:
		var event=InputEventMouseButton.new(); event.button_index=button; event.position=get_viewport().get_mouse_position(); event.global_position=event.position; event.pressed=down; event.factor=1; get_viewport().push_input(event,true)
	emitting=false

func _process(dt):
	if c==null or pointer==null: return
	pointer.visible=enabled and active
	if not enabled or not active: return
	var direction=stick(JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y)
	if ui_mode(): direction+=stick(JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y)
	if direction.length()>0:
		pointer_position=(get_viewport().get_mouse_position()+direction.limit_length()*cursor_speed*minf(dt,0.05)).clamp(Vector2(5,5),Vector2(1275,955))
		emitting=true; get_viewport().warp_mouse(pointer_position); emitting=false
	else: pointer_position=get_viewport().get_mouse_position()
	pointer.queue_redraw()

func draw_pointer():
	if not active: return
	pointer.draw_circle(pointer_position,9,Color(0,0,0,0.7))
	pointer.draw_arc(pointer_position,9,0,TAU,24,Color("f9d86b"),2,true)
	pointer.draw_line(pointer_position-Vector2(14,0),pointer_position+Vector2(14,0),Color.WHITE,1)
	pointer.draw_line(pointer_position-Vector2(0,14),pointer_position+Vector2(0,14),Color.WHITE,1)

func show_settings():
	c.frontend.background(); c.frontend.page="controller"
	c.frontend.label("CONTROLLER",Vector2(425,80),42,Color("f9d86b"))
	var connected=Input.get_connected_joypads()
	c.frontend.label("No controller connected" if connected.is_empty() else "Connected: "+Input.get_joy_name(connected[0]),Vector2(180,150),22)
	var toggle=CheckButton.new(); toggle.position=Vector2(180,220); toggle.text="Enable controller"; toggle.button_pressed=enabled
	toggle.toggled.connect(func(value): enabled=value; active=false; save_settings()); c.frontend.layer.add_child(toggle)
	setting_slider("STICK DEADZONE",Vector2(180,290),0.1,0.5,0.01,deadzone,func(value): deadzone=value; save_settings())
	setting_slider("CURSOR SPEED",Vector2(180,350),300,1600,50,cursor_speed,func(value): cursor_speed=value; save_settings())
	c.frontend.label("Left stick / D-pad: move  |  Right stick: aim / pointer\nMenus: either stick moves pointer, A / Cross: click\nY / Triangle: keyboard for a selected text field\nD-pad up/down: scroll  |  left/right: adjust focused slider\nA/B/X/Y (Cross/Circle/Square/Triangle): battle moves 1-4\nRB / R1: run toggle  |  LB / L1: switch Pokemon (save on map)\nView / Share: Bag (capture and Run / Flee are in the Bag)\nAdventure: A / Cross: talk, X / Square: team, Y / Triangle: map\nStart / Options: pause  |  B / Circle: back in menus\nBattle result: A / Cross: continue",Vector2(180,430),21)
	c.frontend.button("RESTORE DEFAULTS",Rect2(240,850,380,60),func(): reset_defaults(); show_settings())
	c.frontend.button("BACK",Rect2(680,850,300,60),c.frontend.show_settings)

func open_keyboard(field: LineEdit):
	if not is_instance_valid(field) or not field.editable: return
	keyboard_target=field; keyboard_draft=field.text; keyboard_lower=false
	keyboard_layer=CanvasLayer.new(); keyboard_layer.layer=105; add_child(keyboard_layer)
	var shade=ColorRect.new(); shade.color=Color(0.02,0.04,0.08,0.98); shade.size=Vector2(1280,960); keyboard_layer.add_child(shade)
	keyboard_text=Label.new(); keyboard_text.position=Vector2(180,190); keyboard_text.size=Vector2(920,70); keyboard_text.text=keyboard_draft; keyboard_text.add_theme_font_size_override("font_size",30); keyboard_layer.add_child(keyboard_text)
	var chars="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-'"
	for i in range(chars.length()):
		var letter=chars[i]
		keyboard_button(letter,Rect2(180+(i%10)*92,300+(i/10)*80,85,65),func(): type_letter(letter))
	keyboard_button("Aa",Rect2(180,650,150,65),func(): keyboard_lower=not keyboard_lower)
	keyboard_button("SPACE",Rect2(340,650,175,65),func(): type_letter(" "))
	keyboard_button("BACKSPACE",Rect2(525,650,220,65),func(): keyboard_draft=keyboard_draft.left(maxi(0,keyboard_draft.length()-1)); keyboard_text.text=keyboard_draft)
	keyboard_button("DONE",Rect2(755,650,150,65),func(): close_keyboard(true))
	keyboard_button("CANCEL",Rect2(915,650,185,65),func(): close_keyboard(false))

func keyboard_button(text,rect,callback):
	var button=Button.new(); button.text=text; button.position=rect.position; button.size=rect.size
	button.add_theme_font_size_override("font_size",22); button.pressed.connect(callback); keyboard_layer.add_child(button)

func type_letter(letter):
	if not is_instance_valid(keyboard_target): close_keyboard(false); return
	if keyboard_target.max_length>0 and keyboard_draft.length()>=keyboard_target.max_length: return
	keyboard_draft+=letter.to_lower() if keyboard_lower else letter
	keyboard_text.text=keyboard_draft

func close_keyboard(apply):
	if apply and is_instance_valid(keyboard_target):
		keyboard_target.text=keyboard_draft; keyboard_target.text_changed.emit(keyboard_draft)
	if is_instance_valid(keyboard_layer): keyboard_layer.queue_free()
	keyboard_layer=null; keyboard_target=null

func setting_slider(title,pos,minimum,maximum,step,value,callback):
	c.frontend.label(title,pos,20)
	var slider=HSlider.new(); slider.min_value=minimum; slider.max_value=maximum; slider.step=step; slider.value=value
	slider.position=pos+Vector2(250,0); slider.size=Vector2(420,30); c.frontend.layer.add_child(slider)
	var label=Label.new(); label.position=pos+Vector2(700,0); c.frontend.layer.add_child(label)
	var refresh=func(amount): label.text=(str(roundi(amount*100))+"%") if maximum<1 else str(roundi(amount))+" px/s"
	refresh.call(value); slider.value_changed.connect(func(amount): refresh.call(amount); callback.call(amount))

func tests():
	c.check(filtered(Vector2(0.1,0.1))==Vector2.ZERO,"Gamepad deadzone rejects stick drift")
	c.check(filtered(Vector2.RIGHT)==Vector2.RIGHT,"Gamepad full stick retains direction")
	c.check(action_for(JOY_BUTTON_A,true)=="interact" and action_for(JOY_BUTTON_A,false)=="move1","Gamepad A changes between interaction and battle")
	c.check(action_for(JOY_BUTTON_LEFT_SHOULDER,true)=="save" and action_for(JOY_BUTTON_LEFT_SHOULDER,false)=="switch","Gamepad shoulder actions respect gameplay context")
	var event=InputEventKey.new(); event.pressed=true; event.set_meta("controller_action","move1")
	c.check(c.controls.matches(event,"move1") and not c.controls.matches(event,"move2"),"Gamepad actions work independently of keyboard bindings")
