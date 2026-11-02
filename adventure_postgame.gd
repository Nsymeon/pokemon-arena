extends RefCounted
# Persistent, one-per-save roaming Pokemon and source event-island puzzles.
var a
var book: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/postgame.json"))
var teams: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/league-parties.json"))
var pending=false
var flee_clock=0.0
const TRIANGLE="BirthIsland_Exterior_EventScript_Triangle"
const ISLANDS=["MAP_NAVEL_ROCK_HARBOR","MAP_BIRTH_ISLAND_HARBOR"]
const TICKETS=["mysticticket","auroraticket"]

func state() -> Dictionary:
	if not a.data.has("legendary_events"): a.data.legendary_events={"triangle":0,"steps":0,"roamer":{}}
	return a.data.legendary_events

func valid(data) -> bool:
	if not data.has("legendary_events"): return true
	var s=data.legendary_events
	if not s is Dictionary or not s.get("roamer") is Dictionary: return false
	for key in ["triangle","steps"]:
		if not (s.get(key) is int or s.get(key) is float) or s[key]!=int(s[key]) or s[key]<0 or s[key]>(10 if key=="triangle" else 10000): return false
	if s.roamer.is_empty(): return true
	var r=s.roamer
	if not r.get("mon") is Dictionary or not r.get("ended") is bool or not r.get("seen") is bool or not book.routes.has(r.get("map","")): return false
	var mon=r.mon
	return int(mon.get("id",0)) in [243,244,245] and int(mon.get("level",0))==50 and mon.get("hp",-1)>=0 and mon.hp<=1 and a.c.ivs.valid(mon.get("ivs",{})) and mon.get("ailment","") in ["","sleep","freeze","burn","poison","toxic","paralysis"]

func activate():
	if not a.sevii.done("network") or not state().roamer.is_empty(): return
	var species={1:244,4:245,7:243}.get(int(a.data.starter),244)
	state().roamer={"mon":a.new_mon(species,50),"map":book.routes.keys()[a.c.ivs.random.randi_range(0,book.routes.size()-1)],"ended":false,"seen":false}

func move_roamer(far=false):
	activate()
	var r=state().roamer
	if r.is_empty() or r.ended: return
	var options=book.routes[r.map].duplicate()
	if far or a.c.ivs.random.randi_range(0,15)==0: options=book.routes.keys().filter(func(id):return id!=r.map)
	var history=a.data.get("roamer_history",[])
	if history.size()>=3: options=options.filter(func(id):return id!=history[0])
	if options.is_empty(): options=book.routes.keys().filter(func(id):return id!=r.map)
	r.map=options[a.c.ivs.random.randi_range(0,options.size()-1)]

func entered(previous):
	if previous!=a.world.current:
		move_roamer()
		var history=a.data.get("roamer_history",[]); history.append(previous)
		while history.size()>3: history.pop_front()
		a.data.roamer_history=history
		if a.world.current=="MAP_BIRTH_ISLAND_EXTERIOR": state().triangle=0; state().steps=0

func step():
	if int(a.services.state().steps)%128==0:
		for mon in a.data.party: mon.friendship=mini(255,int(mon.get("friendship",70))+1)
	if a.world.current=="MAP_BIRTH_ISLAND_EXTERIOR": state().steps=mini(10000,int(state().steps)+1)
	# Ho-Oh descends at the original approach trigger.
	if a.world.current=="MAP_NAVEL_ROCK_SUMMIT" and not a.field.done("static:HoOh"):
		var tile=Vector2i(a.position_world/48)
		if tile==Vector2i(9,12): legendary(250,"HoOh")

func try_roamer() -> bool:
	activate()
	var r=state().roamer
	if r.is_empty() or r.ended or r.map!=a.world.current or a.world.scenes.habitat() not in ["land_mons","water_mons"]: return false
	if a.c.ivs.random.randi_range(0,3)!=0: return false
	a.begin_battle("wild",[int(r.mon.id)],[50])
	if not a.in_battle: return false
	pending=true; flee_clock=0; r.seen=true
	var data=a.battle_mon(int(r.mon.id),50,r.mon)
	a.c.enemy.data=data; a.c.enemy.hp=data.hp*float(r.mon.hp)
	a.c.enemy.ailment=r.mon.ailment; a.c.enemy.ailment_time=3.0
	a.c.enemy_party[0]=data
	a.c.notice="A roaming "+a.mon_name(r.mon.id)+"! It may flee; its wounds persist."; a.c.notice_time=5
	return true

func tick(dt):
	if not pending or not a.in_battle or a.c.paused or a.c.countdown>0 or a.capture_time>0 or a.c.result!="" or a.c.switch_menu or a.c.switch_time>=0: return
	flee_clock+=dt
	if flee_clock<12 or a.c.enemy.hp<=0 or a.c.player.hp<=0: return
	if a.c.abilities.trapped(a.c.enemy,a.c.player) or a.c.enemy.ailment in ["sleep","freeze"] or a.c.enemy.get("volatile",{}).get("partiallytrapped",0)>0: return
	if a.c.enemy.get("action_lock",0)>0 or a.c.enemy.get("charge_left",0)>0: return
	a.return_world(false,true,true)
	a.dialog="The roaming Pokemon fled! Its HP and status are saved for your next meeting."

func result(caught,won):
	if not pending: return
	var r=state().roamer
	r.mon.hp=clampf(a.c.enemy.hp/a.c.enemy.data.hp,0,1); r.mon.ailment=a.c.enemy.ailment
	r.ended=bool(caught or won or a.c.enemy.hp<=0)
	pending=false
	move_roamer(true)

func tickets_ready() -> bool:
	return a.progression.national() and a.sevii.done("network")

func claim_tickets():
	if not tickets_ready(): return
	for ticket in TICKETS: a.field.finish("event:"+ticket)
	a.clear_ui()
	a.world.scenes.play([{"text":"MYSTERY GIFT: Received the MYSTIC TICKET and AURORA TICKET!","duration":2.5,"flash":true},{"text":"Show them to the Seagallop sailor for Navel Rock and Birth Island. These tickets once came from special distributions.","duration":3.5}],func():a.save())

func can_sail(index) -> bool:
	return index>=0 and index<2 and a.field.done("event:"+TICKETS[index]) and tickets_ready()

func ferry_rows(list):
	a.inventory.row(list,"MYSTERY GIFT / event tickets" if tickets_ready() else "Event tickets / finish Celio's Network Machine first",claim_tickets,not tickets_ready() or a.field.done("event:auroraticket"))
	for i in 2: a.inventory.row(list,("NAVEL ROCK / Mystic Ticket" if i==0 else "BIRTH ISLAND / Aurora Ticket"),sail.bind(i),not can_sail(i))

func sail(index):
	if a.in_battle or not a.sevii.at_port() or not can_sail(index): return
	a.clear_ui()
	a.world.scenes.play([{"text":"The Seagallop sails toward "+("Navel Rock" if index==0 else "Birth Island")+"...","duration":1.8,"flash":true}],func():a.world.enter(ISLANDS[index],Vector2(8.5,5.5)*48))

func hidden(o) -> bool:
	var gfx=str(o.get("graphics_id",""))
	if a.world.current=="MAP_BIRTH_ISLAND_EXTERIOR":
		if gfx=="OBJ_EVENT_GFX_VAR_0": return true
		if o.get("script","")==TRIANGLE: return a.field.done("static:Deoxys")
	if gfx=="OBJ_EVENT_GFX_HO_OH": return a.field.done("static:HoOh")
	if gfx=="OBJ_EVENT_GFX_LUGIA": return a.field.done("static:Lugia")
	return false

func position(o,original: Vector2) -> Vector2:
	if o.get("script","")==TRIANGLE:
		var xy=book.triangle[int(state().triangle)]
		return (Vector2(xy[0],xy[1])+Vector2(.5,.5))*48
	return original

func npc(o) -> bool:
	var script=str(o.get("script","")); var gfx=str(o.get("graphics_id",""))
	if script==TRIANGLE: triangle(); return true
	if gfx=="OBJ_EVENT_GFX_HO_OH": legendary(250,"HoOh"); return true
	if gfx=="OBJ_EVENT_GFX_LUGIA": legendary(249,"Lugia"); return true
	return false

func triangle():
	if not can_sail(1) or a.field.done("static:Deoxys"): return
	var s=state(); var count=int(s.triangle)
	if count>0 and s.steps>book.caps[count-1]:
		s.triangle=0; a.dialog="The triangle cooled and returned to its starting point. Take the shortest path!"
	elif count==10:
		legendary(386,"Deoxys")
	else:
		s.triangle=count+1; a.dialog="The triangle shifted and grew warmer..."
	s.steps=0; a.save()

func legendary(species,key):
	if a.in_battle or a.world.scenes.active or a.field.done("static:"+key) or not can_sail(1 if species==386 else 0): return
	a.world.scenes.play([{"text":"The meteorite shatters. Deoxys descends from the sky!" if species==386 else "Ho-Oh descends in a shower of golden light!" if species==250 else "Lugia rises from the depths of Navel Rock!","duration":2.4,"portrait":species,"flash":true}],func():
		a.begin_battle("wild",[species],[30 if species==386 else 70])
		if a.in_battle: a.field.pending_static="static:"+key)

func league_team(stage: int) -> Array:
	var rematch=a.sevii.done("network") and a.Finale.has(a,"champion")
	var key="ELITE_FOUR_"+["LORELEI","BRUNO","AGATHA","LANCE"][stage]+("_2" if rematch else "") if stage<4 else "CHAMPION_"+("REMATCH_" if rematch else "FIRST_")+{1:"CHARMANDER",4:"SQUIRTLE",7:"BULBASAUR"}.get(int(a.data.starter),"SQUIRTLE")
	return teams.get(key,[])

func journal():
	activate()
	var list=a.inventory.page("POSTGAME / LEGENDARY RESEARCH",a.sevii.journal)
	var r=state().roamer
	if r.is_empty(): a.inventory.row(list,"Complete Celio's Network Machine to awaken a roaming legendary.",func():pass,true)
	elif r.ended: a.inventory.row(list,"Roaming legendary: caught or defeated.",func():pass,true)
	elif r.seen: a.inventory.row(list,a.mon_name(r.mon.id)+" / LAST SIGNAL: "+a.world.maps[r.map].name+" / Lv.50 / HP "+str(roundi(r.mon.hp*100))+"%",func():pass,true)
	else: a.inventory.row(list,"A mysterious Pokemon is roaming Kanto's routes. Search grass or water with "+a.c.controls.text("encounter")+".",func():pass,true)
	for text in ["Navel Rock: climb to Ho-Oh; descend to Lugia. Both Lv.70.","Birth Island: approach each triangle by the shortest path. Deoxys is Lv.30.","Tanoby Ruins: solve the seven-boulder Tanoby Key puzzle to awaken Unown.","After the Network Machine, the League uses its stronger FireRed rematch teams."]:
		a.inventory.row(list,text,func():pass,true)
