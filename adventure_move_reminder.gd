extends RefCounted
var a
const PAYMENTS={"bigmushroom":1,"tinymushroom":2}

func menu():
	var list=a.inventory.page("MOVE MANIAC / Two Island")
	a.inventory.row(list,"One Big Mushroom or two Tiny Mushrooms per remembered move.",func():pass,true)
	for item in PAYMENTS:
		a.inventory.row(list,"PAY "+str(PAYMENTS[item])+" "+item.trim_suffix("mushroom").to_upper()+" MUSHROOM(S)",partners.bind(item),int(a.data.bag.get(item,0))<PAYMENTS[item])

func partners(item):
	var list=a.inventory.page("MOVE MANIAC / choose a partner",menu)
	for i in a.data.party.size(): a.inventory.row(list,a.collection.title(a.data.party[i]),moves.bind(i,item),a.data.party[i].get("is_egg",false))

func available(mon):
	return a.inventory.eligible(mon.id,mon.level).filter(func(id):return id not in mon.moves)

func moves(slot,item):
	if slot<0 or slot>=a.data.party.size(): return
	var list=a.inventory.page("REMEMBER A MOVE / "+a.collection.title(a.data.party[slot]),partners.bind(item))
	for id in available(a.data.party[slot]): a.inventory.row(list,a.inventory.book.moves[id].name,replace.bind(slot,id,item))
	if available(a.data.party[slot]).is_empty(): a.inventory.row(list,"This Pokemon has no forgotten level-up moves.",func():pass,true)

func replace(slot,id,item):
	var list=a.inventory.page("LEARN "+a.inventory.book.moves[id].name+" / choose a slot",moves.bind(slot,item))
	var mon=a.data.party[slot]
	for i in mon.moves.size(): a.inventory.row(list,"REPLACE "+a.inventory.book.moves[mon.moves[i]].name,learn.bind(slot,id,i,item))
	if mon.moves.size()<4: a.inventory.row(list,"USE EMPTY SLOT",learn.bind(slot,id,mon.moves.size(),item))

func learn(slot,id,index,item) -> bool:
	if a.in_battle or slot<0 or slot>=a.data.party.size() or not PAYMENTS.has(item): return false
	if int(a.data.bag.get(item,0))<PAYMENTS[item]: return false
	var mon=a.data.party[slot]
	if mon.get("is_egg",false) or id not in available(mon) or index<0 or index>mon.moves.size() or index>=4: return false
	var candidate=mon.duplicate(true)
	if index==candidate.moves.size(): candidate.moves.append(id)
	else: candidate.moves[index]=id
	if a.field.losing_surf(slot,candidate): return false
	# One save transaction: cancellation and invalid selections spend no mushrooms.
	mon.moves=candidate.moves; mon.pending.erase(id); a.data.bag[item]-=PAYMENTS[item]
	a.save(); moves(slot,item); return true
