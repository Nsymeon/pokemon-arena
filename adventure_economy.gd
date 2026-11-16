extends RefCounted
var a
var book: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/economy.json"))

func price(id: String, fallback=0) -> int:
	return int(book.prices.get("pokeball" if id=="balls" else id.to_lower(),fallback))

func prize(amulet=false) -> int:
	if str(a.encounter.get("kind",""))=="wild": return 0
	var id=str(a.encounter.get("trainer_id",""))
	if not a.trainers.book.trainers.has(id): return 300 if amulet else 150 # Custom fixture/legacy battles.
	var trainer=a.trainers.book.trainers[id]
	var base=int(book.trainer_classes[trainer.trainer_class])
	return 4*int(trainer.party[-1].level)*base*(2 if trainer.double_battle else 1)*(2 if amulet else 1)
