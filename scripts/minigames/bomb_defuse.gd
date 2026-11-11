extends MinigameBase
## Bomben-Entschärfung (2 gegen 2): Über zwei Gärten regnet es Kugelbomben mit brennender Zündschnur.
## B = Zündschnur austreten (+1), A = Bombe über die Hecke in den Nachbargarten kicken. Explodiert eine Bombe,
## fliegt alles in der Nähe durch die Luft und das Team dieses Gartens verliert einen Punkt.
## Online: Host-Modell (Host simuliert Bomben, Kicks und Explosionen).

const HALF_X := 8.0
const HALF_Z := 5.0
const KICK_R := 1.25
const STOMP_R := 1.05

var _bombs: Array[Dictionary] = []   # {node, pos, vel, fuse, ground, fx_t}
var _spawn_t := 1.2
var _next_side := 0
var _cd: Array[float] = [0, 0, 0, 0]


func _init() -> void:
	game_id = "bomb_defuse"
	env_preset = "day"
	backdrop_style = "meadow"
	time_limit = 45.0
	score_format = "%d"
	arena_radius = 9.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 9)
	net_model = "host"
	spawn_points = [Vector3(-5, 0.6, -1.5), Vector3(5, 0.6, -1.5), Vector3(-5, 0.6, 2.0), Vector3(5, 0.6, 2.0)]


## Team 0 spielt links, Team 1 rechts – Startpunkte nach Teamzugehörigkeit
func on_setup() -> void:
	var left := 0
	var right := 0
	for i in 4:
		if teams[i] == 0:
			spawn_points[i] = Vector3(-5.0, 0.6, -1.5 + left * 3.5)
			left += 1
		else:
			spawn_points[i] = Vector3(5.0, 0.6, -1.5 + right * 3.5)
			right += 1


func build_arena() -> void:
	WorldKit.box(world, Vector3(HALF_X * 2 + 1, 0.4, HALF_Z * 2 + 1), Vector3(0, -0.2, 0), Color("#7cc85a"))
	WorldKit.box(world, Vector3(HALF_X + 0.5, 0.02, HALF_Z * 2 + 1), Vector3(-HALF_X * 0.5, 0.01, 0), Color("#86d164"), false)
	# Hecke in der Mitte (Figuren bleiben im eigenen Garten, Bomben fliegen drüber)
	WorldKit.box(world, Vector3(0.6, 0.9, HALF_Z * 2 + 1), Vector3(0, 0.45, 0), Color("#3f8a3a"))
	for z in range(-5, 6, 2):
		WorldKit.place(world, "qp/bush", Vector3(0, 0.5, z), randf() * 360.0, 0.28)
	# Gartenzäune ringsum, Häuschen, Blumenbeete, Gartenzwerge (Pilze)
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(HALF_X * 2 + 1, 0.8, 0.25), Vector3(0, 0.4, side * (HALF_Z + 0.6)), Color("#e8d2a0"))
		WorldKit.box(world, Vector3(0.25, 0.8, HALF_Z * 2 + 1), Vector3(side * (HALF_X + 0.6), 0.4, 0), Color("#e8d2a0"))
		WorldKit.cottage(world, Vector3(side * 12.5, 0, -2.0), -side * PI / 2.0, 1.4, Color("#ffe1c4") if side < 0 else Color("#d8ecff"))
		for k in 4:
			WorldKit.place(world, ["nat/flower_red", "nat/flower_yellow", "nat/flower_purple", "plat/flowers"][k], Vector3(side * (HALF_X + 1.5), 0, -4.0 + k * 2.6), randf() * 360.0, 1.6)
	WorldKit.place(world, "qp/tree_fruit", Vector3(-11.5, 0, 5.5), 20.0, 0.32)
	WorldKit.place(world, "qp/tree", Vector3(11.5, 0, 5.5), -30.0, 0.32)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 13.0, 10.5)
	c.min_dist = 0.95
	c.max_dist = 1.05


func on_start() -> void:
	for av in avatars:
		if av:
			(av as PartyAvatar).can_jump = false
			(av as PartyAvatar).can_shove = false


func on_tick(delta: float) -> void:
	var prog := 1.0 - time_left / time_limit
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = lerpf(1.6, 0.75, prog) * rng.randf_range(0.8, 1.2)
		_spawn_bomb(_next_side, prog)
		_next_side = 1 - _next_side
	# Figuren im eigenen Garten halten
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		var sx := -1.0 if teams[i] == 0 else 1.0
		var p := av.global_position
		p.x = clampf(p.x, -HALF_X + 0.4, -0.6) if sx < 0.0 else clampf(p.x, 0.6, HALF_X - 0.4)
		p.z = clampf(p.z, -HALF_Z + 0.4, HALF_Z - 0.4)
		av.global_position = p
		_cd[i] = maxf(0.0, _cd[i] - delta)
		if _cd[i] <= 0.0:
			if InputHub.pressed(i, "b"):
				_try_stomp(i)
			elif InputHub.pressed(i, "a"):
				_try_kick(i)
	_update_bombs(delta)


func _spawn_bomb(side: int, prog: float) -> void:
	var sx := -1.0 if side == 0 else 1.0
	var pos := Vector3(sx * rng.randf_range(1.2, HALF_X - 1.0), 9.0, rng.randf_range(-HALF_Z + 1.0, HALF_Z - 1.0))
	var node := WorldKit.place(world, "qp/bomb", pos, rng.randf() * 360.0, 0.55)
	MgKit.warn_disc(world, Vector3(pos.x, 0.03, pos.z), 0.7, Color(0.1, 0.05, 0.1), 1.0)
	_bombs.append({"node": node, "pos": pos, "vel": Vector3.ZERO, "fuse": lerpf(6.0, 4.0, prog), "ground": false, "fx_t": 0.0})
	Audio.sfx("whistle_fall", pos, -10.0, 1.2)


func _nearest_bomb(p: Vector3, r: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := r
	for b in _bombs:
		var d := Vector2((b.pos as Vector3).x - p.x, (b.pos as Vector3).z - p.z).length()
		if d < bd and (b.pos as Vector3).y < 1.5:
			bd = d
			best = b
	return best


func _try_stomp(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	var b := _nearest_bomb(av.global_position, STOMP_R)
	av.rig.play_once("punch", "idle", 1.8)
	_cd[i] = 0.25
	if b.is_empty() or not bool(b.ground):
		return
	var p: Vector3 = b.pos
	FX.dust(p + Vector3.UP * 0.6, Color(0.6, 0.6, 0.65), 12, 0.9)
	Audio.sfx("slime", p, -4.0, 1.4)
	Audio.sfx("pop", p)
	Juice.float_text(self, p + Vector3.UP * 1.6, "Puff!", Color("#c9f2ff"), 60)
	add_score(i, 1.0)
	av.rig.react("flex")
	(b.node as Node3D).queue_free()
	_bombs.erase(b)


func _try_kick(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	var b := _nearest_bomb(av.global_position, KICK_R)
	_cd[i] = 0.35
	if b.is_empty():
		return
	var to_enemy := 1.0 if teams[i] == 0 else -1.0
	var dz := clampf(InputHub.move(i).y, -1.0, 1.0) * 2.0
	b.vel = Vector3(to_enemy * rng.randf_range(6.5, 8.0), 6.5, dz)
	b.ground = false
	av.rig.play_once("slice", "idle", 1.8)
	Audio.sfx("boing", b.pos as Vector3, -2.0)
	FX.sparks(b.pos as Vector3 + Vector3.UP * 0.5, Color(1, 0.9, 0.5), 6)


func _update_bombs(delta: float) -> void:
	var k := _bombs.size() - 1
	while k >= 0:
		var b := _bombs[k]
		var p: Vector3 = b.pos
		var v: Vector3 = b.vel
		if not bool(b.ground):
			v.y -= 22.0 * delta
			p += v * delta
			if p.y <= 0.0:
				p.y = 0.0
				if absf(v.y) > 4.0:
					v = Vector3(v.x * 0.5, -v.y * 0.3, v.z * 0.5)
					Audio.sfx("land", p, -8.0)
					FX.dust(p, Color(0.8, 0.9, 0.6), 4, 0.6)
				else:
					v = Vector3.ZERO
					b.ground = true
			p.x = clampf(p.x, -HALF_X + 0.3, HALF_X - 0.3)
			p.z = clampf(p.z, -HALF_Z + 0.3, HALF_Z - 0.3)
		b.pos = p
		b.vel = v
		if bool(b.ground) or p.y < 3.0:
			b.fuse = float(b.fuse) - delta
		_draw_bomb(b, delta)
		if float(b.fuse) <= 0.0:
			_explode(b)
			_bombs.remove_at(k)
		k -= 1


func _draw_bomb(b: Dictionary, delta: float) -> void:
	var node: Node3D = b.node
	node.position = b.pos
	var f := float(b.fuse)
	var pulse := 1.0 + (sin((8.0 + 14.0 / maxf(f, 0.4)) * f) * 0.08 if f < 2.5 else 0.0)
	node.scale = Vector3.ONE * 0.55 * pulse
	b.fx_t = float(b.fx_t) - delta
	if float(b.fx_t) <= 0.0:
		b.fx_t = 0.12 if f > 1.5 else 0.06
		FX.sparks((b.pos as Vector3) + Vector3.UP * 1.0, Color(1.0, 0.7, 0.2), 2)
		if f < 1.5:
			Audio.sfx("tick", b.pos as Vector3, -12.0, 1.5)


func _explode(b: Dictionary) -> void:
	var p: Vector3 = b.pos
	(b.node as Node3D).queue_free()
	FX.explosion(p + Vector3.UP * 0.4, 1.0, true)
	Juice.shake(0.35)
	var side := 0 if p.x < 0.0 else 1
	var loser := -1
	var ld := INF
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		var off := av.global_position - p
		off.y = 0.0
		if off.length() < 2.6:
			av.apply_knockback(off.normalized() if off.length() > 0.05 else Vector3.BACK, 9.0, 0.8, 5.0)
			av.rig.react("soot_blast")
			av.rig.set_soot(2.5)
		if teams[i] == side and off.length() < ld:
			ld = off.length()
			loser = i
	if loser >= 0 and scores[loser] > 0.0:
		add_score(loser, -1.0, p + Vector3.UP * 2.0)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["b"] = _bombs.map(func(b: Dictionary) -> Array: return [snappedf((b.pos as Vector3).x, 0.02), snappedf((b.pos as Vector3).y, 0.02), snappedf((b.pos as Vector3).z, 0.02), snappedf(float(b.fuse), 0.05)])
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var bs: Array = d.get("b", [])
	# Fehlende Bomben sind explodiert oder ausgetreten: kleiner Effekt, dann weg
	while _bombs.size() > bs.size():
		var gone: Dictionary = _bombs.pop_back()
		FX.dust(gone.pos as Vector3 + Vector3.UP * 0.5, Color(0.6, 0.6, 0.65), 10, 0.9)
		if float(gone.fuse) < 0.3:
			FX.explosion(gone.pos as Vector3 + Vector3.UP * 0.4, 1.0, true)
		(gone.node as Node3D).queue_free()
	while _bombs.size() < bs.size():
		var node := WorldKit.place(world, "qp/bomb", Vector3.ZERO, 0.0, 0.55)
		_bombs.append({"node": node, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "fuse": 5.0, "ground": true, "fx_t": 0.0})
	for k in bs.size():
		var e: Array = bs[k]
		_bombs[k].pos = Vector3(float(e[0]), float(e[1]), float(e[2]))
		_bombs[k].fuse = float(e[3])
		_draw_bomb(_bombs[k], 1.0 / 30.0)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var p := av.global_position
	var mine := 0 if teams[slot] == 0 else 1
	var held := {}
	var best: Dictionary = {}
	var bd := INF
	for b in _bombs:
		var bp: Vector3 = b.pos
		if (bp.x < 0.0) != (mine == 0) or bp.y > 2.0:
			continue
		var d := Vector2(bp.x - p.x, bp.z - p.z).length()
		# Mitspieler kümmert sich schon? Dann lieber eine andere Bombe
		for o in active_slots():
			if o != slot and teams[o] == teams[slot] and (avatars[o] as PartyAvatar).global_position.distance_to(bp) < d - 0.5:
				d += 3.0
		if d < bd:
			bd = d
			best = b
	var mv := Vector2.ZERO
	if not best.is_empty():
		var bp2: Vector3 = best.pos
		var to := Vector2(bp2.x - p.x, bp2.z - p.z)
		var f := float(best.fuse)
		if f < Game.lv([0.4, 0.6, 0.8], level) and to.length() < 2.6:
			mv = -to.normalized()   # zu spät – weg da!
		else:
			mv = to.normalized() * clampf(to.length(), 0.0, 1.0)
			if to.length() < STOMP_R * 0.8 and bool(best.ground) and randf() < Game.lv([0.25, 0.5, 0.8], level):
				# Nah an der Hecke und noch viel Zeit? Profis kicken rüber, sonst austreten
				if level >= 1 and absf(bp2.x) < 2.8 and f > 2.0 and randf() < 0.5:
					held["a"] = true
				else:
					held["b"] = true
	else:
		mv = Vector2((-4.0 if mine == 0 else 4.0) - p.x, 0.0 - p.z).limit_length(1.0) * 0.5
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)
