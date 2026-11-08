extends RefCounted
# Adventure-only source builds. Daily/Free Battle teams never use this table.
var a
var leaders: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/gym-leaders.json")).leaders

func party(kind: String) -> Array:
	if not leaders.has(kind): return []
	return leaders[kind].party.map(func(mon):return [int(mon.id),int(mon.level)])

func prepare(kind: String):
	var leader=leaders[kind]
	a.c.opponent_identity=leader.identity
	a.encounter["trainer_id"]=leader.source_id
	a.encounter["trainer_name"]=leader.name
	a.encounter["trainer_items"]=leader.items.duplicate()
	# Retain the step-one diagnostic alias; both refer to the same inventory.
	a.encounter["gym_items"]=a.encounter.trainer_items
	for i in leader.party.size():
		var source=leader.party[i]
		a.c.enemy_party[i].moves=a.inventory.definitions(source.moves)
		a.c.enemy_party[i]["held_item"]=source.held_item

func try_item() -> bool:
	return a.trainer_items.try_item()
