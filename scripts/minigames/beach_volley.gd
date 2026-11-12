extends MinigameBase
## Strand-Volley (2 gegen 2): Ein Wasserball, ein Netz, zwei Teams.
##   * Annahme: Wer unter den Ball läuft, baggert ihn hinüber – und zwar dorthin, wohin der Stick zeigt
##     (zum Gegner-Grundlinie = lang, zurück = kurz, hoch/runter = Seiten). Ohne Stick: Feldmitte.
##   * Trefferqualität ist Physik, kein Zufall: Wer den Ball nicht mittig trifft, verzieht seitlich; wer hinter dem
##     Ball steht, spielt lang, wer zu weit vorne steht, kurz.
##   * Springen (A) und in der Luft B am Netz = Schmetterball: flach und schnell aufs anvisierte Feld – muss aber
##     über die Netzkante. Wer am Netz hochspringt, kann einen Schmetterball blocken.
##   * Spieler kommen nicht durchs Netz (feste Feldgrenze), der Ball prallt unterhalb der Netzkante zurück.
## Landet der Ball im Feld, punktet das andere Team; im Aus punktet der Gegner des letzten Spielers.
## Zuerst 7 Punkte oder die meisten Punkte nach Ablauf der Zeit. Online: Host-Modell.

const HALF_X := 8.0
const HALF_Z := 4.2
const NET_H := 2.3
const BALL_R := 0.45
const GRAV := 13.0
const WIN := 7
const NET_GAP := 0.5          # Körperabstand zum Netz (Feldgrenze)
const HIT_R := 0.65           # Reichweite um den Kopf
const SPIKE_V := 15.5

var _ball: Node3D
var _bpos := Vector3.ZERO
var _bvel := Vector3.ZERO
var _serve_t := 1.0
var _serve_side := 0
var _pts := [0, 0]
var _last_hit := -1
var _hit_cd: Array[float] = [0, 0, 0, 0]
var _shadow: MeshInstance3D
var _score_lbl: Label3D
var _rally := 0
var _touch_n := [0, 0]        # Berührungen je Team seit der Ball auf diese Seite kam (max. 2: Zuspiel + Angriff)
var _log := "--volley-log" in OS.get_cmdline_user_args()


func _init() -> void:
	game_id = "beach_volley"
	env_preset = "pirates"
	backdrop_style = "beach"
	time_limit = 75.0
	score_format = "%d"
	arena_radius = 9.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 9)
	net_model = "host"
	spawn_points = [Vector3(-4, 0.6, -1.5), Vector3(4, 0.6, -1.5), Vector3(-4, 0.6, 1.5), Vector3(4, 0.6, 1.5)]


func on_setup() -> void:
	var c := [0, 0]
	for i in 4:
		var t := teams[i]
		spawn_points[i] = Vector3(-4.5 if t == 0 else 4.5, 0.6, -1.6 + c[t] * 3.2)
		c[t] += 1


func build_arena() -> void:
	WorldKit.water(world, Vector2(80, 80), -0.6, Color(0.06, 0.4, 0.65), Color(0.3, 0.8, 0.9))
	WorldKit.box(world, Vector3(26, 1.0, 16), Vector3(0, -0.5, 0), Color("#f2d9a0"))
	# Spielfeldlinien, Netz mit Pfosten, unsichtbare Netzwand für Figuren
	for z in [-HALF_Z, HALF_Z]:
		WorldKit.box(world, Vector3(HALF_X * 2, 0.02, 0.12), Vector3(0, 0.01, z), Color("#ffffff"), false)
	for x in [-HALF_X, HALF_X]:
		WorldKit.box(world, Vector3(0.12, 0.02, HALF_Z * 2), Vector3(x, 0.01, 0), Color("#ffffff"), false)
	WorldKit.box(world, Vector3(0.1, 0.9, HALF_Z * 2 + 0.6), Vector3(0, NET_H - 0.45, 0), Color(1, 1, 1, 1), false)
	for k in 9:
		WorldKit.box(world, Vector3(0.06, 0.06, HALF_Z * 2 + 0.6), Vector3(0, NET_H - 0.9 + k * 0.11, 0), Color("#3a3a46"), false)
	for z in [-HALF_Z - 0.4, HALF_Z + 0.4]:
		WorldKit.cylinder(world, 0.1, NET_H + 0.2, Vector3(0, (NET_H + 0.2) * 0.5, z), Color("#d9d9e0"), false)
	# Unsichtbare Netzwand für Figuren (Kollision bleibt, Optik aus)
	var wall := WorldKit.box(world, Vector3(0.3, 4.0, HALF_Z * 2 + 1.0), Vector3(0, 2.0, 0), Color(0, 0, 0, 0))
	for m in wall.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).visible = false
	# Strandleben: Palmen, Liegestühle, Schirm, Muscheln, Kokosnüsse, Steg
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		WorldKit.place(world, "pirate/palm", Vector3(cos(a) * 12.0, 0, sin(a) * 8.0), randf() * 360.0, 0.9)
	WorldKit.scatter(world, ["mt/shell", "mt/shell_b", "mt/starfish"], 20, Vector3.ZERO, 9.0, 12.0, 0.02)
	WorldKit.place(world, "city/parasol", Vector3(-10.0, 0, -6.0), 20.0, 1.4)
	WorldKit.place(world, "mt/coconut", Vector3(10.0, 0, -6.0), 0.0, 2.0)
	WorldKit.place(world, "mt/dock", Vector3(11.0, -0.4, 6.0), 90.0, 2.0)
	_ball = Node3D.new()
	_ball.set_meta("keep_visible", true)
	world.add_child(_ball)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	mi.mesh = sm
	mi.material_override = WorldKit.mat(Color("#ffffff"), 0.4)
	_ball.add_child(mi)
	for k in 3:
		var band := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = BALL_R * 0.98
		tm.outer_radius = BALL_R * 1.03
		band.mesh = tm
		band.material_override = WorldKit.mat([Color("#ff4d6d"), Color("#ffd23f"), Color("#4da6ff")][k], 0.4)
		band.rotation = Vector3(k * PI / 3.0, 0, PI / 2.0)
		mi.add_child(band)
	_shadow = MgKit.warn_disc(world, Vector3.ZERO, 0.5, Color(0, 0, 0, 0.35), 9999.0)
	_score_lbl = Label3D.new()
	_score_lbl.font_size = 160
	_score_lbl.outline_size = 30
	_score_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_score_lbl.position = Vector3(0, NET_H + 1.6, -HALF_Z - 0.4)
	world.add_child(_score_lbl)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 1.2, 0.4)
	c.offset = Vector3(0, 10.5, 11.5)
	c.min_dist = 0.95
	c.max_dist = 1.05


func on_start() -> void:
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		av.can_shove = false
		av.rig.surface = "sand"
		av.max_speed = 6.4
		# Netz als feste Feldgrenze (kein Durchrutschen, auch nicht im Sprung oder beim Gedränge)
		if teams[i] == 0:
			av.bound_min = Vector2(-HALF_X - 1.5, -HALF_Z - 1.5)
			av.bound_max = Vector2(-NET_GAP, HALF_Z + 1.5)
		else:
			av.bound_min = Vector2(NET_GAP, -HALF_Z - 1.5)
			av.bound_max = Vector2(HALF_X + 1.5, HALF_Z + 1.5)
	_serve(rng.randi() % 2)


func check_end() -> bool:
	return _pts[0] >= WIN or _pts[1] >= WIN


func _serve(side: int) -> void:
	_serve_side = side
	_serve_t = 1.1
	_bpos = Vector3(-5.8 if side == 0 else 5.8, 4.5, 0)   # Aufschlag von hinten (kein Schmettern direkt vom Aufschlag)
	_bvel = Vector3.ZERO
	_last_hit = -1
	_touch_n = [0, 0]


func on_tick(delta: float) -> void:
	for i in active_slots():
		_hit_cd[i] = maxf(0.0, _hit_cd[i] - delta)
	if _serve_t > 0.0:
		_serve_t -= delta
		_bpos.y = 4.5 + sin(_serve_t * 8.0) * 0.1
		if _serve_t <= 0.0:
			_bvel = Vector3(0.8 if _serve_side == 0 else -0.8, 2.0, 0.0)
	else:
		_bvel.y -= GRAV * delta
		var np := _bpos + _bvel * delta
		if signf(np.x) != signf(_bpos.x) and _bpos.x != 0.0:
			if not _try_block(np):
				# Netz: unterhalb der Netzkante prallt der Ball zurück
				if np.y < NET_H + BALL_R * 0.5:
					_bvel.x *= -0.45
					np.x = _bpos.x
					Audio.sfx("hit_soft", np, -6.0)
				else:
					_touch_n[1 if np.x > 0.0 else 0] = 0   # sauber rüber: Empfänger hat wieder zwei Berührungen
			else:
				np = _bpos + _bvel * delta
		_bpos = np
		if absf(_bpos.z) > HALF_Z + 3.0:
			_bvel.z *= -0.6
			_bpos.z = clampf(_bpos.z, -HALF_Z - 3.0, HALF_Z + 3.0)
		_touches()
		if _bpos.y <= BALL_R:
			_ground()
	_ball.position = _bpos
	_ball.rotation += Vector3(_bvel.z, 0, -_bvel.x) * delta * 0.8
	_shadow.position = Vector3(_bpos.x, 0.03, _bpos.z)
	_shadow.scale = Vector3.ONE * clampf(1.4 - _bpos.y * 0.12, 0.4, 1.4)
	_score_lbl.text = "%d : %d" % [_pts[0], _pts[1]]


## Block: Springt ein Spieler der Empfänger-Seite direkt am Netz hoch, prallt der Ball beim Überqueren zurück.
func _try_block(np: Vector3) -> bool:
	if np.y < NET_H - 0.2 or np.y > NET_H + 1.6:
		return false
	var recv := 1 if np.x > 0.0 else 0
	for i in active_slots():
		if teams[i] != recv or i == _last_hit:
			continue
		var av := avatars[i] as PartyAvatar
		var p := av.global_position
		if absf(p.x) < 1.4 and p.y > 0.45 and absf(p.z - np.z) < 0.95 and not av.is_on_floor():
			_bvel = Vector3(-_bvel.x * 0.45, -absf(_bvel.y) * 0.3 - 1.5, _bvel.z * 0.4)
			_last_hit = i
			_hit_cd[i] = 0.5
			FX.sparks(np, Color(0.6, 0.85, 1.0), 14)
			Audio.sfx("punch", np, -2.0, 0.8)
			Juice.shake(0.15)
			Juice.float_text(self, np + Vector3.UP, "Block!", Color("#9ad8ff"), 64)
			av.rig.play_once("punch", "idle", 1.6)
			return true
	return false


## Zielrichtung beim Treffer: Menschen per Stick (wohin er zeigt), CPUs per geplantem Zielpunkt.
func _aim_of(i: int) -> Vector2:
	if Game.players[i].cpu and cpu_mem[i].has("aim"):
		return cpu_mem[i].aim
	return InputHub.move(i)


func _touches() -> void:
	for i in active_slots():
		if _hit_cd[i] > 0.0 or i == _last_hit:
			continue   # niemand spielt zweimal hintereinander
		var av := avatars[i] as PartyAvatar
		var head := av.global_position + Vector3.UP * 1.3
		if head.distance_to(_bpos) < BALL_R + HIT_R:
			_hit(i, av, head)


func _hit(i: int, av: PartyAvatar, head: Vector3) -> void:
	_hit_cd[i] = 0.45
	_rally += 1
	var dir := 1.0 if teams[i] == 0 else -1.0
	var aim := _aim_of(i).limit_length(1.0)
	# Treffpunkt: Wie nah läuft die Flugbahn am Kopf vorbei (Stoßparameter)? Der Abstand beim ersten Kontakt ist
	# immer die Reichweite – entscheidend ist der seitliche Versatz quer zur Flugrichtung.
	var to_ball := _bpos - head
	var vdir := _bvel.normalized() if _bvel.length() > 0.5 else Vector3.DOWN
	var rel := to_ball - vdir * to_ball.dot(vdir)
	# Zielpunkt im gegnerischen Feld: Stick zeigt dorthin; Treffpunkt am Körper verzieht (Physik statt Würfel)
	var depth := clampf(4.4 + aim.x * dir * 2.8 + rel.x * dir * 1.1, 1.3, 7.6)
	var tz := clampf(aim.y * 3.5, -3.6, 3.6) + rel.z * 1.0
	var target := Vector3(dir * depth, BALL_R, tz)
	var team := teams[i]
	_touch_n[team] += 1
	# Harter Ball (Schmetterball) nicht mittig angenommen: prallt vom Arm ab – Reflexion an der Kontaktnormalen.
	# Gute Position = saubere Annahme, schlechte = Abpraller (meist ins Aus oder ins eigene Feld).
	var off := rel.length() / (BALL_R + HIT_R)
	if _bvel.length() > 10.0 and off > 0.55 and av.is_on_floor():
		var n := (to_ball.normalized() + rel.normalized()).normalized()
		_bvel = (_bvel - 2.0 * _bvel.dot(n) * n) * 0.5 + Vector3.UP * 3.5
		_last_hit = i
		Audio.sfx("hit_soft", _bpos, 0.0, 0.8)
		Juice.float_text(self, _bpos + Vector3.UP, "Abpraller!", Color("#ffb3a8"), 56)
		av.rig.play_once("punch", "idle", 1.6)
		if _log:
			print("[VOLLEY] t=%.1f Abpraller von %d (Versatz %.2f)" % [time_left, i, off])
		return
	var spike := not av.is_on_floor() and av.global_position.y > 0.6 and InputHub.held(i, "b") and absf(av.global_position.x) < 3.6 and _bpos.y > NET_H + 0.2
	# Zuspiel: Erste Berührung weit hinten geht hoch ans Netz zum Mitspieler (der schmettert dann) – außer man
	# drückt den Stick klar nach vorne (direkt rüberspielen). Die zweite Berührung geht immer rüber.
	var mate := -1
	for o in active_slots():
		if o != i and teams[o] == team:
			mate = o
	var setting := false
	if not spike and _touch_n[team] == 1 and mate >= 0 and absf(av.global_position.x) > 3.4 and aim.x * dir < 0.55:
		var mp := (avatars[mate] as PartyAvatar).global_position
		if absf(mp.x) < absf(av.global_position.x) - 1.0:
			setting = true
			target = Vector3(-dir * 1.5, BALL_R, clampf(mp.z, -HALF_Z + 0.6, HALF_Z - 0.6))
	if spike:
		# flach und schnell aufs Ziel; reicht die Höhe nicht über die Netzkante, wird der Schlag angehoben
		# (weiter weg vom Netz abgesprungen = flacher Drive, der eher ins Aus geht – eine echte Folge)
		var v := (target - _bpos).normalized() * SPIKE_V
		var t_net := absf(_bpos.x) / maxf(0.1, absf(v.x))
		var y_net := _bpos.y + v.y * t_net - 0.5 * GRAV * t_net * t_net
		var need_y := NET_H + BALL_R + 0.15
		if y_net < need_y:
			v.y += (need_y - y_net) / maxf(t_net, 0.05)
		_bvel = v
		FX.sparks(_bpos, Color(1, 0.9, 0.4), 12)
		Audio.sfx("punch", _bpos)
		Juice.shake(0.2)
		Juice.float_text(self, _bpos + Vector3.UP, "Schmetterball!", Color("#ffd166"), 60)
	else:
		# Bagger/Zuspiel: ballistischer Bogen genau auf den Zielpunkt. Stick klar nach vorne = flacher, schneller
		# Angriffsball; Zuspiel = hoher Ball ans Netz, damit der Mitspieler hochspringen kann.
		var drive := clampf(aim.x * dir, 0.0, 1.0)
		var apex := maxf(_bpos.y + 1.0, NET_H + 1.7 - 0.7 * drive)
		if setting:
			apex = maxf(_bpos.y + 0.8, 4.6)
		var vy := sqrt(2.0 * GRAV * (apex - _bpos.y))
		var t := vy / GRAV + sqrt(2.0 * (apex - BALL_R) / GRAV)
		_bvel = Vector3((target.x - _bpos.x) / t, vy, (target.z - _bpos.z) / t)
		Audio.sfx("boing", _bpos, -2.0)
	_last_hit = i
	if _log:
		print("[VOLLEY] t=%.1f Treffer %d von %d (%s) bei %s → Ziel %s, v=%s" % [time_left, _rally, i, "Schmetter" if spike else ("Zuspiel" if setting else "Bagger"), str(_bpos.snapped(Vector3.ONE * 0.1)), str(target.snapped(Vector3.ONE * 0.1)), str(_bvel.snapped(Vector3.ONE * 0.1))])
	av.rig.play_once("punch", "idle", 1.6)
	for k in 4:
		cpu_mem[k].erase("land")   # alle schätzen den neuen Ball neu


func _ground() -> void:
	var side := 0 if _bpos.x < 0.0 else 1
	var out := absf(_bpos.x) > HALF_X + 0.2 or absf(_bpos.z) > HALF_Z + 0.2
	# Aus = Punkt für den Gegner des letzten Spielers; im Feld = Punkt für den Gegner der Seite
	var scorer := 1 - side
	if out and _last_hit >= 0:
		scorer = 1 - teams[_last_hit]
	if _log:
		print("[VOLLEY] t=%.1f Boden bei %s %s → Punkt Team %d (Ballwechsel %d)" % [time_left, str(_bpos.snapped(Vector3.ONE * 0.1)), "AUS" if out else "im Feld", scorer, _rally])
	_pts[scorer] += 1
	FX.dust(Vector3(_bpos.x, 0.1, _bpos.z), Color(0.95, 0.85, 0.6), 18, 1.4)
	Audio.sfx("bell", _bpos, -4.0)
	for i in active_slots():
		if teams[i] == scorer:
			add_score(i, 1.0)
			(avatars[i] as PartyAvatar).rig.react("cheer")
		else:
			(avatars[i] as PartyAvatar).rig.react("frustrated")
	Juice.float_text(self, Vector3(_bpos.x, 1.5, _bpos.z), "Aus!" if out else "Punkt!", Color("#fff1a8"), 70)
	_rally = 0
	_serve(1 - scorer)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["b"] = [snappedf(_bpos.x, 0.01), snappedf(_bpos.y, 0.01), snappedf(_bpos.z, 0.01), _pts[0], _pts[1]]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var b: Array = d.get("b", [])
	if b.size() == 5:
		var np := Vector3(float(b[0]), float(b[1]), float(b[2]))
		_bvel = (np - _bpos) * 30.0
		_bpos = np
		if int(b[3]) + int(b[4]) != _pts[0] + _pts[1]:
			Audio.sfx("bell", _bpos, -4.0)
			FX.dust(Vector3(_bpos.x, 0.1, _bpos.z), Color(0.95, 0.85, 0.6), 18, 1.4)
		_pts = [int(b[3]), int(b[4])]
	_ball.position = _bpos
	_shadow.position = Vector3(_bpos.x, 0.03, _bpos.z)
	_score_lbl.text = "%d : %d" % [_pts[0], _pts[1]]


# --- CPU --------------------------------------------------------------------------------------------------------

## Wo passiert der Ball die Kontakthöhe (Kopf) im Sinkflug? Gibt [Punkt, Zeit] zurück (exakt wie die Spielphysik).
func _predict(contact_y := 1.6) -> Array:
	var v := _bvel
	var q := _bpos
	var t := 0.0
	if _serve_t > 0.0:
		q = Vector3(_bpos.x, 4.5, _bpos.z)
		v = Vector3(0.8 if _serve_side == 0 else -0.8, 2.0, 0.0)
		t = _serve_t
	for k in 240:
		v.y -= GRAV / 60.0
		var nq := q + v / 60.0
		if signf(nq.x) != signf(q.x) and q.x != 0.0 and nq.y < NET_H + BALL_R * 0.5:
			v.x *= -0.45
			nq.x = q.x
		q = nq
		t += 1.0 / 60.0
		if v.y < 0.0 and q.y <= contact_y:
			return [q, t]
	return [q, t]


func cpu_think(slot: int, delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	var p := av.global_position
	var mine := -1.0 if teams[slot] == 0 else 1.0
	var pr := _predict()
	var contact: Vector3 = pr[0]
	var t_c: float = pr[1]
	# Reaktion & Schätzfehler: neu einschätzen alle paar Zehntel; der Fehler schrumpft, je näher der Ball kommt
	mem["rt"] = float(mem.get("rt", 0.0)) - delta
	if float(mem.rt) <= 0.0 or not mem.has("land"):
		mem["rt"] = Game.lv_react([0.55, 0.32, 0.18, 0.1], level)
		var err: float = Game.lv([2.0, 1.05, 0.5, 0.15], level, true) * clampf(t_c / 1.2, 0.5, 1.0)
		mem["land"] = contact + Vector3(randf_range(-err, err), 0, randf_range(-err, err))
		mem["aim"] = _pick_aim(slot, level)
	var est: Vector3 = mem.land
	var coming := signf(est.x) == mine
	var mates: Array[int] = []
	for o in active_slots():
		if teams[o] == teams[slot]:
			mates.append(o)
	var other := -1
	for o in mates:
		if o != slot:
			other = o
	# Wer nimmt an? Der Nähere (mit Vorrang-Puffer, damit nicht beide zum Ball rennen und sich verkeilen)
	var mine_takes := true
	if other >= 0 and coming:
		var po := (avatars[other] as PartyAvatar).global_position
		var dm := Vector2(est.x - p.x, est.z - p.z).length()
		var do_ := Vector2(est.x - po.x, est.z - po.z).length()
		mine_takes = dm < do_ - 0.3 or (absf(dm - do_) <= 0.3 and slot < other)
	var front := other < 0 or absf(p.x) <= absf((avatars[other] as PartyAvatar).global_position.x)
	var target: Vector3
	var held := {}
	if coming and mine_takes:
		# leicht hinter den Kontaktpunkt (Richtung eigene Grundlinie) – so geht der Ball sauber nach vorne
		target = est + Vector3(mine * 0.3, 0, 0)
		var horiz := Vector2(_bpos.x - p.x, _bpos.z - p.z).length()
		var near_net := absf(est.x) < 3.2
		# Schmetterball: am Netz, hoher Ball, Absprung rechtzeitig (Stufe bestimmt, wie oft und wie gut)
		if near_net and level >= 1 and _bpos.y > NET_H + 0.6 and horiz < 1.6 and av.is_on_floor() and _bvel.y < 1.0 and randf() < Game.lv([0.0, 0.35, 0.7, 0.95], level):
			held["a"] = true
		elif horiz < 1.25 and _bpos.y > 2.0 and _bpos.y < 3.4 and av.is_on_floor() and _bvel.y < 0.0:
			held["a"] = true
		if not av.is_on_floor() and horiz < 1.5 and near_net:
			held["b"] = true
	elif coming:
		# Mitspieler nimmt an: das restliche Feld abdecken
		target = Vector3(mine * (5.2 if absf(est.x) < 4.0 else 2.2), 0, -est.z * 0.6)
	else:
		# Ball beim Gegner: einer vorne (Block-Bereitschaft), einer hinten
		var bz := clampf(_bpos.z, -HALF_Z, HALF_Z)
		target = Vector3(mine * 0.9, 0, bz * 0.7) if front else Vector3(mine * 5.0, 0, -bz * 0.4)
		# Block: Gegner greift am Netz an → hochspringen, wenn der Ball über die Netzkante kommt
		if front and level >= 1 and absf(_bpos.x) < 3.0 and _bpos.y > NET_H + 0.3 and av.is_on_floor():
			var att := false
			for o in active_slots():
				if teams[o] != teams[slot] and not (avatars[o] as PartyAvatar).is_on_floor() and absf((avatars[o] as PartyAvatar).global_position.x) < 3.6:
					att = true
			if att and absf(p.z - _bpos.z) < 1.0 and randf() < Game.lv([0.0, 0.25, 0.55, 0.85], level):
				held["a"] = true
				if _log:
					print("[VOLLEY] Block-Sprung %d bei x=%.1f z=%.1f (Ball %s)" % [slot, p.x, p.z, str(_bpos.snapped(Vector3.ONE * 0.1))])
	# nie auf den Mitspieler laufen (Verkeilen verhindern)
	if other >= 0:
		var po2 := (avatars[other] as PartyAvatar).global_position
		var sep := Vector2(p.x - po2.x, p.z - po2.z)
		if sep.length() < 1.1 and not (coming and mine_takes):
			target += Vector3(sep.x, 0, sep.y).normalized() * 1.2
	target.x = clampf(target.x, -HALF_X - 1.0, -NET_GAP) if teams[slot] == 0 else clampf(target.x, NET_GAP, HALF_X + 1.0)
	var to := Vector2(target.x - p.x, target.z - p.z)
	var mv := to.normalized() * clampf(to.length() * 1.2, 0.0, 1.0)
	InputHub.set_virtual(slot, mv, held)


## CPU-Ziel: die freieste Stelle im gegnerischen Feld (weit weg von beiden Gegnern), als Stick-Richtung.
func _pick_aim(slot: int, level: int) -> Vector2:
	var dir := 1.0 if teams[slot] == 0 else -1.0
	var opts: Array = []
	for ax in [-0.8, 0.0, 0.85]:
		for az in [-0.85, 0.0, 0.85]:
			var spot := Vector3(dir * (4.4 + ax * 2.8), 0, az * 3.5)
			var dmin := INF
			for o in active_slots():
				if teams[o] != teams[slot]:
					var po := (avatars[o] as PartyAvatar).global_position
					dmin = minf(dmin, Vector2(spot.x - po.x, spot.z - po.z).length())
			opts.append([dmin, Vector2(ax * dir, az)])
	opts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var pick_n: int = Game.lv([6, 4, 3, 2], level, true)
	var pick: Array = opts[randi() % mini(pick_n, opts.size())]
	var aim: Vector2 = pick[1]
	# Erste Berührung hinten und Mitspieler am Netz: starke CPUs spielen bevorzugt zu (Zuspiel → Schmetterball)
	var p := (avatars[slot] as PartyAvatar).global_position
	if _touch_n[teams[slot]] == 0 and absf(p.x) > 3.4 and randf() < Game.lv([0.15, 0.4, 0.65, 0.8], level):
		for o in active_slots():
			if o != slot and teams[o] == teams[slot] and absf((avatars[o] as PartyAvatar).global_position.x) < absf(p.x) - 1.0:
				return Vector2(randf_range(-0.3, 0.2) * dir, randf_range(-0.4, 0.4))   # nicht nach vorne drücken = Zuspiel
	return aim + Vector2(randf_range(-0.12, 0.12), randf_range(-0.15, 0.15))
