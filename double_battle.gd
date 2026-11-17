extends RefCounted
# Two simultaneous fighters per side. Player controls one; partner uses arena AI.
var enabled=false
var player_slots=[]
var enemy_slots=[]

func active(c) -> bool: return enabled and c.adventure.in_battle and c.adventure.encounter.get("source_double_battle",false)
func reset(): enabled=false; player_slots.clear(); enemy_slots.clear()
func squad(c,friendly: bool) -> Array:
	var pool=c.player_states if friendly else c.enemy_bench.states
	return (player_slots if friendly else enemy_slots).map(func(slot):return pool[slot])

func start(c):
	reset()
	if not c.adventure.encounter.get("source_double_battle",false): return
	enabled=true
	player_slots.append(c.player_active)
	for i in c.player_states.size():
		if i!=c.player_active and c.player_states[i].hp>0 and player_slots.size()<2: player_slots.append(i)
	for i in mini(2,c.enemy_bench.states.size()): enemy_slots.append(i)
	for friendly in [true,false]:
		var pool=c.player_states if friendly else c.enemy_bench.states
		for i in pool.size():
			pool[i]["battle_side"]=0 if friendly else 1; pool[i]["battle_slot"]=i
			pool[i]["double_cooldowns"]=[0.,0.,0.,0.]; pool[i]["double_ai"]=.6+i*.35
		var slots=player_slots if friendly else enemy_slots
		for lane in slots.size():
			place(c,pool[slots[lane]],friendly,lane); pool[slots[lane]].double_entry=0
			pool[slots[lane]].action_lock=0; pool[slots[lane]].movement_lock=0; pool[slots[lane]].inv=0
	focus(c,c.player_active)
	c.notice="DOUBLE BATTLE / two partners / Switch menu: choose an active partner to control"; c.notice_time=6
	c.adventure.mark_participant()

func place(c,f,friendly,lane):
	var bounds=c.balance.bounds(c)
	f.pos=bounds.position+bounds.size*Vector2(.3 if friendly else .7,.35+.3*lane)
	f.heading=Vector2.RIGHT if friendly else Vector2.LEFT; f.face=f.heading.x
	f["ability_entered"]=false; f.entering=true; f["double_entry"]=c.SEND_OUT_TIME
	f["double_cooldowns"]=[0.,0.,0.,0.]; f.fainted=false; f.inv=c.SEND_OUT_TIME
	f.action_lock=c.SEND_OUT_TIME; f.movement_lock=c.SEND_OUT_TIME
	c.gear.withdrawn(f)

func focus(c,slot) -> bool:
	if slot not in player_slots or c.player_states[slot].hp<=0: return false
	c.player_active=slot; c.player=c.player_states[slot]; c.cooldowns=c.player.double_cooldowns
	c.click_move=false; c.quick_attack_active=false; c.sprinting=false; c.switch_menu=false
	return true

func target(c):
	var living=squad(c,false).filter(func(f):return f.hp>0)
	if living.is_empty(): return
	var mouse=c.screen_to_arena(c.get_global_mouse_position())
	living.sort_custom(func(x,y):return x.pos.distance_squared_to(mouse)<y.pos.distance_squared_to(mouse))
	c.enemy=living[0]; c.enemy_active=int(c.enemy.battle_slot); c.enemy_cooldowns=c.enemy.double_cooldowns

func ready_foes(c,f) -> Array:
	return c.opponents(c.is_friendly(f)).filter(func(other):return other.hp>0)

func mark_entry(c,f):
	if f.hp<=0 or f.get("ability_entered",false): return
	var opponents=ready_foes(c,f)
	if opponents.is_empty(): return
	c.abilities.entry(f,opponents[0])
	if c.abilities.name_of(f)=="Intimidate":
		for other in opponents.slice(1): c.Conditions.apply(c,other,{"boosts":{"atk":-1}},{})

func tick(c,dt):
	settle(c,dt); target(c)
	if c.result!="": return
	c.adventure.mark_participant(); c.support.tick(dt)
	var fighters=squad(c,true)+squad(c,false)
	for f in fighters: mark_entry(c,f)
	c.weather.suppressed=fighters.any(func(f):return f.hp>0 and c.abilities.name_of(f) in ["Cloud Nine","Air Lock"])
	c.weather.tick(c,dt); c.round_time+=dt; c.notice_time-=dt
	c.adventure.encounter.battle_seconds=float(c.adventure.encounter.get("battle_seconds",0))+dt
	c.switch_cooldown=maxf(0,c.switch_cooldown-dt)
	c.enemy_bench.tick(c,dt)
	if c.enemy_bench.timer>=0: return
	for f in fighters:
		f.double_entry=maxf(0,float(f.get("double_entry",0))-dt)
		for i in 4: f.double_cooldowns[i]=maxf(0,f.double_cooldowns[i]-dt)
		if f.hp>0: c.tick_fighter(f,dt)
	if c.player.hp>0 and c.player.dash_time<=0 and c.player.double_entry<=0:
		c.sprint_movement(c.movement_input(),dt,c.controls.held("battle_sprint"))
	for f in fighters:
		if f.hp>0 and f!=c.player and f.double_entry<=0: ai(c,f,dt)
	c.update_projectiles(dt); settle(c,0)

func ai(c,f,dt):
	var targets=ready_foes(c,f)
	if targets.is_empty(): return
	targets.sort_custom(func(x,y):return x.pos.distance_squared_to(f.pos)<y.pos.distance_squared_to(f.pos))
	var opponent=targets[0]; var direction: Vector2=(opponent.pos-f.pos).normalized()
	var distance=f.pos.distance_to(opponent.pos)
	var player=c.player; var enemy=c.enemy; var pc=c.cooldowns; var ec=c.enemy_cooldowns; var ai_time=c.ai_timer
	var enemy_index=c.enemy_active
	var friendly=c.is_friendly(f)
	if not friendly:
		c.enemy=f; c.player=opponent; c.enemy_cooldowns=f.double_cooldowns; c.ai_timer=f.double_ai
		c.enemy_active=int(f.battle_slot)
		c.update_ai(dt); f.double_ai=c.ai_timer
	else:
		c.player=f; c.enemy=opponent; c.cooldowns=f.double_cooldowns
		if not c.Conditions.immobilized(f) and f.dash_time<=0 and not c.skills.riding(c,f):
			var preferred=130 if f.data.role=="brawler" else 260
			var walk=direction*(1. if distance>preferred+40 else -.5 if distance<preferred-50 else 0.)
			walk+=direction.orthogonal()*sin(c.clock_time*1.3+float(f.battle_slot))*0.35
			c.move_fighter(f,walk.limit_length()*f.data.speed*.75*c.Conditions.speed(f)*c.abilities.speed(f)*c.fields.movement(f)*(2. if c.support.side(c,f).has("tailwind") else 1.)*dt)
		f.double_ai-=dt
		if f.double_ai<=0:
			f.double_ai=c.difficulty.reaction(c.rng); var best=-1; var score=-INF
			for i in f.data.moves.size():
				var move=f.data.moves[i]
				if f.double_cooldowns[i]>0 or f.energy<move.cost or not c.gear.allowed(f,move.id): continue
				if c.support.pp_limit(move)>0 and c.support.pp(f,move)<=0: continue
				var value=c.Dex.effectiveness(move.type,c.Conditions.types(opponent))*(1.5 if move.type in c.Conditions.types(f) else 1.)
				if move.kind=="heal": value=4 if f.hp<f.data.hp*.6 else -1
				if move.kind in ["status","pulse","dash"] and distance>(760 if move.id=="surf" else 320): continue
				if move.kind=="status": value=1.5 if opponent.ailment=="" else -1
				if move.kind in ["buff","guard"]: value=1.4 if f.stages.is_empty() else -1
				if move.id in c.support.SCREENS: value=1.7 if not c.support.side(c,f).has(move.id) else -1
				if value>score: best=i; score=value
			if best>=0 and score>=0: c.use_move(f,opponent,best,direction,true)
		if f.dash_time>0 and not f.dash_move.is_empty() and distance<44:
			c.hit(opponent,f.dash_move.damage,direction,true,f.dash_move,f); f.dash_time=0
	c.player=player; c.enemy=enemy; c.cooldowns=pc; c.enemy_cooldowns=ec; c.ai_timer=ai_time
	c.enemy_active=enemy_index

func settle(c,dt,replace=true):
	var selected=c.enemy; var enemy_index=c.enemy_active
	for friendly in [true,false]:
		var pool=c.player_states if friendly else c.enemy_bench.states
		var slots=player_slots if friendly else enemy_slots
		for lane in slots.size():
			var f=pool[slots[lane]]
			if f.hp>0: continue
			if not f.fainted:
				f.fainted=true; f["double_faint"]=0.; f["faint_frame"]=c.art.frame(f); f["faint_delay"]=0.
				f.dash_time=0; f.attack_time=0; f.charge_left=0; f.pending_move={}; f.stages.clear()
				if not friendly:
					c.enemy=f; c.enemy_active=int(f.battle_slot); c.adventure.record_knockout(true)
			f.double_faint=float(f.get("double_faint",0))+dt
			if not replace or f.double_faint<c.FAINT_RESULT_TIME: continue
			for slot in pool.size():
				if slot in slots or pool[slot].hp<=0: continue
				var controlled=friendly and slots[lane]==c.player_active
				slots[lane]=slot; place(c,pool[slot],friendly,lane)
				if controlled: focus(c,slot)
				break
	c.enemy=selected; c.enemy_active=enemy_index
	if c.player.hp<=0:
		for slot in player_slots:
			if c.player_states[slot].hp>0: focus(c,slot); break
	if replace:
		var ending=outcome(c)
		if ending!="": c.result=ending; c.result_time=0; c.quick_attack_active=false

func outcome(c) -> String:
	var lost=c.player_states.all(func(f):return f.hp<=0)
	var won=c.enemy_bench.states.all(func(f):return f.hp<=0)
	return "DRAW" if lost and won else "DEFEAT" if lost else "VICTORY" if won else ""

func resolution(c,delta):
	var left=delta
	while left>.00001 and not resolution_ready(c):
		var dt=minf(left,.04); left-=dt; c.support.tick(dt)
		for f in squad(c,true)+squad(c,false):
			f.inv=maxf(0,f.inv-dt); f.flash=maxf(0,f.flash-dt)
			if f.volatile.has("protect"): f.volatile.protect=maxf(0,f.volatile.protect-dt)
		c.update_projectiles(dt); settle(c,dt,false); c.result=outcome(c); c.result_time+=dt

func resolution_ready(c) -> bool:
	return c.result_time>=c.FAINT_RESULT_TIME and c.shots.is_empty() and (squad(c,true)+squad(c,false)).all(func(f):return f.hp>0 or f.get("double_faint",0)>=c.FAINT_RESULT_TIME)

func switched(c,old_slot,new_slot):
	var lane=player_slots.find(old_slot)
	if lane<0: return
	player_slots[lane]=new_slot; place(c,c.player_states[new_slot],true,lane); focus(c,new_slot)
	global_entry(c,c.player)

func global_entry(c,f):
	# The shared send-out countdown already freezes the battle for this arrival.
	for other in squad(c,true)+squad(c,false): other.entering=other==f
	f.double_entry=0.; f.action_lock=0.; f.movement_lock=0.; f.inv=0.

func enemy_switched(c,old_slot,new_slot):
	var lane=enemy_slots.find(old_slot)
	if lane<0: return
	enemy_slots[lane]=new_slot; place(c,c.enemy_bench.states[new_slot],false,lane)
	c.enemy=c.enemy_bench.states[new_slot]; c.enemy_cooldowns=c.enemy.double_cooldowns
	global_entry(c,c.enemy)

func draw(c):
	var fighters=squad(c,true)+squad(c,false)
	fighters.sort_custom(func(x,y):return x.pos.y<y.pos.y)
	var time=c.result_time; var countdown=c.countdown
	for f in fighters:
		c.result_time=float(f.get("double_faint",0)); c.countdown=maxf(countdown,float(f.get("double_entry",0)))
		c.draw_creature(f,c.is_friendly(f)); c.skills.draw_charge(c,f)
		if c.countdown>0: c.draw_ball_sequence(f,c.is_friendly(f))
		if f.hp>0:
			c.bar(f.pos+Vector2(-42,-91),84,f.hp/f.data.hp,c.MINT if c.is_friendly(f) else Color("f18c71"),5)
			c.label_at(f.data.name+ (" / YOU" if f==c.player else " / ALLY" if c.is_friendly(f) else ""),f.pos+Vector2(-45,-101),12)
	c.result_time=time; c.countdown=countdown
