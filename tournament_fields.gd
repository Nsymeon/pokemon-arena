extends RefCounted

const LABELS = ["Crystal cavern", "Indigo stadium", "Grass field", "Rock field", "Water field", "Ice field", "Forest field", "Town field", "Wasteland", "Water & rock", "League / field change"]
const HINTS = ["Original cave", "Open championship court", "Grass lanes and flower beds", "Breakable rock cover", "Water slows land Pokémon; islands are safe", "Ice types move 15% faster", "Forest clearings and breakable cover", "Paved streets and model buildings", "Cracked earth and rubble", "Water channels with rocky islands", "Random classic field; changes after 3 KOs on either team"]
var active = 0
var rotating = false
var changed = false
var transition = false

func reset(c, choice: int):
	rotating = choice == 10
	changed = false
	transition = false
	active = c.rng.randi_range(2,5) if rotating else choice
	configure(c)

func configure(c):
	c.rocks.clear()
	var points = []
	if active == 0: points = [Vector2(960,384),Vector2(1440,824),Vector2(1840,240),Vector2(544,944)]
	if active in [3,6,8,9]:
		points = [Vector2(600,340),Vector2(1800,340),Vector2(600,860),Vector2(1800,860),Vector2(1080,430),Vector2(1320,770)]
	for p in points: c.rocks.append({"pos":p,"hp":55.0})

func intermission(c):
	if not rotating or changed: return
	var lost = 0
	for member in c.player_states:
		if member.hp <= 0: lost += 1
	if lost < 3 and c.enemy_active < 3: return
	var choices = [2,3,4,5]
	choices.erase(active)
	active = choices[c.rng.randi_range(0,choices.size()-1)]
	changed = true
	transition = true
	configure(c)
	# A new surface appears only after all committed attacks and recalls settle.
	c.player.pos = c.FIELD.size * Vector2(0.34,0.5)
	c.enemy.pos = c.FIELD.size * Vector2(0.66,0.5)
	c.scars.clear()
	c.impacts.clear()
	c.notice = "FIELD CHANGE / " + LABELS[active].to_upper()
	c.notice_time = 4.0

func islands() -> Array:
	return [Vector2(816,600),Vector2(1584,600),Vector2(1200,320),Vector2(1200,880),Vector2(500,330),Vector2(1900,870)]

func in_water(p: Vector2) -> bool:
	if active not in [4,9] or not Rect2(240,170,1920,860).has_point(p): return false
	for center in islands():
		if ((p-center)/Vector2(145,100)).length_squared() <= 1: return false
	return true

func movement(f) -> float:
	var types = preload("res://status_rules.gd").types(f)
	if in_water(f.pos) and "Water" not in types and "Flying" not in types: return 0.78
	if active == 5 and "Ice" in types: return 1.15
	return 1.0

func polygon(c, points, color):
	c.draw_colored_polygon(PackedVector2Array(points),color)

func tree(c, p: Vector2, scale: float):
	c.draw_ellipse(p+Vector2(12,8),Vector2(65,25)*scale,Color(0.02,0.09,0.06,0.25))
	c.draw_rect(Rect2(p+Vector2(-8,-63)*scale,Vector2(16,66)*scale),Color("745541"))
	for item in [[Vector2(-26,-75),42],[Vector2(29,-85),43],[Vector2(0,-115),50]]:
		var v: Vector2 = p+item[0]*scale
		c.draw_circle(v,item[1]*scale,Color("235c4b"))
		c.draw_circle(v+Vector2(-8,-7)*scale,item[1]*scale*0.74,Color("397958"))
		c.draw_arc(v,item[1]*scale*0.7,3.7,5.5,12,Color("6b9e68"),3)

func building(c, p: Vector2, color: Color):
	c.draw_rect(Rect2(p+Vector2(-65,-40),Vector2(150,68)),Color(0.04,0.06,0.1,0.22))
	c.draw_rect(Rect2(p-Vector2(65,95),Vector2(130,105)),color)
	polygon(c,[p+Vector2(-77,-95),p+Vector2(0,-141),p+Vector2(77,-95)],Color("685477"))
	c.draw_line(p+Vector2(-77,-95),p+Vector2(0,-141),Color("ab8e9f"),5)
	for x in [-43,24]:
		c.draw_rect(Rect2(p+Vector2(x,-72),Vector2(23,29)),Color("8bc9ce"))
		c.draw_line(p+Vector2(x+11,-72),p+Vector2(x+11,-43),Color("e3e1c4"),2)
	c.draw_rect(Rect2(p+Vector2(-13,-28),Vector2(26,38)),Color("504756"))

func draw(c):
	var base = Color("68895e")
	if active in [3,8]: base = Color("ac9373") if active == 3 else Color("a8765c")
	if active in [4,9]: base = Color("3c8193")
	if active == 5: base = Color("9cc6cd")
	if active == 6: base = Color("477459")
	if active == 7: base = Color("8c9499")
	c.draw_rect(c.FIELD,Color("293b50"))
	c.draw_rect(Rect2(140,130,2120,940),base)
	# Fixed seeds keep terrain still while waves and stadium lights animate.
	var random = RandomNumberGenerator.new()
	random.seed = 6400+active
	for i in range(430):
		var p = Vector2(random.randf_range(170,2230),random.randf_range(160,1040))
		if active in [1,2,6]:
			var color = base.lightened(random.randf_range(0.03,0.18))
			c.draw_line(p,p+Vector2(2,-7),color,2)
			c.draw_line(p,p+Vector2(-4,-5),color,1)
		elif active in [3,8]:
			c.draw_line(p,p+Vector2(12,-3),base.darkened(0.12),2)
			if i%5 == 0:
				c.draw_polyline(PackedVector2Array([p,p+Vector2(22,-12),p+Vector2(35,-8),p+Vector2(47,-30)]),base.darkened(0.24),2)
		elif active == 5:
			c.draw_line(p,p+Vector2(30,12),Color(0.9,1,1,0.22),2)
	if active in [1,2]:
		for x in range(240,2200,240): c.draw_rect(Rect2(x,170,120,860),Color(0.7,0.85,0.6,0.04))
		if active == 2:
			for i in range(60):
				var p = Vector2(260+i*32,210 if i%2==0 else 990)
				c.draw_circle(p,4,Color("e5c889") if i%3==0 else Color("b7d3af"))
	if active in [4,9]:
		c.draw_rect(Rect2(240,170,1920,860),Color("256b89"))
		for y in range(200,1020,45):
			for x in range(270,2140,90):
				var p = Vector2(x+sin(c.clock_time*1.1+y)*12,y)
				c.draw_arc(p,30,0.1,2.6,12,Color(0.5,0.86,0.91,0.2),2,true)
		for p in islands():
			c.draw_ellipse(p+Vector2(0,8),Vector2(153,104),Color("194e70"))
			c.draw_ellipse(p,Vector2(145,100),Color("d6ceae") if active==4 else Color("b4aa90"))
			c.draw_ellipse(p-Vector2(0,4),Vector2(130,86),Color("9dad84") if active==4 else Color("8c9184"))
	if active == 5:
		for i in range(24):
			var p = Vector2(random.randf_range(250,2150),random.randf_range(210,990))
			polygon(c,[p+Vector2(-75,0),p+Vector2(-30,-40),p+Vector2(68,-25),p+Vector2(90,22),p+Vector2(-10,55)],Color(0.8,0.95,1,0.23))
			c.draw_polyline(PackedVector2Array([p+Vector2(-75,0),p+Vector2(-30,-40),p+Vector2(68,-25)]),Color("d3edf0"),3)
		for x in range(300,2150,190):
			var p = Vector2(x,230 if x%3==0 else 1020)
			polygon(c,[p+Vector2(-26,0),p+Vector2(-12,-55),p+Vector2(20,-75),p+Vector2(35,-4)],Color("d5eef2"))
	if active == 6:
		for x in range(300,2200,160):
			tree(c,Vector2(x,280),0.85)
			tree(c,Vector2(x+35,1040),1.0)
		for p in [Vector2(400,600),Vector2(2000,600),Vector2(1200,360),Vector2(1200,980)]: tree(c,p,0.85)
	if active == 7:
		c.draw_rect(Rect2(220,470,1960,260),Color("626f7c"))
		c.draw_rect(Rect2(1080,170,240,860),Color("626f7c"))
		for x in range(260,2140,90): c.draw_rect(Rect2(x,596,44,5),Color("ddce99"))
		for y in range(180,1040,80): c.draw_rect(Rect2(1196,y,5,35),Color("ddce99"))
		for x in range(400,2100,330):
			building(c,Vector2(x,340),Color("cebca3"))
			building(c,Vector2(x+30,980),Color("b9adb1"))
	# Pale boundary paint and central Poké Ball are shared tournament landmarks.
	var white = Color(0.95,0.96,0.88,0.6)
	c.draw_rect(Rect2(240,170,1920,860),white,false,4)
	c.draw_line(Vector2(1200,170),Vector2(1200,1030),Color(white,0.23),3)
	c.draw_arc(Vector2(1200,600),120,0,TAU,64,Color(white,0.3),4,true)
	c.draw_arc(Vector2(1200,600),25,0,TAU,32,Color(white,0.4),4,true)
	c.draw_line(Vector2(1080,600),Vector2(1175,600),Color(white,0.3),4)
	c.draw_line(Vector2(1225,600),Vector2(1320,600),Color(white,0.3),4)
	# Crowd tiers, LED ribbons and protected trainer decks stay on the perimeter.
	for y in [15,46,77,1110,1141,1172]:
		c.draw_rect(Rect2(150,y,2100,26),Color("35465e"))
		for x in range(170,2230,23):
			var col = [Color("b8c9bd"),Color("699fa6"),Color("d3ad8b"),Color("9c8db0")][(x/23+y)%4]
			c.draw_circle(Vector2(x,y+7),3.5,col)
			c.draw_rect(Rect2(x-4,y+12,8,7),col.darkened(0.25))
	for y in [135,1060]:
		c.draw_rect(Rect2(145,y,2110,6),Color("73c8d4"))
	for x in [77,2323]:
		c.draw_rect(Rect2(x-45,575,90,120),Color("a8b9c1"))
		c.draw_rect(Rect2(x-40,580,80,108),Color("4b6077"))
		c.draw_line(Vector2(x-35,690),Vector2(x+35,690),Color("e2d4a5"),4)

func tests(c):
	for choice in range(11):
		reset(c,choice)
		c.check(active>=0 and active<10,"Every arena choice resolves to a playable field")
		for rock in c.rocks:
			c.check(rock.pos.distance_to(Vector2(816,600))>100 and rock.pos.distance_to(Vector2(1584,600))>100,"Terrain leaves spawn positions clear")
	active = 4
	c.check(not in_water(Vector2(816,600)) and in_water(Vector2(1200,600)),"Water islands and channels match their visual areas")
	var f = {"pos":Vector2(1200,600),"data":{"types":["Fire"]}}
	c.check(movement(f)==0.78,"Land Pokémon wade slower")
	f.data.types = ["Water"]
	c.check(movement(f)==1.0,"Water Pokémon swim freely")
	active = 5
	f.data.types = ["Ice"]
	c.check(movement(f)==1.15,"Ice types have ice field mobility")
	c.pick(25,7)
	reset(c,10)
	var first = active
	c.enemy_active = 2
	intermission(c)
	c.check(active==first and not changed,"No early field change")
	c.enemy_active = 3
	intermission(c)
	c.check(active!=first and changed,"Three knockouts trigger a different field")
	first = active
	intermission(c)
	c.check(active==first,"Only one halftime change per match")
	c.team_mode = true
	c.start_match()
	reset(c,10)
	first = active
	c.enemy_active = 0
	for i in range(3): c.player_states[i].hp = 0
	intermission(c)
	c.check(active!=first and changed,"Player losses also trigger halftime")
	c.arena_choice.select(4)
	c.start_match()
	c.check(active==4 and c.rocks.is_empty(),"Menu selection loads the water field without hidden rocks")
	c.arena_choice.select(10)
	c.start_match()
	first = active
	for i in range(3):
		c.enemy.hp = 0
		c.finish_round()
		c.shots.clear()
		c.result_time = c.FAINT_RESULT_TIME
		c.advance_team()
	c.check(changed and active!=first and c.enemy_active==3,"Full team battle changes field at the third knockout")
	c.arena_choice.select(0)
	c.pick(25,7)
	reset(c,0)
