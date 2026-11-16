extends RefCounted
# Outdoor rematches only; never reopens a completed Gym or a story battle.
var a
var random=RandomNumberGenerator.new()
var book: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/vs-seeker.json"))
const GIVER="VermilionCity_PokemonCenter_1F_EventScript_VSSeekerWoman"

func state() -> Dictionary:
	if not a.data.has("vs_seeker"): a.data.vs_seeker={"charge":0,"remaining":0,"map":"","ready":{},"defeated":{}}
	return a.data.vs_seeker

func owns() -> bool: return a.field.done("field:vsseeker")

func valid(data) -> bool:
	if not data.has("vs_seeker"): return true
	var s=data.vs_seeker
	if not s is Dictionary or not s.get("ready") is Dictionary or not s.get("defeated") is Dictionary: return false
	if s.get("map","")!="" and not a.world.maps.has(s.map): return false
	for key in ["charge","remaining"]:
		if not a.services.valid_steps(s.get(key,-1)) or s[key]>100: return false
	for id in s.ready:
		if not book.rematches.has(id) or not s.ready[id] is bool or not s.ready[id] or book.rematches[id].map!=s.get("map",""): return false
	for id in s.defeated:
		if not a.trainers.book.trainers.has(id) or not s.defeated[id] is bool or not s.defeated[id]: return false
	return true

func npc(object) -> bool:
	if str(object.get("script",""))==GIVER:
		var label="ExplainVSSeeker" if owns() else "UrgeToBattleSomeoneAgain"
		var text=str(book.texts.get("VermilionCity_PokemonCenter_1F_Text_"+label,"Use the Vs. Seeker outside to invite nearby trainers to another battle."))
		if not owns():
			a.field.finish("field:vsseeker"); state(); a.save()
			text+="\n\nReceived the VS. SEEKER! Walk 100 steps to charge it. Use it from BAG / KEY ITEMS."
		a.show_dialogue(text); return true
	var script=str(object.get("script",""))
	if ready(script):
		a.begin_battle("seeker_"+script,[],[]); return true
	return false

func step():
	if not owns(): return
	var s=state(); s.charge=mini(100,int(s.charge)+1)
	if int(s.remaining)>0:
		s.remaining-=1
		if s.remaining==0: s.ready.clear(); s.map=""

func entered():
	if not a.data.has("vs_seeker"): return
	var s=state()
	if s.map!=a.world.current: s.ready.clear(); s.remaining=0; s.map=""

func ready(script: String) -> bool:
	if not owns() or not a.data.has("vs_seeker") or not a.field.outdoor(): return false
	var s=state(); var base=str(a.trainers.book.scripts.get(script,""))
	return s.map==a.world.current and s.remaining>0 and s.ready.has(base)

func available_stage(index: int) -> bool:
	match index:
		1: return owns()
		2: return a.field.done("visited:MAP_CELADON_CITY")
		3: return a.field.done("visited:MAP_FUCHSIA_CITY")
		4: return a.Finale.has(a,"champion")
		5: return a.sevii.done("network")
	return true

func target(base: String) -> String:
	if not book.rematches.has(base): return ""
	var chain=book.rematches[base].parties; var next=chain.size()-1
	for i in range(1,chain.size()):
		if chain[i]!="" and chain[i]!=base and not state().defeated.has(chain[i]): next=i; break
	# Apply progression gates to the candidate and walk back over source SKIP slots.
	while next>0 and (chain[next]=="" or not available_stage(next)): next-=1
	return str(chain[next])

func resolve(script: String) -> String:
	if not ready(script): return ""
	return target(str(a.trainers.book.scripts.get(script,"")))

func nearby() -> Array:
	if not a.field.outdoor(): return []
	var result=[]
	for npc in a.world.actors():
		if not npc.has("battle"): continue
		var delta=(Vector2(npc.pos)-a.position_world)/a.world.TILE
		if absf(delta.x)>7 or absf(delta.y)>5: continue
		var base=str(a.trainers.book.scripts.get(str(npc.script),""))
		if book.rematches.has(base) and book.rematches[base].map==a.world.current: result.append(npc)
	return result

func activate():
	if a.in_battle or not owns(): return
	a.clear_ui()
	if not a.field.outdoor(): a.dialog="The VS. SEEKER cannot be used here."; return
	var s=state()
	if int(s.charge)<100: a.dialog="VS. SEEKER needs "+str(100-int(s.charge))+" more walking steps."; return
	var trainers=nearby()
	if trainers.is_empty(): a.dialog="There are no trainers in range."; return
	s.charge=0; s.remaining=0; s.map=a.world.current; s.ready.clear()
	var responses={}; var names=[]
	for npc in trainers:
		var base=str(a.trainers.book.scripts[npc.script])
		if not a.field.done("trainer:"+str(npc.script)): continue
		if not responses.has(base): responses[base]=random.randi_range(0,99)>=30
		if responses[base]:
			s.ready[base]=true
			var name=str(a.trainers.book.trainers[base].name)
			if name not in names: names.append(name)
	if not s.ready.is_empty(): s.remaining=100
	a.dialog="VS. SEEKER: "+(", ".join(names)+" want to battle! Talk to them within 100 steps, before leaving this area." if not names.is_empty() else "No one accepted a rematch this time. Walk 100 steps to recharge.")
	a.save()

func started(script: String):
	var base=str(a.trainers.book.scripts.get(script,""))
	state().ready.erase(base)

func result(victory: bool):
	if not str(a.encounter.get("kind","")).begins_with("seeker_"): return
	if victory: state().defeated[a.encounter.trainer_id]=true
