extends SceneTree
# Search legal walking/pushing paths, then replay every push through the runtime.
var c
var a
var w
var base
var pushes=0
const DIRS=[Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]
func _initialize(): run.call_deferred()
func at(cell): return (Vector2(cell)+Vector2.ONE*.5)*48
func cell(pos): return Vector2i((pos/48).floor())
func room(id,spawn):
	a.clear_ui(); w.scenes.reset(); a.dialog=""; w.enter(id,at(spawn))
func reload_puzzle():
	a.data.x=a.position_world.x; a.data.y=a.position_world.y
	var saved=JSON.parse_string(JSON.stringify(a.data))
	c.check(a.valid(saved),"Puzzle save validates: "+w.current)
	a.data=saved; w.events.refresh()
func reset():
	a.data=base.duplicate(true); a.in_battle=false; a.exploring=true
	a.clear_ui(); w.scenes.reset(); a.dialog=""
func flood(floor,start,blocked):
	var found={}; var queue=[start]; found[start]=true; var i=0
	while i<queue.size():
		var p=queue[i]; i+=1
		for d in DIRS:
			var q=p+d
			if not floor.has(q) or found.has(q) or blocked.has(q): continue
			found[q]=true; queue.append(q)
	return found
func static_floor():
	var state=w.events.state(); var old=state.done.duplicate()
	for rock in w.events.rocks(): state.done["fallen:"+rock.key]=true
	var floor={}; var occupied=w.occupied_tiles()
	for y in int(w.room().height):
		for x in int(w.room().width):
			var p=Vector2i(x,y)
			if not w.terrain_blocked(at(p)) and not occupied.has(p): floor[p]=true
	state.done=old
	return floor
func solve_push(index:int,goal:Vector2i) -> bool:
	var key=w.current+":"+str(index)
	var rocks=w.events.rocks(); var options=rocks.filter(func(r):return r.key==key)
	if options.is_empty(): c.check(false,"Expected source boulder: "+key); return false
	var rock=options[0]; var start=Vector2i(rock.x,rock.y); var floor=static_floor(); var fixed={}
	for other in rocks:
		if other.key!=key: fixed[Vector2i(other.x,other.y)]=true
	var queue=[{"box":start,"player":cell(a.position_world),"path":[]}]; var visited={}; var cursor=0; var plan=[]; var solved=false
	while cursor<queue.size() and cursor<12000:
		var s=queue[cursor]; cursor+=1
		if s.box==goal: plan=s.path; solved=true; break
		var blocked=fixed.duplicate(); blocked[s.box]=true
		var region=flood(floor,s.player,blocked); var canonical=s.player
		for p in region:
			if p.y<canonical.y or p.y==canonical.y and p.x<canonical.x: canonical=p
		var identity=Vector4i(s.box.x,s.box.y,canonical.x,canonical.y)
		if visited.has(identity): continue
		visited[identity]=true
		for d in DIRS:
			var next=s.box+d
			if not region.has(s.box-d) or not floor.has(next) or fixed.has(next): continue
			var behavior=int(w.events.catalog[w.current].behavior[next.y*int(w.room().width)+next.x])
			if behavior==0x66 and next!=goal: continue
			var path=s.path.duplicate(); path.append([s.box,d])
			queue.append({"box":next,"player":s.box,"path":path})
	c.check(solved,"Legal push route: "+key+" -> "+str(goal)+" / states "+str(cursor))
	if not solved: return false
	for step in plan:
		var current=w.events.rocks().filter(func(r):return r.key==key)
		if current.is_empty(): c.check(false,"Boulder vanished before goal"); return false
		a.position_world=at(step[0]-step[1]); w.heading=Vector2(step[1])
		w.events.push(current[0]); pushes+=1
		a.position_world=at(step[0])
		if w.scenes.active: w.scenes.finish()
	var remaining=w.events.rocks().filter(func(r):return r.key==key)
	c.check(w.events.done("fallen:"+key) or remaining.size()==1 and Vector2i(remaining[0].x,remaining[0].y)==goal,"Runtime reaches searched boulder goal: "+key)
	reload_puzzle()
	return true
func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; w=a.world; a.loaded=true; a.save_allowed=false; c.campaign.writable=false
	base=JSON.parse_string(FileAccess.get_file_as_string("res://captures/journey-sevii-network-machine-ending.json"))
	if not base is Dictionary: push_error("Run check-campaign-journey.gd -- --qa-snapshots first"); quit(2); return
	w.enabled=true; w.view3d.enabled=false; reset()
	room("MAP_VICTORY_ROAD_1F",Vector2i(11,19)); solve_push(4,Vector2i(20,16))
	c.check(w.events.done("VictoryRoad_1F_EventScript_FloorSwitch"),"Victory Road first plate reached by legal pushes")
	room("MAP_VICTORY_ROAD_2F",Vector2i(1,10)); solve_push(10,Vector2i(2,19))
	room("MAP_VICTORY_ROAD_3F",Vector2i(5,3)); solve_push(6,Vector2i(7,7)); solve_push(7,Vector2i(34,18))
	room("MAP_VICTORY_ROAD_2F",Vector2i(34,19)); solve_push(11,Vector2i(14,19))
	c.check(w.events.done("VictoryRoad_2F_EventScript_FloorSwitch2"),"Victory Road exit plate reached after falling boulder")
	print("PUZZLE: Victory Road / ",pushes," pushes")
	reset(); room("MAP_SEAFOAM_ISLANDS_1F",Vector2i(6,20)); solve_push(0,Vector2i(21,8)); solve_push(1,Vector2i(30,8))
	room("MAP_SEAFOAM_ISLANDS_B1F",Vector2i(21,8)); solve_push(0,Vector2i(23,8))
	room("MAP_SEAFOAM_ISLANDS_B1F",Vector2i(31,5)); solve_push(1,Vector2i(28,8))
	room("MAP_SEAFOAM_ISLANDS_B2F",Vector2i(23,8)); solve_push(0,Vector2i(24,8))
	room("MAP_SEAFOAM_ISLANDS_B2F",Vector2i(31,5)); solve_push(1,Vector2i(27,8))
	c.check(w.events.done("calm:MAP_SEAFOAM_ISLANDS_B3F"),"Two upper Seafoam boulders stop the upper current")
	room("MAP_SEAFOAM_ISLANDS_B3F",Vector2i(6,15)); solve_push(5,Vector2i(6,18)); solve_push(4,Vector2i(7,16)); solve_push(3,Vector2i(13,14)); solve_push(2,Vector2i(9,18))
	c.check(w.events.done("calm:MAP_SEAFOAM_ISLANDS_B4F"),"Two lower Seafoam boulders stop Articuno current")
	w.events.reset_rocks(); c.check(not w.events.done("calm:MAP_SEAFOAM_ISLANDS_B4F"),"Seafoam reset restores all floors without duplicated arrivals")
	print("PUZZLE: Seafoam / ",pushes," pushes")
	reset(); room("MAP_SEVEN_ISLAND_SEVAULT_CANYON_TANOBY_KEY",Vector2i(7,12))
	for entry in [[0,7,2],[6,4,4],[1,10,4],[3,5,10],[5,5,6],[3,5,8],[4,9,10],[2,9,6],[4,9,8]]:
		solve_push(entry[0],Vector2i(entry[1],entry[2]))
	c.check(a.sevii.done("tanoby"),"All seven Tanoby switches solved from original positions")
	print("PUZZLE PATH CHECK: ",c.test_failures," / ",pushes," replayed pushes")
	quit(0 if c.test_failures.is_empty() else 1)
