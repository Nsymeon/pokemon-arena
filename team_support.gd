extends RefCounted

const SCREENS = ["reflect","lightscreen","auroraveil","safeguard","mist","tailwind"]
const PROTECT = ["protect","detect"]
var teams = [{},{}]

func reset():
	teams=[{},{}]

func side(c,f) -> Dictionary:
	return teams[0 if f==c.player else 1]

func tick(dt):
	for team in teams:
		for id in team.keys():
			team[id]=maxf(0,team[id]-dt)
			if team[id]<=0: team.erase(id)

func pp_limit(move) -> int:
	return int(move.get("healing_pp_max",5)) if move.get("kind","")=="heal" else 0

func pp(f,move) -> int:
	return int(f.get("healing_pp",{}).get(move.id,pp_limit(move)))

func consume(f,move) -> bool:
	if pp_limit(move)==0: return true
	if pp(f,move)<=0: return false
	if not f.has("healing_pp"): f["healing_pp"]={}
	f.healing_pp[move.id]=pp(f,move)-1
	return true

func protect_chance(f) -> float:
	return pow(1.0/3.0,mini(6,int(f.get("protect_chain",0))))

func protection(c,f,roll: float) -> bool:
	var chance=protect_chance(f)
	if roll<chance:
		f["protect_chain"]=int(f.get("protect_chain",0))+1
		f.volatile["protect"]=1.5
		c.Conditions.note(f,"PROTECT!")
		return true
	f["protect_chain"]=0
	f.volatile.erase("protect")
	c.Conditions.note(f,"PROTECT FAILED")
	return false

func blocks(f,move) -> bool:
	return f.get("volatile",{}).get("protect",0)>0 and move.get("id","") not in ["feint","phantomforce","shadowforce","hyperspacefury","hyperspacehole"]

func cast(c,f,move,friendly) -> bool:
	if move.id in PROTECT:
		var timers=c.cooldowns if friendly else c.enemy_cooldowns
		for i in range(f.data.moves.size()):
			if f.data.moves[i].id in PROTECT: timers[i]=maxf(timers[i],12)
		protection(c,f,c.rng.randf())
		return true
	f["protect_chain"]=0
	if move.id in SCREENS:
		if move.id=="auroraveil" and c.weather.kind not in ["hail","snow"]:
			c.Conditions.note(f,"NEEDS HAIL / SNOW")
			return true
		side(c,f)[move.id]=60.0
		c.Conditions.note(f,move.name.to_upper()+" / TEAM 60s")
		return true
	return false

func multiplier(c,target,move) -> float:
	if move.get("fixed_damage",false): return 1.0
	var effects=side(c,target)
	var screen="reflect" if move.get("category","Physical")=="Physical" else "lightscreen"
	return 0.5 if effects.has(screen) or effects.has("auroraveil") else 1.0

func draw(c,f,p):
	if f.hp<=0: return
	var effects=side(c,f)
	var colors={"reflect":Color("ffb97d"),"lightscreen":Color("c4a1ff"),"auroraveil":Color("9bffef"),"safeguard":Color("a7ffc1"),"mist":Color("cdeaff"),"tailwind":Color("b4e9ff")}
	var shells=[]
	if f.volatile.get("protect",0)>0: shells.append(["PROTECT",Color("d8ffb0")])
	for id in effects: shells.append([id.to_upper()+" %ds"%ceili(effects[id]),colors[id]])
	var center: Vector2=p+Vector2(0,-35)
	for i in range(shells.size()):
		var radius=54+i*4
		var color: Color=shells[i][1]
		c.draw_circle(center,radius,Color(color,0.065))
		c.draw_arc(center,radius-2,0,TAU,64,Color(color,0.12),7,true)
		var meridian=PackedVector2Array()
		for step in range(33):
			var angle=step*TAU/32
			meridian.append(center+Vector2(cos(angle)*radius*0.4,sin(angle)*radius))
		c.draw_polyline(meridian,Color(color,0.16),1,true)
		c.draw_arc(center,radius,0,TAU,64,Color(color,0.55),2,true)
		c.draw_arc(center,radius-5,-2.6,-1.4,20,Color(color,0.8),3,true)
		c.label_at(shells[i][0],p+Vector2(-55,30+i*13),10,color)
	var stat_colors={"atk":Color("ffad86"),"def":Color("ffe49a"),"spa":Color("f4afff"),"spd":Color("b5bcff"),"spe":Color("8effdd"),"accuracy":Color("e5ffaa"),"evasion":Color("b5e6ff")}
	if f.stages.values().any(func(value): return value!=0):
		c.draw_circle(center,53,Color(0.6,0.8,1,0.035))
		c.draw_arc(center,53,0,TAU,64,Color(0.7,0.85,1,0.25),1,true)
	var index=0
	for stat in f.stages:
		var amount=int(f.stages[stat])
		if amount==0: continue
		var color: Color=stat_colors.get(stat,Color.WHITE)
		if amount<0: color=color.darkened(0.65)
		var angle=-PI/2+index*TAU/7+c.clock_time*0.2
		var point=center+Vector2.from_angle(angle)*65
		c.draw_circle(point,14,Color(color,0.9))
		c.draw_arc(point,14,0,TAU,24,Color("b7c8d1"),1,true)
		c.label_at(stat.to_upper()+str(amount) if amount<0 else stat.to_upper()+"+"+str(amount),point+Vector2(-17,4),9,Color.WHITE if amount<0 else Color("14212d"))
		index+=1

func tests(c):
	c.pick(25,7)
	var f=c.player
	c.check(protection(c,f,0.99),"First Protect always succeeds")
	c.check(is_equal_approx(protect_chance(f),1.0/3),"Second consecutive Protect has 33.33 percent chance")
	c.check(protection(c,f,0.2) and is_equal_approx(protect_chance(f),1.0/9),"Third consecutive Protect has 11.11 percent chance")
	c.check(not protection(c,f,0.2) and protect_chance(f)==1,"Failed Protect resets the streak")
	f.volatile.clear()
	protection(c,f,0)
	var hp: float=f.hp
	c.hit(f,30,Vector2.LEFT,false,{"id":"tackle","type":"Normal"})
	c.check(f.hp==hp,"Protect blocks direct attack damage")
	c.check(not c.Conditions.apply(c,f,{"status":"slp"},{"id":"hypnosis"}),"Protect blocks hostile status effects")
	c.Conditions.tick(f,1.51)
	c.check(not blocks(f,{}),"Protect expires after 1.5 seconds")
	cast(c,f,c.move_editor.book.moves.reflect,true)
	c.check(protect_chance(f)==1,"Using another move resets protection streak")
	var physical={"type":"Normal","category":"Physical"}
	var special={"type":"Normal","category":"Special"}
	c.check(multiplier(c,f,physical)==0.5 and multiplier(c,f,special)==1,"Reflect reduces only physical damage")
	cast(c,f,c.move_editor.book.moves.lightscreen,true)
	c.check(multiplier(c,f,special)==0.5,"Light Screen reduces special damage")
	teams[0]["auroraveil"]=60.0
	c.check(multiplier(c,f,physical)==0.5,"Screens and Aurora Veil do not multiply their reductions")
	c.check(multiplier(c,c.enemy,physical)==1,"Team screens never protect the opposing side")
	teams[0]["safeguard"]=60.0
	c.check(not c.Conditions.apply(c,f,{"status":"psn"},{"id":"toxic"}),"Safeguard blocks incoming status")
	teams[0]["mist"]=60.0
	c.check(not c.Conditions.apply(c,f,{"boosts":{"def":-1}},{"id":"leer"}),"Mist blocks hostile stat drops")
	c.check(c.Conditions.apply(c,f,{"boosts":{"def":-1}},{"id":"closecombat"},false),"Mist permits self-inflicted stat drops")
	var old=c.player
	c.player=c.replacement(true,0)
	c.check(multiplier(c,c.player,physical)==0.5,"Screen protection follows a replacement Pokemon")
	c.player=old
	tick(59.9)
	c.check(side(c,f).has("reflect"),"Screens last for almost a minute")
	tick(0.11)
	c.check(side(c,f).is_empty(),"Screens expire after 60 seconds")
	c.pick(25,7)
	var heal=c.move_editor.book.moves.recover.duplicate(true)
	c.player.data.moves[0]=heal
	for i in range(5):
		c.player.energy=100
		c.player.action_lock=0
		c.player.movement_lock=0
		c.cooldowns[0]=0
		c.player.hp=10
		c.check(c.use_move(c.player,c.enemy,0,Vector2.RIGHT,true),"Healing PP use succeeds")
		c.check(is_equal_approx(c.player.movement_lock,1),"Healing roots the caster for one second")
	c.player.action_lock=0
	c.player.movement_lock=0
	c.cooldowns[0]=0
	c.player.energy=100
	c.check(pp(c.player,heal)==0 and not c.use_move(c.player,c.enemy,0,Vector2.RIGHT,true),"Sixth healing attempt is blocked at zero PP")
	c.check(pp(c.player,heal)==0,"Unavailable cast does not change PP")
	c.check(pp(c.replacement(true,0),heal)==5,"A different Pokemon has independent healing PP")
	c.player_states=[c.player,c.replacement(true,0)]
	c.activate_player(1)
	c.activate_player(0)
	c.check(pp(c.player,heal)==0,"Switching out and back cannot restore healing PP")
	c.pick(25,7)
	c.player.data.moves[0]=c.move_editor.book.moves.protect.duplicate(true)
	c.check(c.use_move(c.player,c.enemy,0,Vector2.RIGHT,true) and c.cooldowns[0]==12,"Protect uses the 12-second cooldown")
	c.reset()
	c.check(teams[0].is_empty() and pp(c.player,heal)==5,"New battle clears screens and restores healing PP")
