extends RefCounted

func launch(c,user,target,move,friendly) -> bool:
	if move.id not in ["fly","dig","whirlpool"]: return false
	var flying = move.id in ["fly","dig"]
	var radius = 100.0 if flying else c.balance.bounds(c).size.x/6.0
	var position: Vector2 = target.pos if flying else user.pos
	var court = c.balance.bounds(c)
	position = position.clamp(court.position,court.end)
	c.shots.append({"target":target,"skill":move.id,"move":move.duplicate(true),"owner":user,"attack_snapshot":user.duplicate(true),"friendly":friendly,"pos":position,"origin":user.pos,"radius":radius,"age":0.0,"life":1.9 if flying else 2.5,"delay":1.5 if flying else 0.55,"damage":move.damage,"dir":Vector2.DOWN,"hit_done":false,"color":c.Dex.color(move.type)})
	if flying:
		user.volatile["underground" if move.id=="dig" else "airborne"] = 1.5
		user.action_lock = 1.6
		user.dash_time = 0
	return true

func tick(c,s,dt):
	s.age += dt
	s.life -= dt
	var target = c.shot_target(s)
	if s.skill in ["fly","dig"]:
		# Follow during ascent, then lock the warning so the opponent can dodge the landing.
		if s.age<0.6:
			var court = c.balance.bounds(c)
			s.pos = target.pos.clamp(court.position,court.end)
		if s.age>=s.delay and not s.hit_done:
			if s.owner.hp>0:
				c.move_fighter(s.owner,s.pos-s.owner.pos)
				s.owner.volatile.erase("underground" if s.skill=="dig" else "airborne")
				# Recovery starts at impact, even if the opponent dodged the move.
				s.owner.movement_lock = maxf(s.owner.get("movement_lock",0),0.8)
				s.owner.action_lock = maxf(s.owner.get("action_lock",0),0.8)
			for foe in c.foes() if s.friendly else [c.player]:
				if foe.pos.distance_to(s.pos)<=s.radius: c.hit(foe,s.damage,(foe.pos-s.pos).normalized(),s.friendly,s.move,s.owner,s.attack_snapshot)
			s.hit_done = true
			c.burst(s.pos,s.color,25)
	else:
		if s.age<s.delay: return
		if not s.has("targets_hit"): s["targets_hit"]=[]
		for foe in c.foes() if s.friendly else [c.player]:
			if foe.hp<=0 or c.Conditions.avoids(foe,s.move): continue
			var delta: Vector2=s.pos-foe.pos
			if delta.length()>s.radius: continue
			var key=int(foe.get("horde_slot",-1)) if s.friendly else -2
			if key not in s.targets_hit:
				var dealt=c.hit(foe,s.damage,delta.normalized(),s.friendly,s.move,s.owner,s.attack_snapshot)
				if dealt>0 and c.rng.randf()<0.3: c.Conditions.apply(c,foe,{"volatileStatus":"flinch"},s.move)
				s.targets_hit.append(key); s.hit_done=true
			c.move_fighter(foe,delta.limit_length(165*dt))

func height(c,f) -> float:
	for s in c.shots:
		if s.get("skill","")=="fly" and s.owner==f and f.hp>0 and s.age<1.5:
			return 260*clampf(s.age/0.35,0,1)*(1-clampf((s.age-1.2)/0.3,0,1))
	return 0

func visual_position(c,f) -> Vector2:
	for s in c.shots:
		if s.get("skill","")=="fly" and s.owner==f and f.hp>0 and s.age<1.5:
			return s.origin.lerp(s.pos,clampf((s.age-1.2)/0.3,0,1))-Vector2(0,height(c,f))
	return f.pos

func draw(c,s):
	var fade = clampf(s.life/0.35,0,1)
	var color: Color = s.color
	c.draw_circle(s.pos,s.radius,Color(color,0.12*fade))
	c.draw_arc(s.pos,s.radius,0,TAU,96,Color(color,0.8*fade),3,true)
	if s.skill in ["fly","dig"]:
		var progress = clampf(s.age/s.delay,0,1)
		c.draw_arc(s.pos,s.radius*progress,-PI/2,-PI/2+TAU*progress,64,Color(1,1,1,fade),4,true)
		for i in range(8):
			var dir = Vector2.from_angle(i*TAU/8)
			c.draw_line(s.pos+dir*s.radius*0.8,s.pos+dir*s.radius,Color(1,1,1,fade),3)
		if s.skill=="dig":
			c.draw_ellipse(s.origin,Vector2(34,15),Color(0.08,0.05,0.02,fade))
			for i in range(12):
				var d = Vector2.from_angle(i*TAU/12)
				var base: Vector2 = s.pos+d*s.radius*0.75
				var lift = maxf(0,sin(clampf((s.age-s.delay)/0.4,0,1)*PI))*70
				c.draw_line(base-d*15,base+d*12,Color(0.4,0.25,0.1,fade),4)
				if s.age>=s.delay: c.draw_circle(base-Vector2(0,lift),8,Color(0.6,0.4,0.2,fade))
		if s.age>=s.delay:
			c.draw_arc(s.pos,s.radius*(1+(s.age-s.delay)*2),0,TAU,64,Color(1,1,1,fade),8,true)
	else:
		for arm in range(5):
			var spiral = PackedVector2Array()
			for i in range(55):
				var t = i/54.0
				spiral.append(s.pos+Vector2.from_angle(arm*TAU/5+t*TAU-s.age*4)*s.radius*t)
			c.draw_polyline(spiral,Color(0.2,0.65,1,fade*0.3),14,true)
			c.draw_polyline(spiral,Color(0.7,0.95,1,fade*0.8),3,true)
		c.draw_circle(s.pos,18,Color(0.08,0.3,0.55,fade))
		if s.age>=s.delay:
			for i in range(9):
				var base: Vector2 = s.pos+Vector2.from_angle(i*TAU/9)*s.radius*(0.25+0.5*(i%3)/2.0)
				var pulse = absf(sin((s.age-s.delay)*7-i*0.6))
				var top = base-Vector2(0,45+110*pulse)
				c.draw_ellipse(base,Vector2(27,10),Color(0.6,0.95,1,fade*0.5))
				c.draw_line(base,top,Color(0.15,0.6,1,fade*0.35),24,true)
				c.draw_line(base,top,Color(0.65,0.95,1,fade*0.8),7,true)
				for drop in range(4):
					c.draw_circle(top+Vector2((drop-1.5)*11,sin(i+drop+s.age*10)*18),3+drop%2,Color(0.8,1,1,fade))

func dig_tests(c):
	c.pick(28,9)
	c.rocks.clear()
	var move = {"id":"dig","name":"Dig","kind":"dash","type":"Ground","category":"Physical","damage":25}
	var quake = {"id":"earthquake","type":"Ground","category":"Physical"}
	var ordinary: float = c.damage_amount(c.enemy,c.player,20,quake)
	launch(c,c.player,c.enemy,move,true)
	var shot = c.shots.back()
	var hp: float = c.player.hp
	c.hit(c.player,20,Vector2.LEFT,false,{"id":"watergun","type":"Water"})
	c.check(c.player.hp==hp and c.player.volatile.has("underground"),"Dig avoids normal attacks while underground")
	c.check(not c.Conditions.apply(c,c.player,{"status":"slp"},{"id":"hypnosis"}),"Underground avoids targeted status moves")
	c.check(absf(c.damage_amount(c.enemy,c.player,20,quake)-ordinary*2)<=0.11,"Earthquake does double damage against Dig")
	c.check(c.hit(c.player,20,Vector2.LEFT,false,quake)>0,"Earthquake still connects underground")
	hp = c.enemy.hp
	tick(c,shot,1.51)
	c.check(c.enemy.hp<hp and not c.player.volatile.has("underground"),"Dig emerges and deals one impact hit")
	hp = c.enemy.hp
	c.enemy.inv = 0
	tick(c,shot,0.1)
	c.check(c.enemy.hp==hp,"Dig emergence never damages twice")
	c.pick(28,9)
	launch(c,c.player,c.enemy,move,true)
	shot = c.shots.back()
	tick(c,shot,0.7)
	c.enemy.pos += Vector2(200,0)
	hp = c.enemy.hp
	tick(c,shot,0.81)
	c.check(c.enemy.hp==hp,"Leaving the Dig warning avoids emergence damage")

func tests(c):
	for id in ["fly","dig"]:
		for friendly in [true,false]:
			c.pick(6,9)
			c.rocks.clear()
			var owner = c.player if friendly else c.enemy
			var target = c.enemy if friendly else c.player
			launch(c,owner,target,{"id":id,"type":"Normal","damage":20},friendly)
			var landing = c.shots.back()
			c.check(landing.radius==100,"Smaller warning and damage radius: "+id)
			c.Conditions.tick(owner,1.5)
			tick(c,landing,1.5)
			c.check(is_equal_approx(owner.movement_lock,0.8) and owner.action_lock>=0.8,"Landing blocks movement and attacks for 0.8s on either side: "+id)
			c.Conditions.tick(owner,0.79)
			c.check(c.Conditions.immobilized(owner) and owner.action_lock>0,"Recovery lasts through 0.79s: "+id)
			c.Conditions.tick(owner,0.02)
			c.check(not c.Conditions.immobilized(owner) and owner.action_lock==0,"Movement and attacks unlock after recovery: "+id)
			tick(c,landing,0.02)
			c.check(owner.movement_lock==0,"Lingering landing effect cannot restart recovery: "+id)
	c.enemy_bench.tests(c)
	dig_tests(c)
	c.pick(6,9)
	var beam = {"move":{"id":"icebeam"},"scale":1.0}
	c.check(c.skills.beam_half_width(beam)==20,"Ice Beam has a narrow 20-unit half-width")
	for field in [0,1]:
		c.fields.active = field
		c.skills.launch(c,c.player,c.enemy,{"id":"earthquake","type":"Ground","damage":30},Vector2.RIGHT,true)
		var quake = c.shots.back()
		c.check(is_equal_approx(quake.radius,c.balance.bounds(c).size.x/5),"Earthquake radius scales with the actual arena")
		quake.age = quake.duration-0.1
		c.check(c.skills.contains(quake,quake.pos+Vector2(quake.radius-0.1,0),quake.pos) and not c.skills.contains(quake,quake.pos+Vector2(quake.radius+1,0),quake.pos),"Earthquake damage matches the drawn outer radius")
	c.pick(6,9)
	c.rocks.clear()
	var move = {"id":"fly","name":"Fly","kind":"dash","type":"Flying","category":"Physical","damage":30}
	launch(c,c.player,c.enemy,move,true)
	var shot = c.shots.back()
	var hp: float = c.player.hp
	c.hit(c.player,20,Vector2.LEFT,false,{"type":"Normal"})
	c.check(c.player.hp==hp,"Fly ascent avoids normal incoming attacks")
	tick(c,shot,0.7)
	var marked: Vector2 = shot.pos
	c.enemy.pos += Vector2(200,0)
	hp = c.enemy.hp
	tick(c,shot,0.81)
	c.check(c.enemy.hp==hp and shot.pos==marked,"Fly locks a warning circle that can be dodged")
	c.check(not c.player.volatile.has("airborne"),"Fly landing clears airborne state")
	c.pick(6,9)
	c.rocks.clear()
	launch(c,c.player,c.enemy,move,true)
	shot = c.shots.back()
	hp = c.enemy.hp
	c.player.hp = 0
	tick(c,shot,1.51)
	c.check(c.enemy.hp<hp,"Committed Fly impact survives caster faint")
	c.pick(9,6)
	c.rocks.clear()
	c.player.pos = Vector2(900,600)
	c.enemy.pos = Vector2(1100,600)
	move = {"id":"whirlpool","type":"Water","category":"Special","damage":20}
	launch(c,c.player,c.enemy,move,true)
	shot = c.shots.back()
	c.check(is_equal_approx(shot.radius,c.balance.bounds(c).size.x/6),"Whirlpool uses one sixth of the arena width")
	var distance: float = c.enemy.pos.distance_to(shot.pos)
	hp = c.enemy.hp
	tick(c,shot,0.6)
	c.check(c.enemy.hp<hp and c.enemy.pos.distance_to(shot.pos)<distance,"Whirlpool damages and pulls toward its center")
	c.enemy.pos = shot.pos+Vector2(shot.radius+10,0)
	var outside: Vector2 = c.enemy.pos
	tick(c,shot,0.1)
	c.check(c.enemy.pos==outside,"Whirlpool cannot pull outside its circle")
	var flinches = 0
	for attempt in range(30):
		c.enemy.hp = c.enemy.data.hp
		c.enemy.inv = 0
		c.enemy.volatile.clear()
		c.enemy.pos = c.player.pos+Vector2(100,0)
		c.shots.clear()
		launch(c,c.player,c.enemy,move,true)
		shot = c.shots.back()
		tick(c,shot,0.56)
		if c.enemy.volatile.has("flinch"):
			flinches += 1
			c.Conditions.tick(c.enemy,0.2)
			tick(c,shot,0.1)
			c.check(c.enemy.volatile.get("flinch",0)<0.3,"Whirlpool cannot reroll or refresh flinch every frame")
	c.check(flinches>0 and flinches<30,"Whirlpool flinch is probabilistic rather than guaranteed")
