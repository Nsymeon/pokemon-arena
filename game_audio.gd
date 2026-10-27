extends RefCounted
var c
var players=[]
var cache={}
var volume=0.65
var cursor=0
var muted=false

func install(context):
	c=context
	for i in range(12):
		var player=AudioStreamPlayer.new(); c.add_child(player); players.append(player)
	if FileAccess.file_exists("user://audio-settings.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string("user://audio-settings.json"))
		if saved is Dictionary and (saved.get("volume") is float or saved.get("volume") is int): volume=clampf(saved.volume,0,1)

func set_volume(value):
	volume=clampf(value,0,1)
	for player in players: player.volume_db=linear_to_db(maxf(volume,0.0001))
	if OS.get_cmdline_user_args().is_empty():
		var file=FileAccess.open("user://audio-settings.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify({"volume":volume}))

func play(stream,gain=1.0):
	if muted or volume<=0 or DisplayServer.get_name()=="headless" or stream==null: return
	var player=players[cursor%players.size()]; cursor+=1
	player.stream=stream; player.volume_db=linear_to_db(maxf(0.0001,volume*gain)); player.play()

func effect(key,frequency=300.0,duration=0.18,noise=0.25):
	if not cache.has(key):
		var stream=AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=22050
		var bytes=PackedByteArray(); var count=int(22050*duration); bytes.resize(count*2)
		var rng=RandomNumberGenerator.new(); rng.seed=hash(key)
		for i in range(count):
			var t=float(i)/22050; var envelope=sin(PI*float(i)/count)*pow(1-float(i)/count,1.5)
			var wave=sin(TAU*frequency*(t-0.7*t*t))+0.3*sin(TAU*frequency*2.03*t)
			var sample=int(clampf((wave*(1-noise)+rng.randf_range(-1,1)*noise)*envelope*0.28,-1,1)*32767)
			bytes.encode_s16(i*2,sample)
		stream.data=bytes; cache[key]=stream
	play(cache[key])

func cry(id):
	var key="cry:"+str(id)
	if not cache.has(key):
		var path="res://assets/audio/cries/"+str(id)+".ogg"
		if not FileAccess.file_exists(path): path="res://assets/audio/cries/"+str(id)+".mp3"
		if FileAccess.file_exists(path):
			var bytes=FileAccess.get_file_as_bytes(path)
			if bytes.slice(0,4).get_string_from_ascii()=="OggS": cache[key]=AudioStreamOggVorbis.load_from_file(path)
			else:
				var stream=AudioStreamMP3.new(); stream.data=bytes; cache[key]=stream
	if cache.has(key): play(cache[key],0.65)

func move(move):
	var type=str(move.get("type","Normal"))
	var pitch={"Fire":140,"Water":220,"Electric":950,"Grass":520,"Ice":1200,"Psychic":680,"Ghost":95,"Rock":80,"Ground":65,"Steel":1450,"Flying":440,"Dragon":175,"Dark":110,"Fairy":860,"Fighting":120,"Poison":260,"Bug":730}.get(type,350)
	effect("cast:"+type,pitch,0.3 if move.get("damage",0)>0 else 0.45,0.7 if type in ["Water","Fire","Flying","Ground"] else 0.2)

func step(surface):
	effect("step:"+surface,{"grass":180,"water":330,"cave":95,"floor":260}.get(surface,220),0.065,0.8)

func tests():
	var previous=muted; muted=true
	for mon in c.roster:
		cry(int(mon.id))
		c.check(cache.has("cry:"+str(int(mon.id))) and cache["cry:"+str(int(mon.id))]!=null,"Decodable cry asset: "+mon.name)
	for type in ["Fire","Water","Electric","Grass","Ice","Psychic","Ghost","Rock","Ground","Steel","Flying","Dragon","Dark","Fairy","Fighting","Poison","Bug","Normal"]:
		move({"type":type,"damage":30})
		c.check(cache.has("cast:"+type) and cache["cast:"+type].data.size()>0,"Attack audio generated: "+type)
	muted=previous
