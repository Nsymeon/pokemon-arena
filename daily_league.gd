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
const TEAM_RULES=2
const Dex=preload("res://roster.gd")
var movesets: Dictionary={}
var book: Dictionary={}
var profiles={}
var targets=[]
var all_targets=0
var cached_teams={}

func prepare_coverage():
	if not profiles.is_empty(): return
	movesets=JSON.parse_string(FileAccess.get_file_as_string("res://data/daily-movesets.json"))
	book=JSON.parse_string(FileAccess.get_file_as_string("res://data/battle-learnsets.json"))
	var roster={}
	for mon in Dex.all(): roster[int(mon.id)]=mon
	var abilities=JSON.parse_string(FileAccess.get_file_as_string("res://data/abilities.json"))
	for party in TEAMS:
		for id in party:
			if id not in targets: targets.append(id)
	assert(targets.size()<63)
	all_targets=(1<<targets.size())-1
	for id in POOL:
		var mon=roster[id]; var reliable=[]; var types=[]; var physical=false; var special=false
		for key in movesets[str(id)]:
			var move=book.moves[key]
			# A token weak move or an inaccurate/conditional attack cannot be the
			# team's promised answer. Respect the user's actual offensive stat.
			if move.damage<23 or move.get("base_power",0)<60 or move.get("charge_time",0)>0 or move.get("requires_recharge",false): continue
			if not move.get("accuracy",100) is bool and float(move.accuracy)<85: continue
			var stat="atk" if move.category=="Physical" else "spa"
			if mon.base_stats[stat]<maxf(mon.base_stats.atk,mon.base_stats.spa)*.7: continue
			reliable.append(move)
			if move.type not in types: types.append(move.type)
			physical=physical or move.category=="Physical"; special=special or move.category=="Special"
		var wins=0; var answers={}
		for i in targets.size():
			var foe=roster[targets[i]]; var ability=abilities[str(targets[i])][0]
			for move in reliable:
				if Dex.effectiveness(move.type,foe.types)<2: continue
				if ability=="Levitate" and move.type=="Ground": continue
				if ability=="Water Absorb" and move.type=="Water": continue
				if ability in ["Volt Absorb","Motor Drive"] and move.type=="Electric": continue
				if ability=="Flash Fire" and move.type=="Fire": continue
				wins|=1<<i; answers[targets[i]]=move.id; break
		profiles[id]={"wins":wins,"types":types,"physical":physical,"special":special,"answers":answers}

func balanced(party: Array) -> bool:
	prepare_coverage()
	if party.size()!=6: return false
	var once=0; var twice=0; var types=[]; var physical=0; var special=0; var seen=[]
	for id in party:
		if not profiles.has(id) or id in seen: return false
		seen.append(id)
		var profile=profiles[id]
		twice|=once & int(profile.wins); once|=int(profile.wins)
		for type in profile.types:
			if type not in types: types.append(type)
		physical+=int(profile.physical); special+=int(profile.special)
	return twice==all_targets and types.size()>=8 and physical>=2 and special>=2

func player_member(c,id: int) -> Dictionary:
	prepare_coverage()
	var result=member(c,id)
	if movesets.has(str(id)): result.moves=movesets[str(id)].map(func(key):return book.moves[key].duplicate(true))
	return result

func today() -> String: return Time.get_date_string_from_system(true)

func valid_day(day) -> bool:
	if not day is String or day.length()!=10 or day[4]!="-" or day[7]!="-": return false
	var numbers=day.replace("-","")
	if numbers.length()!=8 or not numbers.is_valid_int(): return false
	var year=int(day.substr(0,4)); var month=int(day.substr(5,2)); var date=int(day.substr(8,2))
	if year<1900 or month<1 or month>12: return false
	var leap=year%4==0 and (year%100!=0 or year%400==0)
	return date>=1 and date<=[31,29 if leap else 28,31,30,31,30,31,31,30,31,30,31][month-1]

func legacy_team(day: String) -> Array:
	var random=RandomNumberGenerator.new(); random.seed=int(day.replace("-",""))*104729+37
	var pool=POOL.duplicate(); var selected=[]
	for i in 6:
		var slot=random.randi_range(0,pool.size()-1); selected.append(pool[slot]); pool.remove_at(slot)
	return selected

func team(day: String, rules: int=TEAM_RULES) -> Array:
	if rules==1: return legacy_team(day)
	if cached_teams.has(day): return cached_teams[day].duplicate()
	var random=RandomNumberGenerator.new(); random.seed=int(day.replace("-",""))*104729+TEAM_RULES*37
	for attempt in 2048:
		var pool=POOL.duplicate(); var selected=[]
		for i in 6:
			selected.append(pool.pop_at(random.randi_range(0,pool.size()-1)))
		if balanced(selected):
			if cached_teams.size()>=32: cached_teams.clear()
			cached_teams[day]=selected.duplicate(); return selected
	# A verified safety net makes generation bounded even for an unlucky seed.
	var fallback=[9,34,65,68,121,94]
	assert(balanced(fallback),"Daily League fallback must cover every opponent")
	return fallback

func member(c, id: int, individual: Dictionary={}) -> Dictionary:
	var base={"ivs":c.ivs.uniform(31),"nature":"Hardy","ability_slot":0,"shiny":false,"gender":"N"}
	# Challenge rules override saved Free Battle loadouts on both sides.
	var result=c.adventure.battle_mon(id,50,base)
	result.moves=c.roster[c.Dex.find_id(c.roster,id)].moves.duplicate(true)
	return result

func locked(c) -> bool:
	return c.campaign.active and c.campaign.daily_enabled

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
