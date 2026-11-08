extends RefCounted
# Source builds for story battles and ordinary map trainers, separate from the
# player's learnsets, Daily teams and the optional custom Champion Challenges.
var a
var book: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/trainer-builds.json"))
const RIVALS={"rival":"OAKS_LAB","world_Route22_EarlyRival":"ROUTE22_EARLY","bridge_blue":"CERULEAN","ship_blue":"SS_ANNE","story_tower_blue":"POKEMON_TOWER","late_silph_blue":"SILPH","late_league_rival":"ROUTE22_LATE"}
const STORY={
	"bridge_rocket":"TEAM_ROCKET_GRUNT_6", "late_hideout_boss":"BOSS_GIOVANNI", "late_silph_boss":"BOSS_GIOVANNI_2",
	"late_dojo":"BLACK_BELT_KOICHI", "sevii_sapphire":"SCIENTIST_GIDEON", "sevii_lorelei":"TEAM_ROCKET_GRUNT_45",
	"sevii_biker_0":"BIKER_GOON", "sevii_biker_1":"BIKER_GOON_2", "sevii_biker_2":"BIKER_GOON_3", "sevii_biker_3":"CUE_BALL_PAXTON",
	# Retained compact-map interactions use actual trainers from the same area.
	"bug":"BUG_CATCHER_RICK", "lass":"LASS_JANICE", "rocket":"TEAM_ROCKET_GRUNT_4", "sailor":"SAILOR_EDMOND",
	"bridge_0":"BUG_CATCHER_CALE", "bridge_1":"LASS_ALI", "bridge_2":"YOUNGSTER_TIMMY", "bridge_3":"LASS_RELI", "bridge_4":"CAMPER_ETHAN",
	"late_hideout_guard":"TEAM_ROCKET_GRUNT_18", "late_tower_rocket":"TEAM_ROCKET_GRUNT_21", "late_silph_guard":"TEAM_ROCKET_GRUNT_29",
	"late_victory_trainer":"COOLTRAINER_GEORGE"}

func starter_suffix() -> String:
	return {1:"CHARMANDER",4:"SQUIRTLE",7:"BULBASAUR"}.get(int(a.data.starter),"SQUIRTLE")

func league_id(stage: int) -> String:
	if stage<0 or stage>4: return ""
	var rematch=a.sevii.done("network") and a.Finale.has(a,"champion")
	if stage==4: return "TRAINER_CHAMPION_"+("REMATCH_" if rematch else "FIRST_")+starter_suffix()
	return "TRAINER_ELITE_FOUR_"+["LORELEI","BRUNO","AGATHA","LANCE"][stage]+("_2" if rematch else "")

func resolve(kind: String) -> String:
	if a.gyms.leaders.has(kind): return a.gyms.leaders[kind].source_id
	if RIVALS.has(kind): return "TRAINER_RIVAL_"+RIVALS[kind]+"_"+starter_suffix()
	if kind.begins_with("late_league_") and kind.trim_prefix("late_league_").is_valid_int(): return league_id(int(kind.trim_prefix("late_league_")))
	if STORY.has(kind): return "TRAINER_"+STORY[kind]
	if not kind.begins_with("world_"): return ""
	var id=str(book.scripts.get(kind.trim_prefix("world_"),""))
	# Raw story actors must select the same rival/League variant as cutscenes.
	if id.begins_with("TRAINER_RIVAL_") or id.begins_with("TRAINER_CHAMPION_"):
		for starter in ["SQUIRTLE","CHARMANDER","BULBASAUR"]:
			if id.ends_with("_"+starter): id=id.trim_suffix(starter)+starter_suffix(); break
	if id.begins_with("TRAINER_CHAMPION_"): return league_id(4)
	for stage in 4:
		if id.begins_with("TRAINER_ELITE_FOUR_"+["LORELEI","BRUNO","AGATHA","LANCE"][stage]): return league_id(stage)
	return id

func party(kind: String) -> Array:
	var id=resolve(kind)
	if id=="": return []
	assert(book.trainers.has(id),"Unknown FireRed trainer: "+id)
	return book.trainers[id].party.map(func(mon):return [int(mon.id),int(mon.level)])

func definitions(ids: Array) -> Array:
	var moves=[]
	for id in ids:
		# Dive is an original trainer move even though it is not a FireRed HM.
		var move=a.inventory.book.moves.get(id,a.c.move_editor.book.moves.get(id,{})).duplicate(true)
		assert(not move.is_empty(),"Missing source trainer move: "+str(id))
		if move.kind=="heal": move["healing_pp_max"]=5
		moves.append(move)
	return moves

func prepare(kind: String):
	var id=resolve(kind); var trainer=book.trainers[id]
	a.encounter["trainer_id"]=id
	a.encounter["trainer_name"]="BLUE" if id.begins_with("TRAINER_RIVAL_") or id.begins_with("TRAINER_CHAMPION_") else trainer.name
	a.encounter["trainer_items"]=trainer.items.duplicate()
	a.encounter["source_double_battle"]=trainer.double_battle
	if id.begins_with("TRAINER_RIVAL_") or id.begins_with("TRAINER_CHAMPION_"): a.c.opponent_identity="blue"
	elif id.begins_with("TRAINER_ELITE_FOUR_"): a.c.opponent_identity=id.trim_prefix("TRAINER_ELITE_FOUR_").trim_suffix("_2").to_lower()
	elif "GIOVANNI" in id: a.c.opponent_identity="giovanni"
	elif trainer.trainer_class=="BLACK_BELT": a.c.opponent_identity="bruno"
	for i in trainer.party.size():
		var source=trainer.party[i]
		a.c.enemy_party[i].moves=definitions(source.moves)
		a.c.enemy_party[i]["held_item"]=source.held_item
