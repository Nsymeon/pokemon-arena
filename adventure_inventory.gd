extends RefCounted

var a
var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/adventure-learnsets.json"))
var ITEMS = {
	"potion":{"name":"Potion / heal 20%","price":100,"heal":0.2},
	"superpotion":{"name":"Super Potion / heal 50%","price":300,"heal":0.5},
	"antidote":{"name":"Antidote / poison","price":100,"cure":["poison","toxic"]},
	"paralyzeheal":{"name":"Paralyze Heal","price":100,"cure":["paralysis"]},
	"awakening":{"name":"Awakening","price":100,"cure":["sleep"]},
	"burnheal":{"name":"Burn Heal","price":100,"cure":["burn"]},
	"iceheal":{"name":"Ice Heal","price":100,"cure":["freeze"]},
	"fullheal":{"name":"Full Heal / all status","price":400,"cure":["poison","toxic","paralysis","sleep","burn","freeze"]},
	"revive":{"name":"Revive / fainted to 50%","price":600,"revive":true}
}
const SHOP_TMS = {"TM09":1000,"TM17":1200,"TM40":1500}

func install(adventure):
	a = adventure
	ITEMS.merge(a.extras.catalog)

func eligible(id, level) -> Array:
	var result: Array = []
	for entry in book.species[str(id)].levels:
		if int(entry.level)<=level and entry.move not in result: result.append(entry.move)
	return result

func starting(id, level) -> Array:
	var list = eligible(id,level)
	return list.slice(maxi(0,list.size()-4))

func migrate():
	a.c.ivs.migrate(a.data)
	a.collection.sync()
	if not a.data.has("bag"): a.data.bag = {"potion":5,"antidote":2,"paralyzeheal":1}
	if not a.data.has("tms"): a.data.tms = {}
	for field in ["bag","tms"]:
		for id in a.data[field]: a.data[field][id] = int(a.data[field][id])
	if not a.data.has("brock_tm"):
		a.data.brock_tm = false
		if a.data.badge: award_brock()
	for mon in a.data.party+a.data.storage:
		a.c.abilities.assign(mon)
		if not mon.has("moves"): mon.moves = starting(int(mon.id),int(mon.level))
		if not mon.has("pending"): mon.pending = []
		if not mon.has("ailment"): mon.ailment = ""

func valid(value) -> bool:
	for field in ["bag","tms"]:
		if not value.has(field): continue
		if not value[field] is Dictionary: return false
		for id in value[field]:
			if not (ITEMS.has(id) if field=="bag" else book.tms.has(id)): return false
			var amount = value[field][id]
			if not (amount is int or amount is float) or amount!=int(amount) or amount<0 or amount>999: return false
	if value.has("brock_tm") and not value.brock_tm is bool: return false
	for mon in value.party+value.storage:
		for field in ["moves","pending"]:
			if not mon.has(field): continue
			if not mon[field] is Array or mon[field].size()>(4 if field=="moves" else 305): return false
			if field=="moves" and mon[field].is_empty(): return false
			var seen = []
			for id in mon[field]:
				if not id is String or not book.moves.has(id) or id in seen: return false
				seen.append(id)
		if mon.get("ailment","") not in ["","poison","toxic","paralysis","sleep","burn","freeze"]: return false
	return true

func definitions(ids: Array, mon: Dictionary={}) -> Array:
	var result=[]
	for id in ids:
		var move=book.moves[id].duplicate(true)
		if move.kind=="heal": move["healing_pp_max"]=5+int(mon.get("ppups",{}).get(id,0))
		result.append(move)
	return result

func level_up(mon, old_id, level):
	for id in [old_id,int(mon.id)]:
		for entry in book.species[str(id)].levels:
			if int(entry.level)!=level: continue
			if entry.move in mon.moves or entry.move in mon.pending: continue
			if mon.moves.size()<4: mon.moves.append(entry.move)
			else: mon.pending.append(entry.move)

func award_brock():
	if a.data.get("brock_tm",false): return
	a.data.brock_tm = true
	a.data.tms["TM39"] = int(a.data.tms.get("TM39",0))+1

func page(title):
	a.panel(title)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(180,230)
	scroll.size = Vector2(910,500)
	a.ui.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list

func row(list, title, callback: Callable, disabled = false):
	var b = Button.new()
	b.text = title
	b.custom_minimum_size = Vector2(875,48)
	b.disabled = disabled
	b.add_theme_color_override("font_disabled_color",Color("b9c9d1"))
	b.pressed.connect(callback)
	list.add_child(b)

func bag():
	migrate()
	var list = page("BAG / $%d / Poke Balls x%d" % [a.data.money,a.data.balls])
	row(list,"POKE BALL / use G during a wild battle",func():pass,true)
	for id in ITEMS:
		var count = int(a.data.bag.get(id,0))
		if count>0 or not a.extras.catalog.has(id): row(list,ITEMS[id].name+"  x"+str(count),targets.bind(id),count<=0)
	row(list,"KEY ITEMS / tools, badges, teach Fly and Surf",a.field.key_items,a.in_battle)
	row(list,"FIELD TOOLS / bicycle, Fly, Flash, Dig, Teleport",a.field.tools_menu,a.in_battle)
	row(list,"TM CASE",tm_case, a.in_battle)
	row(list,a.Story.keys(a),func():pass,true)
	for key in a.Finale.keys(a): row(list,"KEY ITEM / "+key,func():pass,true)

func targets(id):
	if a.extras.catalog.has(id): a.extras.targets(id); return
	var list = page(ITEMS[id].name+" / CHOOSE POKEMON")
	if a.in_battle: a.sync_health()
	for i in range(a.data.party.size()):
		var mon = a.data.party[i]
		row(list,"%s / HP %d%% / %s" % [a.mon_name(mon.id),roundi(mon.hp*100),mon.get("ailment","")],use_item.bind(id,i))

func use_item(id,slot) -> bool:
	if a.extras.catalog.has(id): return a.extras.use(id,slot)
	if not ITEMS.has(id) or slot<0 or slot>=a.data.party.size() or int(a.data.bag.get(id,0))<=0: return false
	if a.in_battle:
		if a.c.result!="" or a.c.countdown>0 or a.capture_time>0 or a.c.switch_time>=0 or a.c.player.get("action_lock",0)>0 or a.c.player.get("charge_left",0)>0: return false
		a.sync_health()
	var mon = a.data.party[slot]
	var item = ITEMS[id]
	var changed = false
	if item.has("heal") and mon.hp>0 and mon.hp<1:
		mon.hp = minf(1,mon.hp+item.heal)
		changed = true
	elif item.has("revive") and mon.hp<=0:
		mon.hp = 0.5
		changed = true
	elif mon.hp>0 and item.has("cure") and mon.get("ailment","") in item.cure:
		mon.ailment = ""
		changed = true
	if not changed:
		a.clear_ui()
		if a.exploring: a.dialog = "It would have no effect. Item kept."
		else:
			a.c.notice = "NO EFFECT / item kept"
			a.c.notice_time = 2
		return false
	a.data.bag[id] = int(a.data.bag[id])-1
	if a.in_battle:
		var fighter = a.c.player_states[slot]
		fighter.hp = fighter.data.hp*mon.hp
		fighter.ailment = mon.ailment
		if mon.ailment=="": fighter.ailment_time = 0
		if item.has("revive"): fighter.fainted = false
		a.c.player.action_lock = 1.0
		a.c.notice = "USED "+item.name
		a.c.notice_time = 2
	a.save()
	a.clear_ui()
	return true

func shop():
	var list = page("POKE MART / $%d" % a.data.money)
	row(list,"5 Poke Balls / $100",buy.bind("balls",100),a.data.money<100 or a.data.balls>994)
	for id in ITEMS:
		if int(ITEMS[id].price)<=0: continue
		row(list,ITEMS[id].name+" / $"+str(ITEMS[id].price),buy.bind(id,ITEMS[id].price),a.data.money<ITEMS[id].price)
	for id in SHOP_TMS:
		row(list,book.tms[id].name+" / $"+str(SHOP_TMS[id]),buy.bind(id,SHOP_TMS[id]),a.data.money<SHOP_TMS[id])

func buy(id,price):
	if a.data.money<price: return
	if id=="balls":
		if a.data.balls>994: return
		a.data.balls+=5
	elif ITEMS.has(id):
		if int(a.data.bag.get(id,0))>=999: return
		a.data.bag[id]=int(a.data.bag.get(id,0))+1
	elif SHOP_TMS.has(id):
		if int(a.data.tms.get(id,0))>=999: return
		a.data.tms[id]=int(a.data.tms.get(id,0))+1
	else: return
	a.data.money-=price
	a.save()
	shop()

func tm_case():
	var list = page("TM CASE / single-use / choose a machine")
	for id in a.data.tms:
		if int(a.data.tms[id])>0: row(list,book.tms[id].name+" x"+str(a.data.tms[id]),tm_targets.bind(id))
	row(list,"Brock awards TM39 Rock Tomb once. More TMs at the Mart.",func():pass,true)

func tm_targets(tm):
	var list = page(book.tms[tm].name+" / CHOOSE POKEMON")
	for i in range(a.data.party.size()):
		var mon = a.data.party[i]
		var compatible = tm in book.species[str(mon.id)].tms and book.tms[tm].move not in mon.moves
		row(list,a.mon_name(mon.id)+(" / CAN LEARN" if compatible else " / INCOMPATIBLE OR ALREADY KNOWN"),replace_menu.bind(i,book.tms[tm].move,tm),not compatible)

func move_party():
	var list = page("MOVESETS / choose a Pokemon")
	for i in range(a.data.party.size()):
		var mon = a.data.party[i]
		row(list,a.mon_name(mon.id)+" Lv."+str(mon.level)+" / "+str(mon.pending.size())+" waiting",moves_menu.bind(i))

func moves_menu(slot):
	var mon = a.data.party[slot]
	var list = page(a.mon_name(mon.id)+" / MOVES / level "+str(mon.level))
	row(list,a.c.ivs.summary(mon),func():pass,true)
	row(list,a.c.ivs.ev_summary(mon),func():pass,true)
	for move in ["fly","surf"]:
		if a.field.hm_eligible(mon,move) and move not in mon.moves: row(list,"HM / "+move.to_upper(),replace_menu.bind(slot,move,""))
	for id in mon.moves: row(list,"KNOWN / "+book.moves[id].name+" / "+book.moves[id].type,func():pass,true)
	for id in mon.pending:
		if id not in mon.moves: row(list,"NEW / "+book.moves[id].name,replace_menu.bind(slot,id,""))
	for id in eligible(mon.id,mon.level):
		if id not in mon.moves and id not in mon.pending: row(list,"RELEARN / "+book.moves[id].name,replace_menu.bind(slot,id,""))
	for entry in book.species[str(mon.id)].levels:
		if int(entry.level)>mon.level: row(list,"Lv.%d / %s" % [entry.level,book.moves[entry.move].name],func():pass,true)

func replace_menu(slot,id,tm):
	var mon = a.data.party[slot]
	var list = page("LEARN "+book.moves[id].name+" / choose a slot")
	for i in range(mon.moves.size()): row(list,"REPLACE "+book.moves[mon.moves[i]].name,teach.bind(slot,id,i,tm))
	if mon.moves.size()<4: row(list,"USE EMPTY SLOT",teach.bind(slot,id,mon.moves.size(),tm))
	row(list,"CANCEL / keep moves and TM",move_party if tm=="" else tm_case)

func teach(slot,id,index,tm="") -> bool:
	if a.in_battle or slot<0 or slot>=a.data.party.size() or not book.moves.has(id): return false
	var mon = a.data.party[slot]
	if id in mon.moves or index<0 or index>mon.moves.size() or index>=4: return false
	if tm!="":
		if not book.tms.has(tm) or int(a.data.tms.get(tm,0))<=0 or tm not in book.species[str(mon.id)].tms or book.tms[tm].move!=id: return false
	elif id not in eligible(mon.id,mon.level) and id not in mon.pending and not a.field.hm_eligible(mon,id): return false
	var candidate=mon.duplicate(true)
	if index==candidate.moves.size(): candidate.moves.append(id)
	else: candidate.moves[index]=id
	if a.field.losing_surf(slot,candidate): a.clear_ui(); return false
	if index==mon.moves.size(): mon.moves.append(id)
	else: mon.moves[index]=id
	mon.pending.erase(id)
	if tm!="": a.data.tms[tm]=int(a.data.tms[tm])-1
	a.save()
	moves_menu(slot)
	return true

func tests():
	var snapshot = a.data.duplicate(true)
	var old_mon = {"id":4,"level":5,"xp":0,"hp":0.7}
	a.data.party = [old_mon]
	a.data.erase("bag")
	a.data.erase("tms")
	migrate()
	a.c.check(old_mon.moves==["scratch","growl"] and old_mon.hp==0.7,"Old adventure save migrates without losing health or level")
	a.c.check("ember" not in starting(4,5) and "ember" in starting(4,7),"Charmander learns Ember at FireRed level 7")
	a.c.check("metalclaw" in eligible(4,13) and "metalclaw" not in eligible(4,12),"FireRed Metal Claw level 13")
	for id in book.species:
		for level in [5,10,20,50,100]:
			var moves = starting(int(id),level)
			a.c.check(moves.size()>0 and moves.size()<=4 and moves.all(func(move):return book.moves.has(move)),"Valid bounded level moves for species "+id)
	old_mon.moves = ["scratch","growl","ember","smokescreen"]
	old_mon.level = 13
	level_up(old_mon,4,13)
	a.c.check(old_mon.moves.size()==4 and "metalclaw" in old_mon.pending,"Full moveset queues a new move without deleting one")
	a.c.check(teach(0,"metalclaw",1) and old_mon.moves[1]=="metalclaw","Player chooses which move to replace")
	a.clear_ui()
	a.data.tms = {"TM39":1}
	a.data.party = [a.new_mon(10,5),a.new_mon(74,13)]
	a.c.check(not teach(0,"rocktomb",0,"TM39") and a.data.tms.TM39==1,"Incompatible TM does not consume item")
	a.c.check(teach(1,"rocktomb",0,"TM39") and a.data.tms.TM39==0,"Compatible TM teaches and consumes once")
	a.clear_ui()
	a.c.check(not teach(1,"rocktomb",1,"TM39"),"Cannot duplicate known TM move")
	a.data.brock_tm = false
	award_brock()
	var count = a.data.tms.TM39
	award_brock()
	a.c.check(a.data.tms.TM39==count,"Brock TM reward cannot be farmed")
	a.data.bag = {"potion":2,"antidote":1,"revive":1}
	a.c.check(not use_item("potion",0) and a.data.bag.potion==2,"Full-health potion is not consumed")
	a.data.party[0].hp = 0
	a.c.check(not use_item("potion",0) and a.data.bag.potion==2,"Potion cannot revive")
	a.c.check(use_item("revive",0) and a.data.party[0].hp==0.5,"Revive restores fainted Pokemon")
	a.data.party[0].ailment = "poison"
	a.c.check(use_item("antidote",0) and a.data.party[0].ailment=="","Antidote cures saved status")
	a.c.check(use_item("potion",0) and is_equal_approx(a.data.party[0].hp,0.7),"Potion heals correct percentage")
	var expected = a.data.duplicate(true)
	a.save()
	a.data.tms = {}
	a.load_save()
	a.c.check(a.data.party[1].moves==expected.party[1].moves and a.data.bag==expected.bag and a.data.tms==expected.tms,"Moves, TMs and Bag survive JSON round trip")
	a.begin_battle("wild",[16],[4])
	a.c.countdown = 0
	a.c.player.action_lock = 0
	a.c.player.hp = a.c.player.data.hp*0.4
	a.data.bag.potion = 1
	a.c.check(use_item("potion",0) and a.c.player.action_lock==1 and is_equal_approx(a.c.player.hp/a.c.player.data.hp,0.6),"Battle item updates live fighter and spends action gate")
	a.c.player.pos = Vector2(500,500)
	a.c.enemy.pos = Vector2(600,500)
	a.c.enemy.data.types = ["Normal"]
	a.c.player.hp = a.c.player.data.hp*0.5
	a.c.execute_move(a.c.player,a.c.enemy,book.moves.leechseed,Vector2.RIGHT,true)
	var before = a.c.player.hp
	a.c.enemy.volatile.leechseed = 8
	a.c.enemy.seed_tick = 0
	a.c.update_battle(0.01)
	a.c.check(a.c.player.hp>before,"Leech Seed drains and heals its user")
	a.c.enemy.hp = 0
	a.c.finish_round()
	a.c.shots.clear()
	a.c.result_time = 10
	a.return_world()
	a.data = snapshot
	a.clear_ui()
	a.dialog = ""
	a.save()

