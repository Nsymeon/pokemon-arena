extends RefCounted
var c
var players=[]
var cache={}
const DEFAULT_VOLUME=0.65
const DEFAULT_CRY_VOLUME=0.25
var volume=DEFAULT_VOLUME
var cry_volume=DEFAULT_CRY_VOLUME
const DEFAULT_MUSIC_VOLUME=0.3
var music_volume=DEFAULT_MUSIC_VOLUME
var music: AudioStreamPlayer
var music_key=""
var preview_music=false
var music_manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music/manifest.json"))
var cursor=0
var muted=false

func install(context):
	c=context
	music=AudioStreamPlayer.new(); c.add_child(music)
	for i in range(12):
		var player=AudioStreamPlayer.new(); c.add_child(player); players.append(player)
	if FileAccess.file_exists("user://audio-settings.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string("user://audio-settings.json"))
		load_settings(saved)

func load_settings(saved):
	volume=DEFAULT_VOLUME; cry_volume=DEFAULT_CRY_VOLUME; music_volume=DEFAULT_MUSIC_VOLUME
	if not saved is Dictionary: return
	if (saved.get("volume") is float or saved.get("volume") is int) and is_finite(float(saved.volume)): volume=clampf(saved.volume,0,1)
	if (saved.get("cry_volume") is float or saved.get("cry_volume") is int) and is_finite(float(saved.cry_volume)): cry_volume=clampf(saved.cry_volume,0,1)

	if (saved.get("music_volume") is float or saved.get("music_volume") is int) and is_finite(float(saved.music_volume)): music_volume=clampf(saved.music_volume,0,1)

func set_music_volume(value):
	music_volume=clampf(value,0,1); refresh_volume(); save_settings()

func update_music():
	if music==null or c.adventure==null: return
	var key=""
	if c.adventure.exploring and c.adventure.world.enabled:
		key=music_manifest.maps.get(c.adventure.world.current,"")
	if preview_music and c.frontend.layer!=null and c.frontend.layer.visible: key="MUS_PALLET"
	if key!=music_key:
		music_key=key; music.stop(); music.stream=null
		var path="res://assets/audio/music/"+str(music_manifest.tracks.get(key,{}).get("file",""))
		if FileAccess.file_exists(path):
			if path.ends_with(".ogg"): music.stream=AudioStreamOggVorbis.load_from_file(path)
			else:
				var stream=AudioStreamMP3.new(); stream.data=FileAccess.get_file_as_bytes(path); music.stream=stream
			if music.stream: music.stream.loop=true
	if music.stream and not music.playing and not muted and DisplayServer.get_name()!="headless": music.play()
	music.stream_paused=muted or volume*music_volume<=0
	music.volume_db=linear_to_db(maxf(0.0001,volume*music_volume))

func voice_volume(player):
	return volume*float(player.get_meta("gain",1.0))*(cry_volume if player.get_meta("cry",false) else 1.0)

func refresh_volume():
	if music:
		music.volume_db=linear_to_db(maxf(0.0001,volume*music_volume))
		music.stream_paused=muted or volume*music_volume<=0
	for player in players:
		player.volume_db=linear_to_db(maxf(0.0001,voice_volume(player)))
		if voice_volume(player)<=0: player.stop()

func save_settings():
	if OS.get_cmdline_user_args().is_empty():
		var file=FileAccess.open("user://audio-settings.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify({"volume":volume,"cry_volume":cry_volume,"music_volume":music_volume}))

func set_volume(value):
	volume=clampf(value,0,1); refresh_volume(); save_settings()
	if is_instance_valid(c.sound):
		c.sound.volume_db=linear_to_db(maxf(volume,0.0001))
		if volume<=0: c.sound.stop()

func set_cry_volume(value):
	cry_volume=clampf(value,0,1); refresh_volume(); save_settings()

func play(stream,gain=1.0,is_cry=false):
	if muted or volume<=0 or (is_cry and cry_volume<=0) or DisplayServer.get_name()=="headless" or stream==null: return
	var player=players[cursor%players.size()]; cursor+=1
	player.set_meta("gain",gain); player.set_meta("cry",is_cry)
	player.stream=stream; player.volume_db=linear_to_db(maxf(0.0001,voice_volume(player))); player.play()

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
	if cache.has(key): play(cache[key],1.0,true)

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
	var saved_volume=volume; var saved_cries=cry_volume; var saved_music=music_volume
	load_settings({"volume":0.7})
	c.check(is_equal_approx(volume,0.7) and is_equal_approx(cry_volume,0.25),"Legacy audio settings keep master and quieter default cries")
	load_settings({"volume":2,"cry_volume":-1})
	c.check(volume==1 and cry_volume==0,"Audio settings clamp independently")
	var voice=players[0]; voice.set_meta("gain",0.5); voice.set_meta("cry",true)
	volume=0.8; cry_volume=0.25
	c.check(is_equal_approx(voice_volume(voice),0.1),"Cry channel preserves gain")
	voice.set_meta("cry",false)
	c.check(is_equal_approx(voice_volume(voice),0.4),"Cry volume leaves effects unchanged")
	load_settings({"volume":0.8,"cry_volume":0.25,"music_volume":0.45})
	c.check(is_equal_approx(music_volume,0.45) and is_equal_approx(cry_volume,0.25),"Music slider persists independently from cries")
	for track in music_manifest.tracks.values():
		if track.get("pending",false): continue
		var stream=AudioStreamOggVorbis.load_from_file("res://assets/audio/music/"+track.file)
		c.check(stream!=null and stream.get_length()>1,"Town soundtrack decodes: "+track.file)
	for mon in c.roster:
		if int(mon.id)<=151: c.check(c.adventure.collection.entries.has(str(int(mon.id))),"Kanto species has Pokedex description: "+mon.name)
	volume=saved_volume; cry_volume=saved_cries; music_volume=saved_music; refresh_volume()
	muted=previous
