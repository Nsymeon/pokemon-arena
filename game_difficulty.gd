extends RefCounted
const NAMES=["Easy","Normal","Hard"]
var level=1
func install():
	if OS.get_cmdline_user_args().is_empty() and FileAccess.file_exists("user://difficulty.json"):
		var value=JSON.parse_string(FileAccess.get_file_as_string("user://difficulty.json"))
		if value is Dictionary and value.get("level") in [0,1,2]: level=int(value.level)
func choose(value):
	level=clampi(int(value),0,2)
	if OS.get_cmdline_user_args().is_empty():
		var file=FileAccess.open("user://difficulty.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify({"level":level}))
func reaction(rng) -> float: return rng.randf_range([1.0,0.55,0.4][level],[1.7,1.0,0.75][level])
func aim_error() -> float: return [0.2,0.1,0.04][level]
func dodge() -> float: return [0.25,0.45,0.6][level]
func switches() -> int: return 1 if level==0 else 3
