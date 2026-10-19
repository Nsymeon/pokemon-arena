extends RefCounted

const PATH = "user://league-progress-v1.json"
const ORDER = [8,9,10,11,12,13,14,15,1,2,3,4,5]
const NAMES = ["Brock","Misty","Lt. Surge","Erika","Koga","Sabrina","Blaine","Giovanni","Lorelei","Bruno","Agatha","Lance","Blue"]
const BADGES = ["Boulder","Cascade","Thunder","Rainbow","Soul","Marsh","Volcano","Earth"]
const ARENAS = [3,4,1,2,6,1,7,3,5,3,0,10,10]
var data = {"version":1,"cleared":0,"team":[25,6,9,3,94,143],"champion_team":[]}
var path = PATH
var error = ""
var writable = true
var recovered = false
var active = false
var stage = 0
var recorded = false
var layer: CanvasLayer
var c

func valid(value, ids: Array) -> bool:
	if not value is Dictionary: return false
	if value.get("version",0) != 1: return false
	var cleared = value.get("cleared",-1)
	if not (cleared is float or cleared is int) or cleared != int(cleared) or cleared < 0 or cleared > 13: return false
	for key in ["team","champion_team"]:
		var team = value.get(key, null)
		if not team is Array or (team.size() != 6 and not (key == "champion_team" and team.is_empty())): return false
		for id in team:
			if not (id is int or id is float) or id != int(id) or int(id) not in ids: return false
	return true

func read_progress(ids: Array):
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"): return
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK: continue
		var value = parser.data
		if value is Dictionary and value.get("version",1) != 1:
			error = "This save requires another game version. Saving is disabled."
			writable = false
			return
		if valid(value,ids):
			data = value
			data.cleared = int(data.cleared)
			data.team = data.team.map(func(id): return int(id))
			data.champion_team = data.champion_team.map(func(id): return int(id))
			recovered = candidate.ends_with(".bak")
			if recovered: error = "Recovered backup save."
			return
	error = "Save could not be read. Original files preserved; saving is disabled."
	writable = false

func save() -> bool:
	if not writable: return false
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		error = "Could not save progress. Check available storage."
		return false
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		error = "Save write failed. Previous progress preserved."
		return false
	var full = ProjectSettings.globalize_path(path)
	if recovered and FileAccess.file_exists(path):
		if DirAccess.rename_absolute(full,full+".corrupt-"+str(Time.get_ticks_usec())) != OK:
			error = "Could not preserve damaged save. Backup left untouched."
			return false
	elif FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"): DirAccess.remove_absolute(full+".bak")
		if DirAccess.rename_absolute(full,full+".bak") != OK:
			error = "Could not rotate save backup."
			return false
	if DirAccess.rename_absolute(full+".tmp",full) != OK:
		error = "Could not finish saving. Previous save kept as backup."
		return false
	error = ""
	recovered = false
	return true

func remember_team():
	c.player_team[c.team_slot] = c.player_index
	data.team = c.player_team.map(func(index): return int(c.roster[index].id))

func record_result():
	if not active or recorded or not c.resolution_ready() or c.can_continue_team(): return
	recorded = true
	if c.result == "VICTORY" and stage == int(data.cleared):
		data.cleared = mini(13,int(data.cleared)+1)
		if data.cleared == 13: data.champion_team = data.team.duplicate()
	save()

func install(context):
	c = context
	layer = CanvasLayer.new()
	layer.layer = 30
	c.add_child(layer)
	layer.visible = false
	var entry = Button.new()
	entry.text = "MAIN MENU / MODES"
	entry.position = Vector2(900,8)
	entry.size = Vector2(335,40)
	entry.pressed.connect(func():
		if active: remember_team(); save()
		active = false
		c.frontend.show_modes())
	c.selection_controls.add_child(entry)
	if not OS.get_cmdline_user_args().is_empty(): return
	read_progress(c.roster.map(func(mon): return int(mon.id)))
	show_hub()

func text(value: String, pos: Vector2, size: int, color = Color("e7eee2")):
	var label = Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	layer.add_child(label)

func button(value: String, pos: Vector2, size: Vector2, action: Callable, disabled = false):
	var b = Button.new()
	b.text = value
	b.position = pos
	b.size = size
	b.disabled = disabled
	b.add_theme_font_size_override("font_size",18)
	b.pressed.connect(action)
	layer.add_child(b)

func show_hub():
	if active:
		record_result()
		if c.selecting: remember_team()
		save()
	active = false
	c.selecting = true
	c.paused = false
	c.switch_menu = false
	c.selection_controls.visible = false
	for child in layer.get_children(): child.free()
	var bg = ColorRect.new()
	bg.color = Color("0b171f")
	bg.size = Vector2(1280,960)
	layer.add_child(bg)
	layer.visible = true
	button("BACK TO MODES",Vector2(790,42),Vector2(430,50),c.frontend.show_modes)
	text("GYM LEADERS",Vector2(60,42),36,Color("f9d86b"))
	text("%d / 8 BADGES     %d / 13 TRAINERS DEFEATED" % [mini(8,int(data.cleared)),int(data.cleared)],Vector2(60,98),20)
	text("GYM CHALLENGE",Vector2(60,145),20,Color("77e2b0"))
	text("INDIGO PLATEAU",Vector2(680,145),20,Color("77e2b0"))
	for i in range(13):
		var done = i < int(data.cleared)
		var locked = i > int(data.cleared)
		var title = ("LOCKED  " if locked else "CLEARED  " if done else "NEXT  ") + NAMES[i]
		if i < 8: title += "  /  " + BADGES[i] + " Badge"
		button(title,Vector2(60 if i < 8 else 680,185+(i if i<8 else i-8)*58),Vector2(540,48),choose.bind(i),locked)
	if data.cleared == 13:
		text("HALL OF FAME / CHAMPION",Vector2(680,510),24,Color("f9d86b"))
		var names: Array = []
		for id in data.champion_team: names.append(c.roster[c.Dex.find_id(c.roster,int(id))].name)
		text(" / ".join(names.slice(0,3))+"\n"+" / ".join(names.slice(3)),Vector2(680,555),18)
	else:
		text("Next opponent: " + NAMES[int(data.cleared)],Vector2(680,530),24)
		text("Build your team before each match.\nTeam heals between trainers.\nLosses keep your earned badges.",Vector2(680,580),18)
	button("CONTINUE LEAGUE" if data.cleared < 13 else "REMATCH CHAMPION",Vector2(60,700),Vector2(540,60),choose.bind(mini(12,int(data.cleared))))
	button("FREE BATTLE",Vector2(680,700),Vector2(540,60),free_battle)
	text("Autosave after each trainer. Closing mid-battle restarts that encounter.",Vector2(60,800),18)
	text(error if error != "" else "Progress is stored on this PC and survives game updates.",Vector2(60,842),17,Color("ffb67e") if error != "" else Color("77e2b0"))

func choose(index: int):
	if index < 0 or index > mini(12,int(data.cleared)): return
	active = true
	stage = index
	recorded = false
	c.team_mode = true
	c.select_enemy = false
	c.team_slot = 0
	c.player_team = data.team.map(func(id): return c.Dex.find_id(c.roster,int(id)))
	c.player_index = c.player_team[0]
	c.opponent_choice.select(ORDER[index])
	c.opponent_choice.disabled = true
	c.preview_party = c.league.party(c,ORDER[index])
	c.opponent_preview_slot = 0
	c.arena_choice.select(ARENAS[index])
	c.arena_choice.disabled = true
	c.weather_choice.select(0)
	c.weather_choice.disabled = true
	layer.visible = false
	c.selection_controls.visible = true

func free_battle():
	active = false
	c.opponent_choice.disabled = false
	c.arena_choice.disabled = false
	c.weather_choice.disabled = false
	layer.visible = false
	c.selection_controls.visible = true

func prepare_match() -> bool:
	if not active: return true
	if stage > mini(12,int(data.cleared)): return false
	c.opponent_choice.select(ORDER[stage])
	c.arena_choice.select(ARENAS[stage])
	c.weather_choice.select(0)
	c.team_mode = true
	recorded = false
	remember_team()
	save()
	return true

func tests(context):
	var p = load("res://league_campaign.gd").new()
	p.c = context
	p.path = "user://league-test-" + str(Time.get_ticks_usec()) + ".json"
	var ids: Array = context.roster.map(func(mon): return int(mon.id))
	context.check(p.valid(p.data,ids),"Fresh League save validates")
	context.check(not p.valid({"version":2},ids),"Unknown save version rejected")
	var malformed = p.data.duplicate(true)
	malformed.team = [9999,6,9,3,94,143]
	context.check(not p.valid(malformed,ids),"Invalid species rejected in saved team")
	context.check(p.save(),"League save writes successfully")
	p.data.cleared = 1
	context.check(p.save(),"League atomic save rotates backup")
	var readback = load("res://league_campaign.gd").new()
	readback.path = p.path
	readback.read_progress(ids)
	context.check(readback.data.cleared == 1 and readback.data.team == p.data.team,"League progress and team survive reload")
	var file = FileAccess.open(p.path,FileAccess.WRITE)
	file.store_string("broken json")
	file.close()
	readback.read_progress(ids)
	context.check(readback.data.cleared == 0 and readback.writable,"Corrupt save recovers the previous backup")
	context.pick(25,7)
	context.enemy.hp = 0
	context.finish_round()
	p.active = true
	p.stage = 1
	p.record_result()
	context.check(p.data.cleared == 1,"League does not award victory before pending attacks resolve")
	context.shots.clear()
	context.result_time = context.FAINT_RESULT_TIME
	p.record_result()
	context.check(p.data.cleared == 2,"Final League victory unlocks exactly one trainer")
	p.record_result()
	context.check(p.data.cleared == 2,"Result recorded only once")
	p.recorded = false
	p.stage = 0
	p.record_result()
	context.check(p.data.cleared == 2,"Replaying a badge cannot skip locked trainers")
	p.recorded = false
	p.stage = 2
	context.result = "DEFEAT"
	p.record_result()
	context.check(p.data.cleared == 2,"Defeat preserves checkpoint")
	p.recorded = false
	context.result = "DRAW"
	p.record_result()
	context.check(p.data.cleared == 2,"Draw does not award a badge")
	p.recorded = false
	p.data.cleared = 12
	p.stage = 12
	context.result = "VICTORY"
	p.record_result()
	context.check(p.data.cleared == 13 and p.data.champion_team == p.data.team,"Blue victory records the Hall of Fame team")
	# Exercise the real menu/start/result wiring using only an isolated test save.
	var live = context.campaign
	var old_path = live.path
	live.path = p.path
	live.choose(1)
	context.check(not live.active,"Locked League opponent cannot be selected")
	live.choose(0)
	context.start_match()
	context.check(context.opponent_identity == "brock" and context.enemy_party_size() == 2 and context.team_mode,"League start uses the correct trainer and full player team")
	context.enemy.hp = 0
	context.finish_round()
	context.shots.clear()
	context.result_time = context.FAINT_RESULT_TIME
	live.record_result()
	context.check(live.data.cleared == 0,"Intermediate Pokemon KO never awards a badge")
	context.advance_team()
	context.enemy.hp = 0
	context.finish_round()
	context.result_time = context.FAINT_RESULT_TIME
	live.record_result()
	context.check(live.data.cleared == 1,"Defeating Brock's whole party awards the Boulder Badge")
	live.show_hub()
	live.choose(1)
	context.start_match()
	context.check(context.opponent_identity == "misty" and context.player.hp == context.player.data.hp,"Continue starts Misty with a healed team")
	live.show_hub()
	live.free_battle()
	context.result = "VICTORY"
	context.result_time = context.FAINT_RESULT_TIME
	live.record_result()
	context.check(live.data.cleared == 1 and not context.opponent_choice.disabled,"Free battles cannot advance League progress")
	live.path = old_path
	live.data = {"version":1,"cleared":0,"team":[25,6,9,3,94,143],"champion_team":[]}
	live.stage = 0
	live.recorded = false
	context.opponent_choice.select(0)
	context.preview_party.clear()
	context.arena_choice.select(0)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(p.path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(p.path+suffix))
	context.pick(25,7)
