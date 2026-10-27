extends RefCounted

const STATS=["hp","atk","def","spa","spd","spe"]
var c
var random=RandomNumberGenerator.new()
var choices={}
var window: Window
var boxes={}
var editing=""
var natures={}
var nature_choice: OptionButton
var item_choice: OptionButton
var ev_yields: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/ev-yields.json"))

func ev_total(mon) -> int:
	var total=0
	for value in mon.get("training",{}).values(): total+=int(value)
	return total

func award_evs(species):
	var yields=ev_yields.get(str(int(species)),{})
	# The existing shared EXP system rewards every healthy teammate, so EV recipients match.
	for mon in c.adventure.data.party:
		if mon.hp<=0: continue
		var awarded=c.gear.ev_yield(mon,yields)
		var values=mon.get("training",{})
		var remaining=510-ev_total(mon)
		for stat in STATS:
			var gain=mini(int(awarded.get(stat,0)),mini(252-int(values.get(stat,0)),remaining))
			if gain>0: values[stat]=int(values.get(stat,0))+gain; remaining-=gain
		mon["training"]=values

func ev_summary(mon) -> String:
	var values=mon.get("training",{})
	return "EVs %d/510 | HP %d ATK %d DEF %d SPA %d SPD %d SPE %d (max 252/stat)" % [ev_total(mon),values.get("hp",0),values.get("atk",0),values.get("def",0),values.get("spa",0),values.get("spd",0),values.get("spe",0)]

func install(context):
	c=context; random.randomize()
	if OS.get_cmdline_user_args().is_empty() and FileAccess.file_exists("user://battle-natures.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string("user://battle-natures.json"))
		if saved is Dictionary:
			for key in saved:
				if saved[key] in c.adventure.collection.NAMES: natures[key]=saved[key]
	if OS.get_cmdline_user_args().is_empty() and FileAccess.file_exists("user://battle-ivs.json"):
		var data=JSON.parse_string(FileAccess.get_file_as_string("user://battle-ivs.json"))
		if data is Dictionary:
			for key in data:
				if valid(data[key]): choices[key]=data[key]

func valid(values) -> bool:
	if not values is Dictionary or values.size()!=6: return false
	for stat in STATS:
		var n=values.get(stat)
		if not (n is int or n is float) or not is_finite(n) or n!=int(n) or n<0 or n>31: return false
	return true

func uniform(value=31) -> Dictionary:
	var result={}
	for stat in STATS: result[stat]=value
	return result

func roll() -> Dictionary:
	var result={}
	for stat in STATS: result[stat]=random.randi_range(0,31)
	return result

func assign(mon):
	if not mon.has("ivs"): mon["ivs"]=roll()
	if valid(mon.ivs):
		for stat in STATS: mon.ivs[stat]=int(mon.ivs[stat])

func migrate(data):
	# Deterministic only for pre-IV saves, so restarting before autosave cannot reroll them.
	for group in ["party","storage"]:
		for i in range(data[group].size()):
			var mon=data[group][i]
			if not mon.has("ivs"):
				var legacy=RandomNumberGenerator.new(); legacy.seed=hash(group+str(i)+JSON.stringify(mon))
				mon["ivs"]={}
				for stat in STATS: mon.ivs[stat]=legacy.randi_range(0,31)
			assign(mon)
	var daycare=data.get("services",{}).get("daycare",{})
	if not daycare.is_empty() and not daycare.mon.has("ivs"):
		var legacy=RandomNumberGenerator.new(); legacy.seed=hash("daycare"+JSON.stringify(daycare.mon))
		daycare.mon["ivs"]={}
		for stat in STATS: daycare.mon.ivs[stat]=legacy.randi_range(0,31)
	if not daycare.is_empty(): assign(daycare.mon)

func configured(mon,friendly,slot) -> Dictionary:
	var key=c.move_editor.identity(mon,friendly,slot)
	var values=choices.get(key,uniform())
	if not valid(values): values=uniform()
	var result=apply_values(mon,values)
	result["nature"]=natures.get(key,"Hardy")
	result["held_item"]=c.gear.choices.get(key,"")
	for stat in c.adventure.collection.ORDER: result.base_stats[stat]*=c.adventure.collection.factor(result.nature,stat)
	result.speed*=c.adventure.collection.factor(result.nature,"spe")
	return result

func apply_values(mon,values) -> Dictionary:
	var result=mon.duplicate(true)
	# Preserve the unmodified source so repeated previews never add IVs twice.
	if not result.has("iv_base_stats"):
		result["iv_base_stats"]=result.base_stats.duplicate(true); result["iv_base_hp"]=result.hp; result["iv_base_speed"]=result.speed
	result.base_stats=result.iv_base_stats.duplicate(true)
	result["ivs"]=values.duplicate(true)
	for stat in STATS: result.base_stats[stat]=float(result.base_stats[stat])+float(values[stat])/2.0
	result.hp=float(result.iv_base_hp)+float(values.hp)/2.0
	result.speed=float(result.iv_base_speed)+float(values.spe)/2.0
	return result

func open(mon,friendly,slot):
	if window!=null and is_instance_valid(window): window.queue_free()
	editing=c.move_editor.identity(mon,friendly,slot)
	window=Window.new(); window.title=mon.name+" / IVs, nature and held item"; window.size=Vector2i(440,510)
	window.transient=true; window.exclusive=true; c.add_child(window)
	window.close_requested.connect(func():window.hide())
	var values=choices.get(editing,uniform()); boxes={}
	for i in range(STATS.size()):
		var label=Label.new(); label.text=STATS[i].to_upper(); label.position=Vector2(30,25+i*43); window.add_child(label)
		var box=SpinBox.new(); box.min_value=0; box.max_value=31; box.step=1; box.value=values[STATS[i]]; box.position=Vector2(150,20+i*43); box.size=Vector2(240,35)
		window.add_child(box); boxes[STATS[i]]=box
	for spec in [["ALL 31",20,func():set_boxes(uniform())],["RANDOM",155,func():set_boxes(roll())],["APPLY",290,apply]]:
		var button=Button.new(); button.text=spec[0]; button.position=Vector2(spec[1],425); button.size=Vector2(125,44); button.pressed.connect(spec[2]); window.add_child(button)
	var hint=Label.new(); hint.text="Close to cancel. This side and team slot only."; hint.position=Vector2(20,478); window.add_child(hint)
	nature_choice=OptionButton.new(); nature_choice.position=Vector2(20,295); nature_choice.size=Vector2(395,45)
	for nature in c.adventure.collection.NAMES: nature_choice.add_item(c.adventure.collection.nature_text({"nature":nature}))
	nature_choice.selected=c.adventure.collection.NAMES.find(natures.get(editing,"Hardy")); window.add_child(nature_choice)
	item_choice=OptionButton.new(); item_choice.position=Vector2(20,355); item_choice.size=Vector2(395,45); item_choice.add_item("HELD ITEM: none")
	for item in c.adventure.extras.HELD: item_choice.add_item("HELD ITEM: "+item)
	item_choice.selected=c.adventure.extras.HELD.find(c.gear.choices.get(editing,""))+1; window.add_child(item_choice)
	window.popup_centered()

func set_boxes(values):
	for stat in STATS:
		boxes[stat].value=values[stat]
		boxes[stat].get_line_edit().text=str(values[stat])

func apply():
	var values={}
	for stat in STATS:
		boxes[stat].apply()
		values[stat]=int(boxes[stat].value)
	if not valid(values): return
	choices[editing]=values
	natures[editing]=c.adventure.collection.NAMES[nature_choice.selected]
	c.gear.choose(editing,"" if item_choice.selected==0 else c.adventure.extras.HELD[item_choice.selected-1])
	if OS.get_cmdline_user_args().is_empty():
		var file=FileAccess.open("user://battle-ivs.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(choices))
		file=FileAccess.open("user://battle-natures.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(natures))
	window.hide(); c.queue_redraw()

func summary(mon) -> String:
	var values=mon.get("ivs",uniform(0)); var sum=0
	for n in values.values(): sum+=int(n)
	return "IVs %d/186 | HP %d ATK %d DEF %d SPA %d SPD %d SPE %d" % [sum,values.hp,values.atk,values.def,values.spa,values.spd,values.spe]

func party_menu():
	var a=c.adventure; a.inventory.migrate()
	var list=a.inventory.page("POKEMON STATS / IVs 0-31 / EVs 252 per stat, 510 total")
	for mon in a.data.party+a.data.storage:
		a.inventory.row(list,a.mon_name(mon.id)+" Lv."+str(mon.level)+" / "+summary(mon),func():pass,true)
		a.inventory.row(list,ev_summary(mon),func():pass,true)
	var daycare=a.data.get("services",{}).get("daycare",{})
	if not daycare.is_empty():
		a.inventory.row(list,"DAY CARE / "+a.mon_name(daycare.mon.id)+" / "+summary(daycare.mon),func():pass,true)
		a.inventory.row(list,ev_summary(daycare.mon),func():pass,true)

func tests():
	var previous=c.adventure.data.duplicate(true); var saved_natures=natures.duplicate(true); var saved_choices=choices.duplicate(true); var rng_state=random.state
	var a=c.adventure; var saving=a.save_allowed; a.save_allowed=false
	for i in range(500): c.check(valid(roll()),"Six IVs remain integral and bounded 0-31")
	for invalid in [-1,32,1.5,"31"]:
		var values=uniform(); values.atk=invalid; c.check(not valid(values),"Invalid IV rejected")
	var missing=uniform(); missing.erase("spe"); c.check(not valid(missing),"Partial IV blocks are rejected")
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.party=[a.new_mon(4,15)]
	var mon=a.data.party[0]; var values=mon.ivs.duplicate(true)
	mon["training"]={}; award_evs(16)
	c.check(int(mon.training.get("spe",0))==1,"Pidgey defeat awards one Speed EV")
	award_evs(74); c.check(int(mon.training.get("def",0))==1,"Geodude defeat awards one Defense EV")
	mon.training={"spe":251}; award_evs(18)
	c.check(mon.training.spe==252,"Battle EVs stop at 252 per stat")
	mon.training={"spe":252,"atk":252,"hp":5}; award_evs(113)
	c.check(ev_total(mon)==510 and mon.training.hp==6,"Mixed EV yields respect the total 510 cap")
	mon.hp=0; mon.training={}; award_evs(16)
	c.check(mon.training.is_empty(),"Fainted teammates do not receive EVs")
	mon.hp=1; mon.training={"spe":4}
	var ev_before=mon.training.duplicate(true)
	var with_evs=a.battle_mon(4,50,mon); var untrained=mon.duplicate(true); untrained.training={}
	c.check(with_evs.speed>a.battle_mon(4,50,untrained).speed,"Four Speed EVs increase real movement speed")
	a.inventory.migrate(); a.inventory.migrate(); c.check(mon.ivs==values,"Existing IVs never reroll on menu/migration")
	var old=mon.duplicate(true); old.erase("ivs")
	var legacy={"party":[old.duplicate(true)],"storage":[]}; migrate(legacy)
	var again={"party":[old.duplicate(true)],"storage":[]}; migrate(again)
	c.check(legacy.party[0].ivs==again.party[0].ivs,"Legacy migration remains stable even before the next save")
	var zero=mon.duplicate(true); zero.ivs=uniform(0)
	var perfect=mon.duplicate(true); perfect.ivs=uniform()
	var low=a.battle_mon(4,50,zero); var high=a.battle_mon(4,50,perfect)
	c.check(high.hp>low.hp and high.speed>low.speed,"HP and Speed IVs affect live battle values")
	for stat in STATS: c.check(high.base_stats[stat]>low.base_stats[stat],"IV changes real "+stat+" battle stat")
	a.grant_xp(a.xp_needed(mon)-int(mon.xp))
	c.check(mon.id==5 and mon.ivs==values,"Level-up and evolution preserve all six IVs")
	c.check(mon.training==ev_before,"Evolution preserves earned EVs")
	var loaded=JSON.parse_string(JSON.stringify(a.data)); migrate(loaded); c.check(a.valid(loaded) and loaded.party[0].ivs==values,"Adventure IVs survive validated JSON round trip")
	loaded.party[0].ivs.hp=32; c.check(not a.valid(loaded),"Corrupt adventure IVs reject save rather than reroll")
	loaded=JSON.parse_string(JSON.stringify(a.data)); loaded.party[0].training={"atk":253}
	c.check(not a.valid(loaded),"Save validation rejects EVs above the per-stat cap")
	choices.clear(); var species=c.roster[c.Dex.find_id(c.roster,4)]
	choices[c.move_editor.identity(species,true,0)]=uniform(0)
	var first=configured(species,true,0); var next=configured(first,true,0)
	c.check(first.base_stats==next.base_stats and first.hp==next.hp,"IV configuration is idempotent")
	c.check(configured(species,true,1).ivs==uniform() and configured(species,false,0).ivs==uniform(),"IV edits isolate team slots and CPU side")
	open(species,true,0); set_boxes(uniform(7)); nature_choice.selected=c.adventure.collection.NAMES.find("Adamant"); apply()
	c.check(choices[c.move_editor.identity(species,true,0)]==uniform(7),"IV editor applies all six numeric controls")
	var natural=configured(species,true,0)
	c.check(natural.nature=="Adamant" and natural.base_stats.atk>apply_values(species,uniform(7)).base_stats.atk,"Free battle nature editor changes real stats")
	c.check(configured(natural,true,0).base_stats==natural.base_stats,"Repeated nature previews never stack bonuses")
	open(species,true,0); set_boxes(uniform(2)); nature_choice.selected=0; window.hide()
	c.check(natures[c.move_editor.identity(species,true,0)]=="Adamant","Closing editor cancels nature changes")
	c.check(choices[c.move_editor.identity(species,true,0)]==uniform(7),"Closing IV editor cancels draft changes")
	window.queue_free(); window=null
	a.clear_ui(); a.evolutions.clear(); a.data=previous; a.save_allowed=saving; choices=saved_choices; natures=saved_natures; random.state=rng_state
