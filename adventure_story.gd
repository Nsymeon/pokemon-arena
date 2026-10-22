extends RefCounted

const MAPS = ["ROUTE 24 / NUGGET BRIDGE","ROUTE 25 / SEA COTTAGE","S.S. ANNE","VERMILION GYM"]
const FLAGS = ["bridge_blue","bridge_rocket","bill_help","ticket","ship_blue","cut","thunder","sailor"]
const BRIDGE = [[[10,13,11,14],[10,10,10,10]],[[16,43,69],[12,12,12]],[[27,23],[14,14]],[[32,29],[16,16]],[[56],[18]]]

static func state(a) -> Dictionary:
	if not a.data.has("story"): a.data["story"]={}
	return a.data.story

static func valid(value) -> bool:
	if not value.has("story"): return true
	if not value.story is Dictionary: return false
	for key in value.story:
		if key in FLAGS:
			if not value.story[key] is bool: return false
		elif key in ["bridge","switch"]:
			var v=value.story[key]
			if not (v is int or v is float) or v!=int(v) or v<0 or v>(5 if key=="bridge" else 2): return false
		else: return false
	return true

static func objective(a) -> String:
	var s=state(a)
	if not s.get("bridge_blue",false): return "Cerulean west exit: challenge Blue at Nugget Bridge."
	if not s.get("bridge_rocket",false): return "Nugget Bridge: defeat five trainers, then the Rocket recruiter."
	if not s.get("ticket",false): return "Continue north to Bill's Sea Cottage; help him use the transporter."
	if not s.get("ship_blue",false): return "Vermilion north exit: board S.S. Anne with Bill's ticket and find Blue."
	if not s.get("cut",false): return "S.S. Anne: speak to the Captain to receive the Cut field tool."
	if not s.get("thunder",false): return "Vermilion west exit: use Cut, solve the Gym switches and defeat Lt. Surge."
	return a.Finale.objective(a)

static func gate(a,dest) -> String:
	var s=state(a)
	if dest==27 and not s.get("bridge_rocket",false): return "Clear Nugget Bridge and defeat its Rocket recruiter first."
	if dest==28 and not s.get("ticket",false): return "Sailor: You need Bill's S.S. Ticket. Visit Nugget Bridge west of Cerulean."
	if dest==29 and not s.get("cut",false): return "A small tree blocks the Gym. The S.S. Anne Captain can give you Cut."
	return ""

static func npcs(a) -> Array:
	var s=state(a)
	match int(a.data.map):
		26:
			var title="Blue / Rival" if not s.get("bridge_blue",false) else "Bridge trainer %d / 5"%(int(s.get("bridge",0))+1) if int(s.get("bridge",0))<5 else "Rocket recruiter" if not s.get("bridge_rocket",false) else "Bridge cleared"
			return [[Vector2(800,440),title,"story_bridge"]]
		27: return [[Vector2(1110,590),"Bill / Researcher","story_bill"],[Vector2(480,490),"Transporter console","story_console"]]
		28: return [[Vector2(470,650),"Passenger / Heal","heal"],[Vector2(1150,650),"Sailor / Battle","story_sailor"],[Vector2(800,450),"Blue / Rival","story_shipblue"],[Vector2(800,220),"Captain / Cut","story_captain"]]
		29:
			var result=[[Vector2(800,200),"Lt. Surge / Gym Leader","story_surge"]]
			for i in range(6): result.append([Vector2(450+(i%3)*350,470+int(i/3)*200),"Switch box %d"%(i+1),"story_switch"+str(i)])
			return result
	return []

static func buildings(map) -> Array:
	if map==27: return [[Rect2(970,180,390,330),"BILL'S SEA COTTAGE",Color("659fbb")],[Rect2(360,240,230,170),"TRANSPORTER",Color("93a9bd")]]
	return []

static func interact(a,id) -> bool:
	if not id.begins_with("story_"): return false
	var s=state(a)
	match id:
		"story_bridge":
			if not s.get("bridge_blue",false):
				a.begin_battle("bridge_blue",[17,63,19,7 if a.data.starter==4 else 4 if a.data.starter==1 else 1],[17,16,15,18])
			elif int(s.get("bridge",0))<5:
				var team=BRIDGE[int(s.get("bridge",0))]
				a.begin_battle("bridge_"+str(int(s.get("bridge",0))),team[0],team[1])
			elif not s.get("bridge_rocket",false): a.begin_battle("bridge_rocket",[23,41],[15,15])
			else: a.dialog="The bridge is clear! Continue north to Bill's cottage."
		"story_bill":
			if s.get("ticket",false): a.dialog="Bill: Thanks again! Take my ticket to the S.S. Anne in Vermilion."
			else:
				s["bill_help"]=true
				a.dialog="Bill: My experiment went wrong! I'll step into the transporter. Please activate the console to separate me from this Pokemon."
		"story_console":
			if s.get("ticket",false): a.dialog="The transporter is idle. Bill is safe."
			elif not s.get("bill_help",false): a.dialog="The console needs Bill's instructions. Speak to him first."
			else:
				s["ticket"]=true
				a.dialog="The transporter flashes! Bill is himself again. Received S.S. TICKET! Travel to Vermilion and use the north exit to board."
		"story_shipblue":
			if s.get("ship_blue",false): a.dialog="Blue: The Captain is ahead. I'll see you at the next challenge!"
			else: a.begin_battle("ship_blue",[17,20,64,8 if a.data.starter==4 else 5 if a.data.starter==1 else 2],[19,16,18,20])
		"story_captain":
			if not s.get("ship_blue",false): a.dialog="Blue is waiting on the deck. Finish your rival battle before visiting the Captain."
			else:
				s["cut"]=true
				a.dialog="Captain: Thank you for helping! Received CUT field tool. It clears the tree at Vermilion Gym automatically; no battle move slot is required."
		"story_sailor":
			if s.get("sailor",false): a.dialog="Sailor: Well fought! The passenger on the other side can heal your team."
			else: a.begin_battle("sailor",[66,90],[18,18])
		"story_surge":
			if s.get("thunder",false): a.dialog="Lt. Surge: You've earned the Thunder Badge! Train hard for the road ahead."
			elif int(s.get("switch",0))<2: a.dialog="Lt. Surge: Two locks power the barrier. Find one switch, then its neighboring switch. A wrong choice resets both."
			else: a.begin_battle("surge",[100,25,26],[21,18,24])
		_:
			if id.begins_with("story_switch"):
				var index=int(id.trim_prefix("story_switch"))
				var phase=int(s.get("switch",0))
				if phase==2: a.dialog="Both locks are open. Challenge Lt. Surge!"
				elif index==(1 if phase==0 else 2):
					s["switch"]=phase+1
					a.dialog="First lock opened! The second switch is in a neighboring box." if phase==0 else "Both locks opened! The electric barrier powers down."
				else:
					s["switch"]=0
					a.dialog="No switch here. Both locks reset." if phase==1 else "Just an empty switch box."
	a.save()
	return true

static func reward(a,kind) -> String:
	var s=state(a)
	if kind in ["bridge_blue","bridge_rocket","ship_blue","sailor"]:
		var first=not s.get(kind,false)
		s[kind]=true
		if kind=="bridge_rocket" and first:
			a.data.money=mini(999999,int(a.data.money)+5000)
			return "Nugget Bridge cleared! Nugget sold for $5000. Continue north to Bill."
		return objective(a)
	if kind.begins_with("bridge_"):
		var index=int(kind.trim_prefix("bridge_"))
		if index==int(s.get("bridge",0)): s["bridge"]=mini(5,index+1)
		return "Bridge trainers defeated: %d / 5. Speak to the next challenger."%int(s.get("bridge",0))
	if kind=="surge":
		if not s.get("thunder",false): a.data.tms["TM34"]=int(a.data.tms.get("TM34",0))+1
		s["thunder"]=true
		return "THUNDER BADGE earned! TM34 Shock Wave added to your TM Case. Continue to Celadon for Erika and Team Rocket!"
	return ""

static func prepare(a,kind):
	if kind in ["bridge_blue","ship_blue"]: a.c.opponent_identity="blue"
	elif kind=="bridge_rocket": a.c.opponent_identity="giovanni"
	elif kind=="surge":
		a.c.opponent_identity="surge"
		var moves=[["shockwave","tackle","screech","sonicboom"],["shockwave","thunderwave","quickattack","doubleteam"],["shockwave","thunderwave","quickattack","doubleteam"]]
		for i in range(3): a.c.enemy_party[i].moves=a.inventory.definitions(moves[i])

static func draw(a):
	var map=int(a.data.map)
	if map==26:
		a.draw_rect(Rect2(210,110,1180,670),Color("367f9d"))
		a.draw_rect(Rect2(690,90,220,710),Color("b39060"))
		for y in range(110,800,35): a.draw_line(Vector2(695,y),Vector2(905,y),Color("795c41"),3)
		for x in [680,920]: a.draw_line(Vector2(x,100),Vector2(x,800),Color("ead8a5"),10)
	if map==27:
		a.draw_rect(Rect2(453,440,54,50),Color("425369"))
		a.draw_rect(Rect2(460,447,40,25),Color("8bf4d3"))
		a.draw_circle(Vector2(480,483),4,Color("ffd57c"))
	if map in [28,29]:
		a.draw_rect(Rect2(0,0,1600,1000),Color("2d7896") if map==28 else Color("25333f"))
		a.draw_rect(Rect2(715,870,170,130),Color("c5ab80"))
		a.draw_rect(Rect2(180,100,1240,790),Color("bd9364") if map==28 else Color("536575"))
		for y in range(110,880,50): a.draw_line(Vector2(190,y),Vector2(1410,y),Color(0,0,0,0.15),2)
		a.draw_rect(Rect2(180,100,1240,790),Color("e6e0c0"),false,12)
		if map==28:
			for x in [260,1320]:
				for y in [230,380,530]:
					a.draw_circle(Vector2(x,y),30,Color("d5e4e4"))
					a.draw_circle(Vector2(x,y),22,Color("3c90ae"))
		else:
			var opened=int(state(a).get("switch",0))==2
			a.draw_line(Vector2(70,320),Vector2(1530,320),Color("83d6ad") if opened else Color("ffe36d"),6)
			a.words("BARRIER OPEN" if opened else "TWO ELECTRIC LOCKS",Vector2(590,300),22)
			for i in range(6):
				var p=Vector2(450+(i%3)*350,470+int(i/3)*200)
				a.draw_rect(Rect2(p-Vector2(35,45),Vector2(70,60)),Color("a2b0bb"))
				a.draw_circle(p-Vector2(0,20),8,Color("8cf4ac") if opened or (i==1 and int(state(a).get("switch",0))==1) else Color("ffd478"))

static func keys(a) -> String:
	var s=state(a)
	return "KEY ITEMS: "+("S.S. Ticket  " if s.get("ticket",false) else "")+("Cut field tool" if s.get("cut",false) else "")

static func tests(a):
	var snapshot=a.data.duplicate(true)
	a.data.erase("story")
	a.c.check(valid(a.data),"Legacy adventure saves need no chapter-three migration")
	a.data.map=12
	a.data.cascade=true
	a.travel(1)
	a.c.check(a.data.map==12,"Ship requires Bill's ticket")
	a.travel(-2)
	a.c.check(a.data.map==12,"Gym requires Cut")
	a.data.map=26
	a.travel(1)
	a.c.check(a.data.map==26,"Bridge guards the Sea Cottage route")
	a.encounter={"kind":"bridge_blue"}
	a.reward(false)
	a.c.check(not state(a).get("bridge_blue",false),"Losing story battles never unlocks progress")
	a.reward(true)
	for i in range(5):
		a.encounter={"kind":"bridge_"+str(i)}
		a.reward(true)
		a.reward(true)
		a.c.check(int(state(a).bridge)==i+1,"Each bridge trainer advances exactly once")
	a.encounter={"kind":"bridge_rocket"}
	a.reward(true)
	a.travel(1)
	a.c.check(a.data.map==27,"Cleared bridge reaches Bill")
	interact(a,"story_console")
	a.c.check(not state(a).get("ticket",false),"Console requires Bill conversation")
	interact(a,"story_bill")
	interact(a,"story_console")
	a.data.map=12
	a.travel(1)
	a.c.check(a.data.map==28,"Ticket admits the ship")
	interact(a,"story_captain")
	a.c.check(not state(a).get("cut",false),"Captain waits for rival battle")
	a.begin_battle("ship_blue",[17,20,64,8],[19,16,18,20])
	a.c.check(a.c.enemy_party.size()==4 and a.c.opponent_identity=="blue","Ship rival uses full party and Blue presentation")
	a.reward(true)
	a.in_battle=false
	a.exploring=true
	interact(a,"story_captain")
	a.data.map=12
	a.travel(-2)
	a.c.check(a.data.map==29,"Cut opens Vermilion Gym")
	interact(a,"story_switch1")
	interact(a,"story_switch5")
	a.c.check(state(a).get("switch",0)==0,"Wrong second switch resets Gym locks")
	interact(a,"story_switch1")
	interact(a,"story_switch2")
	a.c.check(state(a).get("switch",0)==2,"Adjacent second switch opens Gym")
	interact(a,"story_surge")
	a.c.check(a.in_battle and a.c.enemy_party.size()==3 and a.c.opponent_identity=="surge","Surge starts Adventure Gym battle")
	a.c.check(a.c.enemy_party[2].moves[0].id=="shockwave","Surge uses his designed Electric moveset")
	a.reward(true)
	var tm=a.data.tms.TM34
	a.reward(true)
	a.c.check(state(a).thunder and a.data.tms.TM34==tm,"Thunder Badge and Shock Wave TM award once")
	a.in_battle=false
	a.exploring=true
	a.save()
	a.load_save()
	a.c.check(state(a).ticket and state(a).cut and state(a).thunder and int(state(a).bridge)==5,"Chapter-three key items and progression survive reload")
	for map in range(26,30):
		a.data.map=map
		a.c.check(a.wild_spawns().is_empty(),"New story areas add no wild encounters")
	a.data.story={"bridge":99}
	a.c.check(not valid(a.data),"Corrupt story counters are rejected")
	a.data=snapshot
	a.save()
	a.clear_ui()
	a.dialog=""
