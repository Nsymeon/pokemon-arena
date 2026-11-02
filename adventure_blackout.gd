extends Node2D
var a
var lost=0
var age=0.0
var finished=false

func setup(adventure, amount: int):
	a=adventure; lost=amount

func _process(dt):
	if finished: return
	age+=dt; queue_redraw()
	if age>=4.6: finish()

func finish():
	if finished: return
	finished=true
	if a.modal!="BLACKOUT" or a.blackout_scene!=self: return
	a.clear_ui(); a.dialog="Your Pokemon were fully restored at your last healing spot."
	if not a.evolutions.is_empty(): a.show_evolution()

func text_center(value: String, y: float, size: int, alpha: float):
	var font=ThemeDB.fallback_font
	draw_string(font,Vector2((1280-font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)/2,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(1,1,1,alpha))

func _draw():
	draw_rect(Rect2(0,0,1280,960),Color.BLACK)
	text_center("All of your Pokemon have fainted!",386,32,clampf(age/.4,0,1))
	text_center("You blacked out...",450,28,clampf((age-.4)/.4,0,1))
	text_center("Lost $"+str(lost)+"." if lost>0 else "You have no money to lose.",526,24,clampf((age-.9)/.4,0,1))
	text_center("Returning to your last healing spot...",610,20,clampf((age-1.5)/.4,0,1))
