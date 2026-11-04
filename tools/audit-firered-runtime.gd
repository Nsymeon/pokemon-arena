extends SceneTree
# Diagnostic, not a claim of full playthrough. First run audit-firered-fidelity.py.
var c
var a
func _initialize(): run.call_deferred()
func fixture():
	a.clear_ui(); a.world.scenes.reset(); a.data=a.INITIAL_DATA.duplicate(true)
	a.data.starter=4; a.data.rival=true; a.data.party=[a.new_mon(6,70)]; a.inventory.migrate()
	a.in_battle=false; a.exploring=true; a.world.enabled=true; a.world.current="MAP_ROUTE1"; a.world.events.refresh()
	a.Finale.state(a).merge({"silph_saved":true,"secret_key":true,"quiz":true,"lift_key":true,"silph_blue":true})
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.campaign.active=false
func run():
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://captures/firered-source-trainers.json"))
	if not source is Dictionary: push_error("Run the source fidelity audit first."); quit(1); return
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; a.world.view3d.enabled=false; c.campaign.writable=false
	var report=[]
	for spec in [["brock","TRAINER_LEADER_BROCK"],["misty","TRAINER_LEADER_MISTY"],["surge","TRAINER_LEADER_LT_SURGE"],["erika","TRAINER_LEADER_ERIKA"],["koga","TRAINER_LEADER_KOGA"],["sabrina","TRAINER_LEADER_SABRINA"],["blaine","TRAINER_LEADER_BLAINE"],["giovanni","TRAINER_LEADER_GIOVANNI"]]:
		fixture()
		match spec[0]:
			"brock": a.begin_battle("brock",[74,95],[10,12])
			"misty": a.begin_battle("misty",[120,121],[18,21])
			"surge": a.begin_battle("surge",[100,25,26],[21,18,24])
			_:
				if spec[0]=="giovanni":
					a.data.badge=true; a.data.cascade=true; a.Story.state(a).thunder=true
					for badge in ["rainbow","soul","marsh","volcano"]: a.Finale.state(a)[badge]=true
				a.Finale.start_task(a,spec[0])
		c.check(a.in_battle,"Audit actually starts "+spec[0])
		var actual=c.enemy_party.map(func(mon):return {"id":int(mon.id),"level":int(mon.level),"moves":mon.moves.map(func(move):return str(move.id))})
		var expected=source[spec[1]]; var party_matches=actual.size()==expected.size(); var moves_match=party_matches
		for i in mini(actual.size(),expected.size()):
			party_matches=party_matches and actual[i].id==int(expected[i].id) and actual[i].level==int(expected[i].level)
			if expected[i].moves!=null:
				var left=actual[i].moves.duplicate(); var right=expected[i].moves.duplicate(); left.sort(); right.sort()
				moves_match=moves_match and left==right
		report.append({"leader":spec[0],"species_levels_match":party_matches,"explicit_moves_match":moves_match,"actual":actual,"source":expected})
		print(spec[0],": species/levels=",party_matches," source moves=",moves_match)
	var file=FileAccess.open("res://captures/firered-runtime-fidelity.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FIDELITY PROBE ERRORS: ",c.test_failures)
	quit(0 if c.test_failures.is_empty() else 1)
