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
	viewport.msaa_3d=Viewport.MSAA_2X
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(viewport)
	stage=Node3D.new(); viewport.add_child(stage)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=16; camera.far=180; camera.current=true; stage.add_child(camera)
	var world_environment=WorldEnvironment.new(); var env=Environment.new()
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("a7c6bd")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("d5e9e9"); env.ambient_light_energy=.32
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	world_environment.environment=env; environment=env; stage.add_child(world_environment)
	sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-58,-32,0); sun.light_color=Color("fff1d3"); sun.light_energy=.75
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
	var target=Vector3(a.position_world.x/w.TILE,0,a.position_world.y/w.TILE)
	focus=focus.lerp(target,1.0-exp(-dt*9.0))
	camera.position=focus+Vector3(0,24,18)
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
	if terrain: terrain.free()
	terrain=Node3D.new(); stage.add_child(terrain)
	for node in people.get_children(): node.free()
	actors.clear(); loaded=w.current; props_key=""; labels.clear()
	var room=w.room(); var meta=catalog[loaded]; var width=int(room.width); var height=int(room.height)
	var outside=bool(meta.outdoor); var cave=bool(meta.cave)
	sun.light_energy=.64 if outside else .42
	environment.ambient_light_energy=.32 if outside else .42
	environment.background_color=Color("a2bca3") if outside else Color("37474b")
	var base="6e9867" if outside else "6f7569" if cave else "a9a18e"
	kit.stamp("box",Vector3(width*.5,-.24,height*.5),Vector3(width+.2,.42,height+.2),base)
	# A low landscape apron hides empty space along map borders, without collisions.
	if outside: kit.stamp("box",Vector3(width*.5,-.48,height*.5),Vector3(width+40,.25,height+40),"739a6d")
	var ground_image=Image.load_from_file(meta.ground); ground_image.generate_mipmaps()
	var ground=MeshInstance3D.new(); var plane=PlaneMesh.new(); plane.size=Vector2(width,height)
	var surface=StandardMaterial3D.new(); surface.albedo_texture=ImageTexture.create_from_image(ground_image); surface.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; surface.roughness=1
	ground.mesh=plane; ground.material_override=surface; ground.position=Vector3(width*.5,.005,height*.5); terrain.add_child(ground)
	camera.size=16.0 if outside or cave else clampf(height*.8,11,16)
	for i in room.cells.size():
		var x=i%width; var z=int(i/width); var p=Vector3(x+.5,0,z+.5); var kind=str(meta.tiles[i]); var tile=int(room.cells[i])&1023
		var patch=w.events.patches.get(Vector2i(x,z),{})
		if not patch.is_empty():
			# Patched doors/ice/spinners retain their exact source artwork and collision.
			patch_plane(p,patch.image)
			continue
		match kind:
			"waterfall":
				kit.stamp("box",p+Vector3(0,.7,-.3),Vector3(1.01,1.4,.13),"489eaf")
				kit.stamp("ball",p+Vector3(0,.07,.1),Vector3(1,.12,.65),"b2dcd6")
			"water":
				kit.stamp("box",p+Vector3(0,-.025,0),Vector3(1.01,.07,1.01),"489eaf")
				if (x+z)%3==0:
					kit.stamp("ball",p+Vector3(.1,.025,-.1),Vector3(.42,.012,.035),"8eced1")
			"tree":
				pass
			"shrub": kit.tree(p,x+z,true)
			"grass":
				for j in range(4):
					var offset=Vector3((j%2-.5)*.44,.12,(int(j/2)-.5)*.44)
					kit.stamp("grass",p+offset-Vector3(0,.12,0),Vector3(.6,.35,.6),"8eb76a" if j%2==0 else "578e55",float(x+z+j))
			"flowers":
				for j in range(4):
					var offset=Vector3((j%2-.5)*.4,.16,(int(j/2)-.5)*.4)
					kit.stamp("ball",p+offset,Vector3(.28,.24,.28),"dd7e86" if (x+z)%2==0 else "e9c77e")
			"path": pass
			"floor":
				pass # Original floor/rug/stair pattern is baked into the ground.
			"sand": pass
			"cliff":
				kit.stamp("box",p+Vector3(0,.48,0),Vector3(1.0,.96,1.0),"828574" if cave else "a79c7e")
				var edge=x==0 or z==0 or x==width-1 or z==height-1
				if not edge: edge=meta.tiles[i-1]!="cliff" or meta.tiles[i+1]!="cliff" or meta.tiles[i-width]!="cliff" or meta.tiles[i+width]!="cliff"
				if edge: kit.stamp("rock",p+Vector3(0,.73,0),Vector3(1.06,.85,1.04),"969882" if cave else "b6a887",(x+z)*.3)
				elif (x+z)%5==0: kit.stamp("rock",p+Vector3(0,.99,0),Vector3(.4,.22,.35),"999b82")
			"ledge":
				var behavior=int(w.events.catalog[loaded].behavior[i])
				var axis=Vector3(.16,.2,1) if behavior in [0x38,0x39] else Vector3(1,.2,.16)
				kit.stamp("box",p+Vector3(0,.1,0),axis,"9d926c")
			"fence":
				kit.stamp("box",p+Vector3(0,.37,0),Vector3(.13,.74,.15),"eee6ce")
				for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next=Vector2i(x,z)+direction
					if next.x<0 or next.y<0 or next.x>=width or next.y>=height: continue
					if meta.tiles[next.y*width+next.x]!="fence": continue
					for y in [.27,.56]: kit.stamp("box",p+Vector3(direction.x*.25,y,direction.y*.25),Vector3(.55,.1,.1) if direction.x!=0 else Vector3(.1,.1,.55),"d7d8bd")
			"sign":
				kit.stamp("box",p+Vector3(0,.35,0),Vector3(.12,.7,.12),"876950")
				kit.stamp("box",p+Vector3(0,.77,0),Vector3(.7,.44,.14),"f0dfb6")
				for y in [.69,.8]: kit.stamp("box",p+Vector3(0,y,.08),Vector3(.43,.035,.02),"9a9982")
			"wall": kit.stamp("box",p+Vector3(0,.65,0),Vector3(1,1.3,1),"babaa9")
			"furniture", "cabinet", "plant", "computer", "table", "bed", "chair": kit.furnishing(p,kind,x+z,loaded)
			"void": kit.stamp("box",p+Vector3(0,-.01,0),Vector3(1,.03,1),"404e4e")
	# Source floor art on important pads preserves visual puzzle clues.
	var image: Image
	for i in room.cells.size():
		var behavior=int(w.events.catalog[loaded].behavior[i])
		if behavior in [0x20,0x23,0x26,0x27] or (behavior>=0x40 and behavior<=0x58) or (behavior>=0x60 and behavior<=0x6f):
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
			var p=Vector3(float(door.x)+.5,.045,float(door.y)+.5)
			kit.stamp("box",p,Vector3(.85,.04,.75),"b58d73")
			for step in range(3): kit.stamp("box",p+Vector3(0,.035,step*.19-.2),Vector3(.64,.025,.045),"f0d8ac")
	kit.flush(terrain)
	focus=Vector3(a.position_world.x/w.TILE,0,a.position_world.y/w.TILE)
	sync_actors(); sync_props()
	map_build_ms=Time.get_ticks_msec()-started

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
	node.position=Vector3(pos.x/w.TILE,0,pos.y/w.TILE)
	if look!=Vector2.ZERO: node.rotation.y=atan2(look.x,look.y)
	var swing=sin(age*13)*.5 if walking else 0.0
	node.get_node("LeftLeg").rotation.x=swing; node.get_node("RightLeg").rotation.x=-swing
	node.get_node("LeftArm").rotation.x=-swing*.8; node.get_node("RightArm").rotation.x=swing*.8
	if walking: node.position.y=absf(sin(age*13))*.045

func sync_actors():
	var alive={"player":true}; labels.clear()
	ensure_actor("player",a.position_world,"player",w.heading,w.stepping,true)
	for npc in w.actors():
		var identity=str(npc.get("graphics_id","")); var key=str(npc.get("script",identity))+str(npc.get("local_id",""))
		alive[key]=true
		if identity.contains("POKEDEX") or identity.contains("FOSSIL") or identity.contains("OLD_AMBER") or identity.contains("ITEM_BALL") or identity.contains("SNORLAX") or identity.contains("ARTICUNO") or identity.contains("ZAPDOS") or identity.contains("MOLTRES") or identity.contains("MEWTWO"):
			if not actors.has(key):
				var node=Node3D.new(); people.add_child(node); actors[key]=node
				var species=143 if identity.contains("SNORLAX") else 144 if identity.contains("ARTICUNO") else 145 if identity.contains("ZAPDOS") else 146 if identity.contains("MOLTRES") else 150 if identity.contains("MEWTWO") else 0
				if species>0:
					var sprite=Sprite3D.new(); sprite.texture=a.c.portraits[species]; sprite.pixel_size=.025; sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED; sprite.position.y=.7; node.add_child(sprite)
				elif identity.contains("POKEDEX"):
					kit.shape(node,"box",Vector3(0,.92,0),Vector3(.48,.12,.65),"cc5866")
					kit.shape(node,"box",Vector3(0,.99,-.1),Vector3(.32,.025,.28),"8ac3c1")
					kit.shape(node,"ball",Vector3(-.13,1,.21),Vector3(.08,.035,.08),"e8dfa1")
				else: kit.shape(node,"ball",Vector3(0,.22,0),Vector3(.4,.4,.4),"d4bb85")
			actors[key].position=Vector3(npc.pos.x/w.TILE,0,npc.pos.y/w.TILE)
		else:
			ensure_actor(key,npc.pos,identity,w.scenes.trainer_direction(npc),w.scenes.active and str(w.scenes.actor.get("key",""))==str(npc.get("script","")) and w.scenes.actor.get("walking",false))
		if w.can_talk(npc.pos): labels.append([npc.pos,a.c.controls.text("interact")+" / TALK"])
	for npc in w.quest_actors():
		var key="quest:"+str(npc[2]); alive[key]=true
		ensure_actor(key,npc[0],str(npc[2]),Vector2.DOWN)
		if w.can_talk(npc[0]): labels.append([npc[0],a.c.controls.text("interact")+" / "+str(npc[1])])
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
		if "CUT_TREE" in str(o.graphics_id) and not w.events.done(loaded+"tree"+str(o.x)+":"+str(o.y)): kit.tree(p,0,true)
		if "ROCK_SMASH_ROCK" in str(o.graphics_id) and not w.events.done(a.field.smash_key(o)):
			kit.stamp("ball",p+Vector3(0,.3,0),Vector3(.7,.6,.65),"b5a389")
	for rock in w.events.rocks(): kit.stamp("ball",Vector3(float(rock.x)+.5,.4,float(rock.y)+.5),Vector3(.88,.8,.85),"a0a697")
	for item in w.events.catalog[loaded].items:
		if w.events.done(loaded+"item"+str(item.id)): continue
		var p=Vector3(float(item.x)+.5,.2,float(item.y)+.5)
		kit.stamp("ball",p,Vector3.ONE*.35,"f0e9d6")
		kit.stamp("ball",p+Vector3(0,.09,0),Vector3(.35,.19,.35),"d95f62")
		kit.stamp("box",p+Vector3(0,0,.16),Vector3(.32,.045,.03),"4e6062")
		kit.stamp("ball",p+Vector3(0,0,.19),Vector3.ONE*.09,"fff4dd")
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
