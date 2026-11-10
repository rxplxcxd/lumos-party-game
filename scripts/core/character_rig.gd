class_name CharacterRig
extends Node3D
## Visueller Charakter mit Animations-DNA:
## * Rig-Clips (KayKit Rig_Medium-Bibliothek bzw. Kenney-eigene Clips) über logische Namen
## * Squash & Stretch + Antizipation auf einem eigenen Pivot (Füße bleiben am Boden)
## * Prozeduraler SlapstickModifier (Torkeln, Zittern, Kopfschütteln, Blickkontakt, Lenkpose)
## * Reaktionen aus res://assets/animations/reactions/*.tres
## * Fußschritt-Partikel abhängig vom Untergrund, Ruß-Gesicht, Spielerfarb-Ring
##
## Konvention: Der Rig blickt nach -Z (Godot-Standard), Modelle werden intern gedreht.

const MAP_KAYKIT := {
	"idle": "Idle_A", "idle_b": "Idle_B", "walk": "Walking_A", "run": "Running_A", "sprint": "Running_B",
	"jump_start": "Jump_Start", "jump_air": "Jump_Idle", "land": "Jump_Land", "jump_full": "Jump_Full_Short",
	"jump_long": "Jump_Full_Long", "cheer": "Cheering", "wave": "Waving", "hit": "Hit_A", "hit_b": "Hit_B",
	"death": "Death_A", "death_b": "Death_B", "death_pose": "Death_A_Pose", "dodge": "Dodge_Forward",
	"dodge_back": "Dodge_Backward", "throw": "Throw", "pickup": "PickUp", "interact": "Interact",
	"use": "Use_Item", "spawn_air": "Spawn_Air", "spawn": "Spawn_Ground", "sit": "Sit_Floor_Idle",
	"sit_down": "Sit_Floor_Down", "sit_up": "Sit_Floor_StandUp", "sit_chair": "Sit_Chair_Idle",
	"lie": "Lie_Idle", "lie_down": "Lie_Down", "stand_up": "Lie_StandUp", "taunt": "Skeletons_Taunt",
	"taunt_long": "Skeletons_Taunt_Longer", "punch": "Melee_Unarmed_Attack_Punch_A", "kick": "Melee_Unarmed_Attack_Kick",
	"block": "Melee_Blocking", "crouch": "Crouching", "sneak": "Sneaking", "hammer": "Hammering", "dig": "Digging",
	"spin": "Melee_2H_Attack_Spinning", "hold": "Holding_A", "hold_b": "Holding_B", "pushups": "Push_Ups",
	"chop": "Chopping", "fish": "Fishing_Idle", "cast": "Ranged_Magic_Raise", "crawl": "Crawling",
	"skel_awaken": "Skeletons_Awaken_Standing", "skel_idle": "Skeletons_Idle", "skel_walk": "Skeletons_Walking",
	"strafe_l": "Running_Strafe_Left", "strafe_r": "Running_Strafe_Right", "slice": "Melee_1H_Attack_Slice_Horizontal",
}
const MAP_KENNEY := {
	"idle": "idle", "walk": "walk", "run": "sprint", "sprint": "sprint", "jump_start": "jump", "jump_air": "fall",
	"land": "idle", "jump_full": "jump", "cheer": "emote-yes", "wave": "emote-yes", "hit": "emote-no", "hit_b": "emote-no",
	"death": "die", "death_b": "die", "throw": "attack-melee-right", "pickup": "pick-up", "interact": "interact-right",
	"use": "interact-right", "sit": "sit", "sit_chair": "sit", "drive": "drive", "punch": "attack-melee-right",
	"kick": "attack-kick-right", "hold": "holding-both", "crouch": "crouch", "taunt": "emote-no", "dodge": "jump",
	"spawn_air": "fall", "spawn": "idle", "hammer": "attack-melee-left", "spin": "attack-melee-right",
}
const MAP_PET := {
	"idle": "idle", "walk": "walk", "run": "run", "sprint": "run", "cheer": "dance", "wave": "gesture-positive",
	"hit": "gesture-negative", "taunt": "gesture-negative", "jump_start": "run", "jump_air": "idle", "land": "idle",
	"eat": "eat", "dance": "dance", "death": "gesture-negative",
}
const LOOPING := ["idle", "idle_b", "walk", "run", "sprint", "jump_air", "cheer", "wave", "sit", "sit_chair", "lie",
	"crouch", "sneak", "hammer", "dig", "spin", "hold", "hold_b", "pushups", "chop", "fish", "drive", "skel_idle",
	"skel_walk", "taunt_long", "crawl", "dance", "eat", "block", "strafe_l", "strafe_r"]

var kind := "kaykit"
var model_key := ""
var player := -1
var pivot: Node3D
var model: Node3D
var anim: AnimationPlayer
var skel: Skeleton3D
var modifier: SlapstickModifier
var base_scale := Vector3.ONE
var current := ""
var surface := "stone"
var ring: MeshInstance3D

var _lock_until := 0
var _step_acc := 0.0
var _soot_mat: StandardMaterial3D
var _reaction_cache := {}
var _map: Dictionary = MAP_KAYKIT


## model_key: "hero/knight", "mini/robot", "pet/cat", "npc/skeleton" …
func setup(key: String, player_idx := -1, scl := 1.0) -> CharacterRig:
	model_key = key
	player = player_idx
	var custom_id := ""
	if key.begins_with("custom/"):
		custom_id = key.substr(7)
		if not Avatars.has(custom_id):
			custom_id = ""
		key = Avatars.REFERENCE_HERO   # Referenz-Rig (bzw. Rückfall, solange der Avatar noch lädt)
	if key.begins_with("hero/"):
		kind = "kaykit"
		_map = MAP_KAYKIT
	elif key.begins_with("pet/"):
		kind = "pet"
		_map = MAP_PET
	else:
		kind = "kenney"
		_map = MAP_KENNEY
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	model = Assets.spawn(key, pivot)
	model.rotation.y = PI   # Modelle blicken nach +Z -> Rig nach -Z
	base_scale = Vector3.ONE * scl
	pivot.scale = base_scale
	anim = _find_anim(model)
	skel = _find_skel(model)
	if kind == "kaykit":
		if anim == null:
			anim = AnimationPlayer.new()
			anim.name = "AnimationPlayer"
			model.add_child(anim)
			anim.root_node = NodePath("..")
		anim.add_animation_library("", Assets.rig_library())
		if skel:
			modifier = SlapstickModifier.new()
			modifier.name = "Slapstick"
			skel.add_child(modifier)
			modifier.bind(skel)
	elif anim:
		for clip in anim.get_animation_list():
			if (clip as String) in ["idle", "walk", "sprint", "run", "fall", "drive", "sit", "dance", "eat", "holding-both", "crouch"]:
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	if custom_id != "":
		_attach_custom(custom_id)
	if player >= 0:
		_add_ring(Game.player_color(player))
	play("idle")
	return self


## Eigener Avatar: Das KayKit-Modell bleibt als unsichtbares Referenzskelett (spielt Clips, Reaktionen,
## Slapstick), der Avatar übernimmt per AvatarRetarget jede Pose. `model` zeigt danach auf den Avatar
## (Einfärben, Ruß-Gesicht, Sichtbarkeit wirken also auf das sichtbare Modell).
func _attach_custom(id: String) -> void:
	var av := Avatars.instantiate(id)
	if av == null or skel == null:
		return
	for mi in Assets.find_meshes(model):
		mi.visible = false
	pivot.add_child(av)
	av.rotation.y = PI
	var dsk := _find_skel(av)
	if dsk:
		var rt := AvatarRetarget.new()
		rt.name = "Retarget"
		dsk.add_child(rt)
		rt.bind(skel, dsk, Avatars.mapping(id))
	model = av


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r:
			return r
	return null


func _add_ring(col: Color) -> void:
	ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = FX.tex_ring
	m.albedo_color = Color(col, 0.95)
	m.disable_receive_shadows = true
	q.material = m
	ring.mesh = q
	ring.position.y = 0.04
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func has_clip(logical: String) -> bool:
	return anim != null and _map.has(logical) and anim.has_animation(_map[logical])


func clip_length(logical: String) -> float:
	if not has_clip(logical):
		return 0.5
	return anim.get_animation(_map[logical]).length


## Spielt eine logische Animation (mit Überblendung).
func play(logical: String, blend := 0.15, speed := 1.0, force := false) -> void:
	if anim == null:
		return
	var real: String = _map.get(logical, _map.get("idle", ""))
	if not anim.has_animation(real):
		real = _map.get("idle", "")
		if not anim.has_animation(real):
			return
	if current == logical and anim.is_playing() and not force:
		anim.speed_scale = speed
		return
	current = logical
	anim.play(real, blend, 1.0)
	anim.speed_scale = speed


## Einmal-Clip, blockiert Fortbewegungs-Animationen. Kehrt danach zu then zurück.
func play_once(logical: String, then := "idle", speed := 1.0, blend := 0.12) -> void:
	play(logical, blend, speed, true)
	var len := clip_length(logical) / maxf(speed, 0.01)
	_lock_until = Time.get_ticks_msec() + int(len * 1000.0 / maxf(Engine.time_scale, 0.05))
	await get_tree().create_timer(len, false).timeout
	if current == logical and then != "":
		play(then, 0.2)


func lock(seconds: float) -> void:
	_lock_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func unlock() -> void:
	_lock_until = 0


func is_locked() -> bool:
	return Time.get_ticks_msec() < _lock_until


## Fortbewegung: wählt idle/walk/run/jump/fall passend zur Geschwindigkeit.
func locomote(speed: float, max_speed: float, grounded: bool, vy := 0.0, delta := 0.016) -> void:
	if is_locked():
		return
	var ratio := speed / maxf(max_speed, 0.01)
	if not grounded:
		play("jump_air" if vy > -2.0 or kind != "kaykit" else "jump_air", 0.12)
		return
	if ratio < 0.08:
		play("idle", 0.2)
	elif ratio < 0.5:
		play("walk", 0.15, clampf(ratio * 2.2, 0.7, 1.4))
		_footsteps(delta, 0.42 / clampf(ratio * 2.0, 0.6, 1.4))
	else:
		play("run", 0.12, clampf(ratio * 1.1, 0.8, 1.35))
		_footsteps(delta, 0.29 / clampf(ratio, 0.7, 1.3))


func _footsteps(delta: float, interval: float) -> void:
	_step_acc += delta
	if _step_acc >= interval:
		_step_acc = 0.0
		FX.step(global_position + global_basis.x * randf_range(-0.2, 0.2), surface, 0.55, true)


# --- Juice ---------------------------------------------------------------------------------

func squash(sx: float, sy: float, duration := 0.35) -> void:
	Juice.squash(pivot, sx, sy, duration, base_scale)


func anticipate(depth := 0.35, hold := 0.1) -> Tween:
	return Juice.anticipate(pivot, depth, hold, base_scale)


func jump_stretch() -> void:
	pivot.scale = Vector3(base_scale.x * 0.8, base_scale.y * 1.3, base_scale.z * 0.8)
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "scale", base_scale, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func land_impact(strength := 1.0) -> void:
	squash(1.0 + 0.35 * strength, 1.0 - 0.3 * strength, 0.4)
	FX.land(global_position, surface, strength)
	Audio.sfx("land", global_position, -4.0)


func hop(height := 0.6, duration := 0.35) -> void:
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "position:y", height, duration * 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(pivot, "position:y", 0.0, duration * 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func spin_around(turns := 1.0, duration := 0.5) -> void:
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "rotation:y", pivot.rotation.y + TAU * turns, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: pivot.rotation.y = fmod(pivot.rotation.y, TAU))


## Dreht den Rig weich in Richtung dir (Welt-XZ).
func face(dir: Vector3, delta: float, turn_speed := 12.0) -> void:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	var target := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(delta * turn_speed, 0, 1))


func face_now(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length_squared() > 0.0001:
		rotation.y = atan2(-flat.x, -flat.z)


func look_at_point(p: Vector3, weight := 1.0) -> void:
	if modifier:
		modifier.look_target = p
		var tw := create_tween()
		tw.tween_property(modifier, "look_weight", weight, 0.25)


func clear_look() -> void:
	if modifier:
		create_tween().tween_property(modifier, "look_weight", 0.0, 0.3)


func set_lean(v: float) -> void:
	if modifier:
		modifier.lean = clampf(v, -1.0, 1.0)


func set_steer_pose(on: bool, steer := 0.0) -> void:
	if modifier:
		modifier.steer_weight = 1.0 if on else 0.0
		modifier.steer = steer


func modifier_pulse(mode: String, duration := 1.0, strength := 1.0) -> void:
	if modifier:
		modifier.pulse(mode, duration, strength)


## Ruß-Gesicht nach Explosionen: dunkles Overlay, das langsam verblasst.
func set_soot(duration := 4.0) -> void:
	if _soot_mat == null:
		_soot_mat = StandardMaterial3D.new()
		_soot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_soot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_soot_mat.albedo_color = Color(0.05, 0.04, 0.04, 0.82)
	for mi in Assets.find_meshes(model):
		mi.material_overlay = _soot_mat
	_soot_mat.albedo_color.a = 0.82
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(_soot_mat, "albedo_color:a", 0.0, 1.2)
	tw.tween_callback(func() -> void:
		for mi in Assets.find_meshes(model):
			mi.material_overlay = null)
	FX.smoke(global_position + Vector3.UP * 1.8, Color(0.15, 0.15, 0.15), 6, 0.6)


func set_visible_model(on: bool) -> void:
	pivot.visible = on


# --- Reaktionen ------------------------------------------------------------------------------

func reaction(id: String) -> ReactionClip:
	if _reaction_cache.has(id):
		return _reaction_cache[id]
	var path := "res://assets/animations/reactions/%s.tres" % id
	var r: ReactionClip = load(path) if ResourceLoader.exists(path) else null
	_reaction_cache[id] = r
	return r


## Spielt eine Slapstick-Reaktion aus der Bibliothek. Await-bar (wartet hold-Sekunden).
func react(id: String) -> void:
	var r := reaction(id)
	if r == null:
		push_warning("Reaktion fehlt: " + id)
		return
	var then := r.then_clip if r.then_clip != "" else "idle"
	play(r.clip, 0.1, r.clip_speed, true)
	lock(r.hold)
	if r.squash != Vector2.ONE:
		squash(r.squash.x, r.squash.y, 0.45)
	if r.hop > 0.0:
		hop(r.hop, 0.4)
	if r.spin != 0.0:
		spin_around(r.spin, 0.55)
	if r.modifier != "":
		modifier_pulse(r.modifier, r.modifier_time)
	var head := global_position + Vector3.UP * 2.4 * base_scale.y
	match r.fx:
		"stars":
			FX.stars(head)
		"dizzy":
			FX.dizzy_stars(self, 2.5 * base_scale.y, r.hold)
		"confetti":
			FX.confetti(global_position + Vector3.UP * 0.5, 50)
		"sweat":
			FX.burst(head, {"amount": 6, "life": 0.6, "spread": 40.0, "vel_min": 1.5, "vel_max": 2.5, "size": 0.25, "color": Color(0.6, 0.85, 1.0)})
		"anger":
			FX.smoke(head, Color(1.0, 0.3, 0.2), 5, 0.4)
		"zzz":
			FX.zzz(self, 2.4 * base_scale.y, r.hold)
		"smoke":
			FX.smoke(global_position + Vector3.UP, Color(0.3, 0.3, 0.3), 8, 0.8)
		"soot":
			set_soot(r.hold + 2.0)
		"dust":
			FX.dust(global_position, Color(0.8, 0.75, 0.65), 16, 1.2)
		"sparkle":
			FX.stars(head, Color(1, 1, 1), 8)
	if r.emote != "":
		FX.emote(self, r.emote, r.emote_color, 2.6 * base_scale.y, minf(r.hold, 1.4))
	if r.sfx != "":
		Audio.sfx(r.sfx, global_position)
	if r.shake > 0.0:
		Juice.shake(r.shake)
	if player >= 0:
		EventBus.player_reaction.emit(player, id)
	await get_tree().create_timer(r.hold, false).timeout
	if is_instance_valid(self) and current == r.clip:
		play(then, 0.25)
