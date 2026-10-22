extends RefCounted
# Stateless drawing: each effect uses its own move and age, never a shared timer.
const GROUPS = {
	"rain": "raindance",
	"sun": "sunnyday",
	"snow": "hail snowscape blizzard",
	"sand": "sandstorm sandattack sandtomb scorchingsands",
	"warp": "teleport allyswitch transform substitute doubleteam minimize",
	"aura": "aurasphere focusblast",
	"needle": "poisonsting pinmissile spikes toxicspikes spikecannon iciclespear twinneedle",
	"leaf": "razorleaf magicalleaf leafstorm leafage petalblizzard petaldance leafblade solarblade",
	"vine": "vinewhip powerwhip grassknot bind wrap constrict",
	"bubble": "bubble bubblebeam sparklingaria",
	"seed": "bulletseed seedbomb leechseed worryseed eggbomb barrage",
	"sound": "growl roar sing screech supersonic hypervoice round echoedvoice uproar snarl disarmingvoice boomburst perishsong metalsound healbell bugbuzz",
	"hypnosis": "hypnosis confusion psybeam psychic psystrike dreameater extrasensory futuresight storedpower synchronoise",
	"powder": "sleeppowder poisonpowder stunspore spore powder cottonspore powdersnow sweetscent",
	"web": "spiderweb stickyweb stringshot electroweb infestation",
	"heart": "attract charm sweetkiss drainingkiss lovelykiss playrough babydolleyes",
	"star": "swift wish healingwish meteorbeam meteormash cometpunch",
	"bite": "bite crunch firefang icefang thunderfang poisonfang psychicfangs hyperfang superfang bugbite leechlife",
	"claw": "scratch slash nightslash shadowclaw metalclaw dragonclaw furycutter xscissor crosspoison airslash aircutter cut furyswipes sacredsword razorshell",
	"wing": "wingattack steelwing dualwingbeat aerialace acrobatics peck drillpeck pluck bravebird",
	"spin": "rapidspin gyroball icespinner rollout iceball defensecurl steelroller darkestlariat",
	"eye": "leer meanlook glare scaryface foresight miracleeye lockon mindreader",
	"shield": "protect detect reflect lightscreen safeguard mist wideguard quickguard craftyshield matblock arena_guard",
	"heal": "recover roost rest synthesis moonlight morningsun softboiled slackoff lifedew healpulse",
}

var families = {}

func _init():
	for group in GROUPS:
		for id in GROUPS[group].split(" "): families[id] = group

func family(move: Dictionary) -> String:
	var id: String = move.get("id", "")
	if families.has(id): return families[id]
	if move.get("type", "") == "Grass" and move.get("kind", "") in ["orb", "bolt"] and id != "energyball": return "leaf"
	if "punch" in id: return "punch"
	if "kick" in id: return "kick"
	if "tail" in id: return "tail"
	if "dance" in id or move.get("kind", "") == "buff": return "boost"
	if move.get("kind", "") == "heal": return "heal"
	if move.get("kind", "") == "guard": return "shield"
	if move.get("kind", "") == "dash": return "body"
	return str(move.get("type", "Normal")).to_lower()

func stroke(c, points: PackedVector2Array, color: Color, width: float):
	if points.size() < 2: return
	c.draw_polyline(points, Color(color, color.a * 0.14), width + 9, true)
	c.draw_polyline(points, color, width, true)

func leaf(c, p: Vector2, angle: float, size: float, alpha: float):
	var d = Vector2.from_angle(angle)
	var n = d.orthogonal()
	var points = PackedVector2Array()
	for i in range(9):
		var t = i / 8.0
		points.append(p + d * (t * 2 - 1) * size + n * sin(t * PI) * size * (0.43 if i % 2 else 0.29))
	for i in range(8, -1, -1):
		var t = i / 8.0
		points.append(p + d * (t * 2 - 1) * size - n * sin(t * PI) * size * (0.43 if i % 2 else 0.29))
	c.draw_colored_polygon(points, Color("8fda49", alpha))
	c.draw_line(p-d*size, p+d*size, Color("e4ffa2", alpha), 1.5, true)
	for i in [-1, 0, 1]:
		for sign in [-1, 1]: c.draw_line(p+d*i*size*0.3, p+d*(i+0.6)*size*0.3+n*sign*size*0.25, Color("478a37",alpha),1,true)

func star(c, p: Vector2, radius: float, angle: float, color: Color):
	var points = PackedVector2Array()
	for i in range(10): points.append(p + Vector2.from_angle(angle+i*TAU/10) * radius * (1.0 if i%2==0 else 0.42))
	c.draw_colored_polygon(points, color)

func motif(c, group: String, p: Vector2, d: Vector2, t: float, r: float, color: Color):
	var n = d.orthogonal()
	match group:
		"leaf": leaf(c,p,d.angle()+t*9,r,color.a)
		"needle":
			c.draw_line(p-d*r*2,p,color,3,true)
			c.draw_colored_polygon(PackedVector2Array([p+d*r,p-d*r+n*r*0.25,p-d*r-n*r*0.25]),Color(color.lightened(0.5),color.a))
		"bite", "punch", "kick", "body", "tail", "spin", "vine":
			for i in range(5):
				var ray=Vector2.from_angle(i*TAU/5+t)
				c.draw_line(p+ray*r*0.4,p+ray*r,color,2,true)
			star(c,p,r*0.55,t,Color("fff9dd",color.a))
		"bubble":
			c.draw_circle(p,r,Color("57bcec",color.a*0.18))
			c.draw_arc(p,r,0,TAU,24,Color("90e4ff",color.a),2,true)
			c.draw_arc(p,r*0.78,3.6,5.0,12,Color("ffffff",color.a),2,true)
		"star": star(c,p,r,t*5,Color("ffef9c",color.a))
		"normal", "fighting":
			for i in range(3):
				c.draw_arc(p-d*i*9,r+i*4,d.angle()-1.1,d.angle()+1.1,20,Color(color,color.a*(1-i*0.2)),3,true)
			c.draw_line(p-d*r*2,p,Color(Color.WHITE,color.a),2,true)
		"fairy":
			star(c,p,r,t*3,Color("ffe1f4",color.a))
			for i in range(4): star(c,p+Vector2.from_angle(i*TAU/4+t*3)*r*1.8,r*0.3,-t,Color(color,color.a*0.7))
		"bug":
			for i in range(3):
				var q=p-d*i*13
				c.draw_colored_polygon(PackedVector2Array([q+d*r,q-d*r+n*r*0.3,q-d*r-n*r*0.3]),Color("dcf18a",color.a))
		"dragon":
			var points = PackedVector2Array()
			for i in range(17): points.append(p-d*i*5+n*sin(i*0.6-t*16)*r*0.55)
			stroke(c,points,Color("8974fa",color.a),8)
			c.draw_polyline(points,Color("bff6ff",color.a),2,true)
			c.draw_colored_polygon(PackedVector2Array([p+d*r,p+n*r*0.7,p-d*r*0.3,p-n*r*0.7]),Color("c6c5ff",color.a))
		"heart":
			var points = PackedVector2Array()
			for i in range(40):
				var a = i*TAU/40
				points.append(p+Vector2(16*pow(sin(a),3),-(13*cos(a)-5*cos(2*a)-2*cos(3*a)-cos(4*a)))*r/18)
			c.draw_colored_polygon(points,Color("ff8db9",color.a))
		"ice", "rock", "ground", "steel", "seed":
			var points = PackedVector2Array()
			for i in range(6): points.append(p+Vector2.from_angle(i*TAU/6+t*3)*r*(1.5 if group=="ice" and i%3==0 else 0.85))
			c.draw_colored_polygon(points,color.darkened(0.15))
			c.draw_colored_polygon(PackedVector2Array([p,points[0],points[1],points[2]]),color.lightened(0.4))
			c.draw_line(points[0],points[3],Color(Color.WHITE,color.a*0.65),1.5,true)
		"fire":
			for i in range(6,0,-1): c.draw_circle(p-d*i*r*0.45+n*sin(t*24-i)*r*0.3,r*(1-i/7.0),Color("f65c26",color.a*(1-i/8.0)))
			c.draw_circle(p,r*0.8,Color("ffae36",color.a))
			c.draw_circle(p+d*r*0.2,r*0.4,Color("fff1ab",color.a))
		"water":
			stroke(c,PackedVector2Array([p-d*r*3,p-d*r,p]),Color("42a9ec",color.a),r)
			c.draw_line(p-d*r*2,p,Color("c8faff",color.a),r*0.3,true)
			c.draw_circle(p,r*0.6,Color("a8efff",color.a))
		"electric":
			var points = PackedVector2Array()
			for i in range(9): points.append(p+d*(i-4)*r*0.6+n*sin(i*13+floor(t*25))*r*0.7)
			stroke(c,points,color,4)
			c.draw_polyline(points,Color("fffce4",color.a),1.5,true)
		"aura":
			c.draw_circle(p,r*1.5,Color("6acfff",color.a*0.15))
			c.draw_circle(p,r,Color("39a5de",color.a))
			c.draw_circle(p,r*0.6,Color("d9ffff",color.a))
			for i in range(3): c.draw_arc(p,r+i*3,t*12+i*2,t*12+i*2+2,18,Color("9defff",color.a),2,true)
		"sound":
			for i in range(3): c.draw_arc(p-d*i*12,r+i*7,d.angle()-1.25,d.angle()+1.25,24,Color(color,color.a*(1-i*0.22)),2,true)
			var q=p+n*r*1.4
			c.draw_circle(q,3,color)
			c.draw_line(q,q-Vector2(0,12),color,2,true)
			c.draw_line(q-Vector2(0,12),q+Vector2(6,-9),color,2,true)
		"hypnosis", "psychic":
			for i in range(3): c.draw_arc(p-d*i*12,r+i*7,d.angle()-1.25,d.angle()+1.25,24,Color(color,color.a*(1-i*0.22)),2,true)
		"rain":
			for i in range(6):
				var q=p+Vector2((i%3-1)*r,(i/3.0-1)*r+fposmod(t*60,15))
				c.draw_line(q-Vector2(-3,10),q,Color("9bdfff",color.a),2,true)
		"sun":
			c.draw_circle(p,r*0.6,Color("ffe887",color.a))
			for i in range(8):
				var ray=Vector2.from_angle(i*TAU/8+t)
				c.draw_line(p+ray*r*0.8,p+ray*r*1.3,Color("ffcf65",color.a),2,true)
		"snow":
			for i in range(6):
				var ray=Vector2.from_angle(i*TAU/6+t)
				c.draw_line(p,p+ray*r,Color("c9f5ff",color.a),2,true)
				c.draw_line(p+ray*r*0.6,p+ray*r*0.8+ray.orthogonal()*r*0.2,Color("c9f5ff",color.a),1,true)
		"sand":
			for i in range(9): c.draw_circle(p+Vector2(sin(i*3+t*6)*r,cos(i*7+t*3)*r),2+i%3,Color("cfb07e",color.a*0.7))
		"warp":
			for i in range(3): c.draw_arc(p+Vector2(0,(i-1)*r),r*(1.2-i*0.15),0,TAU,28,Color(color,color.a*(1-i*0.2)),2,true)
		"web":
			for i in range(8):
				var ray = Vector2.from_angle(i*TAU/8)
				c.draw_line(p,p+ray*r,color,1.5,true)
				for k in [0.4,0.7,1.0]: c.draw_line(p+ray*r*k,p+ray.rotated(TAU/8)*r*k,color,1,true)
		"flying", "wing", "claw":
			for i in range(3): c.draw_arc(p+n*(i-1)*10,r+i*4,d.angle()-1.2+t,d.angle()+0.8+t,22,color,2.5,true)
		"poison", "powder":
			for i in range(7):
				var q = p+Vector2.from_angle(i*2.4+t)*r*0.65
				c.draw_circle(q,r*0.45,Color(color,color.a*0.25))
				c.draw_circle(q,2.5,Color(color.lightened(0.4),color.a))
		_:
			c.draw_circle(p,r*1.5,Color(color,color.a*0.12))
			c.draw_circle(p,r,Color("302540",color.a) if group in ["ghost","dark"] else color.darkened(0.3))
			for i in range(3): c.draw_arc(p,r+i*3,t*8+i*2,t*8+i*2+PI,20,Color(color.lightened(0.5),color.a),2,true)
			c.draw_circle(p-d*r*0.25,r*0.25,Color(Color.WHITE,color.a*0.9))

func shot(c, s):
	var group = family(s.move)
	var d: Vector2 = s.vel.normalized()
	var p: Vector2 = s.pos-Vector2(0,42)
	var color: Color = s.color
	var id: String = s.move.get("id", "")
	if id == "fireblast":
		# The anime's five-stroke fire figure (大), not a spinning star.
		for line in [[Vector2(-28,-14),Vector2(28,-14)],[Vector2(0,-38),Vector2(0,-6)],[Vector2(0,-6),Vector2(-29,34)],[Vector2(0,-6),Vector2(30,34)]]:
			stroke(c,PackedVector2Array([p+line[0],p+line[1]]),Color("ff7625"),13)
			c.draw_line(p+line[0],p+line[1],Color("fff2a3"),4,true)
		return
	var count = 5 if group in ["leaf","bubble","powder","seed"] else 3
	for i in range(count-1,-1,-1):
		var spread = sin(s.age*12+i*2.4)* (14 if group in ["leaf","bubble"] else 5)
		var point = p-d*i*17+d.orthogonal()*spread
		var radius: float = clampf(s.radius+4,8,23)*(1-i*0.12)
		motif(c,group,point,d,s.age+i*0.17,radius,Color(color,1-i*0.19))
		if group == "leaf": c.draw_arc(point,radius+5,s.age*15+i,s.age*15+i+2,14,Color("ddffa1",0.4),1.5,true)

func cast(c, fighter):
	var move: Dictionary = fighter.get("last_move",{})
	var group = family(move)
	var t: float = clampf(1-fighter.attack_time/0.55,0,1)
	var p: Vector2 = fighter.pos+Vector2(0,-30)
	var d: Vector2 = fighter.get("attack_heading",Vector2.RIGHT)
	var n = d.orthogonal()
	var color = Color(fighter.get("move_color",Color.WHITE),sin(t*PI))
	var reach = sin(t*PI)*65
	match group:
		"vine":
			for sign in [-1,1]:
				var points = PackedVector2Array()
				for i in range(21):
					var u = i/20.0
					points.append(p+d*u*reach*1.8+n*sign*(14+sin(u*PI)*28*(1-t)))
				stroke(c,points,Color("4a994c",color.a),5)
				c.draw_polyline(points,Color("b4e582",color.a),1.5,true)
		"bite":
			var center = p+d*40
			for sign in [-1,1]:
				for i in range(5):
					var q = center+d*(i-2)*12+n*sign*(30*(1-t)+7)
					c.draw_colored_polygon(PackedVector2Array([q-d*5,q+d*5,q-n*sign*13]),Color("fff8e4",color.a))
				c.draw_line(center-d*30+n*sign*(30*(1-t)+8),center+d*30+n*sign*(30*(1-t)+8),color,4,true)
		"punch":
			var q = p+d*reach
			stroke(c,PackedVector2Array([p-d*12,q]),Color(color,color.a*0.45),12)
			for i in range(4): c.draw_circle(q+n*(i-1.5)*7,6,Color("fff0d9",color.a))
			c.draw_arc(q,23,d.angle()-1.7,d.angle()+1.7,24,color,3,true)
		"kick":
			var q = p+d*reach
			stroke(c,PackedVector2Array([p-d*12,p+d*reach*0.5-n*15,q]),color,8)
			c.draw_line(q-n*12,q+n*17,Color("fff0d9",color.a),10,true)
			c.draw_arc(q,25,d.angle()-1.5,d.angle()+1.5,24,color,2,true)
		"tail", "claw", "wing", "body", "spin":
			motif(c,"claw",p+d*22,d,t,35+reach*0.3,color)
			if group=="body": stroke(c,PackedVector2Array([p-d*55,p-d*20]),color,5)
		"shield":
			var points = PackedVector2Array()
			for i in range(7): points.append(p+Vector2.from_angle(i*TAU/6-PI/2)*57)
			c.draw_colored_polygon(points,Color(color,color.a*0.12))
			stroke(c,points,color,2)
			c.draw_arc(p,43,0,TAU,32,Color("e2ffff",color.a*0.5),1,true)
		"heal", "boost":
			for i in range(9):
				var q = p+Vector2(sin(i*2.4)*44,30-t*85+i%3*14)
				star(c,q,5+sin(t*PI)*3,t,Color("afffcb" if group=="heal" else "ffe89c",color.a))
			c.draw_arc(p+Vector2(0,25),40+t*15,0,TAU,32,Color(color,color.a*0.5),2,true)
		"eye":
			for sign in [-1,1]:
				var q=p+n*sign*14+d*24
				c.draw_arc(q,12,d.angle()-1.4,d.angle()+1.4,16,color,3,true)
				c.draw_circle(q,4,Color("ffefb9",color.a))
		_:
			if move.get("kind", "") in ["bolt","orb"]:
				motif(c,group,p+d*26,d,t,9+sin(t*PI)*8,Color(color,color.a*0.6))
			else:
				for i in range(5):
					var ray = Vector2.from_angle(i*TAU/5+t)
					motif(c,group,p+ray*(25+t*45),ray,t,10,color)

func impact(c, effect):
	var move: Dictionary = effect.get("move",{})
	if move.is_empty(): return
	var group = family(move)
	var t: float = effect.age/0.65
	var color = Color(preload("res://roster.gd").color(move.get("type","Normal")),(1-t)*0.8)
	for i in range(5):
		var d = Vector2.from_angle(i*TAU/5+0.4)
		motif(c,group,effect.pos+d*(14+t*48),d,t,8*(1-t)+2,color)
