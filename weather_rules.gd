extends RefCounted

# Shared arena weather; no species IDs here, so future rosters use the same rules.
const MODES = ["clear", "sun", "rain", "sand", "hail", "dynamic"]
const LABELS = ["Clear sky", "Harsh sunlight", "Rain", "Sandstorm", "Hail", "Changing weather"]
const MOVES = {"sunnyday":"sun", "raindance":"rain", "sandstorm":"sand", "hail":"hail", "snowscape":"snow"}
var mode = "clear"
var kind = "clear"
var remaining = -1.0
var chip_clock = 0.0
var cycle = 0

func reset(selected: int):
	mode = MODES[selected]
	cycle = 0
	restore()

func restore():
	kind = MODES[cycle % 5] if mode == "dynamic" else mode
	remaining = 25.0 if mode == "dynamic" else -1.0
	chip_clock = 0.0

func set_weather(value: String, duration: float = 20.0):
	kind = value
	remaining = duration
	chip_clock = 0.0

func tick(c, dt: float):
	# Only called during active combat: pause, substitutions and recalls freeze time.
	var active = minf(dt, remaining) if remaining >= 0 else dt
	chip_clock += active
	while chip_clock >= 1.0:
		chip_clock -= 1.0
		for f in [c.player, c.enemy]:
			var immune = kind == "sand" and ("Rock" in preload("res://status_rules.gd").types(f) or "Ground" in preload("res://status_rules.gd").types(f) or "Steel" in preload("res://status_rules.gd").types(f))
			immune = immune or (kind == "hail" and "Ice" in preload("res://status_rules.gd").types(f))
			if kind in ["sand", "hail"] and not immune and f.hp > 0 and f.volatile.get("underground",0)<=0:
				f.hp = maxf(0, f.hp - f.data.hp * 0.01)
				c.Conditions.note(f, kind.to_upper())
	if remaining >= 0:
		remaining = maxf(0, remaining - dt)
		if remaining <= 0:
			if mode == "dynamic": cycle += 1
			restore()

func prepare(original: Dictionary) -> Dictionary:
	var move = original.duplicate(true)
	if move.get("weather_prepared", false): return move
	move["weather_prepared"] = true
	var id: String = move.get("id", "")
	if id == "weatherball" and kind != "clear":
		move.type = {"sun":"Fire", "rain":"Water", "sand":"Rock", "hail":"Ice", "snow":"Ice"}.get(kind, "Normal")
		move.damage *= 2.0
	move["weather_power"] = power(move)
	move["area_scale"] = 1.12 if (kind == "sun" and move.get("type", "") == "Fire") or (kind == "rain" and move.get("type", "") == "Water") else 1.0
	if id in ["solarbeam", "solarblade"] and kind == "sun":
		move.charge_time = 0.0
		move.action_delay = 1.0
	return move

func power(move: Dictionary) -> float:
	var type: String = move.get("type", "Normal")
	if move.get("id", "") in ["solarbeam", "solarblade"] and kind in ["rain", "sand", "hail", "snow"]: return 0.5
	if kind == "sun": return 1.5 if type == "Fire" else 0.5 if type == "Water" else 1.0
	if kind == "rain": return 1.5 if type == "Water" else 0.5 if type == "Fire" else 1.0
	return 1.0

func accuracy(move: Dictionary, normal: float) -> float:
	if move.get("id", "") in ["thunder", "hurricane"]:
		if kind == "rain": return 1.0
		if kind == "sun": return 0.5
	if move.get("id", "") == "blizzard" and kind in ["hail", "snow"]: return 1.0
	return normal

func healing(move: Dictionary) -> float:
	if move.get("id", "") in ["synthesis", "moonlight", "morningsun"]:
		return 1.0 / 3.0 if kind == "sun" else 0.125 if kind != "clear" else 0.25
	return 0.25

func defense(target, physical: bool) -> float:
	if kind == "sand" and "Rock" in preload("res://status_rules.gd").types(target) and not physical: return 1.5
	if kind == "snow" and "Ice" in preload("res://status_rules.gd").types(target) and physical: return 1.5
	return 1.0

func draw(c):
	var rect = Rect2(40,180,1200,600)
	if kind == "sun":
		c.draw_rect(rect, Color(1.0,0.76,0.25,0.07))
		for i in range(5):
			var x = 150 + i * 210
			c.draw_colored_polygon(PackedVector2Array([Vector2(x,180),Vector2(x+36,180),Vector2(x+200,780),Vector2(x+90,780)]),Color(1,0.94,0.65,0.04))
	elif kind != "clear":
		c.draw_rect(rect, Color(0.07,0.15,0.3,0.10) if kind == "rain" else Color(0.65,0.42,0.16,0.08) if kind == "sand" else Color(0.75,0.9,1,0.06))
		for i in range(80):
			var speed = 430 if kind == "rain" else 180
			var x = 50 + fposmod(i * 137.7 + c.clock_time * (75 if kind == "sand" else -38), 1170)
			var y = 190 + fposmod(i * 71.3 + c.clock_time * speed, 570)
			if kind == "rain": c.draw_line(Vector2(x,y),Vector2(x-5,y+18),Color(0.7,0.88,1,0.35),1.5,true)
			else: c.draw_circle(Vector2(x,y),2 if kind == "sand" else 3,Color(0.8,0.65,0.35,0.4) if kind == "sand" else Color(0.9,0.97,1,0.6))
	var title: String = kind.to_upper() + (" / %ds" % ceili(remaining) if remaining >= 0 else "")
	var detail = {"sun":"FIRE x1.5 / WATER x0.5 / INSTANT SOLAR", "rain":"WATER x1.5 / FIRE x0.5", "sand":"ROCK Sp.DEF x1.5 / CHIP DAMAGE", "hail":"ICE IMMUNE TO HAIL / CHIP DAMAGE", "snow":"ICE DEF x1.5", "clear":"NO WEATHER MODIFIERS"}.get(kind, "")
	c.draw_rect(Rect2(52,192,405,48),Color(0.03,0.10,0.14,0.84))
	c.label_at(title,Vector2(64,212),14,c.GOLD)
	c.label_at(detail,Vector2(64,230),10,c.WHITE)

func tests(c):
	c.pick(6,9)
	var fire = {"id":"flamethrower","type":"Fire","category":"Special","damage":30}
	var clear: float = c.damage_amount(c.player,c.enemy,30,fire)
	set_weather("sun")
	c.check(absf(c.damage_amount(c.player,c.enemy,30,prepare(fire)) - clear * 1.5) < 0.11,"Sun boosts Fire damage")
	c.check(prepare(fire).area_scale == 1.12,"Sun enlarges Fire hit area")
	var solar = prepare({"id":"solarbeam","type":"Grass","damage":30,"charge_time":1,"action_delay":2})
	c.check(solar.charge_time == 0 and solar.action_delay == 1,"Sun removes Solar Beam charge and charge recovery")
	set_weather("rain")
	c.check(prepare(fire).weather_power == 0.5,"Rain weakens Fire")
	c.check(prepare({"id":"surf","type":"Water"}).area_scale == 1.12,"Rain enlarges Water")
	c.check(prepare({"id":"surf","type":"Water"}).weather_power == 1.5,"Rain boosts Water damage")
	c.check(prepare({"id":"solarbeam","type":"Grass"}).weather_power == 0.5,"Bad weather halves Solar Beam")
	c.check(accuracy({"id":"thunder"},0.7) == 1 and accuracy({"id":"thunderbolt"},0.75) == 0.75,"Rain accuracy only affects appropriate moves")
	c.check(solar.weather_power == 1,"Launched moves keep their weather snapshot")
	c.pick(95,87)
	set_weather("sand")
	var hp: float = c.player.hp
	var foe_hp: float = c.enemy.hp
	tick(c,1)
	c.check(c.player.hp == hp and c.enemy.hp < foe_hp,"Sand immunities and chip damage")
	c.check(defense(c.player,false) == 1.5 and defense(c.player,true) == 1.0,"Sand boosts only Rock special defense")
	set_weather("hail")
	foe_hp = c.enemy.hp
	tick(c,1)
	c.check(c.enemy.hp == foe_hp,"Ice is immune to hail")
	reset(0)
	set_weather("rain",0.1)
	tick(c,0.2)
	c.check(kind == "clear","Temporary weather restores arena baseline")
	reset(5)
	tick(c,25)
	c.check(kind == "sun" and remaining == 25,"Dynamic weather advances after combat timer")
	reset(0)
	for pair in [[38,"sun"],[55,"rain"],[28,"sand"],[87,"hail"]]:
		c.pick(pair[0],9)
		c.check(c.use_move(c.player,c.enemy,3,Vector2.RIGHT,true) and kind == pair[1],"Weather setter launches: " + pair[1])
		c.check(c.player.action_lock == 1 and remaining == 20,"Weather move shares action gate and duration")
	c.pick(3,9)
	set_weather("sun")
	c.use_move(c.player,c.enemy,2,Vector2.RIGHT,true)
	c.check(c.player.charge_left == 0 and c.shots.size() == 1,"Solar Beam actually launches immediately in sun")
	c.reset()
