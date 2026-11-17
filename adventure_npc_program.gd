extends RefCounted
# Ordered source dialogue with a private transaction until the conversation ends.
var a
var book: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/npc-programs.json"))
var active=false
var staged={}
var locals={}
var buffers={}
var stack=[]
var label=""
var pc=0
var compared=[0,0]
var switched=0
var last_text=""
var waiting_choice=false
var choices=[]
var generation=0
var aborted=false
var trace=[]
var temporary={}
var temporary_map=""
var pending_temp={}
var capacity_failed=false
var checkpoint={}
const AIDE_FLAGS={"flash":"FLAG_GOT_HM05","everstone":"FLAG_GOT_EVERSTONE_FROM_OAKS_AIDE","itemfinder":"FLAG_GOT_ITEMFINDER","amuletcoin":"FLAG_GOT_AMULET_COIN_FROM_OAKS_AIDE","expshare":"FLAG_GOT_EXP_SHARE_FROM_OAKS_AIDE"}

const KEYS={
	"OLD_ROD":"field:old_rod","GOOD_ROD":"field:good_rod","SUPER_ROD":"field:super_rod",
	"COIN_CASE":"coin_case","TOWN_MAP":"town_map","ITEMFINDER":"field:itemfinder",
	"TEA":"story:tea","HM02":"field:fly","HM05":"field:flash","HM06":"field:rocksmash","HM07":"field:waterfall"}
const JOURNEY_ITEMS={"BIKE_VOUCHER":"bicycle","GOLD_TEETH":"gold_teeth","POKE_FLUTE":"flute","HM03":"surf","HM04":"strength","SILPH_SCOPE":"scope","LIFT_KEY":"lift_key","CARD_KEY":"card_key","SECRET_KEY":"secret_key"}
const FLAG_KEYS={"FLAG_GOT_TEA":"story:tea","FLAG_GOT_TOWN_MAP":"town_map","FLAG_GOT_COIN_CASE":"coin_case",
	"FLAG_GOT_OLD_ROD":"field:old_rod","FLAG_GOT_GOOD_ROD":"field:good_rod","FLAG_GOT_SUPER_ROD":"field:super_rod",
	"FLAG_GOT_HM02":"field:fly","FLAG_GOT_HM05":"field:flash","FLAG_GOT_HM06":"field:rocksmash",
	"FLAG_GOT_ITEMFINDER":"field:itemfinder","FLAG_GOT_BICYCLE":"field:bicycle","FLAG_OPENED_ROCKET_HIDEOUT":"poster",
	"FLAG_RESCUED_MR_FUJI":"story:fuji_rescued","FLAG_SYS_NATIONAL_DEX":"story:national_dex"}
const FLAG_JOURNEY={"FLAG_GOT_BIKE_VOUCHER":"bicycle","FLAG_GOT_HM03":"surf","FLAG_GOT_HM04":"strength","FLAG_GOT_POKE_FLUTE":"flute",
	"FLAG_GOT_MASTER_BALL":"silph_saved","FLAG_HIDE_SAFFRON_ROCKETS":"silph_boss","FLAG_HIDE_SILPH_ROCKETS":"silph_boss",
	"FLAG_HIDE_CELADON_ROCKETS":"hideout_boss","FLAG_HIDE_TOWER_FUJI":"tower_rocket"}

func valid(data) -> bool:
	var state=data.get("npc_variables",{})
	if not state is Dictionary or state.size()>512: return false
	for key in state:
		if not key is String or not key.begins_with("VAR_") or key.length()>120: return false
		var value=state[key]
		if value is String:
			if value.length()>120 or not value.begins_with("ITEM_"): return false
		elif not (value is int or value is float) or not is_finite(value) or value!=int(value) or value<0 or value>65535: return false
	return true

func supports(script: String) -> bool: return script in book.roots

func start(object: Dictionary) -> bool:
	var script=str(object.get("script",""))
	if not supports(script) or a.in_battle: return false
	cancel()
	a.collection.sync()
	a.world.events.state()
	a.services.state()
	staged=a.data.duplicate(true)
	if not staged.has("npc_variables"): staged.npc_variables={}
	checkpoint=staged.duplicate(true)
	if temporary_map!=a.world.current: temporary={}; temporary_map=a.world.current
	pending_temp=temporary.duplicate(true)
	locals={}; buffers={}; stack=[]; trace=[]; last_text=""; aborted=false; capacity_failed=false
	# Before this engine, generic gifts used a script-level completion marker.
	var old=a.world.scenes.dialogue.get(script,{}).get("gift",{})
	if done("npc_gift:"+script) and old.has("flag"): set_flag(str(old.flag),true)
	for aide in a.progression.AIDES:
		if done("story:aide:"+aide):
			var item=str(a.progression.AIDES[aide][1])
			var flag=AIDE_FLAGS[item]
			set_flag(flag,true)
	active=true; label=script; pc=0; generation+=1; a.c.click_move=false
	run()
	return true

func cancel(reset_map=false):
	active=false; waiting_choice=false; choices=[]; generation+=1; staged={}
	if reset_map: temporary={}; temporary_map=""

func done(key) -> bool: return bool(staged.get("world_events",{}).get("done",{}).get(key,false))

func flag_value(key: String) -> bool:
	if key.begins_with("FLAG_TEMP_"): return bool(pending_temp.get(key,false))
	if done("source:"+key): return true
	if FLAG_KEYS.has(key): return done(FLAG_KEYS[key])
	if FLAG_JOURNEY.has(key): return bool(staged.get("journey",{}).get(FLAG_JOURNEY[key],false))
	if key=="FLAG_GOT_HM01": return bool(staged.get("story",{}).get("cut",false))
	if key=="FLAG_GOT_SS_TICKET": return bool(staged.get("story",{}).get("ticket",false))
	if key=="FLAG_HIDE_SAFARI_ZONE_WEST_GOLD_TEETH": return bool(staged.get("journey",{}).get("gold_teeth",false))
	if key=="FLAG_GOT_MASTER_BALL_FROM_SILPH": return bool(staged.get("journey",{}).get("silph_saved",false))
	if key=="FLAG_WOKE_UP_ROUTE_12_SNORLAX": return done("snorlax:MAP_ROUTE12")
	if key=="FLAG_GOT_TM28_FROM_ROCKET": return bool(staged.get("rocket",false))
	var sevii_flags={"FLAG_RESCUED_LOSTELLE":"lostelle_saved","FLAG_DEFEATED_ROCKETS_IN_WAREHOUSE":"sapphire","FLAG_SYS_CAN_LINK_WITH_RS":"network","FLAG_SEVII_DETOUR_FINISHED":"initial_trip_complete"}
	if sevii_flags.has(key): return done("sevii:"+sevii_flags[key])
	var gym_flags={"FLAG_DEFEATED_BROCK":"FLAG_BADGE01_GET","FLAG_DEFEATED_MISTY":"FLAG_BADGE02_GET","FLAG_DEFEATED_LT_SURGE":"FLAG_BADGE03_GET","FLAG_DEFEATED_ERIKA":"FLAG_BADGE04_GET","FLAG_DEFEATED_KOGA":"FLAG_BADGE05_GET","FLAG_DEFEATED_SABRINA":"FLAG_BADGE06_GET","FLAG_DEFEATED_BLAINE":"FLAG_BADGE07_GET","FLAG_DEFEATED_LEADER_GIOVANNI":"FLAG_BADGE08_GET"}
	if gym_flags.has(key): return flag_value(gym_flags[key])
	var original=a.world.scenes.dialogue_flag(key)
	return bool(original) if original!=null else false

func set_flag(key: String, enabled: bool):
	if key.begins_with("FLAG_TEMP_"): pending_temp[key]=enabled; return
	if enabled: staged.world_events.done["source:"+key]=true
	else: staged.world_events.done.erase("source:"+key)

func value(raw):
	if not raw is String: return raw
	if raw=="VAR_FACING": return {Vector2.DOWN:1,Vector2.UP:2,Vector2.LEFT:3,Vector2.RIGHT:4}.get(a.world.heading,1)
	if raw=="VAR_MAP_SCENE_VIRIDIAN_CITY_GYM_DOOR": return int(a.Finale.badges(a)>=7)
	if raw=="VAR_MAP_SCENE_VIRIDIAN_CITY_OLD_MAN": return 2 if done("field:teachytv") or done("source:FLAG_GOT_TEACHY_TV") else int(done("parcel_delivered"))
	if raw=="VAR_MAP_SCENE_PALLET_TOWN_PROFESSOR_OAKS_LAB": return 6 if done("parcel_delivered") else 4 if a.data.rival else 3 if a.data.starter!=0 else 2 if done("oak_intro") else 0
	if raw=="VAR_MAP_SCENE_SILPH_CO_11F": return int(staged.get("journey",{}).get("silph_boss",false))
	if raw=="VAR_MAP_SCENE_VERMILION_CITY" and staged.get("story",{}).get("cut",false): return 3
	if raw=="VAR_MAP_SCENE_TWO_ISLAND_JOYFUL_GAME_CORNER": return 4 if done("sevii:lostelle_returned") else 2 if done("sevii:lostelle_saved") else 1 if done("sevii:lostelle_quest") else 0
	if raw=="VAR_MAP_SCENE_THREE_ISLAND": return 4 if done("sevii:bikers") else 0
	if raw.begins_with("VAR_"): return locals.get(raw,staged.get("npc_variables",{}).get(raw,0))
	return raw

func put(key: String, result):
	locals[key]=result
	if not (key.begins_with("VAR_TEMP_") or key.begins_with("VAR_0x8") or key=="VAR_RESULT" or key=="VAR_FACING"):
		staged.npc_variables[key]=result

func test(op: String, left, right) -> bool:
	match op:
		"eq": return left==right
		"ne": return left!=right
		"lt": return left<right if typeof(left)!=TYPE_STRING and typeof(right)!=TYPE_STRING else false
		"le": return left<=right if typeof(left)!=TYPE_STRING and typeof(right)!=TYPE_STRING else false
		"gt": return left>right if typeof(left)!=TYPE_STRING and typeof(right)!=TYPE_STRING else false
		"ge": return left>=right if typeof(left)!=TYPE_STRING and typeof(right)!=TYPE_STRING else false
	return false

func jump(destination: String, call=false):
	if call: stack.append([label,pc])
	label=destination; pc=0

func item_id(raw) -> String: return str(value(raw)).trim_prefix("ITEM_")

func count_item(raw) -> int:
	var id=item_id(raw)
	if KEYS.has(id): return int(done(KEYS[id]))
	if JOURNEY_ITEMS.has(id):
		if id=="GOLD_TEETH" and bool(staged.get("journey",{}).get("strength",false)): return 0
		return int(staged.get("journey",{}).get(JOURNEY_ITEMS[id],false))
	if id=="HM01": return int(staged.get("story",{}).get("cut",false))
	if id=="BICYCLE": return int(done("field:bicycle"))
	if id=="POKE_BALL": return int(staged.balls)
	if id.begins_with("TM"): return int(staged.tms.get(id,0))
	return int(staged.bag.get(id.to_lower().replace("_",""),0))

func item_supported(raw) -> bool:
	var id=item_id(raw)
	return KEYS.has(id) or JOURNEY_ITEMS.has(id) or id in ["HM01","BICYCLE","POKE_BALL"] or a.inventory.book.tms.has(id) or a.inventory.ITEMS.has(id.to_lower().replace("_",""))

func change_item(raw, amount: int) -> bool:
	var id=item_id(raw)
	if not item_supported(raw): fail("Unsupported item "+id); return false
	if count_item(raw)+amount<0 or count_item(raw)+amount>999: return false
	if KEYS.has(id):
		if amount>0: staged.world_events.done[KEYS[id]]=true
		else: staged.world_events.done.erase(KEYS[id])
	elif JOURNEY_ITEMS.has(id):
		if not staged.has("journey"): staged.journey={}
		staged.journey[JOURNEY_ITEMS[id]]=amount>0
	elif id=="HM01":
		if not staged.has("story"): staged.story={}
		staged.story.cut=amount>0
	elif id=="BICYCLE": staged.world_events.done["field:bicycle"]=amount>0
	elif id=="POKE_BALL": staged.balls+=amount
	elif id.begins_with("TM"): staged.tms[id]=count_item(raw)+amount
	else: staged.bag[id.to_lower().replace("_","")]=count_item(raw)+amount
	return true

func item_name(raw) -> String:
	var id=item_id(raw)
	var tools={"HM01":"Cut Shears","HM04":"Power Gloves","HM05":"Lantern","HM06":"Rock Hammer","HM07":"Waterfall Climber"}
	if tools.has(id): return tools[id]
	if a.inventory.book.tms.has(id): return id+" ("+str(a.inventory.book.tms[id].name)+")"
	return id.replace("_"," ").capitalize()

func words(key) -> String:
	var text=str(book.texts.get(str(key),key))
	for token in buffers: text=text.replace("{"+str(token)+"}",str(buffers[token]))
	return text.replace("{PLAYER}",str(a.data.get("player_name","RED"))).replace("{RIVAL}","BLUE").replace("{POKEBLOCK}","POKEBLOCK")

func say(text: String):
	last_text=text; trace.append(text); a.show_dialogue(text)

func menu(options: Array, yesno=false, allow_cancel=true):
	checkpoint=staged.duplicate(true)
	waiting_choice=true; choices=options.duplicate(); generation+=1
	var token=generation
	var list=a.inventory.page("CONVERSATION",choose.bind(0 if yesno else 127,token) if allow_cancel else Callable())
	# Esc also follows the source's No/cancel branch; callbacks from old panels expire.
	if not allow_cancel: a.ui_back=func():pass
	var text=Label.new(); text.text=last_text; text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size=Vector2(875,90); text.add_theme_font_size_override("font_size",22); list.add_child(text)
	for i in options.size(): a.inventory.row(list,words(options[i]),choose.bind(1-i if yesno else i,token))

func choose(result, token):
	if not active or not waiting_choice or token!=generation: return
	waiting_choice=false; choices=[]; generation+=1
	a.clear_ui(); put("VAR_RESULT",result); run()

func resume():
	if active and not waiting_choice and a.dialog=="": run()

func fail(reason: String):
	push_warning("NPC program stopped safely: "+label+": "+reason)
	aborted=true; cancel(); a.clear_ui(); a.show_dialogue("This conversation could not be completed. Your items and progress have been kept unchanged.")

func complete():
	# No partial grant/consumption/flag is observable to autosave or another menu.
	if not valid(staged): fail("invalid variables"); return
	if capacity_failed:
		staged=checkpoint
	for aide in a.progression.AIDES:
		if flag_value(AIDE_FLAGS[a.progression.AIDES[aide][1]]): staged.world_events.done["story:aide:"+aide]=true
	a.data=staged; temporary=pending_temp.duplicate(true)
	active=false; waiting_choice=false; generation+=1
	a.save()

func run():
	for step in 2048:
		if not active: return
		if not book.programs.has(label) or pc>=book.programs[label].size(): fail("missing termination"); return
		var cmd=book.programs[label][pc]; pc+=1
		var op=str(cmd[0]); var args=cmd.slice(1)
		if op.begins_with("goto_if_") or op.begins_with("call_if_"):
			if op=="goto_if_questlog": continue
			var relation=op.get_slice("_",2); var matches=false
			if relation in ["set","unset"]: matches=flag_value(str(args[0]))==(relation=="set")
			else: matches=test(relation,value(args[0]) if args.size()==3 else compared[0],value(args[1]) if args.size()==3 else compared[1])
			if matches: jump(str(args[-1]),op.begins_with("call"))
			continue
		match op:
			"end": complete(); return
			"return":
				if stack.is_empty(): complete(); return
				var at=stack.pop_back(); label=at[0]; pc=at[1]
			"goto","call": jump(str(args[0]),op=="call")
			"switch": switched=value(args[0])
			"case":
				if switched==value(args[0]): jump(str(args[1]))
			"setvar","copyvar": put(str(args[0]),value(args[1]))
			"addvar","subvar": put(str(args[0]),posmod(int(value(args[0]))+int(value(args[1]))*(1 if op=="addvar" else -1),65536))
			"compare","compare_var_to_value": compared=[value(args[0]),value(args[1])]
			"checkflag": compared=[int(flag_value(str(args[0]))),1]
			"setflag","clearflag": set_flag(str(args[0]),op=="setflag")
			"famechecker":
				# The optional third argument changes portrait state, not a fact index.
				if args.size()<3 or args[2]=="SetFlavorTextFlagFromSpecialVars": set_flag("FAME:"+str(args[0])+":"+str(args[1]),true)
				else: set_flag("FAME_PORTRAIT:"+str(args[0])+":"+str(args[1]),true)
			"checkplayergender": put("VAR_RESULT",1 if a.avatar.config().gender=="girl" else 0)
			"msgbox","message":
				last_text=words(args[0])
				if args.size()>1 and args[1]=="MSGBOX_YESNO": menu(["YES","NO"],true)
				else: say(last_text)
				return
			"yesnobox": menu(["YES","NO"],true); return
			"badgemenu": menu(["BOULDER","CASCADE","THUNDER","RAINBOW","SOUL","MARSH","VOLCANO","EARTH","EXIT"]); return
			"multichoice","multichoicedefault","multichoicegrid": menu(book.choices[args[2]],false,int(args[-1])==0); return
			"bufferitemname","bufferitemnameplural": buffers[args[0]]=item_name(args[1])
			"buffernumberstring": buffers[args[0]]=str(value(args[1]))
			"bufferstring": buffers[args[0]]=words(args[1])
			"bufferspeciesname": buffers[args[0]]=str(value(args[1])).trim_prefix("SPECIES_").replace("_"," ")
			"bufferpartymonnick":
				var slot=int(value(args[1])); buffers[args[0]]=a.collection.title(staged.party[slot]) if slot>=0 and slot<staged.party.size() else "Pokemon"
			"checkitem","checkitemspace":
				if not item_supported(args[0]): fail("unsupported checked item: "+str(args[0])); return
				var amount=int(value(args[1])) if args.size()>1 else 1
				put("VAR_RESULT",int(count_item(args[0])>=amount if op=="checkitem" else count_item(args[0])+amount<=999))
				if op=="checkitemspace" and value("VAR_RESULT")==0: capacity_failed=true
			"additem","removeitem","giveitem","giveitem_msg","msgreceiveditem":
				var offset=1 if op in ["giveitem_msg","msgreceiveditem"] else 0
				var raw=args[offset]; var amount=int(value(args[offset+1])) if args.size()>offset+1 else 1
				var ok=true if op=="msgreceiveditem" else change_item(raw,amount*(-1 if op=="removeitem" else 1))
				if not active: return
				if not ok and op!="removeitem": capacity_failed=true
				put("VAR_RESULT",int(ok)); buffers["STR_VAR_1"]=item_name(raw); buffers["STR_VAR_2"]=item_name(raw)
				if op in ["giveitem","giveitem_msg","msgreceiveditem"]:
					say((words(args[0]) if offset==1 else "Received "+item_name(raw)+"!") if ok else "There's no room for this item in your Bag."); return
			"checkmoney": put("VAR_RESULT",int(staged.money>=int(value(args[0]))))
			"addmoney","removemoney":
				var amount=int(value(args[0]))*(1 if op=="addmoney" else -1)
				if staged.money+amount<0: fail("not enough money"); return
				staged.money=clampi(int(staged.money)+amount,0,999999)
			"checkcoins": put(str(args[0]),int(staged.services.coins))
			"addcoins","removecoins":
				var amount=int(value(args[0]))*(1 if op=="addcoins" else -1)
				if staged.services.coins+amount<0 or staged.services.coins+amount>9999: fail("coin capacity"); return
				staged.services.coins+=amount
			"getpartysize": put("VAR_RESULT",staged.party.size())
			"checkpartymove":
				var move=str(value(args[0])).trim_prefix("MOVE_").to_lower().replace("_",""); var slot=6
				for i in staged.party.size():
					if not staged.party[i].get("is_egg",false) and move in staged.party[i].moves: slot=i; break
				put("VAR_RESULT",slot)
			"playmoncry":
				var id=int(book.species.get(str(value(args[0])).trim_prefix("SPECIES_"),0))
				if id>0: a.c.audio.cry(id)
			"special","specialvar":
				var name=str(args[-1]); var result=0
				match name:
					"QuestLog_CutRecording": continue
					"GetPokedexCount":
						var caught=0; var seen=0
						for id in staged.get("pokedex",{}):
							if int(id)<=151: caught+=int(staged.pokedex[id].get("caught",false)); seen+=int(staged.pokedex[id].get("seen",false))
						put("VAR_0x8005",seen); put("VAR_0x8006",caught)
					"GetPlayerFacingDirection": result=value("VAR_FACING")
					"GetLeadMonFriendship": result=staged.party[0].get("friendship",70) if not staged.party.is_empty() else 0
					"GetLeadMonIndex": result=0
					_: fail("unsupported special: "+name); return
				if op=="specialvar": put(str(args[0]),result)
			_: fail("unsupported opcode: "+op); return
	fail("instruction limit")
