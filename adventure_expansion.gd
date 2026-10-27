extends RefCounted
var a
const REMATCHES=["brock","misty","lt_surge","erika","koga","sabrina","blaine","giovanni","lorelei","bruno","agatha","lance","blue"]
const PRIZES={"sitrusberry":1,"lumberry":1,"linkcable":5,"machobrace":5,"powerweight":8,"powerbracer":8,"powerbelt":8,"powerlens":8,"powerband":8,"poweranklet":8,"leftovers":12,"choiceband":20,"choicespecs":20,"choicescarf":20}
var selected=""

func state() -> Dictionary:
	if not a.data.has("postgame"): a.data["postgame"]={"bp":0,"streak":0,"best":0,"pending":"","rematches":[],"tracked":"","elite":0}
	if not a.data.postgame.has("elite"): a.data.postgame["elite"]=0
	return a.data.postgame
func valid(data) -> bool:
	if not data.has("postgame"): return true
	var s=data.postgame
	if not s is Dictionary: return false
	for key in ["bp","streak","best"]:
		var value=s.get(key)
		if not (value is int or value is float) or not is_finite(value) or value!=int(value) or value<0 or value>999999: return false
	var elite=s.get("elite",0)
	if not (elite is int or elite is float) or elite!=int(elite) or elite<0 or elite>4: return false
	if s.best<s.streak: return false
	if not s.get("pending") is String or (s.pending!="" and s.pending!="post_tower" and s.pending not in REMATCHES.map(func(id):return "post_rematch:"+id) and s.pending not in ["post_elite:0","post_elite:1","post_elite:2","post_elite:3","post_elite:4"]): return false
	if not s.get("tracked") is String or (s.tracked!="" and not a.Finale.TASKS.has(s.tracked)): return false
	if not s.get("rematches") is Array or s.rematches.size()>REMATCHES.size(): return false
	var seen=[]
	for id in s.rematches:
		if id not in REMATCHES or id in seen: return false
		seen.append(id)
	return true
func recover():
	if state().pending!="":
		if state().pending=="post_tower": state().streak=0
		if str(state().pending).begins_with("post_elite:"): state().elite=0
		state().pending=""
func unlocked() -> bool: return a.Finale.has(a,"champion")

func hub():
	var s=state(); var list=a.inventory.page("CHAMPION CHALLENGES / BP %d / Tower %d (best %d)" % [s.bp,s.streak,s.best],a.menu)
	if not unlocked(): a.inventory.row(list,"Become Kanto Champion to unlock rematches and the Battle Tower.",func():pass,true); return
	a.inventory.row(list,"BATTLE TOWER / next round / level 50 / matched team sizes",start_tower)
	a.inventory.row(list,"Tower heals your team before each round. Bag items, EXP and EVs are disabled.",func():pass,true)
	a.inventory.row(list,"Win: 3 BP (+5 every seventh win). Defeat or leaving a pending fight ends the streak.",func():pass,true)
	a.inventory.row(list,"ELITE FOUR REMATCH RUN / stage "+str(int(s.elite)+1)+" of 5 / Lv.75-85",start_elite)
	a.inventory.row(list,"Elite run keeps HP between battles. Defeat or interruption resets the run.",func():pass,true)
	a.inventory.row(list,"BP REWARD SHOP",shop)
	for id in REMATCHES: a.inventory.row(list,id.replace("_"," ").capitalize()+" / REMATCH Lv.65-80 / 5 BP"+(" / WON" if id in s.rematches else ""),start_rematch.bind(id))
func trainer(id):
	if id=="lt_surge": id="surge"
	if id=="blue": id={1:"blue_charizard",4:"blue_blastoise",7:"blue_venusaur"}.get(int(a.data.starter),"blue_charizard")
	for entry in a.c.league.trainers:
		if str(entry.id)==id: return entry
	return {}
func ready() -> bool: return unlocked() and not a.in_battle and not a.data.party.is_empty() and a.data.party.any(func(m):return m.hp>0)
func start_rematch(id):
	if not ready() or id not in REMATCHES: return
	var entry=trainer(id)
	if entry.is_empty(): return
	state().pending="post_rematch:"+id
	a.begin_battle(state().pending,entry.team.map(func(m):return int(m.id)),entry.team.map(func(m):return mini(80,maxi(65,int(m.level)+15))))
	a.c.opponent_identity=id
func start_elite():
	if not ready(): return
	var stage=int(state().elite); var id=["lorelei","bruno","agatha","lance","blue"][stage]; var entry=trainer(id)
	state().pending="post_elite:"+str(stage)
	a.begin_battle(state().pending,entry.team.map(func(m):return int(m.id)),entry.team.map(func(m):return mini(85,maxi(75,int(m.level)+20))))
	a.c.opponent_identity=id

func start_tower():
	if not ready(): return
	var pool=[3,6,9,26,31,34,38,59,65,68,76,80,91,94,103,112,121,123,130,131,134,135,136,143,149]
	var ids=[]; var levels=[]
	while ids.size()<a.data.party.size():
		var id=pool[a.c.rng.randi_range(0,pool.size()-1)]
		if id not in ids: ids.append(id); levels.append(50)
	for mon in a.data.party: mon.hp=1.0; mon.ailment=""
	state().pending="post_tower"
	a.begin_battle("post_tower",ids,levels)
	a.c.opponent_identity="blue"
	# Higher streaks improve individual quality, without increasing the level cap.
	for f in a.c.enemy_bench.states:
		var mon={"ivs":a.c.ivs.uniform(mini(31,10+int(state().streak)*2)),"nature":"Hardy"}
		f.data=a.battle_mon(f.data.id,50,mon); f.hp=f.data.hp
func reward(win) -> String:
	var kind=str(a.encounter.get("kind","")); var s=state()
	if s.pending!=kind: return "Challenge result already recorded."
	s.pending=""
	if not win:
		if kind=="post_tower": s.streak=0
		if kind.begins_with("post_elite:"): s.elite=0
		return "Challenge ended. Your earned BP is kept."
	var earned=5
	if kind=="post_tower":
		s.streak=mini(999999,int(s.streak)+1); s.best=maxi(int(s.best),int(s.streak)); earned=3+(5 if int(s.streak)%7==0 else 0)
	elif kind.begins_with("post_elite:"):
		if int(s.elite)<4: s.elite=int(s.elite)+1; earned=2
		else: s.elite=0; earned=20; a.data.money=mini(999999,int(a.data.money)+5000)
	else:
		var id=kind.trim_prefix("post_rematch:")
		if id not in s.rematches: s.rematches.append(id)
		a.data.money=mini(999999,int(a.data.money)+1000)
	s.bp=mini(999999,int(s.bp)+earned)
	return "Challenge won! +%d BP / %d total. Tower streak: %d." % [earned,s.bp,s.streak]
func shop():
	var list=a.inventory.page("BATTLE POINT SHOP / "+str(state().bp)+" BP",hub)
	for id in PRIZES: a.inventory.row(list,a.inventory.ITEMS[id].name+" / "+str(PRIZES[id])+" BP",buy.bind(id),state().bp<PRIZES[id] or int(a.data.bag.get(id,0))>=999)
func buy(id):
	if a.in_battle or not unlocked() or not PRIZES.has(id) or state().bp<PRIZES[id] or int(a.data.bag.get(id,0))>=999: return
	state().bp-=PRIZES[id]; a.data.bag[id]=int(a.data.bag.get(id,0))+1; a.save(); shop()

func journal():
	var list=a.inventory.page("QUEST JOURNAL / "+str(a.Finale.badges(a))+" OF 8 BADGES",a.menu)
	a.inventory.row(list,"MAIN OBJECTIVE: "+a.objective(),func():pass,true)
	for row in early_goals(): a.inventory.row(list,row,func():pass,true)
	a.inventory.row(list,"FOLLOW MAIN OBJECTIVE",untrack)
	a.inventory.row(list,"KANTO MAP / connections and current target",a.world.guide)
	for id in a.Finale.TASKS:
		var task=a.Finale.TASKS[id]; var done=a.Finale.has(a,task.get("flag",id)); var missing=a.Finale.missing(a,task.need)
		a.inventory.row(list,("DONE / " if done else "LOCKED / " if missing!="" else "AVAILABLE / ")+task.name,detail.bind(id))
	a.inventory.row(list,"KEY ITEMS / acquisition journal",a.field.journal)
	a.inventory.row(list,"SEVII QUESTS",a.sevii.journal)
func early_goals() -> Array:
	return [("DONE" if a.data.starter!=0 else "NEXT")+" / Oak - Pallet Town laboratory / choose a starter",("DONE" if a.data.rival else "NEXT")+" / Blue - Pallet Town north exit",("DONE" if a.data.badge else "NEXT")+" / Brock - Pewter Gym / travel through Viridian Forest",("DONE" if a.data.get("rocket",false) else "NEXT")+" / Rocket - Mt. Moon / Boulder Badge required",("DONE" if a.data.get("cascade",false) else "NEXT")+" / Misty - Cerulean Gym",("DONE" if a.Story.state(a).get("thunder",false) else "NEXT")+" / Bill -> S.S. Anne Captain -> Lt. Surge / ticket, Cut tool and Cascade Badge"]
func track(id):
	state().tracked=id; a.save(); detail(id)
func target() -> String:
	var id=state().tracked
	if id=="" or not a.Finale.TASKS.has(id): return main_target()
	var task=a.Finale.TASKS[id]
	if a.Finale.has(a,task.get("flag",id)): return main_target()
	return a.world.names.get(a.world.LEGACY[int(task.map)],"")
func detail(id):
	if not a.Finale.TASKS.has(id): return
	var task=a.Finale.TASKS[id]; var list=a.inventory.page(task.name,journal)
	a.inventory.row(list,"LOCATION: "+a.MAPS[int(task.map)],func():pass,true)
	var giver=str(task.get("trainer",task.name.split(" / ")[0])).replace("_"," ").capitalize()
	a.inventory.row(list,"CONTACT / OBJECT: "+giver,func():pass,true)
	var missing=a.Finale.missing(a,task.need)
	a.inventory.row(list,"REQUIRES: "+(missing if missing!="" else "All prerequisites complete"),func():pass,true)
	a.inventory.row(list,"TRACK ON MAP",track.bind(id))
	var map=a.world.names.get(a.world.LEGACY[int(task.map)],"")
	for step in route(map): a.inventory.row(list,step,func():pass,true)
func route(destination) -> Array:
	var w=a.world; var queue=[w.current]; var previous={w.current:""}; var offset=0
	while offset<queue.size() and not previous.has(destination):
		var here=queue[offset]; offset+=1
		var neighbors=[]
		for link in w.maps[here].connections: neighbors.append(link.map)
		for warp in w.maps[here].warps: neighbors.append(warp.dest_map)
		if here in a.sevii.PORTS: neighbors.append_array(a.sevii.PORTS)
		for next in neighbors:
			if w.maps.has(next) and not previous.has(next): previous[next]=here; queue.append(next)
	if not previous.has(destination): return ["No direct route listed; check local travel services."]
	var path=[]; var cursor=destination
	while cursor!="": path.push_front(w.maps[cursor].name.replace("_"," / ")); cursor=previous[cursor]
	var result=["Suggested map route / gates, field tools and ferry unlocks still apply:"]
	for i in range(path.size()): result.append(str(i+1)+". "+path[i])
	return result

func main_target() -> String:
	if a.data.starter==0: return "MAP_PALLET_TOWN_PROFESSOR_OAKS_LAB"
	if not a.data.rival: return "MAP_PALLET_TOWN"
	if not a.data.bug_catcher: return "MAP_VIRIDIAN_FOREST"
	if not a.data.badge: return "MAP_PEWTER_CITY_GYM"
	if not a.data.get("rocket",false): return "MAP_MT_MOON_1F"
	if not a.data.get("cascade",false): return "MAP_CERULEAN_CITY_GYM"
	var story=a.Story.state(a)
	if not story.get("bridge_rocket",false): return "MAP_ROUTE24"
	if not story.get("ticket",false): return "MAP_ROUTE25_SEA_COTTAGE"
	if not story.get("ship_blue",false): return "MAP_SSANNE_2F_CORRIDOR"
	if not story.get("cut",false): return "MAP_SSANNE_CAPTAINS_ROOM"
	if not story.get("thunder",false): return "MAP_VERMILION_CITY_GYM"
	for id in a.Finale.TASKS:
		var task=a.Finale.TASKS[id]
		if not a.Finale.has(a,task.get("flag",id)) and a.Finale.missing(a,task.need)=="": return a.world.names.get(a.world.LEGACY[int(task.map)],"")
	return "MAP_INDIGO_PLATEAU_EXTERIOR"

func tests():
	var old_current=a.world.current; var old_loaded=a.loaded; var old_game={}
	for key in ["player_team","enemy_team","player_index","enemy_index","team_slot","team_mode","opponent_identity","enemy_party"]:
		var value=a.c.get(key); old_game[key]=value.duplicate(true) if value is Array or value is Dictionary else value
	var before=a.data.duplicate(true); var old_path=a.save_path; var old_allowed=a.save_allowed; var old_battle=a.in_battle; var old_world=a.world.enabled; var old_encounter=a.encounter.duplicate(true); var old_pos=a.position_world
	a.save_path="user://expansion-regression.json"; a.save_allowed=true; a.in_battle=false; a.world.enabled=false
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.party=[a.new_mon(64,30),a.new_mon(7,20)]; a.inventory.migrate()
	a.data.bag.linkcable=2; var mon=a.data.party[0]; var ivs=mon.ivs.duplicate(true); var nature=mon.nature
	a.c.check(a.extras.use("linkcable",0) and mon.id==65 and a.data.bag.linkcable==1 and mon.ivs==ivs and mon.nature==nature,"Link Cable evolves Kadabra without replacing its individual data")
	a.evolutions.clear(); a.clear_ui()
	a.c.check(not a.extras.use("linkcable",1) and a.data.bag.linkcable==1,"Incompatible Link Cable is kept")
	for pair in [[67,68],[75,76],[93,94]]:
		a.data.party[0]=a.new_mon(pair[0],30); a.data.bag.linkcable=1
		a.c.check(a.extras.use("linkcable",0) and a.data.party[0].id==pair[1],"Link Cable evolution: "+str(pair[0]))
		a.evolutions.clear(); a.clear_ui()
	a.inventory.bag(); a.inventory.targets("potion"); a.back_ui()
	a.c.check(a.modal.begins_with("BAG"),"Item target Back returns to Bag")
	a.inventory.move_party(); a.inventory.moves_menu(0); a.back_ui()
	a.c.check(a.modal.begins_with("MOVESETS"),"Moveset Back returns to Pokemon selection")
	a.inventory.replace_menu(0,"tackle",""); a.back_ui()
	a.c.check(" / MOVES / " in a.modal,"Move replacement Back returns one level to moveset")
	a.data.tms={"TM17":1}; a.inventory.tm_targets("TM17"); a.back_ui()
	a.c.check(a.modal.begins_with("TM CASE"),"TM targets Back returns to machine list")
	a.inventory.tm_case(); a.back_ui(); a.c.check(a.modal.begins_with("BAG"),"TM case Back returns to Bag")
	start_tower(); a.c.check(not a.in_battle,"Battle Tower is locked before Champion")
	a.Finale.state(a).champion=true
	for id in REMATCHES: a.c.check(not trainer(id).is_empty(),"Champion rematch has a real trainer team: "+id)
	start_rematch("lt_surge")
	a.c.check(a.in_battle and a.c.enemy_party.size()==3 and a.c.enemy.data.level>=65,"Surge rematch starts with enhanced legal team")
	var money=a.data.money; var message=reward(true); var bp=state().bp; reward(true)
	a.c.check(bp==5 and state().bp==5 and a.data.money==money+1000 and "lt_surge" in state().rematches,"Rematch rewards are recorded exactly once")
	a.in_battle=false; a.clear_ui(); start_tower()
	a.c.check(a.c.player.data.level==50 and a.c.enemy.data.level==50 and a.data.party[0].level==30,"Tower normalizes combat levels without changing saved levels")
	var xp=a.data.party[0].xp; var evs=a.data.party[0].get("training",{}).duplicate(true)
	a.c.enemy.hp=0; a.c.finish_round(); a.c.shots.clear(); a.c.result_time=10; a.record_knockout()
	a.c.check(a.data.party[0].xp==xp and a.data.party[0].get("training",{})==evs,"Tower awards no EXP or EVs")
	a.inventory.bag(); a.c.check(a.modal=="","Tower blocks battle Bag")
	reward(true); a.in_battle=false
	a.c.check(state().streak==1 and state().best==1 and state().bp==8,"Tower awards saved BP and advances streak")
	buy("machobrace"); a.c.check(state().bp==3 and int(a.data.bag.machobrace)==1,"BP shop deducts correct price and grants item")
	state().pending="post_tower"; a.save(); a.load_save()
	a.c.check(state().streak==0 and state().best==1 and state().pending=="" and state().bp==3,"Interrupted Tower run resets streak but preserves best and BP")
	a.c.check(valid(a.data),"Postgame state survives validation")
	a.in_battle=false
	for stage in range(5):
		start_elite(); a.c.check(int(state().elite)==stage and a.c.enemy.data.level>=75,"Elite rematch gauntlet follows stage "+str(stage))
		reward(true); a.in_battle=false
	a.c.check(state().elite==0 and state().bp==31,"Elite gauntlet completion awards total 28 BP and resets")
	var corrupt=a.data.duplicate(true); corrupt.postgame.bp=-1; a.c.check(not valid(corrupt),"Negative BP save is rejected")
	a.world.current="MAP_PALLET_TOWN"; a.c.check(route("MAP_PEWTER_CITY_GYM").size()>2,"Journal finds a map route from Pallet to Brock")
	var previous_difficulty=a.c.difficulty.level
	a.c.difficulty.level=0; var easy=a.c.difficulty.dodge(); a.c.difficulty.level=2
	a.c.check(a.c.difficulty.dodge()>easy and a.c.difficulty.switches()==3,"Difficulty changes reactions while retaining three-switch maximum")
	a.c.difficulty.level=previous_difficulty
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(a.save_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(a.save_path+suffix))
	a.data=before; a.save_path=old_path; a.save_allowed=old_allowed; a.in_battle=old_battle; a.world.enabled=old_world; a.encounter=old_encounter; a.position_world=old_pos; a.world.current=old_current; a.world.events.refresh(); a.loaded=old_loaded; a.clear_ui(); a.evolutions.clear()
	for key in old_game: a.c.set(key,old_game[key])
	a.c.reset()

func untrack():
	state().tracked=""; a.save(); journal()
