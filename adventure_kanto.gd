extends RefCounted

# Compact connected areas, preserving the original map IDs and existing saves.
const EXTRA_MAPS = ["ROUTE 5", "SAFFRON CITY", "ROUTE 6", "VERMILION CITY", "ROUTE 8", "LAVENDER TOWN", "ROUTE 7", "CELADON CITY", "CYCLING ROAD / 16-18", "FUCHSIA CITY", "SEA ROUTES / 19-20", "CINNABAR ISLAND", "SEA ROUTE 21", "ROUTES 22-23", "INDIGO PLATEAU", "ROUTE 9 / ROCK TUNNEL", "COAST ROUTES / 12-15"]
const HEALING_MAPS = [0,2,4,8,10,12,14,16,18,20,23]
# [landmark, city color, resident dialogue]
const CITIES = {
	10:["SILPH CO.","d0b26b","Saffron: Silph Co. towers above the city. Routes connect to Cerulean, Vermilion, Celadon and Lavender. Heal and stock up before exploring."],
	12:["S.S. ANNE / HARBOR","d8a45c","Vermilion: Welcome to the harbor! Lt. Surge's challenge is available in Gym Leaders mode. The coastal road leads toward Lavender."],
	14:["POKEMON TOWER","a995bd","Lavender: Pokemon Tower watches over this quiet town. Rock Tunnel leads toward Cerulean; the coastal road continues to Fuchsia."],
	16:["DEPARTMENT STORE","6aaa91","Celadon: Gardens and the department store welcome travelers. Our shop sells supplies and TMs. Cycling Road leads to Fuchsia."],
	18:["SAFARI ZONE GATE","bd82a0","Fuchsia: The Safari Zone gate is a landmark for now. Explore the coastal routes for wild Pokemon. The southern ferry path leads to Cinnabar."],
	20:["POKEMON LAB / MANSION","bb6f5e","Cinnabar: The island laboratory and old mansion overlook the sea. Marked ferry paths let you cross the sea routes without a Surf HM in this version."],
	23:["POKEMON LEAGUE","8d9bb5","Indigo Plateau: You have reached the League! Heal here; the Elite Four and Blue can be challenged from Gym Leaders mode. The Adventure League story is still to come."]
}
# n/s/e/w exit directions. Early chapter layouts stay compatible; routes are compact adaptations.
const LINKS = {
	0:{1:1,-1:21},1:{1:2,-1:0},2:{1:3,-1:1,-2:22},3:{1:4,-1:2},4:{1:5,-1:3},5:{1:6,-1:4},6:{1:7,-1:5},7:{1:8,-1:6},
	8:{-1:7,1:9,2:24},9:{-1:8,1:10},10:{-1:9,1:11,2:13,-2:15},11:{-1:10,1:12},12:{-1:11,2:25},
	13:{-2:10,2:14},14:{-2:13,1:24,-1:25},15:{2:10,-2:16},16:{2:15,-1:17},17:{1:16,-1:18},
	18:{1:17,2:25,-1:19},19:{1:18,-1:20},20:{1:19,-2:21},21:{2:20,1:0},22:{2:2,1:23},23:{-1:22},24:{-2:8,-1:14},25:{-2:12,1:14,-1:18}
}
const WILD = {9:[16,43,52],11:[43,52,56],13:[37,58,63],15:[37,43,69],17:[21,84,20],19:[72,116,90],21:[72,114,120],22:[56,22,75],24:[66,74,95,41],25:[48,44,70,132]}

static func destination(map: int, direction: int) -> int:
	return LINKS.get(map,{}).get(direction,-1)

static func buildings(map: int) -> Array:
	var city = CITIES[map]
	return [[Rect2(250,350,320,250),"POKEMON CENTER",Color("c76263")],[Rect2(1020,350,320,250),"POKE MART",Color("5596b4")],[Rect2(230,70,400,220),city[0],Color(city[1])]]

static func npcs(_map: int) -> Array:
	return [[Vector2(410,650),"Nurse / Heal","heal"],[Vector2(1180,650),"Shop / Supplies","shop"],[Vector2(800,460),"Resident / Town guide","guide"]]

static func wild_spawns(map: int, cycle: int) -> Array:
	var pool: Array = WILD[map]
	var level = 18 if map in [9,11,13,15] else 26 if map in [19,21,22] else 22
	return [[Vector2(450,650),pool[cycle%pool.size()],level],[Vector2(1100,450),pool[(cycle+1)%pool.size()],level+1],[Vector2(470,270),pool[(cycle+2)%pool.size()],level]]

static func draw_ground(a):
	var map = int(a.data.map)
	if CITIES.has(map):
		a.draw_rect(Rect2(190,70,1220,850),Color(CITIES[map][1]).darkened(0.15))
		for x in range(200,1400,80):
			for y in range(80,900,80): a.draw_rect(Rect2(x,y,77,77),Color(1,1,1,0.06))
	if map in [12,19,20,21]:
		for x in [0,1370]:
			a.draw_rect(Rect2(x,0,230,1000),Color("398ba6"))
			for y in range(20,1000,65): a.draw_line(Vector2(x+20,y+sin(a.time+y)*4),Vector2(x+190,y+sin(a.time+y)*4),Color("7ec8d3"),3)
	if map==14:
		for x in [1030,1130,1230]:
			a.draw_rect(Rect2(x,160,55,70),Color("81768f"))
			a.draw_arc(Vector2(x+27,160),27,PI,TAU,16,Color("d1c9d7"),5)
	if map in [16,18]:
		for x in [1040,1160,1280]:
			a.draw_circle(Vector2(x,200),48,Color("326a4c"))
			for i in range(6): a.draw_circle(Vector2(x,200)+Vector2.from_angle(i*TAU/6)*25,7,Color("f5a0bf"))
	if map==23:
		for i in range(8): a.draw_rect(Rect2(250+i*45,275,350-i*30,9),Color("c8d2dc"))

static func draw_signs(a):
	for direction in LINKS.get(int(a.data.map),{}):
		var dest = destination(int(a.data.map),direction)
		var at = {1:Vector2(610,65),-1:Vector2(610,940),2:Vector2(1170,810),-2:Vector2(100,810)}[direction]
		a.words({1:"N / ",-1:"S / ",2:"E / ",-2:"W / "}[direction]+a.MAPS[dest],at,15,Color("fff0ba"))

static func guide(a):
	a.panel("KANTO / REGION GUIDE")
	a.ui_label("HERE: "+a.MAPS[a.data.map]+"   |   Walk to the signed exits.",Vector2(180,215),18)
	var row = 0
	for direction in LINKS[int(a.data.map)]:
		a.ui_label({1:"NORTH",-1:"SOUTH",2:"EAST",-2:"WEST"}[direction]+"  >  "+a.MAPS[destination(int(a.data.map),direction)],Vector2(180,260+row*30),19)
		row += 1
	a.ui_label("TOWNS / CITIES",Vector2(180,420),22)
	for i in range(HEALING_MAPS.size()):
		a.ui_label(a.MAPS[HEALING_MAPS[i]],Vector2(180+(i%3)*300,465+int(i/3)*40),18)
	a.ui_label("Beyond Cerulean opens after Misty. Compact routes; sea crossings use ferry paths.",Vector2(180,655),17)
	a.ui_label("New city landmarks are exterior areas; later story quests are still in development.",Vector2(180,690),17)

static func tests(a):
	var seen = [0]
	var pending = [0]
	while not pending.is_empty():
		var current = pending.pop_front()
		for next in LINKS[current].values():
			a.c.check(next>=0 and next<a.MAPS.size(),"Kanto exit resolves to an existing map")
			a.c.check(current in LINKS[next].values(),"Kanto connections allow a return trip")
			if next not in seen: seen.append(next); pending.append(next)
	a.c.check(seen.size()==a.MAPS.size(),"Every Kanto map is reachable")
	a.data.map = 8
	a.data["cascade"] = false
	a.travel(1)
	a.c.check(a.data.map==8,"Misty gates new Kanto exploration")
	a.data.cascade = true
	a.data["rocket"] = true
	a.data.rival = true
	a.data.bug_catcher = true
	a.data.badge = true
	for current in LINKS:
		for direction in LINKS[current]:
			a.data.map = current
			a.travel(direction)
			a.c.check(a.data.map==destination(current,direction) and not a.blocked(a.position_world),"Walkable exit %d direction %d to %d, actual %d" % [current,direction,destination(current,direction),a.data.map])
	for city in HEALING_MAPS:
		a.data.map = city
		a.heal()
		a.c.check(a.data.healing_map==city and a.valid(a.data),"Town healing checkpoint is a valid save")
		a.save()
		a.load_save()
		a.c.check(a.data.map==city and a.data.healing_map==city,"New town and checkpoint survive reload")
