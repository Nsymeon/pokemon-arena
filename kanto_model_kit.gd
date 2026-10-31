extends RefCounted
# Shared meshes and MultiMesh batches keep forests independent of tree count.
var materials={}
var meshes={}
var batches={}

func material(hex: String) -> Material:
	if materials.has(hex): return materials[hex]
	if hex=="pokeball":
		var shader=Shader.new()
		shader.code="""shader_type spatial;
varying float height;
void vertex() { height=VERTEX.y; }
void fragment() {
 ALBEDO=vec3(.08,.11,.14);
 if (height>.025) { ALBEDO=vec3(.74,.055,.085); }
 else if (height<-.025) { ALBEDO=vec3(.91,.93,.91); }
 ROUGHNESS=.28; SPECULAR=.55;
}
"""
		var paint=ShaderMaterial.new(); paint.shader=shader; materials[hex]=paint; return paint
	if hex.begins_with("grass_"):
		var shader=Shader.new()
		shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color;
varying float blade_height;
void vertex() {
 blade_height=VERTEX.y;
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 VERTEX.x+=sin(TIME*1.65+p.x*1.7+p.z*.8)*.045*blade_height*blade_height;
 VERTEX.z+=cos(TIME*1.2+p.z*1.4)*.025*blade_height;
}
void fragment() {
 ALBEDO=tint.rgb*mix(.68,1.18,clamp(blade_height,0.,1.));
 ROUGHNESS=.86;
 BACKLIGHT=tint.rgb*.22;
}
"""
		var foliage=ShaderMaterial.new(); foliage.shader=shader
		foliage.set_shader_parameter("tint",Color(hex.trim_prefix("grass_")))
		materials[hex]=foliage; return foliage
	if hex=="489eaf":
		var shader=Shader.new()
		shader.code="""shader_type spatial;
varying vec3 world_pos;
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_pos.xz;
 float wave=sin(p.x*3.4+TIME*.7+sin(p.y*2.1-TIME*.4));
 float cross_wave=sin(p.y*4.7-TIME*.8+cos(p.x*2.6+TIME*.35));
 float light=smoothstep(.72,.99,wave*cross_wave);
 ALBEDO=mix(vec3(.10,.39,.61),vec3(.28,.65,.78),.45+.1*wave);
 ALBEDO+=vec3(.18,.25,.23)*light;
 ROUGHNESS=.3; SPECULAR=.45;
 NORMAL=normalize(NORMAL+vec3(wave*.07,0.,cross_wave*.07));
}
"""
		var water=ShaderMaterial.new(); water.shader=shader; materials[hex]=water; return water
	var m=StandardMaterial3D.new()
	m.albedo_color=Color(hex); m.roughness=0.82
	materials[hex]=m
	return m

func mesh(kind: String) -> Mesh:
	if meshes.has(kind): return meshes[kind]
	var m: Mesh
	match kind:
		"softbox":
			var box=BoxMesh.new(); box.size=Vector3.ONE; box.subdivide_width=6; box.subdivide_height=6; box.subdivide_depth=6
			var arrays=box.surface_get_arrays(0); var vertices=arrays[Mesh.ARRAY_VERTEX]; var normals=arrays[Mesh.ARRAY_NORMAL]
			for i in vertices.size():
				var v=vertices[i]; var center=Vector3(clampf(v.x,-.40,.40),clampf(v.y,-.40,.40),clampf(v.z,-.40,.40))
				normals[i]=(v-center).normalized(); vertices[i]=center+normals[i]*.10
			arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
			var rounded=ArrayMesh.new(); rounded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); m=rounded
		"ball":
			var sphere=SphereMesh.new(); sphere.radius=0.5; sphere.height=1.0; sphere.radial_segments=20; sphere.rings=10; m=sphere
		"cylinder":
			var cylinder=CylinderMesh.new(); cylinder.top_radius=0.5; cylinder.bottom_radius=0.5; cylinder.height=1; cylinder.radial_segments=12; m=cylinder
		"rock":
			m=profile_mesh([Vector2(.34,-.5),Vector2(.5,-.28),Vector2(.46,.2),Vector2(.28,.48),Vector2(0,.53)],10,true)
		"torso":
			m=profile_mesh([Vector2(.34,-.5),Vector2(.44,-.43),Vector2(.49,.2),Vector2(.36,.45),Vector2(0,.5)],24,false)
		"haircap":
			m=profile_mesh([Vector2(.5,0),Vector2(.48,.16),Vector2(.39,.32),Vector2(.24,.44),Vector2(0,.5)],32,false)
		"pot":
			m=profile_mesh([Vector2(.32,-.5),Vector2(.36,-.45),Vector2(.5,.43),Vector2(.5,.5)],24,false)
		"ring":
			var ring=TorusMesh.new(); ring.inner_radius=.4; ring.outer_radius=.5; ring.rings=24; ring.ring_segments=8; m=ring
		"canopy":
			m=profile_mesh([Vector2(.12,0),Vector2(.48,.1),Vector2(.5,.2),Vector2(.41,.36),Vector2(.32,.58),Vector2(.16,.82),Vector2(0,1)],20,false)
		"roof":
			var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var points=[Vector3(-.5,0,-.5),Vector3(.5,0,-.5),Vector3(.5,0,.5),Vector3(-.5,0,.5),Vector3(-.5,.5,0),Vector3(.5,.5,0)]
			for index in [0,1,5,0,5,4,4,5,2,4,2,3,0,4,3,1,2,5,0,3,2,0,2,1]: st.add_vertex(points[index])
			st.generate_normals(); m=st.commit()
		"grass":
			var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			# Curved, broad blades rather than crossed triangular spikes.
			for blade in range(5):
				var rotate=Basis(Vector3.UP,blade*2.39996)
				var h=.68+float(blade%3)*.14
				for segment in 8:
					var points=[]; var normals=[]
					for pair in [[segment,-1],[segment,1],[segment+1,-1],[segment+1,1]]:
						var t=float(pair[0])/8.0
						var width=.16*pow(sin(t*PI),.7)+.008*(1-t)
						points.append(rotate*Vector3(pair[1]*width,h*t,.04+.4*t*t))
						normals.append((rotate*Vector3(0,.3+t*.5,.9-t*.4)).normalized())
					for index in [0,2,1,1,2,3]:
						st.set_normal(normals[index]); st.add_vertex(points[index])
			m=st.commit()
		_:
			m=BoxMesh.new(); m.size=Vector3.ONE
	meshes[kind]=m
	return m

func profile_mesh(profile: Array, sides: int, irregular: bool) -> Mesh:
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size()-1):
		for side in sides:
			var points=[]
			for pair in [[ring,side],[ring+1,side],[ring,side+1],[ring+1,side+1]]:
				var angle=float(pair[1])*TAU/sides
				var radius=profile[pair[0]].x*(1.0+.08*sin(angle*3+.7) if irregular else 1.0)
				points.append(Vector3(cos(angle)*radius,profile[pair[0]].y,sin(angle)*radius))
			for index in ([0,2,1] if profile[ring+1].x==0 else [0,2,1,1,2,3]): st.add_vertex(points[index])
	st.generate_normals(); return st.commit()

func shape(parent: Node3D, kind: String, at: Vector3, extent: Vector3, color: String) -> MeshInstance3D:
	var n=MeshInstance3D.new(); n.mesh=mesh(kind); n.material_override=material(color)
	n.position=at; n.scale=extent; parent.add_child(n)
	return n

func stamp(kind: String, at: Vector3, extent: Vector3, color: String, yaw: float=0):
	var key=kind+":"+color
	if not batches.has(key): batches[key]=[]
	batches[key].append(Transform3D(Basis(Vector3.UP,yaw).scaled(extent),at))

func flush(parent: Node3D):
	for key in batches:
		var parts=key.split(":"); var list=batches[key]
		var mm=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.mesh=mesh(parts[0]); mm.instance_count=list.size()
		for i in list.size(): mm.set_instance_transform(i,list[i])
		var n=MultiMeshInstance3D.new(); n.multimesh=mm; n.material_override=material(parts[1]); parent.add_child(n)
	batches.clear()

func tree(at: Vector3, variation: int=0, small: bool=false):
	var s=0.68 if small else 1.0
	stamp("cylinder",at+Vector3(0,.7*s,0),Vector3(.34,1.4,.34)*s,"8b6949")
	var tones=["377e55","41865b","397d5d"]
	stamp("canopy",at+Vector3(0,.78*s,0),Vector3(1.82,1.6,1.82)*s,tones[posmod(variation,3)])
	stamp("canopy",at+Vector3(0,1.46*s,0),Vector3(1.48,1.4,1.48)*s,"4c9863")
	stamp("canopy",at+Vector3(0,2.1*s,0),Vector3(1.05,1.25,1.05)*s,"65a970")
	for tier in 3:
		var radius=[.78,.63,.44][tier]*s
		for leaf in 12:
			var angle=leaf*TAU/12+tier*.2
			stamp("ball",at+Vector3(cos(angle)*radius,(1.06+tier*.65+.04*sin(leaf*2.3))*s,sin(angle)*radius),Vector3(.32,.13,.36)*s,["428858","549b62","6cab6b"][tier])

func flower(at: Vector3, color: String):
	stamp("cylinder",at+Vector3(0,.12,0),Vector3(.035,.24,.035),"4f8f52")
	for petal in 5:
		var angle=petal*TAU/5
		stamp("ball",at+Vector3(cos(angle)*.09,.25,sin(angle)*.09),Vector3(.15,.07,.15),color)
	stamp("ball",at+Vector3(0,.28,0),Vector3(.08,.06,.08),"f4d36b")

func pokeball(at: Vector3, diameter: float=.42):
	stamp("ball",at,Vector3.ONE*diameter,"pokeball")
	stamp("ball",at+Vector3(0,0,diameter*.48),Vector3(.28,.28,.09)*diameter,"34414c")
	stamp("ball",at+Vector3(0,0,diameter*.53),Vector3(.18,.18,.04)*diameter,"f4f4e9")

func sign(at: Vector3):
	stamp("softbox",at+Vector3(0,.38,0),Vector3(.16,.76,.16),"8d7257")
	stamp("softbox",at+Vector3(0,.8,0),Vector3(.78,.48,.18),"886d51")
	stamp("softbox",at+Vector3(0,.81,.1),Vector3(.68,.37,.035),"e2d9b7")
	for y in [.73,.81,.89]: stamp("box",at+Vector3(.04,y,.125),Vector3(.39,.025,.01),"778880")
	stamp("ball",at+Vector3(-.24,.81,.13),Vector3(.13,.13,.025),"a96359")

func counter(at: Vector3, size: Vector2, theme: String):
	var center="POKEMON_CENTER" in theme
	var top="c77f62" if center else "8eafb5" if "LAB" in theme else "78a3ad"
	stamp("softbox",at+Vector3(0,.38,0),Vector3(size.x-.04,.76,size.y-.04),"d2d1c3")
	stamp("softbox",at+Vector3(0,.8,0),Vector3(size.x,.14,size.y),top)
	stamp("box",at+Vector3(0,.2,size.y*.5-.012),Vector3(size.x-.08,.08,.035),top)
	if center and size.x>=3:
		var emblem=at+Vector3(0,.48,size.y*.5+.012)
		stamp("ball",emblem,Vector3(.45,.45,.04),"f5e8d3")
		stamp("box",emblem+Vector3(0,0,.025),Vector3(.43,.045,.02),top)
		stamp("ball",emblem+Vector3(0,0,.04),Vector3(.14,.14,.025),top)

func furnishing(at: Vector3, kind: String, variation: int=0, theme: String=""):
	if kind=="bed":
		stamp("softbox",at+Vector3(0,.2,.5),Vector3(.92,.4,1.9),"957856")
		stamp("softbox",at+Vector3(0,.48,.5),Vector3(.9,.22,1.85),"f2ebd8")
		stamp("softbox",at+Vector3(0,.62,-.1),Vector3(.7,.16,.4),"fff7e4")
		stamp("softbox",at+Vector3(0,.61,.85),Vector3(.92,.12,1.12),"80b79b")
		stamp("softbox",at+Vector3(0,.5,-.48),Vector3(1,.9,.12),"aa8c65")
	elif kind=="chair":
		for x in [-.26,.26]:
			for z in [-.25,.25]: stamp("softbox",at+Vector3(x,.23,z),Vector3(.09,.46,.09),"8c735c")
		stamp("softbox",at+Vector3(0,.48,0),Vector3(.65,.16,.65),"7aa6b4")
		stamp("softbox",at+Vector3(0,.8,-.28),Vector3(.65,.55,.12),"a3c3c5")
	elif kind=="table" and not ("CENTER" in theme or "LAB" in theme or "MART" in theme):
		for x in [-.33,.33]:
			for z in [-.33,.33]: stamp("softbox",at+Vector3(x,.35,z),Vector3(.1,.7,.1),"977653")
		stamp("softbox",at+Vector3(0,.76,0),Vector3(1,.13,1),"d9ba88")
	elif kind=="plant":
		stamp("pot",at+Vector3(0,.22,0),Vector3(.56,.44,.56),"bc8364")
		stamp("ring",at+Vector3(0,.43,0),Vector3(.59,.5,.59),"d8a180")
		stamp("cylinder",at+Vector3(0,.42,0),Vector3(.47,.035,.47),"655b43")
		stamp("cylinder",at+Vector3(0,.64,0),Vector3(.055,.44,.055),"538050")
		for leaf in 8:
			var angle=leaf*2.39996; var height=.57+float(leaf%3)*.13
			stamp("ball",at+Vector3(sin(angle)*.2,height,cos(angle)*.2),Vector3(.25,.095,.57),"619456" if leaf%2 else "7eab64",angle)
			stamp("ball",at+Vector3(sin(angle)*.2,height+.048,cos(angle)*.2),Vector3(.018,.015,.42),"95b774",angle)
	elif kind=="computer":
		stamp("softbox",at+Vector3(0,.42,0),Vector3(.78,.84,.7),"aebbb8")
		stamp("softbox",at+Vector3(0,1.06,-.18),Vector3(.7,.6,.23),"e0deca")
		stamp("softbox",at+Vector3(0,1.07,-.05),Vector3(.54,.4,.035),"62b7c0")
		stamp("softbox",at+Vector3(0,.87,.12),Vector3(.5,.035,.24),"e2e5da")
		for row in 3:
			for col in 6: stamp("softbox",at+Vector3(-.19+col*.075,.895,.045+row*.07),Vector3(.045,.012,.035),"758c92")
		for col in 3: stamp("softbox",at+Vector3(-.16+col*.16,1.08,-.026),Vector3(.09,.09,.012),["c3e7dd","a6d4e8","d6db9f"][col])
		stamp("ball",at+Vector3(.29,.6,.36),Vector3(.045,.045,.02),"74cfaa")
	elif kind=="cabinet":
		stamp("softbox",at+Vector3(0,.55,0),Vector3(.97,1.1,.88),"a99470")
		stamp("softbox",at+Vector3(0,1.12,0),Vector3(1,.1,.95),"d4c9a4")
		stamp("softbox",at+Vector3(0,.59,.445),Vector3(.84,.92,.03),"705d4c")
		for shelf in [.27,.71]:
			stamp("softbox",at+Vector3(0,shelf,.46),Vector3(.82,.06,.05),"e6d7ad")
			for j in range(5):
				var height=.24+float(posmod(j+variation,3))*.03
				stamp("softbox",at+Vector3(-.32+j*.16,shelf+height*.5,.47),Vector3(.11,height,.12),["7d9d9b","b58179","d2ba81"][posmod(j+variation,3)])
				stamp("softbox",at+Vector3(-.32+j*.16,shelf+.08,.535),Vector3(.085,.02,.008),"e8ddbd")
	else:
		var center="POKEMON_CENTER" in theme; var lab="LAB" in theme; var mart="MART" in theme
		stamp("softbox",at+Vector3(0,.38,0),Vector3(.85,.76,.85),"cbd4cb" if center or lab else "acc3bf" if mart else "a79271")
		stamp("softbox",at+Vector3(0,.8,0),Vector3(.99,.14,.99),"c9878e" if center else "9db9be" if lab else "7eabb1" if mart else "cfbda0")
		stamp("softbox",at+Vector3(0,.5,.435),Vector3(.8,.06,.025),"b95f71" if center else "dccab0")

func building(rect: Rect2, style: String, roof: String, doors: Array):
	var center=Vector3(rect.get_center().x,0,rect.get_center().y)
	var width=rect.size.x; var depth=maxf(1.0,rect.size.y-1.0)
	var height=1.9 if style!="tower" else 3.6
	center.z=rect.end.y-depth*.5-.65
	stamp("box",center+Vector3(0,.12,0),Vector3(width+.1,.24,depth+.15),"bdc9bd")
	stamp("box",center+Vector3(0,height*.5,0),Vector3(width-.18,height,depth-.15),"eee3c8")
	stamp("box",center+Vector3(0,.35,0),Vector3(width-.1,.32,depth),"b6c7c6")
	stamp("box",center+Vector3(0,height-.08,0),Vector3(width+.18,.16,depth+.18),"f4ebd6")
	if style in ["lab","gym","tower"]:
		stamp("box",center+Vector3(0,height+.14,0),Vector3(width+.38,.35,depth+.35),roof)
		stamp("box",center+Vector3(width*.26,height+.55,-depth*.16),Vector3(.8,.6,.8),"9caeb4")
	else:
		stamp("roof",center+Vector3(0,height,0),Vector3(width+.5,1.65,depth+.5),roof)
		# Parallel raised tiles catch the sun across both roof slopes.
		for side in [-1,1]:
			for stripe in range(1,5):
				var t=stripe/5.0
				stamp("box",center+Vector3(0,height+.825*(1-t)+.025,side*(depth+.5)*.5*t),Vector3(width+.48,.045,.055),roof)
		stamp("box",center+Vector3(-width*.28,height+.85,-depth*.18),Vector3(.48,.9,.55),"e2cfb1")
	var front=center.z+depth*.5+.02
	# Recessed masonry joints and corner trims give the facade readable depth.
	for course in 3:
		var y=.13+course*.13
		stamp("box",Vector3(center.x,y,front+.015),Vector3(width-.2,.018,.02),"9fada8")
		for brick in range(int(width*2)):
			var bx=rect.position.x+.3+brick*.5+(course%2)*.25
			if bx<rect.end.x-.2: stamp("box",Vector3(bx,y+.05,front+.02),Vector3(.018,.1,.025),"9fada8")
	for side in [-1,1]:
		stamp("box",Vector3(center.x+side*(width*.5-.12),height*.55,front+.045),Vector3(.16,height*.87,.14),"d8d9c5")
	if style in ["house","center","mart"]:
		for side in [-1,1]:
			for row in range(1,5):
				var t=row/5.0
				for column in range(int(width/.6)):
					var rx=rect.position.x+.3+column*.6+(row%2)*.14
					if rx>rect.end.x: continue
					stamp("box",center+Vector3(rx-center.x,height+.825*(1-t)+.035,side*(depth+.5)*.5*t),Vector3(.035,.04,.15),"a87b71" if style=="house" else "b86d75" if style=="center" else "6c94b1")
	for x in range(maxi(1,int(width/1.4))):
		var xx=rect.position.x+.75+x*1.35
		if xx>rect.end.x-.5: continue
		if doors.any(func(d):return absf(float(d.x)+.5-xx)<.8): continue
		stamp("box",Vector3(xx,1.2,front),Vector3(.91,.74,.12),"faf3db")
		stamp("box",Vector3(xx,1.23,front+.075),Vector3(.71,.51,.06),"639da9")
		stamp("box",Vector3(xx-.17,1.29,front+.112),Vector3(.12,.32,.025),"b0dfdc")
		stamp("box",Vector3(xx,.8,front+.1),Vector3(.98,.12,.24),"ced9cc")
		stamp("box",Vector3(xx,1.23,front+.12),Vector3(.045,.51,.025),"dce6dd")
	for door in doors:
		var x=float(door.x)+.5; var z=front+.03
		stamp("box",Vector3(x,.7,z),Vector3(1.12,1.4,.15),"f5ead3")
		stamp("box",Vector3(x,.64,z+.09),Vector3(.86,1.25,.08),"658b98")
		stamp("box",Vector3(x,.83,z+.14),Vector3(.61,.59,.03),"b1dcdb")
		stamp("ball",Vector3(x+.27,.52,z+.18),Vector3.ONE*.08,"f7d999")
		stamp("box",Vector3(x,.04,z+.45),Vector3(1.3,.08,.65),"dfd8c1")
	if style in ["center","mart","gym","lab"]:
		var emblem=Vector3(center.x,height-.1,front+.19)
		stamp("ball",emblem,Vector3(.68,.68,.12),"f5ebd2")
		stamp("box",emblem+Vector3(0,0,.08),Vector3(.48,.09,.04),roof)
		stamp("ball",emblem+Vector3(0,0,.1),Vector3(.2,.2,.05),roof)

func trainer(config: Dictionary, identity: String="") -> Node3D:
	return preload("res://kanto_character_models.gd").new().build(self,config,identity)
