extends RefCounted

var c
var layer: CanvasLayer

func install(context):
	c = context
	layer = CanvasLayer.new()
	layer.layer = 60
	c.add_child(layer)
	layer.visible = false
	if OS.get_cmdline_user_args().is_empty(): show_title()

func label(value,at,size=24,color=Color("e7eee2")):
	var item = Label.new()
	item.text = value
	item.position = at
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",color)
	layer.add_child(item)

func button(value,rect,action):
	var item = Button.new()
	item.text = value
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_size_override("font_size",24)
	item.pressed.connect(action)
	layer.add_child(item)

func portrait(id,rect):
	var item = TextureRect.new()
	item.texture = c.portraits[id]
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.position = rect.position
	item.size = rect.size
	layer.add_child(item)

func background():
	c.audio.preview_music=false
	for child in layer.get_children(): child.queue_free()
	c.campaign.layer.visible = false
	c.selection_controls.visible = false
	c.selecting = true
	c.paused = false
	layer.visible = true
	var bg = ColorRect.new()
	bg.color = Color("0b1726")
	bg.size = Vector2(1280,960)
	layer.add_child(bg)
	for i in range(9):
		var stripe = ColorRect.new()
		stripe.position = Vector2(0,105+i*100)
		stripe.size = Vector2(1280,2)
		stripe.color = Color("193747")
		layer.add_child(stripe)

func show_title():
	background()
	label("POKEMON",Vector2(365,145),76,Color("f9d86b"))
	label("ARENA ADVENTURES",Vector2(350,240),42)
	label("YOUR JOURNEY. YOUR TEAM. REAL-TIME BATTLES.",Vector2(320,320),20,Color("77e2b0"))
	portrait(6,Rect2(155,395,245,245))
	portrait(25,Rect2(520,380,240,240))
	portrait(9,Rect2(880,395,245,245))
	button("PLAY",Rect2(440,690,400,80),show_modes)
	button("INSTRUCTIONS",Rect2(330,790,300,55),show_instructions)
	button("SETTINGS",Rect2(650,790,300,55),show_settings)
	button("QUIT",Rect2(520,875,240,45),c.get_tree().quit)

func show_modes():
	background()
	label("CHOOSE YOUR MODE",Vector2(330,115),46,Color("f9d86b"))
	var names = ["Adventure","Gym Leaders","Free Battles"]
	var descriptions = ["Explore Kanto, catch Pokemon,\ngain XP and earn badges.\nYour adventure autosaves.","Challenge the eight gyms,\nElite Four and Champion.\nSeparate saved progression.","Choose Pokemon and trainers,\ncustomize teams and arenas.\nPractice without progression."]
	for i in range(3):
		var x = 65+i*390
		var card = ColorRect.new()
		card.position = Vector2(x,245)
		card.size = Vector2(370,490)
		card.color = Color("18313e")
		layer.add_child(card)
		portrait([1,95,94][i],Rect2(x+80,275,210,210))
		label(descriptions[i],Vector2(x+25,510),19)
		button(names[i],Rect2(x+25,640,320,65),choose.bind(i))
	button("BACK",Rect2(490,805,300,55),show_title)

func choose(mode):
	layer.visible = false
	match mode:
		0: c.adventure.enter()
		1: c.campaign.show_hub()
		2: c.campaign.free_battle()

func show_instructions():
	background()
	label("HOW TO PLAY",Vector2(430,65),42,Color("f9d86b"))
	var sections=[
		["ADVENTURE", "Walk through doors automatically. Trainers spot you and approach to battle.\nPress your interact key in grass, water or caves to seek a wild Pokemon.\nChoose a starter, earn eight badges and become Champion. Your journey autosaves."],
		["GYM LEADERS", "Challenge the eight Kanto Gym Leaders, Elite Four and Blue.\nBuild your team and choose its moves. League progress saves separately\nfrom Adventure."],
		["FREE BATTLES", "Choose Pokemon, moves, opponents and arenas for practice matches.\nExperiment with team combinations without changing Adventure progress."],
		["REAL-TIME COMBAT", "Aim with the mouse. Use four moves, sprint and switch Pokemon.\nMoves have energy costs and cooldowns: normally 1 second between attacks.\nAfter casting, walking/sprint pauses for 0.4 seconds. Sprint gives no invulnerability.\nHoming attacks can chase for 3 seconds: sprint sideways to evade them."],
		["CONTROLS", "Settings lets you change keyboard and mouse bindings, with two slots per action.\nClick a binding, then press the new key. Backspace clears it; Esc cancels.\nEsc pauses/closes menus. Menu navigation and roster browsing use their shown controls."]
	]
	var y=145
	for section in sections:
		label(section[0],Vector2(100,y),24,Color("77e2b0"))
		label(section[1],Vector2(100,y+38),19)
		y+=155 if section[0]=="REAL-TIME COMBAT" else 140
	button("BACK",Rect2(490,875,300,50),show_title)

func show_settings():
	background()
	label("SETTINGS",Vector2(465,50),42,Color("f9d86b"))
	label("Click a key, then press its replacement. Settings save automatically.",Vector2(220,110),20)
	label("Esc: cancel   /   Backspace: clear   /   Conflicting keys in the same mode are rejected.",Vector2(160,145),18,Color("77e2b0"))
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(165,195)
	scroll.size=Vector2(950,450)
	layer.add_child(scroll)
	var grid=GridContainer.new()
	grid.columns=4
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	for heading in ["Action","Mode","Primary","Alternate"]:
		var title=Label.new()
		title.text=heading
		grid.add_child(title)
	for def in c.controls.DEFINITIONS:
		var name_label=Label.new()
		name_label.text=def[1]
		name_label.custom_minimum_size=Vector2(270,43)
		name_label.add_theme_font_size_override("font_size",20)
		grid.add_child(name_label)
		var context=Label.new()
		context.text={1:"Battle",2:"Adventure",3:"Both"}[def[2]]
		context.custom_minimum_size=Vector2(120,43)
		grid.add_child(context)
		for slot in range(2):
			var key=Button.new()
			key.text=c.controls.key_name(c.controls.bindings[def[0]][slot])
			key.custom_minimum_size=Vector2(225,43)
			key.pressed.connect(capture_key.bind(def[0],slot,def[1],key))
			grid.add_child(key)
	var running=OptionButton.new(); running.position=Vector2(180,655); running.size=Vector2(500,40)
	running.add_item("RUN: Hold key"); running.add_item("RUN: Toggle on / off")
	running.selected=1 if c.controls.run_toggle else 0
	running.item_selected.connect(func(index): c.controls.set_run_toggle(index==1)); layer.add_child(running)
	audio_slider("MASTER",Vector2(180,710),c.audio.volume,c.audio.set_volume)
	audio_slider("POKEMON CRIES",Vector2(180,750),c.audio.cry_volume,c.audio.set_cry_volume)
	audio_slider("MUSIC",Vector2(180,790),c.audio.music_volume,c.audio.set_music_volume)
	button("PREVIEW MUSIC",Rect2(730,790,330,35),func(): c.audio.preview_music=not c.audio.preview_music)
	button("PREVIEW CRY",Rect2(730,750,330,35),func(): c.audio.cry(25))
	var mode=OptionButton.new(); mode.position=Vector2(730,705); mode.size=Vector2(330,40)
	for value in c.difficulty.NAMES: mode.add_item("DIFFICULTY: "+value)
	mode.selected=c.difficulty.level; mode.item_selected.connect(c.difficulty.choose); layer.add_child(mode)
	button("RESTORE DEFAULTS",Rect2(290,845,350,60),func(): c.controls.reset_defaults(); c.audio.set_volume(c.audio.DEFAULT_VOLUME); c.audio.set_cry_volume(c.audio.DEFAULT_CRY_VOLUME); c.audio.set_music_volume(c.audio.DEFAULT_MUSIC_VOLUME); c.difficulty.choose(1); show_settings())
	button("BACK",Rect2(675,845,250,60),show_title)

func audio_slider(title,pos,value,callback):
	label(title,pos,18)
	var slider=HSlider.new(); slider.min_value=0; slider.max_value=1; slider.step=0.05
	slider.value=value; slider.position=pos+Vector2(190,2); slider.size=Vector2(250,25); layer.add_child(slider)
	var percent=Label.new(); percent.position=pos+Vector2(455,0); percent.text=str(roundi(value*100))+"%"; layer.add_child(percent)
	slider.value_changed.connect(func(amount): callback.call(amount); percent.text=str(roundi(amount*100))+"%")

func capture_key(action,slot,title,key_button):
	var shade=ColorRect.new()
	shade.color=Color(0,0,0,0.8)
	shade.size=Vector2(1280,960)
	layer.add_child(shade)
	var box=Panel.new()
	box.position=Vector2(290,330)
	box.size=Vector2(700,260)
	var style=StyleBoxFlat.new()
	style.bg_color=Color("142b3b")
	style.border_color=Color("77e2b0")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	box.add_theme_stylebox_override("panel",style)
	shade.add_child(box)
	var message=Label.new()
	message.position=Vector2(25,30)
	message.size=Vector2(650,210)
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size",23)
	message.text="Bind: "+title+"\n\nPress a keyboard key or mouse button.\nEsc cancels / Backspace clears"
	box.add_child(message)
	c.controls.capturing=action
	c.controls.capture_slot=slot
	c.controls.callback=func(error):
		if error!="":
			message.text=error+"\n\nTry another key. Esc cancels."
		else:
			key_button.text=c.controls.key_name(c.controls.bindings[action][slot])
			shade.queue_free()
