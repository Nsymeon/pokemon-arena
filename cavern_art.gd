extends RefCounted

# Original procedural scenery inspired by the supplied cave battle reference.
var slabs: Array = []
var stones: Array = []
var cracks: Array = []
var bounds = Vector2.ZERO

func build(size: Vector2):
	if bounds == size: return
	bounds = size
	slabs.clear()
	stones.clear()
	cracks.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = 31847
	var columns = int(size.x / 100)
	var rows = int(size.y / 100)
	var vertices: Array = []
	for y in range(rows + 1):
		var row: Array = []
		for x in range(columns + 1):
			row.append(Vector2(x*100 + rng.randf_range(-32,32),y*100 + rng.randf_range(-30,30)).clamp(Vector2.ZERO,size))
		vertices.append(row)
	for y in range(rows):
		for x in range(columns):
			var points = PackedVector2Array([vertices[y][x],vertices[y][x+1],vertices[y+1][x+1],vertices[y+1][x]])
			var center = (points[0]+points[1]+points[2]+points[3])/4
			slabs.append({"points":points,"pos":center,"shade":rng.randf_range(0.0,0.11)})
			if rng.randf() < 0.38:
				var start = center + Vector2(rng.randf_range(-28,28),rng.randf_range(-20,20))
				var turn = rng.randf_range(0,TAU)
				var length = rng.randf_range(0.4,1.4)
				cracks.append(PackedVector2Array([start,start+Vector2(16,-11).rotated(turn)*length,start+Vector2(23,-34).rotated(turn)*length,start+Vector2(41,-42).rotated(turn)*length]))
	for i in range(360):
		stones.append({"pos":Vector2(rng.randf_range(45,size.x-45),rng.randf_range(45,size.y-45)),"size":rng.randf_range(1,4),"shade":rng.randf_range(0,0.15)})

func draw(c):
	build(c.FIELD.size)
	var visible = Rect2(c.camera_offset,Vector2(1200,600)/c.ARENA_SCALE).grow(150)
	c.draw_rect(c.FIELD,Color("242235"))
	for slab in slabs:
		if not visible.has_point(slab.pos): continue
		c.draw_colored_polygon(slab.points,Color("39364e").lightened(slab.shade))
		var outline: PackedVector2Array = slab.points.duplicate()
		outline.append(outline[0])
		c.draw_polyline(outline,Color(0.09,0.08,0.16,0.28),1.5,true)
		c.draw_line(outline[0]+Vector2(0,2),outline[1]+Vector2(0,2),Color(0.55,0.49,0.67,0.12),2,true)
		# Subtle mineral facets break up the flat fill without competing with telegraphs.
		c.draw_colored_polygon(PackedVector2Array([outline[0],outline[1],slab.pos]),Color(0.6,0.51,0.7,0.025))
		for i in range(6):
			var grain: Vector2 = slab.pos + Vector2(sin(slab.pos.x+i*13)*31,cos(slab.pos.y+i*7)*27)
			c.draw_line(grain,grain+Vector2(3+i%3,0),Color(0.66,0.6,0.76,0.10),1)
	for crack in cracks:
		if visible.has_point(crack[0]):
			c.draw_polyline(crack,Color("201e30"),2,true)
			c.draw_line(crack[1],crack[1]+Vector2(-13,-9),Color("252235"),2)
	for stone in stones:
		if visible.has_point(stone.pos):
			c.draw_ellipse(stone.pos,Vector2(stone.size*1.7,stone.size),Color("222030"))
			c.draw_line(stone.pos,stone.pos+Vector2(stone.size,0),Color("71677e").darkened(stone.shade),1)
	# Low, engraved central battle seal; keep its contrast below the effects.
	var center = c.FIELD.get_center()
	for radius in [106,112,146]: c.draw_arc(center,radius,0,TAU,64,Color(0.62,0.55,0.76,0.12),2,true)
	c.draw_line(center-Vector2(110,0),center+Vector2(110,0),Color(0.62,0.55,0.76,0.12),4)
	c.draw_arc(center,24,0,TAU,32,Color(0.62,0.55,0.76,0.17),4,true)
	for side in range(4):
		var horizontal = side < 2
		var length: float = bounds.x if horizontal else bounds.y
		var edge: float = 22 if side%2 == 0 else (bounds.y-22 if horizontal else bounds.x-22)
		for i in range(int(length/60)+1):
			var p = Vector2(i*60,edge) if horizontal else Vector2(edge,i*60)
			if not visible.has_point(p): continue
			var rock = PackedVector2Array([p+Vector2(-38,-16),p+Vector2(-15,-38),p+Vector2(24,-31),p+Vector2(43,4),p+Vector2(20,27),p+Vector2(-30,30)])
			c.draw_colored_polygon(rock,Color("29243e").lightened((i%4)*0.035))
			c.draw_line(rock[0],rock[1],Color("655578"),3)
			c.draw_line(rock[1],rock[2],Color("655578"),3)
		var line = PackedVector2Array()
		for i in range(int(length/24)+1):
			var inward = 48 if side%2 == 0 else -48
			var offset = sin(i*2.4)*4 + sin(i*0.7)*3
			line.append(Vector2(i*24,edge+inward+offset) if horizontal else Vector2(edge+inward+offset,i*24))
		for width in [24,12,4]: c.draw_polyline(line,Color(0.25,0.7,1,0.08 if width>4 else 0.55+sin(c.clock_time*2)*0.08),width,true)
	# Crystal clusters anchor the boundary and provide cyan/purple light pools.
	for x in [105,bounds.x-105]:
		for y in [130,330,bounds.y-330,bounds.y-130]:
			var p = Vector2(x,y)
			if not visible.has_point(p): continue
			for radius in [48,32,18]: c.draw_circle(p,radius,Color(0.33,0.55,1,0.035))
			for i in range(3):
				var base = p + Vector2((i-1)*14,i%2*6)
				var height = 24 + i%2*17
				c.draw_colored_polygon(PackedVector2Array([base-Vector2(7,0),base-Vector2(8,height*0.65),base-Vector2(0,height),base+Vector2(7,-height*0.6),base+Vector2(6,0)]),Color("6889c1"))
				c.draw_line(base,base-Vector2(0,height-3),Color("b4edff"),2)
	for friendly in [true,false]:
		var p: Vector2 = c.trainer_position(friendly)
		c.draw_ellipse(p+Vector2(0,10),Vector2(48,26),Color("242335"))
		c.draw_arc(p+Vector2(0,10),44,0,TAU,40,Color(0.52,0.7,1,0.25),2,true)
	for mark in c.scars:
		c.draw_ellipse(mark.pos,Vector2(28,15)*mark.size,Color(0.05,0.04,0.09,minf(0.6,mark.life*0.05)))
		for i in range(5):
			var direction = Vector2.from_angle(i*TAU/5+mark.size)
			c.draw_line(mark.pos+direction*10,mark.pos+direction*42*mark.size,Color(0.08,0.06,0.13,minf(0.8,mark.life*0.08)),2)
	# Ambient dust, independent of weather and combat random-number state.
	for i in range(35):
		var p = Vector2(fposmod(i*137.7+c.clock_time*5,bounds.x),fposmod(i*91.3-c.clock_time*9,bounds.y))
		if visible.has_point(p): c.draw_circle(p,1.3,Color(0.7,0.65,0.92,0.15+sin(c.clock_time+i)*0.08))
