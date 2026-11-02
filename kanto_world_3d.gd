extends Node
# The 3D scene is a view of kanto_world; all authoritative state stays in 2D tiles.
const Kit=preload("res://kanto_model_kit.gd")
var w
var a
var viewport: SubViewport
var camera: Camera3D
var stage: Node3D
var terrain: Node3D
var people: Node3D
var props: Node3D
var kit=Kit.new()
var catalog: Dictionary={}
var loaded=""
var patch_key=""
var props_key=""
var actors={}
var labels=[]
var age=0.0
var character_pose=preload("res://kanto_character_models.gd").new()
var map_cache={}
var neighbors=[]
var keep_focus=false

func connection_offset(from_id: String, link: Dictionary) -> Vector3:
	var source=w.maps[from_id]; var target=w.maps[link.map]; var offset=float(link.offset)
	match link.direction:
		"up": return Vector3(offset,0,-float(target.height))
		"down": return Vector3(offset,0,float(source.height))
		"left": return Vector3(-float(target.width),0,offset)
		"right": return Vector3(float(source.width),0,offset)
	return Vector3.ZERO

func rebase(from_id: String, link: Dictionary):
	if not viewport: return
	var offset=connection_offset(from_id,link)
	focus-=offset; camera.position-=offset; keep_focus=true

func preload_neighbor():
	if neighbors.is_empty(): return
	var next=neighbors.pop_front()
	if not map_cache.has(next.id):
		build_terrain(next.id)
		map_cache[next.id]=terrain
	map_cache[next.id].position=next.offset
	map_cache[next.id].visible=true
	terrain=map_cache[loaded]
var refresh_clock=0.0
var active=false
var enabled=true
var map_build_ms=0
var focus=Vector3.ZERO
var sun: DirectionalLight3D
var environment: Environment

func install(world):
	w=world; a=w.a
	name="Kanto3D"
	a.add_child(self)
	var settings=ConfigFile.new()
	if settings.load("user://world-graphics.cfg")==OK: enabled=bool(settings.get_value("graphics","modern",true))
	# Load lazily: battles/menu and the headless gameplay suite do not build a world.
	set_process(true)

func initialize():
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/world-3d.json"))
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,700)
	viewport.own_world_3d=true; viewport.transparent_bg=false
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(viewport)
	stage=Node3D.new(); viewport.add_child(stage)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=16; camera.far=180; camera.current=true; stage.add_child(camera)
	var world_environment=WorldEnvironment.new(); var env=Environment.new()
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("a7c6bd")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("dce8f0"); env.ambient_light_energy=.42
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	world_environment.environment=env; environment=env; stage.add_child(world_environment)
	sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-65,-28,0); sun.light_color=Color("fff8eb"); sun.light_energy=.58
	sun.shadow_enabled=true; sun.directional_shadow_max_distance=65; sun.shadow_bias=.035; sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	stage.add_child(sun)
	people=Node3D.new(); stage.add_child(people)
	props=Node3D.new(); stage.add_child(props)

func _process(dt):
	active=enabled and a.exploring and w.enabled and not a.in_battle and not a.c.frontend.layer.visible
	if not active:
		if viewport: viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	if not viewport: initialize()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	age+=dt
	var patches=JSON.stringify(w.events.patches)
	if loaded!=w.current or patches!=patch_key:
		build(); patch_key=patches
	elif not neighbors.is_empty(): preload_neighbor()
	var target=Vector3(a.position_world.x/w.TILE,0,a.position_world.y/w.TILE)
	kit.update_player(target)
	focus=focus.lerp(target,1.0-exp(-dt*9.0))
	camera.position=focus+Vector3(0,22,20)
	camera.look_at(focus+Vector3(0,0,-1.4))
	refresh_clock-=dt
	if refresh_clock<=0:
		refresh_clock=.12; sync_actors(); sync_props()
	if actors.has("player"):
		move_actor(actors.player,a.position_world,w.heading,w.stepping or w.events.spin!=Vector2.ZERO)
		if w.jumping: actors.player.position.y=sin(clampf(a.position_world.distance_to(w.jump_start)/(2*w.TILE),0,1)*PI)*.65
	if w.scenes.active:
		var scene_key=str(w.scenes.actor.get("key",""))
		for key in actors:
			if key=="player" or scene_key=="" or not str(key).begins_with(scene_key): continue
			if w.scenes.positions.has(scene_key): move_actor(actors[key],w.scenes.positions[scene_key],w.scenes.actor.get("look",Vector2.DOWN),w.scenes.actor.get("walking",false))
	a.queue_redraw()

func build():
	var started=Time.get_ticks_msec()
	var patch_changed=map_cache.has(w.current) and map_cache[w.current].get_meta("patches","{}")!=JSON.stringify(w.events.patches)
	if patch_changed and map_cache.has(w.current): map_cache[w.current].free(); map_cache.erase(w.current)
	for node in people.get_children(): node.free()
	actors.clear(); loaded=w.current; props_key=""; labels.clear()
	var meta=catalog[loaded]; var outside=bool(meta.outdoor); var cave=bool(meta.cave)
	sun.light_energy=.65 if outside else .42
	environment.ambient_light_energy=.31 if outside else .43
	environment.background_color=Color("a2bca3") if outside else Color("37474b")
	camera.size=14.0 if outside or cave else clampf(w.room().height*.8,11,16)
	for node in map_cache.values(): node.visible=false
	if not map_cache.has(loaded): build_terrain(loaded); map_cache[loaded]=terrain
	terrain=map_cache[loaded]; terrain.position=Vector3.ZERO; terrain.visible=true
	neighbors.clear()
	var wanted=[loaded]
	if outside:
		for link in w.room().connections:
			if not catalog.has(link.map) or not catalog[link.map].outdoor: continue
			wanted.append(link.map)
			var offset=connection_offset(loaded,link)
			if map_cache.has(link.map): map_cache[link.map].position=offset; map_cache[link.map].visible=true
			else: neighbors.append({"id":link.map,"offset":offset})
	for id in map_cache.keys():
		if id not in wanted and map_cache.size()>7: map_cache[id].free(); map_cache.erase(id)
	if not keep_focus: focus=Vector3(a.position_world.x/w.TILE,0,a.position_world.y/w.TILE)
	keep_focus=false
	sync_actors(); sync_props()
	map_build_ms=Time.get_ticks_msec()-started

func build_terrain(map_id: String):
	terrain=Node3D.new(); stage.add_child(terrain)
	terrain.set_meta("patches",JSON.stringify(w.events.patches) if map_id==w.current else "{}")
	var loaded=map_id
	var room=w.maps[map_id]; var meta=catalog[map_id]; var width=int(room.width); var height=int(room.height)
	var outside=bool(meta.outdoor); var cave=bool(meta.cave)
	var stairs=meta.get("stairs",[]).map(func(index):return int(index))
	var ladders=meta.get("ladders",[]).map(func(index):return int(index))
	var home=not outside and ("HOUSE" in loaded or "COTTAGE" in loaded or "DAY_CARE" in loaded)
	var base="6e9867" if outside else "6f7569" if cave else "a9a18e"
	kit.stamp("box",Vector3(width*.5,-.24,height*.5),Vector3(width+.2,.42,height+.2),base)
	# A low landscape apron hides empty space along map borders, without collisions.
	if outside: kit.stamp("box",Vector3(width*.5,-.48,height*.5),Vector3(width,.25,height),"739a6d")
	var ground_image=Image.load_from_file(meta.ground); ground_image.generate_mipmaps()
	var ground=MeshInstance3D.new(); var plane=PlaneMesh.new(); plane.size=Vector2(width,height)
	var surface=StandardMaterial3D.new(); surface.albedo_texture=ImageTexture.create_from_image(ground_image); surface.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; surface.roughness=1
	ground.mesh=plane; ground.material_override=kit.art.ground(surface.albedo_texture) if home else surface; ground.position=Vector3(width*.5,.005,height*.5); terrain.add_child(ground)
	# Exhibit footprints come from the source museum layout.
	var exhibit_cells={}
	for display in meta.get("exhibits",[]):
		kit.exhibit(Vector3(display[0]+display[2]*.5,0,display[1]+display[3]*.5),Vector2(display[2],display[3]),display[4])
		for zz in range(int(display[1]),int(display[1]+display[3])):
			for xx in range(int(display[0]),int(display[0]+display[2])): exhibit_cells[zz*width+xx]=true
	# Build contiguous service counters once, rather than a grid of padded cubes.
	var merged={}
	if "POKEMON_CENTER" in loaded or "LAB" in loaded or "MART" in loaded or home:
		for i in room.cells.size():
			if i in stairs or i in ladders or merged.has(i) or meta.tiles[i] not in (["table"] if home else ["furniture","table"]): continue
			var x=i%width; var z=int(i/width); var span=1; var depth=1
			while x+span<width and not i+span in stairs+ladders and not merged.has(i+span) and meta.tiles[i+span] in ["furniture","table"]: span+=1
			while z+depth<height:
				var complete=true
				for dx in span:
					var next=(z+depth)*width+x+dx
					if next in stairs+ladders or merged.has(next) or meta.tiles[next] not in ["furniture","table"]: complete=false; break
				if not complete: break
				depth+=1
			for dz in depth:
				for dx in span: merged[(z+dz)*width+x+dx]=true
			if home: kit.dining_table(Vector3(x+span*.5,0,z+depth*.5),Vector2(span,depth))
			else: kit.counter(Vector3(x+span*.5,0,z+depth*.5),Vector2(span,depth),loaded)
	for i in room.cells.size():
		var x=i%width; var z=int(i/width); var p=Vector3(x+.5,0,z+.5); var kind=str(meta.tiles[i]); var tile=int(room.cells[i])&1023
		var patch=w.events.patches.get(Vector2i(x,z),{}) if loaded==w.current else {}
		if not patch.is_empty():
			# Patched doors/ice/spinners retain their exact source artwork and collision.
			patch_plane(p,patch.image)
			continue
		if merged.has(i) or exhibit_cells.has(i): continue
		if i in ladders:
			kit.ladder(p)
			continue
		if i in stairs:
			var start_x=x; var end_x=x
			while start_x>0 and z*width+start_x-1 in stairs: start_x-=1
			while end_x<width-1 and z*width+end_x+1 in stairs: end_x+=1
			kit.stair_tile(p,x-start_x,end_x-start_x+1,not i+width in stairs,not i-width in stairs)
			terrain.set_meta("stair_count",int(terrain.get_meta("stair_count",0))+1)
			continue
		match kind:
			"waterfall":
				kit.stamp("box",p+Vector3(0,.7,-.3),Vector3(1.01,1.4,.13),"waterfall")
				kit.stamp("ball",p+Vector3(0,.07,.1),Vector3(1,.12,.65),"b2dcd6")
			"water":
				kit.stamp("contact_plane",p+Vector3(0,.025,0),Vector3(1.01,1,1.01),"489eaf")
				for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next=Vector2i(x,z)+direction
					if next.x<0 or next.y<0 or next.x>=width or next.y>=height: continue
					if meta.tiles[next.y*width+next.x] in ["water","waterfall"]: continue
					kit.shore(p,direction)
			"tree":
				pass
			"shrub": kit.tree(p,x+z,true)
			"grass":
				for j in range(2):
					var angle=j*2.39996+float((x*17+z*31)%11)*.12
					var offset=Vector3(cos(angle)*.27,0,sin(angle)*.27) if j>0 else Vector3.ZERO
					kit.stamp("blade_tuft",p+offset,Vector3(.92,.82+float((x+z+j)%3)*.035,.92),["grass_5b9631","grass_76ac37","grass_81b640"][posmod(x+z+j,3)],angle)
			"flowers":
				for j in range(4):
					var offset=Vector3((j%2-.5)*.4,.16,(int(j/2)-.5)*.4)
					kit.flower(p+offset-Vector3(0,.16,0),"e58caa" if (x+z)%2==0 else "eae4c9")
			"path": pass
			"floor":
				pass # Original floor/rug/stair pattern is baked into the ground.
			"sand": pass
			"cliff":
				# Contiguous layered rock faces, with recessed joints and turf caps.
				var rock_colors=["cliff_outdoor","cliff_outdoor","cliff_outdoor"] if not cave else ["stone","stone","stone"]
				kit.stamp("box",p+Vector3(0,.59,0),Vector3(1.0,1.18,1.0),rock_colors[0])
				for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next=Vector2i(x,z)+direction
					if next.x<0 or next.y<0 or next.x>=width or next.y>=height: continue
					if meta.tiles[next.y*width+next.x]=="cliff": continue
					kit.stamp_pose("cliff_face",Transform3D(Basis(Vector3.UP,atan2(direction.x,direction.y))*Basis.from_scale(Vector3(1.,1.18,1.)),p),rock_colors[1])
				kit.stamp("box",p+Vector3(0,1.2,0),Vector3(1.0,.14,1.0),"turf" if not cave else "stone")
				if cave:
					kit.stamp("rock_surface",p+Vector3(0,1.27,0),Vector3.ONE,"cave_cap")
			"stairs":
				for step in range(5):
					kit.stamp("box",p+Vector3(0,.03+(4-step)*.045,-.4+step*.2),Vector3(1,.06+(4-step)*.09,.21),"b6bfc0")
					kit.stamp("box",p+Vector3(0,.065+(4-step)*.09,-.31+step*.2),Vector3(1,.015,.025),"909a98")
				for side in [-1,1]:
					var neighbor=x+side
					if neighbor>=0 and neighbor<width and meta.tiles[z*width+neighbor]=="stairs": continue
					for step in range(5): kit.stamp("softbox",p+Vector3(side*.46,.23+(4-step)*.045,-.4+step*.2),Vector3(.12,.13,.24),"c7965e")
			"ledge":
				var behavior=int(w.events.catalog[loaded].behavior[i])
				var axis=Vector3(.32,.22,1) if behavior in [0x38,0x39] else Vector3(1,.22,.32)
				kit.stamp("box",p+Vector3(0,.1,0),axis,"997044")
				kit.stamp("box",p+Vector3(0,.22,0),axis*Vector3(1.01,.15,1.01),"turf")
			"fence":
				var connections=[]
				for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next=Vector2i(x,z)+direction
					if next.x<0 or next.y<0 or next.x>=width or next.y>=height: continue
					if meta.tiles[next.y*width+next.x]!="fence": continue
					connections.append(direction)
				kit.fence(p,connections)
			"sign": kit.sign(p)
			"wall":
				var wall_height=.28 if z>height*.65 else 1.5
				kit.stamp("box",p+Vector3(0,wall_height*.5,0),Vector3(1.01,wall_height,1),"wallpaper" if home else "plaster_c3cec5")
				if home and wall_height>1.:
					kit.stamp("box",p+Vector3(0,.16,.51),Vector3(1.01,.3,.06),"wood_987957")
					kit.stamp("box",p+Vector3(0,1.47,.51),Vector3(1.01,.09,.07),"wood_c5af86")
					if tile in [0x29,0x2a]: kit.home_window(p+Vector3(0,.85,.53))
			"furniture", "cabinet", "plant", "computer", "table", "bed", "chair":
				if home and tile==0x35: kit.furnishing(p,"television",x+z,loaded)
				elif home and tile in [0x31,0x32,0x36,0x37]: kit.furnishing(p,"kitchen",tile,loaded)
				else: kit.furnishing(p,kind,x+z,loaded)
			"void": kit.stamp("box",p+Vector3(0,-.01,0),Vector3(1,.03,1),"404e4e")
	# Source floor art on important pads preserves visual puzzle clues.
	var image: Image
	for i in room.cells.size():
		var behavior=int(w.events.catalog[loaded].behavior[i])
		if behavior in [0x20,0x23,0x26,0x27,0x66,0x67,0x68] or (behavior>=0x40 and behavior<=0x58):
			if image==null: image=Image.load_from_file(room.image)
			var x=i%width; var z=int(i/width)
			var crop=image.get_region(Rect2i(x*16,z*16,16,16))
			floor_art(Vector3(x+.5,.035,z+.5),ImageTexture.create_from_image(crop))
	for b in meta.buildings:
		var rect=Rect2(float(b[0]),float(b[1]),float(b[2]),float(b[3]))
		var doors=room.warps.filter(func(d):return rect.grow(.5).has_point(Vector2(d.x,d.y)))
		kit.building(rect,str(b[4]),str(b[5]),doors)
	for tree in meta.get("trees",[]): kit.tree(Vector3(float(tree[0]),0,float(tree[1])),int(tree[0])+int(tree[1]),bool(tree[2]))
	kit.flush(terrain)
	# Entrances use a clear doorstep marker, matching the original warp tile exactly.
	for door in room.warps:
		if not outside:
			if room.warps.any(func(other):return other.y==door.y and other.x==door.x-1 and other.dest_map==door.dest_map): continue
			var span=1
			while room.warps.any(func(other):return other.y==door.y and other.x==door.x+span and other.dest_map==door.dest_map): span+=1
			var p=Vector3(float(door.x)+span*.5,.045,float(door.y)+.5)
			if not int(door.y)*width+int(door.x) in stairs+ladders and not cave: kit.doorway(p,home,span)
			kit.stamp("box",p,Vector3(.85,.04,.75),"b58d73")
			for step in range(3): kit.stamp("box",p+Vector3(0,.035,step*.19-.2),Vector3(.64,.025,.045),"f0d8ac")
	kit.flush(terrain)

func floor_art(at: Vector3, texture: Texture2D):
	var plane=MeshInstance3D.new(); var mesh=PlaneMesh.new(); mesh.size=Vector2.ONE
	var mat=StandardMaterial3D.new(); mat.albedo_texture=texture; mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; mat.roughness=.9
	plane.mesh=mesh; plane.material_override=mat; plane.position=at; terrain.add_child(plane)

func patch_plane(at: Vector3, path: String):
	floor_art(at+Vector3(0,.04,0),ImageTexture.create_from_image(Image.load_from_file(path)))

func ensure_actor(key: String, pos: Vector2, identity: String, look: Vector2, walking: bool=false, player: bool=false):
	var config=a.avatar.config() if player else {"shirt":["739db5","b88284","8caa79","c7aa6d"][posmod(identity.hash(),4)],"pants":"596b7b","hair":"71513c"}
	var signature=JSON.stringify(config)+identity
	if actors.has(key) and actors[key].get_meta("appearance","")!=signature:
		actors[key].free(); actors.erase(key)
	if not actors.has(key):
		var node=kit.trainer(config,identity); node.set_meta("appearance",signature); people.add_child(node); actors[key]=node
	move_actor(actors[key],pos,look,walking)

func move_actor(node: Node3D, pos: Vector2, look: Vector2, walking: bool):
	var now=age
	var dt=clampf(now-float(node.get_meta("stride_time",now)),0,.15)
	var previous: Vector2=node.get_meta("stride_position",pos)
	var distance=previous.distance_to(pos)/w.TILE
	var phase=float(node.get_meta("stride_phase",0.0))
	if distance<1.5: phase=fmod(phase+distance*TAU/2.4,TAU)
	var blend=move_toward(float(node.get_meta("stride_blend",0.0)),1.0 if walking or distance>0.002 and distance<1.5 else 0.0,dt*12)
	node.set_meta("stride_phase",phase); node.set_meta("stride_blend",blend)
	node.set_meta("stride_position",pos); node.set_meta("stride_time",now)
	node.position=Vector3(pos.x/w.TILE,0,pos.y/w.TILE)
	if look!=Vector2.ZERO:
		var target=atan2(look.x,look.y)
		node.rotation.y=lerp_angle(node.rotation.y,target,1.0-exp(-dt*24)) if node.has_meta("facing_ready") else target
		node.set_meta("facing_ready",true)
	character_pose.pose(node,phase,blend)

func sync_actors():
	var alive={"player":true}; labels.clear()
	ensure_actor("player",a.position_world,"player",w.heading,w.stepping or (w.scenes.active and not w.scenes.sequence.is_empty() and w.scenes.sequence[w.scenes.index].has("player_from")),true)
	for npc in w.actors():
		var identity=str(npc.get("graphics_id","")); var key=str(npc.get("script",identity))+str(npc.get("local_id",""))
		if identity.contains("METEORITE"):
			key+="_"+str(a.postgame.state().triangle); alive[key]=true
			if not actors.has(key):
				var node=Node3D.new(); people.add_child(node); actors[key]=node
				var color=Color("515b72").lerp(Color("ed4338"),float(a.postgame.state().triangle)/10)
				kit.shape(node,"canopy",Vector3(0,.32,0),Vector3(.65,.65,.65),color.to_html(false))
			actors[key].position=Vector3(npc.pos.x/w.TILE,0,npc.pos.y/w.TILE)
			continue
		if identity.contains("LUGIA") or identity.contains("HO_OH"):
			alive[key]=true
			if not actors.has(key):
				var node=Sprite3D.new(); node.texture=a.c.portraits[249 if identity.contains("LUGIA") else 250]; node.pixel_size=.035; node.billboard=BaseMaterial3D.BILLBOARD_ENABLED; people.add_child(node); actors[key]=node
			actors[key].position=Vector3(npc.pos.x/w.TILE,1,npc.pos.y/w.TILE)
			continue
		alive[key]=true
		if identity.contains("POKEDEX") or identity.contains("FOSSIL") or identity.contains("OLD_AMBER") or identity.contains("ITEM_BALL") or identity.contains("SNORLAX") or identity.contains("ARTICUNO") or identity.contains("ZAPDOS") or identity.contains("MOLTRES") or identity.contains("MEWTWO"):
			if not actors.has(key):
				var node=Node3D.new(); people.add_child(node); actors[key]=node
				var species=143 if identity.contains("SNORLAX") else 144 if identity.contains("ARTICUNO") else 145 if identity.contains("ZAPDOS") else 146 if identity.contains("MOLTRES") else 150 if identity.contains("MEWTWO") else 0
				if species>0:
					var sprite=Sprite3D.new(); sprite.texture=a.c.portraits[species]; sprite.pixel_size=.025; sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED; sprite.position.y=.7; node.add_child(sprite)
				elif identity.contains("POKEDEX"):
					kit.shape(node,"softbox",Vector3(0,.92,0),Vector3(.48,.12,.65),"cc5866")
					kit.shape(node,"softbox",Vector3(0,.99,-.1),Vector3(.36,.025,.32),"344752")
					kit.shape(node,"softbox",Vector3(0,1.006,-.1),Vector3(.28,.015,.24),"8ac3c1")
					kit.shape(node,"ball",Vector3(-.13,1,.21),Vector3(.08,.035,.08),"e8dfa1")
					kit.shape(node,"box",Vector3(.11,1,.2),Vector3(.12,.015,.03),"344752")
					kit.shape(node,"box",Vector3(.11,1,.2),Vector3(.03,.015,.12),"344752")
				elif identity.contains("ITEM_BALL"):
					kit.pokeball(Vector3(0,.22,0)); kit.flush(node)
				else:
					kit.shape(node,"rock",Vector3(0,.19,0),Vector3(.55,.32,.48),"c4a173" if not identity.contains("AMBER") else "d79947")
					for mark in 14:
						var t=float(mark)/13; var angle=t*TAU*1.5
						kit.shape(node,"ball",Vector3(cos(angle)*t*.18,.365,sin(angle)*t*.15),Vector3(.055,.025,.055),"846546")
			actors[key].position=Vector3(npc.pos.x/w.TILE,0,npc.pos.y/w.TILE)
		else:
			ensure_actor(key,npc.pos,identity,w.scenes.trainer_direction(npc),w.scenes.active and str(w.scenes.actor.get("key",""))==str(npc.get("script","")) and w.scenes.actor.get("walking",false))
		if w.can_talk(npc.pos): labels.append([npc.pos,a.c.controls.text("interact")+" / TALK"])
	for npc in w.quest_actors():
		var key="quest:"+str(npc[2]); alive[key]=true
		var identity=str(npc[2])
		if npc.size()>3:
			for original in w.room().objects:
				if original.get("local_id","")==npc[3]: identity=str(original.graphics_id); break
		ensure_actor(key,npc[0],identity,Vector2.DOWN)
		if w.can_talk(npc[0]): labels.append([npc[0],a.c.controls.text("interact")+" / "+str(npc[1])])
	if w.scenes.active and w.scenes.actor.get("key","")=="scene_blue":
		alive.scene_blue=true; ensure_actor("scene_blue",w.scenes.positions.scene_blue,"blue",w.scenes.actor.get("look",Vector2.RIGHT),w.scenes.actor.get("walking",false))
	if w.scenes.active and w.scenes.actor.get("key","")=="scene_oak":
		alive.scene_oak=true; ensure_actor("scene_oak",w.scenes.positions.scene_oak,"prof_oak",Vector2.DOWN,w.scenes.actor.get("walking",false))
	for key in actors.keys():
		if not alive.has(key): actors[key].free(); actors.erase(key)

func sync_props():
	var signature=loaded+JSON.stringify(w.events.state())
	if signature==props_key: return
	props_key=signature
	for node in props.get_children(): node.free()
	for o in w.room().objects:
		var p=Vector3(float(o.x)+.5,0,float(o.y)+.5)
		if "CUT_TREE" in str(o.graphics_id) and not w.events.done(loaded+"tree"+str(o.x)+":"+str(o.y)): kit.cut_tree(p)
		if "ROCK_SMASH_ROCK" in str(o.graphics_id) and not w.events.done(a.field.smash_key(o)):
			kit.stamp("rock",p+Vector3(0,.24,0),Vector3(.72,.48,.65),"stone",float(o.x+o.y))
	for rock in w.events.rocks(): kit.stamp("rock",Vector3(float(rock.x)+.5,.38,float(rock.y)+.5),Vector3(.87,.76,.84),"stone",float(rock.x+rock.y))
	if "POKEMON_CENTER_1F" in loaded:
		for npc in w.room().objects:
			if not "NURSE" in str(npc.graphics_id): continue
			var at=Vector3(float(npc.x)+.5,0,float(npc.y)-.5)
			var cell=Vector2i(floori(at.x),floori(at.z))
			if cell.y<0 or not (int(w.room().cells[cell.y*int(w.room().width)+cell.x])&0xc00): continue
			kit.stamp("softbox",at+Vector3(0,.55,0),Vector3(1.35,1.1,.85),"e3d9ca")
			kit.stamp("softbox",at+Vector3(0,1.13,0),Vector3(1.25,.13,.78),"779da6")
			for slot in 6: kit.pokeball(at+Vector3(-.35+(slot%3)*.35,1.26,-.18+int(slot/3)*.36),.22)
			kit.stamp("softbox",at+Vector3(0,.82,.445),Vector3(.55,.2,.035),"81c7bf")
	for item in w.events.catalog[loaded].items:
		if w.events.done(loaded+"item"+str(item.id)): continue
		var p=Vector3(float(item.x)+.5,.2,float(item.y)+.5)
		kit.pokeball(p,.42)
	kit.flush(props)

func screen_point(point: Vector2, elevation: float=0) -> Vector2:
	if camera==null: return point-a.camera+Vector2(0,90)
	return camera.unproject_position(Vector3(point.x/w.TILE,elevation,point.y/w.TILE))+Vector2(0,90)

func ground_point(point: Vector2) -> Vector2:
	if camera==null: return point-Vector2(0,90)+a.camera
	var local=point-Vector2(0,90); var origin=camera.project_ray_origin(local); var ray=camera.project_ray_normal(local)
	var hit=origin+ray*(-origin.y/ray.y)
	return Vector2(hit.x,hit.z)*w.TILE

func draw():
	if viewport==null: return
	a.draw_texture_rect(viewport.get_texture(),Rect2(0,90,1280,700),false)
	for label in labels:
		var p=screen_point(label[0],2.05)
		if Rect2(10,115,1260,630).has_point(p):
			var text=str(label[1]); var width=a.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
			a.draw_style_box(bubble(),Rect2(p-Vector2(width*.5+10,23),Vector2(width+20,31)))
			a.words(text,p-Vector2(width*.5,1),15,Color("fff4d8"))
	if a.c.click_move:
		var p=screen_point(a.c.click_destination,.05); a.draw_arc(p,10,0,TAU,24,Color("fff0bd"),2,true)

func bubble() -> StyleBoxFlat:
	var style=StyleBoxFlat.new(); style.bg_color=Color(.08,.18,.19,.9)
	style.set_corner_radius_all(8)
	return style

func set_enabled(value: bool):
	enabled=value
	if OS.get_cmdline_user_args().is_empty():
		var settings=ConfigFile.new(); settings.set_value("graphics","modern",enabled); settings.save("user://world-graphics.cfg")
	a.queue_redraw()
