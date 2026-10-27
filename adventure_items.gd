extends RefCounted
var a
const STONES={"moonstone":{30:31,33:34,35:36,39:40},"firestone":{37:38,58:59,133:136},"waterstone":{61:62,90:91,120:121,133:134},"thunderstone":{25:26,133:135},"leafstone":{44:45,70:71,102:103}}
const VITAMINS={"hpup":"hp","protein":"atk","iron":"def","calcium":"spa","zinc":"spd","carbos":"spe"}
const EV_BERRIES={"pomegberry":"hp","kelpsyberry":"atk","qualotberry":"def","hondewberry":"spa","grepaberry":"spd","tamatoberry":"spe"}
const XITEMS={"xattack":"atk","xdefend":"def","xspecial":"spa","xspeed":"spe","xaccuracy":"accuracy"}
const TREASURES={"nugget":5000,"bigpearl":3750,"pearl":700,"stardust":1000,"starpiece":4900}
const HELD=["blackglasses","quickclaw","cleansetag","silkscarf","laxincense","seaincense","metalcoat","nevermeltice","kingsrock","luckypunch","dragonscale"]
var catalog={
	"hyperpotion":{"name":"Hyper Potion / heal 80%","price":1200,"heal":0.8},
	"maxpotion":{"name":"Max Potion / full HP","price":2500,"heal":1.0},
	"fullrestore":{"name":"Full Restore / HP and status","price":3000},
	"maxrevive":{"name":"Max Revive / revive to full HP","price":0},
	"rarecandy":{"name":"Rare Candy / gain one level","price":0},
	"escaperope":{"name":"Escape Rope / leave cave","price":550},
	"repel":{"name":"Repel / 100 steps","price":350},
	"ether":{"name":"Ether / energy + recovery PP","price":0},
	"maxether":{"name":"Max Ether / full energy + recovery PP","price":0},
	"elixir":{"name":"Elixir / energy + recovery PP","price":0},
	"maxelixir":{"name":"Max Elixir / full energy + recovery PP","price":0},
	"ppup":{"name":"PP Up / extra recovery PP","price":0},
	"pokedoll":{"name":"Poke Doll / gift for Copycat to learn Mimic","price":1000},
	"maxrepel":{"name":"Max Repel / 250 steps","price":700},
	"direhit":{"name":"Dire Hit / critical boost for this battle","price":650},
	"upgrade":{"name":"Up-Grade / stored for Porygon trade evolution (species not yet in roster)","price":0},
	"sunstone":{"name":"Sun Stone / stored for later-generation evolutions","price":0},
	"guardspec":{"name":"Guard Spec. / team Mist 60s","price":700}
}

func _init():
	for id in EV_BERRIES: catalog[id]={"name":id.trim_suffix("berry").capitalize()+" Berry / -10 "+str(EV_BERRIES[id]).to_upper()+" EVs","price":200}
	for id in STONES: catalog[id]={"name":id.trim_suffix("stone").capitalize()+" Stone / evolve compatible Pokemon","price":2100 if id!="moonstone" else 0}
	for id in VITAMINS: catalog[id]={"name":id.capitalize()+" / permanent "+str(VITAMINS[id]).to_upper()+" training","price":9800}
	for id in XITEMS: catalog[id]={"name":id.capitalize()+" / battle stat boost","price":500}
	for id in TREASURES: catalog[id]={"name":id.capitalize()+" / sell for $"+str(TREASURES[id]),"price":0}
	for id in HELD: catalog[id]={"name":id.capitalize()+" / equip held item","price":0}

func valid(data) -> bool:
	var steps=data.get("repel_steps",0)
	if not (steps is float or steps is int) or steps!=int(steps) or steps<0 or steps>250: return false
	for mon in data.party+data.storage:
		if mon.has("held_item") and mon.held_item not in HELD+[""]: return false
		for field in ["training","ppups"]:
			if not mon.get(field,{}) is Dictionary: return false
			var total=0
			for key in mon.get(field,{}):
				var value=mon[field][key]
				if not (value is float or value is int) or value!=int(value) or value<0 or value>(252 if field=="training" else 3): return false
				if field=="training" and key not in VITAMINS.values(): return false
				if field=="ppups" and not a.inventory.book.moves.has(key): return false
				total+=int(value)
			if field=="training" and total>510: return false
	return true

func targets(id):
	if a.in_battle and (id in STONES or id in VITAMINS or id in EV_BERRIES or id in HELD or id in TREASURES or id in ["rarecandy","ppup","escaperope","repel","maxrepel","upgrade","sunstone"]):
		a.clear_ui(); a.c.notice="Use this item outside battle."; a.c.notice_time=2; return
	if id=="escaperope": a.field.escape(); return
	if id in ["repel","maxrepel"]:
		if int(a.data.bag.get(id,0))>0:
			a.data["repel_steps"]=250 if id=="maxrepel" else 100; consume(id); a.dialog="Repel active for "+str(a.data.repel_steps)+" steps."
		return
	if id in TREASURES:
		if int(a.data.bag.get(id,0))>0 and a.data.money<999999:
			a.data.money=mini(999999,int(a.data.money)+TREASURES[id]); consume(id); a.dialog="Sold for $"+str(TREASURES[id])+"."
		return
	var list=a.inventory.page(catalog[id].name+" / CHOOSE POKEMON")
	for i in range(a.data.party.size()):
		var mon=a.data.party[i]
		a.inventory.row(list,a.mon_name(mon.id)+" Lv."+str(mon.level)+(" / holding "+str(mon.held_item) if mon.get("held_item","")!="" else ""),pp_menu.bind(i) if id=="ppup" else use.bind(id,i))

func consume(id):
	a.data.bag[id]=int(a.data.bag[id])-1
	a.clear_ui(); a.save()

func unavailable() -> bool:
	a.clear_ui()
	if a.in_battle: a.c.notice="NO EFFECT / item kept"; a.c.notice_time=2
	else: a.dialog="It would have no effect. Item kept."
	return false

func use(id,slot) -> bool:
	if not catalog.has(id) or int(a.data.bag.get(id,0))<=0 or slot<0 or slot>=a.data.party.size(): return false
	if a.in_battle:
		if id in STONES or id in VITAMINS or id in EV_BERRIES or id in HELD or id=="rarecandy": return unavailable()
		if a.c.result!="" or a.c.countdown>0 or a.capture_time>0 or a.c.switch_time>=0 or a.c.player.get("action_lock",0)>0 or a.c.player.get("charge_left",0)>0: return false
		a.sync_health()
	var mon=a.data.party[slot]
	var fighter=a.c.player_states[slot] if a.in_battle else {}
	var success=false
	if id=="fullrestore" and mon.hp>0 and (mon.hp<1 or mon.ailment!=""):
		mon.hp=1.0; mon.ailment=""; success=true
	elif id=="maxrevive" and mon.hp<=0: mon.hp=1.0; success=true
	elif catalog[id].has("heal") and mon.hp>0 and mon.hp<1: mon.hp=minf(1,mon.hp+catalog[id].heal); success=true
	elif id in STONES and STONES[id].has(int(mon.id)):
		a.collection.register(mon)
		var old=int(mon.id); mon.id=STONES[id][old]; a.c.abilities.assign(mon)
		a.evolutions.append([old,int(mon.id),mon.get("shiny",false)])
		a.inventory.level_up(mon,old,int(mon.level)); success=true
	elif id=="rarecandy" and mon.level<100 and mon.hp>0:
		var party=a.data.party
		a.data.party=[mon]
		a.dialog=a.grant_xp(a.xp_needed(mon)-int(mon.xp))
		a.data.party=party; success=true
	elif id in EV_BERRIES:
		var training=mon.get("training",{}); var stat=EV_BERRIES[id]
		if int(training.get(stat,0))>0: training[stat]=maxi(0,int(training[stat])-10); mon["training"]=training; success=true
	elif id in VITAMINS:
		var training=mon.get("training",{}); var stat=VITAMINS[id]; var total=0
		for amount in training.values(): total+=int(amount)
		var increase=mini(10,mini(100-int(training.get(stat,0)),510-total))
		if increase>0: training[stat]=int(training.get(stat,0))+increase; mon["training"]=training; success=true
	elif id in HELD and mon.get("held_item","")!=id:
		var previous=str(mon.get("held_item",""))
		if previous!="" and int(a.data.bag.get(previous,0))>=999: return unavailable()
		if previous!="": a.data.bag[previous]=int(a.data.bag.get(previous,0))+1
		mon["held_item"]=id; success=true
	elif id in XITEMS and a.in_battle and slot==a.c.player_active and mon.hp>0:
		var stat=XITEMS[id]
		if int(fighter.stages.get(stat,0))<6: fighter.stages[stat]=mini(6,int(fighter.stages.get(stat,0))+1); success=true
	elif id=="direhit" and a.in_battle and slot==a.c.player_active and mon.hp>0:
		fighter["dire_hit"]=true; success=true
	elif id=="guardspec" and a.in_battle and mon.hp>0:
		a.c.support.side(a.c,a.c.player)["mist"]=60.0; success=true
	elif id in ["ether","maxether","elixir","maxelixir"] and a.in_battle and mon.hp>0:
		var full=id.begins_with("max")
		if fighter.energy<100: fighter.energy=minf(100,fighter.energy+(100 if full else 40)); success=true
		for move in fighter.data.moves:
			var limit=a.c.support.pp_limit(move)
			if limit>0 and a.c.support.pp(fighter,move)<limit:
				if not fighter.has("healing_pp"): fighter["healing_pp"]={}
				fighter.healing_pp[move.id]=limit if full else mini(limit,a.c.support.pp(fighter,move)+3); success=true
	if not success: return unavailable()
	if a.in_battle:
		fighter.hp=mon.hp*fighter.data.hp; fighter.ailment=mon.ailment
		if mon.ailment=="": fighter.ailment_time=0
		if mon.hp>0: fighter.fainted=false
		a.c.player.action_lock=1.0; a.c.notice="USED "+catalog[id].name; a.c.notice_time=2
	consume(id)
	if not a.in_battle and not a.evolutions.is_empty(): a.show_evolution()
	elif not a.in_battle and id!="rarecandy": a.dialog="Used "+catalog[id].name+" on "+a.mon_name(mon.id)+"."
	return true

func pp_menu(slot):
	var list=a.inventory.page("PP UP / RECOVERY MOVES")
	var mon=a.data.party[slot]
	for move in mon.moves:
		if a.inventory.book.moves[move].kind=="heal":
			a.inventory.row(list,a.inventory.book.moves[move].name+" / bonus "+str(mon.get("ppups",{}).get(move,0))+"/3",pp_up.bind(slot,move))
	a.inventory.row(list,"Arena attacks use energy. PP Up increases limited recovery PP.",func():pass,true)

func pp_up(slot,move):
	if a.in_battle or int(a.data.bag.get("ppup",0))<=0 or slot<0 or slot>=a.data.party.size(): return
	var mon=a.data.party[slot]
	if move not in mon.moves or a.inventory.book.moves[move].kind!="heal": return
	var ups=mon.get("ppups",{})
	if int(ups.get(move,0))>=3: unavailable(); return
	ups[move]=int(ups.get(move,0))+1; mon["ppups"]=ups; consume("ppup"); a.dialog="Recovery PP increased."

func tests():
	var arena_before={}
	for key in ["player_team","enemy_team","player_index","enemy_index","team_slot","team_mode","enemy_party","preview_party"]:
		var value=a.c.get(key)
		arena_before[key]=value.duplicate(true) if value is Array else value
	var previous=a.data.duplicate(true); var allowed=a.save_allowed; var battling=a.in_battle; var exploring=a.exploring; var dialog=a.dialog
	a.save_allowed=false; a.in_battle=false; a.exploring=true
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.party=[a.new_mon(4,15),a.new_mon(25,10)]; a.inventory.migrate()
	for id in catalog: a.data.bag[id]=5
	for area in a.world.events.catalog.values():
		for item in area.items:
			var id=str(item.item)
			a.c.check(id in ["POKE_BALL","GREAT_BALL","ULTRA_BALL","CARD_KEY","SECRET_KEY","LIFT_KEY","GOLD_TEETH","HM07"] or a.inventory.book.tms.has(id) or a.inventory.ITEMS.has(id.to_lower().replace("_","")),"Every current map pickup has a usable handler: "+id)
	var candy=a.data.bag.rarecandy
	a.c.check(use("rarecandy",0) and a.data.party[0].id==5 and a.data.party[0].level==16,"Rare Candy levels and evolves the chosen Pokemon")
	a.c.check(a.data.bag.rarecandy==candy-1 and a.data.party[1].level==10,"Rare Candy consumes once and leaves teammates unchanged")
	a.clear_ui(); a.evolutions.clear()
	a.c.check(use("thunderstone",1) and a.data.party[1].id==26,"Thunder Stone evolves Pikachu")
	a.clear_ui(); a.evolutions.clear()
	var stones=a.data.bag.thunderstone
	a.c.check(not use("thunderstone",0) and a.data.bag.thunderstone==stones,"Incompatible stone is retained")
	var before_stat=a.battle_mon(5,16,a.data.party[0]).base_stats.atk
	a.c.check(use("protein",0) and a.battle_mon(5,16,a.data.party[0]).base_stats.atk>before_stat,"Vitamin training changes real battle stats")
	a.data.party[0].training={"atk":100}; var vitamins=a.data.bag.protein
	a.c.check(not use("protein",0) and a.data.bag.protein==vitamins,"Vitamin per-stat cap does not consume an item")
	a.c.check(use("blackglasses",0) and a.data.party[0].held_item=="blackglasses","Held item equips")
	var glasses=a.data.bag.blackglasses
	a.c.check(use("quickclaw",0) and a.data.bag.blackglasses==glasses+1,"Replacing held item returns the previous one")
	a.data.party[0].hp=0; a.c.check(use("maxrevive",0) and a.data.party[0].hp==1,"Max Revive restores full health")
	a.data.party[0].ailment="burn"; a.c.check(use("fullrestore",0) and a.data.party[0].ailment=="","Full Restore cures even at full HP")
	a.data.party[0].moves=["recover"]; pp_up(0,"recover")
	a.c.check(a.c.support.pp_limit(a.inventory.definitions(["recover"],a.data.party[0])[0])==6,"PP Up increases the real recovery move limit")
	var money=a.data.money; targets("nugget")
	a.c.check(a.data.money==money+5000,"Treasure can be sold")
	targets("repel"); a.c.check(a.data.repel_steps==100,"Repel starts its step counter")
	a.c.check(valid(JSON.parse_string(JSON.stringify(a.data))),"Training, held items, PP boosts and repel survive JSON round trip")
	a.begin_battle("wild",[19],[5]); a.c.countdown=0; a.c.player.action_lock=0
	a.c.player.energy=20; a.c.player["healing_pp"]={"recover":0}
	a.c.check(use("ether",0) and a.c.player.energy==60 and a.c.player.healing_pp.recover==3,"Ether restores live energy and recovery PP")
	a.c.check(not use("xattack",0),"Battle items respect shared action gate")
	a.c.player.action_lock=0
	a.c.check(use("xattack",0) and a.c.player.stages.get("atk",0)==1,"X Attack raises active Pokemon stage")
	a.c.player.action_lock=0
	a.c.check(use("guardspec",0) and a.c.support.side(a.c,a.c.player).get("mist",0)==60,"Guard Spec creates actual stat-drop protection")
	a.c.support.reset()
	for key in arena_before: a.c.set(key,arena_before[key])
	a.c.reset()

	a.clear_ui(); a.evolutions.clear(); a.data=previous; a.save_allowed=allowed; a.in_battle=battling; a.exploring=exploring; a.dialog=dialog
