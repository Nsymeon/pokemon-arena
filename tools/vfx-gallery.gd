extends Node2D

var vfx = preload("res://move_vfx.gd").new()
var book = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle-learnsets.json"))
var ids: Array = []
var page = 0
var age = 0.25
var font = ThemeDB.fallback_font

func _ready():
	ids = ["razorleaf","vinewhip","bubblebeam","ember","fireblast","watergun","ice shard".replace(" ",""),"shadowball","energyball","aurasphere","hypnosis","sleeppowder","thunderpunch","megakick","crunch","slash","stringshot","swift","attract","protect","recover","dragonpulse","poisonsting","airslash"]
	for id in book.moves:
		if id not in ids: ids.append(id)
	DirAccess.make_dir_recursive_absolute("res://captures")
	for phase in [0.12,0.3,0.47]:
		age=phase
		for index in range(ceili(ids.size()/24.0)):
			page=index
			queue_redraw()
			await RenderingServer.frame_post_draw
			if index==0: get_viewport().get_texture().get_image().save_png("res://captures/vfx-%.2f.png"%phase)
	print("PASS: rendered cast, projectile and impact for all %d moves at three phases"%ids.size())
	get_tree().quit()

func _draw():
	draw_rect(Rect2(0,0,1280,960),Color("142b38"))
	for slot in range(24):
		var index=page*24+slot
		if index>=ids.size(): break
		var move: Dictionary = book.moves[ids[index]]
		var color = preload("res://roster.gd").color(move.type)
		var origin=Vector2(20+(slot%4)*320,20+floori(slot/4.0)*155)
		draw_rect(Rect2(origin,Vector2(307,143)),Color("1f3b48"))
		draw_string(font,origin+Vector2(10,22),move.name+" / "+vfx.family(move),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
		vfx.cast(self,{"last_move":move,"attack_time":0.55-age,"pos":origin+Vector2(58,112),"attack_heading":Vector2.RIGHT,"move_color":color})
		var shot={"move":move,"vel":Vector2.RIGHT*400,"pos":origin+Vector2(175,120),"age":age,"radius":12,"color":color}
		if move.id in preload("res://arena_skills.gd").SEEKERS:
			shot["trail"]=[]
			for i in range(20): shot.trail.append(shot.pos+Vector2((i-19)*3,sin((19-i)*0.1)*20))
		vfx.shot(self,shot)
		vfx.impact(self,{"move":move,"pos":origin+Vector2(265,84),"age":age})
