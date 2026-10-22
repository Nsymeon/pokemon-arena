extends RefCounted

var vfx = preload("res://move_vfx.gd").new()

var trainers = preload("res://trainer_art.gd").new()
var cave = preload("res://cavern_art.gd").new()
var library = {}
var scales = {}

func load_sprites():
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/animated/manifest.json"))
	for id in manifest:
		var entry = manifest[id]
		for name in entry:
			var anim = entry[name]
			var image = Image.load_from_file(anim.path)
			anim["texture"] = ImageTexture.create_from_image(image)
			anim["rows"] = image.get_height() / int(anim.height)
			if name == "Idle":
				var used = image.get_region(Rect2i(0, 0, int(anim.width), int(anim.height))).get_used_rect()
				scales[int(id)] = clampf(86.4 / maxf(used.size.x, used.size.y), 1.92, 3.6)
		library[int(id)] = entry

func frame(fighter: Dictionary) -> Dictionary:
	var entry: Dictionary = library.get(int(fighter.data.id), {})
	if entry.is_empty(): return {}
	var state = "Idle"
	if fighter.get("walk_time", 0.0) > 0: state = "Walk"
	if fighter.get("attack_time", 0.0) > 0: state = fighter.get("attack_anim", "Attack")
	if fighter.flash > 0 and fighter.get("attack_time", 0.0) <= 0: state = "Hurt"
	if not entry.has(state): state = "Walk" if entry.has("Walk") else entry.keys()[0]
	var anim: Dictionary = entry[state]
	var duration = 0.0
	for ticks in anim.durations: duration += float(ticks) / 60.0
	var age: float = fighter.get("anim_age", 0.0)
	if state in ["Attack", "Shoot"]: age = (0.55 - fighter.get("attack_time", 0.0)) * duration / 0.55
	if state == "Hurt": age = (0.15 - fighter.flash) * duration / 0.15
	var t = fposmod(age, maxf(duration, 0.01))
	var column = 0
	for ticks in anim.durations:
		if t < float(ticks) / 60.0: break
		t -= float(ticks) / 60.0
		column += 1
	column = mini(column, anim.durations.size() - 1)
	var heading: Vector2 = fighter.get("heading", Vector2(fighter.face, 0))
	if state in ["Attack", "Shoot"]: heading = fighter.get("attack_heading", heading)
	# PMD rows run down, down-right, right, up-right, up, up-left, left, down-left.
	var row = posmod(roundi((PI / 2 - heading.angle()) / (PI / 4)), 8)
	if anim.rows == 1: row = 0
	row = mini(row, int(anim.rows) - 1)
	return {"texture": anim.texture, "region": Rect2(column * anim.width, row * anim.height, anim.width, anim.height), "size": Vector2(anim.width, anim.height) * scales.get(int(fighter.data.id), 2.0)}

func tests(c):
	c.pick(25,7)
	for fighter in [c.player,c.enemy]:
		fighter.attack_time=0.31
		fighter.attack_anim="Attack"
		fighter.attack_heading=Vector2.RIGHT if fighter==c.player else Vector2.LEFT
		fighter.flash=0
		var attacking=frame(fighter)
		fighter.flash=0.15
		var simultaneous=frame(fighter)
		c.check(attacking.texture==simultaneous.texture and attacking.region==simultaneous.region,"Receiving damage preserves each fighter's attack frame")
		fighter.attack_time=0
		var hurt=frame(fighter)
		var entry: Dictionary=library[int(fighter.data.id)]
		if entry.has("Hurt"): c.check(hurt.texture==entry.Hurt.texture,"Hurt animation remains available outside attacks")
	var expected={"razorleaf":"leaf","vinewhip":"vine","bubblebeam":"bubble","hypnosis":"hypnosis","sleeppowder":"powder","crunch":"bite","thunderpunch":"punch","megakick":"kick","aurasphere":"aura"}
	for id in expected: c.check(vfx.family(c.move_editor.book.moves[id])==expected[id],"Recognizable VFX family: "+id)
	for move in c.move_editor.book.moves.values(): c.check(not vfx.family(move).is_empty(),"VFX coverage: "+move.id)

func arena(c):
	if c.fields.active == 0: cave.draw(c)
	else: c.fields.draw(c)

func shot(c, s):
	vfx.shot(c, s)

func attack_effect(c, fighter):
	vfx.cast(c, fighter)

func impact(c, effect):
	vfx.impact(c, effect)
	var t: float = effect.age / 0.65
	var alpha = 1 - t
	var p: Vector2 = effect.pos
	var color = c.Dex.color(effect.type)
	var radius: float = (12 + t * 64) * effect.strength
	c.draw_circle(p, radius * 0.7, Color(color, alpha * 0.12))
	if t < 0.2: c.draw_circle(p, 18 * (1 - t * 5), Color(1, 1, 0.9, 0.85))
	for i in range(12):
		var dir = Vector2.from_angle(i * TAU / 12 + sin(i * 5.7) * 0.15)
		var end = p + dir * radius * (0.65 + absf(sin(i * 13.1)) * 0.55)
		if effect.type == "Fire":
			c.draw_circle(end + Vector2(0, -t * 45), (9 + i % 4 * 3) * t, Color(0.18, 0.2, 0.22, alpha * 0.3))
			c.draw_circle(end, (8 + i % 3 * 3) * alpha, Color("ff943f", alpha))
			c.draw_circle(end - Vector2(0, t * 20), 4 * alpha, Color("ffef9e", alpha))
		elif effect.type in ["Water", "Ice"]:
			var point = end + Vector2(0, t * t * 55)
			c.draw_line(point - dir * 9, point, Color("bcf9ff", alpha), 3)
		elif effect.type == "Electric":
			var points = PackedVector2Array([p + dir * radius * 0.3, end + dir.orthogonal() * 10, end + dir * 18])
			c.draw_polyline(points, Color("ffe683", alpha), 3)
		elif effect.type in ["Rock", "Ground", "Steel"]:
			c.draw_colored_polygon(PackedVector2Array([end + Vector2(-5, 5), end + Vector2(0, -8), end + Vector2(7, 4)]), Color(color, alpha))
		else:
			c.draw_line(p + dir * radius * 0.55, end, Color(color, alpha), 3)
	c.draw_arc(p, radius, 0, TAU, 48, Color(color, alpha * 0.7), 2)

func ring(c, effect):
	var alpha = clampf(effect.life * 2, 0, 1)
	var radius: float = effect.radius
	var p: Vector2 = effect.pos
	var color: Color = effect.color
	c.draw_arc(p, radius, 0, TAU, 64, Color(color, alpha * 0.15), 16)
	c.draw_arc(p, radius, 0, TAU, 64, Color(color, alpha), 3)
	if effect.get("type", "") == "Water":
		for i in range(14):
			var angle = i * TAU / 14
			var point = p + Vector2.from_angle(angle) * radius
			c.draw_arc(point, 13, angle - PI, angle, 12, Color("ceffff", alpha), 3)
	elif effect.get("type", "") in ["Ground", "Rock"]:
		for i in range(12):
			var dir = Vector2.from_angle(i * TAU / 12)
			var point = p + dir * radius
			c.draw_line(p + dir * radius * 0.65, point, Color("5f6260", alpha), 4)
			c.draw_colored_polygon(PackedVector2Array([point + Vector2(-7, 6), point + Vector2(0, -15), point + Vector2(8, 6)]), Color(color, alpha))
	else:
		c.draw_arc(p, radius * 0.85, 0, TAU, 48, Color(color, alpha * 0.35), 2)

func hall_details(c):
	var width: float = c.FIELD.size.x
	var height: float = c.FIELD.size.y
	# An inset championship dais, steps, carpet and wall crest.
	for i in range(4):
		c.draw_rect(Rect2(width / 2 - 110 - i * 8, 50 + i * 9, 220 + i * 16, 10), Color("8c9fab"))
		c.draw_line(Vector2(width / 2 - 110 - i * 8, 50 + i * 9), Vector2(width / 2 + 110 + i * 8, 50 + i * 9), Color("c9d4cd"), 2)
	c.draw_rect(Rect2(width / 2 - 38, 1, 76, 88), Color("764651"))
	c.draw_rect(Rect2(width / 2 - 34, 1, 68, 88), Color("a34f58"))
	c.draw_line(Vector2(width / 2 - 30, 0), Vector2(width / 2 - 30, 88), Color("dab77b"), 2)
	c.draw_line(Vector2(width / 2 + 30, 0), Vector2(width / 2 + 30, 88), Color("dab77b"), 2)
	for x in [170.0, width - 170]:
		for y in [55.0, height - 55]:
			var sign = 1 if y < height / 2 else -1
			c.draw_rect(Rect2(x - 19, y - 5, 38, 10), Color("d0b47c"))
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 16, y), Vector2(x + 16, y), Vector2(x + 16, y + 72 * sign), Vector2(x, y + 59 * sign), Vector2(x - 16, y + 72 * sign)]), Color("416782"))
			c.draw_circle(Vector2(x, y + 27 * sign), 9, Color("d9bd78"))
			c.draw_circle(Vector2(x, y + 27 * sign), 5, Color("416782"))
	# Floor inlay lines leave an open central fighting area.
	for x in [125.0, width - 125]:
		c.draw_line(Vector2(x, 140), Vector2(x, height - 140), Color(0.85, 0.9, 0.8, 0.3), 2)
	for x in range(300, int(width) - 200, 200):
		for y in [115.0, height - 115]:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 5, y), Vector2(x, y - 5), Vector2(x + 5, y), Vector2(x, y + 5)]), Color("bdc6ab"))

func trainer_shape(c, p: Vector2, facing: float, points: Array, color: Color):
	var vertices = PackedVector2Array()
	for point in points: vertices.append(p + Vector2(point[0] * facing, point[1]))
	c.draw_colored_polygon(vertices, color)

func trainer(c, friendly: bool):
	var feet: Vector2 = c.trainer_position(friendly)
	var identity = "red" if friendly else c.opponent_identity
	var fighter = c.player if friendly else c.enemy
	var elapsed = c.SEND_OUT_TIME - c.countdown
	var ball = not fighter.get("entering", true) or c.countdown <= 0 or elapsed < 0.25 or elapsed >= 2.4
	trainers.draw(c,feet,identity,1.0 if friendly else -1.0,c.trainer_hand(friendly),ball)
	c.label_at("YOU" if friendly else c.opponent_name().to_upper(),feet+Vector2(-20,24),11,c.MINT if friendly else c.GOLD)
