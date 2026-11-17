extends Control
var a
var book: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/game-corner.json"))
var indices=[0,0,0]
var spinning=[false,false,false]
var bet=0
var paid=true
var clock=0.
var result="Choose a bet: 1 center line / 2 all horizontal / 3 also diagonals"
var stops=[]
var bets=[]
var caption
func _ready():
	for i in 3:
		var button=Button.new(); button.position=Vector2(175+i*210,260); button.size=Vector2(180,42)
		button.text="STOP "+str(i+1); button.pressed.connect(stop.bind(i)); add_child(button); stops.append(button)
		var wager=Button.new(); wager.position=Vector2(175+i*210,320); wager.size=Vector2(180,42)
		wager.text="BET "+str(i+1); wager.pressed.connect(start.bind(i+1)); add_child(wager); bets.append(wager)
	caption=Label.new(); caption.position=Vector2(25,370); caption.size=Vector2(825,70); caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; add_child(caption)
	refresh()
func start(amount):
	if a.in_battle or not paid or amount not in [1,2,3] or not a.field.done("coin_case") or a.services.state().coins<amount: return
	a.services.state().coins-=amount; a.save(); bet=amount; paid=false
	for i in 3: indices[i]=a.c.rng.randi_range(0,20); spinning[i]=true
	result="Stop each reel. Matching symbols pay on the active lines."; refresh()
func stop(i):
	if paid or i<0 or i>=3 or not spinning[i]: return
	spinning[i]=false
	if not spinning.any(func(v):return v):
		var won=payout(book,visible_icons(),bet)
		paid=true; a.services.state().coins=mini(9999,int(a.services.state().coins)+won); a.save()
		result="WON "+str(won)+" COINS!" if won>0 else "No winning line. Choose a bet to play again."
	refresh()
func visible_icons() -> Array:
	var icons=[]
	for reel in 3:
		for row in 3: icons.append(book.reels[reel][(indices[reel]+row+1)%21])
	return icons
static func payout(data,icons,amount) -> int:
	var total=0
	for line in data.lines:
		if amount<int(line[3]): continue
		var first=icons[int(line[0])]; var second=icons[int(line[1])]; var third=icons[int(line[2])]
		if first=="CHERRIES": total+=6 if second=="CHERRIES" else 2
		elif first==second and second==third: total+=int(data.payouts.get(first,0))
	return total
func refresh():
	if caption==null: return
	caption.text=result+"\nCOINS: "+str(a.services.state().coins)
	for i in 3:
		stops[i].disabled=not spinning[i]; bets[i].disabled=not paid or a.services.state().coins<i+1
	queue_redraw()
func _process(dt):
	clock+=dt
	if clock<.085: return
	clock=0.
	for i in 3:
		if spinning[i]: indices[i]=(indices[i]+1)%21
	queue_redraw()
func _draw():
	draw_rect(Rect2(140,0,665,245),Color("102435"))
	var icons=visible_icons()
	for reel in 3:
		for row in 3:
			var rect=Rect2(165+reel*210,10+row*77,190,67)
			draw_rect(rect,Color("eadcc1")); draw_rect(rect,Color("ba985d"),false,2)
			var symbol=icons[reel*3+row]; var id={"PIKACHU":25,"PSYDUCK":54,"MAGNEMITE":81,"SHELLDER":90}.get(symbol,0)
			if id>0:
				var texture=a.c.portrait({"id":id})
				if texture:
					var dimensions=texture.get_size()*56./maxf(texture.get_width(),texture.get_height())
					draw_texture_rect(texture,Rect2(rect.get_center()-dimensions/2,dimensions),false)
			else: draw_string(ThemeDB.fallback_font,rect.position+Vector2(14,42),"7" if symbol=="7" else "R" if symbol=="ROCKET" else "CHERRIES",HORIZONTAL_ALIGNMENT_CENTER,162,26,Color("b33f54"))
	for line in book.lines:
		if bet<int(line[3]): continue
		var points=PackedVector2Array()
		for i in 3: points.append(Vector2(260+i*210,43+(int(line[i])%3)*77))
		draw_polyline(points,Color(1,.8,.3,.25),2,true)
