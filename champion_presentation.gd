extends Node2D
# The ceremony uses the recorded winning party, including shiny variants.
var a
var party=[]
var pictures=[]
var age=0.0
var button: Button
var finished=false
var avatar: Texture2D

func setup(adventure):
	a=adventure; party=a.data.get("hall_of_fame",[]).duplicate(true)
	for mon in party: pictures.append(preload("res://evolution_presentation.gd").trimmed(a.collection.full_picture(mon)))
	avatar=preload("res://evolution_presentation.gd").trimmed(a.avatar.texture(a.avatar.config(),true))
	button=Button.new(); button.text="CONTINUE YOUR JOURNEY"; button.position=Vector2(430,838); button.size=Vector2(420,54)
	button.pressed.connect(advance); button.visible=false; add_child(button)

func _process(dt):
	age+=dt; button.visible=age>=party.size()*1.15+1.5; queue_redraw()

func advance():
	if age<party.size()*1.15+1.5: age=party.size()*1.15+1.5; return
	if finished: return
	finished=true
	if a.progression.done("champion_pending"): a.progression.finish_ceremony()
	else: a.clear_ui()

func words(value,at,size,color=Color("f0eddc")):
	draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw():
	draw_rect(Rect2(0,0,1280,960),Color("101a30"))
	for i in range(65):
		var p=Vector2(fposmod(i*181.7,1280),fposmod(i*79.3+age*18,960))
		draw_circle(p,1.4+sin(age+i)*.6,Color(.9,.78,.48,.5))
	words("HALL OF FAME",Vector2(420,85),44,Color("ffe099"))
	words("Welcome to the Hall of Fame, Champion!",Vector2(352,130),26)
	for i in range(party.size()):
		var alpha=clampf((age-i*1.15)/.65,0,1)
		var at=Vector2(170+(i%3)*350,195+int(i/3)*252)
		draw_rect(Rect2(at,Vector2(240,222)),Color(.15,.23,.34,alpha))
		draw_rect(Rect2(at,Vector2(240,222)),Color(.9,.76,.4,alpha),false,2)
		var texture=pictures[i]; var size=texture.get_size(); size*=145/maxf(size.x,size.y)
		draw_texture_rect(texture,Rect2(at+Vector2(120,87)-size*.5,size),false,Color(1,1,1,alpha))
		words(a.mon_name(party[i].id),at+Vector2(20,179),23,Color(1,.94,.8,alpha))
		words("Lv. "+str(int(party[i].level))+("   SHINY" if party[i].get("shiny",false) else ""),at+Vector2(20,207),18,Color(.7,.83,.9,alpha))
	var size=avatar.get_size(); size*=98/maxf(size.x,size.y)
	draw_texture_rect(avatar,Rect2(Vector2(350,762)-size*.5,size),false)
	words("OAK: Your bond with these partners",Vector2(425,750),23)
	words("is what made you the Champion.",Vector2(425,785),23)
