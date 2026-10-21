extends RefCounted

var areas = preload("res://area_skills.gd").new()

const BEAMS = ["solarbeam", "hyperbeam", "icebeam", "aurorabeam", "hydropump", "flamethrower"]
const RUSHES = ["quickattack", "extremespeed", "aquajet"]

func rush_position(s, progress: float) -> Vector2:
	var t = clampf(progress, 0, 1)
	var lateral = 0.0
	if s.move.id == "quickattack":
		var offsets = [0.0, 48.0, -48.0, 42.0, -32.0, 0.0]
		var segment = mini(4, int(t * 5))
		lateral = lerpf(offsets[segment], offsets[segment + 1], t * 5 - segment) * minf(1, s.origin.distance_to(s.end) / 180)
	return s.origin.lerp(s.end, t) + s.dir.orthogonal() * lateral

func launch_rush(c, user, target, move, friendly):
	var reach = 420.0 if move.id == "extremespeed" else 320.0
	var delta: Vector2 = (target.pos - user.pos).limit_length(reach)
	var duration = 0.24 if move.id == "extremespeed" else 0.42
	c.shots.append({"skill":"rush", "move":move.duplicate(true), "owner":user, "attack_snapshot":user.duplicate(true), "friendly":friendly, "origin":user.pos, "end":user.pos + delta, "pos":user.pos, "dir":delta.normalized(), "age":0.0, "life":duration + 0.18, "duration":duration, "hit_done":false, "trail":[user.pos], "color":c.Dex.color(move.type)})

func tick_rush(c, s, dt):
	var before: float = s.age
	s.age += dt
	s.life -= dt
	var target = c.enemy if s.friendly else c.player
	# Quick Attack follows its target within the original reach instead of hitting an empty launch position.
	if s.move.id=="quickattack" and before<s.duration and target.hp>0:
		s.end = s.origin+(target.pos-s.origin).limit_length(320)
		s.dir = (s.end-s.origin).normalized()
	# Subdivide along the zigzag so low frame rates cannot skip collisions.
	var steps = maxi(1, int(ceil(minf(dt, s.duration) / 0.008)))
	for i in range(steps):
		var old: Vector2 = s.pos
		s.pos = rush_position(s, lerpf(before, s.age, (i + 1.0) / steps) / s.duration)
		if before < s.duration+0.12 and not s.hit_done and target.pos.distance_to(Geometry2D.get_closest_point_to_segment(target.pos, old, s.pos)) <= 40:
			var dealt = c.hit(target, s.move.damage, s.dir, s.friendly, s.move, s.owner, s.attack_snapshot)
			s.hit_done = dealt>0 or c.Dex.effectiveness(s.move.type,c.Conditions.types(target))==0
	if s.owner.hp > 0 and c.result == "": c.move_fighter(s.owner, s.pos - s.owner.pos)
	s.trail.append(s.pos)
	if s.trail.size() > 24: s.trail.pop_front()

func draw_rush(c, s):
	var fade = clampf(s.life / 0.18, 0, 1)
	var path = PackedVector2Array()
	for point in s.trail: path.append(point + Vector2(0,-24))
	if path.size() > 1:
		c.draw_polyline(path, Color(s.color, 0.18 * fade), 26, true)
		c.draw_polyline(path, Color(s.color.lightened(0.5), 0.7 * fade), 8, true)
		c.draw_polyline(path, Color(1,1,1,0.9 * fade), 2, true)
	var center: Vector2 = s.pos + Vector2(0,-24)
	if s.move.id == "aquajet":
		var oval = PackedVector2Array()
		for i in range(49):
			var a = i * TAU / 48
			oval.append(center + s.dir * cos(a) * 58 + s.dir.orthogonal() * sin(a) * 34)
		c.draw_colored_polygon(oval, Color(0.12,0.65,1,0.4 * fade))
		c.draw_polyline(oval, Color(0.65,0.96,1,0.9 * fade), 4, true)
		for i in range(12):
			var a = i * TAU / 12 + s.age * 18
			c.draw_circle(center + s.dir*cos(a)*50 + s.dir.orthogonal()*sin(a)*28, 3, Color(0.8,1,1,fade))
	else:
		for i in range(4):
			var side: Vector2 = s.dir.orthogonal() * (i-1.5)*13
			c.draw_line(center + side - s.dir*55, center + side + s.dir*22, Color(1,1,0.85,fade*0.65), 2, true)

func beam_range(move) -> float:
	return {"flamethrower":520.0,"hydropump":575.0,"icebeam":650.0,"aurorabeam":600.0,"hyperbeam":900.0}.get(move.get("id",""),1150.0)

func front_length(s, age: float) -> float:
	var speed = 25000.0 if s.move.id == "solarbeam" else 1200.0
	return minf(beam_range(s.move), maxf(0,age)*speed)

func visible_length(s) -> float:
	return minf(s.get("clash_limit",beam_range(s.move)), front_length(s,s.age) if s.has("age") else beam_range(s.move))

func beam_half_width(s) -> float:
	return (20.0 if s.get("move",{}).get("id","")=="icebeam" else 28.0 if s.get("move",{}).get("id","") == "flamethrower" else 34.0 if s.get("move",{}).get("id","") == "hydropump" else 48.0) * s.get("scale",1.0)

func description(move) -> String:
	if move.id in RUSHES: return "ZIGZAG RUSH" if move.id == "quickattack" else "WATER JET" if move.id == "aquajet" else "STRAIGHT RUSH"
	if move.id in BEAMS: return "BEAM / " + str(int(beam_range(move)))
	if move.id in ["psychic", "psystrike"]: return "PSYCHIC BURST"
	if move.id == "flamethrower": return "FLAME CONE"
	if move.id == "rockslide": return "FALLING ROCKS"
	if move.id == "hurricane": return "WIND VORTEX"
	if move.id == "surf": return "RIDE WAVE"
	if move.id in ["thunderbolt", "thunder"]: return "AIM CIRCLE"
	if move.id == "earthquake": return "SHOCKWAVE / ARENA WIDTH 1/5"
	if move.id == "whirlpool": return "PULL VORTEX / WIDTH 1/6"
	if move.id == "dig": return "BURROW / MARK / ERUPT"
	if move.id == "fly": return "ASCEND / MARK / DIVE"
	return move.kind.to_upper()

func launch(c, user, target, move, direction, friendly) -> bool:
	move = c.weather.prepare(move)
	if areas.launch(c,user,target,move,friendly): return true
	var id: String = move.get("id", "")
	if id in RUSHES:
		launch_rush(c, user, target, move, friendly)
		return true
	if id not in BEAMS and id not in ["surf", "thunderbolt", "thunder", "earthquake", "flamethrower", "rockslide", "hurricane", "psychic", "psystrike"]: return false
	var kind = "beam" if id in BEAMS else "wave" if id == "surf" else "quake" if id == "earthquake" else "lightning"
	if id == "rockslide": kind = "rocks"
	if id == "hurricane": kind = "vortex"
	if id in ["psychic", "psystrike"]: kind = "psychic"
	var point: Vector2 = user.pos
	if kind in ["lightning", "rocks", "vortex", "psychic"]:
		var aim_point: Vector2 = c.screen_to_arena(c.get_global_mouse_position()) if friendly else target.pos
		point += (aim_point - point).limit_length(850)
		point = point.clamp(Vector2(23, 23), c.FIELD.end - Vector2(23, 23))
	var delay = 0.75 if kind in ["lightning", "rocks", "vortex", "psychic"] else 0.3 if kind == "quake" else 0.0
	var duration = 1.45 if kind == "wave" else delay + 0.55
	if kind == "beam": duration = 1.35
	var radius = c.balance.bounds(c).size.x/5.0 if kind=="quake" else 110.0 if kind in ["lightning","rocks","vortex","psychic"] else 310.0
	if kind=="quake": duration = delay+radius/900.0+0.3
	c.shots.append({"skill": kind, "scale": move.get("area_scale", 1.0), "pos": point, "origin": user.pos, "dir": direction.normalized(), "vel": direction * 620, "age": 0.0, "life": duration, "duration": duration, "delay": delay, "damage": move.damage, "radius": radius, "friendly": friendly, "owner": user, "attack_snapshot": user.duplicate(true), "color": c.Dex.color(move.type), "move": move.duplicate(true), "hit_done": false, "rocks_hit": []})
	return true

func riding(c, fighter) -> bool:
	return c.shots.any(func(s): return s.get("skill", "") in ["wave", "rush"] and s.owner == fighter and s.life > 0)

func tick(c, s, dt):
	if s.life <= 0: return
	if s.skill in ["fly","dig","whirlpool"]:
		areas.tick(c,s,dt)
		return
	if s.skill == "rush":
		tick_rush(c, s, dt)
		return
	s.age += dt
	s.life -= dt
	var target = c.enemy if s.friendly else c.player
	var old: Vector2 = s.pos
	if s.skill == "wave":
		s.pos += s.vel * dt
		if s.owner.hp > 0 and c.result == "":
			c.move_fighter(s.owner, s.pos - s.owner.pos)
		if not c.FIELD.grow(100).has_point(s.pos): s.life = 0
	if s.age < s.delay: return
	if not s.hit_done and contains(s, target.pos, old):
		c.hit(target, s.damage, s.dir, s.friendly, s.move, s.owner, s.attack_snapshot)
		s.hit_done = true
	# Wide attacks pass through scenery, damaging each obstacle once.
	for i in range(c.rocks.size()):
		var rock = c.rocks[i]
		if rock.hp > 0 and i not in s.rocks_hit and contains(s, rock.pos, old):
			rock.hp -= s.damage
			s.rocks_hit.append(i)
			c.burst(rock.pos, s.color, 8)
	if s.skill in ["lightning", "rocks", "vortex", "psychic"]:
		# The impact is instantaneous; the remaining lifetime is only visual.
		s.hit_done = true

func contains(s, point: Vector2, previous: Vector2) -> bool:
	if s.skill == "beam":
		var offset: Vector2 = point - s.origin
		return offset.dot(s.dir) >= 0 and offset.dot(s.dir) <= visible_length(s) and absf(offset.dot(s.dir.orthogonal())) <= beam_half_width(s)
	if s.skill == "wave":
		var offset: Vector2 = point - previous
		return absf(offset.dot(s.dir.orthogonal())) <= 180 * s.get("scale", 1.0) and offset.dot(s.dir) >= -38 and offset.dot(s.dir) <= previous.distance_to(s.pos) + 38
	if s.skill == "cone":
		var offset: Vector2 = point - s.origin
		var along = offset.dot(s.dir)
		return along >= 0 and along <= 520 * s.scale and absf(offset.dot(s.dir.orthogonal())) <= (20 + along / (520 * s.scale) * 115) * s.scale
	if s.skill == "quake":
		return point.distance_to(s.pos) <= minf(s.radius, (s.age - s.delay) * 900)
	return point.distance_to(s.pos) <= s.radius

func draw_charge(c, fighter):
	if fighter.get("charge_left", 0.0) <= 0 or fighter.pending_move.is_empty(): return
	if fighter.pending_move.move.id not in BEAMS: return
	var direction: Vector2 = fighter.pending_move.direction
	var start: Vector2 = fighter.pos - Vector2(0, 42)
	var reach = beam_range(fighter.pending_move.move)
	var end = start + direction * reach
	c.draw_line(start, end, Color("b4ee66"), 2, true)
	c.draw_line(start, end, Color(0.8, 1.0, 0.4, 0.10), 72, true)
	for i in range(10):
		var p = start + direction * (i * reach/10 + fposmod(c.clock_time * 180, reach/10))
		c.draw_circle(p, 3, Color("ffffc4"))
	c.draw_arc(start, 20 + fighter.charge_left * 30, 0, TAU, 48, Color("e5ff9e"), 3, true)

func draw(c, s):
	if s.skill in ["fly","dig","whirlpool"]:
		areas.draw(c,s)
		return
	if s.skill == "rush":
		draw_rush(c, s)
		return
	var color: Color = s.color
	var fade = clampf(s.life / 0.25, 0, 1)
	if s.skill == "beam":
		if s.move.id == "flamethrower":
			draw_flame(c,s,fade)
			return
		var start: Vector2 = s.origin - Vector2(0, 42)
		var end: Vector2 = start + s.dir * visible_length(s)
		var width = beam_half_width(s) * (1.0 + sin(s.age * 45) * 0.125) * fade
		if s.move.id == "hydropump":
			c.draw_line(start, end, Color(0.1,0.55,1,0.12*fade), width*2.4,true)
			c.draw_line(start, end, Color(0.1,0.5,0.85,fade),width*1.5,true)
			for strand in range(4):
				var points = PackedVector2Array()
				for i in range(65):
					var t = i / 64.0
					points.append(start.lerp(end,t) + s.dir.orthogonal()*sin(t*35-s.age*40+strand*TAU/4)*width*0.42)
				c.draw_polyline(points,Color(0.65+strand*0.08,0.92,1,fade),5,true)
			for i in range(28):
				var p = start.lerp(end,fposmod(i/28.0+s.age*0.8,1)) + s.dir.orthogonal()*sin(i*7.2)*width*0.8
				c.draw_circle(p,3+i%4,Color(0.8,1,1,fade*0.7))
			return
		c.draw_line(start, end, Color(color, 0.14 * fade), width * 2.8, true)
		c.draw_line(start, end, Color(color, fade), width * 1.7, true)
		c.draw_line(start, end, Color("f5ffe2") * Color(1,1,1,fade), width * 0.65, true)
		for i in range(12):
			var spacing = maxf(1,visible_length(s)/12)
			var p = start + s.dir * (i * spacing + fposmod(s.age * 480, spacing))
			c.draw_arc(p, width * 0.8, s.age * 9, s.age * 9 + PI * 1.4, 20, Color(color.lightened(0.65), fade), 3, true)
		c.draw_circle(start, width, Color("ffffff") * Color(1,1,1,fade))
	elif s.skill == "wave":
		var side: Vector2 = s.dir.orthogonal()
		var base: Vector2 = s.pos
		for layer in range(5):
			var points = PackedVector2Array()
			for i in range(25):
				var across = (i / 24.0 - 0.5) * 360 * s.get("scale", 1.0)
				var curl = sin(i * 0.7 + s.age * 9) * 8
				points.append(base + side * across + s.dir * (sin(i / 24.0 * PI) * 60 + curl - layer * 16) + Vector2(0, -45 - sin(i / 24.0 * PI) * 45))
			var polygon = points.duplicate()
			polygon.append(base + side * 180 * s.get("scale", 1.0) - s.dir * (layer * 16 + 35))
			polygon.append(base - side * 180 - s.dir * (layer * 16 + 35))
			c.draw_colored_polygon(polygon, Color(Color("087aa9").lerp(Color("5edee6"), layer / 5.0), 0.82 * fade))
			c.draw_polyline(points, Color("d9ffff") * Color(1,1,1,fade), 5, true)
		# Rolled crests break up the broad wall of water into curling foam.
		for i in range(9):
			var across = (i / 8.0 - 0.5) * 340 * s.get("scale", 1.0)
			var crest = base + side * across + s.dir * (sin(i / 8.0 * PI) * 60) + Vector2(0, -45 - sin(i / 8.0 * PI) * 45)
			c.draw_arc(crest - s.dir * 10, 16 + sin(s.age * 7 + i) * 3, -2.5, 1.3, 16, Color("b7ffff") * Color(1,1,1,fade), 5, true)
		for i in range(20):
			var p: Vector2 = base + side * (sin(i * 9.7) * 175 * s.get("scale", 1.0)) - s.dir * fposmod(s.age * 150 + i * 17, 110) + Vector2(0, -100 - sin(i + s.age * 7) * 15)
			c.draw_circle(p, 3 + i % 3, Color(0.8,1,1,fade * 0.8))
	elif s.skill == "cone":
		draw_flame(c, s, fade)
	elif s.skill == "psychic":
		draw_psychic(c, s, fade)
	elif s.skill in ["rocks", "vortex"]:
		draw_targeted(c, s, fade)
	elif s.skill == "lightning":
		var progress = clampf(s.age / s.delay, 0, 1)
		c.draw_circle(s.pos, s.radius, Color(0.3,0.2,0.05,0.18 * fade))
		c.draw_arc(s.pos, s.radius, 0, TAU, 64, Color(color, fade), 3, true)
		c.draw_arc(s.pos, s.radius * progress, -PI / 2, -PI / 2 + TAU * progress, 64, Color("fff6b1") * Color(1,1,1,fade), 4, true)
		for i in range(8):
			var d = Vector2.from_angle(i * TAU / 8)
			c.draw_line(s.pos + d * 92, s.pos + d * 106, Color(color, fade), 3)
		if s.age >= s.delay:
			c.draw_circle(s.pos, s.radius * 0.85, Color(1,0.95,0.6,0.35 * fade))
			for branch in range(3):
				var points = PackedVector2Array()
				for i in range(9):
					points.append(s.pos + Vector2(sin(i * 7 + branch * 3 + s.age * 38) * 26 * sin(i * PI / 8), -360 + i * 45))
				c.draw_polyline(points, Color(color, fade * 0.4), 20, true)
				c.draw_polyline(points, Color("fffbd4") * Color(1,1,1,fade), 5, true)
			c.draw_circle(s.pos, 22 * fade, Color.WHITE)
	else:
		var radius = minf(s.radius, maxf(0, s.age - s.delay) * 900)
		c.draw_arc(s.pos, s.radius, 0, TAU, 64, Color(0.6,0.35,0.1,0.3 * fade), 2)
		c.draw_arc(s.pos, radius, 0, TAU, 64, Color(color, fade), 10, true)
		for i in range(16):
			var dir = Vector2.from_angle(i * TAU / 16)
			var p: Vector2 = s.pos + dir * radius
			c.draw_line(s.pos + dir * radius * 0.4, p, Color(0.25,0.2,0.14,fade), 3)
			c.draw_colored_polygon(PackedVector2Array([p-Vector2(12,0),p-Vector2(3,28),p+Vector2(14,3)]), Color(color.darkened(0.3),fade))

func draw_psychic(c, s, fade):
	var p: Vector2 = s.pos - Vector2(0,32)
	var charge = clampf(s.age / s.delay,0,1)
	var fired: bool = s.age >= s.delay
	# Ground rune remains the readable collision warning beneath the spectacle.
	c.draw_arc(s.pos,110,0,TAU,64,Color(0.8,0.5,1,0.6*fade),2,true)
	for i in range(3):
		var radius = (75-i*12)*(1-charge*0.45) if not fired else 45+(s.age-s.delay)*160+i*15
		var start = s.age*(4+i)+i*2.0
		c.draw_arc(p,radius,start,start+TAU*0.85,48,Color(0.7+i*0.1,0.45+i*0.18,1,fade*0.65),3,true)
	for i in range(8):
		var angle = i*TAU/8+s.age*3
		var radius = 95*(1-charge*0.8) if not fired else 35+(s.age-s.delay)*210
		var point = p + Vector2.from_angle(angle)*radius
		for glow in [14,9,4]: c.draw_circle(point,glow,Color(0.8,0.55,1,(0.12 if glow>4 else 0.9)*fade))
		c.draw_line(point,point-Vector2.from_angle(angle)*18,Color(0.85,0.7,1,fade*0.5),2,true)
	if fired:
		var strength = clampf(1-(s.age-s.delay)/0.55,0,1)
		for radius in [100,65,35]: c.draw_circle(p,radius*strength,Color(0.7,0.3,1,0.08*strength))
		for i in range(12):
			var dir = Vector2.from_angle(i*TAU/12+s.age)
			c.draw_line(p+dir*12,p+dir*(55+i%3*24)*strength,Color(0.95,0.8,1,strength),3,true)
		c.draw_circle(p,18*strength,Color("ffefff"))
		if s.move.id == "psystrike":
			for i in range(7):
				var dir = Vector2.from_angle(i*TAU/7)
				var rock = s.pos+dir*(40+(s.age-s.delay)*180)
				c.draw_colored_polygon(PackedVector2Array([rock-Vector2(9,0),rock-Vector2(2,14),rock+Vector2(12,5)]),Color(0.7,0.5,0.9,fade))

func draw_flame(c, s, fade):
	var origin: Vector2 = s.origin - Vector2(0,42)
	var side: Vector2 = s.dir.orthogonal()
	var reach = visible_length(s)
	var width = beam_half_width(s)
	if reach < 1: return
	c.draw_line(origin,origin+s.dir*reach,Color(1,0.25,0.03,0.12*fade),width*2.8,true)
	# Overlapping rolling flame lobes, with dark edges and incandescent cores.
	for i in range(int(ceil(reach/18.0))):
		var along = minf(reach,i*18.0+fposmod(s.age*400,18))
		var swell = (0.4+0.6*minf(1,along/85))
		var radius = width*swell*(0.8+sin(i*2.1-s.age*25)*0.12)
		var p = origin+s.dir*along+side*sin(i*0.8-s.age*16)*width*0.16
		c.draw_circle(p,radius,Color(0.65,0.075,0.02,0.9*fade))
		c.draw_circle(p-side*radius*0.12,radius*0.8,Color(1,0.29,0.025,fade))
		c.draw_circle(p-s.dir*radius*0.18,radius*0.55,Color(1,0.72,0.1,fade))
		c.draw_circle(p-s.dir*radius*0.22,radius*0.28,Color(1,0.97,0.66,fade))
	for i in range(20):
		var along = fposmod(i*31+s.age*680,maxf(1,reach))
		var p = origin+s.dir*along+side*sin(i*4.7+s.age*8)*width*1.1
		c.draw_line(p-s.dir*8,p,Color(1,0.78,0.2,fade*0.8),2,true)

func draw_targeted(c, s, fade):
	c.draw_circle(s.pos, 110, Color(s.color, 0.12 * fade))
	c.draw_arc(s.pos, 110, 0, TAU, 48, Color(s.color, fade), 3, true)
	var progress = clampf(s.age / s.delay, 0, 1)
	c.draw_arc(s.pos, 110, -PI/2, -PI/2 + progress * TAU, 48, Color(1,1,1,fade), 2, true)
	if s.skill == "rocks":
		for i in range(3):
			var ground: Vector2 = s.pos + Vector2((i-1)*58, (i%2)*32-16)
			c.draw_ellipse(ground,Vector2(32,16)*progress,Color(0.1,0.13,0.15,0.3*fade))
			var p = ground - Vector2(0, (1-progress)*300)
			var shape = PackedVector2Array()
			for j in range(6): shape.append(p + Vector2.from_angle(j * TAU/6 + i) * (28 + j%2*7))
			c.draw_colored_polygon(shape, Color(Color("8d7961"),fade))
			c.draw_polyline(shape,Color(Color("d3c5a1"),fade),3,true)
	else:
		for i in range(10):
			var y = i * 15.0
			var radius = 25 + i * 8.0
			var points = PackedVector2Array()
			for j in range(30):
				var angle = j / 29.0 * TAU * 0.85 + s.age * 16 + i * 0.5
				points.append(s.pos + Vector2(cos(angle)*radius,sin(angle)*radius*0.32-y))
			c.draw_polyline(points,Color(0.8,0.95,1,fade*0.55),4,true)

func minimap(c):
	var rect = Rect2(1044, 672, 180, 90)
	c.draw_rect(rect.grow(5), Color(0.03,0.1,0.14,0.85))
	c.draw_rect(rect, Color("42636b"))
	var ratio: Vector2 = rect.size / c.FIELD.size
	c.draw_rect(Rect2(rect.position + c.camera_offset * ratio, Vector2(1200,600) / c.ARENA_SCALE * ratio), Color(0.9,1,1,0.45), false, 1)
	for friendly in [true, false]:
		c.draw_circle(rect.position + c.trainer_position(friendly) * ratio, 3, c.GOLD)
		var fighter = c.player if friendly else c.enemy
		c.draw_circle(rect.position + fighter.pos * ratio, 4, c.MINT if friendly else Color("ff7a72"))

func tests(c):
	c.move_editor.tests()
	areas.tests(c)
	c.pick(25,9)
	c.rocks.clear()
	c.player.pos = Vector2(500,600)
	c.enemy.pos = Vector2(750,600)
	launch(c,c.player,c.enemy,{"id":"quickattack","type":"Normal","category":"Physical","damage":30.0},Vector2.RIGHT,true)
	var tracking_rush = c.shots.back()
	var tracking_health: float = c.enemy.hp
	for frame in range(30):
		c.enemy.pos.y += 2
		tick(c,tracking_rush,0.016)
	c.check(c.enemy.hp<tracking_health,"Quick Attack damages a moving target within reach")
	tracking_health = c.enemy.hp
	c.enemy.inv = 0
	tick(c,tracking_rush,0.05)
	c.check(c.enemy.hp==tracking_health,"Tracking Quick Attack cannot damage twice")
	for id in RUSHES:
		c.pick(25,9)
		c.rocks.clear()
		c.player.pos = Vector2(500,600)
		c.enemy.pos = Vector2(780,600)
		var rush_move = {"id":id,"type":"Water" if id == "aquajet" else "Normal","category":"Physical","damage":30.0}
		launch(c,c.player,c.enemy,rush_move,Vector2.RIGHT,true)
		var rush = c.shots.back()
		c.check(rush_position(rush,1).is_equal_approx(c.enemy.pos),"Rush ends at launch target: "+id)
		c.check(absf(rush_position(rush,0.2).y-600)>30 if id == "quickattack" else is_equal_approx(rush_position(rush,0.2).y,600),"Zigzag versus straight path: "+id)
		var health: float = c.enemy.hp
		c.player.hp = 0
		tick(c,rush,0.45)
		c.check(c.enemy.hp < health,"Committed rush survives caster KO: "+id)
		health = c.enemy.hp
		c.enemy.inv = 0
		tick(c,rush,0.05)
		c.check(c.enemy.hp == health,"Rush damages once: "+id)
		c.check(c.player.pos == Vector2(500,600),"Fainted body stays put: "+id)
		c.shots.clear()
	for entry in [["hydropump",575.0],["icebeam",650.0],["aurorabeam",600.0],["hyperbeam",900.0],["solarbeam",1150.0]]:
		var beam = {"skill":"beam","origin":Vector2.ZERO,"dir":Vector2.RIGHT,"scale":1.12,"move":{"id":entry[0]}}
		c.check(contains(beam,Vector2(entry[1],0),Vector2.ZERO) and not contains(beam,Vector2(entry[1]+1,0),Vector2.ZERO),"Exact beam range including rain: "+entry[0])
	for name in ["lightning","rocks","vortex","psychic"]:
		var area = {"skill":name,"pos":Vector2.ZERO,"radius":110.0}
		c.check(contains(area,Vector2(110,0),Vector2.ZERO) and not contains(area,Vector2(111,0),Vector2.ZERO),"No invisible damage outside circle: "+name)
	c.pick(3, 9)
	c.rocks.clear()
	c.player.pos = Vector2(400,600)
	c.enemy.pos = Vector2(800,600)
	var move = {"id":"solarbeam", "damage":40, "type":"Grass", "category":"Special"}
	launch(c,c.player,c.enemy,move,Vector2.RIGHT,true)
	var hp: float = c.enemy.hp
	tick(c,c.shots.back(),0.02)
	c.check(c.enemy.hp < hp, "Solar Beam hits along its full line")
	hp = c.enemy.hp
	c.enemy.inv = 0
	tick(c,c.shots.back(),0.3)
	c.check(c.enemy.hp == hp, "Beam visual does not repeat damage")
	c.shots.clear()
	move.id = "surf"
	move.type = "Water"
	launch(c,c.player,c.enemy,move,Vector2.RIGHT,true)
	var start: Vector2 = c.player.pos
	tick(c,c.shots.back(),0.1)
	c.check(c.player.pos.x > start.x, "Surf carries its caster")
	c.player.hp = 0
	start = c.player.pos
	var wave: Vector2 = c.shots.back().pos
	tick(c,c.shots.back(),0.1)
	c.check(c.player.pos == start and c.shots.back().pos.x > wave.x, "Surf continues after faint without moving body")
	c.shots.clear()
	c.player.hp = c.player.data.hp
	move.id = "thunderbolt"
	move.type = "Electric"
	launch(c,c.enemy,c.player,move,Vector2.LEFT,false)
	hp = c.player.hp
	tick(c,c.shots.back(),0.4)
	c.check(c.player.hp == hp, "Thunderbolt warning deals no damage")
	c.enemy.hp = 0
	tick(c,c.shots.back(),0.4)
	c.check(c.player.hp < hp, "Thunderbolt resolves after caster faints")
	c.shots.clear()
	c.enemy.hp = c.enemy.data.hp
	c.player.inv = 0
	launch(c,c.enemy,c.player,move,Vector2.LEFT,false)
	var marked: Vector2 = c.shots.back().pos
	c.player.pos += Vector2(0, 200)
	hp = c.player.hp
	tick(c,c.shots.back(),0.8)
	c.check(c.player.hp == hp and c.shots.back().pos == marked, "Leaving the fixed Thunderbolt circle avoids damage")
	c.shots.clear()
	move.id = "icebeam"
	move.type = "Ice"
	c.player.pos = Vector2(400,600)
	c.enemy.pos = Vector2(800,700)
	c.enemy.inv = 0
	launch(c,c.player,c.enemy,move,Vector2.RIGHT,true)
	hp = c.enemy.hp
	tick(c,c.shots.back(),0.02)
	c.check(c.enemy.hp == hp, "Sidestepping a beam avoids damage")
	c.shots.clear()
	for entry in [["flamethrower","Fire","beam"],["hydropump","Water","beam"],["rockslide","Rock","rocks"],["hurricane","Flying","vortex"],["psychic","Psychic","psychic"],["psystrike","Psychic","psychic"]]:
		move.id = entry[0]
		move.type = entry[1]
		launch(c,c.player,c.enemy,move,Vector2.RIGHT,true)
		var launched = c.shots.back()
		launched.age = 1.0
		c.check(launched.skill == entry[2],"Dedicated skill behavior: " + entry[0])
		if launched.skill in ["rocks","vortex","psychic"]:
			c.check(not contains(launched,launched.pos + Vector2(111,0),launched.pos),"Targeted effect does not hit outside marked circle")
		if launched.skill == "cone":
			c.check(contains(launched,c.player.pos+Vector2(400,0),launched.pos) and not contains(launched,c.player.pos+Vector2(-100,0),launched.pos),"Flame cone hits forward only")
		if entry[0] == "hydropump":
			c.check(contains(launched,c.player.pos+Vector2(574,0),launched.pos) and not contains(launched,c.player.pos+Vector2(576,0),launched.pos),"Hydro Pump ends at 575 units")
			launched.scale = 1.0
			c.check(contains(launched,c.player.pos+Vector2(400,33),launched.pos) and not contains(launched,c.player.pos+Vector2(400,35),launched.pos),"Hydro Pump has a narrower 34-unit half-width")
			launched.scale = 1.12
			c.check(not contains(launched,c.player.pos+Vector2(400,40),launched.pos),"Rain Hydro Pump still allows a 40-unit sidestep")
		c.shots.clear()
	c.reset()
	c.player.pos = Vector2(2300,1100)
	c.update_camera(10)
	c.check(c.camera_offset.is_equal_approx(Vector2(900,450)), "Camera clamps to enlarged arena edge")
	c.check(c.screen_to_arena(c.world_origin() + c.player.pos * c.ARENA_SCALE).is_equal_approx(c.player.pos), "Offset camera preserves mouse aim")
	c.reset()
