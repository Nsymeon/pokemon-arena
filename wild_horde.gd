extends RefCounted

func active(c) -> bool:
	return c.adventure.in_battle and c.adventure.encounter.get("kind","")=="wild" and c.adventure.encounter.get("ids",[]).size()==5

func living(c) -> Array:
	return c.enemy_bench.states.filter(func(f):return f.hp>0)

func start(c):
	if not active(c): return
	var court=c.balance.bounds(c)
	for i in range(c.enemy_bench.states.size()):
		var f=c.enemy_bench.states[i]
		f.pos=court.position+court.size*Vector2(0.60+0.12*(i%2),0.25+0.115*i)
		f["horde_slot"]=i; f["horde_cooldowns"]=[0.0,0.0,0.0,0.0]; f["horde_ai"]=0.6+i*0.35
		f["faint_clock"]=0.0
	c.notice="WILD HORDE / 1 vs 5 / Aim near a Pokemon to target it"; c.notice_time=5

func select_target(c):
	if not active(c) or living(c).is_empty(): return
	var mouse=c.screen_to_arena(c.get_global_mouse_position())
	var target=living(c)[0]
	for f in living(c):
		if f.pos.distance_squared_to(mouse)<target.pos.distance_squared_to(mouse): target=f
	c.enemy=target; c.enemy_active=int(target.horde_slot)

func ai(c,dt):
	var selected=c.enemy
	var selected_slot=c.enemy_active
	for f in living(c):
		c.enemy=f; c.enemy_active=int(f.horde_slot)
		c.enemy_cooldowns=f.horde_cooldowns; c.ai_timer=f.horde_ai
		for i in range(4): c.enemy_cooldowns[i]=maxf(0,c.enemy_cooldowns[i]-dt)
		c.update_ai(dt)
		f.horde_ai=c.ai_timer
	c.enemy=selected; c.enemy_active=selected_slot; c.enemy_cooldowns=selected.horde_cooldowns

func settle(c,dt):
	if not active(c): return
	var selected=c.enemy; var slot=c.enemy_active
	for f in c.enemy_bench.states:
		if f.hp>0: continue
		if not f.get("horde_rewarded",false):
			f["horde_rewarded"]=true; f.fainted=true; f["faint_frame"]=c.art.frame(f); f["faint_delay"]=0.0
			f.dash_time=0; f.charge_left=0; f.pending_move={}
			c.enemy=f; c.enemy_active=int(f.horde_slot); c.adventure.record_knockout(true)
		f.faint_clock+=dt
	c.enemy=selected; c.enemy_active=slot
	if c.enemy.hp<=0 and not living(c).is_empty(): select_target(c)

func draw(c):
	var fighters=c.enemy_bench.states.duplicate(); fighters.append(c.player)
	fighters.sort_custom(func(x,y):return x.pos.y<y.pos.y)
	for f in fighters:
		var old=c.result_time
		if f!=c.player and f.hp<=0: c.result_time=f.get("faint_clock",0.0)
		c.draw_creature(f,f==c.player)
		c.result_time=old
		c.skills.draw_charge(c,f)
		if f!=c.player and f.hp>0:
			c.bar(f.pos+Vector2(-34,-90),68,f.hp/f.data.hp,Color("f18c71"),5)
			c.label_at(f.data.name,f.pos+Vector2(-38,-100),12)
			if f==c.enemy: c.draw_arc(f.pos,35,0,TAU,32,Color("f9d86b"),3,true)

func tests(c):
	var arena_before={}
	for key in ["player_team","enemy_team","enemy_party","player_index","enemy_index","team_slot","team_mode","opponent_identity"]:
		var value=c.get(key); arena_before[key]=value.duplicate(true) if value is Array else value
	var a=c.adventure; var before=a.data.duplicate(true); var old_save=a.save_allowed; var old_world=a.world.enabled
	a.save_allowed=false; a.world.enabled=false; a.data=a.INITIAL_DATA.duplicate(true)
	a.data.party=[a.new_mon(1,50),a.new_mon(7,50),a.new_mon(4,50)]; a.data.starter=1; a.inventory.migrate()
	a.data.party[1]["held_item"]="expshare"
	a.begin_battle("wild",[19,19,19,19,19],[2,2,2,2,2]); c.countdown=0; c.rocks.clear()
	c.check(active(c) and living(c).size()==5,"Lure horde spawns five simultaneously active wild Pokemon")
	var balls=a.data.balls; a.throw_ball(); c.check(a.data.balls==balls and a.capture_time==0,"Horde capture blocked without consuming a ball while several wild Pokemon live")
	for i in range(5): c.foes()[i].pos=c.player.pos+Vector2(150,(i-2)*50)
	var start_positions=c.foes().map(func(f):return f.pos)
	for i in range(180): c.update_battle(0.016)
	c.check(c.foes().all(func(f):return f.pos!=start_positions[int(f.horde_slot)]),"All five horde opponents move independently")
	c.check(c.foes().all(func(f):return f.has("last_move")),"All five horde opponents can attack with independent cooldowns")
	c.check(c.enemy_bench.used==0,"Wild horde members never perform trainer substitutions")
	c.player.pos=Vector2(400,600)
	for i in range(5):
		var f=c.foes()[i]; f.pos=Vector2(650+i*60,600); f.inv=0; f.hp=f.data.hp; f.volatile.clear()
	c.shots.clear(); c.skills.launch(c,c.player,c.enemy,{"id":"solarbeam","type":"Grass","damage":1.0},Vector2.RIGHT,true)
	c.skills.tick(c,c.shots.back(),1.0)
	c.check(c.foes().all(func(f):return f.hp<f.data.hp),"One beam can hit all five horde targets")
	c.shots.clear()
	for f in c.foes(): f.hp=0
	settle(c,0.1)
	c.check(a.encounter.rewarded.size()==5,"Each horde knockout pays rewards once")
	c.check(a.data.party[0].xp==80 and a.data.party[1].xp==40 and a.data.party[2].xp==0,"Participants get XP; bench Exp. Share holder gets half; ordinary bench gets none")
	c.check(c.ivs.ev_total(a.data.party[0])==5 and c.ivs.ev_total(a.data.party[1])==0 and c.ivs.ev_total(a.data.party[2])==0,"Only horde battle participants earn EVs")
	settle(c,0.1); c.check(a.data.party[0].xp==80,"Horde rewards are idempotent")
	c.finish_round(); c.result_time=10; var money=a.data.money; a.return_world()
	c.check(a.exploring and not a.in_battle and a.data.money==money,"Defeating a horde returns to the map without awarding money")
	a.clear_ui(); a.data.party[0].xp=0; a.data.party[1].xp=0
	a.begin_battle("wild",[25],[2]); c.countdown=0
	a.return_world(true)
	c.check(a.data.party[0].xp==23 and a.data.party[1].xp==11 and a.data.party.back().xp==0,"Capture awards participation XP, never XP to the newly caught Pokemon")
	c.check(a.modal!="" and a.data.pokedex["25"].caught,"First capture opens a registered Pokedex entry")
	a.finish_capture_entry(); a.evolutions.clear(); a.clear_ui(); a.dialog=""
	a.begin_battle("wild",[25],[2]); a.return_world(true)
	c.check(a.modal=="","Repeat capture does not reopen the new Pokedex entry")
	a.clear_ui(); a.data.party=[a.new_mon(1,50),a.new_mon(7,50),a.new_mon(4,50)]; a.data.party[1]["held_item"]="expshare"
	a.begin_battle("wild",[19],[2]); c.activate_player(2); c.enemy.hp=0; a.record_knockout(true)
	c.check(a.data.party[0].xp==8 and a.data.party[2].xp==8 and a.data.party[1].xp==8,"Switching shares XP among participants and keeps bench share separate")
	c.check(c.ivs.ev_total(a.data.party[0])==1 and c.ivs.ev_total(a.data.party[2])==1 and c.ivs.ev_total(a.data.party[1])==0,"Both actual participants gain EVs; bench holder does not")
	a.clear_ui(); a.in_battle=false; a.exploring=false; a.visible=false; a.data=before; a.save_allowed=old_save; a.world.enabled=old_world
	for key in arena_before: c.set(key,arena_before[key])
	c.reset()
