extends RefCounted

# Append-only map IDs: existing saves keep their town and coordinates.
const MAPS = ["CELADON GYM","ROCKET HIDEOUT","POKEMON TOWER","FUCHSIA GYM","SAFARI ZONE","WARDEN'S HOUSE","SILPH CO.","SAFFRON GYM","FIGHTING DOJO","POKEMON MANSION","CINNABAR GYM","VIRIDIAN GYM","VICTORY ROAD","INDIGO / LEAGUE CHAMBERS","SEAFOAM ISLANDS","POWER PLANT","DIGLETT'S CAVE","CERULEAN CAVE","UNDERGROUND PATH / 5-6","UNDERGROUND PATH / 7-8","ROUTE 11","ROUTE 2","ROUTE 10","CINNABAR LAB","POKEMON FAN CLUB","HALL OF FAME","SAFARI SECRET HOUSE"]
const PARENTS = {30:16,31:16,32:14,33:18,34:18,35:18,36:10,37:10,38:10,39:20,40:20,41:2,42:22,43:23,44:19,45:24,46:12,47:8,48:9,49:15,50:12,51:2,52:24,53:20,54:12,55:43,56:34}
const SECOND_EXITS = {46:51,48:11,49:13,50:25,51:3,52:14}
const GATES = {30:["thunder"],31:["thunder"],32:["thunder"],33:["flute"],34:["flute"],35:["flute"],36:["soul"],37:["silph_saved"],38:["thunder"],39:["surf"],40:["secret_key","marsh"],41:["seven"],42:["eight","strength","surf"],43:["league_rival","eight"],44:["surf","strength"],45:["surf"],46:["thunder"],47:["champion"],52:["thunder"],53:["surf"],54:["thunder"],55:["champion"],56:["flute"]}
const BADGES = ["rainbow","soul","marsh","volcano","earth"]
const TASKS = {
	"erika":{"name":"Erika / Rainbow Badge","map":30,"need":["thunder"],"trainer":"erika","flag":"rainbow","tm":"TM19"},
	"hideout_guard":{"name":"Rocket / Lift-key guard","map":31,"need":["thunder"],"ids":[20,24,28],"levels":[25,25,26]},
	"lift_key":{"name":"Pick up the Lift Key","map":31,"need":["hideout_guard"]},
	"hideout_boss":{"name":"Giovanni / Silph Scope","map":31,"need":["lift_key"],"ids":[95,111,115],"levels":[25,24,29],"identity":"giovanni","flag":"scope"},
	"tower_ghost":{"name":"Reveal and calm the ghost","map":32,"need":["scope"],"text":"The Silph Scope reveals Marowak's spirit. You calm the restless mother and open the stairway."},
	"tower_rocket":{"name":"Rocket / Tower rescue","map":32,"need":["tower_ghost"],"ids":[42,24,20],"levels":[30,30,30]},
	"flute":{"name":"Mr. Fuji / Poke Flute","map":32,"need":["tower_rocket"],"text":"Mr. Fuji is safe! Received POKE FLUTE. Wake the sleeping Snorlax on the coastal or cycling road."},
	"snorlax":{"name":"Play flute / clear Snorlax","map":25,"need":["flute"],"text":"The Poke Flute wakes Snorlax. It wanders off, clearing the passage."},
	"koga":{"name":"Koga / Soul Badge","map":33,"need":["snorlax","rainbow"],"trainer":"koga","flag":"soul","tm":"TM06"},
	"gold_teeth":{"name":"Find the Warden's Gold Teeth","map":34,"need":["flute"]},
	"surf":{"name":"Secret House / Surf field tool","map":56,"need":["flute"],"text":"Received SURF field tool! You can now explore the Power Plant, Seafoam Islands and Cinnabar Mansion."},
	"strength":{"name":"Warden / Strength field tool","map":35,"need":["gold_teeth"],"text":"You return the Gold Teeth. The Warden gives you STRENGTH for boulder mechanisms."},
	"silph_guard":{"name":"Rocket / Silph security","map":36,"need":["soul"],"ids":[42,97,82],"levels":[35,35,35]},
	"card_key":{"name":"Collect the Card Key","map":36,"need":["silph_guard"]},
	"silph_blue":{"name":"Blue / Silph rival","map":36,"need":["card_key"],"ids":[17,102,58,65,0],"levels":[37,35,35,35,40],"identity":"blue"},
	"silph_boss":{"name":"Giovanni / Silph takeover","map":36,"need":["silph_blue"],"ids":[33,111,115,31],"levels":[37,37,35,41],"identity":"giovanni"},
	"lapras":{"name":"Employee / Lapras gift","map":36,"need":["silph_blue"],"gift":131,"level":25},
	"silph_saved":{"name":"President / Free Silph Co.","map":36,"need":["silph_boss"],"text":"Silph Co. is free! Saffron Gym is open. The employee has a Lapras waiting for you."},
	"sabrina":{"name":"Sabrina / Marsh Badge","map":37,"need":["silph_saved","warp"],"trainer":"sabrina","flag":"marsh","tm":"TM04"},
	"dojo":{"name":"Karate Master / Dojo","map":38,"need":["thunder"],"ids":[106,107],"levels":[37,37],"identity":"bruno"},
	"hitmonlee":{"name":"Choose Hitmonlee","map":38,"need":["dojo"],"gift":106,"level":25,"flag":"dojo_gift"},
	"hitmonchan":{"name":"Choose Hitmonchan","map":38,"need":["dojo"],"gift":107,"level":25,"flag":"dojo_gift"},
	"mansion_switch":{"name":"Statue / secret switch","map":39,"need":["surf"],"text":"The statue switch opens a hidden laboratory passage."},
	"secret_key":{"name":"Laboratory / Secret Key","map":39,"need":["mansion_switch"]},
	"blaine":{"name":"Blaine / Volcano Badge","map":40,"need":["secret_key","marsh","quiz"],"trainer":"blaine","flag":"volcano","tm":"TM38"},
	"giovanni":{"name":"Giovanni / Earth Badge","map":41,"need":["seven"],"trainer":"giovanni","flag":"earth","tm":"TM26"},
	"victory_boulder":{"name":"Push boulder onto the plate","map":42,"need":["eight","strength"]},
	"victory_trainer":{"name":"Ace Trainer / Victory Road","map":42,"need":["victory_boulder"],"ids":[112,68,55],"levels":[47,48,48]},
	"league_rival":{"name":"Blue / League checkpoint","map":42,"need":["victory_trainer"],"ids":[18,111,102,65,58,0],"levels":[47,45,45,47,45,53],"identity":"blue"},
	"seafoam_boulder":{"name":"Move boulders / calm current","map":44,"need":["surf","strength"],"text":"The boulders calm the current. Seafoam's lower chamber is now quiet and accessible."},
	"bicycle":{"name":"Fan Club / Bicycle voucher","map":54,"need":["thunder"],"text":"Received a Bicycle voucher as a key item. Keep it safe; it cannot be redeemed yet."}
}
const LABELS = {"thunder":"Thunder Badge","rainbow":"Rainbow Badge","soul":"Soul Badge","marsh":"Marsh Badge","volcano":"Volcano Badge","earth":"Earth Badge","scope":"Silph Scope","flute":"Poke Flute","gold_teeth":"Gold Teeth","surf":"Surf","strength":"Strength","card_key":"Card Key","secret_key":"Secret Key","seven":"seven badges","eight":"eight badges","champion":"Champion title","snorlax":"clear Snorlax with the flute","warp":"solve the warp panels","quiz":"answer the Gym quiz","silph_saved":"free Silph Co.","league_rival":"defeat Blue at Victory Road"}

static func state(a) -> Dictionary:
	if not a.data.has("journey"): a.data["journey"]={}
	return a.data.journey

static func badges(a) -> int:
	var total=int(a.data.badge)+int(a.data.get("cascade",false))+int(a.Story.state(a).get("thunder",false))
	for key in BADGES: total+=int(state(a).get(key,false))
	return total

static func has(a,key) -> bool:
	if key=="thunder": return a.Story.state(a).get(key,false)
	if key=="seven": return badges(a)>=7
	if key=="eight": return badges(a)>=8
	return state(a).get(key,false)==true

static func missing(a,needs) -> String:
	var result=[]
	for key in needs:
		if not has(a,key): result.append(LABELS.get(key,key.replace("_"," ")))
	return ", ".join(result)

static func valid(value) -> bool:
	if value.has("journey"):
		if not value.journey is Dictionary: return false
		var flags=TASKS.keys()+BADGES+["scope","dojo_gift","warp","quiz","champion"]
		for key in value.journey:
			var v=value.journey[key]
			if key=="league":
				if not (v is int or v is float) or v!=int(v) or v<0 or v>4: return false
			elif key in flags:
				if not v is bool: return false
			else: return false
	if value.has("hall_of_fame"):
		if not value.hall_of_fame is Array or value.hall_of_fame.size()>6: return false
		for mon in value.hall_of_fame:
			if not mon is Dictionary: return false
			for key in ["id","level"]:
				if not (mon.get(key) is int or mon.get(key) is float) or mon[key]!=int(mon[key]): return false
			if mon.id<1 or mon.id>1025 or mon.level<1 or mon.level>100: return false
	return true

static func objective(a) -> String:
	for pair in [["rainbow","Celadon: enter the Gym and defeat Erika."],["scope","Celadon: enter Rocket Hideout, find the Lift Key and defeat Giovanni."],["flute","Lavender: use the Silph Scope in Pokemon Tower and rescue Mr. Fuji."],["snorlax","Coastal road or Cycling Road: play the Poke Flute to clear Snorlax."],["soul","Fuchsia: defeat Koga in the Gym."],["surf","Safari Zone: visit the Secret House for Surf."],["strength","Safari Zone: find Gold Teeth, then visit the Warden in Fuchsia."],["silph_saved","Saffron: enter Silph Co., find the Card Key and stop Team Rocket."],["marsh","Saffron Gym: solve the warp panels, then challenge Sabrina."],["secret_key","Cinnabar Mansion: activate the statue and find the Secret Key."],["volcano","Cinnabar Gym: complete the quiz and defeat Blaine."],["earth","Viridian: the final Gym is open. Defeat Giovanni."],["league_rival","Routes 22-23: enter Victory Road, solve the boulder and defeat Blue."],["champion","Indigo Plateau: enter the League for the Elite Four and Champion."]]:
		if not has(a,pair[0]): return pair[1]
	return "Kanto Champion! Visit the Hall of Fame, explore or replay the League."

static func portals(map: int) -> Array:
	var out=[]
	for dest in PARENTS:
		if PARENTS[dest]==map or SECOND_EXITS.get(dest,-1)==map: out.append(dest)
	return out

static func destinations(map: int) -> Array:
	var out=portals(map)
	if PARENTS.has(map): out.append(PARENTS[map])
	if SECOND_EXITS.has(map): out.append(SECOND_EXITS[map])
	return out

static func enter(a,dest: int):
	if dest not in destinations(int(a.data.map)): return
	var need=missing(a,GATES.get(dest,[]))
	if need!="": a.dialog="Entry requires: "+need+"."; return
	if a.data.map==43 and dest!=55: state(a)["league"]=0
	a.c.click_move=false
	a.data.map=dest
	a.position_world=Vector2(800,700)
	a.dialog=a.MAPS[dest]+" / "+objective(a)
	a.save()
	a.queue_redraw()

static func npcs(a) -> Array:
	var map=int(a.data.map)
	var result=[]
	var entries=portals(map)
	for i in range(entries.size()):
		var dest=entries[i]
		result.append([Vector2(320+(i%4)*310,770+int(i/4)*100),"Enter "+a.MAPS[dest],"late_enter_"+str(dest)])
	if PARENTS.has(map):
		result.append([Vector2(800,890),"Exit to "+a.MAPS[PARENTS[map]],"late_enter_"+str(PARENTS[map])])
		if SECOND_EXITS.has(map): result.append([Vector2(1250,240),"Passage to "+a.MAPS[SECOND_EXITS[map]],"late_enter_"+str(SECOND_EXITS[map])])
	var index=0
	for key in TASKS:
		var task=TASKS[key]
		if task.map!=map and not(key=="snorlax" and map==17): continue
		result.append([Vector2(380+(index%3)*420,360+int(index/3)*230),task.name+(" / DONE" if has(a,task.get("flag",key)) else ""),"late_task_"+key])
		index+=1
	if map==37: result.append([Vector2(800,650),"Warp panel console","late_warp"])
	if map==40: result.append([Vector2(800,650),"Gym quiz console","late_quiz"])
	if map==43: result.append([Vector2(800,350),"League / "+["Lorelei","Bruno","Agatha","Lance","Champion Blue"][int(state(a).get("league",0))],"late_league"])
	if map==55: result.append([Vector2(800,350),"Hall of Fame / winning team","late_hall"])
	if map in [45,47,53,46,48,49,50,51,52]: result.append([Vector2(800,430),"Area information","late_info"])
	return result

static func start_task(a,key):
	if not TASKS.has(key): return
	var task=TASKS[key]
	if has(a,task.get("flag",key)): a.dialog="Already completed: "+task.name+"."; return
	var need=missing(a,task.need)
	if need!="": a.dialog="First: "+need+"."; return
	if task.has("trainer"):
		var trainer=a.c.league.trainers.filter(func(t):return t.id==task.trainer)[0]
		a.begin_battle("late_"+key,trainer.team.map(func(m):return int(m.id)),trainer.team.map(func(m):return int(m.level)))
	elif task.has("ids"):
		var ids=task.ids.duplicate()
		for i in range(ids.size()):
			if ids[i]==0: ids[i]=9 if a.data.starter==4 else 6 if a.data.starter==1 else 3
		a.begin_battle("late_"+key,ids,task.levels)
	else: a.dialog=complete(a,key)
	a.save()

static func complete(a,key) -> String:
	var task=TASKS[key]
	if has(a,task.get("flag",key)): return "Already completed."
	if task.has("gift"):
		if a.data.party.size()>=6 and a.data.storage.size()>=100: return "Your party and storage are full. Make room, then speak again."
		var mon=a.new_mon(task.gift,task.level)
		if a.data.party.size()<6: a.data.party.append(mon)
		else: a.data.storage.append(mon)
	state(a)[key]=true
	state(a)[task.get("flag",key)]=true
	if task.has("tm"): a.data.tms[task.tm]=mini(999,int(a.data.tms.get(task.tm,0))+1)
	return task.get("text","Completed: "+task.name+"!")+(" Received "+task.tm+"." if task.has("tm") else "")+(" Pokemon added to party or storage." if task.has("gift") else "")

static func interact(a,id) -> bool:
	if not id.begins_with("late_"): return false
	if id.begins_with("late_enter_"): enter(a,int(id.trim_prefix("late_enter_"))); return true
	if id.begins_with("late_task_"): start_task(a,id.trim_prefix("late_task_")); return true
	match id:
		"late_warp":
			a.panel("SAFFRON / WARP PANELS")
			a.ui_label("The inscription reads: Dawn comes before night.
Choose the panel that leads to Sabrina.",Vector2(180,250),22)
			a.ui_button("SUN PANEL",Vector2(190,400),Vector2(380,65),solve.bind(a,"warp",true))
			a.ui_button("MOON PANEL",Vector2(650,400),Vector2(380,65),solve.bind(a,"warp",false))
		"late_quiz":
			a.panel("CINNABAR / GYM QUIZ")
			a.ui_label("Which type is super effective against Fire?",Vector2(180,250),22)
			a.ui_button("WATER",Vector2(190,400),Vector2(380,65),solve.bind(a,"quiz",true))
			a.ui_button("GRASS",Vector2(650,400),Vector2(380,65),solve.bind(a,"quiz",false))
		"late_league": start_league(a)
		"late_hall": hall(a)
		"late_info": a.dialog="Exploration area: "+a.MAPS[a.data.map]+". Follow the marked passages. There are no scheduled battles here."
	a.save()
	return true

static func solve(a,key,correct):
	a.clear_ui()
	if correct: state(a)[key]=true
	a.dialog="The mechanism opens! You may challenge the Gym Leader." if correct else "That panel does not open the way. Try again."
	a.save()

static func league_trainer(a):
	var stage=int(state(a).get("league",0))
	var id=["lorelei","bruno","agatha","lance", "blue_blastoise" if a.data.starter==4 else "blue_charizard" if a.data.starter==1 else "blue_venusaur"][stage]
	return a.c.league.trainers.filter(func(t):return t.id==id)[0]

static func start_league(a):
	var need=missing(a,["eight","league_rival"])
	if need!="": a.dialog="League entry requires: "+need; return
	var trainer=league_trainer(a)
	a.begin_battle("late_league_"+str(int(state(a).get("league",0))),trainer.team.map(func(m):return int(m.id)),trainer.team.map(func(m):return int(m.level)))

static func prepare(a,kind):
	if not kind.begins_with("late_"): return
	var key=kind.trim_prefix("late_")
	var trainer={}
	if key.begins_with("league_") and key.trim_prefix("league_").is_valid_int(): trainer=league_trainer(a)
	elif TASKS.has(key):
		var task=TASKS[key]
		a.c.opponent_identity=task.get("identity","giovanni" if "rocket" in key or "guard" in key else "blue")
		if task.has("trainer"): trainer=a.c.league.trainers.filter(func(t):return t.id==task.trainer)[0]
	if not trainer.is_empty():
		a.c.opponent_identity=trainer.id
		for i in range(trainer.team.size()): a.c.enemy_party[i].moves=trainer.team[i].moves.duplicate(true)

static func reward(a,victory: bool) -> String:
	var kind: String=a.encounter.kind
	if not kind.begins_with("late_"): return ""
	if not victory:
		if kind.begins_with("late_league_") and kind.trim_prefix("late_league_").is_valid_int(): state(a)["league"]=0
		return ""
	var key=kind.trim_prefix("late_")
	if key.begins_with("league_") and key.trim_prefix("league_").is_valid_int():
		var stage=int(key.trim_prefix("league_"))
		if stage!=int(state(a).get("league",0)): return "League result already recorded."
		if stage<4:
			state(a)["league"]=stage+1
			return "League battle won! Speak to the next challenger. Team HP is preserved; leaving resets the run."
		state(a)["champion"]=true
		state(a)["league"]=0
		a.data["hall_of_fame"]=a.data.party.map(func(mon):return {"id":int(mon.id),"level":int(mon.level)})
		return "KANTO CHAMPION! Your winning team is saved in the Hall of Fame. Enter the Hall from this chamber."
	if TASKS.has(key): return complete(a,key)
	return ""

static func hall(a):
	a.panel("HALL OF FAME / KANTO CHAMPION")
	var party=a.data.get("hall_of_fame",[])
	for i in range(party.size()):
		var mon=party[i]
		var picture=TextureRect.new()
		picture.texture=a.c.portraits[int(mon.id)]
		picture.position=Vector2(205+(i%3)*300,245+int(i/3)*180)
		picture.size=Vector2(90,90)
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		a.ui.add_child(picture)
		a.ui_label(a.mon_name(int(mon.id))+" / Lv."+str(int(mon.level)),picture.position+Vector2(0,115),20)
	a.ui_label("Eight badges. Elite Four defeated. Champion Blue defeated.",Vector2(180,690),20)

static func keys(a) -> Array:
	var result=[]
	for key in ["lift_key","scope","flute","gold_teeth","surf","strength","card_key","secret_key","bicycle"]:
		if has(a,key): result.append(LABELS.get(key,key.replace("_"," ").capitalize()))
	return result

static func draw(a):
	var map=int(a.data.map)
	if map<30: return
	var cave=map in [42,44,46,47]
	var outside=map in [34,50,51,52,56]
	var color=Color("555065") if cave else Color("6b9867") if outside else Color("476778")
	if map in [30,33]: color=Color("4d7357")
	if map in [39,40]: color=Color("785649")
	if map==32: color=Color("69607e")
	if map==55: color=Color("72633d")
	a.draw_rect(Rect2(0,0,1600,1000),color.darkened(0.4))
	a.draw_rect(Rect2(180,110,1240,790),color)
	for x in range(200,1400,100):
		for y in range(120,880,100): a.draw_rect(Rect2(x,y,96,96),Color(1,1,1,0.035),false,1)
	a.draw_rect(Rect2(180,110,1240,790),Color("c3c4b5"),false,6)
	a.draw_rect(Rect2(720,850,160,150),color.lightened(0.12))
	a.words(a.MAPS[map],Vector2(350,185),28,Color("ffe3a2"))
	if map==55:
		for i in range(8): a.draw_circle(Vector2(450+i*100,240),16,Color("f5d27b"))

static func info_row(list,text):
	var label=Label.new()
	label.text=text
	label.custom_minimum_size=Vector2(875,48)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",Color("dce9e5"))
	label.add_theme_font_size_override("font_size",18)
	list.add_child(label)

static func guide(a):
	var list=a.inventory.page("KANTO GUIDE / "+a.MAPS[a.data.map])
	info_row(list,a.objective())
	for direction in a.Kanto.LINKS.get(int(a.data.map),{}):
		info_row(list,{1:"NORTH",-1:"SOUTH",2:"EAST",-2:"WEST"}[direction]+" > "+a.MAPS[a.Kanto.destination(a.data.map,direction)])
	for dest in destinations(int(a.data.map)):
		var need=missing(a,GATES.get(dest,[]))
		info_row(list,"PASSAGE > "+a.MAPS[dest]+(" / requires "+need if need!="" else " / open"))
	info_row(list,"STORY: "+str(badges(a))+" / 8 badges. "+("Champion registered." if has(a,"champion") else "Main quest shown above."))
	info_row(list,"Talk at marked entrances. Save anytime from the pause menu.")

static func win_battle(a):
	var guard=0
	while a.in_battle and guard<7:
		guard+=1
		a.c.enemy.hp=0
		a.c.finish_round()
		a.c.shots.clear()
		a.c.result_time=10
		a.record_knockout()
		if a.c.can_continue_team(): a.c.advance_team()
		else: a.return_world()
	a.c.check(not a.in_battle,"Story battle completes every opponent slot")
	a.evolutions.clear()
	a.clear_ui()
	a.dialog=""

static func tests(a):
	var snapshot=a.data.duplicate(true)
	a.data.erase("journey")
	a.c.check(valid(a.data),"Old saves are compatible with full Kanto chapter")
	a.data.badge=true
	a.data.cascade=true
	a.Story.state(a)["thunder"]=true
	a.data.party=[a.new_mon(5,31),a.new_mon(8,35),a.new_mon(148,54)]
	a.grant_xp(3000)
	a.c.check(a.data.party[0].id==6 and a.data.party[1].id==9 and a.data.party[2].id==149,"Late starter and Dragonite evolutions work above level 30")
	a.evolutions.clear()
	a.data.party=[a.new_mon(6,28),a.new_mon(9,28),a.new_mon(3,28)]
	a.data.map=23
	enter(a,43)
	a.c.check(a.data.map==23,"League cannot be entered before eight badges and rival")
	a.data.map=10
	enter(a,37)
	a.c.check(a.data.map==10,"Saffron Gym waits for Silph rescue")
	for key in ["erika","hideout_guard","lift_key","hideout_boss","tower_ghost","tower_rocket","flute","snorlax","koga","gold_teeth","surf","strength","silph_guard","card_key","silph_blue","silph_boss","lapras","silph_saved","sabrina","mansion_switch","secret_key","blaine","giovanni","victory_boulder","victory_trainer","league_rival"]:
		var task=TASKS[key]
		a.data.map=task.map
		if key=="sabrina": solve(a,"warp",true)
		if key=="blaine": solve(a,"quiz",true)
		a.c.check(missing(a,task.need)=="","Main quest order satisfies prerequisites: "+key)
		start_task(a,key)
		if a.in_battle:
			a.c.check(a.c.enemy_party.size()>0 and a.c.enemy_party.all(func(m):return m.level>0 and not m.moves.is_empty()),"Story battle has leveled opponents and moves")
			win_battle(a)
		a.c.check(has(a,task.get("flag",key)),"Main quest completes: "+key)
	a.c.check(badges(a)==8,"All eight Adventure badges are tracked")
	var lapras_count=a.data.party.size()+a.data.storage.size()
	start_task(a,"lapras")
	a.c.check(a.data.party.size()+a.data.storage.size()==lapras_count,"Lapras gift cannot be duplicated")
	var tms=a.data.tms.duplicate(true)
	complete(a,"giovanni")
	a.c.check(a.data.tms==tms,"Late Gym TMs cannot be duplicated")
	a.data.map=38
	start_task(a,"dojo")
	win_battle(a)
	start_task(a,"hitmonlee")
	var count=a.data.party.size()+a.data.storage.size()
	start_task(a,"hitmonchan")
	a.c.check(a.data.party.size()+a.data.storage.size()==count,"Dojo choice awards only one Pokemon")
	a.data.map=43
	start_league(a)
	a.reward(false)
	a.in_battle=false
	a.c.check(int(state(a).get("league",0))==0 and not has(a,"champion"),"League defeat resets run without awarding Champion")
	state(a)["league"]=3
	enter(a,23)
	a.c.check(state(a).league==0,"Leaving League resets the current gauntlet")
	enter(a,43)
	for stage in range(5):
		a.c.check(int(state(a).get("league",0))==stage,"League advances in order")
		start_league(a)
		var expected=league_trainer(a)
		a.c.check(a.c.enemy_party.size()==expected.team.size(),"League trainer has full party")
		win_battle(a)
		if stage==0:
			var hp=a.data.party[0].hp
			a.save()
			a.load_save()
			a.c.check(int(state(a).get("league",0))==1 and is_equal_approx(a.data.party[0].hp,hp),"Mid-League reload preserves stage and party health")
	a.c.check(has(a,"champion") and a.data.hall_of_fame.size()==a.data.party.size(),"Champion victory records winning party")
	a.save()
	a.load_save()
	a.c.check(has(a,"champion") and badges(a)==8 and valid(a.data),"All badges, quest keys and Hall of Fame survive save reload")
	for dest in PARENTS:
		# Optional locations share the same saved prerequisites; no wild spawns are added.
		a.data.map=PARENTS[dest]
		enter(a,dest)
		a.c.check(a.data.map==dest and not a.blocked(a.position_world),"Every new Kanto location has a usable entry: "+str(dest))
		a.c.check(a.wild_spawns().is_empty(),"New Kanto interiors do not add wild encounters")
		enter(a,PARENTS[dest])
		a.c.check(a.data.map==PARENTS[dest],"Every new Kanto location has a return exit")
	a.data.party[0].level=100
	a.data.party[0].xp=0
	a.grant_xp(1000)
	a.c.check(a.data.party[0].level==100 and a.data.party[0].xp==0,"Level cap is 100")
	a.data.journey={"league":99}
	a.c.check(not valid(a.data),"Invalid League stage is rejected")
	a.data=snapshot
	a.exploring=true
	a.in_battle=false
	a.evolutions.clear()
	a.clear_ui()
	a.save()
