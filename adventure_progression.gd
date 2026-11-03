extends RefCounted
# Story requirements shared by doors, NPCs, field encounters and the journal.
var a
const AIDES={
	"Route2_EastBuilding_EventScript_Aide":[10,"flash","Lantern / HM05 Flash"],
	"Route10_PokemonCenter_1F_EventScript_Aide":[20,"everstone","Everstone"],
	"Route11_EastEntrance_2F_EventScript_Aide":[30,"itemfinder","Itemfinder"],
	"Route16_NorthEntrance_2F_EventScript_Aide":[40,"amuletcoin","Amulet Coin"],
	"Route15_WestEntrance_2F_EventScript_Aide":[50,"expshare","Exp. Share"]}
var hall_scene
var source_parties: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/story-parties.json"))

func remember_heal():
	if a.world.enabled:
		a.data.heal_spot={"map":a.world.current,"x":a.position_world.x,"y":a.position_world.y}

func blackout_cost() -> int:
	var highest=1
	for mon in a.data.party: highest=maxi(highest,int(mon.level))
	return mini(int(a.data.money),highest*4*[2,4,6,9,12,16,20,25,30][a.Finale.badges(a)])

func recover() -> int:
	var loss=blackout_cost(); a.data.money-=loss
	a.Finale.state(a).league=0
	if a.encounter.get("kind","")=="rival": a.data.rival=true
	for mon in a.data.party: mon.hp=0. if mon.get("is_egg",false) else 1.; mon.ailment=""
	a.data.map=int(a.data.healing_map)
	a.position_world=Vector2(800,760)
	if a.world.enabled:
		var town=a.world.LEGACY[int(a.data.healing_map)]
		var room=a.world.names.get(town+"_PokemonCenter_1F","MAP_PALLET_TOWN_PLAYERS_HOUSE_1F")
		var spot=a.data.get("heal_spot",{"map":room,"x":6.5*48,"y":5.5*48})
		a.field.pending_static=""; a.field.riding=false
		a.services.state().safari=false
		a.world.enter(spot.map,Vector2(spot.x,spot.y))
	return loss

func battle_party(kind: String) -> Array:
	if not a.world.enabled: return []
	if kind.begins_with("late_league_") and kind.trim_prefix("late_league_").is_valid_int():
		return a.postgame.league_team(int(kind.trim_prefix("late_league_"))).map(func(mon):return [int(mon.id),int(mon.level)])
	if kind=="brock": return source_parties.LEADER_BROCK
	var chapter={"rival":"OAKS_LAB","world_Route22_EarlyRival":"ROUTE22_EARLY","bridge_blue":"CERULEAN","ship_blue":"SS_ANNE","story_tower_blue":"POKEMON_TOWER","late_silph_blue":"SILPH","late_league_rival":"ROUTE22_LATE"}.get(kind,"")
	if chapter=="": return []
	var starter={1:"CHARMANDER",4:"SQUIRTLE",7:"BULBASAUR"}.get(int(a.data.starter),"SQUIRTLE")
	return source_parties.get("RIVAL_"+chapter+"_"+starter,[])

func rival_done(kind: String) -> bool:
	if kind=="story_tower_blue": return done("tower_blue")
	if kind=="late_silph_blue": return a.Finale.has(a,"silph_blue")
	return a.Story.state(a).get(kind,false)

func gym_cleared(kind: String) -> bool:
	if kind.begins_with("post_rematch:") and kind.trim_prefix("post_rematch:") in a.expansion.REMATCHES.slice(0,8): return true
	if kind=="brock": return a.data.badge
	if kind=="misty": return a.data.get("cascade",false)
	if kind=="surge": return a.Story.state(a).get("thunder",false)
	var badge={"late_erika":"rainbow","late_koga":"soul","late_sabrina":"marsh","late_blaine":"volcano","late_giovanni":"earth"}.get(kind,"")
	return badge!="" and a.Finale.has(a,badge)

func done(key: String) -> bool: return a.field.done("story:"+key)
func finish(key: String): a.field.finish("story:"+key)
func national() -> bool: return done("national_dex")
func caught_kanto() -> int:
	a.collection.sync(); var count=0
	for id in a.data.pokedex:
		if int(id)<=151 and a.data.pokedex[id].get("caught",false): count+=1
	return count

func national_ready() -> bool:
	return a.Finale.has(a,"champion") and a.field.done("visited:MAP_ONE_ISLAND") and caught_kanto()>=60

func gate(destination: String) -> String:
	var current=a.world.current
	if current=="MAP_VIRIDIAN_CITY" and destination=="MAP_ROUTE2" and not a.field.done("parcel_delivered"): return "Deliver Oak's Parcel to his laboratory before travelling north."
	if current=="MAP_PEWTER_CITY" and destination=="MAP_ROUTE3" and not a.data.badge: return "The guide asks you to earn Brock's Boulder Badge first."
	if destination=="MAP_SAFFRON_CITY" and not done("tea"): return "GUARD: I'm terribly thirsty. The lady in Celadon's condominium has Tea."
	if destination=="MAP_VIRIDIAN_CITY_GYM" and a.Finale.badges(a)<7: return "Viridian Gym is closed. Return with seven Gym Badges."
	if destination=="MAP_CERULEAN_CAVE_1F" and not (a.Finale.has(a,"champion") and national() and a.sevii.done("network")): return "The cave guard admits Champions who have completed Celio's Ruby and Sapphire Network Machine quest."
	return ""

func legendary_requirement(species: int) -> String:
	if species==150: return gate("MAP_CERULEAN_CAVE_1F")
	if species==144 and not a.field.done("calm:MAP_SEAFOAM_ISLANDS_B4F"): return "Solve Seafoam's boulder puzzle and block the lower current before approaching Articuno."
	if species in [144,145] and not a.field.can_use("surf"): return "A partner knowing Surf and the Soul Badge are needed to reach this chamber."
	if species==146 and not (a.sevii.done("tri_pass") and a.field.can_use("strength")): return "Reach One Island with Bill's Tri-Pass and solve Mt. Ember's Strength boulder path."
	return ""

func npc(npc) -> bool:
	var script=str(npc.get("script","")); var gfx=str(npc.get("graphics_id","")); var w=a.world
	if script=="CeruleanCity_EventScript_CeruleanCaveGuard": a.dialog=legendary_requirement(150); return true
	var gifts={"FuchsiaCity_WardensHouse_EventScript_Warden":"strength","VermilionCity_PokemonFanClub_EventScript_Chairman":"bicycle","SafariZone_SecretHouse_EventScript_Attendant":"surf","SilphCo_11F_EventScript_President":"silph_saved"}
	if gifts.has(script):
		a.Finale.start_task(a,gifts[script]); return true
	if w.current=="MAP_POKEMON_TOWER_2F" and "BLUE" in gfx:
		if not done("tower_blue"): a.begin_battle("story_tower_blue",[],[])
		else: a.dialog="BLUE: Your team is getting stronger. See you around!"
		return true
	if script in ["MtEmber_Exterior_EventScript_Grunt1","MtEmber_Exterior_EventScript_Grunt2"] and not a.sevii.done("network_quest"):
		a.dialog="The Rockets are digging. Speak to Celio after receiving the National Pokedex."; return true
	if script=="Route24_EventScript_Rocket":
		if a.Story.state(a).get("bridge_rocket",false): a.dialog="You defeated the Nugget Bridge challenge."; return true
		if bridge_count()<5: a.dialog="Defeat all five trainers on Nugget Bridge first."; return true
		w.scenes.play([{"text":"You cleared the five-trainer challenge! But the recruiter reveals he belongs to Team Rocket...","duration":2.6}],func():a.begin_battle("bridge_rocket",[23,41],[15,15])); return true
	if AIDES.has(script):
		var spec=AIDES[script]; var key="aide:"+script
		if done(key): a.dialog="OAK'S AIDE: I hope your "+spec[2]+" is helping on your journey."; return true
		var count=caught_kanto()
		if count<int(spec[0]): a.dialog="OAK'S AIDE: Catch "+str(spec[0])+" different Kanto species. Your Pokedex records "+str(count)+" caught."; return true
		if spec[1] in ["flash","itemfinder"]: a.field.finish("field:"+spec[1])
		else: a.data.bag[spec[1]]=mini(999,int(a.data.bag.get(spec[1],0))+1)
		finish(key); a.dialog="OAK'S AIDE: Excellent research! Received "+spec[2]+"!"; a.save(); return true
	if script=="CeladonCity_Condominiums_1F_EventScript_TeaWoman":
		finish("tea"); a.dialog="The lady gives you TEA. Share it with Saffron's thirsty gate guards."; a.save(); return true
	if "PROF_OAK" in gfx and a.field.done("parcel_delivered"):
		if national(): a.dialog="OAK: Your National Pokedex is ready. Explore the Sevii Islands and help Celio finish his research."
		elif national_ready(): national_scene()
		else: a.dialog="OAK: You have caught "+str(caught_kanto())+" different Kanto species. After the League, visit One Island and return with 60 caught species for a Pokedex upgrade."
		return true
	if w.current=="MAP_CINNABAR_ISLAND" and "BILL" in gfx:
		bill_visit(); return true
	if w.current=="MAP_SILPH_CO_7F" and "BLUE" in gfx:
		a.Finale.start_task(a,"silph_blue"); return true
	if script=="PokemonTower_7F_EventScript_MrFuji":
		var guards=["Grunt1","Grunt2","Grunt3"]
		if not guards.all(func(id):return a.field.done("trainer:PokemonTower_7F_EventScript_"+id)):
			a.dialog="Rescue Mr. Fuji by defeating all three Rocket guards."; return true
		a.Finale.state(a).tower_rocket=true
		w.scenes.play([{"text":"MR. FUJI: Thank you. The restless spirit is at peace. Let us return to my house.","duration":3.0}],func():
			finish("fuji_rescued"); w.enter("MAP_LAVENDER_TOWN_VOLUNTEER_POKEMON_HOUSE",Vector2(4.5,5.5)*48); a.save())
		return true
	if script=="LavenderTown_VolunteerPokemonHouse_EventScript_MrFuji":
		if done("fuji_rescued"): a.Finale.start_task(a,"flute")
		else: a.dialog="Mr. Fuji is away at Pokemon Tower."
		return true
	return false

func bridge_count() -> int:
	var count=0
	for name in ["Cale","Ali","Timmy","Reli","Ethan"]:
		if a.field.done("trainer:Route24_EventScript_"+name): count+=1
	return count

func hidden_items() -> Array:
	var result=[]
	for sign in a.world.room().signs:
		if sign.get("type","")!="hidden_item": continue
		var item=sign.duplicate(); item.id="hidden_"+str(sign.flag); item.item=str(sign.item).trim_prefix("ITEM_")
		if not a.field.done(a.world.current+"item"+item.id): result.append(item)
	return result

func itemfinder():
	if not a.field.owns("itemfinder"): return
	a.clear_ui()
	var candidates=hidden_items()
	if candidates.is_empty(): a.dialog="ITEMFINDER: No hidden items remain in this area."; return
	candidates.sort_custom(func(x,y):return a.world.events.point(x).distance_squared_to(a.position_world)<a.world.events.point(y).distance_squared_to(a.position_world))
	var delta=a.world.events.point(candidates[0])-a.position_world
	if delta.length()<24:
		a.world.events.pickup(candidates[0]); return
	var direction="east" if absf(delta.x)>absf(delta.y) and delta.x>0 else "west" if absf(delta.x)>absf(delta.y) else "south" if delta.y>0 else "north"
	a.dialog="ITEMFINDER: A hidden item lies "+direction+", about "+str(roundi(delta.length()/48))+" steps away. Search the tile in front of you."

func main_rival() -> bool:
	var w=a.world
	var kind={"MAP_CERULEAN_CITY":"bridge_blue","MAP_POKEMON_TOWER_2F":"story_tower_blue","MAP_SS_ANNE_2F_CORRIDOR":"ship_blue","MAP_SILPH_CO_7F":"late_silph_blue"}.get(w.current,"")
	if kind=="" or rival_done(kind) or a.data.starter==0: return false
	var cell=Vector2i(a.position_world/48)
	var triggers=w.events.catalog[w.current].triggers
	if not triggers.any(func(t):return "RivalTrigger" in str(t.get("script","")) and Vector2i(int(t.x),int(t.y))==cell): return false
	var target=w.walkable(a.position_world+Vector2.UP*48)
	var origin=target
	for object in w.room().objects:
		if object.get("graphics_id","")=="OBJ_EVENT_GFX_BLUE": origin=w.events.point(object); break
	var steps=[{"actor":{"key":"scene_blue","gfx":"blue","from":origin,"to":origin},"text":"BLUE: Hey!","duration":.8}]
	for next in w.scenes.escort_path(origin,target):
		steps.append({"actor":{"key":"scene_blue","gfx":"blue","from":origin,"to":next},"duration":.24})
		origin=next
	steps.append({"text":"BLUE: You're still keeping up? Let's see how strong your team has become!","duration":2.7})
	w.scenes.play(steps,func():a.begin_battle(kind,[],[]))
	return true

func national_scene():
	if national() or not national_ready(): return
	a.world.scenes.play([
		{"text":"OAK: Sixty different species! Your research has grown since you became Champion.","duration":2.7},
		{"text":"BLUE: Grandpa! You're upgrading our Pokedexes?","duration":2.0},
		{"text":"Oak installs the National Mode in both Pokedexes.","duration":2.4,"flash":true},
		{"text":"NATIONAL POKEDEX unlocked! Celio needs your help on One Island.","duration":2.7}
	],func():finish("national_dex"); a.save(),"scene:national_dex")

func bill_visit():
	if not a.Finale.has(a,"volcano"): a.dialog="BILL: Finish your Cinnabar Gym challenge first."; return
	if a.sevii.done("tri_pass"): a.sevii.ferry_menu(); return
	a.world.scenes.play([
		{"text":"BILL: Congratulations on the Volcano Badge! Come meet my friend Celio on One Island.","duration":3.0},
		{"text":"The ferry sails south to the Sevii Islands...","duration":2.0,"flash":true}
	],func():
		a.sevii.finish("tri_pass"); a.sevii.finish("meteorite"); a.field.finish("visited:MAP_ONE_ISLAND")
		a.world.enter("MAP_ONE_ISLAND_POKEMON_CENTER_1F",Vector2(6.5,8.5)*48)
		a.dialog="CELIO: Take this TRI-PASS. Please deliver Bill's Meteorite to his friend at Two Island's Game Corner."; a.save())

func entered():
	if a.world.current=="MAP_CINNABAR_ISLAND" and a.Finale.has(a,"volcano") and not a.sevii.done("tri_pass"): bill_visit()

func after_battle(kind: String, won: bool):
	if not won: return
	if kind=="story_tower_blue": finish("tower_blue")
	if kind.begins_with("world_Route24_"): a.Story.state(a).bridge=bridge_count()
	if kind=="late_league_4": finish("champion_pending")
	if kind=="late_silph_boss": finish("silph_defeated")
	if kind in ["world_MtEmber_Exterior_EventScript_Grunt1","world_MtEmber_Exterior_EventScript_Grunt2"] and ["Grunt1","Grunt2"].all(func(id):return a.field.done("trainer:MtEmber_Exterior_EventScript_"+id)):
		a.sevii.finish("password_ruby")
	a.world.events.refresh()
	if kind=="sevii_lostelle":
		a.world.scenes.play([{"text":"LOSTELLE: Thank you! Please take me home to my daddy.","duration":2.5}],func():
			a.world.enter("MAP_TWO_ISLAND_JOYFUL_GAME_CORNER",Vector2(4.5,6.5)*48)
			a.sevii.npc({"script":"TwoIsland_JoyfulGameCorner_EventScript_LostellesDaddy"}); a.save())
	resume_ceremony()

func resume_ceremony():
	if not done("champion_pending") or a.in_battle or a.modal!="" or a.world.scenes.active: return
	a.dialog=""
	var w=a.world; var target=w.walkable(a.position_world+Vector2.DOWN*48)
	var origin=w.walkable(target+Vector2.DOWN*96)
	w.scenes.play([
		{"actor":{"key":"scene_oak","gfx":"prof_oak","from":origin,"to":target},"text":"OAK: I heard Blue had become Champion, but you've already beaten him!","duration":2.8},
		{"text":"OAK: Blue, victory comes from trust in your Pokemon, not strength alone.","duration":2.8},
		{"text":"OAK: Come with me. You and your partners deserve to be recorded in the Hall of Fame.","duration":3.2}
	],func():w.enter("MAP_POKEMON_LEAGUE_HALL_OF_FAME",Vector2(5.5,6.5)*48))

func hall():
	if a.modal=="HALL OF FAME": return
	a.clear_ui(); a.modal="HALL OF FAME"; a.dialog=""
	hall_scene=preload("res://champion_presentation.gd").new(); a.ui.add_child(hall_scene); hall_scene.setup(a)

func finish_ceremony():
	a.clear_ui(); a.world.events.state().done.erase("story:champion_pending"); finish("hall_recorded")
	for mon in a.data.party: mon.hp=0. if mon.get("is_egg",false) else 1.; mon.ailment=""
	a.world.enter("MAP_PALLET_TOWN_PLAYERS_HOUSE_2F",Vector2(6.5,6.5)*48)
	a.dialog="Your team has entered the Hall of Fame! Visit Professor Oak to continue your journey."; a.save()
