extends RefCounted
var a
const PORTS=["MAP_VERMILION_CITY","MAP_ONE_ISLAND","MAP_TWO_ISLAND","MAP_THREE_ISLAND","MAP_FOUR_ISLAND","MAP_FIVE_ISLAND","MAP_SIX_ISLAND","MAP_SEVEN_ISLAND"]
var tutors: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/tutors.json"))
var dialogue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/dialogue.json"))

func gate(destination) -> bool:
	if destination.begins_with("MAP_MT_EMBER_RUBY_PATH") and not done("network_quest"):
		a.dialog="Speak to Celio after becoming Champion to investigate the Ruby cave."; return false
	if destination=="MAP_SIX_ISLAND_DOTTED_HOLE_1F" and not a.field.can_use("cut"):
		a.dialog="The Braille door requires Cut Shears and the Cascade Badge."; return false
	if destination=="MAP_FIVE_ISLAND_ROCKET_WAREHOUSE" and not done("sapphire_stolen"):
		a.dialog="The Warehouse is locked. Follow the Sapphire quest at Dotted Hole."; return false
	return true

func on_step() -> bool:
	var w=a.world
	var cell=Vector2i(a.position_world/48)
	var behavior=int(w.events.catalog[w.current].behavior[cell.y*int(w.room().width)+cell.x])
	if w.current=="MAP_FOUR_ISLAND_ICEFALL_CAVE_1F" and behavior in [0x26,0x27]:
		var key="ice:"+str(cell.x)+":"+str(cell.y)
		if done(key):
			var at=a.position_world
			w.scenes.play([{"text":"The cracked ice gives way!","duration":0.7,"flash":true}],func():w.enter("MAP_FOUR_ISLAND_ICEFALL_CAVE_B1F",at))
		else: finish(key); a.dialog="The ice cracked under your feet."
		return true
	return false

func waterfall(direction) -> bool:
	if direction not in [Vector2.UP,Vector2.DOWN]: return false
	var w=a.world; var target=a.position_world+direction*48
	var cell=Vector2i(target/48)
	if cell.x<0 or cell.y<0 or cell.x>=w.room().width or cell.y>=w.room().height: return false
	if int(w.events.catalog[w.current].behavior[cell.y*int(w.room().width)+cell.x])!=0x13: return false
	if not a.field.can_use("waterfall") or not a.field.can_use("surf"):
		a.dialog="Waterfall requires the Waterfall Climber, Volcano Badge and a partner using Surf."; return true
	for i in range(int(w.room().height)):
		cell=Vector2i(target/48)
		if cell.y<0 or cell.y>=w.room().height: return true
		if int(w.events.catalog[w.current].behavior[cell.y*int(w.room().width)+cell.x])!=0x13:
			if not w.blocked(target):
				var landing=target
				w.scenes.play([{"text":"The Waterfall Climber pulls you through the rushing water!","duration":1.2,"flash":true}],func():a.position_world=landing; a.save())
			return true
		target+=direction*48
	return true

func done(key): return a.field.done("sevii:"+key)
func finish(key): a.field.finish("sevii:"+key)

func ferry_menu():
	var list=a.inventory.page("SEAGALLOP FERRY / SEVII ISLANDS")
	if not a.Finale.has(a,"volcano"):
		a.inventory.row(list,"Earn the Volcano Badge before travelling with Bill to One Island.",func():pass,true); return
	for i in range(PORTS.size()):
		var locked=i>=4 and not done("ruby_delivered")
		a.inventory.row(list,a.world.maps[PORTS[i]].name+(" / Celio needs the Ruby first" if locked else ""),sail.bind(i),locked)

func at_port() -> bool:
	return a.world.current in PORTS or a.world.current.ends_with("_HARBOR")

func sail(index):
	if a.in_battle or not at_port() or index<0 or index>=PORTS.size() or not a.Finale.has(a,"volcano"): return
	if index>=4 and not done("ruby_delivered"): return
	a.clear_ui()
	a.world.scenes.play([{"text":"The Seagallop sets sail for "+a.world.maps[PORTS[index]].name+"...","duration":1.6,"flash":true}],func():a.world.enter(PORTS[index],Vector2(10.5,10.5)*48))

func npc(o) -> bool:
	var script=str(o.get("script",""))
	if script=="SaffronCity_CopycatsHouse_2F_EventScript_Copycat" and not a.field.done("tutor:"+script) and int(a.data.bag.get("pokedoll",0))<=0:
		a.dialog="COPYCAT: Bring me a Poke Doll from the Mart and I can teach Mimic to a compatible partner."; return true
	if script in ["ThreeIsland_EventScript_Biker","ThreeIsland_EventScript_AntiBiker1","ThreeIsland_EventScript_AntiBiker2"]:
		bikers(); return true
	if tutors.has(script): tutor_menu(script); return true
	if "Celio" in script:
		if done("sapphire"): a.field.reward("sevii:network","CELIO: The Ruby and Sapphire power the Network Machine! Thank you for reconnecting the islands.")
		elif done("ruby"): a.field.reward("sevii:ruby_delivered","CELIO: The Ruby works! Take the RAINBOW PASS for Islands Four through Seven. Find the Sapphire at Dotted Hole on Six Island.")
		elif a.Finale.has(a,"champion"): a.field.reward("sevii:network_quest","CELIO: As Champion, help restore the Network Machine. Find the Ruby deep under Mt. Ember.")
		else: a.dialog="CELIO: Visit Two Island and help Bill's friend. Return after becoming Champion for the Network Machine quest."
		return true
	if "LostellesDaddy" in script:
		if done("lostelle_saved"): a.field.reward("sevii:lostelle_returned","Lostelle and her father are reunited! Bill thanks you for helping the islands.")
		else: a.field.reward("sevii:lostelle_quest","My daughter Lostelle is missing! Search Berry Forest beyond Three Island's Bond Bridge.")
		return true
	if script=="ThreeIsland_BerryForest_EventScript_Lostelle":
		if not done("bikers"): a.dialog="First drive the biker gang out of Three Island. Speak to the townspeople by the bikes."; return true
		if done("lostelle_saved"): a.dialog="Lostelle is safe. Return to her father on Two Island."; return true
		a.world.scenes.play([{"text":"LOSTELLE: That scary Pokemon keeps following me!","duration":1.6},{"text":"A Hypno steps out from the trees!","duration":1.2,"portrait":97}],func():a.begin_battle("sevii_lostelle",[97],[30])); return true
	if script.ends_with("EventScript_Ruby"):
		if not done("network_quest"): a.dialog="Ask Celio about the Network Machine after becoming Champion."
		else: a.field.reward("sevii:ruby","The Ruby glows in your hands. Bring it to Celio on One Island.")
		return true
	if script.ends_with("EventScript_Sapphire"):
		if not done("ruby_delivered"): a.dialog="Return the Ruby to Celio first."
		else: a.field.reward("sevii:sapphire_stolen","A scientist snatches the Sapphire! He reveals the Rocket Warehouse password. Follow him to Five Island!")
		return true
	if "RocketWarehouse_EventScript_Gideon" in script:
		if done("sapphire"): a.dialog="GIDEON: You won. Take the Sapphire back to Celio."
		elif done("sapphire_stolen"): a.begin_battle("sevii_sapphire",[100,101,81,82,137],[46,46,46,46,46])
		else: a.dialog="Track the Sapphire at Dotted Hole first."
		return true
	if "IcefallCave_Back_EventScript_Lorelei" in script:
		if done("lorelei"): a.dialog="LORELEI: Icefall Cave's Pokemon are safe again. Thank you!"
		else: a.world.scenes.play([{"text":"LORELEI: Team Rocket is stealing Pokemon! Help me drive them out!","duration":1.8}],func():a.begin_battle("sevii_lorelei",[42,110],[38,38]))
		return true
	if at_port() and "SAILOR" in str(o.get("graphics_id","")): ferry_menu(); return true
	return false

func result(kind,won):
	if not won: return
	if kind.begins_with("sevii_biker_"):
		finish(kind)
		if kind=="sevii_biker_3": finish("bikers")
	var key={"sevii_lostelle":"lostelle_saved","sevii_sapphire":"sapphire","sevii_lorelei":"lorelei"}.get(kind,"")
	if key!="": finish(key)

func bikers():
	if done("bikers"): a.dialog="The biker gang has left. Cross Bond Bridge to search Berry Forest."; return
	var teams=[[[109,88],[37,37]],[[109],[38]],[[88],[38]],[[110,89],[39,39]]]
	for i in range(4):
		if not done("sevii_biker_"+str(i)):
			var team=teams[i]; var kind="sevii_biker_"+str(i)
			a.world.scenes.play([{"text":"The biker gang challenges you! Opponent "+str(i+1)+" of 4.","duration":1.5}],func():a.begin_battle(kind,team[0],team[1]))
			return

func boulder_puzzle():
	if a.world.current!="MAP_SEVEN_ISLAND_SEVAULT_CANYON_TANOBY_KEY" or done("tanoby"): return
	var switches=a.world.events.catalog[a.world.current].triggers.filter(func(t):return "EventScript_Switch" in str(t.get("script","")))
	var rocks=a.world.events.rocks()
	if switches.size()!=7: return
	if switches.all(func(t):return rocks.any(func(r):return int(r.x)==int(t.x) and int(r.y)==int(t.y))):
		finish("tanoby")
		a.world.scenes.play([{"text":"All seven stones settle into place. A rumble echoes toward the Tanoby Ruins!","duration":2.2,"flash":true}],func():a.save())

func tutor_menu(script):
	var move=tutors[script]
	var list=a.inventory.page("MOVE TUTOR / "+move.to_upper())
	if a.field.done("tutor:"+script): a.inventory.row(list,"I have already taught this move.",func():pass,true); return
	for i in range(a.data.party.size()):
		var mon=a.data.party[i]
		a.inventory.row(list,a.mon_name(mon.id),tutor_slots.bind(script,i),move in mon.moves or move not in a.field.learning.get(str(int(mon.id)),{}).get("tutors",[]) or not a.inventory.book.moves.has(move))

func tutor_slots(script,slot):
	var list=a.inventory.page("LEARN "+tutors[script].to_upper()+" / choose a slot")
	var mon=a.data.party[slot]
	for i in range(mon.moves.size()): a.inventory.row(list,"REPLACE "+mon.moves[i],teach.bind(script,slot,i))
	if mon.moves.size()<4: a.inventory.row(list,"EMPTY SLOT",teach.bind(script,slot,mon.moves.size()))

func teach(script,slot,index):
	if a.in_battle or not tutors.has(script) or a.field.done("tutor:"+script) or slot<0 or slot>=a.data.party.size(): return
	var mon=a.data.party[slot]; var move=tutors[script]
	if move in mon.moves or move not in a.field.learning.get(str(int(mon.id)),{}).get("tutors",[]) or index<0 or index>mon.moves.size() or index>=4: return
	if "Copycat" in script:
		if int(a.data.bag.get("pokedoll",0))<=0: return
		a.data.bag.pokedoll-=1
	if index==mon.moves.size(): mon.moves.append(move)
	else: mon.moves[index]=move
	a.field.finish("tutor:"+script); a.save(); a.clear_ui(); a.dialog=a.mon_name(mon.id)+" learned "+move.to_upper()+"!"

func journal():
	var list=a.inventory.page("SEVII / STORY JOURNAL")
	for pair in [["bikers","Three Island: defeat the four biker gang members."],["tanoby","Seven Island: push all seven Tanoby Key boulders onto their floor switches."],["lostelle_quest","Two Island: speak with Lostelle's father at the Joyful Game Corner."],["lostelle_saved","Three Island: follow Bond Bridge into Berry Forest and rescue Lostelle."],["lostelle_returned","Return to Lostelle's father."],["network_quest","Become Champion, then speak to Celio at One Island Pokemon Center."],["ruby","Find the Ruby in Mt. Ember's underground path."],["ruby_delivered","Bring the Ruby to Celio for the Rainbow Pass."],["lorelei","Help Lorelei confront Rocket in Icefall Cave on Four Island."],["sapphire_stolen","Six Island: enter Dotted Hole with Cut Shears; follow UP, LEFT, RIGHT, DOWN."],["sapphire","Five Island: defeat Gideon in the Rocket Warehouse."],["network","Return the Sapphire to Celio."]]:
		a.inventory.row(list,("DONE / " if done(pair[0]) else "NEXT / ")+pair[1],func():pass,true)
