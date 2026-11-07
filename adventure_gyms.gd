extends RefCounted
# Adventure-only source builds. Daily/Free Battle teams never use this table.
var a
var leaders: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/gym-leaders.json")).leaders

func party(kind: String) -> Array:
	if not leaders.has(kind): return []
	return leaders[kind].party.map(func(mon):return [int(mon.id),int(mon.level)])

func prepare(kind: String):
	var leader=leaders[kind]
	a.c.opponent_identity=leader.identity
	a.encounter["gym_items"]=leader.items.duplicate()
	for i in leader.party.size():
		var source=leader.party[i]
		a.c.enemy_party[i].moves=a.inventory.definitions(source.moves)
		a.c.enemy_party[i]["held_item"]=source.held_item

func try_item() -> bool:
	var c=a.c
	if not a.in_battle or not leaders.has(a.encounter.get("kind","")): return false
	if c.paused or c.selecting or c.switch_menu or c.countdown>0 or c.result!="" or a.modal!="" or a.capture_time>0: return false
	if c.enemy_bench.timer>=0 or c.switch_time>=0: return false
	var f=c.enemy
	if f.hp<=0 or c.player.hp<=0 or f.get("action_lock",0)>0 or f.get("movement_lock",0)>0 or f.get("charge_left",0)>0 or f.dash_time>0: return false
	if f.volatile.get("airborne",0)>0 or f.volatile.get("underground",0)>0 or c.skills.riding(c,f): return false
	var items=a.encounter.get("gym_items",[])
	var alive=c.enemy_bench.states.filter(func(mon):return mon.hp>0).size()
	for i in items.size():
		# FireRed reserves later inventory slots while many partners remain.
		if i>0 and alive>(items.size()-i)+1: continue
		var id=str(items[i])
		if id=="": continue
		var item=a.inventory.ITEMS[id]
		var heal=float(item.get("heal",0))*f.data.hp
		var cure=id=="fullheal" and (f.ailment in item.cure or f.volatile.get("confusion",0)>0)
		if heal>0 and (f.hp<f.data.hp/4.0 or f.data.hp-f.hp>heal):
			# Keep the project's shared percentage healing until the economy pass.
			f.hp=minf(f.data.hp,f.hp+heal)
		elif cure:
			f.ailment=""; f.ailment_time=0; f.toxic_tick=0; f.dot_tick=0
			f.volatile.erase("confusion")
		else: continue
		items[i]=""
		f.action_lock=1.0; f.movement_lock=1.0; f.sprinting=false
		f.dodge_left=0.0
		c.ai_timer=maxf(c.ai_timer,1.0)
		c.notice=leaders[a.encounter.kind].name+" USED "+str(item.name).split(" / ")[0].to_upper()
		c.notice_time=2.0
		c.Conditions.note(f,"+HP" if heal>0 else "STATUS CURED")
		c.burst(f.pos,Color("82e8af"),14)
		return true
	return false
