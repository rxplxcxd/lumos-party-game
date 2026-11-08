class_name NetAvatarSync
extends Node
## Online-Synchronisation der Spielfiguren in Minispielen.
##
## * Eigene Figur (und beim Host alle CPUs): wird lokal simuliert – Eingaben wirken sofort
##   (Client-Prediction ohne Rückfrage) – und sendet ihren Zustand mit 20–30 Hz.
## * Fremde Figuren: Physik aus, Position/Blickrichtung werden 100 ms verzögert zwischen Snapshots
##   interpoliert (bei Lücken kurz mit der Geschwindigkeit extrapoliert), Laufanimation aus der Geschwindigkeit.
## * Schubser auf fremde Figuren gehen als Ereignis an deren Besitzer (Opfer-Autorität),
##   Stürze meldet der Besitzer, das Ende (Platzierungen) bestimmt der Host.

const DELAY := 0.1

var game: MinigameBase
var _snaps: Array = [[], [], [], []]
var _t := 0.0


func setup(g: MinigameBase) -> NetAvatarSync:
	game = g
	for i in 4:
		var av := g.avatars[i] as PartyAvatar
		if av == null:
			continue
		av.net_remote = not Net.owns_slot(i)
		if av.net_remote:
			av.set_physics_process(false)
		av.fell.connect(func(a: PartyAvatar, hz: String) -> void:
			if not a.net_remote:
				Net.send({"k": "fell", "i": a.slot, "hz": hz}, true))
		av.shove_remote.connect(func(victim: PartyAvatar, dir: Vector3, power: float) -> void:
			Net.send({"k": "shove", "to": victim.slot, "d": [snappedf(dir.x, 0.01), snappedf(dir.z, 0.01)], "pw": power}, true))
	Net.message.connect(_on_msg)
	return self


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= 1.0 / Net.state_rate():
		_t = 0.0
		var batch: Array = []
		for i in 4:
			var av := game.avatars[i] as PartyAvatar
			if av and not av.net_remote and av.alive:
				var p := av.global_position
				batch.append({"i": i, "p": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)],
					"v": [snappedf(av.velocity.x, 0.01), snappedf(av.velocity.y, 0.01), snappedf(av.velocity.z, 0.01)],
					"r": snappedf(av.rig.rotation.y, 0.01), "g": 1 if av.is_on_floor() else 0})
		if not batch.is_empty():
			Net.send({"k": "asb", "l": batch}, false)


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0 - DELAY
	for i in 4:
		var av := game.avatars[i] as PartyAvatar
		if av == null or not av.net_remote or not av.alive:
			continue
		var list: Array = _snaps[i]
		if list.is_empty():
			continue
		var a: Dictionary = {}
		var b: Dictionary = {}
		for k in range(list.size() - 1, -1, -1):
			if float(list[k].rt) <= now:
				a = list[k]
				if k + 1 < list.size():
					b = list[k + 1]
				break
		if a.is_empty():
			a = list[0]
		var pos: Vector3
		var vel := _v3(a.v)
		var rot := float(a.r)
		if b.is_empty():
			pos = _v3(a.p) + Vector3(vel.x, 0, vel.z) * clampf(now - float(a.rt), 0.0, 0.2)
		else:
			var t := clampf((now - float(a.rt)) / maxf(float(b.rt) - float(a.rt), 0.001), 0.0, 1.0)
			pos = _v3(a.p).lerp(_v3(b.p), t)
			vel = vel.lerp(_v3(b.v), t)
			rot = lerp_angle(float(a.r), float(b.r), t)
		av.global_position = pos
		av.velocity = vel
		av.rig.rotation.y = rot
		var hs := Vector2(vel.x, vel.z).length()
		av.rig.locomote(hs, av.max_speed, int(a.g) == 1, vel.y, delta)


func _on_msg(_from: String, msg: Dictionary) -> void:
	match String(msg.get("k", "")):
		"asb":
			for st in msg.get("l", []):
				if st is Dictionary:
					_push(st as Dictionary)
		"shove":
			var to := int(msg.get("to", -1))
			if to >= 0 and Net.owns_slot(to):
				var av := game.avatars[to] as PartyAvatar
				var d: Array = msg.get("d", [0, 0])
				av.apply_knockback(Vector3(float(d[0]), 0, float(d[1])), float(msg.get("pw", 11.0)), 0.5, 4.5)
				InputHub.rumble(0, 0.7, 0.18)
		"fell":
			var j := int(msg.get("i", -1))
			if j >= 0:
				var av2 := game.avatars[j] as PartyAvatar
				if av2 and av2.alive:
					av2.fall_into(String(msg.get("hz", game.hazard)))
		"end":
			var pl: Array = msg.get("pl", [])
			var places: Array[int] = []
			for p in pl:
				places.append(int(p))
			if places.size() == 4:
				var fsc: Array = msg.get("sc", [])
				for fi in mini(4, fsc.size()):
					game.scores[fi] = float(fsc[fi])
				game.forced_placements = places
				game.end_game()


func _push(st: Dictionary) -> void:
	var i := int(st.get("i", -1))
	if i < 0 or i >= 4:
		return
	var av := game.avatars[i] as PartyAvatar
	if av == null or not av.net_remote:
		return
	st["rt"] = Time.get_ticks_msec() / 1000.0
	(_snaps[i] as Array).append(st)
	if (_snaps[i] as Array).size() > 16:
		(_snaps[i] as Array).pop_front()


static func _v3(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO
