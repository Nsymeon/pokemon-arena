extends RefCounted
# FireRed's timed Sevii tower; separate from the custom level-50 BP Battle Tower.
var a
var book: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/trainer-tower.json"))
const MODES=["single","double","knockout","mixed"]
const PREFIX="MAP_TRAINER_TOWER_"
func state():
	if not a.data.has("trainer_tower"): a.data.trainer_tower={"active":false,"format":"single","floor":0,"trainer":0,"seconds":0.,"pending":false,"records":{},"prizes":{}}
	return a.data.trainer_tower
func valid(data) -> bool:
	if not data.has("trainer_tower"): return true
	var s=data.trainer_tower
	if not s is Dictionary or not s.get("active") is bool or not s.get("pending") is bool or s.get("format") not in MODES: return false
	for key in ["floor","trainer","seconds"]:
		var v=s.get(key)
		if not (v is int or v is float) or not is_finite(v) or v<0 or v>{"floor":8,"trainer":2,"seconds":3600}[key]: return false
		if key!="seconds" and v!=int(v): return false
	if not s.get("records") is Dictionary or not s.get("prizes") is Dictionary: return false
	for mode in s.records:
		var time=s.records[mode]
		if mode not in MODES or not (time is int or time is float) or not is_finite(time) or time<0 or time>3600: return false
	for mode in s.prizes:
		if mode not in MODES or not s.prizes[mode] is bool: return false
	return not s.pending or s.active and s.floor<8
func floor_number(map:String) -> int:
	if map.begins_with(PREFIX) and map.ends_with("F"):
		var n=map.trim_prefix(PREFIX).trim_suffix("F")
		if n.is_valid_int(): return int(n)
	return 9 if map==PREFIX+"ROOF" else 0
func current_floor(): return book.floors[book.formats[state().format][mini(7,int(state().floor))]]
func tick(dt):
	if not a.data.has("trainer_tower"): return
	var s=state()
	if s.active and (a.exploring or a.in_battle) and a.world.current.begins_with(PREFIX) and not a.c.paused: s.seconds=minf(3600,float(s.seconds)+dt)
func recover():
	if a.data.has("trainer_tower") and state().pending:
		state().active=false; state().pending=false; state().floor=0; state().trainer=0
func gate(destination) -> String:
	var floor=floor_number(destination)
	if floor==0: return ""
	var s=state()
	if not s.active and floor!=9: return "Speak to the Trainer Tower receptionist to start a timed challenge."
	if floor>int(s.floor)+1: return "Defeat every trainer on this floor before climbing the stairs."
	return ""
func entered():
	if a.data.has("trainer_tower") and state().active and not a.world.current.begins_with(PREFIX): state().active=false; state().pending=false
func menu():
	var list=a.inventory.page("TRAINER TOWER / eight floors / race the clock")
	a.inventory.row(list,"Opponents match your highest party level. No EXP, EVs or prize money.",func():pass,true)
	for mode in MODES:
		var best=" / BEST %.2fs"%float(state().records[mode]) if state().records.has(mode) else ""
		a.inventory.row(list,mode.to_upper()+best,start.bind(mode))
	if state().active: a.inventory.row(list,"RESUME / floor "+str(int(state().floor)+1),resume)
func start(mode):
	if a.in_battle or mode not in MODES: return
	var healthy=a.data.party.filter(func(mon):return not mon.get("is_egg",false) and mon.hp>0).size()
	if healthy<(2 if mode in ["double","mixed"] else 1): a.dialog="Bring at least two healthy partners for Double or Mixed challenges."; a.clear_ui(); return
	var s=state(); s.active=true; s.format=mode; s.floor=0; s.trainer=0; s.seconds=0.; s.pending=false
	resume(); a.save()
func resume():
	if not state().active: return
	a.clear_ui(); a.dialog=""
	var map=PREFIX+(str(int(state().floor)+1)+"F" if state().floor<8 else "ROOF")
	a.world.enter(map,Vector2(9.5,18.5)*48)
func elevator():
	var list=a.inventory.page("TRAINER TOWER / return elevator")
	a.inventory.row(list,"RETURN TO LOBBY",leave)
func leave():
	if a.in_battle: return
	state().active=false; state().pending=false
	a.clear_ui(); a.world.enter(PREFIX+"LOBBY",Vector2(9.5,7.5)*48)
func npc(object) -> bool:
	var script=str(object.get("script",""))
	if script=="TrainerTower_Lobby_EventScript_Receptionist": menu(); return true
	if script=="TrainerTower_Lobby_EventScript_MartClerk": a.inventory.shop(script); return true
	if script=="TrainerTower_EventScript_Owner": complete(); return true
	if script.begins_with("TrainerTower_EventScript_") and "Trainer" in script.trim_prefix("TrainerTower_EventScript_"):
		if floor_number(a.world.current)<=state().floor: a.dialog="You cleared our floor. Keep going!"
		else: fight()
		return true
	return false
func actor_visible(object) -> bool:
	var number=floor_number(a.world.current)
	if number<1 or number>8: return true
	var script=str(object.get("script","")); var floor=book.floors[book.formats[state().format][number-1]]
	if script in ["0x0","TrainerTower_EventScript_Owner"]: return false
	if "DoublesTrainer" in script: return floor.type=="double"
	if "SinglesTrainer" in script: return floor.type=="single"
	if "KnockoutTrainer" in script: return floor.type=="knockout"
	return true
func build() -> Array:
	var floor=current_floor(); var picks=book.indices[floor.type][int(state().floor)]; var result=[]
	if floor.type=="knockout": return [floor.trainers[int(state().trainer)].mons[int(picks[int(state().trainer)])].duplicate(true)]
	for i in picks.size(): result.append(floor.trainers[i if floor.type=="double" else 0].mons[int(picks[i])].duplicate(true))
	return result
func graphics(object) -> String:
	var number=floor_number(a.world.current)
	if number<1 or number>8: return str(object.graphics_id)
	var floor=book.floors[book.formats[state().format][number-1]]
	var index=int(state().trainer) if floor.type=="knockout" and number==int(state().floor)+1 else 0
	var options=book.graphics.get(floor.trainers[index]["class"],["OBJ_EVENT_GFX_COOLTRAINER_M"])
	return options[mini(options.size()-1,1 if str(object.get("script","")).ends_with("DoublesTrainer2") else 0)]
func fight():
	var s=state()
	if a.in_battle or not s.active or s.pending or s.floor>=8 or floor_number(a.world.current)!=int(s.floor)+1: return
	if current_floor().type=="double" and a.data.party.filter(func(mon):return mon.hp>0 and not mon.get("is_egg",false)).size()<2:
		a.dialog="This floor needs two healthy partners. Visit the lobby nurse."; return
	var party=build(); var level=1
	for mon in a.data.party:
		if not mon.get("is_egg",false): level=maxi(level,int(mon.level))
	s.pending=true; a.begin_battle("trainer_tower",party.map(func(mon):return int(mon.id)),party.map(func(_mon):return level))
	if not a.in_battle: s.pending=false
func prepare():
	var party=build(); var floor=current_floor()
	a.encounter.source_double_battle=floor.type=="double"
	a.encounter.trainer_name=" & ".join(floor.trainers.map(func(t):return t.name))
	a.encounter.trainer_items=[]
	for i in party.size():
		var source=party[i]; var level=int(a.encounter.levels[i])
		a.c.enemy_party[i]=a.battle_mon(int(source.id),level,source)
		a.c.enemy_party[i].moves=a.trainers.definitions(source.moves)
func reward(won) -> String:
	var s=state()
	if not s.pending: return ""
	s.pending=false
	if not won: s.active=false; return "Trainer Tower challenge ended. Your best records are kept."
	if current_floor().type=="knockout" and int(s.trainer)<2: s.trainer+=1; return "The next trainer steps forward!"
	s.floor+=1; s.trainer=0
	return "Eight floors cleared! Meet the owner on the roof." if s.floor==8 else "Floor cleared! Continue upstairs. Time: %.2fs"%s.seconds
func after_battle(won):
	if not won:
		for mon in a.data.party: mon.hp=0. if mon.get("is_egg",false) else 1.; mon.ailment=""
		a.world.enter(PREFIX+"LOBBY",Vector2(9.5,7.5)*48); return
	if state().active and state().trainer>0:
		a.world.scenes.play([{"text":"The next Knockout challenger is ready!","duration":1.5}],fight)
func complete():
	var s=state()
	if s.floor<8: a.dialog="Clear all eight floors to earn your prize."; return
	if s.active:
		s.records[s.format]=minf(float(s.records.get(s.format,3600)),float(s.seconds)); s.active=false
	var prize=book.floors[book.formats[s.format][0]].prize
	if not s.prizes.get(s.format,false):
		if int(a.data.bag.get(prize,0))>=999: a.dialog="Make room for your prize and speak to me again."; a.save(); return
		a.data.bag[prize]=int(a.data.bag.get(prize,0))+1; s.prizes[s.format]=true
		a.dialog="Congratulations! Received "+a.inventory.ITEMS[prize].name+". Best time: %.2fs"%s.records[s.format]
	else: a.dialog="Challenge completed! Best time: %.2fs. You already received this format's prize."%s.records[s.format]
	a.save()
