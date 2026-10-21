extends RefCounted

const NAMES = {"slp": "sleep", "par": "paralysis", "brn": "burn", "psn": "poison", "tox": "toxic", "frz": "freeze"}

static func types(f) -> Array:
	var current: Array = f.data.types.duplicate()
	if f.get("volatile",{}).get("roost",0)>0:
		current.erase("Flying")
		if current.is_empty(): current.append("Normal")
	return current

static func init(f):
	f["action_lock"] = 0.0
	f["charge_left"] = 0.0
	f["pending_move"] = {}
	f["volatile"] = {}
	f["stages"] = {}
	f["dodge_left"] = 0.0
	f["dodge_cooldown"] = 0.0
	f["sprinting"] = false
	f["toxic_tick"] = 0
	f["trap_tick"] = 1.0
	f["condition_note"] = ""
	f["condition_note_time"] = 0.0

static func note(f, text):
	f.condition_note = text
	f.condition_note_time = 0.8

static func stage(f, stat: String) -> float:
	var n = int(f.get("stages", {}).get(stat, 0))
	var base = 3.0 if stat in ["accuracy", "evasion"] else 2.0
	return (base + n) / base if n >= 0 else base / (base - n)

static func avoids(f,move) -> bool:
	if f.get("volatile",{}).get("airborne",0)>0: return true
	return f.get("volatile",{}).get("underground",0)>0 and move.get("id","") not in ["earthquake","magnitude","fissure"]

static func immobilized(f) -> bool:
	return f.get("volatile",{}).get("underground",0)>0 or f.get("volatile",{}).get("airborne",0)>0 or f.ailment in ["sleep", "freeze"] or f.get("volatile", {}).get("flinch", 0) > 0 or f.get("charge_left", 0.0) > 0

static func speed(f) -> float:
	if immobilized(f): return 0.0
	return stage(f, "spe") * (0.5 if f.ailment == "paralysis" or f.stun > 0 else 1.0)

static func attempt(c, f, move) -> bool:
	if f.ailment == "freeze" and move.get("defrost", false): f.ailment = ""; f.ailment_time = 0
	if immobilized(f): note(f, "FROZEN" if f.ailment == "freeze" else "ASLEEP" if f.ailment == "sleep" else "FLINCH"); return false
	if f.ailment == "paralysis" and c.rng.randf() < 0.25: note(f, "PARALYZED!"); return false
	if f.volatile.get("confusion", 0) > 0 and c.rng.randf() < 1.0 / 3.0:
		f.hp = maxf(0, f.hp - f.data.hp * 0.03)
		note(f, "CONFUSED! SELF HIT")
		return false
	return true

static func apply(c, f, payload, move) -> bool:
	if f.hp <= 0 or (not move.is_empty() and avoids(f,move)): return false
	var status: String = NAMES.get(payload.get("status", ""), "")
	var changed = false
	if status != "":
		var immune = (status == "burn" and "Fire" in types(f)) or (status in ["poison", "toxic"] and ("Poison" in types(f) or "Steel" in types(f))) or (status == "paralysis" and "Electric" in types(f)) or (status == "freeze" and "Ice" in types(f))
		if move.get("id", "") == "thunderwave" and "Ground" in types(f): immune = true
		if move.get("powder", false) and "Grass" in types(f): immune = true
		if immune: note(f, "IMMUNE"); return false
		if f.ailment != "": note(f, "ALREADY AFFLICTED"); return false
		f.ailment = status
		f.ailment_time = c.rng.randf_range(2.0,3.0) if status=="sleep" else 3.0 if status=="paralysis" else float(c.rng.randi_range(1,5)) if status=="freeze" else 8.0
		f.dot_tick = 1.0
		f.toxic_tick = 0
		if status in ["sleep", "freeze"]:
			f.dash_time = 0
			f.charge_left = 0
			f.pending_move = {}
		note(f, status.to_upper())
		changed = true
	var volatile_status: String = payload.get("volatileStatus", "")
	if volatile_status == "leechseed":
		if "Grass" in types(f): note(f,"IMMUNE"); return false
		f.volatile["leechseed"] = 8.0
		f["seed_tick"] = 1.0
		note(f,"SEEDED")
		changed = true
	if volatile_status in ["confusion", "flinch", "partiallytrapped", "focusenergy"]:
		f.volatile[volatile_status] = 0.4 if volatile_status == "flinch" else 5.0 if volatile_status == "partiallytrapped" else 6.0
		if volatile_status == "partiallytrapped": f.trap_tick = 1.0
		if volatile_status == "flinch":
			f.dash_time = 0
			f.charge_left = 0
			f.pending_move = {}
		note(f, "TRAPPED" if volatile_status == "partiallytrapped" else volatile_status.to_upper())
		changed = true
	for stat in payload.get("boosts", {}):
		f.stages[stat] = clampi(int(f.stages.get(stat, 0)) + int(payload.boosts[stat]), -6, 6)
		note(f, stat.to_upper() + (" UP" if payload.boosts[stat] > 0 else " DOWN"))
		changed = true
	return changed

static func tick(f, dt: float):
	f.action_lock = maxf(0, f.action_lock - dt)
	f.condition_note_time = maxf(0, f.condition_note_time - dt)
	# Count only time actually spent afflicted, including the last partial tick.
	var active = minf(dt, f.ailment_time)
	if f.ailment in ["burn", "poison", "toxic"] and active > 0:
		f.dot_tick -= active
		while f.dot_tick <= 0.00001:
			f.dot_tick += 1.0
			f.toxic_tick += 1
			var rate = 0.02 if f.ailment == "burn" else 0.03 if f.ailment == "poison" else minf(0.08, f.toxic_tick * 0.01)
			f.hp = maxf(0, f.hp - f.data.hp * rate)
	f.ailment_time = maxf(0, f.ailment_time - dt)
	if f.ailment_time <= 0: f.ailment = ""
	if f.volatile.get("partiallytrapped", 0) > 0:
		f.trap_tick -= minf(dt, f.volatile.partiallytrapped)
		while f.trap_tick <= 0.00001:
			f.trap_tick += 1
			f.hp = maxf(0, f.hp - f.data.hp * 0.02)
	for key in f.volatile.keys():
		f.volatile[key] = maxf(0, f.volatile[key] - dt)
		if f.volatile[key] <= 0: f.volatile.erase(key)

static func summary(f) -> String:
	var parts = []
	if f.get("ailment", "") != "": parts.append("%s %.1fs" % [f.ailment.to_upper(), f.ailment_time])
	for key in f.get("volatile", {}): parts.append("TRAPPED" if key == "partiallytrapped" else key.to_upper())
	for stat in f.get("stages", {}):
		if f.stages[stat] != 0: parts.append(stat.to_upper() + "%+d" % f.stages[stat])
	return " / ".join(parts)
