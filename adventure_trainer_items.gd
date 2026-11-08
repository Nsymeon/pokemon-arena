extends RefCounted
# Shared finite inventory for source Adventure trainers; no Daily/Free items.
var a

func try_item() -> bool:
	var c=a.c
	if not a.in_battle or not a.encounter.has("trainer_id"): return false
	if c.paused or c.selecting or c.switch_menu or c.countdown>0 or c.result!="" or a.modal!="" or a.capture_time>0: return false
	if c.enemy_bench.timer>=0 or c.switch_time>=0: return false
	var f=c.enemy
	if f.hp<=0 or c.player.hp<=0 or f.get("action_lock",0)>0 or f.get("movement_lock",0)>0 or f.get("charge_left",0)>0 or f.dash_time>0: return false
	if f.volatile.get("airborne",0)>0 or f.volatile.get("underground",0)>0 or c.skills.riding(c,f): return false
	var items=a.encounter.get("trainer_items",[])
	var alive=c.enemy_bench.states.filter(func(mon):return mon.hp>0).size()
	for i in items.size():
		# Keep each original slot, including spent slots, for source reservation.
		if i>0 and alive>(items.size()-i)+1: continue
		var id=str(items[i])
		if id=="": continue
		var item=a.inventory.ITEMS[id]
		var heal=float(item.get("heal",0))*f.data.hp
		var cure=id=="fullheal" and (f.ailment in item.cure or f.volatile.get("confusion",0)>0)
		if id=="fullrestore" and f.hp<f.data.hp/4.0:
			f.hp=f.data.hp; cure=true; heal=f.data.hp
		elif heal>0 and (f.hp<f.data.hp/4.0 or f.data.hp-f.hp>heal):
			# Keep the same healing scale as the player's bag until the economy step.
			f.hp=minf(f.data.hp,f.hp+heal)
		elif not cure: continue
		if cure:
			f.ailment=""; f.ailment_time=0; f.toxic_tick=0; f.dot_tick=0
			f.volatile.erase("confusion")
		items[i]=""
		f.action_lock=1.0; f.movement_lock=1.0; f.sprinting=false; f.dodge_left=0.0
		c.ai_timer=maxf(c.ai_timer,1.0)
		c.notice=str(a.encounter.trainer_name)+" USED "+str(item.name).split(" / ")[0].to_upper()
		c.notice_time=2.0
		c.Conditions.note(f,"+HP" if heal>0 else "STATUS CURED")
		c.burst(f.pos,Color("82e8af"),14)
		return true
	return false
