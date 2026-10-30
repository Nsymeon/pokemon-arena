extends RefCounted
# Shared meshes and MultiMesh batches keep forests independent of tree count.
var materials={}
var meshes={}
var batches={}

func material(hex: String) -> Material:
	if materials.has(hex): return materials[hex]
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
		"ball":
			var sphere=SphereMesh.new(); sphere.radius=0.5; sphere.height=1.0; sphere.radial_segments=20; sphere.rings=10; m=sphere
		"cylinder":
			var cylinder=CylinderMesh.new(); cylinder.top_radius=0.5; cylinder.bottom_radius=0.5; cylinder.height=1; cylinder.radial_segments=12; m=cylinder
		"rock":
			m=profile_mesh([Vector2(.34,-.5),Vector2(.5,-.28),Vector2(.46,.2),Vector2(.28,.48),Vector2(0,.53)],10,true)
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

func furnishing(at: Vector3, kind: String, variation: int=0, theme: String=""):
	if kind=="bed":
		stamp("box",at+Vector3(0,.2,.5),Vector3(.92,.4,1.9),"957856")
		stamp("box",at+Vector3(0,.48,.5),Vector3(.9,.22,1.85),"f2ebd8")
		stamp("box",at+Vector3(0,.62,-.1),Vector3(.7,.16,.4),"fff7e4")
		stamp("box",at+Vector3(0,.61,.85),Vector3(.92,.12,1.12),"80b79b")
		stamp("box",at+Vector3(0,.5,-.48),Vector3(1,.9,.12),"aa8c65")
	elif kind=="chair":
		for x in [-.26,.26]:
			for z in [-.25,.25]: stamp("box",at+Vector3(x,.23,z),Vector3(.09,.46,.09),"8c735c")
		stamp("box",at+Vector3(0,.48,0),Vector3(.65,.16,.65),"7aa6b4")
		stamp("box",at+Vector3(0,.8,-.28),Vector3(.65,.55,.12),"a3c3c5")
	elif kind=="table" and not ("CENTER" in theme or "LAB" in theme or "MART" in theme):
		for x in [-.33,.33]:
			for z in [-.33,.33]: stamp("box",at+Vector3(x,.35,z),Vector3(.1,.7,.1),"977653")
		stamp("box",at+Vector3(0,.76,0),Vector3(1,.13,1),"d9ba88")
	elif kind=="plant":
		stamp("cylinder",at+Vector3(0,.22,0),Vector3(.53,.44,.53),"bc8364")
		stamp("ball",at+Vector3(0,.66,0),Vector3(.7,.65,.7),"63985c")
		stamp("ball",at+Vector3(.1,.9,0),Vector3(.4,.5,.4),"82b568")
	elif kind=="computer":
		stamp("box",at+Vector3(0,.42,0),Vector3(.78,.84,.7),"aebbb8")
		stamp("box",at+Vector3(0,1.06,-.18),Vector3(.7,.6,.23),"e0deca")
		stamp("box",at+Vector3(0,1.07,-.05),Vector3(.54,.4,.035),"62b7c0")
		stamp("box",at+Vector3(0,.87,.12),Vector3(.5,.035,.24),"e2e5da")
	elif kind=="cabinet":
		stamp("box",at+Vector3(0,.55,0),Vector3(.97,1.1,.88),"a99470")
		stamp("box",at+Vector3(0,1.12,0),Vector3(1,.1,.95),"d4c9a4")
		for shelf in [.27,.71]:
			stamp("box",at+Vector3(0,shelf,.46),Vector3(.82,.06,.05),"e6d7ad")
			for j in range(4): stamp("box",at+Vector3(-.3+j*.2,shelf+.16,.4),Vector3(.13,.27,.15),["7d9d9b","b58179","d2ba81"][posmod(j+variation,3)])
	else:
		var center="POKEMON_CENTER" in theme; var lab="LAB" in theme; var mart="MART" in theme
		stamp("box",at+Vector3(0,.38,0),Vector3(.85,.76,.85),"cbd4cb" if center or lab else "acc3bf" if mart else "a79271")
		stamp("box",at+Vector3(0,.8,0),Vector3(.99,.14,.99),"c9878e" if center else "9db9be" if lab else "7eabb1" if mart else "cfbda0")
		stamp("box",at+Vector3(0,.5,.435),Vector3(.8,.06,.025),"b95f71" if center else "dccab0")

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
	var root=Node3D.new()
	var shirt=str(config.get("shirt","6b9dc1")); var pants=str(config.get("pants","536779")); var hair=str(config.get("hair","6c4938")); var shoes=str(config.get("shoes","f3e6ce"))
	var skin="f4cda6"; var professor="oak" in identity.to_lower(); var nurse="nurse" in identity.to_lower()
	var female=config.get("gender","boy")=="girl" or ["WOMAN","GIRL","LASS","MOM","NURSE","MISTY","ERIKA","SABRINA","LORELEI","AGATHA"].any(func(word):return identity.to_upper().contains(word))
	if professor: shirt="eee7d2"; hair="9eaaa3"
	if nurse: shirt="efc0c7"; hair="b96a77"
	if "scientist" in identity.to_lower(): shirt="e5e6d9"
	if "rocket" in identity.to_lower(): shirt="48515a"; pants="48515a"
	for side in [-1,1]:
		var leg=Node3D.new(); leg.name="LeftLeg" if side<0 else "RightLeg"; leg.position=Vector3(side*.16,.43,0); root.add_child(leg)
		shape(leg,"cylinder",Vector3(0,-.11,0),Vector3(.23,.42,.24),pants)
		shape(leg,"ball",Vector3(0,-.32,.08),Vector3(.29,.19,.43),shoes)
		var arm=Node3D.new(); arm.name="LeftArm" if side<0 else "RightArm"; arm.position=Vector3(side*.36,.87,0); root.add_child(arm)
		shape(arm,"ball",Vector3(0,-.05,0),Vector3(.24,.34,.27),shirt)
		shape(arm,"ball",Vector3(0,-.24,0),Vector3(.19,.24,.2),skin)
	shape(root,"ball",Vector3(0,.73,0),Vector3(.69,.75,.5),shirt)
	shape(root,"box",Vector3(0,.55,.18),Vector3(.38,.06,.1),"f4ead4")
	shape(root,"ball",Vector3(0,1.3,0),Vector3(.84,.84,.77),skin)
	shape(root,"ball",Vector3(0,1.55,-.08),Vector3(.89,.49,.78),hair)
	shape(root,"ball",Vector3(-.3,1.43,.15),Vector3(.22,.38,.27),hair)
	if female:
		for side in [-1,1]: shape(root,"ball",Vector3(side*.36,1.18,-.15),Vector3(.24,.7,.32),hair)
	for side in [-1,1]:
		shape(root,"ball",Vector3(side*.155,1.31,.354),Vector3(.16,.22,.062),"fffaf0")
		shape(root,"ball",Vector3(side*.155,1.3,.388),Vector3(.078,.145,.035),"384b52")
		shape(root,"ball",Vector3(side*.145,1.34,.409),Vector3(.024,.038,.015),"ffffff")
	shape(root,"ball",Vector3(0,1.2,.39),Vector3(.09,.08,.09),skin)
	shape(root,"box",Vector3(0,1.12,.35),Vector3(.12,.025,.02),"ad7d6b")
	if nurse: shape(root,"ball",Vector3(0,1.72,0),Vector3(.65,.18,.55),"eeeadd")
	if professor: shape(root,"box",Vector3(0,.8,.25),Vector3(.22,.43,.025),"9e8871")
	if config.has("shoes"):
		shape(root,"ball",Vector3(0,1.65,-.02),Vector3(.91,.32,.84),shirt)
		shape(root,"ball",Vector3(0,1.56,.36),Vector3(.69,.1,.42),"f3e9d5")
		shape(root,"box",Vector3(0,.86,-.3),Vector3(.38,.48,.18),"b28a57")
	return root
