extends Control
# A visual lesson, isolated from the player's real team, inventory and encounters.
var a
var topic=0
var elapsed=0.
var trainer=ImageTexture.create_from_image(Image.load_from_file("res://assets/kanto/actors/old_man_1.png"))
func _process(dt): elapsed+=dt; queue_redraw()
func words(value,at,color=Color.WHITE,size_px=21): draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)
func pokemon(id,at,tint=Color.WHITE):
	var texture=a.c.portrait({"id":id,"shiny":false})
	if texture:
		var scale=130./maxf(texture.get_width(),texture.get_height())
		draw_texture_rect(texture,Rect2(at-texture.get_size()*scale/2,texture.get_size()*scale),false,tint)
func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Color("142c3e"))
	draw_ellipse(Vector2(250,180),Vector2(95,23),Color("315c58"))
	draw_ellipse(Vector2(635,180),Vector2(95,23),Color("315c58"))
	var t=fmod(elapsed,8.)
	if topic==3:
		words("TRAINER",Vector2(203,78),Color("ffd57c"))
		draw_texture_rect_region(trainer,Rect2(218,69,64,128),Rect2(0,0,16,32))
		if t<2.: pokemon(13,Vector2(635,133))
		var progress=clampf((t-1.)/.8,0,1)
		var ball=Vector2(275,130).lerp(Vector2(635,170),progress)+Vector2(0,-sin(progress*PI)*95)
		if t>2. and t<5.5: ball.x+=sin(t*12)*maxf(0,sin(t*PI))*9
		if t>=1.:
			draw_circle(ball,14,Color("26303b") if t>5.5 and t<6. else Color("f4eee1"))
			draw_arc(ball,12,PI,TAU,24,Color("ee675e"),11,true); draw_line(ball-Vector2(13,0),ball+Vector2(13,0),Color("182533"),3); draw_circle(ball,4,Color.WHITE)
		words("A wild WEEDLE appeared!" if t<1. else "The trainer threw a Poke Ball!" if t<2. else "Shake... shake... shake..." if t<5.5 else "Gotcha! WEEDLE was caught!",Vector2(270,225),Color("9fe6cf"))
	elif topic==2:
		for i in 3:
			pokemon([7,4,1][i],Vector2(180+i*255,120)); words(["WATER > FIRE","FIRE > GRASS","GRASS > WATER"][i],Vector2(110+i*255,225),Color("9fe6cf"),18)
	else:
		pokemon(1,Vector2(250,125)); pokemon(25,Vector2(635,125),Color("bdc5ee") if topic==1 else Color.WHITE)
		if topic==1: words("Z z z",Vector2(654,60),Color("ffd57c"),28)
		elif topic==0:
			var orb=Vector2(290,125).lerp(Vector2(600,125),fmod(t,2.)/2.)
			draw_circle(orb,16,Color("87dd80")); draw_arc(orb,25,0,TAU,30,Color("c6ef86"),2,true)
		words(["MOVE / AIM / RECOVER","STATUS / MEDICINE","","","TM CASE / CHOOSE / LEARN","BAG / KEY ITEMS / FIELD TOOLS"][topic],Vector2(235,225),Color("9fe6cf"))
func draw_ellipse(at,radius,color):
	var points=PackedVector2Array()
	for i in 32: points.append(at+Vector2(cos(i*TAU/32),sin(i*TAU/32))*radius)
	draw_colored_polygon(points,color)
