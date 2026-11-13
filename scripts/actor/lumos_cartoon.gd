class_name LumosCartoon
extends RefCounted
## Cartoon-Reaktionen – ein eigener Stilbaustein von Lumos Party: übertrieben, niedlich, situationsabhängig.
##
##   LumosCartoon.react(actor, "cry", 0.9)        # Stärke 0..1: dezent (≈0,3) · deutlich (≈0,6) · extrem (≈1)
##
## Jede Reaktion verbindet Gefühl (LumosEmotion), Körper (Becken, Kopf, Zittern, Stöße, Sprünge), Gesten (LumosMicro)
## und Effekte (Tränenfontänen, Tropfen, Herzen, Sterne, Schweiß, Dampf, Funkeln, Staub). Sie beansprucht ihre Kanäle
## mit P_EMOTE (Reflexe mit P_REFLEX) – Interaktionen und Regie werden nicht überfahren, Mikrogesten weichen.
## Damit nichts ständig auftritt: Abklingzeit je Reaktion und Budget je Figur (höchstens 3 in 10 s), Stärke ×
## cfg.cartoon. Effekte sitzen seitlich bzw. über dem Kopf – das Gesicht bleibt sichtbar. Figuren ohne Skelett
## (Haustiere) reagieren mit dem ganzen Körper, Effekte sitzen dann über dem Modell.

## Reaktion → [Grunddauer s, Kanäle, Priorität (0 = P_EMOTE, 1 = P_REFLEX), Abklingzeit s]
const REACTIONS := {
	"cry": [2.4, ["face", "head", "arm.l", "arm.r", "torso"], 0, 10.0],
	"big_surprise": [1.1, ["face", "head", "torso"], 1, 5.0],
	"freeze": [1.0, ["face", "head", "torso", "legs"], 1, 6.0],
	"jump_back": [0.9, ["root", "legs", "face", "arm.l", "arm.r"], 1, 4.0],
	"almost_fall": [1.3, ["legs", "torso", "arm.l", "arm.r"], 1, 6.0],
	"dizzy": [1.8, ["head", "face", "torso"], 0, 6.0],
	"love": [2.0, ["face", "arm.l", "arm.r"], 0, 8.0],
	"blush_shy": [1.6, ["face", "eyes", "arm.r"], 0, 6.0],
	"face_in_hands": [1.7, ["face", "head", "arm.l", "arm.r"], 0, 7.0],
	"laugh_fit": [2.2, ["face", "torso", "legs", "arm.l", "arm.r"], 0, 8.0],
	"wipe_tears": [1.2, ["arm.r"], 0, 3.0],
	"puff_cheeks": [1.6, ["face", "arm.l", "arm.r"], 0, 7.0],
	"stomp": [0.9, ["legs", "face"], 0, 4.0],
	"sulk": [2.6, ["face", "head", "arm.l", "arm.r"], 0, 8.0],
	"look_away": [1.6, ["head", "face"], 0, 5.0],
	"joy_hop": [1.4, ["legs", "arm.l", "arm.r", "face"], 0, 5.0],
	"head_shake": [1.2, ["head", "face"], 0, 4.0],
	"hide_behind": [2.2, ["root", "legs", "torso", "head", "face"], 1, 8.0],
	"shiver": [1.6, ["torso", "face", "arm.l", "arm.r"], 0, 6.0],
	"jaw_drop": [1.3, ["face", "torso"], 0, 6.0],
	"spin_joy": [1.2, ["root", "arm.l", "arm.r", "face"], 0, 6.0],
	"sweat": [1.6, ["face", "arm.r"], 0, 6.0],
	"proud_pose": [2.0, ["arm.l", "arm.r", "torso", "face"], 0, 8.0],
	"facepalm": [1.5, ["arm.r", "head", "face"], 0, 6.0],
	"puppy": [1.8, ["face", "arm.l", "arm.r", "head"], 0, 8.0],
	"shrug": [1.4, ["arm.l", "arm.r", "head", "face"], 0, 4.0],
}

static var _heart_tex: ImageTexture
static var _drop_tex: ImageTexture
static var _tear_mat: StandardMaterial3D


static func available() -> Array:
	return REACTIONS.keys()


## Reaktion auslösen. opts: force (Abklingzeit/Budget ignorieren), target (LumosActor/Vector3 – wohin geschaut
## wird), from (Vector3 – woher der Schreck kommt), behind (LumosActor – hinter wem man sich versteckt), move (false =
## die Figur wird nicht versetzt), dur. true = läuft.
static func react(actor: LumosActor, id: String, intensity := 0.7, opts := {}) -> bool:
	if actor == null or not REACTIONS.has(id) or actor.cfg.cartoon <= 0.0:
		return false
	var def: Array = REACTIONS[id]
	var now := actor.clock()
	var force := bool(opts.get("force", false))
	var cd: Dictionary = actor.cartoon_state
	if not force:
		if float(cd.get(id, -99.0)) > now:
			return false
		var recent: Array = (cd.get("_recent", []) as Array).filter(func(x: float) -> bool: return now - x < 10.0)
		if recent.size() >= 3:
			return false
		cd["_recent"] = recent
	var i := clampf(intensity * actor.cfg.cartoon, 0.05, 1.0)
	var owner := "cartoon:" + id
	var prio := LumosLayers.P_REFLEX if int(def[2]) == 1 else LumosLayers.P_EMOTE
	var chans: Array = def[1]
	if actor.body == null:
		chans = chans.filter(func(c: String) -> bool: return c in ["root", "face"])
	if not actor.layers.claim(owner, chans, prio, stop.bind(actor, id)):
		return false
	cd[id] = now + float(def[3])
	var rec: Array = cd.get("_recent", [])
	rec.append(now)
	cd["_recent"] = rec
	cd["_last"] = id
	cd["_count"] = int(cd.get("_count", 0)) + 1
	var dur := float(opts.get("dur", float(def[0]) * lerpf(0.8, 1.25, i)))
	var run := {"id": id, "i": i, "dur": dur, "owner": owner, "tweens": [], "fx": []}
	cd["_run_" + id] = run
	_start(actor, run, opts)
	var tw := actor.create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(stop.bind(actor, id))
	(run.tweens as Array).append(tw)
	return true


static func running(actor: LumosActor) -> Array:
	var out: Array = []
	for k: String in actor.cartoon_state:
		if k.begins_with("_run_"):
			out.append(k.substr(5))
	return out


## Reaktion beenden (auch bei Verdrängung): Tweens stoppen, Effekte ausklingen lassen, Körper zurücksetzen.
static func stop(actor: LumosActor, id: String) -> void:
	if not is_instance_valid(actor):
		return
	var cd: Dictionary = actor.cartoon_state
	var run: Dictionary = cd.get("_run_" + id, {})
	if run.is_empty():
		return
	cd.erase("_run_" + id)
	for tw in run.tweens:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	for fx in run.fx:
		if is_instance_valid(fx):
			if fx is CPUParticles3D:
				(fx as CPUParticles3D).emitting = false
				var t2 := (fx as Node).create_tween()
				t2.tween_interval(1.0)
				t2.tween_callback((fx as Node).queue_free)
			else:
				(fx as Node).queue_free()
	var owner := String(run.owner)
	for sd in ["l", "r"]:
		actor.release(sd, 0.35, owner)
	if actor.micro.gesture != "" and String(actor.micro._g.get("owner", "")) == owner:
		actor.micro.stop()
	if actor.body:
		actor.body.tremble = 0.0
		actor.body.crouch = 0.0
		actor.body.micro_chest = Vector3.ZERO
	if actor.rig.anim:
		actor.rig.anim.speed_scale = 1.0
	actor.cartoon_head = Vector3.ZERO
	actor.layers.release(owner)


static func _start(actor: LumosActor, run: Dictionary, opts: Dictionary) -> void:
	var id := String(run.id)
	var i := float(run.i)
	var dur := float(run.dur)
	var em := actor.emotion
	var owner := String(run.owner)
	var b := actor.body
	var fw := actor.forward()
	var gest := func(g: String, gdur: float, side: String) -> void:
		actor.micro.play(g, {"prio": LumosLayers.P_EMOTE + 1, "owner": owner, "dur": gdur, "side": side})
	var later := func(t: float, f: Callable) -> void:
		var tw := actor.create_tween()
		tw.tween_interval(t)
		tw.tween_callback(f)
		(run.tweens as Array).append(tw)
	var head_env := func(v: Vector3, t_in: float, t_hold: float) -> void:   # Kopf-Zusatz mit weicher Hüllkurve
		var tw := actor.create_tween()
		tw.tween_property(actor, "cartoon_head", v, t_in).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(t_hold)
		tw.tween_property(actor, "cartoon_head", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_SINE)
		(run.tweens as Array).append(tw)
	match id:
		"cry":
			em.trigger("cry", i, dur * 0.8, 0.15, 0.8)
			if actor.face:
				actor.face.mouth_action("sob", dur)
			actor.emit_social("cry", {"intensity": i})
			if b:
				b.tremble = 0.35 * i
			head_env.call(Vector3(-0.3 * i, 0, 0), 0.2, dur * 0.5)
			if i > 0.6:
				gest.call("arms_up", dur * 0.55, "r")
			else:
				gest.call("wipe_tears", dur * 0.6, "r")
			if i > 0.45:
				(run.fx as Array).append_array(_tear_fountains(actor, i, dur * 0.65))
			later.call(dur * 0.62, func() -> void:   # danach vornübergebeugt schluchzen, Tropfen fallen
				head_env.call(Vector3(0.24, 0, 0), 0.3, dur * 0.25)
				if actor.body:
					actor.body.crouch = 0.18 * i
				(run.fx as Array).append_array(_tear_drops(actor, dur * 0.4)))
		"big_surprise", "jaw_drop":
			em.trigger("surprise", i, dur * 0.7, 0.05, 0.5)
			if actor.face:
				actor.face.mouth_action("gasp", dur * (1.4 if id == "jaw_drop" else 0.8))
			_freeze(actor, run, 0.12 + 0.2 * i)
			if b:
				b.push(-fw * 2.2 * i)
			head_env.call(Vector3(-0.16 * i, 0, 0), 0.08, dur * 0.4)
			if i > 0.6 and id == "big_surprise":
				actor.rig.hop(0.16 * i, 0.3)
		"freeze":
			em.trigger("panic", i, dur, 0.04, 0.6)
			_freeze(actor, run, dur * 0.6)
			if b:
				b.tremble = 1.0 * i
		"jump_back":
			em.trigger("fear", i, dur, 0.04, 0.7)
			actor.emit_social("fright", {"intensity": i, "source": opts.get("from", actor.rig.global_position + fw)})
			var away := -fw
			if opts.get("from") is Vector3:
				var dd: Vector3 = actor.rig.global_position - (opts.from as Vector3)
				dd.y = 0.0
				away = dd.normalized() if dd.length() > 0.05 else -fw
			actor.rig.hop(0.3 + 0.25 * i, 0.38)
			if bool(opts.get("move", not actor.scripted)):
				var tw := actor.create_tween()
				tw.tween_property(actor.rig, "global_position", actor.rig.global_position + away * (0.3 + 0.35 * i), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				(run.tweens as Array).append(tw)
			gest.call("arms_up", 0.7, "r")
			later.call(0.38, func() -> void:
				if actor.body:
					actor.body.land(0.8 * i))
		"almost_fall":
			em.trigger("fear", i * 0.8, dur * 0.6, 0.05)
			if b:
				b.stumble(-fw, 0.9 * i)
			later.call(dur * 0.7, func() -> void: em.trigger("relief", 0.7, 1.0))
		"dizzy":
			em.trigger("dizzy", i, dur, 0.1, 0.5)
			var top := actor.head_top()
			FX.dizzy_stars(actor.rig, top.y - actor.rig.global_position.y + 0.15, dur, 3 + int(i * 2.0))
			var tw2 := actor.create_tween()
			tw2.tween_method(func(x: float) -> void:
				actor.cartoon_head = Vector3(sin(x * 2.6) * 0.1, 0.0, cos(x * 2.6) * 0.14) * i * (1.0 - smoothstep(dur * 0.75, dur, x))
				if actor.body:
					actor.body.weight_shift = sin(x * 2.0) * 0.8 * i, 0.0, dur, dur)
			(run.tweens as Array).append(tw2)
		"love":
			em.trigger("love", i, dur, 0.2, 0.8)
			(run.fx as Array).append_array(_hearts(actor, 3 + int(i * 3.0), dur))
			gest.call("clasp", dur * 0.85, "r")
			var tw3 := actor.create_tween()
			tw3.tween_method(func(x: float) -> void:
				if actor.body:
					actor.body.micro_chest = Vector3(0, 0, sin(x * 3.0) * 0.06 * i), 0.0, dur, dur)
			(run.tweens as Array).append(tw3)
		"blush_shy":
			em.trigger("embarrassed", i, dur, 0.1)
			actor.look_social(actor.rig.global_position + fw * 1.4 + actor.right() * 0.9, dur * 0.8)
			gest.call("scratch" if actor.rng.randf() < 0.6 else "face_touch", dur * 0.8, "r")
			if b:
				b.crouch = 0.08 * i
		"face_in_hands":
			em.trigger("shame", i, dur, 0.12)
			gest.call("face_hide", dur, "r")
			if b:
				b.crouch = 0.12 * i
		"laugh_fit":
			actor.laugh(dur + 0.3, 1.0)
			em.trigger("laugh", 1.0, dur, 0.1)
			if actor.face:
				actor.face.set_params({"tear": 0.5 * i})
			gest.call("knee_slap" if actor.rng.randf() < 0.5 else "belly", dur * 0.85, "r")
			later.call(dur * 0.88, func() -> void: gest.call("wipe_tears", 1.0, "r"))
		"wipe_tears":
			gest.call("wipe_tears", dur, "r")
		"puff_cheeks":
			em.trigger("puffed", i, dur, 0.12, 0.5)
			if b:
				b.tremble = 0.25 * i
			gest.call("fists", dur * 0.9, "r")
			for k in 2:
				later.call(0.3 + k * 0.55, func() -> void:
					var hp := actor.head_top()
					FX.smoke(hp + actor.right() * actor.head_radius() * 0.7, Color(1, 1, 1, 0.85), 5, 0.5)
					FX.smoke(hp - actor.right() * actor.head_radius() * 0.7, Color(1, 1, 1, 0.85), 5, 0.5))
		"stomp":
			em.trigger("frustrated", i, dur, 0.06)
			if b:
				b.land(1.1 * i)
			actor.rig.squash(1.08, 0.92, 0.25)
			FX.dust(actor.rig.global_position + fw * 0.1, Color(0.8, 0.75, 0.7), 10, 0.8)
		"sulk", "look_away":
			em.trigger("sulk" if id == "sulk" else "defiant", i, dur, 0.15)
			var sgn := 1.0 if actor.rng.randf() < 0.5 else -1.0
			head_env.call(Vector3(-0.1, 0.5 * sgn, 0.0), 0.25, dur * 0.7)
			if id == "sulk":
				gest.call("cross_arms", dur, "r")
		"joy_hop":
			em.trigger("delight" if i < 0.8 else "euphoria", i, dur, 0.08)
			gest.call("cheer", dur, "r")
			var n := 2 if i < 0.75 else 3
			for k2 in n:
				later.call(k2 * 0.42, func() -> void:
					actor.rig.hop(0.25 + 0.2 * i, 0.36)
					var tw4 := actor.create_tween()
					tw4.tween_interval(0.36)
					tw4.tween_callback(func() -> void:
						if actor.body:
							actor.body.land(0.5)))
		"head_shake":
			em.trigger("disbelief", i, dur, 0.1)
			gest.call("head_shake", dur, "r")
		"hide_behind":
			em.trigger("fear", i, dur, 0.08)
			var other: LumosActor = opts.get("behind")
			if other != null and bool(opts.get("move", true)):
				var from: Vector3 = opts.get("from", other.rig.global_position + other.forward() * 3.0)
				var dir := other.rig.global_position - from
				dir.y = 0.0
				var spot := other.rig.global_position + dir.normalized() * (other.head_radius() + actor.head_radius()) * 0.9
				var tw5 := actor.create_tween()
				tw5.tween_property(actor.rig, "global_position", Vector3(spot.x, actor.rig.global_position.y, spot.z), 0.35).set_trans(Tween.TRANS_SINE)
				(run.tweens as Array).append(tw5)
				actor.rig.turn_to(from - spot, 0.3)
			if b:
				b.crouch = 0.3 * i
				b.tremble = 0.4 * i
			later.call(dur * 0.4, func() -> void: head_env.call(Vector3(0.0, 0.0, 0.25), 0.25, dur * 0.3))   # hervorlugen
		"shiver":
			em.trigger("fear", i * 0.8, dur, 0.1)
			if b:
				b.tremble = 1.0 * i
			if actor.face:
				actor.face.mouth_action("chatter", dur)
			gest.call("hug_self", dur, "r")
		"spin_joy":
			em.trigger("euphoria", i, dur, 0.06)
			actor.rig.spin_around(1.0, 0.6)
			gest.call("arms_up", dur * 0.8, "r")
			FX.stars(actor.head_top(), Color(1.0, 0.85, 0.3), 10 + int(i * 8.0))
		"sweat":
			em.trigger("nervous", i, dur, 0.15)
			(run.fx as Array).append(_sweat(actor, dur))
			gest.call("scratch", dur * 0.8, "r")
		"proud_pose":
			em.trigger("pride", i, dur, 0.15)
			gest.call("hips", dur, "r")
			head_env.call(Vector3(-0.14 * i, 0, 0), 0.25, dur * 0.6)
			if i > 0.6:
				FX.stars(actor.head_top(), Color(1.0, 0.9, 0.5), 6)
		"facepalm":
			em.trigger("embarrassed", i * 0.8, dur, 0.1)
			gest.call("facepalm", dur, "r")
			if actor.face:
				actor.face.mouth_action("sigh", 1.0)
		"puppy":
			em.trigger("puppy", i, dur, 0.2)
			gest.call("clasp", dur, "r")
			head_env.call(Vector3(0.05, 0, 0.18 * i), 0.3, dur * 0.6)
			if b:
				b.crouch = 0.06 * i
		"shrug":
			em.trigger("confused", i * 0.7, dur, 0.1)
			gest.call("shrug", dur, "r")
	if actor.body == null:
		_rigid_variant(actor, id, i, dur)


## Figuren ohne Skelett: der ganze Körper hüpft, dreht, zittert oder kippt – passend zur Reaktion.
static func _rigid_variant(actor: LumosActor, id: String, i: float, dur: float) -> void:
	match id:
		"joy_hop", "spin_joy", "big_surprise", "jump_back", "love":
			actor.rig.hop(0.25 + 0.2 * i, 0.35)
			if id == "spin_joy":
				actor.rig.spin_around(1.0, 0.6)
		"shiver", "freeze", "cry", "hide_behind", "sweat":
			actor.pet_tremble = maxf(actor.pet_tremble, i)
			var tw := actor.create_tween()
			tw.tween_property(actor, "pet_tremble", 0.0, dur).set_delay(dur * 0.4)
		"dizzy", "head_shake", "sulk", "look_away":
			actor.nudge(actor.right() * 1.5 * i)
		_:
			actor.rig.squash(1.08, 0.93, 0.3)
	if id == "cry" and i > 0.45:
		_tear_fountains(actor, i, dur * 0.6)


static func _freeze(actor: LumosActor, run: Dictionary, secs: float) -> void:
	if actor.rig.anim == null:
		return
	actor.rig.anim.speed_scale = 0.04
	var tw := actor.create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(func() -> void:
		if is_instance_valid(actor) and actor.rig.anim:
			actor.rig.anim.speed_scale = 1.0)
	(run.tweens as Array).append(tw)


# --- Effekte -------------------------------------------------------------------------------------------------

static func _tear_material() -> StandardMaterial3D:
	if _tear_mat == null:
		_tear_mat = StandardMaterial3D.new()
		_tear_mat.albedo_color = Color(0.62, 0.86, 1.0, 0.92)
		_tear_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tear_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tear_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return _tear_mat


## Augenpositionen (Welt) und Kopfmaß – aus dem Gesicht, sonst geschätzt (Haustiere, Kenney-Figuren).
static func _eyes(actor: LumosActor) -> Array:
	var out: Array = []
	if actor.face and not actor.face.metrics().is_empty():
		var m := actor.face.metrics()
		for c: Vector3 in m.eye_c:
			out.append(actor.face.global_transform * Vector3(c.x, c.y - (m.eye_r as Vector2).y * 0.5, c.z))
	else:
		var hp := actor.head_top() - Vector3.UP * actor.head_radius() * 0.8 + actor.forward() * actor.head_radius() * 0.7
		out.append(hp - actor.right() * actor.head_radius() * 0.35)
		out.append(hp + actor.right() * actor.head_radius() * 0.35)
	return out


## Zwei Fontänen, die in hohen Bögen seitlich aus den Augen schießen (nie übers Gesicht).
static func _tear_fountains(actor: LumosActor, i: float, secs: float) -> Array:
	var r := actor.head_radius()
	var out: Array = []
	var eyes := _eyes(actor)
	for k in eyes.size():
		var p := CPUParticles3D.new()
		actor.rig.add_child(p)
		p.global_position = eyes[k]
		var side := actor.right() * (-1.0 if k == 0 else 1.0)
		if actor.face:   # Augen-Reihenfolge im Gesicht ist modellabhängig – nach außen = vom Gesichtszentrum weg
			var cen := (eyes[0] as Vector3 + eyes[1] as Vector3) * 0.5
			var o := (eyes[k] as Vector3) - cen
			o.y = 0.0
			side = o.normalized() if o.length() > 0.001 else side
		var dir := (side * 0.85 + Vector3.UP * 0.75 + actor.forward() * 0.25).normalized()
		p.local_coords = false
		p.amount = int(26 + 34 * i)
		p.lifetime = 0.6
		p.one_shot = false
		p.explosiveness = 0.0
		p.direction = p.global_basis.inverse() * dir
		p.spread = 9.0
		p.gravity = p.global_basis.inverse() * Vector3(0, -9.8 * r, 0)
		p.initial_velocity_min = (2.0 + 1.6 * i) * r
		p.initial_velocity_max = (2.6 + 2.0 * i) * r
		var sm := SphereMesh.new()
		sm.radius = 0.05 * r
		sm.height = 0.1 * r
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = _tear_material()
		p.mesh = sm
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.3
		p.emitting = true
		var tw := p.create_tween()
		tw.tween_interval(secs)
		tw.tween_callback(func() -> void: p.emitting = false)
		tw.tween_interval(0.8)
		tw.tween_callback(p.queue_free)
		out.append(p)
	return out


static func _tear_drops(actor: LumosActor, secs: float) -> Array:
	var r := actor.head_radius()
	var out: Array = []
	for e: Vector3 in _eyes(actor):
		var p := CPUParticles3D.new()
		actor.rig.add_child(p)
		p.global_position = e - Vector3.UP * r * 0.12
		p.local_coords = false
		p.amount = 6
		p.lifetime = 0.7
		p.direction = Vector3.DOWN
		p.spread = 5.0
		p.gravity = Vector3(0, -6.0 * r, 0)
		p.initial_velocity_min = 0.1 * r
		p.initial_velocity_max = 0.3 * r
		var sm := SphereMesh.new()
		sm.radius = 0.035 * r
		sm.height = 0.08 * r
		sm.material = _tear_material()
		p.mesh = sm
		p.emitting = true
		var tw := p.create_tween()
		tw.tween_interval(secs)
		tw.tween_callback(func() -> void: p.emitting = false)
		tw.tween_interval(0.9)
		tw.tween_callback(p.queue_free)
		out.append(p)
	return out


static func _sprite(tex: Texture2D, size: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.transparent = true
	s.pixel_size = size / float(tex.get_width())
	s.no_depth_test = false
	return s


## Herzen steigen über dem Kopf auf, wiegen sich und verblassen.
static func _hearts(actor: LumosActor, n: int, secs: float) -> Array:
	if _heart_tex == null:
		_heart_tex = _make_heart()
	var r := actor.head_radius()
	var out: Array = []
	for k in n:
		var s := _sprite(_heart_tex, r * actor.rng.randf_range(0.32, 0.48))
		actor.rig.add_child(s)
		var start := actor.head_top() + actor.right() * actor.rng.randf_range(-0.9, 0.9) * r + Vector3.UP * r * 0.1
		s.global_position = start
		s.modulate.a = 0.0
		s.scale = Vector3.ONE * 0.3
		var tw := s.create_tween().set_parallel()
		var dl := k * secs * 0.18
		tw.tween_property(s, "modulate:a", 1.0, 0.2).set_delay(dl)
		tw.tween_property(s, "scale", Vector3.ONE, 0.3).set_delay(dl).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "global_position", start + Vector3.UP * r * 1.4 + actor.right() * actor.rng.randf_range(-0.3, 0.3) * r, secs * 0.8).set_delay(dl).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "modulate:a", 0.0, 0.35).set_delay(dl + secs * 0.6)
		tw.chain().tween_callback(s.queue_free)
		out.append(s)
	return out


## Ein Schweißtropfen gleitet seitlich am Kopf herab.
static func _sweat(actor: LumosActor, secs: float) -> Node3D:
	if _drop_tex == null:
		_drop_tex = _make_drop()
	var r := actor.head_radius()
	var s := _sprite(_drop_tex, r * 0.3)
	actor.rig.add_child(s)
	var p0 := actor.head_top() - Vector3.UP * r * 0.35 + actor.right() * r * 0.95 + actor.forward() * r * 0.2
	s.global_position = p0
	var tw := s.create_tween()
	tw.tween_property(s, "global_position", p0 - Vector3.UP * r * 0.35, secs * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "modulate:a", 0.0, secs * 0.2)
	tw.tween_callback(s.queue_free)
	return s


static func _make_heart() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var u := (x - 32.0) / 24.0
			var v := (32.0 - y) / 24.0 + 0.25
			var f := pow(u * u + v * v - 1.0, 3.0) - u * u * v * v * v
			var c := Color(1.0, 0.36, 0.5, 1.0) if f <= 0.0 else Color(0, 0, 0, 0)
			if f <= 0.0 and f > -0.06:
				c = Color(0.85, 0.15, 0.32, 1.0)   # Rand
			if f <= 0.0 and u < -0.25 and v > 0.4 and v < 0.75:
				c = Color(1.0, 0.75, 0.82, 1.0)    # Glanz
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _make_drop() -> ImageTexture:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 32:
			var u := (x - 16.0) / 11.0
			var v := (y - 30.0) / 11.0
			var inside := u * u + v * v <= 1.0 or (y > 4 and y < 30 and absf(u) < (y - 4.0) / 26.0)
			img.set_pixel(x, y, Color(0.55, 0.82, 1.0, 0.95) if inside else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
