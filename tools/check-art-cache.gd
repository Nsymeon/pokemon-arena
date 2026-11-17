extends SceneTree
func _initialize():
	var art=load("res://battle_art.gd").new(); art.load_sprites(); var failures=[]
	if art.library.size()!=388 or art.shiny_library.size()!=388 or art.texture_bytes!=0: failures.append("Startup should load metadata without all textures")
	var first=art.entry_for({"id":25}); var width=first.Idle.texture.get_width()
	for id in art.library:
		for shiny in [false,true]:
			var entry=art.entry_for({"id":id,"shiny":shiny})
			if entry.is_empty(): failures.append("Missing art: "+str(id)); continue
			for animation in entry.values():
				if animation.texture.get_width()!=int(animation.width)*animation.durations.size() or animation.rows not in [1,8]: failures.append("Bad animation layout: "+str(animation.path))
			if art.cache_order.size()>art.CACHE_ENTRIES or art.texture_bytes>art.CACHE_BYTES and art.cache_order.size()>1: failures.append("Unbounded animation cache")
	if first.Idle.has("texture"): failures.append("Old species should be evicted after walking the full roster")
	if art.entry_for({"id":25}).Idle.texture.get_width()!=width: failures.append("Evicted species did not reload")
	var normal=art.entry_for({"id":25}); var shiny=art.entry_for({"id":25,"shiny":true})
	if normal.Idle.texture==shiny.Idle.texture: failures.append("Normal and shiny texture banks must stay separate")
	print("ART CACHE CHECK: ",failures," / 776 variants / cached bytes ",art.texture_bytes," / entries ",art.cache_order.size())
	quit(0 if failures.is_empty() else 1)
