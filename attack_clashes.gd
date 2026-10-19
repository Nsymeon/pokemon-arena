extends RefCounted

# Resolve opposing attacks before either can damage a fighter this frame.
# Field effects and body rushes deliberately do not behave like projectiles.
func eligible(s) -> bool:
	return s.life > 0 and not s.get("hit_done", false) and (not s.has("skill") or s.skill == "beam")

func strength(c, s) -> float:
	var owner: Dictionary = s.attack_snapshot
	var physical = s.move.get("category", "Special") == "Physical"
	var stat = "atk" if physical else "spa"
	var attack: float = owner.data.base_stats[stat] * c.Conditions.stage(owner, stat)
	var stab = 1.5 if s.move.get("type", "") in owner.data.types else 1.0
	var burn = 0.5 if physical and owner.get("ailment", "") == "burn" else 1.0
	return maxf(1, s.damage * (50 + attack) / 150.0 * stab * s.move.get("weather_power", 1.0) * burn)

func segment(c, s, dt) -> PackedVector2Array:
	if s.get("skill", "") == "beam":
		return PackedVector2Array([s.origin, s.origin + s.dir * c.skills.front_length(s, s.age + dt)])
	return PackedVector2Array([s.pos, s.pos + s.vel * dt])

func width(c, s) -> float:
	return c.skills.beam_half_width(s) if s.get("skill", "") == "beam" else s.radius

func direction(s) -> Vector2:
	return s.dir if s.get("skill", "") == "beam" else s.vel.normalized()

func prepare(c, dt):
	for s in c.shots:
		s.erase("clash_limit")
		s.erase("clashing")
		if not eligible(s): continue
		if not s.has("integrity"):
			s["integrity_max"] = strength(c,s)
			s["integrity"] = s.integrity_max
			s["base_damage"] = s.damage
	var used: Array = []
	for i in range(c.shots.size()):
		var a = c.shots[i]
		if not eligible(a) or i in used: continue
		for j in range(i + 1, c.shots.size()):
			var b = c.shots[j]
			if not eligible(b) or j in used or a.friendly == b.friendly: continue
			if direction(a).dot(direction(b)) > -0.2: continue
			var sa = segment(c,a,dt)
			var sb = segment(c,b,dt)
			var closest = Geometry2D.get_closest_points_between_segments(sa[0],sa[1],sb[0],sb[1])
			if closest[0].distance_to(closest[1]) > width(c,a) + width(c,b): continue
			var point: Vector2 = (closest[0] + closest[1]) * 0.5
			var sustained = a.get("skill", "") == "beam" and b.get("skill", "") == "beam"
			if sustained:
				# Anchor contact while both fronts are pushing against each other.
				point = a.get("contact", point) if a.get("contact_partner", -1) == b.get("clash_id", -2) else point
				if not a.has("clash_id"): a["clash_id"] = c.next_clash_id; c.next_clash_id += 1
				if not b.has("clash_id"): b["clash_id"] = c.next_clash_id; c.next_clash_id += 1
				a["contact"] = point
				a["contact_partner"] = b.clash_id
				for shot in [a,b]:
					shot["clashing"] = true
					shot["clash_limit"] = maxf(0,(point-shot.origin).dot(shot.dir))
			var loss = minf(a.integrity,b.integrity)
			if sustained: loss = minf(loss,minf(a.integrity_max,b.integrity_max)*dt/0.42)
			a.integrity = maxf(0,a.integrity-loss)
			b.integrity = maxf(0,b.integrity-loss)
			for shot in [a,b]:
				shot.damage = shot.base_damage * shot.integrity / shot.integrity_max
				if shot.integrity < 0.001: shot.life = 0
			var steam = (a.move.type == "Fire" and b.move.type == "Water") or (a.move.type == "Water" and b.move.type == "Fire")
			c.clash_effects.append({"pos":point,"age":0.0,"life":0.22 if sustained else 0.45,"steam":steam,"a":a.color,"b":b.color})
			if c.clash_effects.size() > 32: c.clash_effects.pop_front()
			c.shake = maxf(c.shake, 1.6 if sustained else 3.5)
			used.append(i)
			used.append(j)
			break

func draw(c):
	for e in c.clash_effects:
		var fade: float = e.life / (0.22 if e.life <= 0.22 else 0.45)
		var p: Vector2 = e.pos - Vector2(0,42)
		var size: float = 20 + e.age * 65
		c.draw_circle(p, size*1.8, Color(e.a,0.08*fade))
		c.draw_circle(p, size, Color(e.b,0.22*fade))
		c.draw_circle(p, size*0.45, Color(1,1,0.9,0.85*fade))
		for i in range(8):
			var d = Vector2.from_angle(i*TAU/8 + e.age*3)
			c.draw_line(p+d*size*0.7,p+d*size*1.9,Color(1,0.95,0.75,0.8*fade),2,true)
		if e.steam:
			for i in range(5):
				var cloud = p + Vector2(sin(i*7.0+e.age*6)*20,-e.age*190-i*13)
				c.draw_circle(cloud,12+i*3+e.age*16,Color(0.86,0.94,1,0.1*fade))

func tests(c):
	for reverse in [false,true]:
		c.pick(6,9)
		c.rocks.clear()
		c.player.pos = Vector2(600,600)
		c.enemy.pos = Vector2(1060,600)
		var fire = {"id":"flamethrower","type":"Fire","category":"Special","damage":30.0}
		var water = {"id":"hydropump","type":"Water","category":"Special","damage":30.0}
		c.skills.launch(c,c.player,c.enemy,fire,Vector2.RIGHT,true)
		c.skills.launch(c,c.enemy,c.player,water,Vector2.LEFT,false)
		if reverse: c.shots.reverse()
		for s in c.shots:
			s.integrity_max = 100.0
			s.integrity = 100.0
			s.base_damage = s.damage
		var hp_a: float = c.player.hp
		var hp_b: float = c.enemy.hp
		for i in range(45): c.update_projectiles(0.02)
		c.check(c.player.hp == hp_a and c.enemy.hp == hp_b,"Equal opposing beams cancel before damage, independent of list order")
		c.check(c.shots.is_empty(),"Equal beam integrity exhausts both attacks")
	c.pick(6,9)
	c.rocks.clear()
	c.player.pos = Vector2(600,600)
	c.enemy.pos = Vector2(1060,600)
	var move = {"id":"flamethrower","type":"Fire","category":"Special","damage":30.0}
	c.skills.launch(c,c.player,c.enemy,move,Vector2.RIGHT,true)
	move.id = "hydropump"
	move.type = "Water"
	c.skills.launch(c,c.enemy,c.player,move,Vector2.LEFT,false)
	for i in range(2):
		c.shots[i].integrity_max = 50.0 if i == 0 else 150.0
		c.shots[i].integrity = c.shots[i].integrity_max
		c.shots[i].base_damage = c.shots[i].damage
	var water_shot = c.shots[1]
	var health: float = c.player.hp
	c.enemy.hp = 0
	for i in range(45): c.update_projectiles(0.02)
	c.check(c.player.hp < health,"Stronger beam breaks through even after caster KO")
	c.check(is_equal_approx(water_shot.damage,20.0),"Winning beam retains only remaining integrity as damage")
	c.pick(6,9)
	c.rocks.clear()
	c.player.pos = Vector2(600,600)
	c.enemy.pos = Vector2(1060,800)
	c.skills.launch(c,c.player,c.enemy,move,Vector2.RIGHT,true)
	c.skills.launch(c,c.enemy,c.player,move,Vector2.LEFT,false)
	prepare(c,0.5)
	c.check(not c.shots[0].get("clashing",false),"Separated parallel beams do not clash")
	c.shots.clear()
	c.projectile(Vector2(700,600),Vector2.RIGHT,600,30,7,true,Color.WHITE,move)
	c.projectile(Vector2(800,600),Vector2.LEFT,600,30,7,false,Color.WHITE,move)
	for s in c.shots:
		s.integrity_max = 100.0
		s.integrity = 100.0
		s.base_damage = 30.0
	prepare(c,0.1)
	c.check(c.shots[0].life == 0 and c.shots[1].life == 0,"Swept projectile collision catches attacks crossing between frames")
	c.reset()
