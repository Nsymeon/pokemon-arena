extends RefCounted

var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle-learnsets.json"))
var choices = {}
var c
var popup: PopupMenu
var editing = {}
var options: Array = []

func install(context):
	c = context
	popup = PopupMenu.new()
	popup.max_size = Vector2i(600,500)
	c.add_child(popup)
	popup.id_pressed.connect(choose)
	if OS.get_cmdline_user_args().is_empty() and FileAccess.file_exists("user://battle-moves.json"):
		var saved = JSON.parse_string(FileAccess.get_file_as_string("user://battle-moves.json"))
		if saved is Dictionary: choices = saved

func identity(mon, friendly: bool, slot: int) -> String:
	return "%s:%d:%d" % ["you" if friendly else "cpu",slot,mon.id]

func configured(mon, friendly: bool, slot: int) -> Dictionary:
	var result = c.ivs.configured(c.abilities.configured(mon,friendly,slot),friendly,slot)
	var ids = choices.get(identity(mon,friendly,slot),[])
	if not ids is Array or ids.size()!=4: return result
	var seen = []
	for id in ids:
		if id not in book.species.get(str(mon.id),[]) or not book.moves.has(id) or id in seen: return result
		seen.append(id)
	result.moves = ids.map(func(id):return book.moves[id].duplicate(true))
	return result

func open(mon, friendly: bool, slot: int, move_slot: int):
	editing = {"mon":mon,"friendly":friendly,"slot":slot,"move_slot":move_slot}
	var current = configured(mon,friendly,slot)
	options = book.species[str(mon.id)].duplicate()
	options.sort_custom(func(a,b):return book.moves[a].name<book.moves[b].name)
	popup.clear()
	popup.add_item("Reset this Pokemon to default moves",10000)
	popup.add_separator()
	for i in range(options.size()):
		var move = book.moves[options[i]]
		popup.add_check_item(move.name+" / "+move.type,i)
		popup.set_item_checked(popup.item_count-1,current.moves[move_slot].id==options[i])
		popup.set_item_disabled(popup.item_count-1,current.moves.any(func(m):return m.id==options[i]) and current.moves[move_slot].id!=options[i])
	popup.position = Vector2i(c.get_viewport().get_mouse_position())
	popup.popup()

func choose(index: int):
	if editing.is_empty(): return
	var key = identity(editing.mon,editing.friendly,editing.slot)
	if index==10000: choices.erase(key)
	elif index>=0 and index<options.size():
		var mon = configured(editing.mon,editing.friendly,editing.slot)
		var ids = mon.moves.map(func(m):return m.id)
		ids[editing.move_slot] = options[index]
		if ids.count(options[index])>1: return
		choices[key] = ids
	if OS.get_cmdline_user_args().is_empty():
		var file = FileAccess.open("user://battle-moves.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(choices))
	c.queue_redraw()

func click(mouse: Vector2) -> bool:
	for friendly in [true,false]:
		if not friendly and c.opponent_choice.selected>0: continue
		var origin = Vector2(40 if friendly else 652,544)
		if c.abilities.shiny_enabled() and Rect2(origin+Vector2(524,7),Vector2(52,29)).has_point(mouse):
			c.abilities.toggle_shiny(c.roster[c.player_index if friendly else c.enemy_index],friendly,c.team_slot if c.team_mode else 0)
			return true
		if Rect2(origin+Vector2(465,155),Vector2(108,26)).has_point(mouse):
			c.ivs.open(c.roster[c.player_index if friendly else c.enemy_index],friendly,c.team_slot if c.team_mode else 0)
			return true
		if Rect2(origin+Vector2(12,154),Vector2(560,28)).has_point(mouse):
			c.abilities.open(c.roster[c.player_index if friendly else c.enemy_index],friendly,c.team_slot if c.team_mode else 0)
			return true
		for i in range(4):
			if Rect2(origin+Vector2(12+(i%2)*286,57+int(i/2)*50),Vector2(280,48)).has_point(mouse):
				open(c.roster[c.player_index if friendly else c.enemy_index],friendly,c.team_slot if c.team_mode else 0,i)
				return true
	return false

func tests():
	var saved = choices.duplicate(true)
	choices.clear()
	var mon = c.roster[c.Dex.find_id(c.roster,6)]
	c.check(configured(mon,true,0).moves==mon.moves,"Move editor preserves defaults initially")
	var ids = mon.moves.map(func(m):return m.id)
	ids[0] = "fly"
	choices[identity(mon,true,0)] = ids
	c.check(configured(mon,true,0).moves[0].id=="fly","Legal custom move reaches configured fighter")
	c.check(configured(mon,true,1).moves==mon.moves and configured(mon,false,0).moves==mon.moves,"Loadouts isolate team slots and sides")
	c.pick(6,9)
	c.check(c.player.data.moves[0].id=="fly","Custom moves are applied to the actual battle fighter")
	var original_team = c.player_team.duplicate()
	c.player_team[0] = c.Dex.find_id(c.roster,6)
	c.player_team[1] = c.Dex.find_id(c.roster,6)
	c.team_mode = true
	c.reset()
	c.check(c.player_states[0].data.moves[0].id=="fly" and c.player_states[1].data.moves==mon.moves,"Duplicate species have independent moves in team battles")
	c.player_team = original_team
	c.team_mode = false
	ids[0] = "spore"
	c.check(configured(mon,true,0).moves==mon.moves,"Illegal saved move cannot bypass compatibility")
	choices = saved
