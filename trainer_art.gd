extends RefCounted

# Original FRLG files stay unchanged; see assets/trainers/sources.json.
const HANDS = {"leaf":Vector2(15,34),"red":Vector2(23,27),"blue":Vector2(29,37),"brock":Vector2(28,38),"misty":Vector2(54,41),"surge":Vector2(26,30),"erika":Vector2(24,44),"koga":Vector2(32,64),"sabrina":Vector2(26,32),"blaine":Vector2(22,16),"giovanni":Vector2(26,34),"lorelei":Vector2(25,32),"bruno":Vector2(20,45),"agatha":Vector2(28,39),"lance":Vector2(15,24)}
var sprites = {}

func _init():
	for id in HANDS:
		var pixels = Image.load_from_file("res://assets/avatar/girl-battle.png" if id=="leaf" else "res://assets/trainers/"+id+".png")
		if pixels == null or pixels.is_empty():
			push_error("Missing trainer sprite: "+id)
			continue
		var used = pixels.get_used_rect()
		var scale = 110.0 / used.size.y
		var original = ImageTexture.create_from_image(pixels)
		pixels.flip_x()
		sprites[id] = {"left":original,"right":ImageTexture.create_from_image(pixels),"scale":scale,"bottom":float(used.end.y),"size":original.get_size()}

func key(identity: String) -> String:
	var id = identity.split("_")[0]
	return id if sprites.has(id) else "blue"

func hand_offset(identity: String, facing: float) -> Vector2:
	var id = key(identity)
	var sprite = sprites[id]
	var point: Vector2 = HANDS[id]
	return Vector2((point.x-sprite.size.x/2)*-facing,point.y-sprite.bottom)*sprite.scale

func pose_shift(lift: float) -> Vector2:
	return Vector2(0,-lift*0.16)

func draw(c, feet: Vector2, identity: String, facing: float, hand: Vector2, ball: bool = true):
	var id = key(identity)
	var sprite = sprites[id]
	var size: Vector2 = sprite.size*sprite.scale
	var shift = hand-(feet+hand_offset(identity,facing))
	var pos = feet+Vector2(-size.x/2,-sprite.bottom*sprite.scale)+shift
	c.draw_ellipse(feet+Vector2(0,3),Vector2(23,7),Color(0.04,0.04,0.08,0.35))
	var texture = sprite.right if facing>0 else sprite.left
	if identity in ["red","leaf"] and c.adventure.in_battle and c.adventure.data.has("avatar"):
		texture = c.adventure.avatar.texture(c.adventure.avatar.config(),true,facing>0)
	c.draw_texture_rect(texture,Rect2(pos,size),false)
	if ball: c.draw_pokeball(hand,4.2)

