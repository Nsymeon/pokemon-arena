extends RefCounted
# Shared chibi rig: named limbs are the animation contract with KantoWorld3D.
func build(k, config: Dictionary, identity: String) -> Node3D:
	var root=Node3D.new(); var tag=identity.to_lower()
	var player=identity=="player"
	var oak="oak" in tag; var nurse="nurse" in tag or tag=="heal"
	var scientist="scientist" in tag; var rocket="rocket" in tag
	var blue=tag=="rival" or "blue" in tag
	var misty="misty" in tag; var brock="brock" in tag
	var female=config.get("gender","boy")=="girl" or nurse or misty or ["woman","girl","lass","mom","erika","sabrina","lorelei","agatha"].any(func(word):return word in tag)
	var shirt=str(config.get("shirt","6b9dc1")); var pants=str(config.get("pants","536779")); var hair=str(config.get("hair","6c4938")); var shoes=str(config.get("shoes","6a5546"))
	var skin="f2c49f"
	if oak: shirt="ece6d8"; pants="827261"; hair="a6a49d"
	if scientist: shirt="ece6d8"; pants="577988"
	if nurse: shirt="e58eac"; pants="eee4d7"; hair="bc627f"; shoes="eee4d7"
	if rocket: shirt="343e50"; pants="343e50"; shoes="bfc4cc"
	if blue: shirt="6561a3"; pants="54566c"; hair="966336"
	if misty: shirt="e8c952"; pants="6395b5"; hair="cd753a"
	if brock: shirt="799354"; pants="9b815d"; hair="53443b"; skin="d8ae83"
	# Short, separate legs and shaped sneakers; shoulders no longer form a ball.
	for side in [-1,1]:
		var leg=Node3D.new(); leg.name="LeftLeg" if side<0 else "RightLeg"; leg.position=Vector3(side*.145,.43,0); root.add_child(leg)
		k.shape(leg,"ball",Vector3(0,-.11,0),Vector3(.225,.43,.25),pants)
		k.shape(leg,"ball",Vector3(0,-.31,.075),Vector3(.265,.16,.39),shoes)
		k.shape(leg,"ball",Vector3(0,-.365,.08),Vector3(.28,.065,.4),"e9e7df")
		for lace in 2: k.shape(leg,"box",Vector3(0,-.25,.16+lace*.045),Vector3(.14,.018,.018),"eee7da")
		var arm=Node3D.new(); arm.name="LeftArm" if side<0 else "RightArm"; arm.position=Vector3(side*.30,.85,0); root.add_child(arm)
		k.shape(arm,"ball",Vector3(side*.015,-.04,0),Vector3(.22,.31,.25),shirt)
		k.shape(arm,"ball",Vector3(side*.025,-.22,.015),Vector3(.145,.22,.16),skin)
		k.shape(arm,"ball",Vector3(side*.025,-.32,.025),Vector3(.17,.16,.18),skin)
		k.shape(arm,"ball",Vector3(side*-.045,-.31,.1),Vector3(.065,.09,.08),skin)
	k.shape(root,"torso",Vector3(0,.72,0),Vector3(.58,.6,.44),shirt)
	k.shape(root,"cylinder",Vector3(0,1.02,0),Vector3(.2,.16,.2),skin)
	k.shape(root,"box",Vector3(0,.49,.21),Vector3(.4,.035,.035),"eee3cf")
	if oak or scientist:
		k.shape(root,"box",Vector3(0,.78,.235),Vector3(.21,.42,.025),"a69379")
		for side in [-1,1]:
			var lapel=k.shape(root,"box",Vector3(side*.115,.88,.26),Vector3(.13,.29,.03),"fffaed"); lapel.rotation.z=side*-.23
			k.shape(root,"box",Vector3(side*.18,.61,.235),Vector3(.13,.1,.025),"d3cfc5")
	elif nurse:
		k.shape(root,"torso",Vector3(0,.57,0),Vector3(.63,.3,.46),shirt)
		k.shape(root,"ball",Vector3(0,.69,.22),Vector3(.35,.42,.055),"f8f0df")
	elif rocket:
		for part in [[0,.85,.2,.04],[0,.73,.18,.04],[-.08,.79,.04,.24],[.08,.81,.04,.12]]:
			k.shape(root,"box",Vector3(part[0],part[1],.235),Vector3(part[2],part[3],.025),"d84e61")
		var stroke=k.shape(root,"box",Vector3(.045,.67,.235),Vector3(.04,.15,.025),"d84e61"); stroke.rotation.z=.5
	else:
		k.shape(root,"box",Vector3(0,.78,.225),Vector3(.018,.4,.018),"dedbcf")
		for side in [-1,1]: k.shape(root,"box",Vector3(side*.14,.87,.22),Vector3(.12,.035,.025),"d8d8cb")
	# Round head, inset anime eyes and small ears, without protruding eyeballs.
	var head=Node3D.new(); head.name="Head"; root.add_child(head)
	k.shape(head,"ball",Vector3(0,1.4,0),Vector3(.91,.86,.79),skin)
	for side in [-1,1]:
		k.shape(head,"ball",Vector3(side*.442,1.35,-.005),Vector3(.13,.2,.16),skin)
		k.shape(head,"ball",Vector3(side*.459,1.35,.055),Vector3(.055,.11,.035),"d69f88")
		if brock:
			k.shape(head,"ball",Vector3(side*.17,1.4,.38),Vector3(.15,.025,.018),"53443b")
		else:
			k.shape(head,"ball",Vector3(side*.17,1.39,.366),Vector3(.145,.215,.025),"fcf8ef")
			k.shape(head,"ball",Vector3(side*.17,1.385,.384),Vector3(.076,.151,.018),"63503f")
			k.shape(head,"ball",Vector3(side*.17,1.398,.396),Vector3(.042,.11,.012),"293b43")
			k.shape(head,"ball",Vector3(side*.15,1.433,.406),Vector3(.026,.038,.01),"ffffff")
		k.shape(head,"ball",Vector3(side*.17,1.496,.364),Vector3(.16,.025,.022),hair)
		k.shape(head,"ball",Vector3(side*.17,1.535,.343),Vector3(.14,.028,.025),hair)
	k.shape(head,"ball",Vector3(0,1.3,.393),Vector3(.055,.06,.055),skin)
	k.shape(head,"ball",Vector3(0,1.22,.354),Vector3(.105,.022,.018),"ab756a")
	k.shape(head,"haircap",Vector3(0,1.52,-.055),Vector3(.96,.65,.86),hair)
	k.shape(head,"ball",Vector3(0,1.44,-.28),Vector3(.77,.56,.24),hair)
	for fringe in 5:
		var lock=k.shape(head,"ball",Vector3(-.29+fringe*.14,1.58+float(fringe%2)*.025,.26),Vector3(.19,.24,.11),hair)
		lock.rotation.z=-.25
	if blue or brock:
		for spike in 5:
			var lock=k.shape(head,"canopy",Vector3(-.30+spike*.15,1.68,-.04),Vector3(.28,.32+float(spike%2)*.13,.29),hair)
			lock.rotation.z=(2-spike)*-.18
	if female and not misty:
		for side in [-1,1]:
			k.shape(head,"ball",Vector3(side*.42,1.15,-.14),Vector3(.24,.72,.3),hair)
	if nurse or misty:
		for side in [-1,1]:
			if misty and side<0: continue
			k.shape(head,"ball",Vector3(side*.48,1.48,-.12),Vector3(.28,.35,.3),hair)
	if nurse:
		k.shape(head,"ball",Vector3(0,1.84,.02),Vector3(.66,.19,.48),"f7f1e5")
		k.shape(head,"box",Vector3(0,1.86,.25),Vector3(.17,.045,.018),"ce697d")
		k.shape(head,"box",Vector3(0,1.86,.25),Vector3(.045,.13,.02),"ce697d")
	if player:
		k.shape(head,"haircap",Vector3(0,1.68,-.04),Vector3(.96,.4,.88),shirt)
		k.shape(head,"ball",Vector3(0,1.68,.32),Vector3(.8,.065,.43),"f2e9d8")
		k.shape(head,"ball",Vector3(0,1.77,.36),Vector3(.19,.15,.025),"f2e9d8")
		k.shape(root,"ball",Vector3(0,.78,-.28),Vector3(.45,.52,.22),"ac8259")
		k.shape(root,"box",Vector3(0,.69,-.405),Vector3(.3,.17,.04),"c49d70")
		for side in [-1,1]: k.shape(root,"box",Vector3(side*.20,.81,.21),Vector3(.055,.34,.035),"997454")
	return root
