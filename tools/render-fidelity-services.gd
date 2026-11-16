extends SceneTree
var c
var a
func _initialize(): run.call_deferred()
func snap(name):
	c.queue_redraw(); a.queue_redraw()
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/fidelity-"+name+".png")
func run():
	if DisplayServer.get_name()=="headless": quit(2); return
	root.size=Vector2i(1280,960)
	c=load("res://arena.tscn").instantiate(); root.add_child(c); await process_frame; c.set_process(false)
	a=c.adventure; a.loaded=true; a.save_allowed=false; c.campaign.writable=false
	c.frontend.layer.visible=false; c.campaign.layer.visible=false; c.selection_controls.visible=false; c.selecting=false
	a.data=a.INITIAL_DATA.duplicate(true); a.data.starter=4; a.data.rival=true; a.data.avatar=a.avatar.DEFAULT.duplicate(true)
	a.data.party=[a.new_mon(4,12),a.new_mon(7,12)]; a.inventory.migrate(); a.exploring=true; a.visible=true
	a.world.enabled=true; a.world.current="MAP_VIRIDIAN_CITY_MART"; a.world.view3d.enabled=true
	a.position_world=Vector2(4.5,5.5)*48; a.world.events.refresh()
	a.inventory.shop("ViridianCity_Mart_EventScript_Clerk"); await snap("shop")
	for i in 32: a.collection.store(a.new_mon([16,19,25,35][i%4],5+i))
	a.collection.pc(); await snap("pc")
	a.clear_ui(); a.dialog=""; a.world.current="MAP_ROUTE3"; a.world.events.refresh()
	var npc=a.world.actors().filter(func(o):return o.get("script","")=="Route3_EventScript_Ben")[0]
	a.position_world=npc.pos+Vector2(48,0); a.field.finish("field:vsseeker"); a.field.finish("trainer:Route3_EventScript_Ben")
	var s=a.vs_seeker.state(); s.map=a.world.current; s.remaining=100; s.ready["TRAINER_YOUNGSTER_BEN"]=true
	await snap("seeker")
	print("FIDELITY SERVICES RENDER: PASS"); quit()
