extends RefCounted
# Four Island keeps its two parents and pending egg independently of Route 5.
var a
var random=RandomNumberGenerator.new()
var book: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/breeding.json"))
var hatching=false
var egg_texture: Texture2D

func state() -> Dictionary:
	if not a.data.has("breeding"): a.data.breeding={"parents":[],"pending":{},"steps":0}
	return a.data.breeding

func valid(data) -> bool:
	for mon in data.get("party",[])+data.get("storage",[]):
		if mon.has("is_egg") and not mon.is_egg is bool: return false
		if mon.get("is_egg",false):
			var steps=mon.get("egg_steps",-1)
			if not (steps is int or steps is float) or steps!=int(steps) or steps<0 or steps>100000 or mon.hp!=0 or mon.level!=5: return false
	if not data.has("breeding"): return true
	var s=data.breeding
	if not s is Dictionary or not s.get("parents") is Array or s.parents.size()>2 or not s.get("pending") is Dictionary: return false
	if not (s.get("steps") is int or s.get("steps") is float) or s.steps!=int(s.steps) or s.steps<0 or s.steps>1000000000: return false
	var check=[]
	for entry in s.parents:
		if not entry is Dictionary or not entry.get("mon") is Dictionary: return false
		if not (entry.get("level") is int or entry.get("level") is float) or entry.level!=int(entry.level) or entry.level<1 or entry.level>100: return false
		if entry.mon.get("is_egg",false): return false
		check.append(entry.mon)
	if not s.pending.is_empty():
		if not s.pending.get("is_egg",false): return false
		check.append(s.pending)
	if not check.is_empty():
		var copy=data.duplicate(true); copy.erase("breeding"); copy.erase("services"); copy.party=check; copy.storage=[]; copy.starter=1
		if not a.valid(copy): return false
	return true

func picture() -> Texture2D:
	if egg_texture==null: egg_texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/kanto/egg.png"))
	return egg_texture

func egg_summary(group,slot):
	var mon=a.data[group][slot]; var list=a.inventory.page("EGG",a.collection.members if group=="party" else a.collection.pc)
	var view=TextureRect.new(); view.texture=picture(); view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; view.custom_minimum_size=Vector2(200,220); list.add_child(view)
	var steps=int(mon.egg_steps)
	a.inventory.row(list,"It looks like this Egg will take a long time to hatch." if steps>10000 else "It moves occasionally. It may be close to hatching." if steps>1280 else "Sounds can be heard coming from inside! It will hatch soon!",func():pass,true)
	if group=="party": a.inventory.row(list,"DEPOSIT IN BOX",a.collection.deposit.bind(slot),not a.collection.can_deposit(slot))
	else: a.inventory.row(list,"WITHDRAW",a.withdraw.bind(slot),a.data.party.size()>=6)

func compatibility(parents: Array) -> int:
	if parents.size()!=2: return 0
	var first=parents[0]; var second=parents[1]
	var groups1=book.get(str(int(first.id)),{}).get("groups",["UNDISCOVERED"])
	var groups2=book.get(str(int(second.id)),{}).get("groups",["UNDISCOVERED"])
	if "UNDISCOVERED" in groups1 or "UNDISCOVERED" in groups2 or (first.id==132 and second.id==132): return 0
	var same_ot=first.get("ot","player")==second.get("ot","player")
	if first.id==132 or second.id==132: return 20 if same_ot else 50
	if first.get("gender","N")==second.get("gender","N") or first.get("gender","N")=="N" or second.get("gender","N")=="N": return 0
	if not groups1.any(func(group):return group in groups2): return 0
	return (50 if same_ot else 70) if first.id==second.id else (20 if same_ot else 50)

func offspring(parents: Array) -> Dictionary:
	if compatibility(parents)==0: return {}
	var mother=parents[0]; var father=parents[1]
	if mother.id==132 or (father.id!=132 and mother.get("gender","N")!="F"): mother=parents[1]; father=parents[0]
	var species=int(book[str(int(mother.id))].baby)
	if species==29: species=29 if random.randi_range(0,1)==0 else 32
	if species==314: species=313 if random.randi_range(0,1)==0 else 314
	var items=parents.map(func(mon):return str(mon.get("held_item","")))
	if species==298 and "seaincense" not in items: species=183
	if species==360 and "laxincense" not in items: species=202
	var egg=a.new_mon(species,5)
	egg["is_egg"]=true; egg["egg_steps"]=(int(book[str(species)].cycles)+1)*256; egg.hp=0.; egg.friendship=120
	egg["origin"]="Hatched at Four Island Day Care"; egg["ot"]=str(a.data.get("trainer_id","player"))
	var available=["hp","atk","def","spe","spa","spd"]
	for i in 3:
		var chosen=random.randi_range(0,available.size()-1); var stat=available.pop_at(chosen)
		egg.ivs[stat]=parents[random.randi_range(0,1)].ivs[stat]
	# A male paired with Ditto contributes its egg/TM moves; Ditto never does.
	if father.id==132 and mother.get("gender","N")!="F": var swap=mother; mother=father; father=swap
	var inherited=[]; var species_book=a.inventory.book.species[str(species)]
	for move in father.moves:
		if move in book[str(species)].moves or species_book.tms.any(func(tm):return a.inventory.book.tms[tm].move==move): inherited.append(move)
	for move in father.moves:
		if move in mother.moves and species_book.levels.any(func(entry):return entry.move==move) and move not in inherited: inherited.append(move)
	for move in inherited:
		if move in egg.moves: continue
		if egg.moves.size()>=4: egg.moves.pop_front()
		egg.moves.append(move)
	egg["egg_moves"]=inherited
	return egg

func menu():
	if not a.world.current.begins_with("MAP_FOUR_ISLAND") or a.in_battle: return
	var s=state(); var list=a.inventory.page("FOUR ISLAND DAY CARE / two parents")
	for i in s.parents.size():
		var parent=s.parents[i]; var cost=100+100*(int(parent.mon.level)-int(parent.level))
		a.inventory.row(list,"RETRIEVE "+a.collection.title(parent.mon)+" Lv."+str(parent.mon.level)+" / $"+str(cost),withdraw.bind(i),a.data.party.size()>=6 or a.data.money<cost)
	if s.parents.size()<2:
		for i in a.data.party.size():
			var mon=a.data.party[i]
			a.inventory.row(list,"LEAVE "+a.collection.title(mon),deposit.bind(i),mon.get("is_egg",false) or mon.hp<=0 or a.data.party.filter(func(m):return m.hp>0).size()<2)
	else:
		var chance=compatibility(s.parents.map(func(entry):return entry.mon))
		a.inventory.row(list,("They prefer to play with other Pokemon." if chance==0 else "The two get along"+(" very well!" if chance==70 else "."))+" / Egg chance: "+str(chance)+"% per 256 steps",func():pass,true)
	if not s.pending.is_empty(): a.inventory.row(list,"The Day-Care Man found an Egg! / TAKE EGG",take_egg,a.data.party.size()>=6)
	a.inventory.row(list,"Parents gain 1 EXP per step. Retrieval: $100 + $100 per level gained.",func():pass,true)

func deposit(slot: int):
	var s=state()
	if a.in_battle or slot<0 or slot>=a.data.party.size() or s.parents.size()>=2: return
	var mon=a.data.party[slot]
	if mon.get("is_egg",false) or mon.hp<=0 or a.data.party.filter(func(m):return m.hp>0).size()<2: return
	if a.field.losing_surf(slot,{"hp":0,"moves":[]}): return
	s.parents.append({"mon":mon,"level":mon.level}); a.data.party.remove_at(slot); s.steps=0
	a.save(); menu()

func withdraw(slot: int):
	var s=state()
	if a.in_battle or slot<0 or slot>=s.parents.size() or a.data.party.size()>=6: return
	var entry=s.parents[slot]; var cost=100+100*(int(entry.mon.level)-int(entry.level))
	if a.data.money<cost: return
	a.data.money-=cost; a.data.party.append(entry.mon); s.parents.remove_at(slot); s.steps=0
	a.save(); menu()

func take_egg():
	var s=state()
	if a.in_battle or a.data.party.size()>=6 or s.pending.is_empty(): return
	a.data.party.append(s.pending.duplicate(true)); s.pending={}; a.save(); menu()

func step():
	var s=state(); s.steps=mini(1000000000,int(s.steps)+1)
	for entry in s.parents:
		var mon=entry.mon
		if mon.level>=100: continue
		mon.xp+=1
		if mon.xp>=a.xp_needed(mon):
			mon.xp-=a.xp_needed(mon); mon.level+=1; a.inventory.level_up(mon,mon.id,mon.level)
	if int(s.steps)%256==0 and s.pending.is_empty() and s.parents.size()==2:
		var parents=s.parents.map(func(entry):return entry.mon)
		if random.randi_range(0,99)<compatibility(parents): s.pending=offspring(parents)
	for mon in a.data.party:
		if mon.get("is_egg",false): mon.egg_steps=maxi(0,int(mon.egg_steps)-1)

func tick() -> bool:
	if hatching: return true
	if a.in_battle or a.modal!="" or a.dialog!="" or a.world.scenes.active: return false
	for mon in a.data.party:
		if mon.get("is_egg",false) and int(mon.egg_steps)==0: hatch(mon); return true
	return false

func hatch(mon):
	hatching=true; a.c.click_move=false; a.world.stepping=false
	a.panel("OH? / THE EGG IS HATCHING")
	for child in a.ui.get_children():
		if child is Button: child.queue_free()
	var view=TextureRect.new(); view.texture=picture(); view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.position=Vector2(500,320); view.size=Vector2(280,280); view.pivot_offset=Vector2(140,140); a.ui.add_child(view)
	var tween=a.create_tween()
	for i in 6: tween.tween_property(view,"rotation",.12 if i%2 else -.12,.14)
	tween.tween_property(view,"modulate",Color(5,5,5),.55)
	tween.tween_callback(func():
		mon.is_egg=false; mon.erase("egg_steps"); mon.hp=1.; mon.friendship=120
		a.collection.register(mon); a.save()
		view.rotation=0; view.modulate=Color.WHITE; view.texture=a.collection.full_picture(mon)
		a.c.audio.cry(mon.id)
		a.ui_label(a.mon_name(mon.id)+" hatched from the Egg!",Vector2(390,640),26)
		a.ui_button("WELCOME, "+a.mon_name(mon.id).to_upper()+"!",Vector2(390,720),Vector2(500,52),func():hatching=false; a.clear_ui()))
