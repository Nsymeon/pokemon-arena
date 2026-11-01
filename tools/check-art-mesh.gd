extends SceneTree
var failures=[]
func check(value: bool, description: String):
	if not value: failures.append(description)
func _initialize():
	var art=load("res://kanto_art_assets.gd").new()
	for kind in art.MESHES:
		var m=art.mesh(kind); var arrays=m.surface_get_arrays(0)
		var vertices=arrays[Mesh.ARRAY_VERTEX]; var normals=arrays[Mesh.ARRAY_NORMAL]
		check(m==art.mesh(kind),kind+" is cached")
		for i in vertices.size():
			check(vertices[i].is_finite() and normals[i].is_finite(),kind+" has finite geometry")
			if kind=="roof_shingle": check(normals[i].y>.4,"Shingle normals face upward")
			if kind=="cliff_face": check(normals[i].z>.8,"Cliff faces light from outside")
			if kind=="crown" and vertices[i].y>.02 and vertices[i].y<.95:
				check(Vector3(vertices[i].x,0,vertices[i].z).dot(normals[i])>=-.005,"Crown normals face outward")
		print("ART MESH ",kind," ",vertices.size()," vertices")
	print("ART GEOMETRY CHECK: ",failures.size()," failures ",failures.slice(0,5))
	quit(0 if failures.is_empty() else 1)
