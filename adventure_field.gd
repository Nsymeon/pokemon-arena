extends RefCounted
# Kanto field tools and one-shot quest rewards. State lives in world_events.done.
var a
var riding=false
var escape_point={}
var trades: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/trades.json"))
var pending_static=""
var learning: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/field-learning.json"))
const KEY_TOOLS={"cut":["Cut Shears","Cascade"],"strength":["Power Gloves","Rainbow"],"flash":["Lantern","Boulder"],"rocksmash":["Rock Hammer","Marsh"],"waterfall":["Waterfall Climber","Volcano"]}

func owns(tool) -> bool:
	if tool=="cut": return a.Story.state(a).get("cut",false)
	if tool in ["strength","surf"]: return a.Finale.has(a,tool)
	return done("field:"+tool)

func badge(tool) -> bool:
	if tool=="flash": return a.data.badge
	if tool=="cut": return a.data.get("cascade",false)
	return a.Finale.has(a,{"fly":"thunder","strength":"rainbow","surf":"soul","rocksmash":"marsh","waterfall":"volcano"}.get(tool,""))

func can_use(tool) -> bool:
	return owns(tool) and badge(tool) and (knows(tool) if tool in ["fly","surf"] else true)

func key_items():
	var list=a.inventory.page("KEY ITEMS / permanent tools")
	for tool in KEY_TOOLS:
		var spec=KEY_TOOLS[tool]
		a.inventory.row(list,spec[0]+" / "+tool.to_upper()+" / "+("OWNED" if owns(tool) else "NOT FOUND")+" / "+spec[1]+" Badge "+("OK" if badge(tool) else "REQUIRED"),flash if tool=="flash" else func():pass,tool!="flash" or not can_use(tool))
	for move in ["fly","surf"]:
		a.inventory.row(list,"TEACH "+move.to_upper()+" / reusable HM / Pokemon move required",hm_menu.bind(move),not owns(move))
	for key in a.Finale.keys(a): a.inventory.row(list,str(key),func():pass,true)

func hm_menu(move):
	if a.in_battle or not owns(move) or move not in ["fly","surf"]: return
	var list=a.inventory.page("TEACH "+move.to_upper()+" / choose partner")
	for i in range(a.data.party.size()):
		var mon=a.data.party[i]
		a.inventory.row(list,a.mon_name(mon.id),a.inventory.replace_menu.bind(i,move,""),not hm_eligible(mon,move))

func hm_eligible(mon,move) -> bool:
	return move in ["fly","surf"] and owns(move) and move in learning.get(str(int(mon.id)),{}).get("hms",[])
const LEGENDS={"Moltres":146,"Articuno":144,"Zapdos":145,"Mewtwo":150}
const FOSSILS={"helix":138,"dome":140,"amber":142}

func w(): return a.world
func done(key): return w().events.done(key)
func finish(key): w().events.finish(key)
func smash_key(o): return "smashed:"+w().current+":"+str(o.x)+":"+str(o.y)

func smash(o):
	if done(smash_key(o)): return
	if not can_use("rocksmash"):
		a.dialog="A cracked rock. Obtain the Rock Hammer at Pewter Museum and earn the Marsh Badge to use it."
		return
	var key=smash_key(o)
	w().scenes.play([{"text":"ROCK SMASH! Cracks spread through the stone...","duration":0.65,"flash":true,"effect":"smash","point":w().events.point(o)}],func():
		finish(key); a.dialog="The rock crumbled. The path is clear!"; a.save())

func reward(key: String, text: String):
	if done(key): a.dialog=text; return
	w().scenes.play([{"text":text,"duration":2.2,"flash":true}],func():finish(key); a.save())

func hidden(o) -> bool:
	var script=str(o.get("script",""))
	if script=="ThreeIsland_BerryForest_EventScript_Lostelle" and a.sevii.done("lostelle_saved"): return true
	if script=="TwoIsland_JoyfulGameCorner_EventScript_Lostelle" and not a.sevii.done("lostelle_saved"): return true
	if script.begins_with("ThreeIsland_EventScript_Biker") and a.sevii.done("bikers"): return true
	if done("static:"+script): return true
	return (script.ends_with("DomeFossil") or script.ends_with("HelixFossil")) and done("fossil:chosen") or script.ends_with("_OldAmber") and done("fossil:amber")

func npc(npc) -> bool:
	if a.services.npc(npc) or a.sevii.npc(npc): return true
	var script=str(npc.get("script",""))
	if trades.has(script): trade_menu(script); return true
	for name in LEGENDS:
		if script.ends_with("_"+name):
			if done("static:"+script): return true
			var species=LEGENDS[name]
			w().scenes.play([{"text":name.to_upper()+" lets out a powerful cry!","duration":1.5,"flash":true}],func():
				a.begin_battle("wild",[species],[70 if species==150 else 50])
				if a.in_battle: pending_static="static:"+script)
			return true
	var rods={"VermilionCity_House1_EventScript_FishingGuru":"old_rod","FuchsiaCity_House2_EventScript_FishingGurusBrother":"good_rod","Route12_FishingHouse_EventScript_FishingGuruBrother":"super_rod"}
	if rods.has(script):
		reward("field:"+rods[script],"FISHING GURU: Take the "+str(rods[script]).replace("_"," ").to_upper()+"! Face water and select it in BAG / FIELD TOOLS."); return true
	if script=="CeladonCity_Condominiums_RoofRoom_EventScript_EeveeBall":
		gift("eevee",133,25,"You found Eevee's Poke Ball!"); return true
	if script=="SilphCo_7F_EventScript_LaprasGuy" and a.Finale.has(a,"silph_blue"):
		if not a.Finale.has(a,"lapras"): a.dialog=a.Finale.complete(a,"lapras"); a.save()
		else: a.dialog="Take good care of Lapras."
		return true
	if script=="PewterCity_Museum_1F_EventScript_Scientist1":
		if not a.data.badge: a.dialog="RESEARCHER: Earn Brock's Boulder Badge, then I can teach you to break cracked rocks."
		else: reward("field:rocksmash","Received ROCK HAMMER! With the Marsh Badge, face cracked stones and interact. No move slot is required.")
		return true
	if script.ends_with("OldAmberScientist") or script.ends_with("_OldAmber"):
		if not a.Story.state(a).get("cut",false): a.dialog="SCIENTIST: Return with Cut to reach our fossil collection."
		else: reward("fossil:amber","SCIENTIST: This OLD AMBER contains ancient life. Take it to the fossil scientist in Cinnabar's laboratory!")
		return true
	if script.ends_with("DomeFossil") or script.ends_with("HelixFossil"):
		if done("fossil:chosen"): a.dialog="You and Miguel have each taken a fossil."; return true
		if not done("trainer:MtMoon_B2F_EventScript_Miguel"):
			a.dialog="Miguel guards these fossils. Defeat him first."; return true
		var kind="dome" if script.ends_with("DomeFossil") else "helix"
		a.panel("CHOOSE "+kind.to_upper()+" FOSSIL?")
		a.ui_label("Miguel will take the other fossil. Bring yours to Cinnabar Lab.",Vector2(180,285),21)
		a.ui_button("TAKE "+kind.to_upper(),Vector2(250,430),Vector2(700,65),choose_fossil.bind(kind))
		return true
	if script.ends_with("FossilScientist"):
		fossil_menu(); return true
	if script=="CeruleanCity_BikeShop_EventScript_Clerk":
		if done("field:bicycle"): a.dialog="Your bicycle is ready. Use BAG / FIELD TOOLS to mount it outdoors."
		elif a.Finale.has(a,"bicycle"): reward("field:bicycle","CLERK: Your Bicycle Voucher checks out! Here is your BICYCLE. Open BAG / FIELD TOOLS to ride outdoors.")
		else: a.dialog="The chairman of Vermilion's Pokemon Fan Club has a Bicycle Voucher."
		return true
	if script=="Route16_House_EventScript_Woman":
		reward("field:fly","Received HM FLY! Teach it in BAG / KEY ITEMS. A healthy partner knowing Fly and the Thunder Badge are required."); return true
	if script=="Route2_EastBuilding_EventScript_Aide":
		var species=[]
		for mon in a.data.party+a.data.storage:
			if mon.id not in species: species.append(mon.id)
		for mon in a.c.roster:
			if done("seen:"+str(int(mon.id))) and int(mon.id) not in species: species.append(int(mon.id))
		if species.size()<10: a.dialog="OAK'S AIDE: See 10 different Pokemon and I will give you Flash. Seen: "+str(species.size())
		else: reward("field:flash","OAK'S AIDE: Take this LANTERN! With the Boulder Badge, illuminate Rock Tunnel from BAG / KEY ITEMS. No move slot needed.")
		return true
	return false

func choose_fossil(kind):
	if done("fossil:chosen"): return
	a.clear_ui()
	w().scenes.play([{"text":"You carefully lift the "+kind.to_upper()+" FOSSIL.","duration":1.5},{"text":"MIGUEL: Then the other one is mine! A scientist on Cinnabar can revive yours.","duration":2.3}],func():
		finish("fossil:chosen"); finish("fossil:"+kind); a.save())

func fossil_menu():
	var list=a.inventory.page("CINNABAR / FOSSIL REVIVAL")
	for kind in FOSSILS:
		if done("fossil:"+kind): a.inventory.row(list,kind.to_upper()+" / "+a.mon_name(FOSSILS[kind])+(" / ALREADY REVIVED" if done("revived:"+kind) else " / REVIVE"),revive.bind(kind),done("revived:"+kind))
	a.inventory.row(list,"Bring a Mt. Moon fossil or Old Amber from Pewter Museum.",func():pass,true)

func revive(kind):
	if not FOSSILS.has(kind) or not done("fossil:"+kind) or done("revived:"+kind): return
	if a.data.party.size()>=6 and a.data.storage.size()>=100: a.dialog="Party and storage are full. Make room first."; a.clear_ui(); return
	a.clear_ui()
	w().scenes.play([{"text":"SCIENTIST: The fossil is going into the regeneration chamber...","duration":1.8},{"text":"Ancient cells stir. A Pokemon is waking up!","duration":1.7,"flash":true},{"text":"It is alive!","duration":1.5,"portrait":FOSSILS[kind]}],func():
		if a.data.party.size()>=6 and a.data.storage.size()>=100: a.dialog="Make space and return."; return
		var mon=a.new_mon(FOSSILS[kind],5)
		if a.data.party.size()<6: a.data.party.append(mon)
		else: a.data.storage.append(mon)
		finish("revived:"+kind); a.dialog=a.mon_name(mon.id)+" was revived! "+("Sent to storage." if a.data.party.size()>=6 and mon not in a.data.party else "Joined your party."); a.save())

func outdoor() -> bool:
	return w().room().type in ["MAP_TYPE_TOWN","MAP_TYPE_CITY","MAP_TYPE_ROUTE"]

func entered(previous, at: Vector2):
	if previous.begins_with("MAP_SAFARI_ZONE") and not w().current.begins_with("MAP_SAFARI_ZONE"):
		a.services.state().safari=false; a.services.safari_mon={}
	riding=false
	if w().maps[previous].type in ["MAP_TYPE_TOWN","MAP_TYPE_CITY","MAP_TYPE_ROUTE"] and not outdoor():
		escape_point={"map":previous,"x":at.x,"y":at.y}
		a.data["field_exit"]=escape_point.duplicate()
	if outdoor(): finish("visited:"+w().current)

func tools_menu():
	var list=a.inventory.page("FIELD TOOLS / KANTO & SEVII")
	a.inventory.row(list,"SEVII STORY JOURNAL",a.sevii.journal)
	if a.sevii.at_port(): a.inventory.row(list,"SEAGALLOP FERRY",a.sevii.ferry_menu)
	if a.world.current.contains("GAME_CORNER"): a.inventory.row(list,"GAME CORNER",a.services.game_menu)
	if a.world.current.contains("POKEMON_DAY_CARE"): a.inventory.row(list,"DAY CARE",a.services.daycare_menu)
	if a.world.current.contains("SAFARI_ZONE_ENTRANCE"): a.inventory.row(list,"SAFARI ADMISSION",a.services.safari_menu)
	a.inventory.row(list,"KEY ITEMS / tools, badges and HM teaching",key_items)
	a.inventory.row(list,"QUEST JOURNAL / where to find tools and rewards",journal)
	a.inventory.row(list,"ROCK HAMMER / "+("face a cracked rock / Marsh Badge required" if done("field:rocksmash") else "Pewter museum researcher"),func():pass,true)
	a.inventory.row(list,"BICYCLE / "+("DISMOUNT" if riding else "RIDE OUTDOORS"),toggle_bike,not done("field:bicycle"))
	a.inventory.row(list,"FLY / VISITED TOWNS",fly_menu,not can_use("fly"))
	a.inventory.row(list,"FLASH / LIGHT ROCK TUNNEL",flash,not can_use("flash"))
	a.inventory.row(list,"DIG / ESCAPE CAVE",escape.bind(false),not knows("dig"))
	a.inventory.row(list,"TELEPORT / LAST HEALING TOWN",teleport,not knows("teleport"))
	for rod in ["old_rod","good_rod","super_rod"]:
		a.inventory.row(list,rod.replace("_"," ").to_upper()+" / FISH",fish.bind(rod),not done("field:"+rod))
	for kind in FOSSILS:
		if done("fossil:"+kind): a.inventory.row(list,kind.to_upper()+" FOSSIL / "+("revived" if done("revived:"+kind) else "take to Cinnabar Lab"),func():pass,true)

func knows(move):
	return a.data.party.any(func(mon):return mon.hp>0 and move in mon.moves)

func toggle_bike():
	if a.in_battle or not done("field:bicycle"): return
	if not outdoor(): a.clear_ui(); a.dialog="You can only ride outdoors."; return
	riding=not riding; a.clear_ui(); a.dialog="Mounted the bicycle." if riding else "Dismounted."

func flash():
	if a.in_battle or not can_use("flash"): return
	a.clear_ui()
	if not w().current.contains("ROCK_TUNNEL"): a.dialog="It is already bright enough here."; return
	reward("lit:"+w().current,"FLASH! Light fills the tunnel.")

func fly_menu():
	if a.in_battle or not can_use("fly"): return
	var list=a.inventory.page("FLY / VISITED TOWNS")
	for id in w().maps:
		if w().maps[id].type in ["MAP_TYPE_TOWN","MAP_TYPE_CITY"] and done("visited:"+id): a.inventory.row(list,w().maps[id].name,fly.bind(id))

func fly(id):
	if a.in_battle or not can_use("fly") or not done("visited:"+id): return
	if not outdoor(): a.clear_ui(); a.dialog="Go outside before using Fly."; return
	a.clear_ui()
	w().scenes.play([{"text":"FLY! Your partner carries you toward "+w().maps[id].name+".","duration":1.5,"flash":true}],func():w().enter(id,Vector2(12.5,12.5)*w().TILE))

func escape(consume=true) -> bool:
	if a.in_battle or w().room().type!="MAP_TYPE_UNDERGROUND": a.clear_ui(); a.dialog="Use this inside a cave."; return false
	if not consume and not knows("dig"): return false
	if consume and int(a.data.bag.get("escaperope",0))<=0: return false
	var target=a.data.get("field_exit",{})
	if target.is_empty() or not w().maps.has(target.get("map","")): a.clear_ui(); a.dialog="No cave entrance recorded. Leave and re-enter once."; return false
	if consume: a.data.bag.escaperope-=1
	a.clear_ui(); w().enter(target.map,Vector2(target.x,target.y)); a.dialog="Returned safely to the entrance."; return true

func teleport():
	if a.in_battle or not knows("teleport"): return
	if not outdoor(): a.clear_ui(); a.dialog="Use Teleport outdoors."; return
	var id=w().names[w().LEGACY[int(a.data.healing_map)]]
	a.clear_ui(); w().enter(id,Vector2(12.5,12.5)*w().TILE); a.dialog="Teleported to the last healing town."

func draw():
	if w().current.contains("ROCK_TUNNEL") and not done("lit:"+w().current):
		# A light overlay preserves navigation; Flash visibly removes it.
		a.draw_rect(Rect2(0,90,1280,700),Color(0.025,0.025,0.08,0.42))
	if riding and outdoor():
		var p=a.position_world-a.camera+Vector2(0,101)
		a.draw_arc(p+Vector2(-15,0),11,0,TAU,20,Color("324859"),3)
		a.draw_arc(p+Vector2(15,0),11,0,TAU,20,Color("324859"),3)
		a.draw_polyline(PackedVector2Array([p+Vector2(-15,0),p+Vector2(0,-12),p+Vector2(15,0),p+Vector2(-15,0)]),Color("d9e7ed"),2)

func gift(key,species,level,text):
	if done("gift:"+key): a.dialog="This Pokemon is already travelling with you."; return
	if a.data.party.size()>=6 and a.data.storage.size()>=100: a.dialog="Make room in your party or storage first."; return
	w().scenes.play([{"text":text,"duration":1.8,"flash":true}],func():
		if done("gift:"+key): return
		var mon=a.new_mon(species,level)
		if a.data.party.size()<6: a.data.party.append(mon)
		elif a.data.storage.size()<100: a.data.storage.append(mon)
		else: return
		finish("gift:"+key); a.dialog=a.mon_name(species)+" joined you!"; a.save())

func fish(rod):
	if a.in_battle or not done("field:"+rod): return
	var at=a.position_world+w().heading*w().TILE
	var x=floori(at.x/w().TILE); var y=floori(at.y/w().TILE)
	if x<0 or y<0 or x>=w().room().width or y>=w().room().height: return
	var terrain=int(w().events.catalog[w().current].behavior[y*int(w().room().width)+x])
	var pool=w().scenes.encounters.get(w().current,{}).get(rod,[])
	a.clear_ui()
	if terrain not in [0x10,0x11,0x12,0x15,0x50,0x51,0x52,0x53] or pool.is_empty(): a.dialog="Face a fishable water tile first."; return
	var mon=w().scenes.roll(pool)
	w().scenes.play([{"text":"You cast your line...","duration":1.1},{"text":"A bite!","duration":0.6}],func():a.begin_battle("wild",[mon.id],[mon.level]))

func ghost() -> bool:
	if a.Finale.has(a,"tower_ghost"): return false
	if not a.Finale.has(a,"scope"): a.dialog="A ghost blocks the stairway. Find the Silph Scope to reveal it."; return true
	w().scenes.play([{"text":"The Silph Scope reveals Marowak's restless spirit!","duration":1.7,"flash":true},{"text":"Calm Cubone's mother. This spirit cannot be caught.","duration":1.5}],func():a.begin_battle("late_tower_ghost",[105],[30]))
	return true

func battle_result(kind,won,caught):
	a.sevii.result(kind,won)
	if pending_static!="":
		if kind=="wild" and (won or caught): finish(pending_static)
		pending_static=""

func journal():
	var list=a.inventory.page("KANTO / QUEST JOURNAL")
	for entry in [["field:rocksmash","Rock Hammer: Pewter Museum researcher; Marsh Badge required to use."],["field:bicycle","Bicycle: Vermilion Fan Club voucher, then Cerulean Bike Shop."],["fossil:chosen","Fossils: defeat Miguel in Mt. Moon B2F; choose one fossil."],["fossil:amber","Old Amber: return to Pewter Museum after obtaining Cut."],["field:fly","Fly: speak to the woman in Route 16's house; Thunder Badge required."],["field:flash","Flash: see 10 different species to Oak's aide in Route 2 East Building."],["field:old_rod","Old Rod: Vermilion City's fishing guru."],["field:good_rod","Good Rod: Fuchsia City's fishing guru."],["field:super_rod","Super Rod: fishing house on Route 12."]]:
		a.inventory.row(list,("DONE / " if done(entry[0]) else "NEXT / ")+entry[1],func():pass,true)
	a.inventory.row(list,"Revive fossils: Cinnabar Lab / Experiment Room. Make room in party or storage.",func():pass,true)
	a.inventory.row(list,"Pokemon Tower: obtain Silph Scope, calm Marowak, then rescue Mr. Fuji.",func():pass,true)

func tests():
	var previous=a.data.duplicate(true); var map_before=w().current; var position=a.position_world
	var allowed=a.save_allowed; var battling=a.in_battle; var exploring=a.exploring; var dialog=a.dialog
	a.save_allowed=false; a.in_battle=false; a.exploring=true
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.party=[a.new_mon(4,10)]; a.inventory.migrate()
	w().current="MAP_CERULEAN_CAVE_1F"; w().events.refresh()
	var rock=w().room().objects.filter(func(o):return str(o.graphics_id).contains("ROCK_SMASH_ROCK"))[0]
	smash(rock)
	a.c.check(not w().scenes.active and w().blocked(w().events.point(rock)),"Rock Smash requires its field unlock")
	finish("field:rocksmash"); a.Finale.state(a)["marsh"]=true; smash(rock)
	a.c.check(w().scenes.active,"Rock Smash plays an action scene")
	w().scenes.finish()
	a.c.check(done(smash_key(rock)) and not w().blocked(w().events.point(rock)),"Rock Smash removes live collision and saves removal")
	var saved=JSON.parse_string(JSON.stringify(a.data)); a.data=saved
	a.c.check(done(smash_key(rock)),"Smashed rock remains removed after save round trip")
	w().current="MAP_MT_MOON_B2F"; w().events.refresh()
	finish("trainer:MtMoon_B2F_EventScript_Miguel"); choose_fossil("helix"); w().scenes.finish()
	choose_fossil("dome")
	a.c.check(done("fossil:helix") and not done("fossil:dome"),"Mt Moon grants only one fossil")
	w().current="MAP_CINNABAR_ISLAND_POKEMON_LAB_EXPERIMENT_ROOM"; w().events.refresh()
	var count=a.data.party.size(); revive("helix"); w().scenes.finish(); revive("helix")
	a.c.check(a.data.party.size()==count+1 and a.data.party[-1].id==138 and done("revived:helix"),"Fossil revival grants one Omanyte without duplicates")
	reward("fossil:amber","Old Amber"); w().scenes.finish(); revive("amber"); w().scenes.finish()
	a.c.check(a.data.party[-1].id==142,"Old Amber revives Aerodactyl")
	w().current="MAP_CERULEAN_CITY"; finish("field:bicycle"); toggle_bike()
	a.c.check(riding,"Bicycle can mount outdoors")
	w().current="MAP_MT_MOON_1F"; entered("MAP_ROUTE4",Vector2(4.5,4.5)*w().TILE)
	a.c.check(not riding and a.data.field_exit.map=="MAP_ROUTE4","Entering interior dismounts and records exit")
	a.data.bag.escaperope=1; escape()
	a.c.check(w().current=="MAP_ROUTE4" and a.data.bag.escaperope==0,"Escape Rope returns to recorded entrance and consumes once")
	pending_static="static:regression"; battle_result("wild",false,false)
	a.c.check(not done("static:regression"),"Failed legendary battle leaves encounter available")
	pending_static="static:regression"; battle_result("wild",false,true)
	a.c.check(done("static:regression"),"Caught legendary is removed once")
	var script=trades.keys()[0]; var offer=trades[script]
	a.data.party=[a.new_mon(int(offer.give),20)]; a.data.party[0]["held_item"]="quickclaw"
	confirm_trade(script,0); a.clear_ui()
	a.c.check(a.data.party[0].id==offer.give,"Cancelling trade confirmation keeps the original Pokemon")
	trade(script,0); w().scenes.finish(); trade(script,0)
	a.c.check(a.data.party.size()==1 and a.data.party[0].id==offer.receive and a.data.party[0].level==20 and int(a.data.bag.get("quickclaw",0))==1,"NPC trade replaces once, preserves level and returns held item")
	for rod in ["old_rod","good_rod","super_rod"]:
		var slots=w().scenes.encounters["MAP_VERMILION_CITY"][rod]; var total=0
		for slot in slots: total+=int(slot.weight)
		a.c.check(total==100,"Imported "+rod+" slot probabilities sum to 100")
	w().scenes.reset(); a.clear_ui(); riding=false; pending_static=""
	a.data=previous; w().current=map_before; w().events.refresh(); a.position_world=position
	a.save_allowed=allowed; a.in_battle=battling; a.exploring=exploring; a.dialog=dialog

func trade_menu(script):
	if done("trade:"+script): a.dialog="Thanks for the trade! Your old partner is doing well."; return
	var offer=trades[script]
	var list=a.inventory.page(offer.trainer+" / "+a.mon_name(offer.give)+" FOR "+a.mon_name(offer.receive))
	a.inventory.row(list,"Choose the Pokemon to trade. The new partner keeps its level. Cancel to keep your Pokemon.",func():pass,true)
	for i in range(a.data.party.size()):
		var mon=a.data.party[i]
		a.inventory.row(list,a.mon_name(mon.id)+" Lv."+str(mon.level)+(" / SHINY" if mon.get("shiny",false) else ""),confirm_trade.bind(script,i),int(mon.id)!=int(offer.give))

func confirm_trade(script,slot):
	if not trades.has(script) or done("trade:"+script) or slot<0 or slot>=a.data.party.size(): return
	var offer=trades[script]; var mon=a.data.party[slot]
	if int(mon.id)!=int(offer.give): return
	a.panel("CONFIRM TRADE")
	a.ui_label("Trade your "+a.mon_name(mon.id)+" Lv."+str(mon.level)+(" (SHINY)" if mon.get("shiny",false) else "")+" for "+a.mon_name(offer.receive)+"?",Vector2(180,285),22)
	a.ui_label("The Pokemon you give away leaves your party. Its held item is returned to your bag.",Vector2(180,345),19)
	a.ui_button("CONFIRM EXCHANGE",Vector2(250,450),Vector2(700,65),trade.bind(script,slot))

func trade(script,slot):
	if a.in_battle or not trades.has(script) or done("trade:"+script) or slot<0 or slot>=a.data.party.size(): return
	var offer=trades[script]; var mon=a.data.party[slot]
	if int(mon.id)!=int(offer.give): return
	var held=str(mon.get("held_item",""))
	if held!="" and int(a.data.bag.get(held,0))>=999: a.clear_ui(); a.dialog="Make room for the held item first."; return
	a.clear_ui()
	w().scenes.play([{"text":"Your Poke Balls enter the trading machine...","duration":1.5},{"text":offer.nickname+" is on the way!","duration":1.4,"flash":true}],func():
		if done("trade:"+script) or a.data.party[slot]!=mon: return
		var received=a.new_mon(int(offer.receive),int(mon.level))
		received.shiny=false; received.ability_slot=int(offer.ability); a.c.abilities.assign(received)
		received["nickname"]=offer.nickname
		if held!="": a.data.bag[held]=int(a.data.bag.get(held,0))+1
		a.data.party[slot]=received; finish("trade:"+script); finish("seen:"+str(int(received.id)))
		a.dialog="Trade complete! "+offer.nickname+" ("+a.mon_name(received.id)+") joined your team."; a.save())

func losing_surf(slot, replacement) -> bool:
	if not a.world.enabled or a.world.scenes.habitat()!="water_mons": return false
	for i in range(a.data.party.size()):
		var mon=replacement if i==slot else a.data.party[i]
		if mon.hp>0 and "surf" in mon.moves: return false
	a.dialog="Reach land before removing your last partner that knows Surf."
	return true
