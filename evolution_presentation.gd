extends Node2D
# Presentation only: the saved individual and learned moves stay authoritative.
var a
var pair=[]
var pictures=[]
var age=0.0
var revealed=false
var continue_button: Button
const REVEAL=5.3
const FINISH=7.4

func setup(adventure, evolution: Array):
	a=adventure; pair=evolution.duplicate()
	for id in pair.slice(0,2): pictures.append(trimmed(a.collection.full_picture({"id":id,"shiny":pair[2] if pair.size()>2 else false})))
	continue_button=Button.new(); continue_button.text="CONTINUE  /  Space"; continue_button.position=Vector2(480,774); continue_button.size=Vector2(320,52)
	continue_button.pressed.connect(a.next_evolution); continue_button.visible=false; add_child(continue_button)
	a.c.audio.cry(int(pair[0]))

static func trimmed(texture: Texture2D) -> Texture2D:
	var pixels=texture.get_image(); var used=pixels.get_used_rect()
	return ImageTexture.create_from_image(pixels.get_region(used)) if used.has_area() else texture

func _process(dt):
	age=minf(FINISH,age+dt)
	if age>=REVEAL and not revealed: revealed=true; a.c.audio.cry(int(pair[1]))
	continue_button.visible=age>=FINISH
	queue_redraw()

func advance():
	if age<FINISH: age=FINISH; _process(0)
	else: a.next_evolution()

func picture(index: int, size_value: float, color: Color):
	var texture=pictures[index]
	var size=texture.get_size(); size*=size_value/maxf(size.x,size.y)
	draw_texture_rect(texture,Rect2(Vector2(640,390)-size*.5,size),false,color)

func words(value: String, y: float, size: int, color=Color("f3f3df")):
	var font=ThemeDB.fallback_font
	draw_string(font,Vector2((1280-font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)*.5,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw():
	draw_rect(Rect2(0,0,1280,960),Color("091221"))
	draw_rect(Rect2(114,142,1052,565),Color("233b62"))
	for y in range(150,705,8): draw_line(Vector2(120,y),Vector2(1160,y),Color(0.3,0.53,0.7,.07),2)
	draw_rect(Rect2(114,142,1052,565),Color("a3c3cc"),false,5)
	words("POKEMON EVOLUTION",115,30,Color("ffe19b"))
	var dark=clampf((age-.8)/1.05,0,1)
	if age<2.0: picture(0,270,Color.WHITE.lerp(Color.BLACK,dark))
	elif age<4.9:
		var phase=(age-2.)*PI*(2.+(age-2.)*1.1)
		var amount=(sin(phase)+1.)*.5
		picture(0,270*(1.-amount*.32),Color(0,0,0,1.-amount))
		picture(1,270*(.68+amount*.32),Color(0,0,0,amount))
	elif age<REVEAL: picture(1,270,Color.BLACK)
	else:
		picture(1,270,Color.WHITE)
		var flash=1.-clampf((age-REVEAL)/.35,0,1)
		draw_rect(Rect2(118,146,1044,557),Color(1,1,1,flash))
		for burst in range(9):
			var t=age-REVEAL-burst*.12
			if t<0 or t>2.1: continue
			var center=Vector2(310+float(burst%3)*330,265+float(burst/3)*130)
			var color=[Color("ffe57c"),Color("78e9e3"),Color("ef99ce")][burst%3]
			color.a=clampf(1.-t/2.1,0,1)
			for ray in range(12):
				var direction=Vector2.from_angle(ray*TAU/12.+burst*.37)
				var tip=center+direction*t*95.+Vector2(0,t*t*26.)
				draw_line(tip-direction*9.,tip,color,3)
				draw_circle(tip,2.5,color)
	var message="What? "+a.mon_name(pair[0])+" is evolving!" if age<REVEAL else "Congratulations! "+a.mon_name(pair[0])+" evolved into "+a.mon_name(pair[1])+"!"
	draw_style_box(frame(),Rect2(114,605,1052,102))
	words(message,668,25)
	if age>=REVEAL: words(a.mon_name(pair[1]).to_upper(),578,32,Color("ffe19b"))
	if age<FINISH: words("Space / Enter: finish animation",813,17,Color("93acbf"))

func frame() -> StyleBoxFlat:
	var box=StyleBoxFlat.new(); box.bg_color=Color("10233a"); box.border_color=Color("dce4cf"); box.set_border_width_all(3); box.set_corner_radius_all(8); return box
