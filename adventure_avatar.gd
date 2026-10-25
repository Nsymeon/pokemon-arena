extends RefCounted

const DEFAULT = {"gender":"boy","shirt":"e65050","shoes":"eeeeee","hair":"684638","pants":"477ba8"}
const PARTS = ["shirt","shoes","hair","pants"]
var cache = {}
var draft = {}
var previews = []
var a

func valid(value) -> bool:
	if not value is Dictionary or value.get("gender") not in ["boy","girl"]: return false
	for part in PARTS:
		var color = value.get(part)
		if not color is String or color.length()!=6 or not Color.html_is_valid(color): return false
	return true

func texture(config: Dictionary, battle: bool=false, flipped: bool=false) -> Texture2D:
	var key = str(battle)+str(flipped)+JSON.stringify(config)
	if cache.has(key): return cache[key]
	var gender = config.get("gender","boy")
	var source = ("res://assets/trainers/red.png" if gender=="boy" else "res://assets/avatar/girl-battle.png") if battle else "res://assets/kanto/actors/"+("red" if gender=="boy" else "green")+"_normal.png"
	var pixels = Image.load_from_file(source)
	var mask = Image.load_from_file("res://assets/avatar/"+gender+("-battle" if battle else "-world")+"-mask.png")
	for y in pixels.get_height():
		for x in pixels.get_width():
			var region = mask.get_pixel(x,y)
			if region.a==0: continue
			var color = Color.html(config.get(PARTS[region.r8-1],DEFAULT[PARTS[region.r8-1]]))
			var shade = region.g8/180.0
			pixels.set_pixel(x,y,Color(clampf(color.r*shade,0,1),clampf(color.g*shade,0,1),clampf(color.b*shade,0,1),pixels.get_pixel(x,y).a))
	if flipped: pixels.flip_x()
	var result = ImageTexture.create_from_image(pixels)
	# Color pickers emit continuously; retain only a small working set.
	if cache.size()>24: cache.clear()
	cache[key] = result
	return result

func config() -> Dictionary:
	return a.data.get("avatar",DEFAULT)

func show_creator(context):
	a = context
	draft = config().duplicate(true)
	a.world.scenes.reset()
	a.dialog = ""
	a.panel("CREATE YOUR TRAINER")
	# This screen must be completed or explicitly left; ordinary modal close would bypass it.
	for child in a.ui.get_children():
		if child is Button: child.queue_free()
	a.ui_label("Choose your look. It follows you across Kanto and into every battle.",Vector2(180,220),20)
	a.ui_button("BOY",Vector2(180,275),Vector2(180,48),set_gender.bind("boy"))
	a.ui_button("GIRL",Vector2(380,275),Vector2(180,48),set_gender.bind("girl"))
	for i in PARTS.size():
		var part = PARTS[i]
		a.ui_label(part.capitalize(),Vector2(180,358+i*70),22)
		var picker = ColorPickerButton.new()
		picker.position = Vector2(365,350+i*70)
		picker.size = Vector2(195,48)
		picker.set_meta("part",part)
		picker.edit_alpha = false
		picker.color = Color.html(draft[part])
		picker.color_changed.connect(change_color.bind(part))
		a.ui.add_child(picker)
	a.ui_label("MAP / FRONT, BACK, SIDE",Vector2(650,282),18)
	previews.clear()
	for i in range(3):
		var view = TextureRect.new()
		view.position = Vector2(685+i*105,315)
		view.size = Vector2(80,160)
		view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		a.ui.add_child(view)
		previews.append(view)
	var portrait = TextureRect.new()
	portrait.position = Vector2(730,480)
	portrait.size = Vector2(240,240)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.ui.add_child(portrait)
	previews.append(portrait)
	a.ui_button("BACK TO MENU",Vector2(180,755),Vector2(220,45),a.leave)
	a.ui_button("SAVE & START ADVENTURE",Vector2(650,755),Vector2(440,45),confirm)
	refresh()

func set_gender(gender):
	draft.gender = gender
	refresh()

func change_color(color: Color, part: String):
	draft[part] = color.to_html(false)
	refresh()

func refresh():
	for i in range(3):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture(draft)
		atlas.region = Rect2(i*16,0,16,32)
		previews[i].texture = atlas
	var portrait = AtlasTexture.new()
	portrait.atlas = texture(draft,true)
	portrait.region = portrait.atlas.get_image().get_used_rect()
	previews[3].texture = portrait
	for child in a.ui.get_children():
		if child is ColorPickerButton: child.color=Color.html(draft[child.get_meta("part")])
		if child is Button and child.text in ["BOY","GIRL"]:
			child.modulate = Color("83efbb") if child.text.to_lower()==draft.gender else Color.WHITE

func confirm():
	var previous = a.data.get("avatar")
	a.data["avatar"] = draft.duplicate(true)
	if not a.save():
		if previous==null: a.data.erase("avatar")
		else: a.data.avatar = previous
		a.ui_label("Could not save. Check storage and try again.",Vector2(180,705),18)
		return
	a.clear_ui()
	previews.clear()
	a.world.scenes.entrance()

func tests(context):
	a = context
	a.c.check(valid(DEFAULT) and not valid({"gender":"other"}),"Avatar validates profile")
	var bad = DEFAULT.duplicate(); bad.hair = "invalid"
	a.c.check(not valid(bad),"Avatar rejects malformed colors")
	for gender in ["boy","girl"]:
		var profile = DEFAULT.duplicate(); profile.gender = gender
		for battle in [false,true]:
			var original = texture(profile,battle).get_image()
			for part in PARTS:
				var changed = profile.duplicate(); changed[part] = "00ff00"
				a.c.check(texture(changed,battle).get_image().get_data()!=original.get_data(),"Avatar "+gender+" "+part+" changes "+str(battle))
	a.c.check(valid(JSON.parse_string(JSON.stringify(DEFAULT))),"Avatar JSON round trip")

	var previous = a.data.duplicate(true)
	var previous_path = a.save_path
	var previous_allowed = a.save_allowed
	var previous_error = a.save_error
	var previous_loaded = a.loaded
	var previous_position = a.position_world
	a.save_path = "user://avatar-regression.json"
	a.save_allowed = true
	a.data = a.INITIAL_DATA.duplicate(true)
	a.inventory.migrate()
	a.position_world = Vector2(a.data.x,a.data.y)
	show_creator(a)
	set_gender("girl")
	change_color(Color("31b875"),"shirt")
	var escape = InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	a.handle_input(escape)
	a.c.check(a.modal=="CREATE YOUR TRAINER" and not a.data.has("avatar"),"Creator cannot be bypassed by Escape")
	confirm()
	a.c.check(a.modal=="" and a.data.avatar==draft,"Creator confirms and saves chosen colors")
	a.data.erase("avatar")
	a.load_save()
	a.c.check(a.data.avatar.gender=="girl" and a.data.avatar.shirt=="31b875","Avatar persists after loading save")
	a.data.erase("avatar")
	a.c.check(a.valid(a.data),"Existing saves without avatars remain valid")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(a.save_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(a.save_path+suffix))
	a.world.scenes.reset()
	a.data=previous; a.save_path=previous_path; a.save_allowed=previous_allowed; a.save_error=previous_error; a.loaded=previous_loaded; a.position_world=previous_position
