extends RefCounted

# Modern 18-type chart: attacking type -> super effective / resisted / immune.
# Cross-checked against Pokemon Showdown data/typechart.ts.
const TYPES = ["Normal", "Fire", "Water", "Electric", "Grass", "Ice", "Fighting", "Poison", "Ground", "Flying", "Psychic", "Bug", "Rock", "Ghost", "Dragon", "Dark", "Steel", "Fairy"]
const COLORS = ["b7b5a4", "ff9860", "69b9f2", "f9d86b", "99d875", "99e3e7", "ef8e8d", "c98fe4", "dfba7c", "abc1ff", "fa93bb", "c4d96e", "cabb8e", "a69bd8", "aa9aff", "aaa0b5", "a4cbd3", "f2b1db"]
const CHART = {
	"Normal": [[], ["Rock", "Steel"], ["Ghost"]],
	"Fire": [["Grass", "Ice", "Bug", "Steel"], ["Fire", "Water", "Rock", "Dragon"], []],
	"Water": [["Fire", "Ground", "Rock"], ["Water", "Grass", "Dragon"], []],
	"Electric": [["Water", "Flying"], ["Electric", "Grass", "Dragon"], ["Ground"]],
	"Grass": [["Water", "Ground", "Rock"], ["Fire", "Grass", "Poison", "Flying", "Bug", "Dragon", "Steel"], []],
	"Ice": [["Grass", "Ground", "Flying", "Dragon"], ["Fire", "Water", "Ice", "Steel"], []],
	"Fighting": [["Normal", "Ice", "Rock", "Dark", "Steel"], ["Poison", "Flying", "Psychic", "Bug", "Fairy"], ["Ghost"]],
	"Poison": [["Grass", "Fairy"], ["Poison", "Ground", "Rock", "Ghost"], ["Steel"]],
	"Ground": [["Fire", "Electric", "Poison", "Rock", "Steel"], ["Grass", "Bug"], ["Flying"]],
	"Flying": [["Grass", "Fighting", "Bug"], ["Electric", "Rock", "Steel"], []],
	"Psychic": [["Fighting", "Poison"], ["Psychic", "Steel"], ["Dark"]],
	"Bug": [["Grass", "Psychic", "Dark"], ["Fire", "Fighting", "Poison", "Flying", "Ghost", "Steel", "Fairy"], []],
	"Rock": [["Fire", "Ice", "Flying", "Bug"], ["Fighting", "Ground", "Steel"], []],
	"Ghost": [["Psychic", "Ghost"], ["Dark"], ["Normal"]],
	"Dragon": [["Dragon"], ["Steel"], ["Fairy"]],
	"Dark": [["Psychic", "Ghost"], ["Fighting", "Dark", "Fairy"], []],
	"Steel": [["Ice", "Rock", "Fairy"], ["Fire", "Water", "Electric", "Steel"], []],
	"Fairy": [["Fighting", "Dragon", "Dark"], ["Fire", "Poison", "Steel"], []]
}

static func effectiveness(attack_type: String, defense_type) -> float:
	if defense_type is Array:
		var result = 1.0
		for part in defense_type: result *= effectiveness(attack_type, part)
		return result
	var row = CHART[attack_type]
	if defense_type in row[2]: return 0.0
	if defense_type in row[0]: return 2.0
	if defense_type in row[1]: return 0.5
	return 1.0

static func color(type: String) -> Color:
	return Color(COLORS[TYPES.find(type)])

# The generated snapshot is checked against modern stats and recorded learnsets.
static func all() -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/roster.json"))
	assert(data is Array and data.size() == 158, "Missing or invalid roster data")
	for mon in data: mon.id = int(mon.id)
	return data

static func type_label(mon: Dictionary) -> String:
	return "/".join(mon.types)

static func find_id(roster: Array, number: int) -> int:
	for i in range(roster.size()):
		if int(roster[i].id) == number: return i
	return -1
