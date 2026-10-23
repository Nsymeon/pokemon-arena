extends RefCounted

var states: Array = []
var used = 0
var cooldown = 8.0
var timer = -1.0
var target = -1

func reset(c):
	states.clear()
	used = 0
	cooldown = 8.0
	timer = -1
	target = -1
	if not c.team_mode: return
	for slot in range(c.enemy_party_size()):
		c.enemy_active = slot
		states.append(c.enemy if slot==0 else c.replacement(false,c.enemy_team[slot]))
	c.enemy_active = 0

func reserve(c) -> int:
	for i in range(states.size()):
		if i!=c.enemy_active and states[i].hp>0: return i
	return -1

func activate(c,slot):
	c.enemy_active = slot
	c.enemy = states[slot]
	c.enemy.pos = c.FIELD.size*Vector2(0.66,0.5)
	c.enemy.face = -1
	c.enemy.heading = Vector2.LEFT
	c.enemy.entering = true
	c.enemy["ability_entered"]=false
	c.enemy.fainted = false
	for key in ["inv","flash","dash_time","attack_time","walk_time"]: c.enemy[key] = 0.0
	c.enemy.dash_move = {}
	c.enemy_cooldowns = [0.0,0.0,0.0,0.0]
	c.ai_timer = 1.0

func request(c,slot) -> bool:
	if not c.team_mode or used>=3 or timer>=0 or cooldown>0 or c.countdown>0 or c.result!="" or c.paused or c.switch_menu or c.switch_time>=0: return false
	if c.enemy.hp<=0 or c.player.hp<=0 or slot<0 or slot>=states.size() or slot==c.enemy_active or states[slot].hp<=0: return false
	if c.Conditions.immobilized(c.enemy) or c.enemy.volatile.get("partiallytrapped",0)>0 or c.enemy.action_lock>0 or c.enemy.dash_time>0: return false
	# Do not erase or evade already launched attacks through a trainer substitution.
	if c.shots.any(func(s):return s.life>0): return false
	if c.abilities.trapped(c.enemy,c.player): return false
	c.abilities.withdrawn(c.enemy)
	c.enemy.volatile.clear()
	c.enemy["protect_chain"]=0
	c.enemy.stages.clear()
	c.enemy.toxic_tick = 0
	c.enemy.attack_time = 0
	c.enemy.walk_time = 0
	c.enemy.sprinting = false
	c.player.entering = false
	c.enemy.entering = false
	states[c.enemy_active] = c.enemy
	used += 1
	target = slot
	timer = 0
	c.notice = "OPPONENT SWITCH / %d OF 3" % used
	c.notice_time = 2
	return true

func complete(c):
	activate(c,target)
	target = -1
	timer = -1
	cooldown = c.rng.randf_range(12,20)
	c.countdown = c.SEND_OUT_TIME

func tick(c,dt):
	cooldown = maxf(0,cooldown-dt)
	if cooldown>0 or used>=3 or reserve(c)<0: return
	var danger = 0.0
	for move in c.player.data.moves:
		if move.damage>0: danger = maxf(danger,c.Dex.effectiveness(move.type,c.Conditions.types(c.enemy)))
	if c.enemy.hp/c.enemy.data.hp>0.35 and danger<2 and c.rng.randf()>0.2:
		cooldown = c.rng.randf_range(4,7)
		return
	var best = -1
	var score = -100.0
	for i in range(states.size()):
		if i==c.enemy_active or states[i].hp<=0: continue
		var f = states[i]
		var offense = 0.0
		for move in f.data.moves:
			if move.damage>0: offense = maxf(offense,c.Dex.effectiveness(move.type,c.Conditions.types(c.player)))
		var rating = offense + f.hp/f.data.hp
		if rating>score: best = i; score = rating
	if not request(c,best): cooldown = 2.0

func draw_recall(c):
	var p: Vector2 = c.enemy.pos
	var hand: Vector2 = c.trainer_hand(false)
	var progress = smoothstep(0,0.7,timer)
	var center = p.lerp(hand,progress)
	c.draw_line(hand,center,Color(1,0.4,0.5,0.7),4,true)
	var texture = c.portrait(c.enemy.data)
	if texture:
		var size = texture.get_size()*78.0/maxf(texture.get_width(),texture.get_height())*(1-progress)
		c.draw_texture_rect(texture,Rect2(center-size/2,size),false,Color(1,0.4,0.5,1-progress))
	c.draw_pokeball(hand,12)

func tests(c):
	c.team_mode = true
	c.reset()
	c.countdown = 0
	c.shots.clear()
	c.enemy.hp = 80
	c.enemy.energy = 45
	c.enemy_cooldowns[0] = 2
	var first = c.enemy
	cooldown = 0
	c.enemy.volatile["underground"] = 1
	c.check(not request(c,1),"Enemy cannot switch while using Dig")
	c.enemy.volatile.clear()
	c.shots.append({"life":1.0})
	c.check(not request(c,1) and used==0,"Enemy waits for committed attacks without spending switch budget")
	c.shots.clear()
	for slot in [1,0,1]:
		cooldown = 0
		c.countdown = 0
		c.enemy.action_lock = 0
		c.check(request(c,slot),"Opponent can voluntarily switch within three-change budget")
		complete(c)
	c.check(first.hp==80 and first.energy==45,"Enemy reserves keep HP and energy")
	cooldown = 0
	c.countdown = 0
	c.check(not request(c,0) and used==3,"Fourth voluntary enemy switch is rejected")
	c.enemy.hp = 0
	var next = reserve(c)
	c.check(next==0,"Fainted enemy can return to an earlier living reserve")
	activate(c,next)
	c.check(c.enemy==first and c.enemy.hp==80,"Returning enemy receives no free healing")
	c.check(c.enemy_cooldowns==[0.0,0.0,0.0,0.0],"Returning enemy resets every move cooldown")
	for f in states: f.hp = 0
	c.check(reserve(c)==-1,"Enemy party exhausts only after every member faints")
	c.pick(25,7)
