extends Node2D

const FIELD = Rect2(0, 0, 2400, 1200)
const ARENA_ORIGIN = Vector2(40, 180)
const ARENA_SCALE = 0.8
var camera_offset = Vector2.ZERO
var enemy_bench = preload("res://enemy_switching.gd").new()
var balance = preload("res://battle_balance.gd").new()
var weather = preload("res://weather_rules.gd").new()
var weather_choice: OptionButton
var arena_choice: OptionButton
var fields = preload("res://tournament_fields.gd").new()
var arena_overview = false
var opponent_choice: OptionButton
var league = preload("res://league.gd").new()
var frontend = preload("res://front_menu.gd").new()
var adventure = preload("res://adventure.gd").new()
var campaign = preload("res://league_campaign.gd").new()
var enemy_party: Array = []
var preview_party: Array = []
var opponent_preview_slot = 0
var opponent_identity = "rival"
var trainer_gallery = false
var move_editor = preload("res://battle_moves.gd").new()
var skills = preload("res://arena_skills.gd").new()
var clashes = preload("res://attack_clashes.gd").new()
var clash_effects: Array = []
var next_clash_id = 0
const ROSTER_OFFSET = Vector2(0, 80)
const GOLD = Color("f9d86b")
const INK = Color("142833")
const WHITE = Color("e7eee2")
const MINT = Color("77e2b0")
const FAINT_FALL_TIME = 0.42
const FAINT_FADE_START = 1.65
const FAINT_HIDE_TIME = 2.6
const FAINT_RESULT_TIME = 2.9
const SEND_OUT_TIME = 3.2
const BALL_RELEASE_TIME = 1.05
const SUMMON_END_TIME = 1.8
const Dex = preload("res://roster.gd")
const Conditions = preload("res://status_rules.gd")
var art = preload("res://battle_art.gd").new()
var scars: Array = []
var team_mode = true
var team_slot = 0
var player_team = [24, 5, 8, 2, 93, 142]
var enemy_team = [3, 130, 64, 111, 102, 148]
var player_active = 0
var enemy_active = 0
var roster = Dex.all()
var player_index = 24
var enemy_index = 3
var selecting = true
var select_enemy = false
var enemy_cooldowns = [0.0, 0.0, 0.0, 0.0]
var player: Dictionary
var enemy: Dictionary
var shots: Array = []
var particles: Array = []
var rings: Array = []
var rocks: Array = []
var cooldowns = [0.0, 0.0, 0.0, 0.0]
var clock_time = 0.0
var round_time = 0.0
var countdown = SEND_OUT_TIME
var ai_timer = 1.0
var click_move = false
var click_destination = Vector2.ZERO
var sprinting = false
var player_states: Array = []
var switch_menu = false
var switch_time = -1.0
var switch_target = -1
var switch_cooldown = 0.0
var impacts: Array = []
var quick_attack_active = false
var shake = 0.0
var paused = false
var result = ""
var result_time = 0.0
var notice = ""
var notice_time = 0.0
var font = ThemeDB.fallback_font
var rng = RandomNumberGenerator.new()
var sound: AudioStreamPlayer
var portraits = {}
var portraits_flipped = {}
var page = 0
var search_box: LineEdit
var type_filter: OptionButton
var region_filter: OptionButton
var selection_controls: CanvasLayer
var query = ""
var test_failures: Array = []

var controls = preload("res://keybinds.gd").new()

func _ready():
	add_child(controls)
	controls.install()
	if "--capture-controls" in OS.get_cmdline_user_args(): call_deferred("capture_controls")
	rng.seed = 47
	sound = AudioStreamPlayer.new()
	add_child(sound)
	setup_selection_controls()
	move_editor.install(self)
	load_portraits()
	art.load_sprites()
	reset()
	add_child(adventure)
	adventure.install(self)
	campaign.install(self)
	frontend.install(self)
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("smoke_test")
	elif "--capture-clashes" in OS.get_cmdline_user_args():
		call_deferred("capture_clashes")
	elif "--capture-progress" in OS.get_cmdline_user_args():
		call_deferred("capture_progress")
	if "--capture-kanto" in OS.get_cmdline_user_args():
		call_deferred("capture_kanto")
	if "--capture-loadouts" in OS.get_cmdline_user_args():
		call_deferred("capture_loadouts")
	elif "--capture-adventure" in OS.get_cmdline_user_args():
		call_deferred("capture_adventure")
	elif "--capture-campaign" in OS.get_cmdline_user_args():
		call_deferred("capture_campaign")
	elif "--capture" in OS.get_cmdline_user_args():
		call_deferred("capture_preview")
	elif "--capture-faint" in OS.get_cmdline_user_args():
		call_deferred("capture_faint")
	elif "--capture-trainers" in OS.get_cmdline_user_args():
		call_deferred("capture_trainers")
	elif "--capture-style" in OS.get_cmdline_user_args():
		call_deferred("capture_style")
	elif "--capture-status" in OS.get_cmdline_user_args():
		call_deferred("capture_status")
	elif "--capture-polish" in OS.get_cmdline_user_args():
		call_deferred("capture_polish")
	elif "--capture-league" in OS.get_cmdline_user_args() or "--capture-gyms" in OS.get_cmdline_user_args():
		call_deferred("capture_league")
	elif "--capture-skills" in OS.get_cmdline_user_args():
		call_deferred("capture_skills")
	elif "--capture-special" in OS.get_cmdline_user_args():
		call_deferred("capture_special")
	elif "--capture-fields" in OS.get_cmdline_user_args():
		call_deferred("capture_fields")
	elif "--capture-persistent" in OS.get_cmdline_user_args():
		call_deferred("capture_persistent")

func reset():
	click_move = false
	clash_effects.clear()
	weather.reset(weather_choice.selected if weather_choice != null else 0)
	player_active = 0
	enemy_active = 0
	if team_mode:
		player_index = player_team[0]
		enemy_index = enemy_team[0]
	scars.clear()
	impacts.clear()
	switch_menu = false
	switch_time = -1
	switch_target = -1
	switch_cooldown = 0
	player_states.clear()
	player = {"pos": Vector2(350, 410), "hp": 180.0, "energy": 100.0, "face": 1.0, "inv": 0.0, "flash": 0.0, "dash": Vector2.ZERO, "dash_time": 0.0, "stun": 0.0}
	enemy = {"pos": Vector2(930, 410), "hp": 210.0, "energy": 100.0, "face": -1.0, "inv": 0.0, "flash": 0.0, "dash": Vector2.ZERO, "dash_time": 0.0, "stun": 0.0}
	for pair in [[player, player_index], [enemy, enemy_index]]:
		var fighter: Dictionary = pair[0]
		fighter["data"] = roster[pair[1]].duplicate(true)
		fighter.hp = fighter.data.hp
		fighter["guard"] = 0.0
		fighter["boost"] = 0.0
		fighter["ailment"] = ""
		fighter["ailment_time"] = 0.0
		fighter["dot_tick"] = 0.0
		fighter["transformed"] = false
		fighter["dash_move"] = {}
		fighter["fainted"] = false
		fighter["entering"] = true
		fighter["anim_age"] = 0.0
		fighter["attack_time"] = 0.0
		fighter["walk_time"] = 0.0
		fighter["heading"] = Vector2(fighter.face, 0)
		Conditions.init(fighter)
	if not enemy_party.is_empty():
		enemy.data = enemy_party[0].duplicate(true)
		enemy.hp = enemy.data.hp
	player.pos = FIELD.size * Vector2(0.34, 0.5)
	enemy.pos = FIELD.size * Vector2(0.66, 0.5)
	update_camera(10)
	if team_mode:
		for index in player_team: player_states.append(replacement(true, index))
		player_states[0] = player
	if not adventure.in_battle:
		player.data = move_editor.configured(player.data,true,0)
		if team_mode:
			for slot in range(player_states.size()): player_states[slot].data = move_editor.configured(player_states[slot].data,true,slot)
		if enemy_party.is_empty(): enemy.data = move_editor.configured(enemy.data,false,0)
	rocks = [{"pos": Vector2(600, 240), "hp": 55.0}, {"pos": Vector2(900, 515), "hp": 55.0}, {"pos": Vector2(1150, 150), "hp": 55.0}, {"pos": Vector2(340, 590), "hp": 55.0}]
	for rock in rocks: rock.pos *= Vector2(1.6, 1.6)
	fields.reset(self,arena_choice.selected if arena_choice != null else 0)
	shots.clear()
	particles.clear()
	rings.clear()
	cooldowns = [0.0, 0.0, 0.0, 0.0]
	enemy_cooldowns = [0.0, 0.0, 0.0, 0.0]
	result = ""
	result_time = 0.0
	paused = false
	round_time = 0
	countdown = SEND_OUT_TIME
	ai_timer = 1.0
	sprinting = false
	quick_attack_active = false
	shake = 0
	notice_time = 0
	enemy_bench.reset(self)

func _unhandled_input(event):
	if frontend.layer != null and frontend.layer.visible: return
	if enemy_bench.timer>=0:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE: paused = not paused
		return
	if adventure.exploring:
		adventure.handle_input(event)
		return
	if adventure.in_battle and adventure.modal != "":
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: adventure.clear_ui()
		return
	if adventure.in_battle:
		if controls.matches(event,"bag"):
			if result == "" and countdown<=0 and not paused and not switch_menu and switch_time<0 and adventure.capture_time<=0 and player.get("action_lock",0)<=0 and player.get("charge_left",0)<=0: adventure.inventory.bag()
			return
		if controls.matches(event,"capture"):
			adventure.throw_ball()
			return
		if controls.matches(event,"restart") or controls.matches(event,"roster") or (result!="" and event is InputEventKey and event.pressed and event.keycode==KEY_ENTER):
			if not can_continue_team(): adventure.return_world()
			return
	if adventure.in_battle and adventure.capture_time > 0: return
	if campaign.layer != null and campaign.layer.visible: return
	if selecting:
		selection_input(event)
		return
	if switch_menu:
		switch_input(event)
		return
	if switch_time >= 0:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE: paused = not paused
		return
	if controls.matches(event,"roster"):
		if campaign.active:
			campaign.show_hub()
			return
		selecting = true
		if team_mode:
			player_index = player_team[team_slot]
			enemy_index = enemy_team[team_slot]
		return
	if controls.matches(event,"restart"):
		if campaign.active:
			if result != "" and resolution_ready():
				campaign.record_result()
				campaign.show_hub()
			elif result == "": reset()
			return
		reset()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		paused = not paused
		return
	if not paused and result == "" and countdown <= 0:
		for i in range(4):
			if controls.matches(event,"move"+str(i+1)): attack(i)
		if controls.matches(event,"switch") and team_mode: switch_menu=true
		for i in range(6):
			if controls.matches(event,"slot"+str(i+1)): request_switch(i)
		if controls.matches(event,"click_move"):
			var mouse=get_global_mouse_position()
			if Rect2(40,180,1200,600).has_point(mouse):
				var court=balance.bounds(self)
				click_destination=screen_to_arena(mouse).clamp(court.position,court.end)
				click_move=true

func movement_input() -> Vector2:
	var keyboard = Vector2(float(controls.held("right"))-float(controls.held("left")),float(controls.held("down"))-float(controls.held("up"))).normalized()

	if keyboard!=Vector2.ZERO:
		click_move = false
		return keyboard
	if click_move:
		var location: Vector2 = adventure.position_world if adventure.exploring else player.pos
		if location.distance_to(click_destination)<=20:
			click_move = false
			return Vector2.ZERO
		return (click_destination-location).normalized()
	return Vector2.ZERO

func aim() -> Vector2:
	return (screen_to_arena(get_global_mouse_position()) - player.pos).normalized()

func screen_to_arena(point: Vector2) -> Vector2:
	return (point - world_origin()) / ARENA_SCALE

func world_origin() -> Vector2:
	return ARENA_ORIGIN - camera_offset * ARENA_SCALE

func update_camera(dt: float):
	var view = Vector2(1200, 600) / ARENA_SCALE
	var ahead = (enemy.pos - player.pos).normalized() * 220
	var desired = (player.pos + ahead - view * 0.5).clamp(Vector2.ZERO, FIELD.size - view)
	camera_offset = camera_offset.lerp(desired, 1.0 - exp(-dt * 6.0))

func attack(index: int):
	var direction = aim()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	use_move(player, enemy, index, direction, true)

func use_move(user: Dictionary, target: Dictionary, index: int, direction: Vector2, friendly: bool) -> bool:
	if index < 0 or index >= user.data.moves.size(): return false
	if result != "" or user.hp <= 0: return false
	var timers = cooldowns if friendly else enemy_cooldowns
	var move: Dictionary = weather.prepare(user.data.moves[index])
	if user.volatile.get("disabled",0) > 0 and user.get("disabled_move","") == move.id:
		Conditions.note(user,"MOVE DISABLED")
		return false
	if timers[index] > 0 or user.dash_time > 0 or user.get("action_lock", 0.0) > 0 or user.get("charge_left", 0.0) > 0:
		return false
	if user.energy < move.cost:
		if friendly:
			notice = "LOW ENERGY — reposition and recover"
			notice_time = 1.5
		return false
	user.action_lock = 1.0
	if not Conditions.attempt(self, user, move): return false
	timers[index] = move.cooldown
	user.energy -= move.cost
	if move.get("charge_time", 0.0) > 0 and move.id not in ["fly","dig"]:
		user.charge_left = float(move.charge_time)
		user.pending_move = {"move": move.duplicate(true), "direction": direction, "friendly": friendly}
		user.heading = direction
		user["move_label"] = move.name
		user["move_color"] = Dex.color(move.type)
		Conditions.note(user, "CHARGING " + move.name)
		return true
	execute_move(user, target, move, direction, friendly)
	return true

func execute_move(user: Dictionary, target: Dictionary, move: Dictionary, direction: Vector2, friendly: bool):
	user["movement_lock"] = 0.4
	move = weather.prepare(move)
	if move.id == "mirrormove":
		var copied: Dictionary = target.get("last_move", {})
		if copied.is_empty() or copied.id == "mirrormove":
			user.action_lock = 1.0
			Conditions.note(user,"NO MOVE TO COPY")
			return
		move = copied.duplicate(true)
		for key in ["weather_prepared","weather_power","area_scale"]: move.erase(key)
		move = weather.prepare(move)
		if move.get("charge_time",0)>0 and move.id not in ["fly","dig"]:
			user.charge_left = move.charge_time
			user.pending_move = {"move":move,"direction":direction,"friendly":friendly}
			user.action_lock = 1.0
			return
	user["last_move"] = move.duplicate(true)
	user.action_lock = float(move.get("action_delay", 1.0))
	var accuracy = 1.0 if move.get("accuracy", true) is bool else float(move.accuracy) / 100.0 * Conditions.stage(user, "accuracy")
	accuracy = weather.accuracy(move, accuracy)
	if not move.get("accuracy",true) is bool: accuracy /= Conditions.stage(target,"evasion")
	if rng.randf() > accuracy:
		Conditions.note(user, "MISS")
		return
	var timers = cooldowns if friendly else enemy_cooldowns
	user["heading"] = direction
	user["attack_heading"] = direction
	user["attack_time"] = 0.55
	user["attack_anim"] = "Shoot" if move.kind in ["bolt", "orb", "pulse", "status"] else "Attack"
	user["attack_kind"] = move.kind
	user["move_label"] = move.name
	user["move_color"] = Dex.color(move.type)
	user.face = signf(direction.x) if absf(direction.x) > 0.1 else user.face
	var color = Dex.color(move.type)
	if move.id == "disable":
		if user.pos.distance_to(target.pos)<260 and not target.get("last_move",{}).is_empty():
			target["disabled_move"] = target.last_move.id
			target.volatile["disabled"] = 4.0
			Conditions.note(target,"DISABLED " + target.last_move.name)
		else: Conditions.note(user,"NO MOVE IN RANGE")
		return
	if move.id == "bide":
		if not move.get("release_bide",false):
			user["bide_damage"] = 0.0
			user.charge_left = 2.0
			move = move.duplicate(true)
			move["release_bide"] = true
			user.pending_move = {"move":move,"direction":direction,"friendly":friendly}
			Conditions.note(user,"BIDE / STORING DAMAGE")
		else:
			move["fixed_damage"] = true
			if user.pos.distance_to(target.pos)<300:
				hit(target,user.get("bide_damage",0.0)*2,direction,friendly,move,user)
			rings.append({"pos":user.pos,"radius":0.0,"max":300.0,"life":0.6,"color":GOLD})
		return
	if move.id == "selfdestruct":
		rings.append({"pos":user.pos,"radius":0.0,"max":300.0,"life":0.7,"color":GOLD})
		burst(user.pos,GOLD,60)
		if user.pos.distance_to(target.pos)<300: hit(target,move.damage,direction,friendly,move,user)
		user.hp = 0
		return
	if move.id == "psywave":
		move = move.duplicate(true)
		move.damage *= rng.randf_range(0.5,1.5)
	if move.id == "dreameater" and target.ailment != "sleep":
		Conditions.note(user,"TARGET MUST SLEEP")
		return
	if move.id == "haze":
		player.stages.clear()
		enemy.stages.clear()
		rings.append({"pos":user.pos,"radius":0.0,"max":300.0,"life":0.7,"color":color})
		return
	if move.id in ["whirlwind","roar"]:
		if user.pos.distance_to(target.pos) < 300:
			move_fighter(target,direction*190)
			Conditions.apply(self,target,{"volatileStatus":"flinch"},move)
		rings.append({"pos":user.pos,"radius":0.0,"max":300.0,"life":0.6,"color":color})
		return
	if move.id == "counter":
		if round_time-user.get("last_physical_time",-100.0) <= 2 and user.pos.distance_to(target.pos)<260:
			move["fixed_damage"] = true
			hit(target,user.get("last_physical_damage",0.0)*2,direction,friendly,move,user)
		else: Conditions.note(user,"NO HIT TO COUNTER")
		return
	if weather.MOVES.has(move.id):
		weather.set_weather(weather.MOVES[move.id])
		Conditions.note(user, move.name.to_upper())
		return
	if skills.launch(self, user, target, move, direction, friendly):
		tone(820, 0.12)
		return
	match move.kind:
		"bolt", "orb":
			projectile(user.pos, direction, 580 if move.kind == "bolt" else 360, move.damage, 7 if move.kind == "bolt" else 18, friendly, color, move)
		"dash":
			user.dash = direction * (user.data.speed + 540)
			user.dash_time = 0.23
			user.inv = 0.24
			user.dash_move = move
			if friendly: quick_attack_active = true
		"pulse":
			rings.append({"pos": user.pos, "radius": 0.0, "max": 175.0 * move.get("area_scale", 1.0), "life": 0.5, "color": color, "type": move.type})
			if user.pos.distance_to(target.pos) < 175 * move.get("area_scale", 1.0):
				hit(target, move.damage, direction, friendly, move)
		"status":
			rings.append({"pos": user.pos, "radius": 0.0, "max": 260.0, "life": 0.6, "color": color})
			if user.pos.distance_to(target.pos) < 260:
				apply_status(target, move)
		"buff":
			user.boost = 5.0
			Conditions.apply(self, user, status_payload(move), move)
		"splash":
			user.energy = minf(100, user.energy + 15)
			user.inv = 0.2
		"teleport":
			move_fighter(user, direction * 130)
			user.inv = 0.25
		"transform":
			var own_max: float = user.data.hp
			user.data = target.data.duplicate(true)
			user.data.hp = own_max
			user.transformed = true
			for i in range(4): timers[i] = 0.5
		"guard":
			if move.get("stat_changes", {}).is_empty(): user.guard = 3.0
			else: Conditions.apply(self, user, status_payload(move), move)
			rings.append({"pos": user.pos, "radius": 25.0, "max": 55.0, "life": 0.6, "color": color})
		"heal":
			if move.id=="roost":
				user.volatile["roost"] = 1.5
				Conditions.note(user,"ROOST / GROUNDED 1.5s")
			if move.get("rest", false):
				user.hp = user.data.hp
				user.ailment = "sleep"
				user.ailment_time = 2.5
			else: user.hp = minf(user.data.hp, user.hp + user.data.hp * weather.healing(move))
			burst(user.pos, MINT, 25)
	burst(user.pos, color, 9)
	tone(620 + move.get("damage", 0) * 4, 0.07)

func sprint_movement(direction: Vector2, dt: float, requested: bool):
	if skills.riding(self, player):
		sprinting = false
		return
	sprinting = requested and direction.length_squared() > 0 and player.energy >= 12.0 * dt and not Conditions.immobilized(player)
	if sprinting: player.energy = maxf(0, player.energy - 12.0 * dt)
	move_fighter(player, direction * player.data.speed * (1.35 if sprinting else 1.0) * Conditions.speed(player) * fields.movement(player) * dt)

func projectile(origin: Vector2, direction: Vector2, speed: float, damage: float, radius: float, friendly: bool, color: Color, move: Dictionary = {}) :
	move = weather.prepare(move)
	radius *= move.get("area_scale", 1.0)
	shots.append({"pos": origin + direction * 27, "origin": origin, "age": 0.0, "vel": direction * speed, "damage": damage, "radius": radius, "friendly": friendly, "owner": player if friendly else enemy, "attack_snapshot": (player if friendly else enemy).duplicate(true), "color": color, "life": 2.6, "move": move.duplicate(true)})
	if skills.homing(move):
		shots.back().vel = direction.normalized() * 360.0
		shots.back().life = 3.0
		shots.back()["trail"] = []

func steer_homing(shot: Dictionary, dt: float):
	if shot.life <= 0 or not skills.homing(shot.get("move", {})): return
	var target = enemy if shot.friendly else player
	if target.hp > 0:
		var delta: Vector2 = target.pos-shot.pos
		if delta.length_squared() > 1:
			# Bounded turning lets a sideways sprint escape; never snaps onto a target.
			var turn = clampf(shot.vel.angle_to(delta), -1.8*dt, 1.8*dt)
			shot.vel = shot.vel.rotated(turn)
	var trail: Array = shot.get("trail", [])
	trail.append(shot.pos)
	if trail.size() > 20: trail.pop_front()
	shot["trail"] = trail

func _process(delta):
	if frontend.layer != null and frontend.layer.visible: return
	if adventure.in_battle and not paused: adventure.progress_time = maxf(0,adventure.progress_time-delta)
	if adventure.in_battle and adventure.modal != "":
		queue_redraw()
		return
	if adventure.exploring:
		selection_controls.visible = false
		adventure.tick(delta)
		queue_redraw()
		return
	if adventure.in_battle and adventure.capture_time > 0:
		adventure.tick_capture(delta)
		queue_redraw()
		return
	if not paused and not switch_menu: clock_time += delta
	selection_controls.visible = selecting and not campaign.layer.visible
	if not paused and not selecting and not switch_menu:
		update_effects(delta)
		if enemy_bench.timer>=0:
			enemy_bench.timer += delta
			if enemy_bench.timer>=0.7: enemy_bench.complete(self)
		elif switch_time >= 0:
			switch_time += delta
			if switch_time >= 0.7: complete_switch()
		elif countdown > 0:
			var intro_before = SEND_OUT_TIME - countdown
			countdown = maxf(0, countdown - delta)
			if countdown <= 0: fields.transition = false
			if intro_before < BALL_RELEASE_TIME and SEND_OUT_TIME - countdown >= BALL_RELEASE_TIME:
				tone(950, 0.14)
		elif result == "":
			update_battle(minf(delta, 0.04))
		else:
			var recall_before = result_time
			update_resolution(delta)
			if recall_before < FAINT_FADE_START and result_time >= FAINT_FADE_START: tone(720, 0.15)
			if resolution_ready() and adventure.in_battle: adventure.record_knockout()
			if resolution_ready() and can_continue_team(): advance_team()
			elif resolution_ready(): campaign.record_result()
	if not selecting: update_camera(delta)
	queue_redraw()

func update_battle(dt: float):
	if result != "": return
	if player.hp <= 0 or enemy.hp <= 0:
		finish_round()
		return
	weather.tick(self, dt)
	if player.hp <= 0 or enemy.hp <= 0:
		finish_round()
		return
	round_time += dt
	notice_time -= dt
	switch_cooldown = maxf(0, switch_cooldown - dt)
	sprinting = controls.held("sprint") and movement_input() != Vector2.ZERO and player.dash_time <= 0 and player.energy >= 12.0 * dt and not Conditions.immobilized(player)
	for i in range(4):
		cooldowns[i] = maxf(0, cooldowns[i] - dt)
		enemy_cooldowns[i] = maxf(0, enemy_cooldowns[i] - dt)
	for fighter in [player, enemy]:
		fighter.inv = maxf(0, fighter.inv - dt)
		fighter.flash = maxf(0, fighter.flash - dt)
		fighter.stun = maxf(0, fighter.stun - dt)
		fighter.guard = maxf(0, fighter.guard - dt)
		fighter.boost = maxf(0, fighter.boost - dt)
		if fighter.volatile.get("leechseed",0)>0 and fighter.hp>0:
			fighter["seed_tick"] = fighter.get("seed_tick",1.0)-minf(dt,fighter.volatile.leechseed)
			if fighter.seed_tick<=0:
				fighter.seed_tick += 1
				var stolen = minf(fighter.hp,fighter.data.hp*0.025)
				fighter.hp -= stolen
				var recipient = enemy if fighter==player else player
				if recipient.hp>0: recipient.hp = minf(recipient.data.hp,recipient.hp+stolen)
		Conditions.tick(fighter, dt)
		if fighter.hp > 0 and fighter.charge_left > 0:
			fighter.charge_left = maxf(0, fighter.charge_left - dt)
			if fighter.charge_left <= 0 and not fighter.pending_move.is_empty():
				var pending: Dictionary = fighter.pending_move
				fighter.pending_move = {}
				execute_move(fighter, enemy if fighter == player else player, pending.move, pending.direction, pending.friendly)
		if fighter != player or not sprinting:
			fighter.energy = minf(100, fighter.energy + dt * 15)
		if fighter.dash_time > 0:
			move_fighter(fighter, fighter.dash * dt)
			fighter.dash_time -= dt
			burst(fighter.pos, Dex.color(fighter.data.type), 1)
	if player.hp <= 0 or enemy.hp <= 0:
		finish_round()
		return
	if player.dash_time <= 0:
		quick_attack_active = false
		var direction = movement_input()
		sprint_movement(direction, dt, controls.held("sprint"))
		if absf(direction.x) > 0:
			player.face = signf(direction.x)
	elif quick_attack_active and player.pos.distance_to(enemy.pos) < 48 * player.dash_move.get("area_scale", 1.0) and player.inv > 0:
		hit(enemy, player.dash_move.damage, player.dash.normalized(), true, player.dash_move)
		player.dash_time = 0
	update_ai(dt)
	update_projectiles(dt)
	if player.hp <= 0 or enemy.hp <= 0: finish_round()

func update_projectiles(dt: float):
	for shot in shots: steer_homing(shot, dt)
	clashes.prepare(self,dt)
	for shot in shots:
		if shot.life <= 0: continue
		if shot.has("skill"):
			skills.tick(self, shot, dt)
			continue
		shot.life -= dt
		shot.age = shot.get("age", 0.0) + dt
		shot.pos += shot.vel * dt
		var target = enemy if shot.friendly else player
		if shot.life > 0 and shot.pos.distance_to(target.pos) < shot.radius + 19:
			hit(target, shot.damage, shot.vel.normalized(), shot.friendly, shot.move, shot.get("owner", {}), shot.get("attack_snapshot", {}))
			shot.life = 0
		for rock in rocks:
			if rock.hp > 0 and shot.life > 0 and shot.pos.distance_to(rock.pos) < 25 + shot.radius:
				rock.hp -= shot.damage
				shot.life = 0
				burst(shot.pos, Color("a2b1a0"), 15)
				if rock.hp <= 0:
					shake = 6
		if not FIELD.grow(30).has_point(shot.pos):
			shot.life = 0
	shots = shots.filter(func(s): return s.life > 0)

func finish_round():
	if result != "": return
	var player_out = player.hp <= 0 and (not team_mode or not has_player_reserve())
	var enemy_out = enemy.hp <= 0 and (not team_mode or enemy_bench.reserve(self)<0)
	result = "DRAW" if player_out and enemy_out else "DEFEAT" if player_out else "VICTORY" if enemy_out else "SWITCH"
	result_time = 0.0
	quick_attack_active = false
	notice_time = 0
	for fighter in [player, enemy]:
		fighter.fainted = fighter.hp <= 0
		fighter["faint_delay"] = 0.0
		fighter.dash_time = 0
		fighter["attack_time"] = 0.0
		fighter["walk_time"] = 0.0
		fighter.charge_left = 0
		fighter.pending_move = {}
		if fighter.fainted:
			fighter.stages.clear()
			fighter["faint_frame"] = art.frame(fighter)
			# Freeze a forward direction, including a vertically moving opponent.
			fighter.face = (1.0 if fighter == player else -1.0) if fighter.face == 0 else fighter.face
			burst(fighter.pos + Vector2(0, 6), Color("b4a47a"), 12)
	tone(180, 0.18)

func update_ai(dt: float):
	if enemy.hp <= 0 or player.hp <= 0: return
	enemy_bench.tick(self,dt)
	if enemy_bench.timer>=0: return
	var offset: Vector2 = player.pos - enemy.pos
	var distance = offset.length()
	var direction = offset.normalized()
	enemy.face = signf(direction.x)
	var preferred = 110 if enemy.data.role == "brawler" else 210 if enemy.data.role == "control" else 290
	var has_projectile = enemy.data.moves.any(func(move): return move.kind in ["bolt", "orb"])
	if not has_projectile: preferred = 110
	var walk = direction * (1.0 if distance > preferred + 35 else -0.7 if distance < preferred - 50 else 0.0)
	walk += direction.orthogonal() * sin(clock_time * 1.3) * 0.7
	var dodge_direction = balance.dodge(self,dt)
	if enemy.dash_time <= 0 and not skills.riding(self, enemy):
		var velocity = dodge_direction*1.35 if dodge_direction!=Vector2.ZERO else walk.limit_length()*0.75
		move_fighter(enemy, velocity * enemy.data.speed * Conditions.speed(enemy) * fields.movement(enemy) * dt)
	ai_timer -= dt * (0.4 if enemy.stun > 0 else 1.0)
	if ai_timer <= 0:
		ai_timer = rng.randf_range(0.55, 1.0)
		var choices = [0, 2, 1, 3]
		var best = -1
		var best_score = -1.0
		for i in choices:
			if i >= enemy.data.moves.size(): continue
			var move: Dictionary = enemy.data.moves[i]
			if enemy_cooldowns[i] > 0 or enemy.energy < move.cost:
				continue
			var score = Dex.effectiveness(move.type, Conditions.types(player)) * (1.5 if move.type in Conditions.types(enemy) else 1.0)
			if move.kind == "dash" and distance > (420 if move.id == "extremespeed" else 320 if move.id in skills.RUSHES else 200): continue
			if move.kind == "pulse" and distance > (800 if move.id in ["surf", "rockslide"] else 310 if move.id == "earthquake" else 175): continue
			if move.kind == "transform": score = 10.0
			if weather.MOVES.has(move.id): score = 2.2 if weather.kind != weather.MOVES[move.id] else -1.0
			if move.kind == "status": score = 1.6 if distance < 260 and (move.get("status", "") == "" or player.ailment == "") else -1.0
			if move.kind == "buff": score = 1.8 if enemy.boost <= 0 else -1.0
			if move.kind == "splash": score = -1.0
			if move.kind == "teleport": score = 2.0 if distance < 100 else -1.0
			if move.kind == "heal": score = 3.0 if enemy.hp < enemy.data.hp * 0.65 else -1.0
			if move.kind == "guard": score = 1.8 if enemy.guard <= 0 and distance < 280 else -1.0
			if weather.MOVES.has(move.id): score = 2.2 if weather.kind != weather.MOVES[move.id] else -1.0
			if move.id == "dreameater" and player.ailment != "sleep": score = -1.0
			if move.id == "counter" and round_time-enemy.get("last_physical_time",-100.0)>2: score = -1.0
			if move.id == "mirrormove" and player.get("last_move",{}).is_empty(): score = -1.0
			if move.id == "haze" and player.stages.is_empty() and enemy.stages.is_empty(): score = -1.0
			if score > best_score:
				best = i
				best_score = score
		if best >= 0:
			use_move(enemy, player, best, direction.rotated(rng.randf_range(-0.1, 0.1)), false)
	if enemy.dash_time > 0 and not enemy.dash_move.is_empty() and distance < 44 * enemy.dash_move.get("area_scale", 1.0):
		hit(player, enemy.dash_move.damage, direction, false, enemy.dash_move)
		enemy.dash_time = 0

func move_fighter(fighter: Dictionary, change: Vector2):
	if change.length_squared() > 0.01:
		fighter["heading"] = change.normalized()
		fighter["walk_time"] = 0.12
	var next: Vector2 = fighter.pos + change
	var court = balance.bounds(self)
	next = next.clamp(court.position,court.end)
	for rock in rocks:
		if rock.hp > 0 and next.distance_to(rock.pos) < 46:
			var away = (next - rock.pos).normalized()
			next = rock.pos + away * 46
	fighter.pos = next.clamp(court.position,court.end)

func damage_amount(attacker: Dictionary, target: Dictionary, base_damage: float, move: Dictionary) -> float:
	var move_type: String = move.get("type", "Normal")
	if move.get("fixed_damage", false):
		return base_damage * (0.0 if Dex.effectiveness(move_type,Conditions.types(target)) == 0 else 1.0) * (0.5 if target.guard > 0 else 1.0)
	if target.get("volatile",{}).get("underground",0)>0 and move.get("id","") in ["earthquake","magnitude"]: base_damage *= 2
	var physical = move.get("category", "Physical") == "Physical"
	var attack_stat: float = attacker.data.base_stats.atk if physical else attacker.data.base_stats.spa
	var defense_stat: float = target.data.base_stats.def if physical else target.data.base_stats.spd
	attack_stat *= Conditions.stage(attacker, "atk" if physical else "spa")
	defense_stat *= Conditions.stage(target, "def" if physical else "spd")
	defense_stat *= weather.defense(target, physical)
	var ratio = clampf((50.0 + attack_stat) / (50.0 + defense_stat), 0.35, 2.5)
	var stab = 1.5 if move_type in Conditions.types(attacker) else 1.0
	var multiplier = Dex.effectiveness(move_type, Conditions.types(target))
	var boost = float(move.get("weather_power", weather.power(move)))
	if physical and attacker.ailment == "burn": boost *= 0.5
	return snappedf(base_damage * ratio * stab * multiplier * boost * (0.5 if target.guard > 0 else 1.0), 0.1)

func hit(target: Dictionary, damage: float, direction: Vector2, friendly: bool, move: Dictionary = {}, owner: Dictionary = {}, attack_snapshot: Dictionary = {}) -> float:
	if target.inv > 0 or target.hp <= 0 or Conditions.avoids(target,move): return 0.0
	if move.get("id", "") == "dreameater" and target.ailment != "sleep": return 0.0
	var attacker = owner if not owner.is_empty() else player if friendly else enemy
	var offense = attack_snapshot if not attack_snapshot.is_empty() else attacker
	var move_type: String = move.get("type", "Normal")
	var multiplier = Dex.effectiveness(move_type, Conditions.types(target))
	damage = damage_amount(offense, target, damage, move)
	if offense.get("volatile", {}).get("focusenergy", 0) > 0 and rng.randf() < 0.5:
		damage *= 1.5
		Conditions.note(attacker, "CRITICAL!")
	var feedback = "IMMUNE" if multiplier == 0 else "SUPER EFFECTIVE x" + str(multiplier) if multiplier > 1 else "RESISTED x" + str(multiplier) if multiplier < 1 else ""
	if feedback != "":
		notice = move_type.to_upper() + " > " + Dex.type_label(target.data).to_upper() + " / " + feedback
		notice_time = 1.8
	if multiplier == 0:
		particles.append({"pos": target.pos + Vector2(-25, -45), "vel": Vector2(0, -30), "life": 0.7, "max_life": 0.7, "color": WHITE, "size": 0.0, "text": "IMMUNE"})
		return 0.0
	var actual_damage = minf(target.hp, damage)
	if target.get("pending_move",{}).get("move",{}).get("id","") == "bide":
		target["bide_damage"] = target.get("bide_damage",0.0) + actual_damage
	if move.get("category", "Physical") == "Physical":
		target["last_physical_damage"] = actual_damage
		target["last_physical_time"] = round_time
	target.hp = maxf(0, target.hp - damage)
	target.inv = 0.23
	target.flash = 0.15
	move_fighter(target, direction * 16)
	shake = 5
	impacts.append({"pos": target.pos + Vector2(0, -24), "type": move_type, "move": move.duplicate(true), "age": 0.0, "life": 0.65, "strength": clampf(damage / 35.0, 0.6, 1.8)})
	if impacts.size() > 24: impacts.pop_front()
	scars.append({"pos": target.pos, "life": 14.0, "size": clampf(damage / 40.0, 0.6, 1.6)})
	if scars.size() > 60: scars.pop_front()
	rings.append({"pos": target.pos, "radius": 8.0, "max": 65.0, "life": 0.3, "color": Dex.color(move_type)})
	burst(target.pos, Dex.color(move_type), 18)
	particles.append({"pos": target.pos + Vector2(0, -42), "vel": Vector2(0, -40), "life": 0.8, "max_life": 0.8, "color": WHITE, "size": 0.0, "text": str(int(damage))})
	if target.ailment == "freeze" and move_type == "Fire":
		target.ailment = ""
		target.ailment_time = 0
		Conditions.note(target, "THAWED")
	apply_hit_effects(attacker, target, move)
	if move.get("drain", false) and attacker.hp > 0: attacker.hp = minf(attacker.data.hp, attacker.hp + actual_damage * 0.4)
	if move.get("recoil", false): attacker.hp = maxf(0, attacker.hp - actual_damage * 0.2)
	tone(190 if friendly else 100, 0.045)
	return damage

func status_payload(move: Dictionary) -> Dictionary:
	var status: String = move.get("status", "")
	if status == "":
		status = {"sleep": "slp", "paralysis": "par", "burn": "brn", "poison": "psn", "toxic": "tox", "freeze": "frz"}.get(move.get("effect", ""), "")
	return {"status": status, "volatileStatus": move.get("volatile_status", ""), "boosts": move.get("stat_changes", {})}

func apply_status(target: Dictionary, move: Dictionary):
	if target.inv > 0: return
	if Conditions.apply(self, target, status_payload(move), move): burst(target.pos, Dex.color(move.type), 12)

func apply_hit_effects(attacker: Dictionary, target: Dictionary, move: Dictionary):
	if move.get("volatile_status", "") != "": Conditions.apply(self, target, status_payload(move), move)
	for effect in move.get("secondaries", []):
		if rng.randf() * 100 >= effect.get("chance", 100): continue
		if move.get("tri_status", false):
			Conditions.apply(self, target, {"status": ["brn", "par", "frz"][rng.randi_range(0, 2)]}, move)
		else: Conditions.apply(self, target, effect, move)
		if effect.has("self"): Conditions.apply(self, attacker, effect.self, move)

func burst(pos: Vector2, color: Color, count: int):
	for i in range(count):
		particles.append({"pos": pos, "vel": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30, 180), "life": 0.4, "max_life": 0.4, "color": color, "size": rng.randf_range(2, 5), "text": ""})

func update_effects(dt: float):
	for effect in clash_effects:
		effect.age += dt
		effect.life -= dt
	clash_effects = clash_effects.filter(func(effect): return effect.life > 0)
	for effect in impacts:
		effect.age += dt
		effect.life -= dt
	impacts = impacts.filter(func(effect): return effect.life > 0)
	for fighter in [player, enemy]:
		fighter["anim_age"] = fighter.get("anim_age", 0.0) + dt
		fighter["attack_time"] = maxf(0, fighter.get("attack_time", 0.0) - dt)
		fighter["walk_time"] = maxf(0, fighter.get("walk_time", 0.0) - dt)
	for mark in scars: mark.life -= dt
	scars = scars.filter(func(mark): return mark.life > 0)
	shake = maxf(0, shake - 28 * dt)
	for p in particles:
		p.life -= dt
		p.pos += p.vel * dt
	particles = particles.filter(func(p): return p.life > 0)
	for ring in rings:
		ring.life -= dt
		ring.radius = lerpf(ring.radius, ring.max, dt * 12)
	rings = rings.filter(func(r): return r.life > 0)

func tone(frequency: float, duration: float):
	if DisplayServer.get_name() == "headless":
		return
	sound.stop()
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var data = PackedByteArray()
	data.resize(int(22050 * duration))
	for i in range(data.size()):
		var envelope = 1.0 - float(i) / data.size()
		data[i] = int(sin(float(i) * frequency * TAU / 22050) * 24 * envelope) & 255
	stream.data = data
	sound.stream = stream
	sound.play()

func label_at(text: String, pos: Vector2, size: int = 16, color: Color = WHITE):
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color, border: Color = Color("29424b")):
	draw_rect(rect, color)
	draw_rect(rect, border, false, 1)

func bar(pos: Vector2, width: float, ratio: float, color: Color, height: float = 9):
	draw_rect(Rect2(pos, Vector2(width, height)), Color("203a40"))
	draw_rect(Rect2(pos, Vector2(width * clampf(ratio, 0, 1), height)), color)

func _draw():
	if adventure.exploring: return
	if arena_overview:
		draw_rect(Rect2(0,0,1280,960),Color("0b171f"))
		label_at(fields.LABELS[fields.active].to_upper(),Vector2(80,90),32,GOLD)
		label_at(fields.HINTS[fields.active],Vector2(80,130),18,MINT)
		draw_set_transform(Vector2(64,210),0,Vector2.ONE*0.48)
		draw_arena()
		for rock in rocks: draw_rock(rock)
		draw_trainer(true)
		draw_trainer(false)
		draw_creature(player,true)
		draw_creature(enemy,false)
		draw_set_transform(Vector2.ZERO)
		return
	if trainer_gallery:
		draw_trainer_gallery()
		return
	draw_rect(Rect2(0, 0, 1280, 960), Color("0b171f"))
	if selecting:
		draw_set_transform(ROSTER_OFFSET)
		draw_selection()
		draw_set_transform(Vector2.ZERO)
		return
	var jitter = Vector2(sin(clock_time * 85), cos(clock_time * 91)) * shake
	draw_set_transform(world_origin() + jitter, 0, Vector2.ONE * ARENA_SCALE)
	draw_arena()
	draw_trainer(true)
	draw_trainer(false)
	var sorted_rocks = rocks.duplicate()
	for rock in sorted_rocks:
		draw_rock(rock)
	for shot in shots:
		if shot.get("skill", "") == "wave": skills.draw(self, shot)
	if player.pos.y < enemy.pos.y:
		draw_creature(player, true)
		draw_creature(enemy, false)
	else:
		draw_creature(enemy, false)
		draw_creature(player, true)
	skills.draw_charge(self, player)
	skills.draw_charge(self, enemy)
	for shot in shots:
		if shot.get("skill", "") == "wave": continue
		if shot.has("skill"): skills.draw(self, shot)
		else: art.shot(self, shot)
	clashes.draw(self)
	for effect in impacts: art.impact(self, effect)
	for ring in rings:
		art.ring(self, ring)
	for p in particles:
		if p.text != "":
			label_at(p.text, p.pos, 22, p.color)
		else:
			draw_rect(Rect2(p.pos, Vector2.ONE * p.size), Color(p.color, p.life / p.max_life))
	if adventure.in_battle and adventure.capture_time>0:
		var progress = 1.0-adventure.capture_time/1.2
		var ball_pos = capture_ball_position(progress)
		draw_pokeball(ball_pos+Vector2(sin(progress*50)*5,0),14)
		draw_arc(enemy.pos,50+sin(progress*20)*8,0,TAU,40,Color(GOLD,0.7),3)
	if click_move: draw_arc(click_destination,15,0,TAU,24,MINT,2)
	draw_ball_sequence(player, true)
	draw_ball_sequence(enemy, false)
	if result == "" and countdown <= 0:
		var target = screen_to_arena(get_global_mouse_position())
		draw_arc(target, 10, 0, TAU, 16, Color(GOLD, 0.7), 1)
		draw_line(target - Vector2(15, 0), target + Vector2(15, 0), Color(GOLD, 0.5))
		draw_line(target - Vector2(0, 15), target + Vector2(0, 15), Color(GOLD, 0.5))
	draw_set_transform(Vector2.ZERO)
	for mask in [Rect2(0,0,1280,180), Rect2(0,780,1280,180), Rect2(0,180,40,600), Rect2(1240,180,40,600)]:
		draw_rect(mask, Color("0b171f"))
	label_at(fields.LABELS[fields.active].to_upper() + "   /   KANTO + EXTRAS", Vector2(40, 30), 12, MINT)
	label_at("POKÉMON  ARENA", Vector2(40, 66), 29)
	label_at("REAL-TIME POKÉMON BATTLES", Vector2(1000, 36), 13, Color("88a0a4"))
	label_at(("VS " + opponent_name().to_upper() + " / " + str(enemy_party_size()) + " POKÉMON") if not enemy_party.is_empty() else "6 VS 6   /   TEAM BATTLE" if team_mode else "1 VS 1   /   DUEL", Vector2(976, 63), 14, GOLD)
	draw_hud()
	if adventure.in_battle: adventure.draw_progress()
	weather.draw(self)
	skills.minimap(self)
	draw_set_transform(Vector2(0, 140))
	draw_moves()
	label_at("CHARGING %.1fs" % player.charge_left if player.get("charge_left", 0) > 0 else "NEXT MOVE %.1fs" % player.action_lock if player.get("action_lock", 0) > 0 else "READY / 1s BETWEEN MOVES", Vector2(40, 659), 14, GOLD)
	if notice_time > 0:
		label_at(notice, Vector2(440, 659), 14, GOLD)
	draw_set_transform(Vector2(0, 80))
	if countdown > 0:
		label_at("TRAINERS, SEND OUT!" if countdown > 0.7 else "BATTLE!", Vector2(515, 130), 20, GOLD)
		if fields.transition:
			draw_set_transform(Vector2.ZERO)
			var shutter = clampf((countdown-0.65)/SEND_OUT_TIME,0,1)
			for i in range(10):
				draw_rect(Rect2(40+i*120,180,120,600*shutter),Color("334354"))
			label_at("FIELD CHANGE / " + fields.LABELS[fields.active].to_upper(),Vector2(400,220),21,GOLD)
	elif result != "" and resolution_ready():
		overlay(result + (" / " + opponent_name().to_upper() if not enemy_party.is_empty() else ""), ("R / Tab: League progress" + (" / " + campaign.error if campaign.error != "" else " / SAVED")) if campaign.active else ("R / Enter: return to adventure" if adventure.in_battle else "R: rematch  •  Tab: choose Pokémon"))
	elif paused:
		overlay("PAUSED", "Esc to resume  •  R to restart")
	draw_set_transform(Vector2.ZERO)
	if switch_menu: draw_switch_menu()

func draw_hud():
	if adventure.in_battle:
		label_at("ADVENTURE / G: BALL (%d) / I: BAG / weaken wild Pokemon first" % adventure.data.balls, Vector2(40,945),18,GOLD)
	for friendly in [true, false]:
		var f = player if friendly else enemy
		var x = 40 if friendly else 755
		var accent = MINT if friendly else Color("f18c71")
		panel(Rect2(x, 85, 485, 85), Color("152734"), Color("607989"))
		panel(Rect2(x + 6, 91, 66, 66), Color("304557"), GOLD)
		var texture = portraits.get(int(f.data.id))
		if texture:
			var size = texture.get_size() * 58.0 / maxf(texture.get_width(), texture.get_height())
			draw_texture_rect(texture, Rect2(Vector2(x + 39, 124) - size / 2, size), false, Color.WHITE if f.hp > 0 else Color(0.3, 0.3, 0.3))
		label_at(f.data.name.to_upper() + (" Lv."+str(f.data.get("level",5)) if adventure.in_battle else ""), Vector2(x + 82, 110), 20, WHITE)
		var type_x = x + 82
		for type in Conditions.types(f):
			draw_rect(Rect2(type_x, 115, 78, 14), Dex.color(type))
			label_at(type.to_upper(), Vector2(type_x + 5, 126), 10, INK)
			type_x += 83
		var ratio: float = f.hp / f.data.hp
		bar(Vector2(x + 82, 135), 310, ratio, MINT if ratio > 0.5 else GOLD if ratio > 0.2 else Color("f7756b"), 13)
		label_at("%d" % f.hp, Vector2(x + 402, 147), 15)
		bar(Vector2(x + 82, 153), 310, f.energy / 100.0, Color("6fb9f4"), 3)
		label_at((Conditions.summary(f)+(" / SPRINT" if f.get("sprinting",false) else "")).left(55), Vector2(x + 82, 167), 9, GOLD)
		var active = player_active if friendly else enemy_active
		for i in range((player_states.size() if friendly else enemy_party_size()) if team_mode else 1):
			var pos = Vector2(x + 410 + (i % 3) * 20, 102 + (i / 3) * 20)
			if friendly:
				pos = Vector2(x + 410 + (i % 3)*26,101+(i/3)*28)
				var member = player_states[i] if team_mode else player
				var alive = member.hp>0
				draw_pokeball(pos,11)
				var face_texture = portraits.get(int(member.data.id))
				if face_texture:
					var face_size = face_texture.get_size()*18.0/maxf(face_texture.get_width(),face_texture.get_height())
					draw_texture_rect(face_texture,Rect2(pos-face_size/2,face_size),false,Color.WHITE if alive else Color(0.3,0.3,0.3,0.8))
				if not alive: draw_line(pos-Vector2(7,7),pos+Vector2(7,7),Color("ed8272"),2)
				if i==active: draw_arc(pos,13,0,TAU,24,accent,2)
			else:
				if (enemy_bench.states[i].hp<=0 if team_mode and i<enemy_bench.states.size() else f.hp<=0): draw_circle(pos,5,Color("3d4d56"))
				else: draw_pokeball(pos,5)
				if i==active: draw_arc(pos,8,0,TAU,16,accent,1)

	label_at("VS", Vector2(621, 115), 25, GOLD)
	label_at("%02d:%02d" % [int(round_time) / 60, int(round_time) % 60], Vector2(610, 147), 18)

func draw_arena():
	art.arena(self)

func draw_rock(rock: Dictionary):
	var p: Vector2 = rock.pos
	if rock.hp <= 0:
		for i in range(5):
			draw_rect(Rect2(p + Vector2(i * 9 - 22, sin(i * 5) * 10), Vector2(7, 5)), Color("777b68"))
		return
	draw_ellipse(p + Vector2(4, 12), Vector2(35, 15), Color(0.1, 0.17, 0.15, 0.25))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-27, 11), p + Vector2(-25, -15), p + Vector2(-9, -30), p + Vector2(15, -26), p + Vector2(29, -6), p + Vector2(26, 15)]), Color("596b65"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-25, -15), p + Vector2(-9, -30), p + Vector2(15, -26), p + Vector2(24, -8), p + Vector2(-1, -6)]), Color("94a497"))
	draw_line(p + Vector2(-1, -6), p + Vector2(7, 8), Color("435951"), 3)
	if rock.hp < 55:
		bar(p + Vector2(-22, 21), 44, rock.hp / 55.0, Color("afbd9d"), 3)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color):
	var points = PackedVector2Array()
	for i in range(24):
		points.append(center + Vector2(cos(i * TAU / 24), sin(i * TAU / 24)) * radii)
	draw_colored_polygon(points, color)

func draw_creature(fighter: Dictionary, friendly: bool):
	if not selecting and not friendly and enemy_bench.timer>=0:
		enemy_bench.draw_recall(self)
		return
	if fighter.get("hp",1)>0 and fighter.get("volatile",{}).get("underground",0)>0:
		draw_ellipse(fighter.pos,Vector2(30,12),Color(0.12,0.08,0.03,0.85))
		draw_arc(fighter.pos,30,0,TAU,24,Color("b69b69"),3)
		return
	if not selecting and friendly and switch_time >= 0:
		draw_switch_recall()
		return
	if not selecting and fighter.get("fainted", false):
		draw_fainted(fighter)
		return
	var p: Vector2 = fighter.pos
	var summon = summon_progress(SEND_OUT_TIME - countdown) if not selecting and countdown > 0 and fighter.get("entering", true) else 1.0
	if shadow_entry(fighter, friendly):
		draw_shadow_entry(fighter, SEND_OUT_TIME - countdown)
		return
	if summon <= 0: return
	draw_ellipse(p + Vector2(0, 8), Vector2(25, 9) * summon, Color(0.06, 0.14, 0.13, 0.28 * summon))
	p = skills.areas.visual_position(self,fighter)
	var texture = (portraits_flipped if fighter.face > 0 else portraits).get(int(fighter.data.id))
	var animated = art.frame(fighter) if not selecting else {}
	if not animated.is_empty():
		var size: Vector2 = animated.size * summon
		if fighter.dash_time > 0:
			for i in range(3, 0, -1):
				var trail: Vector2 = p - fighter.dash.normalized() * i * 17 + Vector2(0, -24) - size / 2
				draw_texture_rect_region(animated.texture, Rect2(trail, size), animated.region, Color(0.7, 0.9, 1, 0.16 * (1 - i / 4.0)))
		draw_texture_rect_region(animated.texture, Rect2(p + Vector2(0, -24) - size / 2, size), animated.region, Color(2, 2, 2, summon) if fighter.flash > 0 or summon < 0.9 else Color.WHITE)
	elif texture:
		var factor = (62.0 if selecting else 78.0) / maxf(texture.get_width(), texture.get_height())
		var size = texture.get_size() * factor * summon
		var pos = p + Vector2(-size.x * 0.5, -size.y + 8 + sin(clock_time * 7) * 1.5)
		draw_texture_rect(texture, Rect2(pos, size), false, Color(2, 2, 2, summon) if fighter.flash > 0 or summon < 0.9 else Color.WHITE)
	if not selecting and fighter.get("attack_time", 0.0) > 0:
		art.attack_effect(self, fighter)
		var text: String = fighter.get("move_label", "")
		var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_rect(Rect2(p + Vector2(-width / 2 - 8, -113), Vector2(width + 16, 24)), Color(0.05, 0.1, 0.16, 0.85))
		label_at(text, p + Vector2(-width / 2, -96), 15, fighter.get("move_color", GOLD))
	if fighter.inv > 0:
		draw_arc(p, 30, 0, TAU, 24, Color(WHITE, 0.6), 2)
	if not selecting: draw_conditions(fighter)
	if fighter.get("boost", 0) > 0: label_at("BOOST", p + Vector2(-22, -60), 11, MINT)
	if fighter.guard > 0: draw_arc(p + Vector2(0, -20), 40, 0, TAU, 32, MINT, 3)
	if not selecting:
		draw_arc(p + Vector2(0, 9), 28, 0.1, PI - 0.1, 20, MINT if friendly else Color("f18c71"), 2)

func faint_pose(time: float) -> Dictionary:
	var fall = smoothstep(0.0, FAINT_FALL_TIME, time)
	var alpha = 1.0 - smoothstep(FAINT_FADE_START, FAINT_HIDE_TIME, time)
	var black = time >= FAINT_FALL_TIME and int((time - FAINT_FALL_TIME) / 0.11) % 2 == 0
	return {"fall": fall, "alpha": alpha, "black": black, "visible": time < FAINT_HIDE_TIME}

func draw_fainted(fighter: Dictionary):
	var faint_elapsed = maxf(0, result_time - fighter.get("faint_delay", 0.0))
	var pose = faint_pose(faint_elapsed)
	if not pose.visible: return
	var p: Vector2 = fighter.pos
	p = skills.areas.visual_position(self,fighter)
	var texture = (portraits_flipped if fighter.face > 0 else portraits).get(int(fighter.data.id))
	if not texture: return
	var size = texture.get_size() * (78.0 / maxf(texture.get_width(), texture.get_height()))
	var animated: Dictionary = fighter.get("faint_frame", {})
	var facing: float = fighter.face
	var recall = recall_progress(faint_elapsed)
	var hand = trainer_hand(fighter == player)
	draw_ellipse(p + Vector2(facing * size.y * 0.4 * pose.fall, 9), Vector2(25 + pose.fall * 9, 8), Color(0.06, 0.14, 0.13, 0.28 * pose.alpha))
	var jitter = Vector2(sin(clock_time * 85), cos(clock_time * 91)) * shake
	# Pivot at the feet: the head tips forward towards the opponent.
	var pivot = (p + Vector2(0, 8)).lerp(hand, recall)
	draw_set_transform(world_origin() + pivot * ARENA_SCALE + jitter, facing * PI * 0.5 * pose.fall * (1.0 - recall), Vector2(1.0 - 0.5 * pose.fall, 1.0) * ARENA_SCALE * (1.0 - recall))
	var tint = Color(0, 0, 0, pose.alpha) if pose.black else Color(1, 1, 1, pose.alpha)
	if recall > 0: tint = Color(1.0, 0.18, 0.3, pose.alpha)
	if not animated.is_empty():
		draw_texture_rect_region(animated.texture, Rect2(-animated.size / 2 + Vector2(0, -32), animated.size), animated.region, tint)
	else:
		draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y), size), false, tint)
	draw_set_transform(world_origin() + jitter, 0, Vector2.ONE * ARENA_SCALE)

func load_portraits():
	for mon in roster:
		var image = Image.load_from_file(mon.sprite)
		assert(image != null, "Missing sprite: " + mon.sprite)
		var used = image.get_used_rect()
		var cropped = image.get_region(used)
		portraits[int(mon.id)] = ImageTexture.create_from_image(cropped)
		cropped.flip_x()
		portraits_flipped[int(mon.id)] = ImageTexture.create_from_image(cropped)

func trainer_position(friendly: bool) -> Vector2:
	return FIELD.size * Vector2(0.032 if friendly else 0.968, 0.54)

func trainer_hand(friendly: bool) -> Vector2:
	var fighter = player if friendly else enemy
	var elapsed = SEND_OUT_TIME - countdown
	var lift = 0.0
	if countdown > 0 and fighter.get("entering", true):
		lift = sin(clampf(elapsed / 1.05, 0, 1) * PI) * 18
	var identity = "red" if friendly else opponent_identity
	return trainer_position(friendly) + art.trainers.hand_offset(identity,1.0 if friendly else -1.0) + art.trainers.pose_shift(lift)

func summon_progress(time: float) -> float:
	return smoothstep(BALL_RELEASE_TIME, SUMMON_END_TIME, time)

func shadow_entry(fighter, friendly) -> bool:
	return not selecting and not friendly and opponent_identity == "agatha" and int(fighter.data.id) == 94 and countdown > 0 and fighter.get("entering", true)

func draw_shadow_entry(fighter, elapsed: float):
	if elapsed < BALL_RELEASE_TIME: return
	var p: Vector2 = fighter.pos
	var spread = smoothstep(BALL_RELEASE_TIME, 1.65, elapsed)
	var rise = smoothstep(1.7, 2.85, elapsed)
	var dissolve = 1.0 - smoothstep(2.65, SEND_OUT_TIME, elapsed)
	draw_ellipse(p + Vector2(0,8), Vector2(57,20)*spread, Color(0.22,0.03,0.38,0.45*dissolve))
	draw_ellipse(p + Vector2(0,8), Vector2(44,14)*spread, Color(0.025,0.015,0.045,0.95))
	for i in range(8):
		var a = i*TAU/8 + elapsed*1.5
		var mist = p + Vector2(cos(a)*43, sin(a)*12 - rise*36)
		draw_circle(mist, (5 + sin(a*3)*2)*spread, Color(0.4,0.08,0.65,0.35*dissolve))
	var frame = art.frame(fighter)
	if not frame.is_empty() and rise > 0:
		var size: Vector2 = frame.size
		var region: Rect2 = frame.region
		region.size.y *= rise
		draw_texture_rect_region(frame.texture, Rect2(p + Vector2(-size.x/2,8-size.y*rise),Vector2(size.x,size.y*rise)),region,Color(0.24,0.10,0.34).lerp(Color.WHITE,rise))
	if rise < 0.45:
		for side in [-1,1]: draw_ellipse(p + Vector2(side*10,3-rise*28),Vector2(5,2)*spread,Color(1,0.18,0.3,spread))

func recall_progress(time: float) -> float:
	return smoothstep(FAINT_FADE_START, FAINT_HIDE_TIME, time)

func throw_position(friendly: bool, destination: Vector2, time: float) -> Vector2:
	var progress = clampf((time - 0.25) / (BALL_RELEASE_TIME - 0.25), 0, 1)
	return trainer_hand(friendly).lerp(destination, progress) + Vector2(0, -sin(progress * PI) * 100)

func capture_ball_position(progress: float) -> Vector2:
	var flight = clampf(progress*2,0,1)
	return trainer_hand(true).lerp(enemy.pos,flight)+Vector2(0,-sin(flight*PI)*140)

func draw_trainer(friendly: bool):
	if not friendly and adventure.in_battle and adventure.encounter.kind == "wild": return
	art.trainer(self, friendly)

func draw_pokeball(p: Vector2, radius: float, opened: bool = false):
	for top in [true, false]:
		var offset = Vector2(0, -3 if top and opened else 3 if opened else 0)
		var points = PackedVector2Array([p + offset])
		for i in range(17):
			var angle = PI + i * PI / 16 if top else i * PI / 16
			points.append(p + offset + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, Color("f26970") if top else WHITE)
		draw_arc(p + offset, radius, PI if top else 0.0, TAU if top else PI, 16, INK, 1.5)
	draw_line(p - Vector2(radius, 0), p + Vector2(radius, 0), INK, 2)
	draw_circle(p, radius * 0.32, INK)
	draw_circle(p, radius * 0.18, WHITE)

func draw_ball_sequence(fighter: Dictionary, friendly: bool):
	if not friendly and adventure.in_battle and adventure.encounter.kind == "wild": return
	var hand = trainer_hand(friendly)
	var destination: Vector2 = fighter.pos + Vector2(0, -35)
	if shadow_entry(fighter, friendly): destination = fighter.pos + Vector2(0,8)
	if countdown > 0 and fighter.get("entering", true):
		var elapsed = SEND_OUT_TIME - countdown
		if elapsed >= 0.25 and elapsed < BALL_RELEASE_TIME:
			var ball = throw_position(friendly, destination, elapsed)
			draw_line(ball - Vector2(16 if friendly else -16, -6), ball, Color(WHITE, 0.5), 3)
			draw_pokeball(ball, 9)
		elif elapsed >= BALL_RELEASE_TIME and elapsed < SUMMON_END_TIME:
			var growth = summon_progress(elapsed)
			draw_arc(destination, 15 + growth * 55, 0, TAU, 40, Color(0.8, 0.95, 1, 1.0 - growth), 4)
			for i in range(10):
				var ray = Vector2.from_angle(i * TAU / 10 + growth) * (20 + growth * 50)
				draw_line(destination + ray * 0.7, destination + ray, Color(1, 0.95, 0.8, 1.0 - growth), 3)
			draw_pokeball(destination, 8, true)
		elif elapsed >= SUMMON_END_TIME and elapsed < 2.4:
			var back = smoothstep(SUMMON_END_TIME, 2.4, elapsed)
			draw_pokeball(destination.lerp(hand, back) + Vector2(0, -sin(back * PI) * 50), 7)
	var faint_elapsed = maxf(0, result_time - fighter.get("faint_delay", 0.0))
	if fighter.get("fainted", false) and faint_elapsed >= FAINT_FADE_START:
		var recall = recall_progress(faint_elapsed)
		if recall < 1:
			var origin: Vector2 = fighter.pos + Vector2(fighter.face * 22, 0)
			var energy = origin.lerp(hand, recall)
			draw_line(hand, energy, Color(1, 0.12, 0.3, 0.22), 14)
			draw_line(hand, energy, Color(1, 0.3, 0.4, 0.85), 4)
			draw_circle(energy, 9 * (1.0 - recall) + 2, Color("ffb8c6"))
			draw_pokeball(hand, 7, true)
		else:
			var glow = 1.0 - clampf((faint_elapsed - FAINT_HIDE_TIME) / (FAINT_RESULT_TIME - FAINT_HIDE_TIME), 0, 1)
			draw_arc(hand, 10 + glow * 10, 0, TAU, 24, Color(1, 0.5, 0.6, glow), 2)

func draw_moves():
	var keys = [controls.text("move1"),controls.text("move2"),controls.text("move3"),controls.text("move4")]
	for i in range(player.data.moves.size()):
		var move: Dictionary = weather.prepare(player.data.moves[i])
		var type_color = Dex.color(move.type)
		var x = 40 + i * 247
		panel(Rect2(x, 678, 233, 78), Color("142831"), Color("726747") if cooldowns[i] <= 0 else Color("29424b"))
		label_at(keys[i] + "  " + move.type.to_upper(), Vector2(x + 12, 698), 11, type_color)
		label_at(move.name.to_upper(), Vector2(x + 12, 721), 15)
		label_at(move_description(move, Conditions.types(enemy)), Vector2(x + 12, 742), 11, Color("91a6a7"))
		label_at(str(int(move.cost)) + " EN", Vector2(x + 185, 698), 10, Color("91a6a7"))
		var remaining = maxf(cooldowns[i], player.get("action_lock", 0.0))
		if remaining > 0:
			bar(Vector2(x, 753), 233, 1 - cooldowns[i] / move.cooldown, type_color, 3)
			label_at("%.1fs" % remaining, Vector2(x + 184, 720), 12, GOLD)
	panel(Rect2(1028, 678, 212, 78), Color("142831"))
	label_at(controls.text("sprint")+" / SPRINT", Vector2(1042, 704), 16, MINT)
	label_at("HOLD / +35% SPEED", Vector2(1042, 731), 12, WHITE)
	label_at("Move: "+controls.text("up")+", "+controls.text("left")+", "+controls.text("down")+", "+controls.text("right")+" / "+controls.text("click_move")+"    Aim: Mouse", Vector2(40, 783), 12, Color("91a6a7"))
	label_at(controls.text("switch")+": Team  "+controls.text("roster")+": Roster  Esc: Pause", Vector2(945, 783), 11, Color("91a6a7"))

func move_description(move: Dictionary, target_types) -> String:
	if weather.MOVES.has(move.id): return "WEATHER / 20s / WHOLE ARENA"
	if move.id == "solarbeam" and weather.kind == "sun": return "INSTANT BEAM / SUN"
	if move.id=="roost": return "Heal / NO FLYING 1.5s"
	if move.get("rest", false): return "Full heal / SLEEP 2.5s"
	if not move.get("stat_changes", {}).is_empty(): return move.effect.to_upper() + " / UNTIL SWITCH"
	if move.get("volatile_status", "") == "focusenergy": return "Critical boost / 6s"
	match move.kind:
		"heal": return "Recover %d%% HP" % roundi(weather.healing(move) * 100)
		"guard": return "Guard / 3s"
		"buff": return "Power +30% / 5s"
		"status": return move.get("effect", "status").to_upper() + " / range 260"
		"transform": return "Copy rival / keep own HP"
		"teleport": return "Reposition / brief invulnerability"
		"splash": return "Recover 15 energy"
	if move.get("charge_time", 0) > 0: return "CHARGE 1s / RECOVERY 2s"
	if move.get("requires_recharge", false): return "RECOVERY 2s"
	var multiplier = Dex.effectiveness(move.type, target_types)
	return ("PHY" if move.category == "Physical" else "SPC") + " / " + skills.description(move) + " / " + ("IMMUNE" if multiplier == 0 else "x" + str(multiplier))

func setup_selection_controls():
	selection_controls = CanvasLayer.new()
	selection_controls.offset = ROSTER_OFFSET
	add_child(selection_controls)
	search_box = LineEdit.new()
	search_box.position = Vector2(40, 112)
	search_box.size = Vector2(260, 35)
	search_box.placeholder_text = "Search name or Pokédex number..."
	search_box.add_theme_font_size_override("font_size", 15)
	search_box.text_changed.connect(func(value): query = value.strip_edges().to_lower(); page = 0)
	search_box.text_submitted.connect(func(_value): start_match())
	selection_controls.add_child(search_box)
	type_filter = OptionButton.new()
	type_filter.position = Vector2(310, 112)
	type_filter.size = Vector2(135, 35)
	type_filter.add_item("All types")
	for type in Dex.TYPES: type_filter.add_item(type)
	type_filter.item_selected.connect(func(_index): page = 0)
	selection_controls.add_child(type_filter)
	region_filter = OptionButton.new()
	region_filter.position = Vector2(455, 112)
	region_filter.size = Vector2(150, 35)
	for region in ["All Pokémon", "Gen 1 · #001–151", "Retained extras"]: region_filter.add_item(region)
	region_filter.item_selected.connect(func(_index): page = 0)
	selection_controls.add_child(region_filter)
	weather_choice = OptionButton.new()
	weather_choice.position = Vector2(615,112)
	weather_choice.size = Vector2(200,35)
	for title in weather.LABELS: weather_choice.add_item("Weather: " + title)
	selection_controls.add_child(weather_choice)
	arena_choice = OptionButton.new()
	arena_choice.position = Vector2(825,112)
	arena_choice.size = Vector2(410,35)
	for title in fields.LABELS: arena_choice.add_item("Arena: " + title)
	for i in range(fields.LABELS.size()): arena_choice.get_popup().set_item_tooltip(i,fields.HINTS[i])
	arena_choice.tooltip_text = fields.HINTS[0]
	arena_choice.item_selected.connect(func(index): arena_choice.tooltip_text = fields.HINTS[index])
	selection_controls.add_child(arena_choice)
	for control in [type_filter,region_filter,weather_choice,arena_choice]:
		control.add_theme_font_size_override("font_size",14)
		control.fit_to_longest_item = false
		control.clip_text = true
	opponent_choice = OptionButton.new()
	opponent_choice.position = Vector2(625,66)
	opponent_choice.size = Vector2(610,32)
	opponent_choice.add_item("Opponent: Custom team")
	for trainer in league.trainers: opponent_choice.add_item(trainer.name + " / " + trainer.title + " / Red & Blue")
	opponent_choice.item_selected.connect(func(choice): preview_party = league.party(self,choice); opponent_preview_slot = 0; select_enemy = false; team_mode = true if choice > 0 else team_mode)
	selection_controls.add_child(opponent_choice)

func filtered_roster() -> Array:
	var indices = []
	for i in range(roster.size()):
		var mon: Dictionary = roster[i]
		if query != "" and not mon.name.to_lower().contains(query) and not ("%03d" % mon.id).contains(query): continue
		if type_filter.selected > 0 and Dex.TYPES[type_filter.selected - 1] not in mon.types: continue
		if region_filter.selected == 1 and mon.id > 151: continue
		if region_filter.selected == 2 and mon.id <= 151: continue
		indices.append(i)
	return indices

func change_page(amount: int):
	var total = maxi(1, ceili(filtered_roster().size() / 18.0))
	page = posmod(page + amount, total)

func start_match():
	if not campaign.prepare_match(): return
	opponent_choice.release_focus()
	enemy_party = league.party(self,opponent_choice.selected)
	opponent_identity = league.trainers[opponent_choice.selected-1].id if opponent_choice.selected > 0 else "rival"
	if not enemy_party.is_empty(): team_mode = true
	search_box.release_focus()
	type_filter.release_focus()
	region_filter.release_focus()
	weather_choice.release_focus()
	arena_choice.release_focus()
	selecting = false
	selection_controls.visible = false
	if team_mode:
		player_team[team_slot] = player_index
		enemy_team[team_slot] = enemy_index
	reset()

func selection_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T and opponent_choice.selected == 0: team_mode = not team_mode
		if team_mode and event.keycode >= KEY_1 and event.keycode <= KEY_6:
			player_team[team_slot] = player_index
			enemy_team[team_slot] = enemy_index
			team_slot = event.keycode - KEY_1
			player_index = player_team[team_slot]
			enemy_index = enemy_team[team_slot]
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB and opponent_choice.selected == 0: select_enemy = not select_enemy
		if event.keycode == KEY_ENTER:
			start_match()
			return
		if event.keycode == KEY_PAGEDOWN: change_page(1)
		if event.keycode == KEY_PAGEUP: change_page(-1)
		var change = 0
		if event.keycode == KEY_LEFT: change = -1
		if event.keycode == KEY_RIGHT: change = 1
		if event.keycode == KEY_UP: change = -6
		if event.keycode == KEY_DOWN: change = 6
		var indices = filtered_roster()
		if change != 0 and not indices.is_empty():
			var current = indices.find(enemy_index if select_enemy else player_index)
			current = posmod(current + change, indices.size())
			if select_enemy: enemy_index = indices[current]
			else: player_index = indices[current]
			page = current / 18
			if team_mode:
				player_team[team_slot] = player_index
				enemy_team[team_slot] = enemy_index
	if event is InputEventMouseButton and event.pressed:
		selection_click(get_global_mouse_position() - ROSTER_OFFSET, event.button_index)

func selection_click(mouse: Vector2, button: int):
	if button == MOUSE_BUTTON_WHEEL_DOWN: change_page(1); return
	if button == MOUSE_BUTTON_WHEEL_UP: change_page(-1); return
	if button not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]: return
	search_box.release_focus()
	if button==MOUSE_BUTTON_LEFT and move_editor.click(mouse): return
	if not preview_party.is_empty():
		for i in range(preview_party.size()):
			if Rect2(652+i*98,806,92,50).has_point(mouse):
				opponent_preview_slot = i
				return
	if team_mode:
		for friendly in [true, false]:
			if not friendly and opponent_choice.selected > 0: continue
			for i in range(6):
				if Rect2((40 if friendly else 652) + i * 98, 806, 92, 50).has_point(mouse):
					player_team[team_slot] = player_index
					enemy_team[team_slot] = enemy_index
					team_slot = i
					select_enemy = not friendly
					player_index = player_team[i]
					enemy_index = enemy_team[i]
					return
	if Rect2(40, 66, 260, 32).has_point(mouse): select_enemy = false
	if Rect2(310, 66, 260, 32).has_point(mouse) and opponent_choice.selected == 0: select_enemy = true
	if Rect2(930, 748, 310, 42).has_point(mouse): start_match(); return
	if Rect2(1040, 497, 90, 32).has_point(mouse): change_page(-1); return
	if Rect2(1140, 497, 100, 32).has_point(mouse): change_page(1); return
	var indices = filtered_roster()
	for slot in range(18):
		var location = page * 18 + slot
		if location >= indices.size(): break
		if Rect2(40 + (slot % 6) * 202, 160 + (slot / 6) * 111, 190, 101).has_point(mouse):
			if select_enemy or button == MOUSE_BUTTON_RIGHT:
				if opponent_choice.selected > 0: return
				enemy_index = indices[location]
			else: player_index = indices[location]
			if team_mode:
				player_team[team_slot] = player_index
				enemy_team[team_slot] = enemy_index

func draw_selection():
	var preview_enemy = preview_party[mini(opponent_preview_slot,preview_party.size()-1)] if not preview_party.is_empty() else roster[enemy_index]
	var shown_enemy_index = Dex.find_id(roster,int(preview_enemy.id))
	label_at("POKÉMON  ARENA", Vector2(40, 43), 30)
	label_at("LEAGUE / " + campaign.NAMES[campaign.stage] if campaign.active else "KANTO 151 + 7 EXTRAS", Vector2(500, 39), 17, MINT)
	panel(Rect2(40, 66, 260, 32), Color("233e3b") if not select_enemy else INK, MINT if not select_enemy else Color("29424b"))
	panel(Rect2(310, 66, 260, 32), Color("43352f") if select_enemy else INK, GOLD if select_enemy else Color("29424b"))
	label_at("1 / YOUR POKÉMON", Vector2(55, 88), 15, MINT)
	label_at("2 / " + (league.trainers[opponent_choice.selected-1].name.to_upper() if opponent_choice.selected > 0 else "CPU OPPONENT"), Vector2(325, 88), 15, GOLD)

	var indices = filtered_roster()
	var pages = maxi(1, ceili(indices.size() / 18.0))
	page = clampi(page, 0, pages - 1)
	label_at("%d FOUND   /   PAGE %d OF %d" % [indices.size(), page + 1, pages], Vector2(700, 520), 13, GOLD)
	for slot in range(18):
		var location = page * 18 + slot
		if location >= indices.size(): break
		var i: int = indices[location]
		var mon: Dictionary = roster[i]
		var pos = Vector2(40 + (slot % 6) * 202, 160 + (slot / 6) * 111)
		var border = MINT if i == player_index else GOLD if i == shown_enemy_index else Color("29424b")
		panel(Rect2(pos, Vector2(190, 101)), Color("142831"), border)
		draw_rect(Rect2(pos, Vector2(4, 101)), Dex.color(mon.type))
		label_at("#%03d" % mon.id, pos + Vector2(9, 17), 10, Color("91a6a7"))
		var tag = "YOU+CPU" if i == player_index and i == shown_enemy_index else "YOU" if i == player_index else "CPU" if i == shown_enemy_index else ""
		label_at(tag, pos + Vector2(125, 17), 10, border)
		draw_creature({"pos": pos + Vector2(36, 83), "data": mon, "face": 1, "flash": 0, "inv": 0, "stun": 0, "guard": 0}, true)
		label_at(mon.name, pos + Vector2(72, 42), 15)
		label_at(Dex.type_label(mon).to_upper(), pos + Vector2(72, 62), 9, Dex.color(mon.type))
		label_at("BST %d" % stat_total(mon), pos + Vector2(72, 82), 11, Color("91a6a7"))
	if indices.is_empty():
		label_at("No Pokémon match these filters.", Vector2(430, 300), 24, GOLD)
	label_at("Scroll / PgUp / PgDn: pages   ·   Modern types & base stats", Vector2(40, 520), 12, Color("91a6a7"))
	panel(Rect2(1040, 497, 90, 32), INK)
	panel(Rect2(1140, 497, 100, 32), INK)
	label_at("< PREV", Vector2(1055, 519), 14)
	label_at("NEXT >", Vector2(1160, 519), 14)
	selection_details(roster[player_index], preview_enemy, Vector2(40, 544), true)
	selection_details(preview_party[mini(opponent_preview_slot,preview_party.size()-1)] if not preview_party.is_empty() else roster[enemy_index], roster[player_index], Vector2(652, 544), false)
	label_at(("6 VS %d / EDIT SLOT %d — keys 1–6 select slot" % [preview_party.size() if not preview_party.is_empty() else 6,team_slot + 1]) if team_mode else "1 VS 1 / DUEL", Vector2(40, 761), 14, GOLD)
	label_at("Edit YOUR team / opponent uses the original Red & Blue party" if opponent_choice.selected > 0 else "T: toggle team / duel   ·   Each slot: click for YOU, right click for CPU", Vector2(40, 783), 12, Color("91a6a7"))
	if team_mode: draw_team_selection()
	panel(Rect2(930, 748, 310, 42), MINT, MINT)
	label_at("ENTER  /  START BATTLE", Vector2(973, 777), 18, INK)

func stat_total(mon: Dictionary) -> int:
	var total = 0
	for value in mon.base_stats.values(): total += int(value)
	return total

func selection_details(mon: Dictionary, rival: Dictionary, pos: Vector2, friendly: bool):
	if friendly or opponent_choice.selected==0: mon = move_editor.configured(mon,friendly,team_slot if team_mode else 0)
	panel(Rect2(pos, Vector2(588, 185)), Color("10232c"))
	label_at(("YOU / " if friendly else "CPU / ") + mon.name.to_upper(), pos + Vector2(16, 25), 18, Dex.color(mon.type))
	label_at(Dex.type_label(mon), pos + Vector2(400, 24), 12, Dex.color(mon.type))
	var s: Dictionary = mon.base_stats
	label_at("BASE   HP %d   ATK %d   DEF %d   SPA %d   SPD %d   SPE %d" % [s.hp, s.atk, s.def, s.spa, s.spd, s.spe], pos + Vector2(16, 46), 11, WHITE)
	for i in range(mon.moves.size()):
		var move: Dictionary = mon.moves[i]
		var offset = Vector2(16 + (i % 2) * 286, 76 + (i / 2) * 50)
		label_at(["Q", "E", "F", "C"][i] + "  " + move.name + ("  v" if friendly or opponent_choice.selected==0 else ""), pos + offset, 14)
		label_at(move.type.to_upper() + " / " + move_description(move, rival.types), pos + offset + Vector2(0, 17), 9, Dex.color(move.type))
	label_at("ARENA  %d HP / %d movement  ·  %s" % [mon.hp, mon.speed, mon.role], pos + Vector2(16, 173), 10, Color("91a6a7"))

func overlay(title: String, subtitle: String):
	draw_rect(Rect2(360, 337, 560, 132), Color(0.04, 0.09, 0.12, 0.94))
	draw_rect(Rect2(360, 337, 560, 3), GOLD)
	var width = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	label_at(title, Vector2(640 - width / 2, 395), 38, GOLD)
	width = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	label_at(subtitle, Vector2(640 - width / 2, 435), 16)

func check(condition: bool, message: String):
	if not condition:
		test_failures.append(message)
		push_error("TEST FAILURE: " + message)

func pick(number: int, rival: int):
	enemy_party = []
	opponent_identity = "rival"
	team_mode = false
	player_index = Dex.find_id(roster, number)
	enemy_index = Dex.find_id(roster, rival)
	reset()
	countdown = 0
	selecting = false

func homing_tests():
	for id in skills.SEEKERS:
		var move = move_editor.book.moves[id].duplicate(true)
		for friendly in [true,false]:
			pick(25,7)
			rocks.clear()
			player.pos=Vector2(900,550)
			enemy.pos=Vector2(1250,650)
			var attacker = player if friendly else enemy
			var target = enemy if friendly else player
			projectile(attacker.pos,Vector2.RIGHT if friendly else Vector2.LEFT,360,30,18,friendly,Dex.color(move.type),move)
			var shot = shots.back()
			var before: Vector2=shot.vel
			steer_homing(shot,0.02)
			check(absf(before.angle_to(shot.vel))>0 and absf(before.angle_to(shot.vel))<=0.0361,id+": steers gradually for either side")
			var hp: float=target.hp
			attacker.hp=0
			for frame in range(180): update_projectiles(1.0/60)
			check(target.hp<hp and shots.is_empty(),id+": tracks and hits after caster faints")
		pick(25,7)
		rocks.clear()
		player.pos=Vector2(800,550)
		enemy.pos=Vector2(800,770)
		var hp: float=player.hp
		projectile(enemy.pos,Vector2.UP,360,30,18,false,Dex.color(move.type),move)
		for frame in range(190):
			sprint_movement(Vector2.RIGHT,1.0/60,true)
			update_projectiles(1.0/60)
		check(player.hp==hp and shots.is_empty(),id+": sideways sprint evades until expiry")
		check(player.inv==0 and player.dash_time==0,"Aura evasion does not grant sprint invulnerability")
		projectile(player.pos,Vector2.LEFT,580,20,7,true,Color.WHITE,{"id":"ember","type":"Fire"})
		var straight=shots.back()
		steer_homing(straight,0.1)
		check(straight.vel==Vector2.LEFT*580 and straight.life==2.6,"Other projectiles keep their original trajectory and lifetime")
		reset()

func movement_recovery_tests():
	pick(25,7)
	rocks.clear()
	player.pos=Vector2(800,550)
	enemy.pos=Vector2(1300,650)
	var move=move_editor.book.moves.swift.duplicate(true)
	execute_move(player,enemy,move,Vector2.RIGHT,true)
	execute_move(enemy,player,move,Vector2.LEFT,false)
	var origin: Vector2=player.pos
	var cpu_origin: Vector2=enemy.pos
	var energy: float=player.energy
	ai_timer=99
	sprint_movement(Vector2.RIGHT,0.1,true)
	update_ai(0.1)
	check(player.pos==origin and enemy.pos==cpu_origin,"Post-move recovery blocks player sprint and AI walking/dodges")
	check(player.energy==energy,"Blocked sprint does not consume energy")
	for fighter in [player,enemy]:
		Conditions.tick(fighter,0.39)
		check(Conditions.speed(fighter)==0,"Movement stays locked for the first 0.39 seconds")
		Conditions.tick(fighter,0.011)
		check(Conditions.speed(fighter)>0 and fighter.action_lock>0,"Movement resumes after 0.4 seconds while the one-second attack gate remains")
	sprint_movement(Vector2.RIGHT,0.1,true)
	update_ai(0.1)
	check(player.pos!=origin and enemy.pos!=cpu_origin,"Both fighters can move again after recovery")
	shots.clear()
	move=move_editor.book.moves.quickattack.duplicate(true)
	execute_move(player,enemy,move,Vector2.RIGHT,true)
	origin=player.pos
	update_projectiles(0.1)
	check(player.pos!=origin and player.movement_lock>0,"Recovery does not cancel attack-driven Quick Attack movement")
	Conditions.init(player)
	check(player.movement_lock==0,"New fighter initialization clears movement recovery")
	reset()

func smoke_test():
	controls.tests(self)
	movement_recovery_tests()
	homing_tests()
	art.tests(self)
	balance.tests(self)
	adventure.tests()
	campaign.tests(self)
	clashes.tests(self)
	check(roster.size() == 158, "151 Kanto plus all seven existing non-Kanto species")
	var ids = []
	for mon in roster:
		check(mon.id not in ids, "Unique species ID")
		ids.append(mon.id)
		check(mon.moves.size() == 4 and mon.base_stats.size() == 6, "Four moves / six stats: " + mon.name)
		check(portraits.has(int(mon.id)), "Sprite loaded: " + mon.name)
	for number in range(1, 152): check(number in ids, "Kanto ID %d exists" % number)
	check(Dex.effectiveness("Rock", ["Fire", "Flying"]) == 4, "Double weakness")
	check(Dex.effectiveness("Grass", ["Fire", "Flying"]) == 0.25, "Double resistance")
	check(Dex.effectiveness("Electric", ["Water", "Ground"]) == 0, "Immunity beats weakness")
	pick(25, 7)
	var special = {"type": "Electric", "category": "Special"}
	var expected = snappedf(10.0 * 100.0 / 114.0 * 1.5 * 2.0, 0.1)
	check(is_equal_approx(damage_amount(player, enemy, 10, special), expected), "SpA / SpD and STAB formula")
	var old_hp: float = enemy.hp
	hit(enemy, 10, Vector2.RIGHT, true, special)
	check(enemy.hp < old_hp, "Damage applied")
	var damaged_hp: float = enemy.hp
	hit(enemy, 10, Vector2.RIGHT, true, special)
	check(enemy.hp == damaged_hp, "Invulnerability blocks repeated damage")
	pick(25, 27)
	check(hit(enemy, 40, Vector2.RIGHT, true, special) == 0, "Ground immune to Electric")
	apply_status(enemy, player.data.moves[3])
	check(enemy.stun == 0, "Ground immune to Thunder Wave")
	pick(150, 113)
	var physical_damage = damage_amount(player, enemy, 30, {"type": "Normal", "category": "Physical"})
	var special_damage = damage_amount(player, enemy, 30, {"type": "Normal", "category": "Special"})
	check(physical_damage > special_damage, "Chansey's separate defenses affect combat")
	pick(25, 4)
	player.energy = 0
	check(not use_move(player, enemy, 0, Vector2.RIGHT, true), "Energy blocks attacks")
	player.energy = 100
	var sprint_start: Vector2 = player.pos
	sprint_movement(Vector2.RIGHT, 0.1, true)
	check(player.inv == 0 and player.dash_time == 0 and is_equal_approx(player.energy, 98.8), "Sprint consumes stamina without dash or invulnerability")
	check(is_equal_approx(player.pos.x - sprint_start.x, player.data.speed * 1.35 * 0.1), "Sprint is 35 percent faster")
	move_fighter(player, Vector2(-9999, -9999))
	check(FIELD.has_point(player.pos), "Arena bounds")
	check(FIELD.get_area() > 2.0 * 1128 * 440, "Arena has more than twice the original playable area")
	check(screen_to_arena(world_origin() + FIELD.get_center() * ARENA_SCALE).is_equal_approx(FIELD.get_center()), "Mouse aim matches enlarged field transform")
	player.hp = 0
	update_battle(1.0 / 60)
	check(result == "DEFEAT", "Round ends")
	type_tests()
	faint_tests()
	trainer_tests()
	style_tests()
	control_tests()
	condition_tests()
	persistent_attack_tests()
	skills.tests(self)
	weather.tests(self)
	league.tests(self)
	fields.tests(self)
	sound.stop()
	sound.stream = null
	if test_failures.is_empty(): print("PASS: major statuses, secondary effects, immunity, stat stages, 1s action gate, charging/recovery, 158 species, sprint, switching, team exhaustion, combat, AI and trainers")
	else: print("FAILED: ", test_failures)
	get_tree().quit(0 if test_failures.is_empty() else 1)

func type_tests():
	for i in range(roster.size()):
		for slot in range(4):
			pick(int(roster[i].id), 143)
			player.hp = player.data.hp * 0.4
			enemy.pos = player.pos + Vector2(70, 0)
			var move: Dictionary = player.data.moves[slot]
			check(use_move(player, enemy, slot, Vector2.RIGHT, true), "Move usable: " + roster[i].name + " / " + move.name)
			check(cooldowns[slot] > 0, "Move has cooldown")
			check(not use_move(player, enemy, slot, Vector2.RIGHT, true), "Repeat blocked by cooldown")
			if move.kind == "heal": check(player.hp > player.data.hp * 0.4, "Heal restores HP")
			if move.kind == "guard": check(player.guard > 0 or not player.stages.is_empty(), "Guard or defense stages enabled")
			if move.kind == "buff": check(player.boost > 0, "Buff enabled")
		pick(143, int(roster[i].id))
		for frame in range(120):
			update_battle(1.0 / 60)
			update_effects(1.0 / 60)
		check(player.hp >= 0 and enemy.hp >= 0, "AI simulation: " + roster[i].name)
	pick(132, 6)
	var ditto_max: float = player.data.hp
	use_move(player, enemy, 0, Vector2.RIGHT, true)
	check(player.transformed and player.data.id == 6 and player.data.hp == ditto_max, "Ditto copies opponent and retains maximum HP")
	check(player.data.moves[0].id == enemy.data.moves[0].id, "Ditto copies moves")
	reset()
	check(player.data.id == 132 and not player.transformed, "Transform does not mutate roster")
	pick(25, 7)
	var normal_move = {"type": "Normal", "category": "Physical"}
	var regular_damage = damage_amount(player, enemy, 20, normal_move)
	enemy.guard = 3
	check(absf(damage_amount(player, enemy, 20, normal_move) * 2 - regular_damage) < 0.2, "Guard halves actual damage")
	apply_status(enemy, {"id": "toxic", "type": "Poison", "effect": "poison"})
	var hp_before_dot: float = enemy.hp
	for frame in range(70): update_battle(1.0 / 60)
	check(enemy.hp < hp_before_dot and enemy.ailment == "poison", "Poison damages over time")
	pick(37, 4)
	apply_status(enemy, {"id": "willowisp", "type": "Fire", "effect": "burn"})
	check(enemy.ailment == "", "Fire immune to burn")
	pick(25, 81)
	apply_status(enemy, {"id": "toxic", "type": "Poison", "effect": "poison"})
	check(enemy.ailment == "", "Steel immune to poison")
	pick(143, 821)
	rocks.clear()
	var starting_distance: float = player.pos.distance_to(enemy.pos)
	for frame in range(300): update_battle(1.0 / 60)
	check(player.pos.distance_to(enemy.pos) < starting_distance - 200, "Contact-only AI approaches instead of waiting at range")
	pick(25, 7)
	var contact = {"type": "Normal", "category": "Physical"}
	var before_projectile: float = enemy.hp
	projectile(enemy.pos - Vector2(40, 0), Vector2.RIGHT, 300, 14, 7, true, GOLD, contact)
	update_battle(1.0 / 60)
	check(enemy.hp < before_projectile, "Projectile collision still deals damage")
	query = "mew"
	check(filtered_roster().size() == 2, "Search matches Mew and Mewtwo")
	query = "does-not-exist"
	check(filtered_roster().is_empty(), "Empty search")
	query = ""
	type_filter.select(Dex.TYPES.find("Steel") + 1)
	var matches = filtered_roster()
	check(Dex.find_id(roster, 81) in matches and Dex.find_id(roster, 599) in matches, "Dual type filtering")
	type_filter.select(0)
	region_filter.select(2)
	check(filtered_roster().size() == 7, "Retained extras filter")
	region_filter.select(1)
	check(filtered_roster().size() == 151, "Gen 1 filter")
	region_filter.select(0)
	page = 8
	select_enemy = false
	selection_click(Vector2(60, 180), MOUSE_BUTTON_LEFT)
	check(player_index == 144, "Pagination selects correct species")
	selection_click(Vector2(260, 180), MOUSE_BUTTON_RIGHT)
	check(enemy_index == 145, "Right click selects CPU on correct page")
	change_page(1)
	check(page == 0, "Last page wraps")
	start_match()
	check(not selecting and player.data.id == 145 and enemy.data.id == 146, "Start match uses selections")

func capture_preview():
	player_index = Dex.find_id(roster, 6)
	enemy_index = Dex.find_id(roster, 9)
	reset()
	selecting = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://captures")
	get_viewport().get_texture().get_image().save_png("res://captures/roster-gen1.png")
	page = 8
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/roster-extras.png")
	start_match()
	countdown = 0
	use_move(player, enemy, 0, Vector2.RIGHT, true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/battle-gen1.png")
	get_tree().quit()

func faint_tests():
	pick(6, 9)
	enemy.hp = 0
	update_battle(1.0 / 60)
	check(result == "VICTORY" and enemy.fainted and not player.fainted, "Enemy faint starts victory sequence")
	check(result_time == 0 and result_time < FAINT_RESULT_TIME, "Result overlay waits for animation")
	var old_pos: Vector2 = player.pos
	check(not use_move(player, enemy, 0, Vector2.RIGHT, true), "Attacks blocked during faint")
	update_battle(0.5)
	check(player.pos == old_pos and shots.is_empty(), "Battle freezes during faint")
	check(faint_pose(0.2).fall > 0 and faint_pose(0.2).fall < 1, "Forward fall interpolates")
	check(faint_pose(0.45).black and not faint_pose(0.56).black, "Alternates black and normal")
	check(faint_pose(1.85).alpha > 0 and faint_pose(1.85).alpha < 1, "Fades after blinking")
	check(not faint_pose(FAINT_HIDE_TIME).visible, "Fainted sprite disappears completely")
	paused = true
	_process(0.5)
	check(result_time == 0, "Pause freezes faint animation")
	paused = false
	_process(FAINT_RESULT_TIME)
	check(result_time == FAINT_RESULT_TIME, "Animation advances to result")
	reset()
	check(result == "" and result_time == 0 and not enemy.fainted, "Rematch restores sprite and animation state")
	pick(6, 9)
	player.hp = 0
	update_battle(0.01)
	check(result == "DEFEAT" and player.fainted and not enemy.fainted, "Player also faints")
	pick(6, 9)
	player.hp = 0
	enemy.hp = 0
	finish_round()
	check(result == "DRAW" and player.fainted and enemy.fainted, "Simultaneous faint handles both")

func capture_faint():
	set_process(false)
	pick(6, 9)
	selection_controls.visible = false
	enemy.hp = 0
	finish_round()
	DirAccess.make_dir_recursive_absolute("res://captures")
	for time in [0.2, 0.45, 0.56, 1.85, 2.2]:
		result_time = time
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/faint-%.2f.png" % time)
	pick(6, 9)
	player.hp = 0
	finish_round()
	result_time = 0.45
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/faint-player.png")
	get_tree().quit()

func trainer_tests():
	check(summon_progress(0.6) == 0, "Pokémon stays inside ball during throw")
	check(summon_progress(1.4) > 0 and summon_progress(1.4) < 1, "Pokémon grows out of release flash")
	check(summon_progress(SUMMON_END_TIME) == 1, "Pokémon fully appears before combat")
	check(recall_progress(1.0) == 0 and recall_progress(FAINT_HIDE_TIME) == 1, "Recall starts after faint and ends at trainer")
	for friendly in [true, false]:
		var destination = FIELD.size * Vector2(0.34 if friendly else 0.66, 0.5) + Vector2(0, -35)
		check(throw_position(friendly, destination, 0.25).is_equal_approx(trainer_hand(friendly)), "Throw starts in trainer hand")
		check(throw_position(friendly, destination, BALL_RELEASE_TIME).is_equal_approx(destination), "Thrown ball reaches Pokémon spawn")
	pick(6, 9)
	reset()
	var before: Vector2 = enemy.pos
	_process(0.4)
	check(enemy.pos == before and round_time == 0 and shots.is_empty(), "No combat during send-out")
	paused = true
	var timer_before = countdown
	_process(0.5)
	check(countdown == timer_before, "Pause freezes send-out")
	paused = false
	reset()
	check(countdown == SEND_OUT_TIME and result_time == 0, "Rematch replays ball sequence")

func capture_trainers():
	set_process(false)
	pick(6, 9)
	selection_controls.visible = false
	DirAccess.make_dir_recursive_absolute("res://captures")
	for time in [0.0, 0.6, 1.4, 2.2]:
		countdown = SEND_OUT_TIME - time
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/send-out-%.1f.png" % time)
	countdown = 0
	enemy.hp = 0
	finish_round()
	result_time = 2.1
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/trainer-recall.png")
	get_tree().quit()

func enemy_party_size() -> int:
	return enemy_party.size() if not enemy_party.is_empty() else enemy_team.size()

func opponent_name() -> String:
	if adventure.in_battle:
		return {"wild":"Wild Pokemon","rival":"Blue","bug":"Bug Catcher","brock":"Brock","lass":"Lass","rocket":"Team Rocket Grunt","misty":"Misty"}.get(adventure.encounter.kind,"Trainer")
	for trainer in league.trainers:
		if trainer.id == opponent_identity: return trainer.name
	return opponent_identity.split("_")[0].capitalize()

func can_continue_team() -> bool:
	if not team_mode or result == "": return false
	return (player.hp > 0 or has_player_reserve()) and (enemy.hp > 0 or enemy_bench.reserve(self)>=0)

func replacement(friendly: bool, index: int) -> Dictionary:
	var fighter: Dictionary = (player if friendly else enemy).duplicate(true)
	fighter.data = enemy_party[enemy_active].duplicate(true) if not friendly and not enemy_party.is_empty() else roster[index].duplicate(true)
	if not friendly and enemy_party.is_empty() and not adventure.in_battle: fighter.data = move_editor.configured(fighter.data,false,enemy_active)
	fighter.hp = fighter.data.hp
	fighter.energy = 100.0
	fighter.pos = FIELD.size * Vector2(0.34 if friendly else 0.66, 0.5)
	fighter.face = 1.0 if friendly else -1.0
	for key in ["inv", "flash", "dash_time", "stun", "guard", "boost", "ailment_time", "dot_tick", "anim_age", "attack_time", "walk_time"]: fighter[key] = 0.0
	fighter.ailment = ""
	fighter.dash = Vector2.ZERO
	fighter.dash_move = {}
	fighter.fainted = false
	fighter.transformed = false
	fighter.entering = true
	fighter.heading = Vector2(fighter.face, 0)
	Conditions.init(fighter)
	fighter.erase("last_move")
	fighter.erase("last_physical_time")
	fighter.erase("last_physical_damage")
	return fighter

func advance_team():
	if adventure.in_battle: adventure.record_knockout()
	player.entering = false
	enemy.entering = false
	if player.hp <= 0:
		player_states[player_active] = player
		activate_player(next_player_reserve())
		sprinting = false
	if enemy.hp <= 0:
		enemy_bench.activate(self,enemy_bench.reserve(self))
	result = ""
	result_time = 0
	fields.intermission(self)
	countdown = SEND_OUT_TIME
	ai_timer = 1.0
	particles.clear()

func draw_team_selection():
	for friendly in [true, false]:
		var team = player_team if friendly else enemy_team
		var party = preview_party if not friendly else []
		var start_x = 40 if friendly else 652
		for i in range(party.size() if not party.is_empty() else 6):
			var mon = party[i] if not party.is_empty() else roster[team[i]]
			var x = start_x + i * 98
			panel(Rect2(x, 806, 92, 50), Color("243c49"), GOLD if i == (opponent_preview_slot if not party.is_empty() else team_slot) else Color("425b68"))
			label_at(str(i + 1), Vector2(x + 5, 822), 11, GOLD)
			var texture = portraits.get(int(mon.id))
			if texture:
				var size = texture.get_size() * 30.0 / maxf(texture.get_width(), texture.get_height())
				draw_texture_rect(texture, Rect2(Vector2(x + 46, 824) - size / 2, size), false)
			label_at(mon.name.left(12), Vector2(x + 4, 850), 10)

func style_tests():
	check(art.library.size() == roster.size(), "Animated sprites for every species")
	for mon in roster:
		check(art.library.has(int(mon.id)), "Animation exists: " + mon.name)
		if not art.library.has(int(mon.id)): continue
		for name in ["Idle", "Walk", "Attack", "Hurt"]:
			check(art.library[int(mon.id)].has(name), "Animation state " + name + ": " + mon.name)
		for anim in art.library[int(mon.id)].values():
			check(anim.durations.size() * int(anim.width) == anim.texture.get_width(), "Animation columns match metadata")
			check(anim.rows == 8 or anim.rows == 1, "Animation has supported directions")
	pick(6, 9)
	player.heading = Vector2.RIGHT
	check(art.frame(player).region.position.y == art.frame(player).region.size.y * 2, "Facing right selects east row")
	player.heading = Vector2.UP
	check(art.frame(player).region.position.y == art.frame(player).region.size.y * 4, "Facing up selects north row")
	team_mode = true
	reset()
	countdown = 0
	player.hp -= 25
	var preserved_hp: float = player.hp
	enemy.hp = 0
	finish_round()
	check(can_continue_team(), "Team with reserves continues")
	result_time = FAINT_RESULT_TIME
	advance_team()
	check(enemy_active == 1 and enemy.hp == enemy.data.hp, "Next rival enters at full HP")
	check(player.hp == preserved_hp and not player.entering, "Survivor keeps HP and stays on field")
	check(countdown == SEND_OUT_TIME and enemy.entering and result == "", "Replacement plays summon before combat resumes")
	countdown = 0
	for state in player_states: state.hp = 0
	player_active = 5
	enemy_active = 5
	for f in enemy_bench.states: f.hp = 0
	player.hp = 0
	enemy.hp = 0
	finish_round()
	check(not can_continue_team() and result == "DRAW", "Last simultaneous faint ends match")
	result = ""
	player_states[0].hp = 10
	finish_round()
	check(result == "VICTORY" and not can_continue_team(), "Simultaneous faint: team with a reserve wins against exhausted team")
	reset()
	for i in range(6):
		countdown = 0
		enemy.hp = 0
		finish_round()
		_process(FAINT_RESULT_TIME + 0.1)
		if i < 5:
			check(result == "" and enemy_active == i + 1 and countdown == SEND_OUT_TIME, "Automatic replacement %d" % i)
		else:
			check(result == "VICTORY" and enemy_active == 5, "Victory only after sixth rival faints")
	selecting = true
	var saved_player = player_team.duplicate()
	var saved_enemy = enemy_team.duplicate()
	selection_click(Vector2(652 + 98 * 2 + 20, 830), MOUSE_BUTTON_LEFT)
	check(team_slot == 2 and select_enemy, "Team chip selects CPU slot")
	selection_click(Vector2(50, 170), MOUSE_BUTTON_LEFT)
	check(enemy_team[2] == filtered_roster()[page * 18], "Roster click edits selected team slot")
	start_match()
	check(enemy.data.id == roster[enemy_team[0]].id, "Battle starts with lead, not editor slot")
	player_team = saved_player
	enemy_team = saved_enemy
	team_slot = 0
	select_enemy = false
	team_mode = false
	check(trainer_position(true).is_equal_approx(FIELD.size * Vector2(0.032, 0.54)) and trainer_position(false).is_equal_approx(FIELD.size * Vector2(0.968, 0.54)), "Trainer positions preserved")

func capture_style():
	set_process(false)
	team_mode = true
	player_team[0] = Dex.find_id(roster, 6)
	enemy_team[0] = Dex.find_id(roster, 9)
	reset()
	player_index = player_team[0]
	enemy_index = enemy_team[0]
	selecting = true
	selection_controls.visible = true
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/style-roster.png")
	selecting = false
	selection_controls.visible = false
	countdown = 0
	player.pos = Vector2(565, 420)
	enemy.pos = Vector2(1000, 320)
	player.heading = Vector2.RIGHT
	enemy.heading = Vector2.LEFT
	player.anim_age = 0.2
	enemy.anim_age = 0.25
	use_move(player, enemy, 2, Vector2.RIGHT, true)
	use_move(enemy, player, 2, Vector2.LEFT, false)
	for shot in shots: shot.pos += shot.vel * 0.3
	scars.append({"pos": Vector2(700, 310), "life": 10.0, "size": 1.2})
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/style-battle.png")
	var effect_types = ["Fire", "Water", "Electric", "Ice", "Ground", "Psychic"]
	for i in range(effect_types.size()):
		impacts.append({"pos": Vector2(250 + i * 190, 570), "type": effect_types[i], "age": 0.25, "life": 0.4, "strength": 1.2})
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/impact-preview.png")
	impacts.clear()
	switch_menu = true
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/switch-menu.png")
	switch_menu = false
	request_switch(2)
	switch_time = 0.35
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/manual-recall.png")
	complete_switch()
	countdown = 0
	enemy.hp = 0
	finish_round()
	result_time = 0.8
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/style-faint.png")
	advance_team()
	countdown = SEND_OUT_TIME - 1.4
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/style-replacement.png")
	get_tree().quit()

func has_player_reserve() -> bool:
	return next_player_reserve() >= 0

func next_player_reserve() -> int:
	for step in range(1, player_states.size()):
		var slot = (player_active + step) % player_states.size()
		if player_states[slot].hp > 0: return slot
	return -1

func activate_player(slot: int):
	click_move = false
	player_active = slot
	player = player_states[slot]
	player.pos = FIELD.size * Vector2(0.34, 0.5)
	player.face = 1.0
	player.heading = Vector2.RIGHT
	player.entering = true
	player.dash = Vector2.ZERO
	player.dash_time = 0
	player.inv = 0
	player.flash = 0
	player.attack_time = 0
	player.walk_time = 0
	player.dash_move = {}
	cooldowns = player.get("saved_cooldowns", [0.0, 0.0, 0.0, 0.0]).duplicate()
	quick_attack_active = false
	sprinting = false

func request_switch(slot: int) -> bool:
	if not team_mode or paused or countdown > 0 or result != "" or switch_time >= 0 or enemy_bench.timer>=0: return false
	if slot < 0 or slot >= player_states.size() or slot == player_active or player_states[slot].hp <= 0: return false
	if player.get("charge_left", 0.0) > 0 or player.get("volatile", {}).get("partiallytrapped", 0) > 0 or player.get("volatile",{}).get("airborne",0)>0 or player.get("volatile",{}).get("underground",0)>0:
		Conditions.note(player, "CANNOT SWITCH")
		return false
	if switch_cooldown > 0:
		notice = "SWITCH READY IN %.1fs" % switch_cooldown
		notice_time = 1.5
		return false
	player["saved_cooldowns"] = cooldowns.duplicate()
	player_states[player_active] = player
	player.volatile.clear()
	player.stages.clear()
	player.toxic_tick = 0
	player.attack_time = 0
	player.walk_time = 0
	player.dash_time = 0
	quick_attack_active = false
	sprinting = false
	switch_target = slot
	switch_time = 0
	switch_menu = false
	shots.clear()
	rings.clear()
	impacts.clear()
	player.entering = false
	enemy.entering = false
	tone(720, 0.15)
	return true

func complete_switch():
	activate_player(switch_target)
	switch_time = -1
	switch_target = -1
	switch_cooldown = 4.0
	countdown = SEND_OUT_TIME
	ai_timer = 1.0
	particles.clear()

func switch_input(event):
	if controls.matches(event,"switch") or (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE): switch_menu=false
	for i in range(6):
		if controls.matches(event,"slot"+str(i+1)): request_switch(i)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse = get_global_mouse_position()
		for i in range(6):
			if switch_card(i).has_point(mouse): request_switch(i)

func switch_card(slot: int) -> Rect2:
	return Rect2(260 + (slot % 2) * 390, 280 + (slot / 2) * 125, 370, 110)

func draw_switch_menu():
	draw_rect(Rect2(0, 0, 1280, 960), Color(0.02, 0.04, 0.08, 0.88))
	label_at("CHOOSE YOUR POKÉMON", Vector2(390, 220), 30, GOLD)
	label_at("Battle paused • Click a Pokemon to switch • "+controls.text("switch")+" / Esc to return", Vector2(370, 252), 15)
	for i in range(player_states.size()):
		var f: Dictionary = player_states[i]
		var rect = switch_card(i)
		var accent = MINT if i == player_active else GOLD if f.hp > 0 else Color("546574")
		panel(rect, Color("172c3b"), accent)
		var texture = portraits.get(int(f.data.id))
		var size = texture.get_size() * 60.0 / maxf(texture.get_width(), texture.get_height())
		draw_texture_rect(texture, Rect2(rect.position + Vector2(48, 52) - size / 2, size), false, Color.WHITE if f.hp > 0 else Color(0.3, 0.3, 0.3))
		label_at("%d  %s" % [i + 1, f.data.name], rect.position + Vector2(90, 28), 20, accent)
		label_at("ACTIVE" if i == player_active else "FAINTED" if f.hp <= 0 else Dex.type_label(f.data), rect.position + Vector2(90, 51), 12, accent)
		bar(rect.position + Vector2(90, 65), 245, f.hp / f.data.hp, MINT, 8)
		label_at("HP %d / %d     ENERGY %d" % [f.hp, f.data.hp, f.energy], rect.position + Vector2(90, 94), 12)
	label_at("Switch ready in %.1fs of battle • B to resume" % switch_cooldown if switch_cooldown > 0 else "Recall and send out • HP and energy are preserved", Vector2(390, 690), 15, GOLD)

func draw_switch_recall():
	var progress = smoothstep(0.0, 0.7, switch_time)
	var hand = trainer_hand(true)
	var center: Vector2 = (player.pos + Vector2(0, -24)).lerp(hand, progress)
	var frame = art.frame(player)
	var size: Vector2 = frame.size * (1 - progress)
	draw_line(hand, center, Color(1, 0.15, 0.3, 0.22), 14)
	draw_line(hand, center, Color(1, 0.5, 0.5, 0.8), 3)
	if progress < 0.99:
		draw_texture_rect_region(frame.texture, Rect2(center - size / 2, size), frame.region, Color(1, 0.2, 0.3, 1 - progress))
	draw_pokeball(hand, 7, true)

func control_tests():
	pick(6, 9)
	var headings = [Vector2.DOWN, Vector2(1, 1), Vector2.RIGHT, Vector2(1, -1), Vector2.UP, Vector2(-1, -1), Vector2.LEFT, Vector2(-1, 1)]
	for i in range(8):
		player.heading = headings[i]
		check(art.frame(player).region.position.y == art.frame(player).region.size.y * i, "Sprite sheet direction %d" % i)
	var before: Vector2 = player.pos
	sprint_movement(Vector2.ZERO, 0.1, true)
	check(player.pos == before and not sprinting, "Space without movement never lunges toward mouse")
	sprint_movement(Vector2.DOWN, 0.1, true)
	check(player.pos.y > before.y and player.dash_time == 0 and player.inv == 0, "Sprint can steer and grants no invulnerability")
	team_mode = true
	reset()
	countdown = 0
	player.hp = 50
	player.energy = 35
	cooldowns[0] = 2.0
	check(not request_switch(0), "Cannot switch to active member")
	check(request_switch(2), "Can request healthy reserve")
	var enemy_pos: Vector2 = enemy.pos
	_process(0.3)
	check(enemy.pos == enemy_pos and switch_time > 0 and player_active == 0, "Recall freezes battle before replacement")
	paused = true
	var before_time = switch_time
	_process(0.3)
	check(switch_time == before_time, "Pause freezes manual recall")
	paused = false
	_process(0.5)
	check(player_active == 2 and countdown == SEND_OUT_TIME and not enemy.entering, "Chosen slot summons while opponent stays")
	countdown = 0
	check(not request_switch(0), "Switch cooldown prevents repeated switching")
	switch_cooldown = 0
	check(request_switch(0), "Can return to earlier slot")
	complete_switch()
	check(player.hp == 50 and player.energy == 35 and cooldowns[0] == 2.0, "Switch preserves HP, energy and move cooldowns")
	countdown = 0
	switch_cooldown = 0
	player_states[1].hp = 0
	check(not request_switch(1), "Cannot send fainted teammate")
	player.hp = 0
	finish_round()
	advance_team()
	check(player_active == 2, "Automatic replacement skips fainted teammates after manual switches")
	countdown = 0
	switch_menu = true
	before_time = round_time
	_process(1.0)
	check(round_time == before_time, "Team menu pauses battle")
	switch_menu = false
	team_mode = false

func draw_conditions(f):
	var p: Vector2 = f.pos
	var text = Conditions.summary(f)
	if text != "":
		var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_rect(Rect2(p + Vector2(-width / 2 - 5, -85), Vector2(width + 10, 19)), Color(0.06, 0.1, 0.18, 0.9))
		label_at(text, p + Vector2(-width / 2, -71), 12, GOLD)
	if f.get("condition_note_time", 0) > 0: label_at(f.condition_note, p + Vector2(-40, -125), 13, WHITE)
	match f.ailment:
		"sleep":
			for i in range(3): label_at("Z", p + Vector2(15 + i * 9, -55 - i * 15 - sin(clock_time * 3 + i) * 4), 13 + i * 3, Color("b0c6f4"))
		"freeze":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-30, 8), p + Vector2(-34, -42), p + Vector2(0, -70), p + Vector2(34, -42), p + Vector2(30, 8)]), Color(0.5, 0.9, 1, 0.32))
			draw_line(p + Vector2(-25, -45), p + Vector2(18, 4), Color("c5f6ff"), 2)
		"paralysis":
			for i in range(3):
				var point = p + Vector2(sin(clock_time * 18 + i * 2) * 32, -i * 22)
				draw_polyline(PackedVector2Array([point, point + Vector2(8, -12), point + Vector2(-3, -10), point + Vector2(5, -24)]), GOLD, 2)
		"burn", "poison", "toxic":
			for i in range(4):
				var phase = fposmod(clock_time * 0.9 + i * 0.25, 1)
				var point = p + Vector2(sin(i * 7) * 25, -phase * 70)
				draw_circle(point, 3 + phase * 4, Color(Color("ff9e52") if f.ailment == "burn" else Color("d18eea"), 1 - phase))
	if f.get("volatile", {}).get("confusion", 0) > 0:
		for i in range(3):
			var point = p + Vector2(cos(clock_time * 4 + i * TAU / 3) * 25, -62 + sin(clock_time * 4 + i * TAU / 3) * 8)
			draw_circle(point, 4, Color("ef9ff4"))
	if f.get("charge_left", 0) > 0:
		var color: Color = f.get("move_color", GOLD)
		draw_arc(p + Vector2(0, -25), 40, clock_time * 4, clock_time * 4 + TAU * (1 - f.charge_left), 40, color, 3)
		for i in range(8):
			var ray = Vector2.from_angle(i * TAU / 8 + clock_time) * (20 + f.charge_left * 45)
			draw_circle(p + Vector2(0, -25) + ray, 3, color)
		label_at("CHARGE %.1fs" % f.charge_left, p + Vector2(-35, -100), 13, color)

func condition_tests():
	pick(25, 7)
	check(use_move(player, enemy, 0, Vector2.RIGHT, true), "First move accepted")
	check(not use_move(player, enemy, 2, Vector2.RIGHT, true), "Global gate blocks different move")
	Conditions.tick(player, 0.99)
	check(not use_move(player, enemy, 2, Vector2.RIGHT, true), "Global gate lasts full second")
	Conditions.tick(player, 0.011)
	check(use_move(player, enemy, 2, Vector2.RIGHT, true), "Different move allowed after one second")
	check(use_move(enemy, player, 0, Vector2.LEFT, false), "CPU first move accepted")
	check(not use_move(enemy, player, 1, Vector2.LEFT, false), "CPU shares same global rule")
	pick(25, 7)
	player.data.moves[0]["requires_recharge"] = true
	player.data.moves[0]["action_delay"] = 2.0
	use_move(player, enemy, 0, Vector2.RIGHT, true)
	Conditions.tick(player, 1.1)
	check(not use_move(player, enemy, 2, Vector2.RIGHT, true), "Recharge move blocks all moves beyond one second")
	Conditions.tick(player, 0.91)
	check(use_move(player, enemy, 2, Vector2.RIGHT, true), "Recharge move unlocks after two seconds")
	pick(3, 9)
	ai_timer = 999
	check(use_move(player, enemy, 2, Vector2.RIGHT, true), "Solar Beam starts charge")
	check(shots.is_empty() and player.charge_left == 1, "No projectile before charging")
	var before: Vector2 = player.pos
	sprint_movement(Vector2.RIGHT, 0.1, true)
	check(player.pos == before, "Charging holds position even with sprint")
	update_battle(0.5)
	check(shots.is_empty(), "Charge not released early")
	update_battle(0.5)
	check(shots.size() == 1 and player.action_lock == 2, "Charge releases then requires two seconds recovery")
	check(not use_move(player, enemy, 0, Vector2.RIGHT, true), "Other moves blocked after Solar Beam")
	Conditions.tick(player, 2)
	check(use_move(player, enemy, 0, Vector2.RIGHT, true), "Normal move after recovery")
	pick(25, 7)
	var sleep_move = {"id": "hypnosis", "type": "Psychic", "status": "slp"}
	apply_status(enemy, sleep_move)
	check(enemy.ailment == "sleep" and enemy.ailment_time >= 2.0 and enemy.ailment_time <= 3.0, "Hypnosis applies 2–3 second sleep")
	check(Conditions.speed(enemy) == 0 and not Conditions.attempt(self, enemy, {}), "Sleep stops movement and actions")
	Conditions.tick(enemy, 5.1)
	check(enemy.ailment == "" and Conditions.speed(enemy) > 0, "Sleep expires")
	Conditions.apply(self, enemy, {"status": "par"}, {})
	check(Conditions.speed(enemy) == 0.5, "Paralysis halves speed")
	var failures = 0
	rng.seed = 991
	for i in range(1000):
		if not Conditions.attempt(self, enemy, {}): failures += 1
	check(failures > 200 and failures < 300, "Paralysis failure rate near 25 percent")
	check(not Conditions.apply(self, enemy, {"status": "slp"}, sleep_move), "Major statuses do not overwrite each other")
	pick(25, 7)
	Conditions.apply(self, enemy, {"status": "brn"}, {})
	var hp: float = enemy.hp
	Conditions.tick(enemy, 2.5)
	check(is_equal_approx(hp - enemy.hp, enemy.data.hp * 0.04), "Burn ticks twice across variable delta")
	var burnt = damage_amount(enemy, player, 20, {"type": "Normal", "category": "Physical"})
	enemy.ailment = ""
	check(absf(damage_amount(enemy, player, 20, {"type": "Normal", "category": "Physical"}) - burnt * 2) < 0.2, "Burn halves physical damage")
	Conditions.apply(self, enemy, {"status": "tox"}, {})
	hp = enemy.hp
	Conditions.tick(enemy, 3)
	check(is_equal_approx(hp - enemy.hp, enemy.data.hp * 0.06), "Toxic ramps 1+2+3 percent")
	pick(25, 7)
	Conditions.apply(self, enemy, {"status": "frz"}, {})
	check(Conditions.speed(enemy) == 0, "Freeze immobilizes")
	hit(enemy, 10, Vector2.RIGHT, true, {"type": "Fire", "category": "Special"})
	check(enemy.ailment == "", "Fire hit thaws freeze")
	pick(25, 7)
	Conditions.apply(self, enemy, {"volatileStatus": "confusion"}, {})
	failures = 0
	for i in range(300):
		enemy.hp = enemy.data.hp
		if not Conditions.attempt(self, enemy, {}): failures += 1
	check(failures > 70 and failures < 130, "Confusion sometimes replaces attack with self damage")
	Conditions.apply(self, enemy, {"boosts": {"spe": -2, "accuracy": -1}}, {})
	check(Conditions.speed(enemy) == 0.5 and Conditions.stage(enemy, "accuracy") < 1, "Speed and accuracy reductions are distinct")
	Conditions.apply(self, enemy, {"volatileStatus": "flinch"}, {})
	check(Conditions.immobilized(enemy), "Flinch interrupts movement and action")
	Conditions.tick(enemy, 0.5)
	check(not Conditions.immobilized(enemy), "Flinch recovers")
	pick(25, 81)
	check(not Conditions.apply(self, enemy, {"status": "par"}, {}), "Electric immune to paralysis")
	check(not Conditions.apply(self, enemy, {"status": "tox"}, {}), "Steel immune to Toxic")
	pick(25, 144)
	check(not Conditions.apply(self, enemy, {"status": "frz"}, {}), "Ice immune to freeze")
	pick(25, 1)
	check(not Conditions.apply(self, enemy, {"status": "slp"}, {"powder": true}), "Grass immune to sleep powder")
	pick(25, 7)
	apply_hit_effects(player, enemy, {"secondaries": [{"chance": 100, "status": "par"}]})
	check(enemy.ailment == "paralysis", "Damaging move secondary applies")
	pick(143, 7)
	player.hp = 10
	player.ailment = "poison"
	player.ailment_time = 5
	check(use_move(player, enemy, 3, Vector2.RIGHT, true), "Rest usable")
	check(player.hp == player.data.hp and player.ailment == "sleep" and player.ailment_time == 2.5, "Rest cures major status and heals at cost of sleep")
	pick(25, 7)
	team_mode = true
	reset()
	countdown = 0
	Conditions.apply(self, player, {"volatileStatus": "partiallytrapped"}, {})
	check(not request_switch(1), "Trapping blocks manual switching")
	Conditions.tick(player, 6)
	check(request_switch(1), "Switch allowed after trap expires")
	complete_switch()
	team_mode = false

func capture_status():
	set_process(false)
	pick(3, 94)
	selection_controls.visible = false
	player.pos = Vector2(500, 400)
	enemy.pos = Vector2(950, 350)
	use_move(player, enemy, 2, Vector2.RIGHT, true)
	player.charge_left = 0.6
	Conditions.apply(self, enemy, {"status": "slp"}, {})
	enemy.ailment_time = 3.0
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/status-charge-sleep.png")
	player.charge_left = 0
	player.pending_move = {}
	player.action_lock = 2.0
	Conditions.apply(self, player, {"status": "par"}, {})
	enemy.ailment = ""
	Conditions.apply(self, enemy, {"status": "brn", "volatileStatus": "confusion"}, {})
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/status-paralysis-burn.png")
	get_tree().quit()

func capture_polish():
	set_process(false)
	pick(6, 9)
	selection_controls.visible = false
	clock_time = 1.3
	player.pos = FIELD.size * Vector2(0.36, 0.54)
	enemy.pos = FIELD.size * Vector2(0.65, 0.42)
	player.heading = Vector2.RIGHT
	enemy.heading = Vector2.LEFT
	use_move(player, enemy, 2, Vector2.RIGHT, true)
	use_move(enemy, player, 2, Vector2.LEFT, false)
	for shot in shots:
		shot.pos += shot.vel * 0.55
		shot.age = 0.55
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/champion-polish.png")
	reset()
	countdown = SEND_OUT_TIME - 0.6
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/trainers-polish.png")
	get_tree().quit()

func resolution_ready() -> bool:
	if result == "" or not shots.is_empty(): return false
	for fighter in [player, enemy]:
		if fighter.get("fainted", false) and result_time < fighter.get("faint_delay", 0.0) + FAINT_RESULT_TIME - 0.00001: return false
	return result_time >= FAINT_RESULT_TIME - 0.00001

func update_resolution(delta: float):
	var left = delta
	while left > 0.00001 and not resolution_ready():
		var dt = minf(left, 0.04)
		left -= dt
		for fighter in [player, enemy]:
			fighter.inv = maxf(0, fighter.inv - dt)
			fighter.flash = maxf(0, fighter.flash - dt)
			fighter.guard = maxf(0, fighter.guard - dt)
		update_projectiles(dt)
		var until = FAINT_RESULT_TIME
		for fighter in [player, enemy]:
			if fighter.hp <= 0 and not fighter.get("fainted", false):
				fighter.fainted = true
				fighter["faint_delay"] = result_time
				fighter["faint_frame"] = art.frame(fighter)
				fighter.dash_time = 0
				fighter.attack_time = 0
				fighter.walk_time = 0
				fighter.charge_left = 0
				fighter.pending_move = {}
				fighter.face = (1.0 if fighter == player else -1.0) if fighter.face == 0 else fighter.face
				burst(fighter.pos, Color("b4a47a"), 12)
			until = maxf(until, fighter.get("faint_delay", 0.0) + FAINT_RESULT_TIME)
		result_time = minf(until, result_time + dt)
		if is_equal_approx(result_time, until): result_time = until
		var player_out = player.hp <= 0 and (not team_mode or not has_player_reserve())
		var enemy_out = enemy.hp <= 0 and (not team_mode or enemy_bench.reserve(self)<0)
		result = "DRAW" if player_out and enemy_out else "DEFEAT" if player_out else "VICTORY" if enemy_out else "SWITCH"

func persistent_attack_tests():
	pick(25, 7)
	rocks.clear()
	player.pos = Vector2(400, 400)
	enemy.pos = Vector2(700, 400)
	var move = {"type": "Electric", "category": "Special", "drain": true}
	var expected = damage_amount(player, enemy, 20, move)
	projectile(player.pos, Vector2.RIGHT, 300, 20, 7, true, GOLD, move)
	player.hp = 0
	var hp: float = enemy.hp
	finish_round()
	check(shots.size() == 1, "Knockout preserves launched projectile")
	check(not resolution_ready(), "Result waits for in-flight attack")
	player.data.base_stats.spa = 999
	update_resolution(1.2)
	check(is_equal_approx(hp - enemy.hp, expected), "Posthumous damage uses launch stats")
	check(player.hp == 0, "Drain cannot revive a fainted caster")
	check(shots.is_empty(), "Projectile resolves on hit")
	update_resolution(4)
	check(result == "DEFEAT" and resolution_ready(), "Nonlethal late hit resolves original outcome")
	pick(25, 7)
	rocks.clear()
	player.pos = Vector2(400, 400)
	enemy.pos = Vector2(700, 400)
	enemy.hp = 1
	projectile(player.pos, Vector2.RIGHT, 300, 40, 7, true, GOLD, move)
	player.hp = 0
	finish_round()
	update_resolution(1.2)
	check(enemy.hp == 0 and result == "DRAW", "Late projectile produces double knockout")
	check(enemy.get("faint_delay", 0.0) > 0 and not resolution_ready(), "Second faint gets its own full animation")
	update_resolution(4)
	check(resolution_ready(), "Draw waits for both recalls")
	pick(25, 7)
	rocks.clear()
	projectile(Vector2(600, 600), Vector2.DOWN, 30, 20, 7, true, GOLD, move)
	player.hp = 0
	finish_round()
	paused = true
	var before: Vector2 = shots[0].pos
	_process(0.5)
	check(shots[0].pos == before and result_time == 0, "Pause freezes lingering attacks")
	paused = false
	update_resolution(4)
	check(shots.is_empty() and resolution_ready(), "Missed attack expires without blocking result")
	team_mode = true
	reset()
	countdown = 0
	rocks.clear()
	player.pos = Vector2(400, 400)
	enemy.pos = Vector2(700, 400)
	enemy.hp = 1
	projectile(player.pos, Vector2.RIGHT, 300, 40, 7, true, GOLD, move)
	player.hp = 0
	finish_round()
	_process(1.2)
	check(player_active == 0 and enemy_active == 0 and enemy.hp == 0, "Team replacement waits for old attacks")
	_process(4)
	check(player_active == 1 and enemy_active == 1 and result == "", "Both teams replace after late double knockout")
	team_mode = false

func capture_persistent():
	set_process(false)
	pick(6, 9)
	selection_controls.visible = false
	rocks.clear()
	player.pos = Vector2(620, 460)
	enemy.pos = Vector2(1080, 460)
	enemy.hp = 1
	projectile(player.pos, Vector2.RIGHT, 300, 50, 18, true, Dex.color("Fire"), player.data.moves[2])
	player.hp = 0
	finish_round()
	update_resolution(0.7)
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/attack-after-knockout.png")
	update_resolution(1.0)
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/late-double-knockout.png")
	get_tree().quit()

func capture_skills():
	set_process(false)
	selection_controls.visible = false
	selecting = false
	paused = false
	DirAccess.make_dir_recursive_absolute("res://captures")
	for entry in [[3, "solarbeam", "solar-warning", -1.0], [3, "solarbeam", "solar-beam", 0.12], [134, "surf", "surf-wave", 0.5], [6, "flamethrower", "sun-flamethrower", 0.2], [9, "hydropump", "rain-hydropump", 0.2], [28, "rockslide", "sand-rockslide", 0.8], [149, "hurricane", "rain-hurricane", 0.8], [87, "icebeam", "hail-icebeam", 0.2], [150, "psystrike", "cavern-psystrike", 0.85], [151, "psychic", "cavern-psychic-charge", 0.5], [25, "thunderbolt", "thunder-warning", 0.5], [25, "thunderbolt", "thunder-strike", 0.8]]:
		pick(entry[0], 6)
		weather.set_weather("sun" if entry[2].begins_with("sun-") else "rain" if entry[2].begins_with("rain-") else "sand" if entry[2].begins_with("sand-") else "hail" if entry[2].begins_with("hail-") else "clear")
		countdown = 0
		player.entering = false
		enemy.entering = false
		player.pos = Vector2(650, 600)
		enemy.pos = Vector2(1200, 600)
		rocks.clear()
		if entry[2].begins_with("cavern-"):
			player.pos = Vector2(300,340)
			enemy.pos = Vector2(800,420)
		update_camera(10)
		var move: Dictionary = {}
		for mon in roster:
			for candidate in mon.moves:
				if candidate.id == entry[1]: move = candidate.duplicate(true)
		if entry[3] < 0:
			player.charge_left = 0.7
			player.pending_move = {"move": move, "direction": Vector2.RIGHT, "friendly": true}
		else:
			skills.launch(self, player, enemy, move, Vector2.RIGHT, true)
			if entry[1] in ["thunderbolt", "hurricane", "rockslide", "psychic", "psystrike"]: shots.back().pos = enemy.pos
			var remaining: float = entry[3]
			while remaining > 0:
				skills.tick(self, shots.back(), minf(remaining, 0.02))
				remaining -= 0.02
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/" + entry[2] + ".png")
	get_tree().quit()

func draw_trainer_gallery():
	draw_rect(Rect2(0,0,1280,960),Color("151925"))
	label_at("KANTO / GYM LEADERS" if "--capture-gyms" in OS.get_cmdline_user_args() else "INDIGO LEAGUE / TRAINER REDESIGN",Vector2(80,90),28,GOLD)
	label_at("FireRed / LeafGreen battle sprites",Vector2(80,125),17,WHITE)
	var identities = ["red","lorelei","bruno","agatha","lance","blue"]
	var gyms = "--capture-gyms" in OS.get_cmdline_user_args()
	if gyms: identities = ["brock","misty","surge","erika","koga","sabrina","blaine","giovanni"]
	for i in range(identities.size()):
		var origin = Vector2(220+(i%3)*410,460+(i/3)*400)
		if gyms: origin = Vector2(160+(i%4)*310,430+(i/4)*380)
		draw_set_transform(origin,0,Vector2.ONE*2.8)
		art.trainers.draw(self,Vector2.ZERO,identities[i],1,art.trainers.hand_offset(identities[i],1))
		draw_set_transform(Vector2.ZERO)
		label_at(identities[i].to_upper(),origin+Vector2(-50,44),20,MINT)

func capture_league():
	set_process(false)
	selection_controls.visible = false
	trainer_gallery = true
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/gyms-trainers.png" if "--capture-gyms" in OS.get_cmdline_user_args() else "res://captures/league-trainers.png")
	trainer_gallery = false
	for choice in ([8,9,15] if "--capture-gyms" in OS.get_cmdline_user_args() else [1,4,5]):
		opponent_choice.select(choice)
		preview_party = league.party(self,choice)
		selecting = true
		selection_controls.visible = true
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/league-menu-%d.png" % choice)
		start_match()
		selection_controls.visible = false
		countdown = 0
		player.entering = false
		enemy.entering = false
		camera_offset = Vector2(900,350)
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/league-battle-%d.png" % choice)
	get_tree().quit()

func capture_fields():
	set_process(false)
	selection_controls.visible = false
	selecting = false
	countdown = 0
	player.entering = false
	enemy.entering = false
	arena_overview = true
	for choice in range(1,10):
		fields.reset(self,choice)
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/field-%d.png" % choice)
	arena_overview = false
	fields.reset(self,4)
	camera_offset = Vector2(450,250)
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/field-water-battle.png")
	selecting = true
	selection_controls.visible = true
	arena_choice.select(10)
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/field-menu.png")
	get_tree().quit()

func capture_special():
	set_process(false)
	selection_controls.visible = false
	for id in ["quickattack", "extremespeed", "aquajet"]:
		pick(25,9)
		rocks.clear()
		player.pos = Vector2(900,600)
		enemy.pos = Vector2(1200,600)
		camera_offset = Vector2(400,220)
		var move = {"id":id,"name":id,"type":"Water" if id == "aquajet" else "Normal","category":"Physical","damage":30.0}
		skills.launch(self,player,enemy,move,Vector2.RIGHT,true)
		for i in range(18): skills.tick(self,shots.back(),0.016)
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/special-"+id+".png")
	pick(25,94)
	opponent_identity = "agatha"
	enemy.pos = Vector2(1200,600)
	camera_offset = Vector2(400,220)
	for elapsed in [1.6,2.2,2.9]:
		countdown = SEND_OUT_TIME - elapsed
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/special-gengar-"+str(elapsed)+".png")
	get_tree().quit()

func capture_clashes():
	set_process(false)
	selection_controls.visible = false
	pick(6,9)
	rocks.clear()
	player.pos = Vector2(850,600)
	enemy.pos = Vector2(1310,600)
	camera_offset = Vector2(400,220)
	player.heading = Vector2.RIGHT
	enemy.heading = Vector2.LEFT
	var fire = {"id":"flamethrower","name":"Flamethrower","type":"Fire","category":"Special","damage":30.0}
	var water = {"id":"hydropump","name":"Hydro Pump","type":"Water","category":"Special","damage":38.0}
	skills.launch(self,player,enemy,fire,Vector2.RIGHT,true)
	skills.launch(self,enemy,player,water,Vector2.LEFT,false)
	for i in range(20):
		update_effects(0.02)
		update_projectiles(0.02)
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/beam-clash.png")
	for i in range(20):
		update_effects(0.02)
		update_projectiles(0.02)
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/beam-breakthrough.png")
	get_tree().quit()

func capture_campaign():
	set_process(false)
	campaign.show_hub()
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/league-campaign.png")
	campaign.choose(0)
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/league-team-builder.png")
	get_tree().quit()

func capture_adventure():
	adventure.save_path = "user://adventure-capture-test.json"
	adventure.loaded = true
	adventure.enter()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/adventure-pallet.png")
	adventure.dialog = ""
	adventure.starter_menu()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/adventure-starters.png")
	adventure.choose_starter(4)
	adventure.evolutions = [[4,5]]
	adventure.show_evolution()
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/adventure-evolution.png")
	adventure.next_evolution()
	adventure.inventory.bag()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/adventure-bag.png")
	adventure.inventory.moves_menu(0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/adventure-moves.png")
	adventure.clear_ui()
	for id in [7,1,25,16,19]: adventure.data.party.append(adventure.new_mon(id,5))
	adventure.begin_battle("wild",[16],[4])
	countdown = 0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/adventure-battle.png")
	get_tree().quit()

func capture_kanto():
	frontend.layer.visible = false
	adventure.save_path = "user://kanto-preview-test.json"
	adventure.loaded = true
	adventure.enter()
	adventure.choose_starter(4)
	adventure.dialog = ""
	adventure.data["cascade"] = true
	adventure.data.rival = true
	adventure.data.bug_catcher = true
	adventure.data.badge = true
	adventure.data["rocket"] = true
	for city in adventure.Kanto.CITIES:
		adventure.data.map = city
		adventure.position_world = Vector2(800,400)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/kanto-%d.png" % city)
	adventure.Kanto.guide(adventure)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/kanto-guide.png")
	get_tree().quit()

func capture_progress():
	frontend.show_title()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/title.png")
	frontend.show_modes()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/modes.png")
	frontend.layer.visible = false
	adventure.save_path = "user://chapter-preview-test.json"
	adventure.loaded = true
	adventure.enter()
	adventure.choose_starter(4)
	adventure.data.party[0] = adventure.new_mon(4,6)
	adventure.data.party[0].xp = 55
	adventure.begin_battle("lass",[21,39],[11,12])
	enemy.hp = 0
	finish_round()
	shots.clear()
	result_time = 10
	adventure.record_knockout()
	advance_team()
	paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/ko-level-up.png")
	adventure.in_battle = false
	adventure.exploring = true
	adventure.visible = true
	adventure.dialog = ""
	adventure.data.rival = true
	adventure.data.bug_catcher = true
	adventure.data.badge = true
	adventure.data["rocket"] = true
	adventure.data.map = 6
	adventure.position_world = Vector2(800,700)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/mt-moon.png")
	adventure.data.map = 8
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/cerulean.png")
	get_tree().quit()

func capture_loadouts():
	set_process(false)
	frontend.layer.visible = false
	campaign.layer.visible = false
	pick(6,9)
	selecting = true
	selection_controls.visible = true
	move_editor.open(roster[player_index],true,0,0)
	move_editor.popup.position = Vector2i(300,300)
	await get_tree().process_frame
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/move-dropdown.png")
	move_editor.popup.hide()
	for entry in [["icebeam",0.3],["earthquake",0.8],["fly",0.9],["dig",0.9],["whirlpool",0.8]]:
		pick(6 if entry[0]=="fly" else 28 if entry[0]=="dig" else 9,6)
		selecting = false
		selection_controls.visible = false
		rocks.clear()
		player.pos = Vector2(1000,650)
		enemy.pos = Vector2(1250,650)
		update_camera(10)
		var move = move_editor.book.moves[entry[0]].duplicate(true)
		skills.launch(self,player,enemy,move,Vector2.RIGHT,true)
		skills.tick(self,shots.back(),entry[1])
		queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/custom-"+entry[0]+".png")
	team_mode = true
	reset()
	countdown = 0
	selecting = false
	enemy_bench.cooldown = 0
	enemy_bench.request(self,1)
	enemy_bench.timer = 0.35
	queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/enemy-switch.png")
	get_tree().quit()

func capture_controls():
	set_process(false)
	DirAccess.make_dir_recursive_absolute("res://captures")
	for screen in ["title","instructions","settings","capture"]:
		match screen:
			"title": frontend.show_title()
			"instructions": frontend.show_instructions()
			"settings": frontend.show_settings()
			"capture":
				var dummy=Button.new()
				frontend.layer.add_child(dummy)
				frontend.capture_key("move1",0,"Attack 1",dummy)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://captures/controls-"+screen+".png")
	var key=InputEventKey.new()
	key.physical_keycode=KEY_Z
	key.keycode=KEY_Z
	key.pressed=true
	controls._input(key)
	check(controls.capturing=="" and controls.bindings.move1[0]==KEY_Z,"Capture dialog assigns key and closes")
	controls.reset_defaults(false)
	frontend.layer.visible=false
	pick(25,7)
	countdown=0
	controls.assign("move1",0,KEY_Z,false)
	_unhandled_input(key)
	check(player.action_lock>0,"Remapped attack reaches live battle input handler")
	controls.reset_defaults(false)
	print("PASS: title, instructions, settings, key capture and live rebound attack" if test_failures.is_empty() else str(test_failures))
	get_tree().quit(0 if test_failures.is_empty() else 1)
