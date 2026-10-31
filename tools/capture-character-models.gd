extends SceneTree
var kit=preload("res://kanto_model_kit.gd").new()
func _initialize(): run.call_deferred()
func run():
	root.size=Vector2i(1280,800)
	var stage=Node3D.new(); root.add_child(stage)
	var env=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("d4e4e5"); env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color("dce8f0"); env.environment.ambient_light_energy=.32; stage.add_child(env)
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-55,-30,0); sun.light_energy=.45; sun.shadow_enabled=true; stage.add_child(sun)
	var camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=8; camera.position=Vector3(3,9,15); stage.add_child(camera); camera.look_at(Vector3(3,1,2.25)); camera.current=true
	kit.shape(stage,"box",Vector3(3,-.1,1.5),Vector3(11,.15,9),"b7cdcc")
	var gallery=Node3D.new(); stage.add_child(gallery)
	var identities=["player","player","prof_oak","nurse","blue","brock","misty","rocket_m"]
	var names=["PLAYER / BOY","PLAYER / GIRL","PROF. OAK","NURSE JOY","BLUE","BROCK","MISTY","TEAM ROCKET"]
	for i in identities.size():
		var config={"gender":"girl" if i==1 else "boy","shirt":"537eb1" if i==1 else "d45e65","pants":"566b8a","hair":"5e4036","shoes":"ad655a"}
		if i>1: config.erase("shoes")
		var model=kit.trainer(config,identities[i]); gallery.add_child(model); model.position=Vector3((i%4)*2,0,int(i/4)*4.5)
		for limb in ["Head","LeftArm","RightArm","LeftLeg","RightLeg"]: assert(model.has_node(limb),"Rig missing "+limb)
		label(gallery,names[i],model.position+Vector3(0,2.15,0))
	await capture("characters-showcase")
	gallery.free(); gallery=Node3D.new(); stage.add_child(gallery)
	for i in 7:
		var pos=Vector3((i%4)*2,0,int(i/4)*4.5)
		var kind=["computer","cabinet","chair","plant","bed","table","pokeball"][i]
		if kind=="pokeball": kit.pokeball(pos+Vector3(0,.3,0),.6)
		else: kit.furnishing(pos,kind,i,"HOUSE")
		label(gallery,kind.to_upper(),pos+Vector3(0,0,.9))
	kit.sign(Vector3(6,0,4.5)); label(gallery,"SIGN",Vector3(6,0,5.4)); kit.flush(gallery)
	await capture("objects-showcase")
	print("CHARACTER AND OBJECT PREVIEW: PASS"); quit()
func label(parent, title, at):
	var text=Label3D.new(); text.text=title; text.font_size=42; text.pixel_size=.003; text.modulate=Color("304d58"); text.outline_size=0; text.billboard=BaseMaterial3D.BILLBOARD_ENABLED; text.position=at+Vector3(0,.18,0); text.no_depth_test=true; parent.add_child(text)
func capture(title):
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/"+title+".png")
