extends RefCounted

var trainers: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/trainers.json")).trainers

func party(c, choice: int) -> Array:
	var result: Array = []
	if choice <= 0: return result
	for member in trainers[choice-1].team:
		var data: Dictionary = c.roster[c.Dex.find_id(c.roster,int(member.id))].duplicate(true)
		data.moves = member.moves.duplicate(true)
		data["level"] = int(member.level)
		result.append(data)
	return result

func tests(c):
	var saved = c.opponent_choice.selected
	for choice in range(1,trainers.size()+1):
		c.opponent_choice.select(choice)
		c.start_match()
		c.check(c.enemy_party_size() == [5,5,5,5,6,6,6,2,2,3,3,4,4,4,5][choice-1],"Correct opponent party length")
		c.enemy.hp = 0
		c.finish_round()
		c.shots.clear()
		c.result_time = c.FAINT_RESULT_TIME
		c.advance_team()
		c.check(c.enemy_active == 1 and c.enemy.data.id == trainers[choice-1].team[1].id,"Trainer sends correct next slot")
		for slot in range(c.enemy_party_size()):
			c.enemy_active = slot
			c.enemy = c.replacement(false,0)
			var expected = trainers[choice-1].team[slot]
			c.check(c.enemy.data.id == expected.id and c.enemy.data.moves == expected.moves,"Trainer slot has its own exact moveset")
			c.countdown = 0
			for index in range(c.enemy.data.moves.size()):
				c.enemy_cooldowns = [0.0,0.0,0.0,0.0]
				c.enemy.action_lock = 0
				c.enemy.charge_left = 0
				c.enemy.dash_time = 0
				c.enemy.energy = 100
				c.enemy.hp = c.enemy.data.hp
				c.player.hp = c.player.data.hp
				c.result = ""
				c.use_move(c.enemy,c.player,index,Vector2.LEFT,false)
				c.shots.clear()
		c.enemy.hp = 0
		c.result = ""
		c.finish_round()
		c.check(c.result == "VICTORY" and not c.can_continue_team(),"Final trainer slot ends battle without phantom sixth member")
	c.opponent_choice.select(0)
	c.start_match()
	c.check(c.enemy_party.is_empty() and c.enemy_party_size() == 6,"Custom opponent restored")
	c.opponent_choice.select(saved)
	c.pick(25,7)
	var hp: float = c.player.hp
	var dream = trainers[2].team[0].moves[3].duplicate(true)
	c.execute_move(c.enemy,c.player,dream,Vector2.LEFT,false)
	c.check(c.player.hp == hp and c.shots.is_empty(),"Dream Eater fails against awake target")
	c.player.stages = {"atk":2}
	c.enemy.stages = {"def":-2}
	c.execute_move(c.enemy,c.player,trainers[2].team[1].moves[3],Vector2.LEFT,false)
	c.check(c.player.stages.is_empty() and c.enemy.stages.is_empty(),"Haze clears both sides' stat stages")
	var counter = trainers[1].team[1].moves[3].duplicate(true)
	c.enemy.pos = c.player.pos + Vector2(100,0)
	c.enemy["last_physical_damage"] = 12.0
	c.enemy["last_physical_time"] = c.round_time
	c.player.inv = 0
	c.execute_move(c.enemy,c.player,counter,Vector2.LEFT,false)
	c.check(is_equal_approx(hp-c.player.hp,24),"Counter returns twice the recent physical damage")
	c.pick(3,18)
	c.player["last_move"] = c.player.data.moves[2].duplicate(true)
	c.execute_move(c.enemy,c.player,trainers[4].team[0].moves[3],Vector2.LEFT,false)
	c.check(c.enemy.charge_left == 1 and c.shots.is_empty(),"Mirror Move honors copied Solar Beam charge")
	c.pick(25,7)
	c.enemy.pos = c.player.pos + Vector2(100,0)
	var bide = trainers[7].team[1].moves[2].duplicate(true)
	c.execute_move(c.enemy,c.player,bide,Vector2.LEFT,false)
	c.check(c.enemy.charge_left == 2,"Bide stores damage for two seconds")
	c.enemy.inv = 0
	c.hit(c.enemy,12,Vector2.RIGHT,true,{"type":"Normal","category":"Physical","fixed_damage":true},c.player)
	var release = c.enemy.pending_move.move.duplicate(true)
	c.enemy.pending_move = {}
	c.player.inv = 0
	hp = c.player.hp
	c.execute_move(c.enemy,c.player,release,Vector2.LEFT,false)
	c.check(is_equal_approx(hp-c.player.hp,24),"Bide returns twice stored damage")
	c.player["last_move"] = c.player.data.moves[0].duplicate(true)
	var disable = trainers[11].team[1].moves[0].duplicate(true)
	disable.accuracy = true
	c.execute_move(c.enemy,c.player,disable,Vector2.LEFT,false)
	c.player.action_lock = 0
	c.cooldowns = [0.0,0.0,0.0,0.0]
	c.check(not c.use_move(c.player,c.enemy,0,Vector2.RIGHT,true),"Disable blocks the recorded move")
	c.Conditions.tick(c.player,4.1)
	c.check(c.use_move(c.player,c.enemy,0,Vector2.RIGHT,true),"Disabled move returns after four seconds")
	c.pick(25,7)
	c.enemy.pos = c.player.pos + Vector2(100,0)
	c.player.inv = 0
	hp = c.player.hp
	c.execute_move(c.enemy,c.player,trainers[11].team[3].moves[3],Vector2.LEFT,false)
	c.check(c.enemy.hp == 0 and c.player.hp < hp,"Self-Destruct damages opponent and faints caster")
	c.pick(25,7)
	c.execute_move(c.enemy,c.player,trainers[11].team[1].moves[2],Vector2.LEFT,false)
	c.check(c.Conditions.stage(c.enemy,"evasion") > 1 and c.player.stages.is_empty(),"Minimize raises the caster's evasion only")
	c.pick(25,7)
