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
var dialogue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/npc-dialogue.json"))

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
		if not actor.is_empty(): actor["walking"]=false
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
	elif w.current=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB" and not a.data.rival:
		starter_battle()
	elif w.current=="MAP_POKEMON_LEAGUE_HALL_OF_FAME" and a.Finale.has(a,"champion"):
		play([{"text":"OAK: You and your Pokemon have earned your place here.","duration":3.0},{"text":"HALL OF FAME — Your winning team is recorded. Congratulations, Champion!","duration":3.5}],Callable(),"scene:hall_of_fame")

func check_oak_intro() -> bool:
	if w.current=="MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB" and not a.data.rival:
		entrance()
		return active
	if a.data.starter!=0 or w.current!="MAP_PALLET_TOWN" or a.position_world.y>w.TILE: return false
	oak_rescue()
	return true

func oak_rescue():
	var target=w.walkable(a.position_world+Vector2.DOWN*w.TILE)
	var origin=w.walkable(target+Vector2.DOWN*w.TILE*2)
	play([{"text":"OAK: Wait! Wild Pokemon live beyond the town!","duration":1.7},{"actor":{"key":"scene_oak","gfx":"prof_oak","from":origin,"to":target},"text":"OAK: Come with me. You need a Pokemon of your own.","duration":2.2}],func():w.enter("MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB",Vector2(6.5,9.5)*w.TILE))

func starter_battle():
	if a.data.starter==0 or a.data.rival or a.in_battle: return
	var rival_id=7 if a.data.starter==4 else 4 if a.data.starter==1 else 1
	play([{"text":"BLUE: I'll take "+a.mon_name(rival_id)+"!","duration":2.0},{"text":"BLUE: Wait! Let's check out our Pokemon! Come on, I'll take you on!","duration":2.5}],func():a.begin_battle("rival",[rival_id],[5]))

func quest(id: String) -> bool:
	if id=="late_task_tower_ghost": return a.field.ghost()
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
	var key=str(npc.get("script",""))
	if active and str(actor.get("key",""))==key and actor.has("look"): return actor.look
	var type=str(npc.get("movement_type",""))
	var choices=[]
	for pair in [["DOWN",Vector2.DOWN],["LEFT",Vector2.LEFT],["UP",Vector2.UP],["RIGHT",Vector2.RIGHT]]:
		if pair[0] in type: choices.append(pair[1])
	if "AROUND" in type or "ROTATE" in type: choices=[Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.RIGHT]
	if choices.is_empty(): return Vector2.DOWN
	if choices.size()==1: return choices[0]
	var seed_value=absi(hash(key))
	var interval=1.8+float(seed_value%9)*0.1
	var phase=int(floor(a.time/interval))+seed_value%choices.size()
	if "COUNTERCLOCKWISE" in type: phase=-phase
	return choices[posmod(phase,choices.size())]

func dialogue_flag(flag):
	match flag:
		"FLAG_SYS_GAME_CLEAR": return a.Finale.has(a,"champion")
		"FLAG_SYS_POKEDEX_GET": return w.events.done("parcel_delivered")
		"FLAG_BADGE01_GET": return a.data.badge
		"FLAG_BADGE02_GET": return a.data.get("cascade",false)
		"FLAG_BADGE03_GET": return a.Story.state(a).get("thunder",false)
		"FLAG_BADGE04_GET": return a.Finale.has(a,"rainbow")
		"FLAG_BADGE05_GET": return a.Finale.has(a,"soul")
		"FLAG_BADGE06_GET": return a.Finale.has(a,"marsh")
		"FLAG_BADGE07_GET": return a.Finale.has(a,"volcano")
		"FLAG_BADGE08_GET": return a.Finale.has(a,"earth")
	return null

func npc_text(npc, kind="text") -> String:
	return resolve_dialogue(str(npc.get("script","")),kind,[])

func resolve_dialogue(key: String, kind: String, visited: Array) -> String:
	if key in visited or visited.size()>=20: return ""
	visited=visited.duplicate(); visited.append(key)
	var record=dialogue.get(key,{})
	if kind=="text":
		for branch in record.get("branches",[]):
			var args=branch.args
			if branch.op in ["goto_if_set","goto_if_unset"]:
				var flag=dialogue_flag(str(args[0]))
				if flag!=null and bool(flag)==(branch.op=="goto_if_set"):
					var found=resolve_dialogue(str(args[-1]),kind,visited)
					if found!="": return found
	return str(record.get(kind,record.get("text","")))

func start_trainer(npc):
	# Snapshot both endpoints: actor positions change while the approach animates.
	var copy=npc.duplicate(true)
	var direction=(a.position_world-Vector2(copy.pos)).normalized()
	var target=a.position_world-direction*w.TILE
	var identity=str(copy.graphics_id).trim_prefix("OBJ_EVENT_GFX_").to_lower()
	var key=str(copy.script)
	var moving={"key":key,"gfx":identity,"from":Vector2(copy.pos),"to":target,"look":direction,"walking":true}
	var intro=npc_text(copy,"intro")
	if intro=="": intro=str(copy.battle.name)+": Let's battle!"
	play([{"actor":{"key":key,"gfx":identity,"from":copy.pos,"to":copy.pos,"look":direction},"text":"!","duration":0.65},{"actor":moving,"text":"","duration":maxf(0.3,Vector2(copy.pos).distance_to(target)/110.0)},{"text":intro,"duration":maxf(2.0,float(intro.length())/35.0)}],func():a.begin_battle("world_"+key,copy.battle.party.map(func(m):return int(m[0])),copy.battle.party.map(func(m):return int(m[1]))))

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
		start_trainer(npc)
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

func horde_eligible() -> bool:
	if int(a.data.get("repel_steps",0))<=0 or w.room().type=="MAP_TYPE_UNDERGROUND" or w.current.begins_with("MAP_SAFARI_ZONE"): return false
	var tile=Vector2i(a.position_world/w.TILE)
	var behavior=int(w.events.catalog[w.current].behavior[tile.y*int(w.room().width)+tile.x])
	return behavior in [2,3,0x0B] and habitat()=="land_mons"

func seek_wild() -> bool:
	var slots=pool()
	if slots.is_empty(): return false
	var mon=roll(slots)
	if w.current.begins_with("MAP_SAFARI_ZONE"):
		a.services.safari_encounter(mon); return true
	var leader=a.data.party.filter(func(member):return member.hp>0)
	if not leader.is_empty():
		if leader[0].get("held_item","")=="cleansetag" and random.randf()<1.0/3.0:
			a.dialog="Cleanse Tag kept a wild Pokemon away."; return true
	var ids=[mon.id]; var levels=[mon.level]
	if horde_eligible() and random.randf()<0.2:
		for i in range(4):
			var extra=roll(slots); ids.append(extra.id); levels.append(extra.level)
	a.begin_battle("wild",ids,levels)
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
	if index<sequence.size():
		var step=sequence[index]
		if step.has("portrait"):
			a.draw_circle(Vector2(640,390),115,Color(0.8,0.95,1,0.15))
			a.draw_texture_rect(a.c.portraits[int(step.portrait)],Rect2(540,290,200,200),false)
		if step.get("effect","")=="smash":
			var center=Vector2(step.point)-a.camera+Vector2(0,90)
			for i in range(10):
				var velocity=Vector2.from_angle(i*TAU/10)*90+Vector2(0,-70)
				a.draw_circle(center+velocity*elapsed+Vector2(0,150*elapsed*elapsed),4,Color("ceb18b"))
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
	w.current="MAP_PALLET_TOWN"; w.events.refresh()
	a.data.starter=0; a.position_world=Vector2(12.5,0.5)*w.TILE
	a.c.check(check_oak_intro() and active,"Oak intercepts northern approach before mouse movement hits map boundary")
	reset(); a.data.starter=4
	a.c.check(not check_oak_intro(),"Oak does not stop a trainer who already has a starter")
	var old_battle=a.in_battle; a.in_battle=false; a.data.rival=false
	for pair in [[1,4],[4,7],[7,1]]:
		a.data.starter=pair[0]; starter_battle()
		a.c.check(active and str(sequence[0].text).contains(a.mon_name(pair[1])) and completion.is_valid(),"Starter introduction gives Blue the counter starter")
		reset()
	a.data.rival=true; starter_battle()
	a.c.check(not active,"Completed first rival battle does not replay")
	a.in_battle=old_battle; a.data=before.duplicate(true)

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
	var old_time=a.time
	var turning={"script":"look_test","movement_type":"MOVEMENT_TYPE_FACE_LEFT_AND_RIGHT"}
	var looks=[]
	for second in range(12):
		a.time=float(second)
		var look=trainer_direction(turning)
		a.c.check(look in [Vector2.LEFT,Vector2.RIGHT],"Side-looking trainer uses only original allowed directions")
		if look not in looks: looks.append(look)
	a.c.check(looks.size()==2,"Side-looking trainer scans both directions over time")
	a.time=old_time
	npc.graphics_id="OBJ_EVENT_GFX_BOY"; npc.script="approach_test"
	start_trainer(npc)
	var arrived=[]; completion=func(): arrived.append(true)
	tick(0.7)
	a.c.check(index==1 and active,"Exclamation progresses automatically to approach")
	tick(0.2)
	a.c.check(positions.approach_test.distance_to(npc.pos)>0,"Trainer actually moves toward the player")
	tick(2.0); tick(10.0)
	a.c.check(not active and arrived.size()==1,"Trainer approach launches battle callback exactly once")
	a.c.check(Vector2(positions.approach_test).distance_to(a.position_world)>w.TILE*0.9,"Trainer stops adjacent instead of overlapping player")
	reset()
	a.show_dialogue("First original page.\n\nSecond original page.")
	a.c.check(a.dialog=="First original page. " and a.dialog_pages.size()==1,"Original paragraph breaks paginate dialogue")
	a.advance_dialogue()
	a.c.check(a.dialog.contains("Second original page"),"Continue shows the next dialogue page")
	a.dialog="A new conversation."
	a.c.check(a.dialog_pages.is_empty(),"Replacing a conversation clears old pages")
	var calls=[]
	play([{"text":"First line","duration":0.2},{"text":"Second line","duration":0.2}],func():calls.append(true),"scene:regression")
	tick(0.3); tick(0.3)
	a.c.check(not active and calls.size()==1 and w.events.done("scene:regression"),"Cutscene advances automatically and commits once")
	play([{"text":"Already played"}],func():calls.append(true),"scene:regression")
	a.c.check(not active and calls.size()==1,"Saved one-shot scenes are not replayed")
	reset(); a.data=before; a.save_allowed=old_allowed; w.current=old_current; a.position_world=old_position; a.dialog=old_dialog; w.warp_latch=old_latch
	w.events.refresh(); w.update_camera()
