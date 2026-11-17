extends RefCounted
var a
const TITLES=["HOW TO BATTLE","STATUS PROBLEMS","TYPE MATCHUPS","CATCHING POKEMON","ABOUT TMs","KEY ITEMS AND CONTROLS"]

func owns() -> bool: return a.field.done("field:teachytv") or a.field.done("source:FLAG_GOT_TEACHY_TV")

func old_man() -> bool:
	if not a.field.done("parcel_delivered"): return false
	if owns(): menu(); return true
	show(3,true); return true

func trigger() -> bool:
	if a.world.current!="MAP_VIRIDIAN_CITY" or owns() or not a.field.done("parcel_delivered"): return false
	var cell=Vector2i(a.position_world/a.world.TILE)
	if cell.y!=8 or cell.x not in [20,22]: return false
	return old_man()

func menu():
	if not owns() or a.in_battle: return
	var list=a.inventory.page("TEACHY TV / POKe DUDE's lessons",a.field.key_items)
	for i in TITLES.size(): a.inventory.row(list,TITLES[i],show.bind(i))

func description(topic) -> String:
	var controls=a.c.controls
	return [
		"Choose one of your four moves, aim at the opponent and keep moving. Each attack has a shared recovery delay. Hold "+controls.text("battle_sprint")+" to sprint in battle; use the switch menu to change partners.",
		"Sleep prevents attacking for a short time. Paralysis slows a Pokemon and can interrupt a move. Poison and burn cause damage over time. Use the matching medicine or visit a Pokemon Center.",
		"Water attacks are strong against Fire. Fire attacks are strong against Grass. Grass attacks are strong against Water. Dual types combine their weaknesses and resistances; some types are immune.",
		"Weaken a wild Pokemon and try a Poke Ball from your Bag. Sleep or paralysis makes capture easier. The ball shakes before a successful catch. Trainer Pokemon cannot be caught. This demonstration uses no items or money.",
		"Open BAG / TM CASE, choose a machine and a compatible Pokemon, then select a move slot. Ordinary TMs are consumed only when learned. Fly and Surf can be taught repeatedly from Key Items.",
		"Open BAG / KEY ITEMS for permanent tools. Most field tools also require a Badge. Search grass, water and caves with "+controls.text("encounter")+". Talk with "+controls.text("interact")+". Change your bindings in OPTIONS."
	][topic]

func show(topic:int, old=false):
	if a.in_battle or topic<0 or topic>=TITLES.size() or (not old and not owns()): return
	var list=a.inventory.page(("OLD MAN / WATCH HOW IT'S DONE" if old else "TEACHY TV / "+TITLES[topic]),received if old else menu)
	var demo=preload("res://teachy_demo.gd").new(); demo.a=a; demo.topic=topic
	demo.custom_minimum_size=Vector2(875,250); list.add_child(demo)
	var label=Label.new(); label.text=description(topic); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size",23); list.add_child(label)
	a.inventory.row(list,"CONTINUE",received if old else menu)

func received():
	if a.in_battle: return
	a.field.finish("field:teachytv"); a.clear_ui(); a.save()
	a.show_dialogue("OLD MAN: That was educational, was it not? Take this, too!\n\nReceived the TEACHY TV! Watch it from BAG / KEY ITEMS whenever you need help.")
