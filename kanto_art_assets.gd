extends RefCounted
# Reusable art meshes: build once, instance across the world.
const MESHES=["crown","blade_tuft","roof_shingle","contact_plane","cliff_face","rock_surface"]
var cache={}
func mesh(kind: String) -> Mesh:
	if cache.has(kind): return cache[kind]
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind=="contact_plane":
		var plane=PlaneMesh.new(); plane.size=Vector2.ONE; cache[kind]=plane; return plane
	if kind=="rock_surface":
		var plane=PlaneMesh.new(); plane.size=Vector2.ONE; plane.subdivide_width=7; plane.subdivide_depth=7; cache[kind]=plane; return plane
	if kind=="crown":
		var profile=[Vector2(.33,0),Vector2(.5,.12),Vector2(.46,.29),Vector2(.37,.49),Vector2(.25,.70),Vector2(.12,.88),Vector2(0,1)]
		for row in range(profile.size()-1):
			for side in range(48):
				var points=[]
				for pair in [[row,side],[row,side+1],[row+1,side],[row+1,side+1]]:
					var angle=pair[1]*TAU/48.0; var t=profile[pair[0]].y
					var r=profile[pair[0]].x*(1.+.045*cos(angle*12.))
					points.append(Vector3(cos(angle)*r,t+.02*sin(angle*12.)*(1.-t),sin(angle)*r))
				for i in [0,1,2,1,3,2]:
					st.set_color(Color("4b8433").lerp(Color("98c74b"),points[i].y).srgb_to_linear()); st.add_vertex(points[i])
		# Overlapping individual leaf scales follow the crown's rounded silhouette.
		for row in range(4):
			var count=22-row*4; var t=.13+row*.17; var radius=[.49,.44,.36,.26][row]
			for side in range(count):
				var angle=side*TAU/count+row*.17
				var basis=Basis(Vector3.UP,angle)
				var center=Vector3(sin(angle)*radius,t,cos(angle)*radius)
				var points=[Vector3(0,-.13,.01),Vector3(-.075,-.04,0),Vector3(-.065,.075,-.025),Vector3(0,.12,-.055),Vector3(.065,.075,-.025),Vector3(.075,-.04,0),Vector3(0,0,.055)]
				var shade=Color("518c34").lerp(Color("a4cf56"),t+.03*sin(side*2.))
				for edge in range(6):
					for i in [edge,(edge+1)%6,6]:
						st.set_color(shade.lightened(.06 if i==6 else 0).srgb_to_linear()); st.add_vertex(center+basis*points[i])
	elif kind=="roof_shingle":
		for strip in range(8):
			var points=[]; var uvs=[]
			for pair in [[strip,0],[strip+1,0],[strip,1],[strip+1,1]]:
				var x=-.5+pair[0]/8.0
				points.append(Vector3(x,.4*cos(x*PI)-pair[1]*.04,pair[1]-.5))
				uvs.append(Vector2(x+.5,pair[1]))
			for i in [0,1,2,1,3,2]: st.set_uv(uvs[i]); st.add_vertex(points[i])
	elif kind=="cliff_face":
		# Matching end points keep adjacent faces continuous, with shallow facets.
		for row in range(4):
			for column in range(6):
				var points=[]
				for pair in [[column,row],[column+1,row],[column,row+1],[column+1,row+1]]:
					var x=pair[0]/6.0; var y=pair[1]/4.0
					points.append(Vector3(x-.5,y,.5+.065*sin(x*PI)*sin(y*PI)+.025*sin(x*TAU)*sin(y*TAU)))
				for i in [0,2,1,1,2,3]: st.add_vertex(points[i])
	elif kind=="blade_tuft":
		for blade in range(5):
			var turn=Basis(Vector3.UP,blade*2.39996)
			var height=.68+(blade%3)*.11
			for segment in range(8):
				for half in [-1,1]:
					var points=[]; var uvs=[]
					for pair in [[segment,0],[segment,half],[segment+1,0],[segment+1,half]]:
						var t=pair[0]/8.0; var lateral=float(pair[1]); var width=.22*pow(maxf(0.,sin(t*PI)),.82)
						points.append(turn*Vector3(lateral*width,height*(1.12*t-.18*t*t),.04+.52*t*t+.055*(1.-absf(lateral))*sin(t*PI)))
						uvs.append(Vector2((lateral+1.)*.5,t))
					for i in ([0,1,2,1,3,2] if half==1 else [1,0,2,3,1,2]): st.set_uv(uvs[i]); st.add_vertex(points[i])
	st.index(); st.generate_normals(); var result=st.commit(); cache[kind]=result; return result

func material(kind: String) -> Material:
	if kind=="cave_cap":
		var shader=Shader.new(); shader.code="""shader_type spatial;
varying vec3 p;
float relief(vec2 q){
 return .17+.06*sin(q.x*3.+sin(q.y*2.4))+.05*cos(q.y*4.3+q.x*1.7)+.025*sin(q.x*9.-q.y*6.);
}
void vertex(){
 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 VERTEX.y+=relief(p.xz);
 float dx=(relief(p.xz+vec2(.02,0.))-relief(p.xz-vec2(.02,0.)))/.04;
 float dz=(relief(p.xz+vec2(0.,.02))-relief(p.xz-vec2(0.,.02)))/.04;
 NORMAL=normalize(vec3(-dx,1.,-dz));
}
void fragment(){
 float grain=sin(p.x*61.+p.z*17.)*sin(p.z*49.-p.x*21.);
 ALBEDO=vec3(.27,.29,.27)*(1.+grain*.045+relief(p.xz)*.2); ROUGHNESS=.97;
}
"""
		var mat=ShaderMaterial.new(); mat.shader=shader; return mat
	if kind in ["waterfall","shore_foam"]:
		var shader=Shader.new(); shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform float falling=0.;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float flow=sin(p.x*37.+sin(p.y*5.+TIME*3.))*sin(p.y*18.+TIME*6.);
 float ripple=sin(p.x*9.+p.z*11.-TIME*.8)*.5+.5;
 ALBEDO=mix(vec3(.17,.39,.49),vec3(.57,.76,.75),.48+flow*.15);
 if(falling<.5){ALBEDO=vec3(.47,.67,.60); ALPHA=.28+.15*ripple;}
 ROUGHNESS=.47; SPECULAR=.25;
}
"""
		var mat=ShaderMaterial.new(); mat.shader=shader; mat.set_shader_parameter("falling",1. if kind=="waterfall" else 0.); return mat
	if kind=="stone":
		var shader=Shader.new(); shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float grain=sin(p.x*59.+p.y*19.)*sin(p.z*47.+p.y*71.);
 float strata=sin((p.y+p.x*.23+p.z*.17)*16.+sin(p.x*3.)*.5);
 ALBEDO=vec3(.29,.32,.31)*(1.+grain*.06-smoothstep(.9,.99,strata)*.18);
 ROUGHNESS=.96;
}
"""
		var mat=ShaderMaterial.new(); mat.shader=shader; return mat
	if kind=="quilt":
		var shader=Shader.new(); shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 tile=fract(p.xz*5.);
 float seam=max(1.-smoothstep(.01,.06,tile.x),1.-smoothstep(.01,.06,tile.y));
 ALBEDO=mix(vec3(.20,.40,.32),vec3(.39,.57,.45),seam*.5);
 ROUGHNESS=1.;
}
"""
		var mat=ShaderMaterial.new(); mat.shader=shader; return mat
	if kind in ["door_left","door_right"]:
		var shader=Shader.new(); shader.code="""shader_type spatial;
uniform vec3 player=vec3(10000.);
uniform float side=1.;
void vertex(){
 vec3 origin=MODEL_MATRIX[3].xyz;
 float opened=1.-smoothstep(.7,1.9,distance(origin.xz,player.xz));
 VERTEX.x+=side*.38*opened/length(MODEL_MATRIX[0].xyz);
}
void fragment(){
 float frame=max(step(.92,UV.x),step(UV.x,.08));
 frame=max(frame,max(step(.95,UV.y),step(UV.y,.05)));
 ALBEDO=mix(vec3(.27,.49,.54),vec3(.60,.68,.65),frame);
 float reflection=1.-smoothstep(.025,.045,abs(UV.x*.45+UV.y-.7));
 ALBEDO+=vec3(.08)*reflection*(1.-frame); ROUGHNESS=.3; SPECULAR=.35;
}
"""
		var mat=ShaderMaterial.new(); mat.shader=shader; mat.set_shader_parameter("side",-1. if kind=="door_left" else 1.); return mat
	if kind=="foliage":
		var shader=Shader.new(); shader.code="""shader_type spatial;
render_mode cull_disabled;
void fragment(){ ALBEDO=COLOR.rgb; ROUGHNESS=.83; BACKLIGHT=COLOR.rgb*.13; }
"""
		var mat=ShaderMaterial.new(); mat.shader=shader; return mat
	if kind=="contact_shadow":
		var shader=Shader.new(); shader.code="""shader_type spatial;
render_mode unshaded,depth_draw_never,cull_disabled;
void fragment(){ float d=length((UV-.5)*2.); ALBEDO=vec3(.055,.09,.055); ALPHA=.25*pow(1.-smoothstep(.15,1.,d),1.6); }
"""
		var mat=ShaderMaterial.new(); mat.shader=shader; return mat
	if kind.begins_with("wood_") or kind.begins_with("roof_") or kind.begins_with("plaster_"):
		var shader=Shader.new(); shader.code="""shader_type spatial;
uniform vec4 tint:source_color;
uniform float wood=0.;
uniform float tile=0.;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float grain=sin(p.y*82.+sin(p.x*3.5+p.z*4.)*2.)*.035;
 float fleck=sin(p.x*123.+p.z*17.)*sin(p.y*93.+p.z*69.)*.012;
 float joint=(1.-smoothstep(.04,.12,UV.y))+smoothstep(.88,.96,UV.y);
 ALBEDO=tint.rgb*(1.+grain*wood+fleck)*(1.-joint*.22*tile); ROUGHNESS=.76;
}
"""
		var mat=ShaderMaterial.new(); mat.shader=shader
		mat.set_shader_parameter("tint",Color(kind.get_slice("_",1))); mat.set_shader_parameter("wood",1. if kind.begins_with("wood_") else 0.); mat.set_shader_parameter("tile",1. if kind.begins_with("roof_") else 0.); return mat
	if kind=="wallpaper":
		var shader=Shader.new(); shader.code="""shader_type spatial;
varying vec3 p; varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz; n=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){float stripes=smoothstep(.38,.44,fract((p.x+p.z)*4.)); ALBEDO=mix(vec3(.38,.52,.53),vec3(.52,.64,.63),stripes); if(abs(n.y)>.7){ALBEDO=vec3(.42,.32,.20);} ROUGHNESS=.95;}
"""
		var mat=ShaderMaterial.new(); mat.shader=shader; return mat
	if kind=="tablecloth":
		var shader=Shader.new(); shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){ float check=mod(floor(p.x*6.)+floor(p.z*6.),2.); ALBEDO=mix(vec3(.34,.51,.52),vec3(.65,.72,.65),check); ROUGHNESS=1.;}
"""
		var mat=ShaderMaterial.new(); mat.shader=shader; return mat
	return null

func ground(texture: Texture2D) -> Material:
	var shader=Shader.new(); shader.code="""shader_type spatial;
uniform sampler2D flooring:source_color,filter_linear_mipmap;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec3 base=texture(flooring,UV).rgb;
 float wood=step(base.g*1.09,base.r)*step(base.b*1.4,base.r);
 float grain=sin(p.z*180.+sin(p.x*2.+p.z*.3)*4.)*.025;
 ALBEDO=base*(1.+grain*wood); ROUGHNESS=mix(.92,.56,wood); SPECULAR=.22;
}
"""
	var mat=ShaderMaterial.new(); mat.shader=shader; mat.set_shader_parameter("flooring",texture); return mat
