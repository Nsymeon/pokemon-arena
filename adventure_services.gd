extends RefCounted
# Optional activities use a separate, validated save block.
var a
var safari_mon={}
var catch_factor=0
var bait=0
var angry=0
var message=""
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
	if "DaycareMan" in script or "DaycareWoman" in script: daycare_menu(); return true
	if "CoinCaseMan" in script: a.field.reward("coin_case","Received COIN CASE! Use the Game Corner's machines and prize counters."); return true
	if script.begins_with("CeladonCity_GameCorner_") and not "RocketGrunt" in script: game_menu(); return true
	if "SAFARI_ZONE_ENTRANCE" in a.world.current: safari_menu(); return true
	return false

func steps():
	var s=state(); s.steps=mini(1000000000,int(s.steps)+1)
	if not s.daycare.is_empty():
		var mon=s.daycare.mon
		if mon.level<100:
			mon.xp+=1
			if mon.xp>=a.xp_needed(mon):
				mon.xp-=a.xp_needed(mon); mon.level+=1
				# Preserve chosen moves; new moves wait for the player's decision.
				for entry in a.inventory.book.species[str(int(mon.id))].levels:
					if int(entry.level)==int(mon.level) and entry.move not in mon.moves and entry.move not in mon.pending: mon.pending.append(entry.move)
	if s.safari and a.world.current.begins_with("MAP_SAFARI_ZONE"):
		s.safari_steps=maxi(0,int(s.safari_steps)-1)
		if s.safari_steps==0: end_safari("Time is up! Your Safari visit has ended.")

func daycare_menu():
	var s=state(); var list=a.inventory.page("DAY CARE / one partner / 1 EXP per walking tile")
	if s.daycare.is_empty():
		a.inventory.row(list,"Retrieval costs $100 + $100 per level gained. No automatic evolution or move replacement.",func():pass,true)
		for i in range(a.data.party.size()): a.inventory.row(list,"LEAVE "+a.mon_name(a.data.party[i].id)+" Lv."+str(a.data.party[i].level),deposit.bind(i),a.data.party.size()<2 or a.data.party[i].hp<=0)
	else:
		var mon=s.daycare.mon
		a.inventory.row(list,a.mon_name(mon.id)+" Lv."+str(mon.level)+" / RETRIEVE $"+str(fee()),withdraw,a.data.party.size()>=6 or a.data.money<fee())

func deposit(slot):
	if a.in_battle or not state().daycare.is_empty() or slot<0 or slot>=a.data.party.size() or a.data.party.size()<2: return
	if a.data.party[slot].hp<=0 or a.data.party.filter(func(m):return m.hp>0).size()<2: a.dialog="Keep a healthy partner with you."; return
	state().daycare={"mon":a.data.party[slot],"start_level":a.data.party[slot].level,"deposited":state().steps}
	a.data.party.remove_at(slot); a.save(); daycare_menu()

func fee() -> int:
	if state().daycare.is_empty(): return 0
	return 100+100*maxi(0,int(state().daycare.mon.level)-int(state().daycare.start_level))

func withdraw():
	if a.in_battle or state().daycare.is_empty() or a.data.party.size()>=6 or a.data.money<fee(): return
	a.data.money-=fee(); a.data.party.append(state().daycare.mon); state().daycare={}; a.save(); daycare_menu()

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
	catch_factor=int(int(rates.get(str(int(mon.id)),{"catch":45})["catch"])*100/1275)
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
	if action=="run": safari_mon={}; a.clear_ui(); return
	if action=="ball":
		if a.data.party.size()>=6 and a.data.storage.size()>=100: message="Party and storage are full. Make room before catching."; safari_panel(); return
		state().safari_balls-=1
		# Full HP, Safari Ball 1.5x, no status bonus. Four shakes resolve to a/255.
		var chance=floor(float(catch_factor*1275/100)*1.5)/765.0
		if randf()<chance:
			var name=a.mon_name(safari_mon.id)
			if a.data.party.size()<6: a.data.party.append(safari_mon)
			else: a.data.storage.append(safari_mon)
			a.field.finish("seen:"+str(int(safari_mon.id))); safari_mon={}; a.clear_ui(); a.dialog="Caught "+name+"!"; a.save()
			if state().safari_balls==0: end_safari("Last Safari Ball used. "+name+" was caught!")
			return
		message="It broke free!"
	elif action=="bait": catch_factor=maxi(3,catch_factor/2); bait=mini(6,bait+randi_range(2,6)); angry=0; message="The Pokemon is eating. Catching is harder, but fleeing is less likely."
	elif action=="rock": catch_factor=mini(20,catch_factor*2); angry=mini(6,angry+randi_range(2,6)); bait=0; message="The Pokemon is angry. Catching is easier, but fleeing is more likely."
	var flee=maxi(2,int(int(rates.get(str(int(safari_mon.id)),{"flee":50}).flee)*100/1275))*5
	if angry>0: flee*=2; angry-=1
	elif bait>0: flee=maxi(5,flee/4); bait-=1
	if state().safari_balls<=0: end_safari("Out of Safari Balls!"); return
	if randi_range(0,99)<flee: safari_mon={}; a.clear_ui(); a.dialog="The wild Pokemon fled."; a.save(); return
	a.save(); safari_panel()

func game_menu():
	var list=a.inventory.page("GAME CORNER / "+str(state().coins)+" COINS")
	if not a.field.done("coin_case"):
		a.inventory.row(list,"Get the Coin Case from the man at Celadon's restaurant.",func():pass,true); return
	a.inventory.row(list,"BUY 50 COINS / $1000",buy_coins,a.data.money<1000 or state().coins>9949)
	a.inventory.row(list,"PLAY SLOTS / 3 COINS / three matching symbols pay 24",spin,state().coins<3)
	for prize in [[63,180],[35,500],[123,5500],[147,2800],[137,9999]]: a.inventory.row(list,a.mon_name(prize[0])+" / "+str(prize[1])+" COINS",prize_mon.bind(prize[0],prize[1]),state().coins<prize[1])
	for prize in [["TM13",4000],["TM24",4000],["TM35",4000],["TM23",3500],["TM30",4500]]: a.inventory.row(list,a.inventory.book.tms[prize[0]].name+" / "+str(prize[1])+" COINS",prize_tm.bind(prize[0],prize[1]),state().coins<prize[1])

func buy_coins():
	if a.in_battle or not a.field.done("coin_case") or a.data.money<1000 or state().coins>9949: return
	a.data.money-=1000; state().coins+=50; a.save(); game_menu()

func spin():
	if a.in_battle or not a.field.done("coin_case") or state().coins<3: return
	state().coins-=3
	var symbols=["PIKACHU","STARYU","PSYDUCK"]; var reels=[randi_range(0,2),randi_range(0,2),randi_range(0,2)]
	var won=reels[0]==reels[1] and reels[1]==reels[2]
	if won: state().coins=mini(9999,int(state().coins)+24)
	a.save(); a.clear_ui()
	a.world.scenes.play([{"text":"The reels spin...","duration":0.8},{"text":symbols[reels[0]]+" / "+symbols[reels[1]]+" / "+symbols[reels[2]]+(" -- WON 24 COINS!" if won else " -- Try again!"),"duration":1.5}],game_menu)

func prize_mon(id,cost):
	if a.in_battle or not a.field.done("coin_case") or state().coins<cost: return
	if a.data.party.size()>=6 and a.data.storage.size()>=100: a.dialog="Make room in your party or storage first."; return
	state().coins-=cost
	var mon=a.new_mon(id,{63:9,35:8,123:25,147:18,137:26}[id])
	if a.data.party.size()<6: a.data.party.append(mon)
	else: a.data.storage.append(mon)
	a.save(); game_menu()

func prize_tm(id,cost):
	if a.in_battle or not a.field.done("coin_case") or state().coins<cost or int(a.data.tms.get(id,0))>=999: return
	state().coins-=cost; a.data.tms[id]=int(a.data.tms.get(id,0))+1; a.save(); game_menu()

func tests():
	var previous=a.data.duplicate(true); var saving=a.save_allowed; var map=a.world.current; var at=a.position_world
	var old_dialog=a.dialog; var old_battle=a.in_battle; var old_exploring=a.exploring
	a.save_allowed=false; a.in_battle=false; a.exploring=true
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.party=[a.new_mon(4,10),a.new_mon(7,10)]; a.inventory.migrate()
	a.data.money=20000; a.world.current="MAP_ROUTE5_POKEMON_DAY_CARE"
	deposit(1); a.clear_ui()
	a.c.check(a.data.party.size()==1 and state().daycare.mon.id==7,"Day Care transfers the exact partner out of the party")
	var mon=state().daycare.mon; mon.xp=a.xp_needed(mon)-1
	steps(); a.c.check(mon.level==11 and fee()==200,"Day Care steps grant EXP and calculate the retrieval fee")
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
	for i in range(100): a.data.storage.append(a.new_mon(19,5))
	safari_encounter({"id":113,"level":25}); safari_action("ball")
	a.c.check(state().safari_balls==30 and not safari_mon.is_empty(),"Full storage preserves Safari Ball and encounter")
	a.data.party=party; a.data.storage=[]; safari_mon={}; a.clear_ui()
	state().safari_steps=1; steps()
	a.c.check(not state().safari and a.world.current=="MAP_FUCHSIA_CITY_SAFARI_ZONE_ENTRANCE","Safari step expiry returns safely to reception")
	a.c.check(valid(JSON.parse_string(JSON.stringify(a.data))),"Services survive a JSON save round trip")
	var corrupt=a.data.duplicate(true); corrupt.services.coins=-1; a.c.check(not valid(corrupt),"Invalid coin balances are rejected")
	a.c.check(not a.sevii.gate("MAP_FIVE_ISLAND_ROCKET_WAREHOUSE"),"Warehouse requires Sapphire quest")
	a.sevii.finish("sapphire_stolen"); a.c.check(a.sevii.gate("MAP_FIVE_ISLAND_ROCKET_WAREHOUSE"),"Warehouse opens with quest password")
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
