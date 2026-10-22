extends RefCounted

# FRLG slots for its species; normal slots for the two later-generation guests.
# Time-based effects use five combat seconds as one ability turn.
var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/abilities.json"))
var random = RandomNumberGenerator.new()
var choices = {}
var shiny_choices = {}
var c
var popup: PopupMenu
var editing = {}
const SHINY_DENOMINATOR = 8192
const FEMALE = {"1": 0.125, "2": 0.125, "3": 0.125, "4": 0.125, "5": 0.125, "6": 0.125, "7": 0.125, "8": 0.125, "9": 0.125, "10": 0.5, "11": 0.5, "12": 0.5, "13": 0.5, "14": 0.5, "15": 0.5, "16": 0.5, "17": 0.5, "18": 0.5, "19": 0.5, "20": 0.5, "21": 0.5, "22": 0.5, "23": 0.5, "24": 0.5, "25": 0.5, "26": 0.5, "27": 0.5, "28": 0.5, "29": 1, "30": 1, "31": 1, "32": 0, "33": 0, "34": 0, "35": 0.75, "36": 0.75, "37": 0.75, "38": 0.75, "39": 0.75, "40": 0.75, "41": 0.5, "42": 0.5, "43": 0.5, "44": 0.5, "45": 0.5, "46": 0.5, "47": 0.5, "48": 0.5, "49": 0.5, "50": 0.5, "51": 0.5, "52": 0.5, "53": 0.5, "54": 0.5, "55": 0.5, "56": 0.5, "57": 0.5, "58": 0.25, "59": 0.25, "60": 0.5, "61": 0.5, "62": 0.5, "63": 0.25, "64": 0.25, "65": 0.25, "66": 0.25, "67": 0.25, "68": 0.25, "69": 0.5, "70": 0.5, "71": 0.5, "72": 0.5, "73": 0.5, "74": 0.5, "75": 0.5, "76": 0.5, "77": 0.5, "78": 0.5, "79": 0.5, "80": 0.5, "81": -1, "82": -1, "83": 0.5, "84": 0.5, "85": 0.5, "86": 0.5, "87": 0.5, "88": 0.5, "89": 0.5, "90": 0.5, "91": 0.5, "92": 0.5, "93": 0.5, "94": 0.5, "95": 0.5, "96": 0.5, "97": 0.5, "98": 0.5, "99": 0.5, "100": -1, "101": -1, "102": 0.5, "103": 0.5, "104": 0.5, "105": 0.5, "106": 0, "107": 0, "108": 0.5, "109": 0.5, "110": 0.5, "111": 0.5, "112": 0.5, "113": 1, "114": 0.5, "115": 1, "116": 0.5, "117": 0.5, "118": 0.5, "119": 0.5, "120": -1, "121": -1, "122": 0.5, "123": 0.5, "124": 1, "125": 0.25, "126": 0.25, "127": 0.5, "128": 0, "129": 0.5, "130": 0.5, "131": 0.5, "132": -1, "133": 0.125, "134": 0.125, "135": 0.125, "136": 0.125, "137": -1, "138": 0.125, "139": 0.125, "140": 0.125, "141": 0.125, "142": 0.125, "143": 0.125, "144": -1, "145": -1, "146": -1, "147": 0.5, "148": 0.5, "149": 0.5, "150": -1, "151": -1, "152": 0.125, "185": 0.5, "197": 0.125, "355": 0.5, "361": 0.5, "599": -1, "821": 0.5}
const CONTEXT = {"Lightning Rod":"FRLG: redirects Electric moves in double battles; no immunity or stat boost.", "Cute Charm":"30% infatuation on opposite-gender contact; 5s, 50% action failure.", "Plus":"Requires an allied Minus user (double battles).", "Minus":"Requires an allied Plus user (double battles).", "Illuminate":"Affects random encounters; that system is deferred.", "Stench":"FRLG overworld encounter effect; random encounters are deferred.", "Pickup":"Finds a Potion after some won Adventure battles.", "Sticky Hold":"Protects held items; held items are not implemented.", "Unnerve":"Blocks opposing berries; held berries are not implemented.", "Run Away":"Wild escape passive; running from encounters is not implemented yet."}

func install(context):
	c=context
	random.randomize()
	popup=PopupMenu.new()
	c.add_child(popup)
	popup.id_pressed.connect(choose)
	if OS.get_cmdline_user_args().is_empty() and FileAccess.file_exists("user://battle-abilities.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string("user://battle-abilities.json"))
		if saved is Dictionary: choices=saved
	if OS.get_cmdline_user_args().is_empty() and FileAccess.file_exists("user://battle-shinies.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string("user://battle-shinies.json"))
		if saved is Dictionary:
			for key in saved:
				if saved[key] is bool: shiny_choices[key]=saved[key]

func shiny_enabled() -> bool:
	return not c.campaign.active and not c.adventure.in_battle

func toggle_shiny(mon,friendly,slot):
	if not shiny_enabled(): return
	var key=c.move_editor.identity(mon,friendly,slot)
	shiny_choices[key]=not bool(shiny_choices.get(key,false))
	if OS.get_cmdline_user_args().is_empty():
		var file=FileAccess.open("user://battle-shinies.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(shiny_choices))
	c.queue_redraw()

func draw_shiny_toggle(mon,pos):
	var enabled=bool(mon.get("shiny",false))
	var color=c.GOLD if enabled else Color("78929c")
	var box=Rect2(pos+Vector2(524,7),Vector2(52,29))
	c.draw_rect(box,Color("453e24") if enabled else Color("182f39"))
	c.draw_rect(box,color,false,1)
	for star in [[Vector2(544,21),9.0],[Vector2(561,16),5.0]]:
		var points=PackedVector2Array()
		for i in range(8):
			points.append(pos+star[0]+Vector2.from_angle(-PI/2+i*PI/4)*float(star[1])*(1.0 if i%2==0 else 0.3))
		if enabled: c.draw_colored_polygon(points,color)
		else:
			points.append(points[0])
			c.draw_polyline(points,color,1.4,true)

func legal(id) -> Array:
	return book.get(str(int(id)),[])

func assign(mon, roll: bool=false):
	var options=legal(mon.id)
	if not mon.has("ability_slot"): mon["ability_slot"]=random.randi_range(0,options.size()-1) if roll else 0
	if not mon.has("shiny"): mon["shiny"]=random.randi_range(0,SHINY_DENOMINATOR-1)==0 if roll else false
	if not mon.has("gender"):
		var ratio=float(FEMALE.get(str(int(mon.id)),-1))
		mon["gender"]="N" if ratio<0 else "F" if (random.randf() if roll else 0.5)<ratio else "M"
	mon["ability"]=options[int(mon.ability_slot)%options.size()]

func configured(mon,friendly,slot):
	var result=mon.duplicate(true)
	assign(result)
	var key=c.move_editor.identity(mon,friendly,slot)
	if shiny_enabled(): result.shiny=bool(shiny_choices.get(key,false))
	var selected=choices.get(key,"")
	if selected in legal(mon.id):
		result.ability_slot=legal(mon.id).find(selected)
		result.ability=selected
	return result

func open(mon,friendly,slot):
	editing={"mon":mon,"friendly":friendly,"slot":slot}
	popup.clear()
	for name in legal(mon.id):
		popup.add_item(name)
		popup.set_item_tooltip(popup.item_count-1,CONTEXT.get(name,"Passive ability / FireRed rules adapted to real-time combat"))
	popup.position=Vector2i(c.get_viewport().get_mouse_position())
	popup.popup()

func choose(index):
	if editing.is_empty() or index<0 or index>=legal(editing.mon.id).size(): return
	choices[c.move_editor.identity(editing.mon,editing.friendly,editing.slot)]=legal(editing.mon.id)[index]
	if OS.get_cmdline_user_args().is_empty():
		var file=FileAccess.open("user://battle-abilities.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(choices))
	c.queue_redraw()

func name_of(f) -> String:
	return f.get("copied_ability",f.data.get("ability",""))

func announce(f):
	c.Conditions.note(f,name_of(f).to_upper())

func entry(f,other):
	if f.get("ability_entered",false): return
	f["ability_entered"]=true
	f["ability_clock"]=0.0
	var a=name_of(f)
	if a=="Trace" and name_of(other) not in ["Trace",""]:
		f["copied_ability"]=name_of(other)
		announce(f)
	if name_of(f)=="Intimidate":
		c.Conditions.apply(c,other,{"boosts":{"atk":-1}},{})
		announce(f)

func withdrawn(f):
	if name_of(f)=="Natural Cure": f.ailment=""; f.ailment_time=0
	f.erase("copied_ability")
	f.erase("flash_fire")
	f["ability_entered"]=false

func trapped(f,other) -> bool:
	var a=name_of(other)
	return other.hp>0 and ((a=="Arena Trap" and "Flying" not in c.Conditions.types(f) and name_of(f)!="Levitate") or (a=="Magnet Pull" and "Steel" in c.Conditions.types(f)))

func tick(f,dt):
	if f.hp<=0: return
	f["ability_clock"]=f.get("ability_clock",0.0)+dt
	while f.ability_clock>=5:
		f.ability_clock-=5
		if name_of(f)=="Shed Skin" and f.ailment!="" and c.rng.randf()<1.0/3.0:
			f.ailment=""; f.ailment_time=0; announce(f)

func speed(f) -> float:
	var a=name_of(f)
	return 2.0 if (a=="Chlorophyll" and c.weather.kind=="sun") or (a=="Swift Swim" and c.weather.kind=="rain") else 1.0

func status_block(f,status,volatile_status,move) -> bool:
	var a=name_of(f)
	if (a in ["Insomnia","Vital Spirit"] and status=="sleep") or (a=="Immunity" and status in ["poison","toxic"]) or (a=="Limber" and status=="paralysis") or (a=="Water Veil" and status=="burn") or (a=="Own Tempo" and volatile_status=="confusion") or (a=="Inner Focus" and volatile_status=="flinch") or (a=="Oblivious" and volatile_status=="attract") or (a=="Soundproof" and flag(move,"sound")):
		announce(f); return true
	return false

func blocks_drop(f,stat) -> bool:
	return name_of(f)=="Clear Body" or (name_of(f)=="Keen Eye" and stat=="accuracy") or (name_of(f)=="Hyper Cutter" and stat=="atk")

func flag(move,key) -> bool:
	return bool(c.move_flags.get(move.get("id",""),{}).get(key,0))

func blocks_hit(f,move) -> bool:
	var a=name_of(f)
	var type=move.get("type","")
	if (a=="Levitate" and type=="Ground") or (a=="Soundproof" and flag(move,"sound")) or (a=="Sturdy" and move.get("id","") in ["fissure","guillotine","horndrill","sheercold"]):
		announce(f); return true
	if (a=="Water Absorb" and type=="Water") or (a=="Volt Absorb" and type=="Electric"):
		f.hp=minf(f.data.hp,f.hp+f.data.hp*0.25)
		announce(f); return true
	if a=="Flash Fire" and type=="Fire":
		f["flash_fire"]=true
		announce(f); return true
	return false

func damage(attacker,target,move) -> float:
	var a=name_of(attacker)
	var b=name_of(target)
	var type=move.get("type","")
	var factor=1.0
	if attacker.hp<=attacker.data.hp/3.0 and {"Overgrow":"Grass","Blaze":"Fire","Torrent":"Water","Swarm":"Bug"}.get(a,"?")==type: factor*=1.5
	if a=="Guts" and attacker.ailment!="" and move.get("category","")=="Physical": factor*=1.5
	if attacker.get("flash_fire",false) and type=="Fire": factor*=1.5
	if b=="Thick Fat" and type in ["Ice","Fire"]: factor*=0.5
	return factor

func accuracy(attacker,target,normal) -> float:
	if name_of(attacker)=="Compound Eyes": normal*=1.3
	if name_of(target)=="Sand Veil" and c.weather.kind=="sand": normal*=0.8
	return normal

func contact(attacker,target,move):
	if not flag(move,"contact") or attacker.hp<=0: return
	var a=name_of(target)
	var status={"Static":"par","Poison Point":"psn","Flame Body":"brn"}.get(a,"")
	if a=="Effect Spore" and c.rng.randf()<0.1:
		status=["slp","par","psn"][c.rng.randi_range(0,2)]
	elif status!="" and c.rng.randf()>=0.3: status=""
	if status!="": c.Conditions.apply(c,attacker,{"status":status},{})
	if a=="Cute Charm" and attacker.data.get("gender","N")!="N" and target.data.get("gender","N")!="N" and attacker.data.gender!=target.data.gender and c.rng.randf()<0.3:
		c.Conditions.apply(c,attacker,{"volatileStatus":"attract"},{})

func tests():
	for mon in c.roster:
		c.check(not legal(mon.id).is_empty(),"Legal passive slots: "+mon.name)
	var sample={"id":19}
	random.seed=9123
	var counts=[0,0]
	for i in range(10000):
		var m={"id":19}; assign(m,true); counts[m.ability_slot]+=1
	c.check(counts[0]>4700 and counts[0]<5300,"Normal ability slots use equal odds")
	assign(sample,true)
	var saved=sample.duplicate(true)
	assign(sample,true)
	c.check(sample==saved,"Identity never rerolls on repeated assignment")
	c.pick(25,7)
	c.enemy.data.ability="Water Absorb"; c.enemy.hp=50
	c.check(blocks_hit(c.enemy,{"type":"Water"}) and c.enemy.hp>50,"Water Absorb prevents damage and heals")
	c.enemy.data.ability="Levitate"
	c.check(blocks_hit(c.enemy,{"type":"Ground"}),"Levitate prevents Ground damage")
	c.enemy.data.ability="Insomnia"
	c.check(not c.Conditions.apply(c,c.enemy,{"status":"slp"},{}),"Insomnia blocks sleep")
	c.enemy.data.ability="Clear Body"
	c.Conditions.apply(c,c.enemy,{"boosts":{"atk":-1}},{})
	c.check(c.enemy.stages.get("atk",0)==0,"Clear Body prevents hostile stat loss")
	c.player.data.ability="Intimidate"; c.enemy.data.ability="Torrent"
	c.player.erase("ability_entered")
	entry(c.player,c.enemy); entry(c.player,c.enemy)
	c.check(c.enemy.stages.get("atk",0)==-1,"Intimidate runs once per entry")
	c.player.data.ability="Blaze"
	c.player.hp=c.player.data.hp/3.0
	c.check(damage(c.player,c.enemy,{"type":"Fire"})==1.5,"Blaze activates at one-third HP")
	c.player.hp=c.player.data.hp
	c.check(damage(c.player,c.enemy,{"type":"Fire"})==1.0,"Blaze does not boost at full HP")
	c.player.data.ability="Guts"; c.player.ailment="burn"
	c.check(damage(c.player,c.enemy,{"type":"Normal","category":"Physical"})==1.5,"Guts boosts physical attacks while afflicted")
	c.player.data.ability="Chlorophyll"; c.weather.set_weather("sun")
	c.check(speed(c.player)==2,"Chlorophyll doubles movement in sun")
	c.player.data.ability="Swift Swim"; c.weather.set_weather("rain")
	c.check(speed(c.player)==2,"Swift Swim doubles movement in rain")
	c.player.data.ability="Natural Cure"; withdrawn(c.player)
	c.check(c.player.ailment=="","Natural Cure clears status on withdrawal")
	c.enemy.data.ability="Arena Trap"
	c.player.data.types=["Normal"]; c.player.data.ability="Run Away"
	c.check(trapped(c.player,c.enemy),"Arena Trap blocks grounded switches")
	c.player.data.ability="Levitate"
	c.check(not trapped(c.player,c.enemy),"Levitate escapes Arena Trap")
	var saved_shinies=shiny_choices.duplicate(true)
	shiny_choices.clear()
	var charizard=c.roster[c.Dex.find_id(c.roster,6)]
	toggle_shiny(charizard,true,0)
	c.check(configured(charizard,true,0).shiny and not configured(charizard,true,1).shiny and not configured(charizard,false,0).shiny,"Shiny toggle isolates side and team slot")
	c.pick(6,130)
	c.check(c.player.data.shiny,"Selected shiny reaches the actual fighter")
	toggle_shiny(charizard,true,0)
	c.check(not configured(charizard,true,0).shiny,"Shiny toggle returns to normal")
	shiny_choices=saved_shinies
	var config=choices.duplicate(true)
	var mon=c.roster[c.Dex.find_id(c.roster,19)]
	choices[c.move_editor.identity(mon,true,0)]="Guts"
	c.check(configured(mon,true,0).ability=="Guts" and configured(mon,true,1).ability=="Run Away","Ability selector isolates individual team slots")
	choices[c.move_editor.identity(mon,true,0)]="Levitate"
	c.check(configured(mon,true,0).ability=="Run Away","Illegal saved abilities are rejected")
	choices=config
	var evolving={"id":10,"shiny":true,"ability_slot":1,"gender":"F"}
	assign(evolving)
	evolving.id=12
	assign(evolving)
	c.check(evolving.shiny and evolving.ability=="Compound Eyes" and evolving.ability_slot==1,"Evolution preserves rarity and resolves the legal ability from its slot")
	for species in c.roster:
		c.check(c.shiny_portraits.has(int(species.id)) and not c.art.shiny_library.get(int(species.id),{}).is_empty(),"Shiny portrait and animation coverage: "+species.name)
	c.pick(6,130)
	var normal=c.art.frame(c.player)
	c.player.data.shiny=true
	c.check(c.art.frame(c.player).texture!=normal.texture,"Shiny combat uses its own animation sheets")

	random.randomize()
