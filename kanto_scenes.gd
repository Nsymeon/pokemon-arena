extends RefCounted
var reference: WeakRef
var w:
	get: return reference.get_ref()
var a
var active=false
var sequence=[]
var elapsed=0.0
var index=0
var completion=Callable()
var once_key=""
var positions={}
var subtitle=""
var actor={}
var encounters: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/encounters.json"))
var random=RandomNumberGenerator.new()

func install(world):
	reference=weakref(world); a=world.a; random.randomize()

func reset():
	active=false; sequence.clear(); positions.clear(); actor={}; subtitle=""; completion=Callable(); once_key=""

func play(steps: Array, after: Callable=Callable(), key: String=""):
	if active: return
	if key!="" and w.events.done(key): return
	active=true; sequence=steps; index=0; elapsed=0; completion=after; once_key=key
	a.dialog=""; a.c.click_move=false; w.stepping=false

func tick(dt: float) -> bool:
	if not active: return false
	if sequence.is_empty(): finish(); return true
	var step=sequence[index]
	elapsed+=dt
	subtitle=str(step.get("text",""))
	if step.has("actor"):
		actor=step.actor
		var ratio=clampf(elapsed/float(step.get("duration",2.0)),0,1)
		positions[str(actor.key)]=Vector2(actor.from).lerp(Vector2(actor.to),ratio)
	if elapsed>=float(step.get("duration",2.0)):
		index+=1; elapsed=0
		if index>=sequence.size(): finish()
	return true

func finish():
	var after=completion
	var key=once_key
	active=false; subtitle=""; sequence.clear(); actor={}; completion=Callable(); once_key=""
	if key!="": w.events.finish(key); a.save()
	if after.is_valid(): after.call()

func entrance():
	if w.current=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB" and a.data.starter==0:
		play([{"text":"OAK: Welcome to my laboratory. A Pokemon partner will keep you safe on your journey.","duration":3.2},{"text":"OAK: Choose Bulbasaur, Charmander or Squirtle.","duration":2.2}],a.starter_menu)
	elif w.current=="MAP_POKEMON_LEAGUE_HALL_OF_FAME" and a.Finale.has(a,"champion"):
		play([{"text":"OAK: You and your Pokemon have earned your place here.","duration":3.0},{"text":"HALL OF FAME — Your winning team is recorded. Congratulations, Champion!","duration":3.5}],Callable(),"scene:hall_of_fame")

func oak_rescue():
	var target=w.walkable(a.position_world+Vector2.DOWN*w.TILE)
	var origin=w.walkable(target+Vector2.DOWN*w.TILE*2)
	play([{"text":"OAK: Wait! Wild Pokemon live beyond the town!","duration":1.7},{"actor":{"key":"scene_oak","gfx":"prof_oak","from":origin,"to":target},"text":"OAK: Come with me. You need a Pokemon of your own.","duration":2.2}],func():w.enter("MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB",Vector2(6.5,9.5)*w.TILE))

func quest(id: String) -> bool:
	if id=="story_console" and a.Story.state(a).get("bill_help",false) and not a.Story.state(a).get("ticket",false):
		var bill=a.position_world
		for npc in w.quest_actors():
			if npc[2]=="story_bill": bill=npc[0]
		var capsule=w.walkable(bill+Vector2.UP*w.TILE)
		play([{"actor":{"key":"quest:story_bill","gfx":"bill","from":bill,"to":capsule},"text":"BILL: The transporter is ready. Start the separation system!","duration":2.1},{"text":"The capsules light up. The machine hums, then a flash fills the cottage...","duration":2.5,"flash":true},{"text":"BILL: I'm human again! Take this S.S. Ticket as my thanks.","duration":2.5}],func():a.Story.interact(a,id); a.dialog="", "scene:bill")
		return true
	if id=="story_captain" and a.Story.state(a).get("ship_blue",false) and not a.Story.state(a).get("cut",false):
		play([{"text":"CAPTAIN: Oh... the sea has left me feeling terrible.","duration":2.0},{"text":"You help the Captain recover. He shows you the Cut technique.","duration":2.8},{"text":"CAPTAIN: Use Cut to clear the small trees blocking your path.","duration":2.5}],func():a.Story.interact(a,id); a.dialog="", "scene:captain")
		return true
	if id in ["late_task_flute","late_task_silph_saved"]:
		var key=id.trim_prefix("late_task_")
		var task=a.Finale.TASKS[key]
		if not a.Finale.has(a,key) and a.Finale.missing(a,task.need)=="":
			var text="MR. FUJI: Thank you for rescuing me. This Poke Flute can wake sleeping Pokemon." if key=="flute" else "PRESIDENT: Team Rocket has fled. Silph Co. is safe thanks to you!"
			play([{"text":text,"duration":3.6}],func():a.Finale.start_task(a,key); a.dialog="", "scene:"+key)
			return true
	return false

func trainer_direction(npc) -> Vector2:
	var type=str(npc.get("movement_type",""))
	if "LEFT" in type: return Vector2.LEFT
	if "RIGHT" in type: return Vector2.RIGHT
	if "UP" in type: return Vector2.UP
	return Vector2.DOWN

func sees(npc) -> bool:
	if not npc.has("battle") or str(npc.get("trainer_type",""))!="TRAINER_TYPE_NORMAL": return false
	if w.events.done("trainer:"+str(npc.script)): return false
	var direction=trainer_direction(npc)
	var delta=a.position_world-Vector2(npc.pos)
	var forward=delta.dot(direction)
	var sideways=absf(delta.cross(direction))
	var reach=int(str(npc.get("trainer_sight_or_berry_tree_id","0")))
	if forward<w.TILE*0.8 or forward>reach*w.TILE+1 or sideways>w.TILE*0.2: return false
	var steps=roundi(forward/w.TILE)
	for i in range(1,steps):
		var p=Vector2(npc.pos)+direction*w.TILE*i
		if w.blocked(p): return false
		for other in w.actors():
			if str(other.get("script",""))!=str(npc.script) and Vector2(other.pos).distance_to(p)<w.TILE*0.5: return false
	return true

func detect_trainer() -> bool:
	if a.data.party.is_empty() or not a.data.party.any(func(mon):return mon.hp>0): return false
	for npc in w.actors():
		if not sees(npc): continue
		var target=a.position_world-trainer_direction(npc)*w.TILE
		var identity=str(npc.graphics_id).trim_prefix("OBJ_EVENT_GFX_").to_lower()
		var moving={"key":str(npc.script),"gfx":identity,"from":Vector2(npc.pos),"to":target}
		play([{"actor":{"key":str(npc.script),"gfx":identity,"from":npc.pos,"to":npc.pos},"text":"!","duration":0.65},{"actor":moving,"text":str(npc.battle.name)+" spotted you!","duration":maxf(0.3,Vector2(npc.pos).distance_to(target)/170.0)},{"text":str(npc.battle.name)+": Let's battle!","duration":1.2}],func():a.begin_battle("world_"+str(npc.script),npc.battle.party.map(func(m):return int(m[0])),npc.battle.party.map(func(m):return int(m[1]))))
		return true
	return false

func habitat() -> String:
	var x=floori(a.position_world.x/w.TILE); var y=floori(a.position_world.y/w.TILE)
	if x<0 or y<0 or x>=w.room().width or y>=w.room().height: return ""
	var behavior=int(w.events.catalog[w.current].behavior[y*int(w.room().width)+x])
	if behavior in [0x10,0x11,0x12,0x15,0x50,0x51,0x52,0x53]: return "water_mons"
	if behavior in [2,3,0x0B]: return "land_mons"
	if w.room().type=="MAP_TYPE_UNDERGROUND" and behavior in [0,8]: return "land_mons"
	return ""

func pool() -> Array:
	return encounters.get(w.current,{}).get(habitat(),[])

func roll(slots: Array) -> Dictionary:
	var total=0
	for slot in slots: total+=int(slot.weight)
	if total<=0: return {}
	var choice=random.randi_range(1,total)
	for slot in slots:
		choice-=int(slot.weight)
		if choice<=0: return {"id":int(slot.id),"level":random.randi_range(int(slot.min),int(slot.max))}
	return {}

func seek_wild() -> bool:
	var slots=pool()
	if slots.is_empty(): return false
	var mon=roll(slots)
	a.begin_battle("wild",[mon.id],[mon.level])
	return true

func draw():
	if not active: return
	if actor.get("key","")=="scene_oak":
		a.draw_set_transform(Vector2(0,90)-a.camera)
		w.person(positions.scene_oak,"prof_oak")
		a.draw_set_transform(Vector2.ZERO)
	if index<sequence.size() and sequence[index].get("flash",false): a.draw_rect(Rect2(0,90,1280,700),Color(0.75,0.9,1.0,0.4*maxf(0.0,1.0-absf(elapsed-1.2)*2)))
	a.draw_rect(Rect2(0,90,1280,38),Color(0.02,0.04,0.06,0.95))
	a.draw_rect(Rect2(40,640,1200,140),Color(0.02,0.04,0.06,0.96))
	a.draw_multiline_string(a.font,Vector2(65,681),a.wrapped(subtitle),HORIZONTAL_ALIGNMENT_LEFT,1140,22,3,Color("f1ecd9"))
	a.words("SCENE / Enter or "+a.c.controls.text("interact")+": next / Esc: skip",Vector2(65,762),13,Color("a8b9bd"))
	if subtitle=="!" and not actor.is_empty():
		var p=Vector2(positions.get(str(actor.key),a.position_world))-a.camera+Vector2(0,90)
		a.draw_circle(p+Vector2(24,-78),19,Color("fff1be"))
		a.words("!",p+Vector2(18,-66),32,Color("382a23"))


func tests():
	var before=a.data.duplicate(true)
	var old_current=w.current
	var old_position=a.position_world
	var old_dialog=a.dialog
	var old_allowed=a.save_allowed
	var old_latch=w.warp_latch
	a.save_allowed=false
	reset()
	w.current="MAP_ROUTE1"; w.events.refresh()
	var terrain=w.events.catalog[w.current].behavior
	var grass=-1; var road=-1
	for i in range(terrain.size()):
		if int(terrain[i])==2: grass=i
		if int(terrain[i])==0: road=i
	a.position_world=Vector2(grass%int(w.room().width)+0.5,int(grass/int(w.room().width))+0.5)*w.TILE
	a.c.check(habitat()=="land_mons" and not pool().is_empty(),"E encounter uses grass-specific FireRed table")
	for i in range(100):
		var mon=roll(pool())
		a.c.check(mon.id in [16,19] and mon.level>=2 and mon.level<=5,"Route 1 random rolls preserve species and level range")
	a.c.check(not tick(1.0),"Walking or waiting never starts a wild battle")
	a.position_world=Vector2(road%int(w.room().width)+0.5,int(road/int(w.room().width))+0.5)*w.TILE
	a.c.check(pool().is_empty(),"Road tiles cannot trigger grass encounters")
	for map_id in ["MAP_MT_MOON_1F","MAP_ROUTE19"]:
		w.current=map_id; w.events.refresh()
		var wanted=8 if map_id=="MAP_MT_MOON_1F" else 0x15
		var cells=w.events.catalog[map_id].behavior
		var found=-1
		for i in range(cells.size()):
			if int(cells[i])==wanted: found=i; break
		a.c.check(found>=0,"Cave/water encounter habitat exists")
		a.position_world=Vector2(found%int(w.room().width)+0.5,int(found/int(w.room().width))+0.5)*w.TILE
		a.c.check(not pool().is_empty(),"Cave/water E has its own encounter slots")
	w.current="MAP_PALLET_TOWN"; w.events.refresh(); w.warp_latch=""
	var door=w.room().warps.filter(func(d):return d.dest_map=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB")[0]
	a.position_world=w.events.point(door)
	a.c.check(w.try_warp() and w.current=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB","Stepping on a door enters without E")
	a.c.check(a.dialog=="" and not w.try_warp(),"Arrival needs no dismissal and cannot immediately bounce back")
	w.current="MAP_ROUTE1"; w.events.refresh()
	var npc={"script":"scene_regression","battle":{"name":"Tester","party":[[19,3]]},"movement_type":"MOVEMENT_TYPE_FACE_UP","trainer_type":"TRAINER_TYPE_NORMAL","trainer_sight_or_berry_tree_id":"3","pos":Vector2.ZERO}
	var found_line=false
	for y in range(3,int(w.room().height)-2):
		if found_line: break
		for x in range(2,int(w.room().width)-2):
			var p=Vector2(x+0.5,y+0.5)*w.TILE
			if w.blocked(p) or w.blocked(p+Vector2.UP*w.TILE) or w.blocked(p+Vector2.UP*w.TILE*2): continue
			npc.pos=p; a.position_world=p+Vector2.UP*w.TILE*2
			if sees(npc): found_line=true; break
	a.c.check(found_line,"Trainer sees aligned player along an unobstructed path")
	npc.movement_type="MOVEMENT_TYPE_FACE_DOWN"
	a.c.check(not sees(npc),"Trainer does not see behind them")
	npc.movement_type="MOVEMENT_TYPE_FACE_UP"; w.events.finish("trainer:scene_regression")
	a.c.check(not sees(npc),"Defeated trainers do not re-trigger approach")
	var calls=[]
	play([{"text":"First line","duration":0.2},{"text":"Second line","duration":0.2}],func():calls.append(true),"scene:regression")
	tick(0.3); tick(0.3)
	a.c.check(not active and calls.size()==1 and w.events.done("scene:regression"),"Cutscene advances automatically and commits once")
	play([{"text":"Already played"}],func():calls.append(true),"scene:regression")
	a.c.check(not active and calls.size()==1,"Saved one-shot scenes are not replayed")
	reset(); a.data=before; a.save_allowed=old_allowed; w.current=old_current; a.position_world=old_position; a.dialog=old_dialog; w.warp_latch=old_latch
	w.events.refresh(); w.update_camera()
