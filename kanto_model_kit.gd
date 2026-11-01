extends RefCounted
# Shared meshes and MultiMesh batches keep forests independent of tree count.
var art=preload("res://kanto_art_assets.gd").new()
var materials={}
var meshes={}
var batches={}

func material(hex: String) -> Material:
	if materials.has(hex): return materials[hex]
	var crafted=art.material(hex)
	if crafted!=null: materials[hex]=crafted; return crafted
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
 float vein=1.-smoothstep(.01,.055,abs(UV.x-.5));
 ALBEDO=tint.rgb*mix(.55,1.16,clamp(blade_height,0.,1.))*(1.+vein*.12);
 ROUGHNESS=.86;
 BACKLIGHT=tint.rgb*.10;
}
"""
		var foliage=ShaderMaterial.new(); foliage.shader=shader
		foliage.set_shader_parameter("tint",Color(hex.trim_prefix("grass_")).srgb_to_linear())
		materials[hex]=foliage; return foliage
	if hex=="turf":
		var shader=Shader.new()
		shader.code="""shader_type spatial;
varying vec3 p;
void vertex() { p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz; }
float turf_hash(vec2 q) { return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453); }
float turf_noise(vec2 q) {
 vec2 i=floor(q); vec2 f=fract(q); f=f*f*(3.-2.*f);
 return mix(mix(turf_hash(i),turf_hash(i+vec2(1.,0.)),f.x),mix(turf_hash(i+vec2(0.,1.)),turf_hash(i+vec2(1.,1.)),f.x),f.y);
}
void fragment() {
 float shade=turf_noise(p.xz*2.)-.5;
 float grain=turf_noise(p.xz*35.)-.5;
 ALBEDO=vec3(.30,.46,.20)*(1.+shade*.12+grain*.04);
 ROUGHNESS=1.;
}
"""
		var turf=ShaderMaterial.new(); turf.shader=shader; materials[hex]=turf; return turf
	if hex=="cliff_outdoor":
		var shader=Shader.new()
		shader.code="""shader_type spatial;
varying vec3 p;
void vertex() { p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz; }
void fragment() {
 float grain=sin(p.x*18.+sin(p.z*11.))*sin(p.y*23.+p.z*17.);
 float strata=sin((p.y+p.x*.19+p.z*.11)*11.+sin(p.x*1.2+p.z*.7)*.6);
 float seam=smoothstep(.74,.99,strata);
 ALBEDO=mix(vec3(.39,.23,.12),vec3(.57,.36,.20),.60+grain*.06);
 ALBEDO*=1.-seam*.26;
 ROUGHNESS=.95;
}
"""
		var rock=ShaderMaterial.new(); rock.shader=shader; materials[hex]=rock; return rock
	if hex=="489eaf":
		var shader=Shader.new()
		shader.code="""shader_type spatial;
uniform vec4 deep:source_color=vec4(.24,.39,.55,1.);
uniform vec4 shallow:source_color=vec4(.36,.57,.65,1.);
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float wave=sin(p.x*1.4+p.z*.8+TIME*.35)+sin(p.z*2.2-p.x*.6-TIME*.27);
 float lines=pow(max(0.,sin(p.x*5.+p.z*2.+TIME*.5)*sin(p.z*3.-TIME*.23)),18.);
 ALBEDO=mix(deep.rgb,shallow.rgb,.24+.10*wave)+vec3(.02,.025,.03)*lines;
 ROUGHNESS=.42; SPECULAR=.28;
}
"""
		var water=ShaderMaterial.new(); water.shader=shader; materials[hex]=water; return water
	var m=StandardMaterial3D.new()
	m.albedo_color=Color(hex); m.roughness=0.82
	materials[hex]=m
	return m

func mesh(kind: String) -> Mesh:
	if meshes.has(kind): return meshes[kind]
	if kind in art.MESHES: return art.mesh(kind)
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
		"leaf":
			var leaf=SphereMesh.new(); leaf.radius=.5; leaf.height=1.0; leaf.radial_segments=8; leaf.rings=4; m=leaf
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
						var width=.20*pow(sin(t*PI),.8)+.008*(1-t)
						points.append(rotate*Vector3(pair[1]*width,h*t,.04+.4*t*t))
						normals.append((rotate*Vector3(0,.8*t,-h)).normalized())
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
	var s=.68 if small else 1.
	stamp("contact_plane",at+Vector3(0,.018,0),Vector3(2.05,1,1.75)*s,"contact_shadow")
	stamp("cylinder",at+Vector3(0,.64*s,0),Vector3(.42,1.28,.42)*s,"wood_a57a46")
	for root in range(5):
		var angle=root*TAU/5
		stamp("rock",at+Vector3(sin(angle)*.21,.17,cos(angle)*.21)*s,Vector3(.25,.38,.44)*s,"wood_b38a51",angle)
	for tier in range(3):
		var size=[2.05,1.66,1.19][tier]*s
		stamp("crown",at+Vector3(0,(.89+tier*.63)*s,0),Vector3(size,(1.31-tier*.08)*s,size),"foliage",float(variation)*.27+tier*.19)

func cut_tree(at: Vector3):
	# A distinct waist-high sapling; full forest trees reach 3.35 units.
	stamp("cylinder",at+Vector3(0,.27,0),Vector3(.17,.54,.17),"aa804b")
	stamp("canopy",at+Vector3(0,.32,0),Vector3(.78,.7,.78),"4f8e31")
	stamp("canopy",at+Vector3(0,.65,0),Vector3(.52,.55,.52),"88be47")
	for side in [-1,1]:
		stamp("ball",at+Vector3(side*.22,.58,.06),Vector3(.4,.16,.3),"6aa438")

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
	stamp("contact_plane",at+Vector3(0,.018,0),Vector3(1.15,1,1.05),"contact_shadow")
	if kind=="television":
		stamp("softbox",at+Vector3(0,.32,0),Vector3(.94,.64,.68),"wood_b48e61")
		for x in [-.22,.22]: stamp("softbox",at+Vector3(x,.43,.35),Vector3(.38,.23,.025),"dac59c")
		stamp("cylinder",at+Vector3(0,.77,0),Vector3(.08,.25,.08),"46505c")
		stamp("softbox",at+Vector3(0,1.08,0),Vector3(.91,.59,.13),"303c4a")
		stamp("softbox",at+Vector3(0,1.08,.073),Vector3(.8,.47,.015),"83bdcf")
		stamp("softbox",at+Vector3(.18,.7,.15),Vector3(.32,.07,.16),"354654")
		for side in [-1,1]: stamp("softbox",at+Vector3(.18+side*.17,.7,.15),Vector3(.07,.075,.17),"60b6ca" if side<0 else "e97670")
	elif kind=="kitchen":
		stamp("softbox",at+Vector3(0,.42,0),Vector3(1,.84,.9),"e6d9b5")
		stamp("softbox",at+Vector3(0,.87,0),Vector3(1.02,.12,.98),"b7c8c6")
		stamp("softbox",at+Vector3(0,.43,.46),Vector3(.88,.63,.025),"b2cbb9")
		stamp("softbox",at+Vector3(.28,.65,.49),Vector3(.18,.035,.035),"657779")
		if variation==0x31:
			stamp("softbox",at+Vector3(0,.94,0),Vector3(.64,.035,.55),"657d86")
			stamp("softbox",at+Vector3(0,.96,0),Vector3(.5,.035,.4),"9db9c0")
			stamp("cylinder",at+Vector3(0,1.08,-.3),Vector3(.05,.35,.05),"d1dcdb")
			stamp("softbox",at+Vector3(0,1.24,-.22),Vector3(.06,.055,.2),"d1dcdb")
		elif variation==0x32:
			for x in [-.21,.21]:
				for z in [-.2,.2]: stamp("ring",at+Vector3(x,.94,z),Vector3(.26,.1,.26),"59636a")
	elif kind=="bed":
		stamp("softbox",at+Vector3(0,.2,.5),Vector3(.92,.4,1.9),"wood_957856")
		stamp("softbox",at+Vector3(0,.48,.5),Vector3(.9,.22,1.85),"f2ebd8")
		stamp("softbox",at+Vector3(0,.62,-.1),Vector3(.7,.16,.4),"fff7e4")
		stamp("softbox",at+Vector3(0,.61,.85),Vector3(.92,.12,1.12),"quilt")
		stamp("softbox",at+Vector3(0,.66,.33),Vector3(.94,.05,.14),"c4d6bd")
		stamp("softbox",at+Vector3(0,.5,-.48),Vector3(1,.9,.12),"wood_aa8c65")
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
		stamp("softbox",at+Vector3(0,.55,0),Vector3(.97,1.1,.88),"wood_a99470")
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
	var width=rect.size.x; var depth=maxf(1.,rect.size.y-1.)
	var height=1.95 if style!="tower" else 3.5
	var center=Vector3(rect.get_center().x,0,rect.end.y-depth*.5-.65)
	var front=center.z+depth*.5+.02
	var timber=style=="house"
	stamp("contact_plane",center+Vector3(0,.021,.15),Vector3(width+.8,1,depth+1.1),"contact_shadow")
	stamp("softbox",center+Vector3(0,.16,0),Vector3(width+.08,.32,depth+.08),"939b91")
	stamp("box",center+Vector3(0,height*.5+.1,0),Vector3(width-.16,height,depth-.12),"wood_b99c70" if timber else "plaster_e0e5d7")
	# Timber siding wraps the exterior. Narrow joints give each board a lit upper edge.
	for row in range(7):
		var y=.39+row*.22
		stamp("softbox",Vector3(center.x,y,front+.01),Vector3(width-.18,.205,.08),"wood_c5aa7d" if timber else "plaster_d3dbd4")
		for side in [-1,1]: stamp("softbox",center+Vector3(side*(width*.5-.07),y,0),Vector3(.08,.205,depth-.1),"wood_b99c70" if timber else "plaster_d3dbd4")
	for side in [-1,1]:
		stamp("softbox",Vector3(center.x+side*(width*.5-.16),height*.5+.12,front+.06),Vector3(.17,height,.15),"wood_82674c" if timber else "c6d0c9")
	stamp("box",center+Vector3(0,height+.07,0),Vector3(width+.23,.16,depth+.22),"wood_8e7452" if timber else "cad8d5")
	if style in ["lab","gym","tower"]:
		stamp("softbox",center+Vector3(0,height+.22,0),Vector3(width+.35,.35,depth+.3),"roof_"+roof)
		stamp("box",center+Vector3(0,height+.42,0),Vector3(width-.2,.06,depth-.25),"roof_"+roof)
		for side in [-1,1]: stamp("box",center+Vector3(side*(width*.5),height+.48,0),Vector3(.12,.22,depth+.2),"d1d8c6")
	else:
		var half=(depth+.5)*.5; var rise=.95
		stamp("roof",center+Vector3(0,height+.1,0),Vector3(width+.5,rise*2,depth+.5),"roof_"+roof)
		var columns=maxi(3,ceili((width+.5)/.45)); var rows=maxi(3,ceili(half/.42))
		var pitch=atan2(rise,half)
		for side in [-1,1]:
			for row in range(rows):
				var t=(row+.5)/rows
				for column in range(columns):
					var p=center+Vector3(-(width+.5)*.5+(column+.5)*(width+.5)/columns,height+.1+rise*(1.-t)+.025,side*half*t)
					var basis=Basis(Vector3.RIGHT,side*pitch)*Basis.from_scale(Vector3((width+.5)/columns+.015,.14,sqrt(half*half+rise*rise)/rows+.035))
					stamp_pose("roof_shingle",Transform3D(basis,p),"roof_"+roof)
			stamp("softbox",center+Vector3(0,height+.04,side*half),Vector3(width+.62,.11,.12),"wood_80664b" if timber else "a8babd")
		stamp("softbox",center+Vector3(0,height+rise+.13,0),Vector3(width+.6,.16,.2),"roof_"+roof)
		stamp("softbox",center+Vector3(-width*.29,height+.7,-depth*.12),Vector3(.42,1.05,.52),"plaster_c6b59b")
		stamp("softbox",center+Vector3(-width*.29,height+1.25,-depth*.12),Vector3(.56,.12,.65),"a38b70")
	for column in range(maxi(1,int(width/1.6))):
		var x=rect.position.x+.85+column*1.6
		if x>rect.end.x-.5 or doors.any(func(d):return absf(d.x+.5-x)<.85): continue
		stamp("softbox",Vector3(x,1.16,front+.09),Vector3(.98,.87,.18),"wood_8e704f" if timber else "aabac2")
		stamp("box",Vector3(x,1.18,front+.19),Vector3(.79,.66,.025),"538a9e")
		if timber:
			for side in [-1,1]: stamp("softbox",Vector3(x+side*.29,1.18,front+.22),Vector3(.13,.62,.035),"eedba7")
		stamp("box",Vector3(x,1.18,front+.23),Vector3(.045,.67,.04),"e1d3b1")
		stamp("box",Vector3(x,1.18,front+.23),Vector3(.8,.045,.04),"e1d3b1")
		stamp("softbox",Vector3(x,.7,front+.18),Vector3(1.1,.14,.26),"wood_957452")
		if timber:
			stamp("softbox",Vector3(x,.57,front+.16),Vector3(.86,.18,.23),"wood_9c7855")
			for flower_index in range(3): flower(Vector3(x-.27+flower_index*.27,.61,front+.18),["e9af9a","e6c780","c0ce9d"][flower_index])
	for door in doors:
		var x=float(door.x)+.5
		if style in ["center","mart"]: doorway(Vector3(x,0,front+.16),false); continue
		stamp("softbox",Vector3(x,.73,front+.09),Vector3(1.09,1.46,.16),"wood_84674b")
		stamp("softbox",Vector3(x,.7,front+.18),Vector3(.84,1.34,.07),"wood_b38b58")
		stamp("softbox",Vector3(x,1.03,front+.23),Vector3(.56,.45,.035),"79a5ac")
		stamp("box",Vector3(x,1.03,front+.255),Vector3(.035,.46,.02),"e1c892")
		stamp("box",Vector3(x,.35,front+.23),Vector3(.58,.38,.03),"wood_987349")
		stamp("ball",Vector3(x+.27,.64,front+.26),Vector3(.075,.075,.04),"c9ad6c")
		stamp("softbox",Vector3(x,.045,front+.36),Vector3(1.18,.09,.48),"b1aca0")
	if style in ["center","mart","gym","lab"]:
		var emblem=Vector3(center.x,height-.11,front+.25)
		stamp("ball",emblem,Vector3(.62,.62,.12),"e9e4d3")
		stamp("box",emblem+Vector3(0,0,.075),Vector3(.55,.075,.035),roof)
		stamp("ball",emblem+Vector3(0,0,.1),Vector3(.19,.19,.04),roof)

func stamp_pose(kind: String, transform: Transform3D, color: String):
	var key=kind+":"+color
	if not batches.has(key): batches[key]=[]
	batches[key].append(transform)

func trainer(config: Dictionary, identity: String="") -> Node3D:
	return preload("res://kanto_character_models.gd").new().build(self,config,identity)

func dining_table(at: Vector3, size: Vector2):
	stamp("contact_plane",at+Vector3(0,.02,0),Vector3(size.x+1,1,size.y+1),"contact_shadow")
	for x in [-1,1]:
		for z in [-1,1]: stamp("softbox",at+Vector3(x*(size.x*.5-.2),.36,z*(size.y*.5-.2)),Vector3(.13,.72,.13),"95714d")
	stamp("softbox",at+Vector3(0,.78,0),Vector3(size.x,.15,size.y),"dac197")
	stamp("softbox",at+Vector3(0,.866,0),Vector3(size.x*.58,.025,size.y*.92),"tablecloth")
	stamp("pot",at+Vector3(0,1.01,0),Vector3(.22,.28,.22),"eee4d0")
	flower(at+Vector3(0,1.08,0),"efb777")

func home_window(at: Vector3):
	stamp("softbox",at,Vector3(.88,.76,.08),"b29b78")
	stamp("box",at+Vector3(0,0,.048),Vector3(.74,.62,.025),"b7dce3")
	for x in [-.33,.33]: stamp("softbox",at+Vector3(x,0,.08),Vector3(.18,.74,.09),"f2dca7")
	stamp("box",at+Vector3(0,0,.075),Vector3(.035,.64,.035),"f1e8d5")
	stamp("box",at+Vector3(0,0,.075),Vector3(.76,.035,.035),"f1e8d5")

func stair_tile(at: Vector3, column: int=0, columns: int=1, front_rail: bool=false, back_rail: bool=false):
	for step in range(4):
		var height=.06+.75*(column+(step+1)/4.0)/columns
		stamp("box",at+Vector3(-.375+step/4.0,height*.5,0),Vector3(.26,height,1.01),"ac9273")
		stamp("box",at+Vector3(-.375+step/4.0,height+.012,0),Vector3(.26,.025,1.01),"c8bda6")
		stamp("box",at+Vector3(-.49+step/4.0,height+.027,0),Vector3(.022,.012,1.01),"9a8b76")
	for side in [-1,1]:
		if not (front_rail if side>0 else back_rail): continue
		var height=.06+.75*(column+.5)/columns
		stamp("softbox",at+Vector3(0,height+.17,side*.46),Vector3(.08,.35,.08),"wood_b29363")
		var basis=Basis(Vector3.BACK,atan2(.75,columns))*Basis.from_scale(Vector3(sqrt(1.+pow(.75/columns,2)),.065,.09))
		stamp_pose("softbox",Transform3D(basis,at+Vector3(0,height+.36,side*.46)),"wood_c6a271")

func doorway(at: Vector3, wood: bool=false, span: float=1.0):
	# The front wall is cut away in homes; a threshold reads as an exit without
	# freestanding glass panels hiding the player and the room.
	if wood:
		stamp("box",at+Vector3(0,.035,0),Vector3(span,.06,.25),"wood_b1956e")
		stamp("softbox",at+Vector3(0,.026,.30),Vector3(span-.1,.045,.45),"a98669")
		return
	for side in [-1,1]:
		stamp("softbox",at+Vector3(side*(span*.5-.02),.8,0),Vector3(.12,1.6,.17),"b5946c" if wood else "a1b8c5")
		stamp("box",at+Vector3(side*(span-.2)*.25,.69,0),Vector3((span-.2)*.5,1.3,.07),"door_left" if side<0 else "door_right")
	stamp("softbox",at+Vector3(0,1.62,0),Vector3(span+.1,.15,.19),"ead7b5" if wood else "d4e1de")
	stamp("box",at+Vector3(0,.02,.2),Vector3(span-.1,.03,.62),"b5826d")

func exhibit(at: Vector3, size: Vector2, subject: String):
	stamp("softbox",at+Vector3(0,.22,0),Vector3(size.x-.12,.44,size.y-.12),"c4b38c")
	stamp("softbox",at+Vector3(0,.46,0),Vector3(size.x-.28,.06,size.y-.28),"547d91")
	stamp("softbox",at+Vector3(0,.5,size.y*.5-.15),Vector3(.65,.06,.25),"eadbb1")
	for corner in [-1,1]:
		stamp("cylinder",at+Vector3(corner*(size.x*.5-.16),.66,0),Vector3(.04,.4,.04),"bcc8c5")
	if subject=="shuttle":
		stamp("ball",at+Vector3(0,.8,0),Vector3(2.2,.48,.64),"f2ede1")
		stamp("ball",at+Vector3(-.65,.97,0),Vector3(.45,.15,.48),"46677d")
		for side in [-1,1]: stamp("softbox",at+Vector3(.32,.7,side*.48),Vector3(1.0,.09,.7),"dedccf",side*.35)
		stamp("softbox",at+Vector3(.78,1.05,0),Vector3(.48,.65,.08),"e8e5d9")
	elif subject=="meteorites":
		for i in range(4):
			stamp("rock",at+Vector3((i%2-.5)*1.4,.78,(int(i/2)-.5)*.85),Vector3(.64,.55,.55),["6d6866","8a7b64","506a6d","a79177"][i],i)
	else:
		var bone="e3d1a2"
		for i in range(9):
			var x=-1.1+i*.26
			stamp("ball",at+Vector3(x,.88+sin(i*.35)*.14,0),Vector3(.27,.22,.22),bone)
			if i in [2,3,4,5,6]:
				for side in [-1,1]: stamp("softbox",at+Vector3(x,.81,side*.24),Vector3(.09,.1,.48),bone,side*.3)
		stamp("rock",at+Vector3(-1.28,.94,0),Vector3(.6,.45,.42),bone)
		stamp("ball",at+Vector3(-1.42,1.03,.2),Vector3(.12,.12,.03),"5e5a4d")
		for side in [-1,1]:
			stamp("softbox",at+Vector3(.2,.71,side*.6),Vector3(.12,.12,.85),bone,side*.5)
			if subject=="aerodactyl":
				for finger in range(3): stamp("softbox",at+Vector3(-.5+finger*.4,.77,side*.65),Vector3(.09,.09,.9),bone,side*(.5+finger*.3))

func ladder(at: Vector3):
	stamp("box",at+Vector3(0,.02,0),Vector3(.82,.035,.9),"353e43")
	for side in [-1,1]: stamp("softbox",at+Vector3(side*.32,.09,0),Vector3(.08,.09,.96),"c9ad7b")
	for rung in range(5): stamp("softbox",at+Vector3(0,.1,-.36+rung*.18),Vector3(.69,.07,.065),"e4c993")

func shore(at: Vector3, direction: Vector2i):
	var vertical=direction.x!=0
	stamp("box",at+Vector3(direction.x*.48,.035,direction.y*.48),Vector3(.12,.10,1.005) if vertical else Vector3(1.005,.10,.12),"8b7953")
	stamp("box",at+Vector3(direction.x*.49,.084,direction.y*.49),Vector3(.12,.025,1.005) if vertical else Vector3(1.005,.025,.12),"70914b")
	stamp("contact_plane",at+Vector3(direction.x*.38,.029,direction.y*.38),Vector3(.12,1,1.005) if vertical else Vector3(1.005,1,.12),"shore_foam")

func fence(at: Vector3, connections: Array):
	stamp("softbox",at+Vector3(0,.40,0),Vector3(.15,.8,.15),"e1ddc4")
	stamp("softbox",at+Vector3(0,.82,0),Vector3(.19,.06,.19),"f0ebd6")
	for direction in connections:
		var along=Vector3(direction.x,0,direction.y)
		for height in [.25,.57]:
			stamp("box",at+along*.25+Vector3(0,height,0),Vector3(.52,.09,.075) if direction.x else Vector3(.075,.09,.52),"c5cab8")
		for offset in [.20,.40]:
			stamp("softbox",at+along*offset+Vector3(0,.40,0),Vector3(.13,.65,.07) if direction.x else Vector3(.07,.65,.13),"e4e1cb")

func update_player(at: Vector3):
	for key in ["door_left","door_right"]:
		if materials.has(key): materials[key].set_shader_parameter("player",at)
