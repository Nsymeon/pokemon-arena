extends SceneTree
var c
func _initialize(): run.call_deferred()
func check(value,label): c.check(value,label)

func raw_answers(daily, party, target) -> Array:
	var foe=c.roster[c.Dex.find_id(c.roster,target)]; var answers=[]
	for id in party:
		var mon=c.roster[c.Dex.find_id(c.roster,id)]
		for key in daily.movesets[str(id)]:
			var move=c.move_editor.book.moves[key]
			if move.category=="Status" or move.damage<23 or move.get("base_power",0)<60 or move.get("charge_time",0)>0 or move.get("requires_recharge",false): continue
			if not move.accuracy is bool and float(move.accuracy)<85: continue
			if mon.base_stats["atk" if move.category=="Physical" else "spa"]<maxf(mon.base_stats.atk,mon.base_stats.spa)*.7: continue
			if c.Dex.effectiveness(move.type,foe.types)<2: continue
			if move.type=="Ground" and c.abilities.legal(target)[0]=="Levitate": continue
			answers.append(str(id)+":"+move.id); break
	return answers

func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	c.adventure.loaded=true; c.adventure.save_allowed=false; c.adventure.in_battle=false; c.adventure.exploring=false; c.adventure.visible=false
	c.campaign.writable=false; c.frontend.layer.visible=false
	var daily=c.campaign.daily; daily.prepare_coverage()
	check(daily.movesets.size()==daily.POOL.size(),"Every daily species has a reviewed default moveset")
	for id in daily.POOL:
		var ids=daily.movesets[str(id)]; var mon=c.roster[c.Dex.find_id(c.roster,id)]
		check(ids.size()==4 and ids.all(func(key):return ids.count(key)==1 and key in c.move_editor.book.species[str(id)]),"Four distinct legal daily moves: "+str(id))
		check(id==132 or ids.any(func(key):return c.move_editor.book.moves[key].damage>0 and c.move_editor.book.moves[key].type in mon.types),"Daily STAB attack: "+str(id))
	check(daily.balanced([9,34,65,68,121,94]),"Bounded-generation fallback covers the entire League")
	var used={}; var unique={}; var max_us=0; var epoch=Time.get_unix_time_from_datetime_string("2026-01-01T00:00:00")
	for offset in 730:
		var day=Time.get_date_string_from_unix_time(int(epoch)+offset*86400)
		var started=Time.get_ticks_usec(); var party=daily.team(day); max_us=maxi(max_us,Time.get_ticks_usec()-started)
		check(party.size()==6 and party.all(func(id):return party.count(id)==1),"Six unique Pokemon on "+day)
		check(daily.team(day)==party,"Same-day generation is stable: "+day)
		for target in daily.targets: check(raw_answers(daily,party,target).size()>=2,"Two separate effective attackers on "+day+" against "+str(target))
		for id in party: used[id]=true
		unique[str(party)]=true
	check(used.size()>=55 and unique.size()>700,"Coverage keeps broad species and daily team variety")
	print("DAILY SAMPLE: 730 dates / ",used.size()," species / ",unique.size()," teams / slowest generation us ",max_us)
	var fresh=load("res://daily_league.gd").new()
	check(fresh.team("2026-11-03")==daily.team("2026-11-03"),"Separate generator instances agree on the same date")
	print("TODAY TEAM: ",daily.team("2026-11-03"))
	for target in daily.TEAMS[0]: print("BROCK ",target," answers ",raw_answers(daily,daily.team("2026-11-03"),target))
	# Real old-save migration must retain already-earned daily badges.
	var progress=load("res://league_campaign.gd").new(); progress.path="user://daily-coverage-regression.json"; progress.day_override="2026-11-03"
	progress.data={"version":1,"day":"2026-11-03","cleared":3,"team":daily.legacy_team("2026-11-03"),"champion_team":[]}
	check(progress.save(),"Legacy daily fixture saves")
	var reloaded=load("res://league_campaign.gd").new(); reloaded.path=progress.path; reloaded.day_override=progress.day_override
	reloaded.read_progress(c.roster.map(func(mon):return int(mon.id)))
	check(reloaded.writable and reloaded.data.cleared==3,"Legacy daily save is accepted, not marked corrupt")
	reloaded.refresh_day()
	check(reloaded.data.cleared==3 and reloaded.data.team_rules==daily.TEAM_RULES and daily.balanced(reloaded.data.team),"Upgrade balances today's team without removing badges")
	var upgraded=reloaded.data.duplicate(true); reloaded.refresh_day()
	check(reloaded.data==upgraded and reloaded.valid(upgraded,c.roster.map(func(mon):return int(mon.id))),"Upgraded daily save remains stable and valid")
	var round_trip=load("res://league_campaign.gd").new(); round_trip.path=progress.path
	round_trip.read_progress(c.roster.map(func(mon):return int(mon.id)))
	check(round_trip.writable and round_trip.data.get("team_rules",0)==2 and round_trip.data.cleared==3 and round_trip.data.team==upgraded.team,"Upgraded rules and team survive a fresh JSON save/load")
	reloaded.day_override="2026-11-04"; reloaded.refresh_day()
	check(reloaded.data.cleared==0 and reloaded.data.team!=upgraded.team,"Next date resets daily progress and changes team")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(progress.path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path+suffix))
	# Actual preview, move editing and spawned fighters use the daily defaults.
	c.campaign.day_override="2026-11-03"; c.campaign.refresh_day(); var party=c.campaign.data.team
	var mon=c.roster[c.Dex.find_id(c.roster,int(party[0]))]; var saved_choices=c.move_editor.choices.duplicate(true)
	c.campaign.active=false; var free_key=c.move_editor.identity(mon,true,0); var free_moves=mon.moves.map(func(move):return move.id)
	c.move_editor.choices[free_key]=free_moves
	c.campaign.choose(0); var daily_key=c.move_editor.identity(mon,true,0)
	check(daily_key!=free_key and c.move_editor.configured(mon,true,0).moves.map(func(move):return move.id)==daily.movesets[str(mon.id)],"Free Battle choices cannot replace balanced daily defaults")
	c.move_editor.choices[daily_key]=free_moves
	check(c.move_editor.configured(mon,true,0).moves.map(func(move):return move.id)==free_moves,"Daily moves remain customizable")
	c.move_editor.choices.erase(daily_key); c.start_match()
	for fighter in c.player_states:
		check(fighter.data.moves.map(func(move):return move.id)==daily.movesets[str(fighter.data.id)],"Actual daily fighter has its coverage moves")
		check(fighter.data.level==50 and fighter.data.nature=="Hardy" and fighter.data.ability_slot==0 and fighter.data.get("held_item","")=="","Daily build locks remain intact")
	for stage in 13:
		for enemy in daily.opponent(c,stage): check(enemy.moves==c.roster[c.Dex.find_id(c.roster,int(enemy.id))].moves,"Opponents retain their fixed moves")
	c.campaign.active=false; c.move_editor.choices=saved_choices
	# One deliberately long final frame cannot make Surf travel/hit past its reach.
	for friendly in [true,false]:
		for weather in ["","rain"]:
			c.pick(9,9); c.rocks.clear(); c.shots.clear(); c.result=""; c.weather.kind=weather
			var user=c.player if friendly else c.enemy; var target=c.enemy if friendly else c.player
			user.pos=Vector2(400,600); target.pos=Vector2(400+c.skills.SURF_RANGE+50,600); target.inv=0
			var hp=target.hp; var move=c.move_editor.book.moves.surf
			c.skills.launch(c,user,target,move,Vector2.RIGHT,friendly); var shot=c.shots.back()
			c.skills.tick(c,shot,2.)
			check(absf(shot.pos.distance_to(shot.origin)-760)<.01 and target.hp==hp,"Surf stops at 760 and cannot hit beyond its crest, including rain and CPU")
			var end=shot.pos; c.skills.tick(c,shot,.2); check(shot.pos==end,"Expired Surf cannot move again")
			c.shots.clear(); user.pos=Vector2(400,600); target.pos=Vector2(1100,600); target.inv=0
			c.skills.launch(c,user,target,move,Vector2.RIGHT,friendly); c.skills.tick(c,c.shots.back(),2.)
			check(target.hp<hp,"Shorter Surf still damages targets within its path")
	print("DAILY COVERAGE CHECK: ",c.test_failures); quit(0 if c.test_failures.is_empty() else 1)
