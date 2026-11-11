extends MinigameBase
## Stampf-Wellen: Runde Kristallbühne über dem Sternenhimmel. B = Stampfer (kurzer Hüpfer, bei der Landung
## läuft ein Wellenring los). Wellen werfen alle am Boden nach außen – A = drüberspringen. Dazu rollen
## Bühnenwellen von der Mitte. Wer runterfällt, ist raus; Wellentreffer zählen bei Gleichstand.
## Online: Host-Modell (Host simuliert Wellen und Treffer).

const R := 9.0
const WAVE_V := 7.5
const WAVE_MAX := 8.0
const STOMP_CD := 1.4

var _waves: Array[Dictionary] = []   # {c: Vector3, r, owner, node, hit:{}}
var _cd: Array[float] = [0, 0, 0, 0]
var _stomping: Array[bool] = [false, false, false, false]
var _stage_t := 4.0


func _init() -> void:
	game_id = "stomp_waves"
	fair_spawns = true   # Startplätze jede Runde neu auslosen (kein fester Platzvorteil)
	env_preset = "observatory"
	backdrop_style = "sky_dusk"
	time_limit = 45.0
	survival = true
	hazard = "fall"
	kill_y = -6.0
	arena_radius = 9.5
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 13)
	net_model = "host"
	spawn_points = [Vector3(-3.5, 0.6, -3), Vector3(3.5, 0.6, -3), Vector3(-3.5, 0.6, 3), Vector3(3.5, 0.6, 3)]


func build_arena() -> void:
	WorldKit.cylinder(world, R, 0.6, Vector3(0, -0.3, 0), Color("#3b2f7a"))
	for k in 4:
		var rr := MgKit.ring(world, 2.0 + k * 2.2, 0.08, Color(0.75, 0.6, 1.0, 0.7), 1.2)
		rr.position.y = 0.02
	# Kristalle und schwebende Sterne rund um die Bühne
	for i in 10:
		var a := TAU * i / 10.0
		WorldKit.place(world, "space/rock_crystals" if i % 2 else "space/rock_crystals_b", Vector3(cos(a) * 13.0, -3.0, sin(a) * 13.0), randf() * 360.0, 2.4)
	for i in 6:
		var a2 := TAU * i / 6.0 + 0.4
		var st := WorldKit.place(world, "plat/star", Vector3(cos(a2) * 11.0, 3.0 + i % 3, sin(a2) * 11.0), 0.0, 1.6)
		var tw := st.create_tween().set_loops()
		tw.tween_property(st, "rotation:y", TAU, 6.0 + i).as_relative()


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 14.5, 12.5)
	c.min_dist = 0.9
	c.max_dist = 1.1


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).can_shove = false
		(av as PartyAvatar).rig.surface = "metal"


func on_tick(delta: float) -> void:
	var prog := 1.0 - time_left / time_limit
	for i in active_slots():
		_cd[i] = maxf(0.0, _cd[i] - delta)
		var av := avatars[i] as PartyAvatar
		if not av.alive:
			continue
		if InputHub.pressed(i, "b") and _cd[i] <= 0.0 and av.is_on_floor() and not _stomping[i]:
			_stomping[i] = true
			_cd[i] = STOMP_CD
			av.velocity.y = 7.5
			av.rig.play("jump_start", 0.08, 1.6, true)
			Audio.sfx("woop", av.global_position, -6.0, 1.3)
		elif _stomping[i] and av.velocity.y < 0.0 and av.is_on_floor():
			_stomping[i] = false
			_spawn_wave(av.global_position, i)
			av.rig.land_impact(1.2)
	_stage_t -= delta
	if _stage_t <= 0.0:
		_stage_t = lerpf(4.5, 2.4, prog)
		_spawn_wave(Vector3.ZERO, -1)
	var k := _waves.size() - 1
	while k >= 0:
		var w := _waves[k]
		w.r = float(w.r) + WAVE_V * delta
		var node: Node3D = w.node
		node.scale = Vector3(float(w.r), 1.0, float(w.r))
		var m := ((node as MeshInstance3D).mesh as TorusMesh).material as StandardMaterial3D
		m.albedo_color.a = clampf(1.0 - float(w.r) / WAVE_MAX, 0.0, 1.0)
		for j in active_slots():
			var av2 := avatars[j] as PartyAvatar
			if j == int(w.owner) or not av2.alive or (w.hit as Dictionary).has(j):
				continue
			var off := av2.global_position - (w.c as Vector3)
			off.y = 0.0
			if absf(off.length() - float(w.r)) < 0.5 and av2.global_position.y < 0.35:
				(w.hit as Dictionary)[j] = true
				av2.apply_knockback(off.normalized() if off.length() > 0.01 else Vector3.FORWARD, 12.5 if int(w.owner) >= 0 else 10.0, 0.55, 4.5)
				av2.rig.react("hit")
				FX.sparks(av2.global_position + Vector3.UP, Color(0.75, 0.6, 1.0), 10)
				Audio.sfx("hit_soft", av2.global_position)
				if int(w.owner) >= 0:
					add_score(int(w.owner), 1.0)
		if float(w.r) >= WAVE_MAX:
			node.queue_free()
			_waves.remove_at(k)
		k -= 1


func _spawn_wave(at: Vector3, owner: int) -> void:
	var col := Color(0.8, 0.65, 1.0, 1.0) if owner < 0 else Game.player_color(owner).lightened(0.25)
	var ring := MgKit.ring(world, 1.0, 0.09, col, 2.0)
	ring.position = Vector3(at.x, 0.12, at.z)
	ring.scale = Vector3(0.3, 1, 0.3)
	_waves.append({"c": Vector3(at.x, 0, at.z), "r": 0.3, "owner": owner, "node": ring, "hit": {}, "id": ring.get_instance_id()})
	Audio.sfx("woom", at, -4.0 if owner < 0 else -2.0)
	FX.ring(at + Vector3.UP * 0.1, Color(col.r, col.g, col.b, 0.8), 2.0, 0.3)
	Juice.shake(0.1 if owner < 0 else 0.18)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["w"] = _waves.map(func(w: Dictionary) -> Array: return [snappedf((w.c as Vector3).x, 0.1), snappedf((w.c as Vector3).z, 0.1), snappedf(float(w.r), 0.05), int(w.owner)])
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var ws: Array = d.get("w", [])
	# Wellen darstellen: neue anlegen, Radien übernehmen, alte entfernen
	while _waves.size() < ws.size():
		var e: Array = ws[_waves.size()]
		_spawn_wave(Vector3(float(e[0]), 0, float(e[1])), int(e[3]))
	while _waves.size() > ws.size():
		(_waves[0].node as Node3D).queue_free()
		_waves.remove_at(0)
	for k in ws.size():
		var e2: Array = ws[k]
		_waves[k].r = float(e2[2])
		(_waves[k].node as Node3D).position = Vector3(float(e2[0]), 0.12, float(e2[1]))
		(_waves[k].node as Node3D).scale = Vector3(float(e2[2]), 1, float(e2[2]))


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not av.alive:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var p := av.global_position
	var held := {}
	var mv := Vector2.ZERO
	# Welle naht? Springen, kurz bevor das Band ankommt (pro Welle einmal entscheiden, ob die CPU patzt)
	var mem: Dictionary = cpu_mem[slot]
	if not mem.has("miss"):
		mem["miss"] = {}
	for w in _waves:
		if int(w.owner) == slot:
			continue
		if not (mem.miss as Dictionary).has(w.id):
			mem.miss[w.id] = randf() < Game.lv([0.35, 0.18, 0.07], level, true)
		if bool(mem.miss[w.id]):
			continue
		var gap := Vector2(p.x - (w.c as Vector3).x, p.z - (w.c as Vector3).z).length() - float(w.r)
		if gap > 0.0 and gap / WAVE_V < Game.lv([0.16, 0.12, 0.09], level) + 0.05 and av.is_on_floor():
			held["a"] = true
	# Gegner in Stampf-Reichweite suchen, aber nicht zu nah an den Rand
	var best: PartyAvatar = null
	var bd := INF
	for o in avatars:
		var oa := o as PartyAvatar
		if oa != av and oa.alive:
			var dd := oa.global_position.distance_to(p)
			if dd < bd:
				bd = dd
				best = oa
	if best:
		var to := best.global_position - p
		mv = Vector2(to.x, to.z).normalized() * (1.0 if bd > 3.5 else -0.3)
		if bd < 4.0 and _cd[slot] <= 0.0 and randf() < Game.lv([0.01, 0.025, 0.04], level):
			held["b"] = true
	var r := Vector2(p.x, p.z).length()
	if r > R * 0.6:
		mv = mv * 0.3 - Vector2(p.x, p.z).normalized() * (r / R) * 1.6
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)
