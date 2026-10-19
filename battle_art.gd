extends RefCounted

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
	if fighter.flash > 0: state = "Hurt"
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

func arena(c):
	if c.fields.active == 0: cave.draw(c)
	else: c.fields.draw(c)

func shot(c, s):
	# Collision uses ground positions; artwork travels at the Pokémon's body height.
	s = s.duplicate()
	s.pos -= Vector2(0, 42)
	var dir: Vector2 = s.vel.normalized()
	var side = dir.orthogonal()
	var type: String = s.move.get("type", "Normal")
	if s.move.get("id", "") in ["shadowball", "energyball", "aurasphere"]:
		var radius: float = s.radius + 8
		for i in range(9,0,-1):
			var p = s.pos-dir*i*9+side*sin(s.age*15-i)*5
			c.draw_circle(p,radius*(1-i/11.0),Color(s.color,(1-i/10.0)*0.15))
		for layer in range(4,0,-1): c.draw_circle(s.pos,radius+layer*7,Color(s.color,0.035*layer))
		c.draw_circle(s.pos,radius,Color("282039") if type == "Ghost" else s.color.darkened(0.2))
		for i in range(3):
			var angle = s.age*11+i*TAU/3
			c.draw_arc(s.pos,radius-3+i*3,angle,angle+PI*1.2,24,Color(s.color.lightened(0.45),0.9),3,true)
		c.draw_circle(s.pos-dir*5,radius*0.3,s.color.lightened(0.75))
		for i in range(5):
			var ray = Vector2.from_angle(i*TAU/5+s.age*4)
			c.draw_line(s.pos+ray*radius,s.pos+ray*(radius+10),Color(s.color,0.6),2,true)
		return
	if s.move.get("id", "") == "fireblast":
		var radius = (34 + sin(s.age * 24) * 4) * s.move.get("area_scale", 1.0)
		for i in range(5):
			var ray = Vector2.from_angle(i * TAU / 5 - PI/2 + s.age * 0.4)
			c.draw_line(s.pos, s.pos + ray * radius, Color(1,0.25,0.03,0.2),23,true)
			c.draw_line(s.pos, s.pos + ray * radius, Color("ff8f32"),12,true)
			c.draw_line(s.pos, s.pos + ray * radius * 0.85, Color("fff1ae"),4,true)
			c.draw_circle(s.pos - dir * (i*12+20) + side*sin(i+s.age*18)*10,6-i,Color(1,0.45,0.1,0.5))
		return
	if s.move.get("id", "") == "razorleaf":
		for i in range(3):
			var p = s.pos - dir*i*20 + side*sin(s.age*16+i)*12
			var leaf_dir = Vector2.from_angle(s.age*20+i)
			var leaf_side = leaf_dir.orthogonal()
			c.draw_colored_polygon(PackedVector2Array([p-leaf_dir*18,p+leaf_side*7,p+leaf_dir*18,p-leaf_side*7]),Color("b5eb65"))
			c.draw_line(p-leaf_dir*16,p+leaf_dir*16,Color("417e42"),2)
			c.draw_arc(p,22,s.age*20+i,s.age*20+i+PI,12,Color(0.8,1,0.6,0.4),2,true)
		return
	var beam = s.move.get("id", "") in ["flamethrower", "hydropump", "icebeam", "aurorabeam", "solarbeam", "hyperbeam", "dragonpulse", "waterpulse", "thunderbolt", "bubblebeam", "psybeam", "flashcannon"]
	var tail = 65.0 if type in ["Fire", "Water", "Dragon", "Ice"] else 35.0
	if beam:
		tail = minf(280, s.pos.distance_to(s.get("origin", s.pos - dir * 145) - Vector2(0, 42)))
		stream(c, s, s.pos - dir * tail, type, dir, side)
		return
	for i in range(7, 0, -1):
		var p: Vector2 = s.pos - dir * i * tail / 7 + side * sin(c.clock_time * 25 + i) * 4
		c.draw_circle(p, s.radius * (1 - i / 9.0) + 3, Color(s.color, (1 - i / 9.0) * 0.6))
	if type == "Electric":
		var points = PackedVector2Array()
		for i in range(9): points.append(s.pos - dir * i * 9 + side * sin(i * 14 + c.clock_time * 30) * 12)
		c.draw_polyline(points, Color(s.color, 0.25), 14)
		c.draw_polyline(points, s.color, 5)
		c.draw_polyline(points, Color("fffbe0"), 2)
	elif type in ["Flying", "Fighting", "Normal"]:
		c.draw_arc(s.pos - dir * 14, 26, dir.angle() - PI / 2, dir.angle() + PI / 2, 20, Color(s.color, 0.35), 10)
		c.draw_arc(s.pos - dir * 14, 26, dir.angle() - PI / 2, dir.angle() + PI / 2, 20, Color("f0f4e9"), 3)
	elif type in ["Grass", "Bug"]:
		for i in range(3):
			var p: Vector2 = s.pos - dir * i * 14
			c.draw_colored_polygon(PackedVector2Array([p + dir * 16, p + side * 8, p - dir * 16, p - side * 8]), s.color)
	elif type in ["Rock", "Ground", "Steel", "Ice"]:
		var points = PackedVector2Array()
		for i in range(6): points.append(s.pos + Vector2.from_angle(i * TAU / 6 + c.clock_time * 5) * (s.radius + 6))
		c.draw_colored_polygon(points, s.color)
		c.draw_line(points[0], points[3], Color.WHITE, 2)
	else:
		c.draw_circle(s.pos, s.radius + 8, Color(s.color, 0.18))
		c.draw_circle(s.pos, s.radius, s.color)
		c.draw_circle(s.pos - dir * 2, s.radius * 0.45, Color("fff3d3"))
		if type in ["Psychic", "Ghost", "Dark", "Fairy"]:
			c.draw_arc(s.pos, s.radius + 7, c.clock_time * 7, c.clock_time * 7 + PI * 1.5, 24, s.color, 3)

func attack_effect(c, fighter):
	var progress = 1 - fighter.attack_time / 0.55
	var color: Color = fighter.get("move_color", Color.WHITE)
	var direction: Vector2 = fighter.get("attack_heading", fighter.get("heading", Vector2.RIGHT))
	var kind: String = fighter.get("attack_kind", "")
	var area_scale: float = fighter.get("dash_move", {}).get("area_scale", 1.0)
	var p: Vector2 = fighter.pos + Vector2(0, -24)
	if kind == "dash":
		for i in range(3):
			var offset = direction.orthogonal() * (i - 1) * 14
			c.draw_arc(p + offset, (44 + i * 9) * area_scale, direction.angle() - 1.5 + progress, direction.angle() + 0.7 + progress, 28, Color(color, (1 - progress) * 0.4), 11)
			c.draw_arc(p + offset, 44 + i * 9, direction.angle() - 1.5 + progress, direction.angle() + 0.7 + progress, 28, Color(1, 1, 1, 1 - progress), 3)
	elif kind in ["bolt", "orb"] and progress < 0.4:
		var mouth: Vector2 = fighter.pos + Vector2(0, -42) + direction * 25
		c.draw_circle(mouth, 16 + progress * 20, Color(color, 0.3 * (1 - progress)))
		for i in range(7):
			var ray = Vector2.from_angle(i * TAU / 7 + progress) * (32 - progress * 45)
			c.draw_line(mouth + ray * 0.55, mouth + ray, Color(color, 1 - progress), 2)
	elif kind in ["pulse", "status", "buff", "heal", "guard"]:
		for i in range(6):
			var angle = i * TAU / 6 + progress * 2
			var ray = Vector2.from_angle(angle) * (35 + progress * 70)
			c.draw_line(p + ray * 0.75, p + ray, Color(color, 1 - progress), 4)

func stream(c, s, start: Vector2, type: String, dir: Vector2, side: Vector2):
	var length = start.distance_to(s.pos)
	var phase = c.clock_time * 22
	var area_scale: float = s.move.get("area_scale", 1.0)
	# Soft reflection on the tile floor beneath the stream.
	c.draw_line(start + Vector2(0, 43), s.pos + Vector2(0, 43), Color(s.color, 0.08), 23)
	if s.move.get("id", "") in ["solarbeam", "hyperbeam"]:
		c.draw_line(start, s.pos, Color(s.color, 0.09), 68)
		c.draw_line(start, s.pos, Color(s.color, 0.2), 42)
		c.draw_line(start, s.pos, s.color, 23)
		c.draw_line(start, s.pos, Color("ffffdc"), 10)
		for i in range(10):
			var point = start.lerp(s.pos, i / 9.0)
			var radius = 20 + sin(phase + i) * 5
			c.draw_arc(point, radius, phase + i, phase + i + PI * 1.5, 24, Color(s.color, 0.8), 2)
		for i in range(8):
			var ray = Vector2.from_angle(i * TAU / 8 + phase * 0.1)
			c.draw_line(s.pos + ray * 12, s.pos + ray * (32 + i % 2 * 12), Color("fffee1"), 3)
	elif type == "Electric":
		var points = PackedVector2Array()
		for i in range(17): points.append(start.lerp(s.pos, i / 16.0) + side * sin(i * 17 + floor(phase)) * 16 * sin(i * PI / 16))
		c.draw_polyline(points, Color(1, 0.8, 0.1, 0.15), 26)
		c.draw_polyline(points, Color("ffd557"), 7)
		c.draw_polyline(points, Color("fffde2"), 2)
		for i in [4, 8, 12]:
			var branch = points[i] + side * sin(i + phase) * 40 - dir * 15
			c.draw_line(points[i], branch, Color("ffe692"), 2)
	elif type == "Fire":
		var top = PackedVector2Array()
		var bottom = PackedVector2Array()
		for i in range(19):
			var t = i / 18.0
			var p = start.lerp(s.pos, t)
			var width = (4 + t * 20) * (0.8 + sin(i * 2.5 - phase) * 0.2)
			top.append(p + side * width)
			bottom.insert(0, p - side * width)
		c.draw_colored_polygon(top + bottom, Color(1, 0.25, 0.08, 0.8))
		for i in range(20):
			var t = i / 19.0
			var p = start.lerp(s.pos, t) + side * sin(i * 1.9 - phase) * (3 + t * 10)
			c.draw_circle(p, 4 + t * 11, Color("ffab3e"))
			c.draw_circle(p - side * 2, 2 + t * 5, Color("fff4b2"))
			if i % 3 == 0: c.draw_circle(p + side * sin(i * 7 + phase) * 35, 2, Color("ffd98b"))
		for i in range(9):
			var t = fposmod(phase * 0.07 + i * 0.113, 1)
			var point = start.lerp(s.pos, t) + side * sin(i * 9 + phase * 0.2) * 21
			c.draw_line(point - dir * 9, point + Vector2(0, -5), Color("fff0b0"), 2)
	elif type == "Water":
		c.draw_line(start, s.pos, Color(0.2, 0.55, 0.95, 0.2), 42 * area_scale)
		c.draw_line(start, s.pos, Color("3686d1"), 23 * area_scale)
		for strand in range(3):
			var points = PackedVector2Array()
			for i in range(24): points.append(start.lerp(s.pos, i / 23.0) + side * sin(i * 0.65 - phase + strand * TAU / 3) * 9)
			c.draw_polyline(points, Color("c8f8ff") if strand == 0 else Color("69cfed"), 4)
		for i in range(7):
			var p: Vector2 = s.pos - dir * i * minf(length / 7, 24) + side * sin(phase + i * 3) * 25
			c.draw_circle(p, 3, Color("d4ffff"))
		for i in range(4):
			var point: Vector2 = start.lerp(s.pos, (i + 0.5) / 4.0)
			c.draw_arc(point, 17, dir.angle() - PI / 2, dir.angle() + PI / 2, 20, Color(0.8, 1, 1, 0.7), 2)
	else:
		c.draw_line(start, s.pos, Color(s.color, 0.12), 38)
		c.draw_line(start, s.pos, Color(s.color, 0.3), 23)
		c.draw_line(start, s.pos, s.color, 12)
		c.draw_line(start, s.pos, Color("fffef2"), 4)
		for i in range(7):
			var p: Vector2 = start.lerp(s.pos, i / 6.0)
			if type == "Ice":
				var point = p + side * sin(phase + i) * 18
				c.draw_colored_polygon(PackedVector2Array([point + dir * 11, point + side * 5, point - dir * 11, point - side * 5]), Color("d6ffff"))
			else: c.draw_arc(p, 14 + sin(phase + i) * 3, phase + i, phase + i + PI * 1.5, 20, Color(s.color, 0.6), 2)
	c.draw_circle(s.pos, 21, Color(s.color, 0.15))
	c.draw_circle(s.pos, 7, Color("fff8de"))

func impact(c, effect):
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
