extends RefCounted

var a
const NAMES=["Hardy","Lonely","Brave","Adamant","Naughty","Bold","Docile","Relaxed","Impish","Lax","Timid","Hasty","Serious","Jolly","Naive","Modest","Mild","Quiet","Bashful","Rash","Calm","Gentle","Sassy","Careful","Quirky"]
const ORDER=["atk","def","spe","spa","spd"]
var pc_box=0
var search=""
var shiny_only=false

func assign(mon, fresh=false):
	if not mon.has("nature"): mon["nature"]=NAMES[a.c.ivs.random.randi_range(0,24)] if fresh else "Hardy"
	if not mon.has("box"): mon["box"]=0

func factor(nature,stat) -> float:
	var index=NAMES.find(nature)
	if index<0 or index/5==index%5: return 1.0
	if stat==ORDER[index/5]: return 1.1
	if stat==ORDER[index%5]: return 0.9
	return 1.0

func nature_text(mon) -> String:
	var n=str(mon.get("nature","Hardy")); var changes=[]
	for stat in ORDER:
		if factor(n,stat)!=1.0: changes.append(("+10% " if factor(n,stat)>1 else "-10% ")+stat.to_upper())
	return n+" / "+(", ".join(changes) if not changes.is_empty() else "neutral")

func owned() -> Array:
	var result=a.data.party+a.data.storage
	var care=a.data.get("services",{}).get("daycare",{})
	if not care.is_empty(): result.append(care.mon)
	return result

func register(mon,caught=true):
	if not a.data.has("pokedex"): a.data["pokedex"]={}
	var key=str(int(mon.id)); var entry=a.data.pokedex.get(key,{"seen":false,"caught":false,"shiny":false})
	entry.seen=true
	entry.caught=entry.caught or caught
	entry.shiny=entry.shiny or bool(mon.get("shiny",false))
	a.data.pokedex[key]=entry

func sync():
	if not a.data.has("pokedex"): a.data["pokedex"]={}
	for mon in owned(): assign(mon); register(mon)
	for key in a.data.get("world_events",{}).get("done",{}):
		if str(key).begins_with("seen:"): register({"id":int(str(key).trim_prefix("seen:"))},false)

func valid(data) -> bool:
	for mon in data.get("party",[])+data.get("storage",[]):
		if mon.has("nature") and mon.nature not in NAMES: return false
		if mon.has("nickname") and (not mon.nickname is String or mon.nickname.length()>16 or "\n" in mon.nickname): return false
		if mon.has("box") and (not (mon.box is int or mon.box is float) or mon.box!=int(mon.box) or mon.box<0 or mon.box>9): return false
	if data.has("pokedex"):
		if not data.pokedex is Dictionary: return false
		for id in data.pokedex:
			if not a.c.roster.any(func(m):return str(int(m.id))==id): return false
			var e=data.pokedex[id]
			if not e is Dictionary: return false
			for field in ["seen","caught","shiny"]:
				if not e.get(field) is bool: return false
	return true

func title(mon) -> String:
	return (str(mon.nickname)+" / " if mon.has("nickname") else "")+a.mon_name(mon.id)+(" *" if mon.get("shiny",false) else "")

func members():
	var list=a.inventory.page("POKEMON SUMMARY / choose your partner")
	for i in range(a.data.party.size()):
		var mon=a.data.party[i]
		a.inventory.row(list,title(mon)+" Lv."+str(mon.level),summary.bind("party",i))

func summary(group,slot):
	if slot<0 or slot>=a.data[group].size(): return
	var mon=a.data[group][slot]; assign(mon)
	var battle=a.battle_mon(mon.id,mon.level,mon)
	var list=a.inventory.page(title(mon)+" / Lv."+str(mon.level))
	var face=TextureRect.new(); face.texture=a.c.portrait(battle); face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; face.custom_minimum_size=Vector2(130,120); list.add_child(face)
	a.inventory.row(list,"TYPE "+" / ".join(battle.types)+" | "+nature_text(mon),func():pass,true)
	a.inventory.row(list,"HP %d/%d | EXP %d/%d | %s" % [roundi(mon.hp*battle.hp),int(battle.hp),mon.xp,a.xp_needed(mon),str(mon.get("ailment","")).to_upper()],func():pass,true)
	a.inventory.row(list,"ATK %d  DEF %d  SPA %d  SPD %d  SPE %d" % [battle.base_stats.atk,battle.base_stats.def,battle.base_stats.spa,battle.base_stats.spd,battle.base_stats.spe],func():pass,true)
	a.inventory.row(list,a.c.ivs.summary(mon),func():pass,true)
	a.inventory.row(list,a.c.ivs.ev_summary(mon),func():pass,true)
	a.inventory.row(list,"ABILITY "+a.c.abilities.legal(mon.id)[int(mon.get("ability_slot",0))%a.c.abilities.legal(mon.id).size()]+" | HELD "+str(mon.get("held_item","none")),func():pass,true)
	for id in mon.moves:
		var move=a.inventory.book.moves[id]
		a.inventory.row(list,move.name+" / "+move.type+" / "+move.get("category","Status"),func():pass,true)
	if not mon.get("pending",[]).is_empty(): a.inventory.row(list,"NEW MOVES: "+", ".join(mon.pending),func():pass,true)
	a.inventory.row(list,"NICKNAME",rename.bind(group,slot),a.in_battle)
	if group=="party":
		a.inventory.row(list,"EDIT MOVESET",a.inventory.moves_menu.bind(slot))
		a.inventory.row(list,"DEPOSIT IN BOX "+str(pc_box+1),deposit.bind(slot),a.in_battle or not can_deposit(slot))
	else:
		a.inventory.row(list,"WITHDRAW / swap with lead if team full",a.withdraw.bind(slot),a.in_battle)
		a.inventory.row(list,"MOVE TO ANOTHER BOX",choose_box.bind(slot),a.in_battle)
		a.inventory.row(list,"RELEASE...",confirm_release.bind(slot),a.in_battle)
	a.inventory.row(list,"BACK",members if group=="party" else pc)

func rename(group,slot):
	if a.in_battle: return
	a.panel("NICKNAME / up to 16 characters")
	var input=LineEdit.new(); input.max_length=16; input.text=str(a.data[group][slot].get("nickname","")); input.position=Vector2(240,290); input.size=Vector2(700,55); a.ui.add_child(input); input.grab_focus()
	a.ui_button("SAVE NAME",Vector2(240,390),Vector2(300,55),func():
		var value=input.text.strip_edges()
		if value=="": a.data[group][slot].erase("nickname")
		else: a.data[group][slot]["nickname"]=value
		a.save(); summary(group,slot))

func can_deposit(slot) -> bool:
	if slot<0 or slot>=a.data.party.size() or a.data.party.size()<2 or a.data.storage.size()>=100: return false
	var remaining=a.data.party.duplicate(); remaining.remove_at(slot)
	return remaining.any(func(m):return m.hp>0)

func deposit(slot):
	if a.in_battle or slot<0 or slot>=a.data.party.size() or not can_deposit(slot): return
	if a.field.losing_surf(slot,{"hp":0,"moves":[]}): return
	var mon=a.data.party[slot]; mon["box"]=pc_box
	a.data.storage.append(mon); a.data.party.remove_at(slot); a.save(); pc()

func pc():
	sync()
	var list=a.inventory.page("PC / BOX %d / %d of 100 stored" % [pc_box+1,a.data.storage.size()])
	var options=HBoxContainer.new(); list.add_child(options)
	var box=OptionButton.new()
	for i in range(10): box.add_item("Box "+str(i+1))
	box.selected=pc_box; box.item_selected.connect(func(i):pc_box=i; pc()); options.add_child(box)
	var input=LineEdit.new(); input.placeholder_text="Name or type..."; input.text=search; input.custom_minimum_size=Vector2(380,44); options.add_child(input)
	var filter=CheckButton.new(); filter.text="Shiny only"; filter.button_pressed=shiny_only; options.add_child(filter)
	var apply=Button.new(); apply.text="SEARCH"; options.add_child(apply)
	apply.pressed.connect(func():search=input.text; shiny_only=filter.button_pressed; pc())
	a.inventory.row(list,"YOUR PARTY / deposit or view summary",members)
	var grid=GridContainer.new(); grid.columns=3; grid.add_theme_constant_override("h_separation",10); grid.add_theme_constant_override("v_separation",10); list.add_child(grid)
	var count=0
	for i in range(a.data.storage.size()):
		var mon=a.data.storage[i]; var species=a.c.roster[a.c.Dex.find_id(a.c.roster,mon.id)]
		if int(mon.get("box",0))!=pc_box or shiny_only and not mon.get("shiny",false): continue
		if search!="" and not (title(mon)+" "+" ".join(species.types)).to_lower().contains(search.to_lower()): continue
		count+=1
		var card=Button.new(); card.text=title(mon)+"\nLv."+str(mon.level)+" / "+"-".join(species.types); card.custom_minimum_size=Vector2(280,105); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; card.icon=a.c.portrait(mon); card.expand_icon=true; card.add_theme_constant_override("icon_max_width",48); card.pressed.connect(summary.bind("storage",i)); grid.add_child(card)
	if count==0: a.inventory.row(list,"No Pokemon match this box and filter.",func():pass,true)

func choose_box(slot):
	var list=a.inventory.page("MOVE TO BOX")
	for i in range(10): a.inventory.row(list,"BOX "+str(i+1),move_box.bind(slot,i))

func move_box(slot,box):
	if a.in_battle or slot<0 or slot>=a.data.storage.size() or box<0 or box>9: return
	a.data.storage[slot]["box"]=box; pc_box=box; a.save(); pc()

func confirm_release(slot):
	if a.in_battle or slot<0 or slot>=a.data.storage.size(): return
	var mon=a.data.storage[slot]; var list=a.inventory.page("RELEASE "+title(mon)+"?")
	a.inventory.row(list,"This permanently removes this Pokemon. Held items return to your Bag.",func():pass,true)
	a.inventory.row(list,"CANCEL",summary.bind("storage",slot))
	a.inventory.row(list,"YES, RELEASE",release_mon.bind(slot))

func release_mon(slot):
	if a.in_battle or slot<0 or slot>=a.data.storage.size(): return
	var mon=a.data.storage[slot]; var held=str(mon.get("held_item",""))
	if held!="" and int(a.data.bag.get(held,0))>=999: return
	register(mon)
	if held!="": a.data.bag[held]=int(a.data.bag.get(held,0))+1
	a.data.storage.remove_at(slot); a.save(); pc()

func dex():
	sync(); var seen=0; var caught=0
	for e in a.data.pokedex.values():
		if e.seen: seen+=1
		if e.caught: caught+=1
	var list=a.inventory.page("POKEDEX / Seen %d / Caught %d / %d" % [seen,caught,a.c.roster.size()])
	for mon in a.c.roster:
		var entry=a.data.pokedex.get(str(int(mon.id)),{})
		a.inventory.row(list,"#%03d  %s  %s" % [mon.id,mon.name if entry.get("seen",false) else "???","CAUGHT" if entry.get("caught",false) else "SEEN" if entry.get("seen",false) else ""],dex_entry.bind(int(mon.id),false),not entry.get("seen",false))

func dex_entry(id,shiny=false):
	var mon=a.c.roster[a.c.Dex.find_id(a.c.roster,id)].duplicate(true); mon["shiny"]=shiny
	var list=a.inventory.page("#%03d / %s / %s" % [id,mon.name," / ".join(mon.types)])
	var face=TextureRect.new(); face.texture=a.c.portrait(mon); face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; face.custom_minimum_size=Vector2(160,150); list.add_child(face)
	a.inventory.row(list,"PLAY CRY",a.c.audio.cry.bind(id))
	if a.data.pokedex[str(id)].shiny: a.inventory.row(list,"SHOW NORMAL" if shiny else "SHOW SHINY",dex_entry.bind(id,not shiny))
	if a.EVOLUTIONS.has(id): a.inventory.row(list,"EVOLUTION: Lv.%d -> %s" % [a.EVOLUTIONS[id][0],a.mon_name(a.EVOLUTIONS[id][1])],func():pass,true)
	var trades={64:65,67:68,75:76,93:94}
	if trades.has(id): a.inventory.row(list,"Original evolution: trade -> "+a.mon_name(trades[id])+" (link trading not available)",func():pass,true)
	for stone in a.extras.STONES:
		if a.extras.STONES[stone].has(id): a.inventory.row(list,"EVOLUTION: "+stone+" -> "+a.mon_name(a.extras.STONES[stone][id]),func():pass,true)
	for source in locations(id): a.inventory.row(list,source,func():pass,true)
	a.inventory.row(list,"BACK TO POKEDEX",dex)

func locations(id) -> Array:
	var result=[]
	for map in a.world.scenes.encounters:
		var habitats=[]
		for habitat in a.world.scenes.encounters[map]:
			var slots=a.world.scenes.encounters[map][habitat]
			if slots is Array and slots.any(func(s):return int(s.get("id",s.get("species",0)))==id): habitats.append(str(habitat).replace("_mons",""))
		if not habitats.is_empty(): result.append(a.world.maps[map].name.replace("_"," ")+" / "+", ".join(habitats))
	if result.is_empty(): result.append("No habitat recorded. May require evolution, a gift or a special event.")
	return result

func tests():
	var before=a.data.duplicate(true); var old_path=a.save_path; var old_save=a.save_allowed; var old_battle=a.in_battle; var old_world=a.world.enabled; var old_pos=a.position_world
	a.save_path="user://collection-regression.json"; a.save_allowed=true; a.in_battle=false; a.world.enabled=false
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.party=[a.new_mon(4,15),a.new_mon(7,10)]; a.inventory.migrate()
	var mon=a.data.party[0]; mon.nature="Adamant"; mon["training"]={"atk":252,"spe":252,"hp":6}; mon["nickname"]="Ember"
	var neutral=mon.duplicate(true); neutral.nature="Hardy"
	var high=a.battle_mon(4,50,mon); var base=a.battle_mon(4,50,neutral)
	a.c.check(high.base_stats.atk>base.base_stats.atk and high.base_stats.spa<base.base_stats.spa and high.hp==base.hp,"Nature modifies opposite stats without changing HP")
	for n in NAMES:
		var up=0; var down=0
		for stat in ORDER:
			if factor(n,stat)>1: up+=1
			if factor(n,stat)<1: down+=1
		a.c.check(up==down and up<=1,"Valid nature stat pair: "+n)
	var legacy={"id":25}; assign(legacy); assign(legacy); a.c.check(legacy.nature=="Hardy","Old partners receive stable neutral natures")
	a.data.bag["kelpsyberry"]=2
	a.c.check(a.extras.use("kelpsyberry",0) and mon.training.atk==242 and a.data.bag.kelpsyberry==1,"EV berry removes ten EVs and consumes exactly one item")
	mon.training.atk=0
	a.c.check(not a.extras.use("kelpsyberry",0) and a.data.bag.kelpsyberry==1,"EV berry at zero is not consumed")
	register({"id":25,"shiny":true},false)
	a.c.check(a.data.pokedex["25"].seen and not a.data.pokedex["25"].caught and a.data.pokedex["25"].shiny,"Seen shiny is tracked without falsely marking caught")
	var original=mon.duplicate(true); pc_box=2; deposit(0)
	a.c.check(a.data.storage.size()==1 and a.data.storage[0].nickname=="Ember" and a.data.storage[0].nature=="Adamant" and int(a.data.storage[0].box)==2,"PC deposit preserves individual data and chosen box")
	move_box(0,4); a.withdraw(0)
	a.c.check(a.data.party.size()==2 and a.data.party[1].ivs==original.ivs and a.data.party[1].training==original.training,"PC withdrawal preserves IVs and EVs")
	a.c.check(not can_deposit(9) and can_deposit(1),"PC rejects invalid slots and permits valid deposit")
	pc_box=0; deposit(1); a.data.storage[0]["held_item"]="quickclaw"
	release_mon(0)
	a.c.check(a.data.storage.is_empty() and int(a.data.bag.quickclaw)==1 and a.data.pokedex["4"].caught,"Release returns held item and preserves historical caught entry")
	a.c.check(not can_deposit(0),"Cannot deposit last Pokemon")
	a.save(); a.load_save()
	a.c.check(a.data.pokedex["4"].caught and a.data.pokedex["25"].shiny and a.valid(a.data),"Collection history survives actual save/load")
	var broken=a.data.duplicate(true); broken.party[0].nature="invalid"
	a.c.check(not a.valid(broken),"Unknown saved nature is rejected")
	a.c.check(locations(25).any(func(v):return "ViridianForest" in v),"Pokedex uses actual habitat data for Pikachu")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(a.save_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(a.save_path+suffix))
	a.data=before; a.save_path=old_path; a.save_allowed=old_save; a.in_battle=old_battle; a.world.enabled=old_world; a.position_world=old_pos; a.clear_ui(); pc_box=0
