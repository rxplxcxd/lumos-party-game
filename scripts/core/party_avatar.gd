class_name PartyAvatar
extends CharacterBody3D
## Spielfigur für Minispiele zu Fuß: Laufen, Sprung (Antizipation + Stretch), Schubsen,
## Knockback mit Betäubung, Rutschen (Schleim), Sturz in Gefahren (Wasser/Lava/Abgrund).
## Eingabe kommt immer über InputHub (Mensch oder CPU, transparent).

signal fell(avatar: PartyAvatar, hazard: String)
signal shoved(by: PartyAvatar, victim: PartyAvatar)
## Online: Schubser auf eine Figur, die ein anderes Gerät steuert (deren Besitzer wendet ihn an).
signal shove_remote(victim: PartyAvatar, dir: Vector3, power: float)

const LAYER_WORLD := 1
const LAYER_AVATAR := 2

var slot := 0
var rig: CharacterRig
var max_speed := 7.0
var accel := 42.0
var friction := 34.0
var air_control := 0.65
var jump_velocity := 10.0
var gravity_force := 28.0
var slippery := 0.0
var input_mult := 1.0   # −1 = vertauschte Steuerung (z. B. Boss-Effekte)
var cam_yaw := 0.0
var can_move := true
var can_jump := true
var can_shove := true
var alive := true
var kill_y := -8.0
var hazard := "lava"
var shove_power := 11.0
var net_remote := false
## Spielfeldgrenzen (x/z), direkt nach jeder Bewegung erzwungen – z. B. die Netzseite im Volleyball. Anders als
## eine Wand kann man hier weder durchrutschen noch beim Springen darüber, und es gibt kein Zittern.
var bound_min := Vector2(-INF, -INF)
var bound_max := Vector2(INF, INF)

var _stun_left := 0.0   # Spielzeit (nicht Wanduhr): Zeitlupe/Hitstop/niedrige Bildrate verlängern nichts falsch
var _shove_cd := 0.0
var _dash_t := 0.0
var _knock := Vector3.ZERO
var _coyote := 0.0
var _jump_buf := 0.0
var _was_floor := true
var _prev_vy := 0.0
var _slip_spin := 0.0


func setup(p: int, pos: Vector3, scl := 0.85) -> PartyAvatar:
	slot = p
	collision_layer = LAYER_AVATAR
	collision_mask = LAYER_WORLD | LAYER_AVATAR
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	rig = CharacterRig.new()
	add_child(rig)
	rig.setup(Game.hero(Game.players[p].hero).model, p, scl)
	position = pos
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	return self


func is_stunned() -> bool:
	return _stun_left > 0.0


func stun(seconds: float) -> void:
	_stun_left = maxf(_stun_left, seconds)


func apply_knockback(dir: Vector3, strength: float, stun_time := 0.45, up := 4.0) -> void:
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	_knock = flat * strength
	velocity.y = maxf(velocity.y, up)
	stun(stun_time)
	rig.face_now(-flat)
	rig.react("hit" if strength < 14.0 else "big_hit")


func _physics_process(delta: float) -> void:
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
	if not alive:
		return
	var on_floor := is_on_floor()
	var stunned := is_stunned()
	var mv := (InputHub.move(slot) * input_mult) if (can_move and not stunned) else Vector2.ZERO
	var wish := Vector3(mv.x, 0, mv.y).rotated(Vector3.UP, cam_yaw)

	# horizontale Bewegung
	var hv := Vector3(velocity.x, 0, velocity.z) - _knock
	var a := accel * (1.0 if on_floor else air_control) * (1.0 - slippery * 0.88)
	if wish.length() > 0.05:
		hv = hv.move_toward(wish * max_speed, a * delta)
	else:
		hv = hv.move_toward(Vector3.ZERO, friction * (1.0 - slippery * 0.96) * delta * (1.0 if on_floor else 0.25))
	if _dash_t > 0.0:
		_dash_t -= delta
	_knock = _knock.move_toward(Vector3.ZERO, (16.0 if on_floor else 6.0) * delta)
	velocity.x = hv.x + _knock.x
	velocity.z = hv.z + _knock.z

	# Schwerkraft & Sprung
	if on_floor:
		_coyote = 0.12
	else:
		_coyote -= delta
		velocity.y -= gravity_force * delta
	_jump_buf -= delta
	if can_jump and not stunned and InputHub.pressed(slot, "a"):
		_jump_buf = 0.14
	if _jump_buf > 0.0 and _coyote > 0.0:
		_jump_buf = 0.0
		_coyote = 0.0
		velocity.y = jump_velocity
		rig.jump_stretch()
		rig.play("jump_start", 0.05, 1.6, true)
		rig.lock(0.18)
		FX.dust(global_position, Color(0.9, 0.9, 0.9), 6, 0.7)
		Audio.sfx("jump", global_position, -6.0)
	# variable Sprunghöhe
	if velocity.y > 0.0 and not InputHub.held(slot, "a"):
		velocity.y -= gravity_force * 0.9 * delta

	# Schubsen
	_shove_cd -= delta
	if can_shove and not stunned and _shove_cd <= 0.0 and InputHub.pressed(slot, "b"):
		_do_shove()

	_prev_vy = velocity.y
	move_and_slide()
	if bound_min.x > -INF or bound_max.x < INF or bound_min.y > -INF or bound_max.y < INF:
		var gp := global_position
		var cx := clampf(gp.x, bound_min.x, bound_max.x)
		var cz := clampf(gp.z, bound_min.y, bound_max.y)
		if cx != gp.x or cz != gp.z:
			global_position = Vector3(cx, gp.y, cz)
			if cx != gp.x:
				velocity.x = 0.0
				_knock.x = 0.0
			if cz != gp.z:
				velocity.z = 0.0
				_knock.z = 0.0

	# Landung
	var now_floor := is_on_floor()
	if now_floor and not _was_floor and _prev_vy < -4.0:
		rig.land_impact(clampf(-_prev_vy / 16.0, 0.3, 1.2))
		InputHub.rumble(slot, 0.25, 0.08)
	_was_floor = now_floor

	# Optik
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if slippery > 0.5 and hspeed > 1.0 and now_floor:
		_slip_spin += delta * hspeed * 2.0
		rig.pivot.rotation.z = sin(_slip_spin) * 0.15
	else:
		rig.pivot.rotation.z = lerpf(rig.pivot.rotation.z, 0.0, delta * 8.0)
	if not stunned and hspeed > 0.4:
		rig.face(Vector3(velocity.x, 0, velocity.z), delta, 14.0)
	rig.locomote(hspeed, max_speed, now_floor, velocity.y, delta)
	rig.set_lean(clampf(-mv.x * 0.6, -1, 1) if hspeed > 3.0 else 0.0)

	if global_position.y < kill_y:
		fall_into(hazard)


func _do_shove() -> void:
	_shove_cd = 0.65
	_dash_t = 0.18
	var fwd := -rig.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	velocity.x += fwd.x * 7.0
	velocity.z += fwd.z * 7.0
	rig.play("punch", 0.05, 1.5, true)
	rig.lock(0.3)
	rig.squash(1.15, 0.9, 0.3)
	Audio.sfx("whoosh", global_position, -8.0)
	var space := get_parent()
	for other in space.get_children():
		if other is PartyAvatar and other != self and (other as PartyAvatar).alive:
			var o := other as PartyAvatar
			var d := o.global_position - global_position
			d.y = 0
			if d.length() < 1.9 and fwd.dot(d.normalized()) > 0.3:
				if o.net_remote:
					shove_remote.emit(o, d.normalized(), shove_power)
					o.rig.react("hit")
				else:
					o.apply_knockback(d.normalized(), shove_power, 0.5, 4.5)
				FX.stars(o.global_position + Vector3.UP * 1.5, Color(1, 0.95, 0.4), 6)
				Audio.sfx("punch", o.global_position)
				Juice.hitstop(0.05)
				Juice.shake(0.15)
				InputHub.rumble(slot, 0.4, 0.1)
				InputHub.rumble(o.slot, 0.7, 0.18)
				shoved.emit(self, o)


## Sturz in eine Gefahr: Effekt, Reaktion, Signal. Minispiel entscheidet über Respawn/Ausscheiden.
func fall_into(kind := "lava") -> void:
	if not alive:
		return
	alive = false
	velocity = Vector3.ZERO
	var p := global_position
	match kind:
		"water":
			FX.splash(Vector3(p.x, maxf(p.y, kill_y + 1.0), p.z), 1.3)
			Audio.sfx("splash", p)
		"lava":
			FX.embers(p, 20)
			FX.smoke(p, Color(0.3, 0.25, 0.25), 10, 1.0)
			Audio.sfx("thruster", p)
			rig.set_soot(3.0)
		_:
			FX.dust(p, Color(0.7, 0.7, 0.75), 12)
	Audio.sfx("whistle_fall", p, -4.0)
	InputHub.rumble(slot, 0.8, 0.3)
	rig.react("launch")
	fell.emit(self, kind)


func respawn(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO
	alive = true
	visible = true
	rig.play("spawn", 0.05, 1.0, true)
	rig.lock(0.6)
	FX.stars(pos + Vector3.UP, Color(1, 1, 1), 8)
	Juice.pop_in(rig.pivot, 0.35)


func freeze(on: bool) -> void:
	can_move = not on
	can_jump = not on
	can_shove = not on
