extends SceneTree
var c
var a
var w
var base
var checked=0
var triangle_failed={}
const DIRS=[Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]
func _initialize(): run.call_deferred()
func at(p): return (Vector2(p)+Vector2.ONE*.5)*48
func cell(p): return Vector2i((p/48).floor())
func reset(map):
	a.clear_ui(); a.npc_program.cancel(true); w.scenes.reset(); a.data=base.duplicate(true)
	a.in_battle=false; a.exploring=true; c.selecting=true; c.result=""; a.dialog=""
	w.enter(map,Vector2(6.5,8.5)*48)
func warp(index):
	var source=w.current; var door=w.room().warps[index]; var destination=str(door.dest_map)
	a.position_world=w.events.point(door); w.warp_latch=""
	c.check(w.try_warp() and w.current==destination,"Source warp executes: "+source+" #"+str(index))
	c.check(not w.blocked(a.position_world),"Warp arrival is free: "+destination)
	checked+=1
func route(start,goals,floor,edges={}):
	var parents={start:start}; var queue=[start]; var i=0; var end=null
	while i<queue.size():
		var p=queue[i]; i+=1
		if p in goals: end=p; break
		for direction in DIRS:
			var q=p+direction
			if not floor.has(q): continue
			q=edges.get(q,q)
			if parents.has(q): continue
			parents[q]=p; queue.append(q)
	if end==null: return []
	var path=[end]
	while path[0]!=start: path.push_front(parents[path[0]])
	return path
func floor_cells():
	var result={}; var occupied=w.occupied_tiles()
	for y in int(w.room().height):
		for x in int(w.room().width):
			var p=Vector2i(x,y)
			if not w.terrain_blocked(at(p)) and not occupied.has(p): result[p]=true
	return result
func triangle_plan(stage,start,floor) -> Variant:
	if stage==11: return []
	var key=Vector3i(stage,start.x,start.y)
	if triangle_failed.has(key): return null
	var xy=a.postgame.book.triangle[stage]; var target=Vector2i(xy[0],xy[1]); var tiles=floor.duplicate(); tiles.erase(target)
	for d in DIRS:
		var goal=target+d
		if not tiles.has(goal): continue
		var path=route(start,[goal],tiles)
		if path.is_empty() or path.size()-1>int(a.postgame.book.caps[stage-1]): continue
		var rest=triangle_plan(stage+1,goal,floor)
		if rest!=null: return [path]+rest
	triangle_failed[key]=true
	return null
func run():
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; w=a.world; a.loaded=true; a.save_allowed=false; c.campaign.writable=false; w.enabled=true; w.view3d.enabled=false
	base=JSON.parse_string(FileAccess.get_file_as_string("res://captures/journey-sevii-network-machine-ending.json"))
	if not base is Dictionary: push_error("Run campaign journey snapshots first"); quit(2); return
	# Both outcomes on every Cinnabar question; wrong answers begin the source trainer.
	for i in range(1,7):
		reset("MAP_CINNABAR_ISLAND_GYM"); a.Finale.state(a).erase("volcano"); a.Finale.state(a).erase("quiz")
		w.events.state().done.erase("quiz"+str(i))
		w.events.answer(i,not bool(w.events.QUIZZES[i-1][1]))
		c.check(a.in_battle and not w.events.done("quiz"+str(i)),"Wrong answer starts fight without opening door "+str(i))
		w.events.battle_reward(a.encounter.kind,true); a.in_battle=false
		c.check(w.events.done("quiz"+str(i)),"Trainer victory opens matching quiz door "+str(i))
		w.events.state().done.erase("quiz"+str(i)); w.events.answer(i,bool(w.events.QUIZZES[i-1][1]))
		c.check(w.events.done("quiz"+str(i)) and not a.in_battle,"Correct answer bypasses quiz fight "+str(i)); checked+=3
	# Exhaust every first-switch position and every legal adjacent second switch.
	for first in range(1,16):
		for second in range(1,16):
			if absi((first-1)%5-(second-1)%5)+absi(int((first-1)/5)-int((second-1)/5))!=1: continue
			reset("MAP_VERMILION_CITY_GYM"); a.Story.state(a).switch=0
			w.events.state().trash_first=first; w.events.trash(first); w.events.state().trash_second=second
			a.data=JSON.parse_string(JSON.stringify(a.data)); w.events.trash(second)
			c.check(a.Story.state(a).switch==2,"Surge adjacent switches survive reload: "+str(first)+"/"+str(second)); checked+=1
	# All Card Key door signs use the normal adjacent interaction and actual patches.
	var doors=0
	for map in w.maps:
		if not str(map).begins_with("MAP_SILPH_CO_"): continue
		for sign in w.maps[map].signs:
			var script=str(sign.get("script",""))
			if not "_Door" in script: continue
			reset(map); var position=Vector2i(int(sign.x),int(sign.y)); var spot=Vector2i(-1,-1)
			for direction in DIRS:
				if not w.blocked(at(position+direction)): spot=position+direction; break
			c.check(spot.x>=0,"Silph door has an accessible interaction side: "+script)
			if spot.x<0: continue
			a.position_world=at(spot); w.heading=Vector2(position-spot)
			var key=map+"EventScript_Close"+str(w.room().name).trim_prefix("SilphCo_")+"Door"+script.split("_Door")[1]
			w.events.state().done.erase(key); a.Finale.state(a).card_key=false; w.events.refresh(); w.events.interact()
			c.check(not w.events.done(key),"Card Key door refuses absent key: "+script)
			a.Finale.state(a).card_key=true; w.events.interact(); c.check(w.events.done(key),"Card Key opens source door: "+script)
			doors+=1; checked+=2
	# Saffron's full source warp graph must reach Sabrina and allow return.
	reset("MAP_SAFFRON_CITY_GYM"); var floor=floor_cells(); var edges={}
	for i in w.room().warps.size():
		var door=w.room().warps[i]
		if door.dest_map!=w.current: continue
		var source=Vector2i(int(door.x),int(door.y)); warp(i); edges[source]=cell(a.position_world)
	var target=Vector2i(14,11); var goals=DIRS.map(func(d):return target+d)
	var path=route(Vector2i(14,22),goals,floor,edges)
	c.check(not path.is_empty(),"Saffron warp maze reaches Sabrina from entrance")
	if not path.is_empty(): c.check(not route(path[-1],[Vector2i(14,22)],floor,edges).is_empty(),"Saffron maze allows return to exit")
	# Every wrong Dotted Hole choice resets; the source up/left/right/down chain succeeds.
	for pair in [["B1F",1],["B2F",4],["B3F",2],["B4F",3]]:
		for choice in range(1,5):
			reset("MAP_SIX_ISLAND_DOTTED_HOLE_"+pair[0]); warp(choice)
			c.check(w.current!="MAP_SIX_ISLAND_DOTTED_HOLE_1F" if choice==pair[1] else w.current=="MAP_SIX_ISLAND_DOTTED_HOLE_1F","Dotted Hole correct/reset branch: "+pair[0]+"/"+str(choice))
	# Crack each original thin-ice tile, reload, then fall through it.
	reset("MAP_FOUR_ISLAND_ICEFALL_CAVE_1F"); var terrain=w.events.catalog[w.current].behavior.duplicate(); var width=int(w.room().width); var ice=0
	for i in terrain.size():
		if int(terrain[i]) not in [0x26,0x27]: continue
		reset("MAP_FOUR_ISLAND_ICEFALL_CAVE_1F"); var p=Vector2i(i%width,i/width); a.position_world=at(p)
		a.sevii.on_step(); c.check(not w.scenes.active,"Thin ice first step cracks without falling")
		a.data=JSON.parse_string(JSON.stringify(a.data)); a.sevii.on_step(); c.check(w.scenes.active,"Cracked ice remains after reload")
		w.scenes.finish(); c.check(w.current=="MAP_FOUR_ISLAND_ICEFALL_CAVE_B1F" and not w.blocked(a.position_world),"Thin ice lands safely below")
		ice+=1; checked+=3
	# Deoxys: walk shortest legal paths to each new triangle position under source caps.
	reset("MAP_BIRTH_ISLAND_EXTERIOR"); a.postgame.claim_tickets(); if w.scenes.active: w.scenes.finish()
	a.position_world=at(Vector2i(15,13)); floor=floor_cells(); floor[Vector2i(15,12)]=true
	var solution=triangle_plan(1,cell(a.position_world),floor)
	c.check(solution!=null,"Complete Deoxys solution exists within every source step cap")
	if solution==null: print("PUZZLE TRANSITION CHECK: ",c.test_failures); quit(1); return
	a.postgame.triangle()
	for i in range(1,11):
		path=solution[i-1]
		c.check(not path.is_empty() and path.size()-1<=int(a.postgame.book.caps[i-1]),"Deoxys legal route fits step cap: "+str(i))
		for step in path.slice(1):
			c.check(not w.blocked(at(step)),"Deoxys solution walks through clear terrain")
			a.position_world=at(step); a.postgame.step()
		a.postgame.triangle(); checked+=1
	if w.scenes.active: w.scenes.finish()
	c.check(a.in_battle and c.enemy.data.id==386,"Walking the triangle solution summons Deoxys")
	print("PUZZLE TRANSITION CHECK: ",c.test_failures," / ",checked," cases / ",doors," Card Key doors / ",ice," ice tiles")
	quit(0 if c.test_failures.is_empty() else 1)
