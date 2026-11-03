extends RefCounted
var c
var choices={}
var editing={}
var popup: PopupMenu
const LETTERS="ABCDEFGHIJKLMNOPQRSTUVWXYZ!?"
const TANOBY=["MONEAN","LIPTOO","WEEPTH","DILFORD","SCUFIB","RIXY","VIAPOIS"]
const SLOTS=[[0,0,0,0,0,0,0,0,0,0,0,27],[2,2,2,3,3,3,7,7,7,20,20,14],[13,13,13,13,18,18,18,18,8,8,4,4],[15,15,11,11,9,9,17,17,17,16,16,16],[24,24,19,19,6,6,6,5,5,5,10,10],[21,21,21,22,22,22,23,23,12,12,1,1],[25,25,25,25,25,25,25,25,25,25,25,26]]
const DEOXYS=[[150,50,150,50,150],[180,20,180,20,150],[70,160,70,160,90],[95,90,95,90,180]]

func install(context):
	c=context; popup=PopupMenu.new(); c.add_child(popup); popup.id_pressed.connect(choose)
	if OS.get_cmdline_user_args().is_empty() and FileAccess.file_exists("user://battle-forms.json"):
		var data=JSON.parse_string(FileAccess.get_file_as_string("user://battle-forms.json"))
		if data is Dictionary: choices=data

func count(id) -> int: return 28 if id==201 else 4 if id in [351,386] else 1
func default_form(id) -> int: return 1 if id==386 else 0
func label(id,form) -> String:
	if id==201: return LETTERS.substr(clampi(int(form),0,27),1)
	if id==351: return ["Normal","Sunny","Rainy","Snowy"][clampi(int(form),0,3)]
	if id==386: return ["Normal","Attack","Defense","Speed"][clampi(int(form),0,3)]
	return "Normal"

func assign(mon,fresh=false):
	if mon.has("form"): return
	mon["form"]=default_form(int(mon.id))
	if int(mon.id)==201:
		var p=int(mon.get("personality",0))
		mon.form=(((p&0x3000000)>>18)|((p&0x30000)>>12)|((p&0x300)>>6)|(p&3))%28
		if fresh:
			for i in TANOBY.size():
				if TANOBY[i] in c.adventure.world.current:
					var roll=c.rng.randi_range(1,100); var weights=[20,20,10,10,10,10,5,5,4,4,1,1]
					for slot in 12:
						roll-=weights[slot]
						if roll<=0: mon.form=SLOTS[i][slot]; return

func apply(mon: Dictionary, form: int) -> Dictionary:
	mon["form"]=clampi(form,0,count(int(mon.id))-1)
	if mon.id==386:
		var stats=DEOXYS[mon.form]
		for i in 5: mon.base_stats[["atk","def","spa","spd","spe"][i]]=stats[i]
		mon.speed=roundf(minf(340,150+stats[4]*1.1))
	return mon

func configured(mon,friendly,slot):
	var result=mon.duplicate(true); var selected=default_form(int(mon.id))
	if not c.campaign.daily.locked(c): selected=int(choices.get(c.move_editor.identity(mon,friendly,slot),selected))
	return apply(result,selected)

func open(mon,friendly,slot):
	if c.campaign.daily.locked(c) or c.adventure.in_battle or count(int(mon.id))<=1: return
	editing={"id":int(mon.id),"key":c.move_editor.identity(mon,friendly,slot)}; popup.clear()
	# Castform changes automatically with weather; its base choice stays Normal.
	for i in count(editing.id):
		popup.add_item(label(editing.id,i),i)
		if editing.id==351 and i!=0: popup.set_item_disabled(i,true)
	popup.position=Vector2i(c.get_viewport().get_mouse_position()); popup.popup()

func choose(index):
	if editing.is_empty() or c.campaign.daily.locked(c) or index<0 or index>=count(editing.id): return
	if editing.id==351 and index!=0: return
	choices[editing.key]=index
	if OS.get_cmdline_user_args().is_empty():
		var file=FileAccess.open("user://battle-forms.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(choices))
	c.queue_redraw()

func draw(mon,pos):
	if count(int(mon.id))<=1 or c.campaign.daily.locked(c): return
	c.draw_rect(Rect2(pos+Vector2(404,7),Vector2(114,29)),Color("243d49"))
	c.draw_string(c.font, pos+Vector2(410,27),"FORM: "+label(int(mon.id),int(mon.get("form",default_form(int(mon.id))))),HORIZONTAL_ALIGNMENT_LEFT,108,14,Color("cee5ed"))
