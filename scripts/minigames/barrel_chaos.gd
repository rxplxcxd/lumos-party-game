extends MinigameBase
## Fässer-Chaos: Kapitän Knochenbart versteckt Gold in einem Fass. Dann tanzen die Fässer
## wild durcheinander. Spring ins richtige Fass (A)! Im Schatzfass gibt es Punkte – in den
## anderen stecken Bomben. 4 Runden, immer schneller.

const BARRELS := 5
const ROUNDS := 4
const SLOT_X := [-6.0, -3.0, 0.0, 3.0, 6.0]
const BARREL_Z := -2.5

var barrels: Array[Dictionary] = []     # {node, slot, treasure, occupant}
var captain: CharacterRig
var round_i := 0
var phase := "idle"
var _choose_t := 0.0
var _beliefs: Array[int] = [0, 0, 0, 0]


func _init() -> void:
	game_id = "barrel_chaos"
	env_preset = "pirates"
	time_limit = 999.0
	show_timer = false
	teaser_height = 1.0
	arena_radius = 10.0
	arena_center = Vector3(0, 0, 0)
	cannon_pos = Vector3(-12, 0.3, 6)
	spawn_points = [Vector3(-4.5, 0.4, 4.5), Vector3(-1.5, 0.4, 4.5), Vector3(1.5, 0.4, 4.5), Vector3(4.5, 0.4, 4.5)]


func build_arena() -> void:
	WorldKit.water(world, Vector2(160, 160), -1.2)
	# Schiffsdeck
	var deck := WorldKit.box(world, Vector3(20, 1.0, 14), Vector3(0, -0.5, 0), Color("#a0703f"))
	var planks: Array = []
	for x in range(-9, 10, 2):
		for z in range(-6, 7, 3):
			planks.append(Transform3D(Basis(), Vector3(x + 0.5, 0.01, z)))
	WorldKit.multimesh(world, "pirate/platform_planks", planks)
	for side in [-1.0, 1.0]:
		for z in range(-6, 7, 3):
			WorldKit.place(world, "pirate/structure", Vector3(side * 10.4, 0, z), 90.0 * side, 0.9)
	WorldKit.place(world, "pirate/mast", Vector3(0, 0, -6.5), 0.0, 1.4)
	WorldKit.place(world, "pirate/cannon", Vector3(-8.5, 0, -5), 160.0, 1.3)
	WorldKit.place(world, "pirate/cannon", Vector3(8.5, 0, -5), -160.0, 1.3)
	WorldKit.place(world, "pirate/crate_bottles", Vector3(-8.5, 0, 5), 20.0, 1.0)
	WorldKit.place(world, "pirate/ship_medium", Vector3(-30, -1.2, -24), 60.0, 1.2)
	WorldKit.place(world, "pirate/tower_watch", Vector3(26, -1.0, -20), 0.0, 1.2)
	for i in BARRELS:
		var n := Node3D.new()
		world.add_child(n)
		var model := Assets.spawn("pirate/barrel", n, Vector3.ZERO, randf() * 360.0, 1.5)
		n.position = Vector3(SLOT_X[i], 0, BARREL_Z)
		barrels.append({"node": n, "model": model, "slot": i, "treasure": false, "occupant": -1})
	captain = CharacterRig.new()
	world.add_child(captain)
	captain.setup("npc/skeleton", -1, 2.6)
	captain.position = Vector3(0, 0, -6.0)
	captain.face_now(Vector3(0, 0, 1))
	captain.play("idle")
	Assets.spawn("pirate/flag", captain, Vector3(0.9, 0, -0.3), 0.0, 0.25)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0.5, 0)
	c.offset = Vector3(0, 11, 13)
	c.follow = false


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "wood"
	_rounds()


func _rounds() -> void:
	for r in ROUNDS:
		round_i = r
		await _play_round()
		if state != "play":
			return
	end_game()


func _play_round() -> void:
	_freeze_all(true)
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.visible = true
		av.alive = true
		av.global_position = spawn_points[i]
		av.velocity = Vector3.ZERO
		av.rig.face_now(Vector3(0, 0, -1))
	for b in barrels:
		b.treasure = false
		b.occupant = -1
		(b.node as Node3D).visible = true
		(b.node as Node3D).scale = Vector3.ONE
	await CutsceneManager.big_word("Runde %d" % (round_i + 1), Color.WHITE, 0.7)
	# Kapitän versteckt den Schatz
	var treasures := 2 if round_i % 2 == 1 else 1
	var picks: Array = range(BARRELS)
	picks.shuffle()
	for k in treasures:
		barrels[picks[k]].treasure = true
	captain.react("laugh")
	Audio.sfx("evil_laugh", captain.global_position)
	for b in barrels:
		if b.treasure:
			var gold := Assets.spawn("dun/coin_stack", world, (b.node as Node3D).position + Vector3.UP * 3.5, 0.0, 1.6)
			FX.stars(gold.global_position, Color(1, 0.85, 0.2), 10)
			Audio.sfx("coin", gold.global_position)
			var tw := gold.create_tween()
			tw.tween_property(gold, "position:y", 1.0, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_property(gold, "scale", Vector3.ZERO, 0.2)
			tw.tween_callback(gold.queue_free)
	await get_tree().create_timer(1.4, false).timeout
	var first_t := 0
	for k in BARRELS:
		if barrels[k].treasure:
			first_t = k
			break
	for i in 4:
		_beliefs[i] = first_t
	# Fässer tanzen
	phase = "shuffle"
	var swaps := 6 + round_i * 3
	var dur := maxf(0.55 - round_i * 0.1, 0.22)
	for s in swaps:
		var a := randi() % BARRELS
		var b2 := (a + randi_range(1, BARRELS - 1)) % BARRELS
		await _swap(a, b2, dur)
	phase = "choose"
	# Springen!
	await CutsceneManager.big_word("SPRING REIN!", Color("#ffcc33"), 0.6)
	_freeze_all(false)
	for av in avatars:
		(av as PartyAvatar).can_jump = false
		(av as PartyAvatar).can_shove = true
	_choose_t = 5.0
	while _choose_t > 0.0 and state == "play":
		_choose_t -= get_process_delta_time()
		timer_label.visible = true
		timer_label.text = str(int(ceil(_choose_t)))
		for i in 4:
			_try_enter(i)
		await get_tree().process_frame
	timer_label.visible = false
	_freeze_all(true)
	phase = "reveal"
	await _reveal()


func _swap(a: int, b: int, dur: float) -> void:
	var ba: Dictionary = barrels[a]
	var bb: Dictionary = barrels[b]
	var na: Node3D = ba.node
	var nb: Node3D = bb.node
	var pa := na.position
	var pb := nb.position
	Audio.sfx("whoosh", pa, -8.0, 1.0 + randf() * 0.3)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		na.position = pa.lerp(pb, t) + Vector3(0, sin(t * PI) * 1.6, sin(t * PI) * 1.4)
		nb.position = pb.lerp(pa, t) + Vector3(0, sin(t * PI) * 0.4, -sin(t * PI) * 1.4)
		na.rotation.y = t * TAU
		nb.rotation.y = -t * TAU, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE)
	await tw.finished
	Juice.squash(na, 1.25, 0.8, 0.25)
	Juice.squash(nb, 1.25, 0.8, 0.25)
	Audio.sfx("wood_hit", pb, -8.0)
	# Array-Positionen tauschen (Slot folgt dem Fass)
	barrels[a] = bb
	barrels[b] = ba
	# CPU-Verfolgung (fehlbar)
	for i in 4:
		if Game.players[i].cpu:
			var acc: float = [0.7, 0.85, 0.96][int(Game.players[i].cpu_level)]
			if _beliefs[i] == a:
				_beliefs[i] = b if randf() < acc else a
			elif _beliefs[i] == b:
				_beliefs[i] = a if randf() < acc else b


func _try_enter(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	if not av.visible or not InputHub.ui_pressed(i, "a"):
		return
	for k in BARRELS:
		var b: Dictionary = barrels[k]
		var n: Node3D = b.node
		if b.occupant < 0 and av.global_position.distance_to(n.global_position) < 2.0:
			b.occupant = i
			av.freeze(true)
			var from := av.global_position
			var tw := av.create_tween()
			tw.tween_method(func(t: float) -> void:
				av.global_position = from.lerp(n.global_position + Vector3.UP * 0.5, t) + Vector3.UP * sin(t * PI) * 2.5, 0.0, 1.0, 0.35)
			tw.tween_callback(func() -> void:
				av.visible = false
				Juice.squash(n, 1.3, 0.75, 0.4)
				Audio.sfx("wood_hit", n.global_position))
			Audio.sfx("jump", from)
			return


func _reveal() -> void:
	await get_tree().create_timer(0.5, false).timeout
	Audio.sfx("drumroll")
	await get_tree().create_timer(1.2, false).timeout
	for k in BARRELS:
		var b: Dictionary = barrels[k]
		var n: Node3D = b.node
		var occ: int = b.occupant
		Juice.squash(n, 1.4, 0.7, 0.3)
		if b.treasure:
			FX.coins_burst(n.global_position, 8, true)
			FX.confetti(n.global_position + Vector3.UP, 40)
			Audio.sfx("powerup", n.global_position)
		else:
			FX.explosion(n.global_position + Vector3.UP * 0.5, 0.7)
		n.visible = false
		if occ >= 0:
			var av := avatars[occ] as PartyAvatar
			av.visible = true
			av.global_position = n.global_position + Vector3.UP * 0.3
			if b.treasure:
				add_score(occ, 3, n.global_position + Vector3.UP * 2.5)
				av.rig.react("victory")
				InputHub.rumble(occ, 0.5, 0.2)
			else:
				av.rig.react("soot_blast")
				var land := av.global_position + Vector3(randf_range(-2, 2), 0, 4.0)
				var from := av.global_position
				var tw := av.create_tween()
				tw.tween_method(func(t: float) -> void:
					av.global_position = from.lerp(land, t) + Vector3.UP * sin(t * PI) * 5.0, 0.0, 1.0, 0.8)
				InputHub.rumble(occ, 1.0, 0.3)
		await get_tree().create_timer(0.35, false).timeout
	await get_tree().create_timer(1.8, false).timeout


func _update_badges() -> void:
	for i in badges.size():
		badges[i].set_score("%d" % int(scores[i]))


# --- CPU ---------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if phase != "choose" or not av.visible or av.can_move == false:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var target := _beliefs[slot]
	if barrels[target].occupant >= 0:
		var best := -1
		var bd := INF
		for k in BARRELS:
			if barrels[k].occupant < 0:
				var d := av.global_position.distance_to((barrels[k].node as Node3D).global_position)
				if d < bd:
					bd = d
					best = k
		target = best if best >= 0 else target
	if _choose_t > 4.6 - level * 0.4:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var tp: Vector3 = (barrels[target].node as Node3D).global_position + Vector3(0, 0, 1.2)
	var to := tp - av.global_position
	var held := {}
	var bpos: Vector3 = (barrels[target].node as Node3D).global_position
	if av.global_position.distance_to(bpos) < 1.8 and Engine.get_physics_frames() % 8 < 4:
		held["a"] = true
	InputHub.set_virtual(slot, Vector2(to.x, to.z).normalized() if to.length() > 0.3 else Vector2.ZERO, held)
