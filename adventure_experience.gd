extends RefCounted
var species: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/kanto/experience.json"))

func total(id: int, level: int) -> int:
	if level<=1: return 0
	var n=float(level); var cube=n*n*n
	match str(species.get(str(id),{}).get("growth","MEDIUM_FAST")):
		"FAST": return int(4*cube/5)
		"SLOW": return int(5*cube/4)
		"MEDIUM_SLOW": return maxi(0,int(6*cube/5-15*n*n+100*n-140))
		"ERRATIC":
			return int(cube*(100-n)/50) if n<=50 else int(cube*(150-n)/100) if n<=68 else int(cube*floor((1911-10*n)/3)/500) if n<=98 else int(cube*(160-n)/100)
		"FLUCTUATING":
			return int(cube*(floor((n+1)/3)+24)/50) if n<=15 else int(cube*(n+14)/50) if n<=36 else int(cube*(floor(n/2)+32)/50)
	return int(cube)

func needed(mon) -> int:
	return maxi(1,total(int(mon.id),mini(100,int(mon.level)+1))-total(int(mon.id),int(mon.level)))

func migrate(mon):
	if int(mon.get("xp_curve",0))==2: return
	var fraction=clampf(float(mon.xp)/(20+int(mon.level)*6),0,.999)
	mon.xp=0 if mon.level>=100 else int(fraction*needed(mon))
	mon["xp_curve"]=2

func reward(id: int, level: int, trainer: bool) -> int:
	return maxi(1,int(float(species.get(str(id),{}).get("yield",100))*level/7.0*(1.5 if trainer else 1.0)))
