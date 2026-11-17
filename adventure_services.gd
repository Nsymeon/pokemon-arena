extends RefCounted
# Optional activities use a separate, validated save block.
var a
var safari_mon={}
var catch_factor=0
var bait=0
var angry=0
var message=""
const MON_PRIZES={63:[180,9],35:[500,8],147:[2800,18],123:[5500,25],137:[9999,26]}
const TM_PRIZES={"TM13":4000,"TM23":3500,"TM24":4000,"TM30":4500,"TM35":4000}
const ITEM_PRIZES={"smokeball":800,"miracleseed":1000,"charcoal":1000,"mysticwater":1000,"yellowflute":1600}
var rates: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/catch-rates.json"))

func state():
	if not a.data.has("services"): a.data.services={"coins":0,"steps":0,"safari":false,"safari_steps":0,"safari_balls":0,"daycare":{}}
	return a.data.services

func valid(value) -> bool:
	if not value.has("services"): return true
	var s=value.services
	if not s is Dictionary or not s.get("safari") is bool or not s.get("daycare") is Dictionary: return false
	for key in ["coins","steps","safari_steps","safari_balls"]:
		var n=s.get(key)
		if not (n is int or n is float) or not is_finite(n) or n!=int(n) or n<0 or n>{"coins":9999,"steps":1000000000,"safari_steps":600,"safari_balls":30}[key]: return false
	if not s.daycare.is_empty():
		if not s.daycare.get("mon") is Dictionary: return false
		if not valid_steps(s.daycare.get("xp_steps",0)): return false
		for key in ["start_level","deposited"]:
			var n=s.daycare.get(key)
			if not (n is int or n is float) or n!=int(n) or n<0 or n>1000000000: return false
		if s.daycare.start_level<1 or s.daycare.start_level>100: return false
		var copy=value.duplicate(true); copy.erase("services"); copy.party=[s.daycare.mon]; copy.starter=1
		if not a.valid(copy): return false
		if s.daycare.mon.level<s.daycare.start_level or s.daycare.deposited>s.steps: return false
	return true

func npc(o) -> bool:
	var script=str(o.get("script",""))
	if script=="TwoIsland_EventScript_Clerk":
		var stage="Expanded3" if a.sevii.done("network") else "Expanded2" if a.Finale.has(a,"champion") else "Expanded1" if a.sevii.done("lostelle_saved") else "Initial"
		a.inventory.shop("TwoIsland_EventScript_Shop"+stage); return true
	if "DaycareMan" in script or "DaycareWoman" in script:
		if a.world.current.begins_with("MAP_FOUR_ISLAND"): a.breeding.menu()
		else: daycare_menu()
		return true
	# Patrons and the information attendant keep their own dialogue and choices.
	if script=="CeladonCity_GameCorner_EventScript_CoinsClerk": game_menu(); return true
	if script.begins_with("CeladonCity_GameCorner_PrizeRoom_EventScript_PrizeClerk"): game_menu(); return true
	if script=="FuchsiaCity_SafariZone_Entrance_EventScript_AskEnterSafariZone" or (a.world.current=="MAP_FUCHSIA_CITY_SAFARI_ZONE_ENTRANCE" and script=="0x0"): safari_menu(); return true
	return false

func steps():
	a.breeding.step()
	a.vs_seeker.step()
	var s=state(); s.steps=mini(1000000000,int(s.steps)+1)
	if not s.daycare.is_empty():
		s.daycare.xp_steps=mini(1000000000,int(s.daycare.get("xp_steps",0))+1)
	if s.safari and a.world.current.begins_with("MAP_SAFARI_ZONE"):
		s.safari_steps=maxi(0,int(s.safari_steps)-1)
		if s.safari_steps==0: end_safari("Time is up! Your Safari visit has ended.")

func daycare_menu():
	var s=state(); var list=a.inventory.page("DAY CARE / one partner / 1 EXP per walking tile")
	if s.daycare.is_empty():
		a.inventory.row(list,"Retrieval: $100 + $100 per level gained. New moves can replace the oldest move; no evolution.",func():pass,true)
		for i in range(a.data.party.size()): a.inventory.row(list,"LEAVE "+a.mon_name(a.data.party[i].id)+" Lv."+str(a.data.party[i].level),deposit.bind(i),a.data.party.size()<2 or a.data.party[i].hp<=0)
	else:
		var mon=projected(s.daycare.mon,int(s.daycare.get("xp_steps",0)))
		a.inventory.row(list,a.mon_name(mon.id)+" Lv."+str(mon.level)+" / RETRIEVE $"+str(fee()),withdraw,a.data.party.size()>=6 or a.data.money<fee())

func deposit(slot):
	if a.in_battle or not state().daycare.is_empty() or slot<0 or slot>=a.data.party.size() or a.data.party.size()<2: return
	if a.data.party[slot].hp<=0 or a.data.party.filter(func(m):return m.hp>0).size()<2: a.dialog="Keep a healthy partner with you."; return
	if a.field.losing_surf(slot,{"hp":0,"moves":[]}): return
	state().daycare={"mon":a.data.party[slot],"start_level":a.data.party[slot].level,"deposited":state().steps,"xp_steps":0}
	a.data.party.remove_at(slot); a.save(); daycare_menu()

func fee() -> int:
	if state().daycare.is_empty(): return 0
	var mon=projected(state().daycare.mon,int(state().daycare.get("xp_steps",0)))
	return 100+100*maxi(0,int(mon.level)-int(state().daycare.start_level))

func withdraw():
	if a.in_battle or state().daycare.is_empty() or a.data.party.size()>=6 or a.data.money<fee(): return
	var mon=projected(state().daycare.mon,int(state().daycare.get("xp_steps",0)))
	mon.hp=1.; mon.ailment=""
	a.data.money-=fee(); a.data.party.append(mon); state().daycare={}; a.save(); daycare_menu()

func valid_steps(value) -> bool:
	return (value is int or value is float) and is_finite(value) and value==int(value) and value>=0 and value<=1000000000

func projected(original: Dictionary, steps: int) -> Dictionary:
	var mon=original.duplicate(true)
	mon.xp+=steps
	while int(mon.level)<100 and mon.xp>=a.xp_needed(mon):
		mon.xp-=a.xp_needed(mon); mon.level+=1
		for entry in a.inventory.book.species[str(int(mon.id))].levels:
			if int(entry.level)!=int(mon.level) or entry.move in mon.moves: continue
			if mon.moves.size()>=4: mon.moves.pop_front()
			mon.moves.append(entry.move); mon.pending.erase(entry.move)
	if int(mon.level)>=100: mon.xp=0
	return mon

func safari_menu():
	var list=a.inventory.page("SAFARI ZONE / $500 / 30 Safari Balls / 600 steps")
	a.inventory.row(list,"Search grass or water with E. Catch with balls, bait or rocks; no Pokemon battle.",func():pass,true)
	a.inventory.row(list,"START SAFARI VISIT",start_safari,a.data.money<500 or state().safari)
	if state().safari: a.inventory.row(list,"END VISIT",end_safari.bind("You ended the Safari visit."))

func start_safari():
	if a.in_battle or state().safari or a.data.money<500: return
	a.data.money-=500; state().safari=true; state().safari_steps=600; state().safari_balls=30
	a.clear_ui(); a.world.enter("MAP_SAFARI_ZONE_CENTER",Vector2(26.5,30.5)*48); a.save()

func end_safari(text):
	state().safari=false; safari_mon={}; a.clear_ui()
	a.world.enter("MAP_FUCHSIA_CITY_SAFARI_ZONE_ENTRANCE",Vector2(4.5,6.5)*48)
	a.dialog=text; a.save()

func safari_encounter(mon):
	if not state().safari: a.dialog="Buy a Safari admission at the entrance first."; return
	safari_mon=a.new_mon(int(mon.id),int(mon.level)); bait=0; angry=0
	catch_factor=base_catch_factor()
	a.collection.register(safari_mon,false)
	message="A wild "+a.mon_name(mon.id)+(" sparkles!" if safari_mon.shiny else " appeared!")
	safari_panel()

func safari_panel():
	var list=a.inventory.page("SAFARI / "+str(state().safari_balls)+" BALLS / "+str(state().safari_steps)+" STEPS")
	var portrait=TextureRect.new()
	portrait.texture=a.c.portrait(safari_mon); portrait.custom_minimum_size=Vector2(180,150)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	list.add_child(portrait)
	a.inventory.row(list,message,func():pass,true)
	for action in ["ball","bait","rock","run"]: a.inventory.row(list,action.to_upper(),safari_action.bind(action))

func safari_action(action):
	if safari_mon.is_empty() or not state().safari: return
	if action not in ["ball","bait","rock","run"]: return
	if action=="run": safari_mon={}; a.clear_ui(); return
	if action=="ball":
		if a.data.party.size()>=6 and a.data.storage.size()>=a.collection.STORAGE_CAPACITY: message="Party and storage are full. Make room before catching."; safari_panel(); return
		state().safari_balls-=1
		if safari_shakes()==4: caught_safari(); return
		message="It broke free!"
	elif action=="bait": catch_factor=maxi(3,catch_factor/2); bait=mini(6,bait+randi_range(2,6)); angry=0; message="The Pokemon is eating. Catching is harder, but fleeing is less likely."
	elif action=="rock": catch_factor=mini(20,catch_factor*2); angry=mini(6,angry+randi_range(2,6)); bait=0; message="The Pokemon is angry. Catching is easier, but fleeing is more likely."
	var flee=flee_chance()
	if state().safari_balls<=0: end_safari("Out of Safari Balls!"); return
	if randi_range(0,99)<flee: safari_mon={}; a.clear_ui(); a.dialog="The wild Pokemon fled."; a.save(); return
	safari_watch()
	a.save(); safari_panel()

func base_catch_factor() -> int:
	return int(int(rates.get(str(int(safari_mon.id)),{"catch":45})["catch"])*100/1275)

func shake_threshold() -> int:
	# FireRed uses integer truncation at every division and square root.
	var odds=int(int(catch_factor*1275/100)*15/10)/3
	if odds<=0: return 0
	return 65536 if odds>=255 else int(1048560/int(sqrt(int(sqrt(int(16711680/odds))))))

func safari_shakes() -> int:
	var threshold=shake_threshold(); var shakes=0
	while shakes<4 and a.c.rng.randi_range(0,65535)<threshold: shakes+=1
	return shakes

func flee_chance() -> int:
	var factor=maxi(2,int(int(rates.get(str(int(safari_mon.id)),{"flee":50}).flee)*100/1275))
	if angry>0: factor=mini(20,factor*2)
	elif bait>0: factor=maxi(1,factor/4)
	return factor*5

func safari_watch():
	if angry>0:
		angry-=1
		if angry==0: catch_factor=base_catch_factor()
	elif bait>0: bait-=1

func caught_safari():
	var mon=safari_mon; var fresh=not a.data.pokedex.get(str(int(mon.id)),{}).get("caught",false)
	var amount=a.experience.reward(int(mon.id),int(mon.level),false)
	var lead=-1
	for i in a.data.party.size():
		if a.data.party[i].hp>0 and not a.data.party[i].get("is_egg",false): lead=i; break
	var report=a.grant_xp(amount,[lead]) if lead>=0 else ""
	a.collection.register(mon)
	if a.data.party.size()<6: a.data.party.append(mon)
	else: a.collection.store(mon)
	safari_mon={}; a.clear_ui()
	var description="Caught "+a.mon_name(mon.id)+"! +"+str(amount)+" EXP. "+report
	if state().safari_balls==0: end_safari("Last Safari Ball used. "+description)
	else: a.dialog=description
	a.save()
	if fresh: a.collection.dex_entry(int(mon.id),bool(mon.shiny),true,int(mon.get("form",0)))
	elif not a.evolutions.is_empty(): a.show_evolution()

func game_menu():
	var list=a.inventory.page("GAME CORNER / "+str(state().coins)+" COINS")
	if not a.field.done("coin_case"):
		a.inventory.row(list,"Get the Coin Case from the man at Celadon's restaurant.",func():pass,true); return
	a.inventory.row(list,"BUY 50 COINS / $1000",buy_coins,a.data.money<1000 or state().coins>9949)
	a.inventory.row(list,"BUY 500 COINS / $10000",buy_coins.bind(500),a.data.money<10000 or state().coins>9499)
	a.inventory.row(list,"PLAY SLOTS / bet 1, 2 or 3 coins",spin,state().coins<1)
	for prize in [[63,180],[35,500],[123,5500],[147,2800],[137,9999]]: a.inventory.row(list,a.mon_name(prize[0])+" / "+str(prize[1])+" COINS",prize_mon.bind(prize[0],prize[1]),state().coins<prize[1])
	for prize in [["TM13",4000],["TM24",4000],["TM35",4000],["TM23",3500],["TM30",4500]]: a.inventory.row(list,a.inventory.book.tms[prize[0]].name+" / "+str(prize[1])+" COINS",prize_tm.bind(prize[0],prize[1]),state().coins<prize[1])
	for id in ITEM_PRIZES: a.inventory.row(list,a.inventory.ITEMS[id].name+" / "+str(ITEM_PRIZES[id])+" COINS",prize_item.bind(id),state().coins<ITEM_PRIZES[id])

func buy_coins(amount=50):
	if amount not in [50,500] or a.in_battle or not a.field.done("coin_case") or a.data.money<amount*20 or state().coins>9999-amount: return
	a.data.money-=amount*20; state().coins+=amount; a.save(); game_menu()

func spin():
	if a.in_battle or not a.field.done("coin_case"): return
	var list=a.inventory.page("GAME CORNER / STOP THE REELS",game_menu)
	var game=preload("res://game_corner_slots.gd").new(); game.a=a; game.custom_minimum_size=Vector2(875,450); list.add_child(game)

func prize_mon(id,cost):
	if not MON_PRIZES.has(id) or cost!=MON_PRIZES[id][0]: return
	if a.in_battle or not a.field.done("coin_case") or state().coins<cost: return
	if a.data.party.size()>=6 and a.data.storage.size()>=a.collection.STORAGE_CAPACITY: a.dialog="Make room in your party or storage first."; return
	state().coins-=cost
	var mon=a.new_mon(id,MON_PRIZES[id][1]); a.collection.register(mon)
	if a.data.party.size()<6: a.data.party.append(mon)
	else: a.collection.store(mon)
	a.save(); game_menu()

func prize_tm(id,cost):
	if not TM_PRIZES.has(id) or cost!=TM_PRIZES[id]: return
	if a.in_battle or not a.field.done("coin_case") or state().coins<cost or int(a.data.tms.get(id,0))>=999: return
	state().coins-=cost; a.data.tms[id]=int(a.data.tms.get(id,0))+1; a.save(); game_menu()

func prize_item(id):
	if a.in_battle or not a.field.done("coin_case") or not ITEM_PRIZES.has(id): return
	if state().coins<ITEM_PRIZES[id] or int(a.data.bag.get(id,0))>=999: return
	state().coins-=ITEM_PRIZES[id]; a.data.bag[id]=int(a.data.bag.get(id,0))+1; a.save(); game_menu()

func tests():
	var previous=a.data.duplicate(true); var saving=a.save_allowed; var map=a.world.current; var at=a.position_world
	var old_dialog=a.dialog; var old_battle=a.in_battle; var old_exploring=a.exploring
	a.save_allowed=false; a.in_battle=false; a.exploring=true
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.party=[a.new_mon(4,10),a.new_mon(7,10)]; a.inventory.migrate()
	a.data.money=20000; a.world.current="MAP_ROUTE5_POKEMON_DAY_CARE"
	deposit(1); a.clear_ui()
	a.c.check(a.data.party.size()==1 and state().daycare.mon.id==7,"Day Care transfers the exact partner out of the party")
	var mon=state().daycare.mon; mon.xp=a.xp_needed(mon)-1
	steps(); a.c.check(mon.level==10 and projected(mon,int(state().daycare.xp_steps)).level==11 and fee()==200,"Day Care previews deferred EXP and calculates retrieval fee")
	var money=a.data.money; withdraw(); a.clear_ui()
	a.c.check(state().daycare.is_empty() and a.data.party.size()==2 and a.data.money==money-200,"Day Care retrieval charges once and returns partner")
	withdraw(); a.c.check(a.data.money==money-200,"Empty Day Care cannot charge twice")
	a.data.party=[a.new_mon(7,10)]; deposit(0); a.c.check(state().daycare.is_empty(),"Day Care cannot take the last partner")
	a.Story.state(a)["cut"]=true
	a.c.check(not a.field.can_use("cut"),"Cut Shears still require Cascade Badge")
	a.data.cascade=true; a.c.check(a.field.can_use("cut") and "cut" not in a.data.party[0].moves,"Cut tool uses no move slot")
	a.Finale.state(a)["surf"]=true; a.Finale.state(a)["soul"]=true
	a.c.check(not a.field.can_use("surf"),"Surf unlock and badge alone do not allow water traversal")
	a.c.check(a.inventory.teach(0,"surf",0),"Compatible Pokemon can learn reusable HM Surf")
	a.clear_ui(); a.c.check(a.field.can_use("surf"),"Known Surf plus Soul Badge permits water")
	a.data.party[0].hp=0; a.c.check(not a.field.can_use("surf"),"Fainted Surf partner cannot carry the player")
	a.data.party[0].hp=1
	a.c.check(not a.field.hm_eligible(a.new_mon(4,10),"surf"),"HM teaching enforces species compatibility")
	for tool in ["flash","rocksmash","waterfall"]:
		a.field.finish("field:"+tool); a.c.check(not a.field.can_use(tool),"Owned "+tool+" remains badge gated")
	a.data.badge=true; a.Finale.state(a)["marsh"]=true; a.Finale.state(a)["volcano"]=true
	for tool in ["flash","rocksmash","waterfall"]: a.c.check(a.field.can_use(tool),"Badge enables "+tool+" without learning an HM")
	a.field.finish("coin_case"); buy_coins(); a.clear_ui()
	a.c.check(state().coins==50,"Coin Case enables coin purchase")
	state().coins=180; prize_mon(63,180); a.clear_ui()
	a.c.check(state().coins==0 and a.data.party[-1].id==63,"Game Corner exchanges coins for an actual partner")
	money=a.data.money; start_safari()
	a.c.check(state().safari and state().safari_balls==30 and state().safari_steps==600 and a.data.money==money-500,"Safari admission charges once and grants bounded visit")
	start_safari(); a.c.check(a.data.money==money-500,"Active Safari cannot charge a duplicate admission")
	var party=a.data.party.duplicate(true)
	while a.data.party.size()<6: a.data.party.append(a.new_mon(16,5))
	for i in a.collection.STORAGE_CAPACITY: a.collection.store(a.new_mon(19,5))
	safari_encounter({"id":113,"level":25}); safari_action("ball")
	a.c.check(state().safari_balls==30 and not safari_mon.is_empty(),"Full storage preserves Safari Ball and encounter")
	a.data.party=party; a.data.storage=[]; safari_mon={}; a.clear_ui()
	state().safari_steps=1; steps()
	a.c.check(not state().safari and a.world.current=="MAP_FUCHSIA_CITY_SAFARI_ZONE_ENTRANCE","Safari step expiry returns safely to reception")
	a.c.check(valid(JSON.parse_string(JSON.stringify(a.data))),"Services survive a JSON save round trip")
	var corrupt=a.data.duplicate(true); corrupt.services.coins=-1; a.c.check(not valid(corrupt),"Invalid coin balances are rejected")
	a.c.check(not a.sevii.gate("MAP_FIVE_ISLAND_ROCKET_WAREHOUSE"),"Warehouse requires Sapphire quest")
	a.sevii.finish("sapphire_stolen"); a.c.check(not a.sevii.gate("MAP_FIVE_ISLAND_ROCKET_WAREHOUSE"),"Warehouse requires both passwords")
	a.sevii.finish("password_ruby"); a.c.check(a.sevii.gate("MAP_FIVE_ISLAND_ROCKET_WAREHOUSE"),"Warehouse opens with both quest passwords")
	a.sevii.result("sevii_sapphire",false); a.c.check(not a.sevii.done("sapphire"),"Lost Sevii battle does not award quest gem")
	a.sevii.result("sevii_sapphire",true); a.c.check(a.sevii.done("sapphire"),"Winning Gideon battle awards Sapphire")
	a.world.current="MAP_SEVEN_ISLAND_SEVAULT_CANYON_TANOBY_KEY"; a.world.events.refresh()
	var rocks=a.world.events.rocks(); var triggers=a.world.events.catalog[a.world.current].triggers
	a.sevii.boulder_puzzle(); a.c.check(not a.sevii.done("tanoby"),"Tanoby puzzle starts unsolved")
	for i in range(7): a.world.events.state().rocks[rocks[i].key]={"x":triggers[i].x,"y":triggers[i].y}
	a.sevii.boulder_puzzle(); a.c.check(a.sevii.done("tanoby"),"All seven Tanoby switches complete the boulder puzzle")
	a.world.scenes.finish()
	a.world.current="MAP_FOUR_ISLAND_ICEFALL_CAVE_1F"; a.world.events.refresh()
	var terrain=a.world.events.catalog[a.world.current].behavior; var ice=terrain.map(func(b):return int(b)).find(0x26)
	a.c.check(ice>=0,"Icefall Cave has original thin-ice tiles")
	if ice>=0:
		a.position_world=(Vector2(ice%int(a.world.room().width),int(ice/int(a.world.room().width)))+Vector2.ONE*0.5)*48
		a.sevii.on_step(); a.c.check(not a.world.scenes.active,"First thin-ice crossing cracks the tile")
		a.sevii.on_step(); a.c.check(a.world.scenes.active,"Second thin-ice crossing starts a fall scene")
		a.world.scenes.finish(); a.c.check(a.world.current=="MAP_FOUR_ISLAND_ICEFALL_CAVE_B1F","Broken ice drops to the matching lower floor")
	a.world.scenes.reset(); a.clear_ui(); safari_mon={}
	a.data=previous; a.world.current=map; a.world.events.refresh(); a.position_world=at
	a.save_allowed=saving; a.dialog=old_dialog; a.in_battle=old_battle; a.exploring=old_exploring
