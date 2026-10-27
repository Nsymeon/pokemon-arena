extends RefCounted

func threat(c) -> bool:
	# Respond only to visible, already launched attacks, not to player input.
	for shot in c.shots:
		if not shot.get("friendly",false) or shot.get("life",0)<=0 or shot.get("hit_done",false) or shot.get("age",0)<0.15: continue
		var pos=Vector2(shot.get("pos",c.player.pos))
		if pos.distance_to(c.enemy.pos)<300: return true
		if shot.get("skill","")=="beam":
			var delta=c.enemy.pos-Vector2(shot.origin); var direction=Vector2(shot.dir)
			if delta.dot(direction)>0 and delta.dot(direction)<c.skills.beam_range(shot.move) and absf(delta.cross(direction))<c.skills.beam_half_width(shot)+40: return true
	return false

func score(c,move,base,distance) -> float:
	if base<0: return base
	var f=c.enemy; var other=c.player; var id=str(move.id)
	var identity=str(c.opponent_identity)
	if id in c.support.PROTECT:
		return (5.0*c.support.protect_chance(f)) if threat(c) and f.volatile.get("protect",0)<=0 else -1.0
	if id=="auroraveil" and c.weather.kind not in ["snow","hail"]: return -1.0
	if c.weather.MOVES.has(id):
		var weather=c.weather.MOVES[id]
		if c.weather.kind==weather: return -1.0
		var benefit=0.0
		for ally in c.enemy_bench.states:
			if ally.hp<=0: continue
			for attack in ally.data.moves:
				if weather=="sun" and (attack.type=="Fire" or attack.id=="solarbeam") or weather=="rain" and (attack.type=="Water" or attack.id=="thunder"): benefit+=0.4
		if weather=="sand" and f.data.types.any(func(t):return t in ["Rock","Ground","Steel"]): benefit+=1
		if weather in ["hail","snow"] and "Ice" in f.data.types: benefit+=1
		return 1.0+minf(benefit,2.0) if benefit>0 else -1.0
	if move.kind=="heal": return 4.5 if f.hp/f.data.hp<0.35 else base
	if move.kind=="status":
		if move.get("status","")!="" and other.ailment!="": return -1.0
		if move.get("status","")=="paralysis" and "Ground" in c.Conditions.types(other) and move.type=="Electric": return -1.0
		if move.get("status","") in ["poison","toxic"] and c.Conditions.types(other).any(func(t):return t in ["Poison","Steel"]): return -1.0
		if identity in ["koga","agatha","sabrina"]: base+=0.8
		if other.hp/other.data.hp<0.25: base*=0.4
	if move.kind=="buff":
		var boosts=move.get("boosts",{})
		if not boosts.is_empty() and boosts.keys().all(func(stat):return int(f.stages.get(stat,0))>=2): return -1.0
		if f.hp/f.data.hp<0.4: return -1.0
		if identity in ["brock","bruno","giovanni"]: base+=0.5
	if id in c.support.SCREENS:
		if identity in ["sabrina","lorelei","blue"]: base+=0.65
		if id in ["reflect","lightscreen"]:
			var category="Physical" if id=="reflect" else "Special"
			if not other.data.moves.any(func(m):return m.damage>0 and m.get("category","")==category): return -1.0
	if move.damage>0:
		if c.Dex.effectiveness(move.type,c.Conditions.types(other))<=0: return -1.0
		base*=clampf(float(move.damage)/35.0,0.5,2.0)
		base*=1.15 if (move.get("category","Physical")=="Physical" and f.data.base_stats.atk>f.data.base_stats.spa) or (move.get("category","")=="Special" and f.data.base_stats.spa>f.data.base_stats.atk) else 1.0
		base*=c.weather.power(move)
		if move.damage*c.Dex.effectiveness(move.type,c.Conditions.types(other))*(1.5 if move.type in c.Conditions.types(f) else 1.0)>=other.hp: base+=3.0
		if other.ailment=="sleep": base+=0.6
		if move.get("charge_time",0)>0 and other.get("sprinting",false): base*=0.8
	return base

func matchup(c,f) -> float:
	var offense=0.0; var danger=0.0
	for move in f.data.moves:
		if move.damage>0: offense=maxf(offense,c.Dex.effectiveness(move.type,c.Conditions.types(c.player)))
	for move in c.player.data.moves:
		if move.damage>0: danger=maxf(danger,c.Dex.effectiveness(move.type,c.Conditions.types(f)))
	return offense+f.hp/f.data.hp-danger*0.8

func tests(c):
	c.pick(25,7); c.shots.clear()
	var protect={"id":"protect","kind":"guard","damage":0,"type":"Normal"}
	c.check(score(c,protect,2,100)<0,"AI saves Protect when no visible attack threatens it")
	c.shots.append({"friendly":true,"life":1.0,"age":0.3,"pos":c.enemy.pos,"hit_done":false})
	c.check(score(c,protect,2,100)>0,"AI reacts to visible incoming attacks with Protect")
	c.shots.clear(); c.pick(27,25)
	c.check(score(c,{"id":"thunderbolt","kind":"bolt","type":"Electric","damage":40},2,100)<0,"AI does not attack an immune matchup")
