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
	button("QUIT",Rect2(520,800,240,50),c.get_tree().quit)

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
