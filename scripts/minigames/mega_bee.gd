extends MinigameBase
## Mega-Summser (Boss, jeder gegen jeden): Eine riesige Wiesenbiene brummt über der Blumenwiese. Sie sucht
## sich ein Opfer (Warnkreis!) und sticht herab – die Schockwelle wirft alle in der Nähe um. Danach steckt der
## Stachel kurz im Boden fest: Jetzt auf ihren Rücken springen! Jeder Treffer zählt für dich (+1) und kostet
## die Biene Kraft. Ist ihre Leiste leer, ist der Spuk vorbei – wer die meisten Treffer gelandet hat, gewinnt.
## Online: Host-Modell.

const HP_MAX := 16
const ARENA_R := 9.0
const SCALE := 3.2

var _bee: Node3D
var _anim: AnimationPlayer
var _hp := HP_MAX
var _state := "fly"
var _t := 3.0
var _pos := Vector3(0, 5.5, -2)
var _target := Vector3.ZERO
var _orbit := 0.0
var _warn: MeshInstance3D
var _hp_fill: Node3D
var _stomp_cd: Array[float] = [0, 0, 0, 0]
var _buzz_t := 0.0
var _hit_this: Array[bool] = [false, false, false, false]   # ein Treffer je Spieler und Festsitz-Phase


func _init() -> void:
	game_id = "mega_bee"
	env_preset = "day"
	backdrop_style = "meadow"
	time_limit = 60.0
	score_format = "%d Treffer"
	arena_radius = 9.5
	teaser_height = 3.0
	cannon_pos = Vector3(0, 0, 11)
	net_model = "host"
	spawn_points = [Vector3(-4, 0.6, 3), Vector3(4, 0.6, 3), Vector3(-4, 0.6, -2), Vector3(4, 0.6, -2)]


func build_arena() -> void:
	WorldKit.cylinder(world, ARENA_R + 1.5, 0.6, Vector3(0, -0.3, 0), Color("#86d164"))
	WorldKit.scatter(world, ["plat/flowers", "nat/flower_red", "nat/flower_yellow", "nat/flower_purple", "mt/grass_clump"], 46, Vector3.ZERO, 1.5, ARENA_R, 0.0)
	# Bienenstock, Baumkreis, Honigtöpfe
	for i in 10:
		var a := TAU * i / 10.0
		WorldKit.place(world, ["nat/tree_oak", "nat/tree_default", "qp/tree_fruit"][i % 3], Vector3(cos(a), 0, sin(a)) * (ARENA_R + 3.0), randf() * 360.0, [2.6, 2.4, 0.34][i % 3])
	var hive := WorldKit.cylinder(world, 1.4, 2.4, Vector3(-9.5, 1.2, -8.5), Color("#ffc94a"), false)
	for k in 3:
		WorldKit.cylinder(hive, 1.45, 0.12, Vector3(0, -0.6 + k * 0.6, 0), Color("#d89a2a"), false)
	_bee = Node3D.new()
	_bee.set_meta("keep_visible", true)
	world.add_child(_bee)
	var model := Assets.spawn("qp/bee", _bee, Vector3.ZERO, 0.0, SCALE)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim and _anim.has_animation("Flying"):
		_anim.play("Flying")
	_warn = MgKit.warn_disc(world, Vector3(0, 0.04, 0), 2.4, Color(0.9, 0.2, 0.1, 0.55), 9999.0)
	_warn.visible = false
	# Lebensleiste über der Biene
	var bar := Node3D.new()
	_bee.add_child(bar)
	bar.position = Vector3(0, 3.6, 0)
	WorldKit.box(bar, Vector3(3.0, 0.3, 0.08), Vector3.ZERO, Color("#2b2236"), false)
	_hp_fill = WorldKit.box(bar, Vector3(2.9, 0.22, 0.1), Vector3.ZERO, Color("#ffcc33"), false)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 1.5, 0.5)
	c.offset = Vector3(0, 13.0, 13.5)
	c.min_dist = 0.95
	c.max_dist = 1.05


func on_start() -> void:
	for av in avatars:
		if av:
			(av as PartyAvatar).can_shove = false


func check_end() -> bool:
	return _hp <= 0 and _state == "down"


func _play(anim: String) -> void:
	if _anim and _anim.has_animation(anim):
		_anim.play(anim, 0.15)


func on_tick(delta: float) -> void:
	var rage := 1.0 - float(_hp) / HP_MAX
	_t -= delta
	_buzz_t -= delta
	if _buzz_t <= 0.0 and _state != "down":
		_buzz_t = 0.9
		Audio.sfx("thruster", _pos, -14.0, 0.6)
	match _state:
		"fly":
			_orbit += delta * (0.6 + rage * 0.5)
			var want := Vector3(cos(_orbit) * 5.0, 5.5 + sin(_orbit * 2.0) * 0.6, sin(_orbit) * 4.0)
			_pos = _pos.lerp(want, minf(1.0, delta * 2.0))
			if _t <= 0.0:
				var alive_slots := active_slots()
				var pick := alive_slots[rng.randi() % alive_slots.size()]
				_target = (avatars[pick] as PartyAvatar).global_position
				_target.y = 0.0
				_state = "aim"
				_t = lerpf(1.3, 0.8, rage)
				_warn.visible = true
				_warn.position = _target + Vector3.UP * 0.04
				Audio.sfx("alert", _target, -4.0)
		"aim":
			_pos = _pos.lerp(_target + Vector3.UP * 5.5, minf(1.0, delta * 4.0))
			_warn.scale = Vector3.ONE * (1.0 + sin(_t * 20.0) * 0.05)
			if _t <= 0.0:
				_state = "dive"
				_t = 0.3
				_play("Bite_Front")
				Audio.sfx("whoosh", _pos)
		"dive":
			_pos = _pos.lerp(_target + Vector3.UP * 0.9, minf(1.0, delta * 12.0))
			if _t <= 0.0:
				_impact()
		"stuck":
			_pos = _target + Vector3(sin(_t * 30.0) * 0.06, 0.9, 0)
			if randf() < 0.1:
				FX.stars(_pos + Vector3.UP * 2.4, Color(1, 1, 0.6), 2)
			_stomps()
			if _t <= 0.0:
				_state = "fly"
				_t = lerpf(3.0, 1.6, rage) * rng.randf_range(0.8, 1.2)
				_play("Flying")
				Audio.sfx("woop", _pos, -4.0, 0.6)
		"down":
			_pos.y = lerpf(_pos.y, 0.6, delta * 3.0)
	_bee.position = _pos
	var face := (_target - _pos) if _state in ["aim", "dive"] else Vector3(-sin(_orbit), 0, cos(_orbit))
	if face.length() > 0.1:
		_bee.rotation.y = lerp_angle(_bee.rotation.y, atan2(face.x, face.z), 0.1)
	_hp_fill.scale.x = maxf(float(_hp) / HP_MAX, 0.01)
	_hp_fill.position.x = -1.45 * (1.0 - float(_hp) / HP_MAX)
	for i in active_slots():
		_stomp_cd[i] = maxf(0.0, _stomp_cd[i] - delta)


func _impact() -> void:
	_state = "stuck"
	_hit_this = [false, false, false, false]
	_t = lerpf(3.0, 2.2, 1.0 - float(_hp) / HP_MAX)
	_warn.visible = false
	Juice.shake(0.4)
	Audio.sfx("stone_hit", _target, 2.0, 0.6)
	FX.dust(_target, Color(0.75, 0.9, 0.55), 26, 2.4)
	FX.ring(_target + Vector3.UP * 0.2, Color(1, 0.9, 0.5), 3.0, 0.35)
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		var off := av.global_position - _target
		off.y = 0.0
		if off.length() < 2.6:
			av.apply_knockback(off.normalized() if off.length() > 0.1 else Vector3.BACK, 9.0, 1.0, 5.0)
			av.rig.react("dizzy")


func _stomps() -> void:
	var top := _pos.y + 1.3
	for i in active_slots():
		if _stomp_cd[i] > 0.0 or _hit_this[i]:
			continue
		var av := avatars[i] as PartyAvatar
		var p := av.global_position
		if Vector2(p.x - _pos.x, p.z - _pos.z).length() < 1.9 and p.y > top - 0.6 and p.y < top + 1.0 and av.velocity.y < 0.0:
			_stomp_cd[i] = 0.6
			_hit_this[i] = true
			av.velocity.y = 12.0
			_hp -= 1
			add_score(i, 1.0, _pos + Vector3.UP * 3.0)
			Audio.sfx("boing", _pos)
			Audio.sfx("hit_soft", _pos, -2.0)
			FX.stars(_pos + Vector3.UP * 2.0, Color(1, 0.95, 0.4), 12)
			Juice.squash(_bee, 1.25, 0.7, 0.3, Vector3.ONE)
			Juice.hitstop(0.05)
			_play("HitRecieve")
			av.rig.react("star_get")
			if _hp <= 0:
				_state = "down"
				_play("Death")
				CutsceneManager.big_word("Summser besiegt!", Color("#ffd166"), 0.9)
				Audio.sfx("fanfare", _pos, -2.0)
				return


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["bee"] = [snappedf(_pos.x, 0.01), snappedf(_pos.y, 0.01), snappedf(_pos.z, 0.01), snappedf(_bee.rotation.y, 0.02), _hp,
		["fly", "aim", "dive", "stuck", "down"].find(_state), snappedf(_target.x, 0.01), snappedf(_target.z, 0.01)]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var e: Array = d.get("bee", [])
	if e.size() < 8:
		return
	_pos = Vector3(float(e[0]), float(e[1]), float(e[2]))
	_bee.position = _pos
	_bee.rotation.y = float(e[3])
	var st: String = ["fly", "aim", "dive", "stuck", "down"][int(e[5])]
	_target = Vector3(float(e[6]), 0, float(e[7]))
	if st != _state:
		match st:
			"aim":
				_warn.visible = true
				_warn.position = _target + Vector3.UP * 0.04
				Audio.sfx("alert", _target, -4.0)
			"stuck":
				_warn.visible = false
				Juice.shake(0.4)
				FX.dust(_target, Color(0.75, 0.9, 0.55), 26, 2.4)
				Audio.sfx("stone_hit", _target, 2.0, 0.6)
			"fly":
				_play("Flying")
			"down":
				_play("Death")
	if int(e[4]) < _hp:
		Audio.sfx("boing", _pos)
		FX.stars(_pos + Vector3.UP * 2.0, Color(1, 0.95, 0.4), 12)
		_play("HitRecieve")
	_hp = int(e[4])
	_state = st
	_hp_fill.scale.x = maxf(float(_hp) / HP_MAX, 0.01)
	_hp_fill.position.x = -1.45 * (1.0 - float(_hp) / HP_MAX)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var p := av.global_position
	var held := {}
	var mv := Vector2.ZERO
	match _state:
		"aim", "dive":
			var off := Vector2(p.x - _target.x, p.z - _target.z)
			if off.length() < 3.4:
				mv = off.normalized() if off.length() > 0.05 else Vector2.RIGHT
		"stuck":
			var to := Vector2(_pos.x - p.x, _pos.z - p.z)
			mv = to.normalized() * clampf(to.length(), 0.0, 1.0)
			# Absprung kurz vor der Biene, damit man von oben auf ihr landet
			if to.length() < [2.2, 2.6, 2.9][level] and to.length() > 1.0 and av.is_on_floor() and randf() < [0.2, 0.5, 0.9][level]:
				held["a"] = true
			if not av.is_on_floor() and to.length() < 0.8:
				mv *= 0.2
		_:
			var to2 := Vector2(-p.x, -p.z) * 0.15
			mv = to2.limit_length(0.6)
	InputHub.set_virtual(slot, mv, held)
