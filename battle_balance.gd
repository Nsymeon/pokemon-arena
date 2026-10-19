extends RefCounted

func bounds(c) -> Rect2:
	# Foot positions stay inside the painted court, with room for the sprite above.
	return Rect2(110,135,2180,965) if c.fields.active==0 else Rect2(275,245,1850,750)

func dodge(c,dt: float) -> Vector2:
	var f = c.enemy
	f["dodge_cooldown"] = maxf(0,f.get("dodge_cooldown",0)-dt)
	f["dodge_left"] = maxf(0,f.get("dodge_left",0)-dt)
	f["sprinting"] = false
	if c.Conditions.immobilized(f) or f.dash_time>0 or c.skills.riding(c,f) or f.energy<12*dt: return Vector2.ZERO
	if f.dodge_left<=0 and f.dodge_cooldown<=0:
		var escape = Vector2.ZERO
		for shot in c.shots:
			if not shot.get("friendly",false) or shot.get("life",0)<=0 or shot.get("hit_done",false) or shot.get("age",0)<0.12: continue
			var skill = shot.get("skill","")
			if skill in ["lightning","rocks","vortex","psychic"]:
				if shot.age>=shot.delay or f.pos.distance_to(shot.pos)>shot.radius+55: continue
				escape = (f.pos-shot.pos).normalized()
				if escape==Vector2.ZERO: escape = Vector2.UP
			elif skill=="beam":
				var relative: Vector2 = f.pos-shot.origin
				if relative.dot(shot.dir)<0 or relative.dot(shot.dir)>c.skills.beam_range(shot.move)+80: continue
				if absf(relative.dot(shot.dir.orthogonal()))>c.skills.beam_half_width(shot)+55: continue
				escape = shot.dir.orthogonal()
				if relative.dot(escape)<0: escape = -escape
			elif skill in ["","wave"]:
				var velocity: Vector2 = shot.get("vel",Vector2.ZERO)
				if velocity.length_squared()<1: continue
				var relative: Vector2 = f.pos-shot.pos
				var arrival = relative.dot(velocity)/velocity.length_squared()
				var miss = (relative-velocity*arrival).length()
				var width = 180.0*shot.get("scale",1.0) if skill=="wave" else shot.get("radius",12)+30
				if arrival<0 or arrival>0.65 or miss>width+20: continue
				escape = velocity.normalized().orthogonal()
				if relative.dot(escape)<0: escape = -escape
			else: continue
			if escape!=Vector2.ZERO: break
		if escape!=Vector2.ZERO:
			var best = Vector2.ZERO
			var score = 0.0
			var court = bounds(c)
			for direction in [escape,escape.rotated(PI/4),escape.rotated(-PI/4),-escape]:
				var destination: Vector2 = (f.pos+direction*155).clamp(court.position,court.end)
				var clear = true
				for rock in c.rocks:
					if rock.hp>0 and Geometry2D.get_closest_point_to_segment(rock.pos,f.pos,destination).distance_to(rock.pos)<50: clear = false
				var travel = f.pos.distance_to(destination)
				if clear and travel>score:
					score = travel
					best = (destination-f.pos).normalized()
			if score>40:
				f.dodge_direction = best
				f.dodge_left = 0.5
				f.dodge_cooldown = 1.8
	if f.dodge_left>0:
		f.energy = maxf(0,f.energy-12*dt)
		f.sprinting = true
		return f.dodge_direction
	return Vector2.ZERO

func tests(c):
	c.pick(25,7)
	c.fields.active = 1
	for delta in [Vector2(-10000,0),Vector2(10000,0),Vector2(0,-10000),Vector2(0,10000)]:
		c.move_fighter(c.player,delta)
		c.check(c.player.pos==c.player.pos.clamp(bounds(c).position,bounds(c).end),"Fighter stays inside court after movement/knockback")
	c.player.pos = Vector2(600,600)
	c.enemy.pos = Vector2(900,600)
	c.projectile(c.player.pos,Vector2.RIGHT,600,20,12,true,Color.WHITE)
	c.shots.back().age = 0.2
	var energy = c.enemy.energy
	var evade = dodge(c,0.04)
	c.check(evade!=Vector2.ZERO and c.enemy.energy<energy and c.enemy.inv==0,"AI sprints away from visible projectile without invulnerability")
	c.enemy.ailment = "sleep"
	c.check(dodge(c,0.04)==Vector2.ZERO,"Sleep prevents AI sprint")
	c.pick(25,7)
	c.fields.active = 1
	c.enemy.pos = bounds(c).position+Vector2(8,8)
	c.shots.append({"skill":"lightning","friendly":true,"life":1.0,"age":0.2,"delay":0.75,"pos":c.enemy.pos,"radius":110.0})
	var escape = dodge(c,0.04)
	c.check(escape!=Vector2.ZERO and escape.y>=0,"AI chooses inward escape near arena boundary")
	c.enemy.dodge_left = 0
	c.enemy.dodge_cooldown = 0
	c.enemy.energy = 0
	c.check(dodge(c,0.04)==Vector2.ZERO,"AI cannot sprint without energy")
	c.pick(25,7)
	c.Conditions.apply(c,c.player,{"boosts":{"atk":2,"def":-1,"spa":1,"spe":-2}}, {})
	c.Conditions.tick(c.player,60)
	c.check(c.player.stages.get("atk",0)==2 and c.player.stages.get("def",0)==-1 and c.player.stages.get("spe",0)==-2,"Stat stages persist beyond former expiry")
	c.team_mode = true
	c.reset()
	c.countdown = 0
	c.Conditions.apply(c,c.player,{"boosts":{"atk":2}}, {})
	var outgoing = c.player
	c.check(c.request_switch(1) and outgoing.stages.is_empty(),"Withdrawing clears stat stages")
	c.complete_switch()
	c.pick(25,7)
	c.Conditions.apply(c,c.enemy,{"status":"slp"},{})
	c.check(c.enemy.ailment_time>=0.8 and c.enemy.ailment_time<=1.6,"Sleep has short balanced duration")
	c.Conditions.tick(c.enemy,1.61)
	c.check(c.enemy.ailment=="","Sleep expires by 1.6 seconds")
	c.Conditions.apply(c,c.enemy,{"status":"par"},{})
	c.check(c.enemy.ailment_time==3,"Paralysis lasts three seconds")
	c.Conditions.tick(c.enemy,3.01)
	c.check(c.enemy.ailment=="","Paralysis expires after three seconds")
