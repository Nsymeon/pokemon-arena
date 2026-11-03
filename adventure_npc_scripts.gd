extends RefCounted
# Services complement the existing story, trades, tutors and Oak's aides.
var a

func npc(object: Dictionary) -> bool:
	var script=str(object.get("script",""))
	if script=="PalletTown_RivalsHouse_EventScript_Daisy": daisy(); return true
	if script=="FiveIsland_WaterLabyrinth_EventScript_EggGentleman": togepi_egg(); return true
	if "NameRater" in script:
		var list=a.inventory.page("NAME RATER / Which Pokemon's nickname shall I rate?")
		for i in a.data.party.size():
			var mon=a.data.party[i]
			a.inventory.row(list,a.collection.title(mon),a.collection.rename.bind("party",i),mon.get("is_egg",false) or str(mon.get("ot","player")).begins_with("npc:"))
		return true
	if "MagikarpSalesman" in script:
		if a.field.done("gift:magikarp_sale"): a.show_dialogue("I don't give refunds!"); return true
		var list=a.inventory.page("A MAGIKARP / $500")
		a.inventory.row(list,"BUY MAGIKARP / Lv.5",buy_magikarp,a.data.money<500 or (a.data.party.size()>=6 and a.data.storage.size()>=100))
		return true
	if "PokemonCenter" in script and ("Jigglypuff" in script or "Chansey" in script):
		a.c.audio.cry(39 if "Jigglypuff" in script else 113); a.show_dialogue(a.world.scenes.npc_text(object)); return true
	if object.has("battle"): return false
	var record=a.world.scenes.dialogue.get(script,{})
	if not record.has("gift"): return false
	var gift=record.gift; var raw=str(gift.item); var item=raw.to_lower().replace("_","")
	var tm=raw.begins_with("TM") and a.inventory.book.tms.has(raw)
	if not tm and not a.inventory.ITEMS.has(item): return false
	var key="npc_gift:"+script
	if a.field.done(key): a.show_dialogue(a.world.scenes.npc_text(object)); return true
	var inventory=a.data.tms if tm else a.data.bag; var id=raw if tm else item
	if int(inventory.get(id,0))+int(gift.amount)>999: a.show_dialogue("There's no room for this item in your Bag."); return true
	inventory[id]=int(inventory.get(id,0))+int(gift.amount)
	a.field.finish(key)
	if gift.has("flag"): a.field.finish("source:"+str(gift.flag))
	a.show_dialogue(str(record.get("text",""))+"\n\nReceived "+(a.inventory.book.tms[id].name if tm else a.inventory.ITEMS[id].name)+"!")
	a.save(); return true

func buy_magikarp():
	if a.in_battle or a.data.money<500 or a.field.done("gift:magikarp_sale") or (a.data.party.size()>=6 and a.data.storage.size()>=100): return
	a.data.money-=500
	var mon=a.new_mon(129,5)
	if a.data.party.size()<6: a.data.party.append(mon)
	else: a.data.storage.append(mon)
	a.field.finish("gift:magikarp_sale"); a.clear_ui(); a.show_dialogue("You paid $500 and received MAGIKARP!"); a.save()

func togepi_egg():
	if a.field.done("gift:togepi_egg"): a.show_dialogue("I'm glad I met someone like you. Take good care of that little Pokemon!"); return
	if a.data.party.is_empty() or a.data.party[0].get("is_egg",false) or int(a.data.party[0].get("friendship",70))<250:
		a.show_dialogue("Let me take a look at your Pokemon... Come back when your first partner trusts you completely."); return
	if a.data.party.size()>=6: a.show_dialogue("You don't have space in your party. Make room for an Egg and come back."); return
	var egg=a.new_mon(175,5); egg["is_egg"]=true; egg["egg_steps"]=(int(a.breeding.book["175"].cycles)+1)*256; egg.hp=0.; egg.friendship=120
	a.data.party.append(egg); a.field.finish("gift:togepi_egg"); a.save(); a.show_dialogue("You treat your Pokemon right. Please take this Egg!\n\nReceived an Egg from the Gentleman!")

func daisy():
	if not a.field.done("parcel_delivered"): a.show_dialogue("DAISY: Hi! My brother BLUE is out at Grandpa's lab."); return
	if not a.field.done("town_map"):
		a.field.finish("town_map"); a.save(); a.show_dialogue("DAISY: Grandpa asked you to run an errand? Here, this will help you!\n\nReceived the TOWN MAP! Open it from BAG / KEY ITEMS."); return
	if not a.Finale.has(a,"champion"): a.show_dialogue("DAISY: Pokemon are living things! If they get tired, please give them a rest."); return
	var list=a.inventory.page("DAISY / GROOMING")
	var cooldown=int(a.services.state().steps)-int(a.data.get("daisy_step",-500))
	for i in a.data.party.size():
		var mon=a.data.party[i]
		a.inventory.row(list,a.collection.title(mon)+" / Friendship "+str(mon.get("friendship",70)),groom.bind(i),mon.get("is_egg",false) or cooldown<500)
	if cooldown<500: a.inventory.row(list,"Come back after another "+str(500-cooldown)+" walking steps.",func():pass,true)

func groom(slot):
	if a.in_battle or slot<0 or slot>=a.data.party.size() or not a.Finale.has(a,"champion"): return
	var mon=a.data.party[slot]
	if mon.get("is_egg",false) or int(a.services.state().steps)-int(a.data.get("daisy_step",-500))<500: return
	mon.friendship=mini(255,int(mon.get("friendship",70))+3); a.data["daisy_step"]=int(a.services.state().steps)
	a.clear_ui(); a.world.scenes.play([{"text":"DAISY: Your Pokemon will look nice in no time!","duration":2.,"flash":true},{"text":"DAISY: There you go! All done!","duration":2.}],a.save)
