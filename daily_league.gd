extends RefCounted
# Fixed expanded Kanto teams. Adventure keeps its source-level trainer parties.
const TEAMS=[
	[76,95,112,139,141,142], [121,131,130,134,55,9],
	[26,82,101,125,135,25], [3,45,71,103,114,47],
	[49,89,110,24,42,73], [65,122,97,80,103,124],
	[59,38,78,126,136,6], [112,31,34,51,28,115],
	[87,91,80,124,131,9], [95,106,107,68,62,57],
	[94,42,24,94,110,49], [130,142,149,149,6,131],
	[18,65,112,103,59,9]]
const POOL=[3,6,9,12,15,18,20,22,24,26,28,31,34,36,38,40,42,45,47,49,51,53,55,57,59,62,65,68,71,73,76,78,80,82,83,85,87,89,91,94,95,97,99,101,103,105,106,107,110,112,114,115,121,123,124,125,126,127,128,130,131,132,134,135,136,139,141,142,143,149]

func today() -> String: return Time.get_date_string_from_system(true)

func valid_day(day) -> bool:
	if not day is String or day.length()!=10 or day[4]!="-" or day[7]!="-": return false
	var numbers=day.replace("-","")
	if numbers.length()!=8 or not numbers.is_valid_int(): return false
	var year=int(day.substr(0,4)); var month=int(day.substr(5,2)); var date=int(day.substr(8,2))
	if year<1900 or month<1 or month>12: return false
	var leap=year%4==0 and (year%100!=0 or year%400==0)
	return date>=1 and date<=[31,29 if leap else 28,31,30,31,30,31,31,30,31,30,31][month-1]

func team(day: String) -> Array:
	var random=RandomNumberGenerator.new(); random.seed=int(day.replace("-",""))*104729+37
	var pool=POOL.duplicate(); var selected=[]
	for i in 6:
		var slot=random.randi_range(0,pool.size()-1); selected.append(pool[slot]); pool.remove_at(slot)
	return selected

func member(c, id: int, individual: Dictionary={}) -> Dictionary:
	var base={"ivs":c.ivs.uniform(31),"nature":"Hardy","ability_slot":0,"shiny":false,"gender":"N"}
	base.merge(individual,true)
	var result=c.adventure.battle_mon(id,100,base)
	result.moves=c.roster[c.Dex.find_id(c.roster,id)].moves.duplicate(true)
	return result

func opponent(c, stage: int) -> Array:
	return TEAMS[stage].map(func(id):return member(c,id))

func apply_player(c):
	for fighter in c.player_states:
		var configured=fighter.data
		var individual={}
		for key in ["ivs","nature","held_item","ability_slot","shiny","gender"]:
			if configured.has(key): individual[key]=configured[key]
		fighter.data=member(c,int(configured.id),individual)
		fighter.data.moves=configured.moves.duplicate(true)
		fighter.hp=fighter.data.hp
	if not c.player_states.is_empty(): c.player=c.player_states[0]
