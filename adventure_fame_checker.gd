extends RefCounted
var a
var book: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/fame-checker.json"))

func owns() -> bool:
	# Existing saves which already defeated Cerulean's rival receive his omitted gift.
	return a.field.done("field:famechecker") or a.field.done("source:FLAG_GOT_FAME_CHECKER") or a.Story.state(a).get("bridge_blue",false)

func known(person,index) -> bool:
	return a.field.done("source:FAME:"+person+":"+str(index))

func count(person) -> int:
	var total=0
	for i in 6:
		if known(person,i): total+=1
	return total

func text(value: String) -> String:
	return value.replace("{PLAYER}",str(a.data.get("player_name","RED"))).replace("{RIVAL}","BLUE")

func menu():
	if not owns() or a.in_battle: return
	var list=a.inventory.page("FAME CHECKER / people and discoveries",a.field.key_items)
	a.inventory.row(list,"Talk to people and inspect signs and journals to collect their stories.",func():pass,true)
	for person in book:
		var n=count(person)
		a.inventory.row(list,(text(book[person].name) if n>0 else "???")+" / "+str(n)+" of 6 facts",person_page.bind(person),n==0)

func paragraph(list,value):
	var label=Label.new(); label.text=text(value); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",21); list.add_child(label)

func person_page(person):
	if not owns() or person not in book or count(person)==0: return
	var list=a.inventory.page("FAME CHECKER / "+text(book[person].name),menu)
	for i in 6:
		paragraph(list,str(i+1)+". "+(book[person].facts[i] if known(person,i) else "No information discovered yet."))
	if count(person)==6: paragraph(list,"A MESSAGE FOR YOU\n\n"+book[person].quote)
