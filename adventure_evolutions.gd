extends RefCounted
var book: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/evolutions.json"))
var a

func level_target(mon) -> int:
	if mon.get("held_item","")=="everstone": return 0
	for rule in book.get(str(int(mon.id)),[]):
		if rule.target>151 and not a.progression.national(): continue
		var method=str(rule.method); var p=int(rule.param) if rule.param is float or rule.param is int else 0
		var friendship=int(mon.get("friendship",70))
		var day=Time.get_datetime_dict_from_system().hour in range(6,18)
		if method=="LEVEL" and mon.level>=p: return int(rule.target)
		if method.begins_with("FRIENDSHIP") and friendship>=220 and (method=="FRIENDSHIP" or day and method=="FRIENDSHIP_DAY" or not day and method=="FRIENDSHIP_NIGHT"): return int(rule.target)
		if method in ["LEVEL_ATK_GT_DEF","LEVEL_ATK_EQ_DEF","LEVEL_ATK_LT_DEF"] and mon.level>=p:
			var stats=a.battle_mon(mon.id,mon.level,mon).base_stats
			if (method=="LEVEL_ATK_GT_DEF" and stats.atk>stats.def) or (method=="LEVEL_ATK_EQ_DEF" and stats.atk==stats.def) or (method=="LEVEL_ATK_LT_DEF" and stats.atk<stats.def): return int(rule.target)
		if method in ["LEVEL_SILCOON","LEVEL_CASCOON"] and mon.level>=p:
			if (int(mon.get("personality",0))%10<5)==(method=="LEVEL_SILCOON"): return int(rule.target)
		if method=="LEVEL_NINJASK" and mon.level>=p: return int(rule.target)
		if method=="BEAUTY" and int(mon.get("beauty",0))>=p: return int(rule.target)
	return 0

func item_target(mon,item) -> int:
	if mon.get("held_item","")=="everstone": return 0
	for rule in book.get(str(int(mon.id)),[]):
		if rule.target>151 and not a.progression.national(): continue
		if rule.method=="ITEM" and rule.param==item: return int(rule.target)
		if item=="linkcable" and (rule.method=="TRADE" or rule.method=="TRADE_ITEM" and mon.get("held_item","")==rule.param): return int(rule.target)
	return 0

func evolve(mon,target):
	var old=int(mon.id); a.collection.register(mon)
	mon.id=target; a.c.abilities.assign(mon)
	a.evolutions.append([old,target,mon.get("shiny",false)])
	if old==290 and target==291 and a.data.party.size()<6 and a.data.balls>0:
		var shed=mon.duplicate(true); shed.id=292; a.c.abilities.assign(shed); a.data.party.append(shed); a.data.balls-=1
		a.evolutions.append([290,292,shed.get("shiny",false)])
