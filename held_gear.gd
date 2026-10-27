extends RefCounted
const POWER={"powerweight":"hp","powerbracer":"atk","powerbelt":"def","powerlens":"spa","powerband":"spd","poweranklet":"spe"}
const CHOICE=["choiceband","choicespecs","choicescarf"]
const ITEMS=["leftovers","sitrusberry","lumberry","choiceband","choicespecs","choicescarf","machobrace","powerweight","powerbracer","powerbelt","powerlens","powerband","poweranklet"]
const DESCRIPTIONS={"leftovers":"Leftovers / heal 1/16 HP every 5 combat seconds","sitrusberry":"Sitrus Berry / heal 25% at half HP, consumed","lumberry":"Lum Berry / cure status and confusion, consumed","choiceband":"Choice Band / 1.5x Attack, locks one move until switching","choicespecs":"Choice Specs / 1.5x Sp. Atk, locks one move until switching","choicescarf":"Choice Scarf / 1.5x movement speed, locks one move until switching","machobrace":"Macho Brace / double earned EVs, half movement speed","powerweight":"Power Weight / +8 HP EVs, half movement speed","powerbracer":"Power Bracer / +8 ATK EVs, half movement speed","powerbelt":"Power Belt / +8 DEF EVs, half movement speed","powerlens":"Power Lens / +8 SPA EVs, half movement speed","powerband":"Power Band / +8 SPD EVs, half movement speed","poweranklet":"Power Anklet / +8 SPE EVs, half movement speed"}
var c
var choices={}
func install():
	if OS.get_cmdline_user_args().is_empty() and FileAccess.file_exists("user://battle-gear.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string("user://battle-gear.json"))
		if saved is Dictionary:
			for key in saved:
				if saved[key] in c.adventure.extras.HELD+[""]: choices[key]=saved[key]
func choose(key,id):
	choices[key]=id
	if OS.get_cmdline_user_args().is_empty():
		var file=FileAccess.open("user://battle-gear.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(choices))

func held(f): return str(f.data.get("held_item",""))
func speed(f) -> float:
	var item=held(f)
	return 1.5 if item=="choicescarf" else 0.5 if item in POWER or item=="machobrace" else 1.0
func attack(f,physical) -> float: return 1.5 if held(f)==("choiceband" if physical else "choicespecs") else 1.0
func allowed(f,id) -> bool: return held(f) not in CHOICE or f.get("choice_move",id)==id
func lock(f,id):
	if held(f) in CHOICE: f["choice_move"]=id
func withdrawn(f):
	f.erase("choice_move"); f["item_clock"]=0.0
func consume(f):
	f.data["held_item"]=""
	if c.adventure.in_battle:
		var slot=c.player_states.find(f)
		if slot>=0 and slot<c.adventure.data.party.size(): c.adventure.data.party[slot]["held_item"]=""
func tick(f,other,dt):
	if f.hp<=0: return
	var item=held(f)
	if item=="leftovers":
		f["item_clock"]=float(f.get("item_clock",0))+dt
		if f.item_clock>=5:
			f.item_clock=fmod(f.item_clock,5)
			if f.hp<f.data.hp: f.hp=minf(f.data.hp,f.hp+f.data.hp/16.0); c.Conditions.note(f,"LEFTOVERS +HP")
	if item in ["sitrusberry","lumberry"] and c.abilities.name_of(other)=="Unnerve": return
	if item=="sitrusberry" and f.hp<=f.data.hp*0.5:
		f.hp=minf(f.data.hp,f.hp+f.data.hp*0.25); consume(f); c.Conditions.note(f,"SITRUS BERRY +HP")
	elif item=="lumberry" and (f.ailment!="" or f.volatile.get("confusion",0)>0):
		f.ailment=""; f.ailment_time=0; f.volatile.erase("confusion"); consume(f); c.Conditions.note(f,"LUM BERRY / CURED")
func ev_yield(mon,base) -> Dictionary:
	var result=base.duplicate(true); var item=str(mon.get("held_item",""))
	if item in POWER: result[POWER[item]]=int(result.get(POWER[item],0))+8
	elif item=="machobrace":
		for stat in result: result[stat]=int(result[stat])*2
	return result

func tests():
	var battle=c.adventure.in_battle; c.adventure.in_battle=false
	c.pick(25,7); c.player.data["held_item"]="choiceband"
	lock(c.player,"tackle"); c.check(not allowed(c.player,"growl") and allowed(c.player,"tackle"),"Choice item locks only the selected move")
	var replacement=c.replacement(true,c.Dex.find_id(c.roster,7))
	c.check(not replacement.has("choice_move"),"Fresh replacement never inherits previous Pokemon Choice lock")
	withdrawn(c.player); c.check(allowed(c.player,"growl"),"Switch clears Choice lock")
	c.check(attack(c.player,true)==1.5 and attack(c.player,false)==1,"Choice Band only boosts physical Attack")
	c.player.data.held_item="sitrusberry"; c.player.hp=c.player.data.hp*0.4
	tick(c.player,c.enemy,0.1); var hp=c.player.hp; tick(c.player,c.enemy,0.1)
	c.check(is_equal_approx(hp,c.player.data.hp*0.65) and c.player.hp==hp and held(c.player)=="","Sitrus heals once and is consumed")
	c.player.data.held_item="lumberry"; c.player.ailment="sleep"; tick(c.player,c.enemy,0.1)
	c.check(c.player.ailment=="" and held(c.player)=="","Lum removes status and is consumed")
	c.player.data.held_item="leftovers"; c.player.hp=c.player.data.hp*0.5; tick(c.player,c.enemy,4.9)
	c.check(c.player.hp==c.player.data.hp*0.5,"Leftovers waits five combat seconds")
	tick(c.player,c.enemy,0.1); c.check(is_equal_approx(c.player.hp,c.player.data.hp*0.5625),"Leftovers heals one sixteenth per five seconds")
	c.check(ev_yield({"held_item":"powerbracer"},{"spe":1}).atk==8,"Power item adds eight targeted EVs")
	c.check(ev_yield({"held_item":"machobrace"},{"spe":1}).spe==2,"Macho Brace doubles base EV yield")
	c.adventure.in_battle=battle
