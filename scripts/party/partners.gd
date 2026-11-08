class_name PartnerSystem
extends RefCounted
## Party-Partner (nach dem Vorbild der Jamboree-Partner):
## * Ab Runde 2 taucht immer wieder ein Partner auf einem Feld auf (Funkeln + Banner).
## * Wer ihn zuerst erreicht, löst ein Partner-Minispiel aus (mit kleinem Startvorteil). Der Sieger holt den
##   Partner für 3 Runden (inkl. der aktuellen) in sein Team.
## * Ein Partner "verdoppelt" fast alles: Münzen auf blauen UND roten Feldern, zwei Sterne zum doppelten
##   Preis kaufen … – und hat eine eigene Fähigkeit.
## * Überholt ein Gegner den Partner-Besitzer, wirbt er den Partner ab.

const PARTNERS := {
	"hoppel": {"name": "Hoppel", "model": "pet/bunny", "ability": "dice_plus", "desc": "+3 bis 8 Felder beim Würfeln"},
	"piepsi": {"name": "Piepsi", "model": "pet/chick", "ability": "lucky_dice", "desc": "Würfelt zweimal, die höhere Zahl zählt"},
	"mauzi": {"name": "Mauzi", "model": "pet/cat", "ability": "star_half", "desc": "Sterne kosten nur die Hälfte"},
	"hirschi": {"name": "Hirschi", "model": "pet/deer", "ability": "shop_half", "desc": "Alle Ladenpreise halbiert"},
	"muhla": {"name": "Muhla", "model": "pet/cow", "ability": "coins_turn", "desc": "3 bis 8 Münzen zu Zugbeginn"},
	"summsi": {"name": "Summsi", "model": "pet/bee", "ability": "steal_pass", "desc": "Mopst Überholten 3 bis 8 Münzen"},
	"kraxi": {"name": "Kraxi", "model": "pet/crab", "ability": "copy_item", "desc": "Kopiert ein Item beim Überholen"},
	"robbi": {"name": "Robbi", "model": "mini/robot", "ability": "item_turn", "desc": "Ein nützliches Item zu Zugbeginn"},
	"zippy": {"name": "Zippy", "model": "mini/alien", "ability": "warp_turn", "desc": "Darf sich zu Zugbeginn wegbeamen"},
	"bauli": {"name": "Bauli", "model": "mini/worker", "ability": "trap_end", "desc": "Legt am Zugende eine Münzfalle"},
}

var board: Node3D
var free_partner := ""            # Partner, der gerade auf dem Brett wartet
var free_space := -1
var _free_rig: CharacterRig
var _companions: Array = [null, null, null, null]
var _sparkle: CPUParticles3D


func _init(b: Node3D) -> void:
	board = b


## Zustand liegt in Game.party.partners: {slot: {id, until_round}}, Fallen in Game.party.traps: {space: owner}
func state() -> Dictionary:
	if not Game.party.has("partners"):
		Game.party["partners"] = {}
	return Game.party.partners


func partner_of(p: int) -> String:
	var st := state()
	var e: Variant = st.get(str(p))
	if e is Dictionary and int((e as Dictionary).get("until", 0)) >= int(Game.party.round):
		return String((e as Dictionary).id)
	return ""


func has_ability(p: int, ab: String) -> bool:
	var id := partner_of(p)
	return id != "" and String(PARTNERS[id].ability) == ab


## Faktor für "verdoppelte" Ereignisse.
func mult(p: int) -> int:
	return 2 if partner_of(p) != "" else 1


func restore_visuals() -> void:
	if Game.party.has("free_partner") and String(Game.party.free_partner) != "":
		_place_free(String(Game.party.free_partner), int(Game.party.get("free_space", -1)), false)
	for p in 4:
		_update_companion(p)


func expire_round() -> void:
	var st := state()
	for k in st.keys():
		var e: Dictionary = st[k]
		if int(e.get("until", 0)) < int(Game.party.round):
			st.erase(k)
			board._show_banner("%s verabschiedet sich von %s!" % [PARTNERS[String(e.id)].name, board._pname(int(k))], Color(1, 1, 1, 0.9), 1.0)
	for p in 4:
		_update_companion(p)


## Rundenstart: ggf. neuen Partner aufs Brett setzen.
func maybe_spawn() -> void:
	if int(Game.party.round) < 2 or String(Game.party.get("free_partner", "")) != "":
		return
	if Game.prng.randf() > 0.7:
		return
	var taken: Array = []
	for p in 4:
		var id := partner_of(p)
		if id != "":
			taken.append(id)
	var pool: Array = PARTNERS.keys().filter(func(k: String) -> bool: return not (k in taken))
	if pool.is_empty():
		return
	var id: String = pool[Game.prng.randi() % pool.size()]
	var cands: Array = []
	for sp in board.spaces:
		var sid := int(sp.id)
		if int(sp.branch) < 0 and sid != int(Game.party.star_space) and String(sp.type) in ["B", "R"]:
			var occupied := false
			for p in 4:
				if int(Game.players[p].space) == sid:
					occupied = true
			if not occupied:
				cands.append(sid)
	if cands.is_empty():
		return
	var sid2: int = cands[Game.prng.randi() % cands.size()]
	_place_free(id, sid2, true)
	board.cam.target = _free_rig
	board.cam.overview = false
	board.cam.zoom = 1.2
	await board._show_banner("Party-Partner %s ist aufgetaucht!" % PARTNERS[id].name, Color("#ffd23f"), 1.4)
	board._show_banner(String(PARTNERS[id].desc), Color(1, 1, 1, 0.9), 1.2)
	await board._wait(1.4)
	board.cam.overview = true
	board.cam.zoom = 1.0


func _place_free(id: String, sid: int, animate: bool) -> void:
	free_partner = id
	free_space = sid
	Game.party["free_partner"] = id
	Game.party["free_space"] = sid
	if _free_rig:
		_free_rig.queue_free()
	_free_rig = CharacterRig.new()
	board.add_child(_free_rig)
	var key: String = PARTNERS[id].model
	_free_rig.setup(key, -1, 1.2 if key.begins_with("pet/") else 1.6)
	_free_rig.position = board._space_pos(sid) + Vector3(0, 0.1, 0)
	_free_rig.face_now(Vector3(0, 0, 1))
	_free_rig.play("wave")
	if _sparkle:
		_sparkle.queue_free()
	_sparkle = FX.make_trail(_free_rig, "embers")
	_sparkle.color_ramp = null
	_sparkle.color = Color(1, 0.95, 0.6)
	_sparkle.emitting = true
	var halo := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.82
	tm.material = WorldKit.mat(Color("#ffd23f"), 0.4, 1.0)
	halo.mesh = tm
	halo.position.y = 0.08
	_free_rig.add_child(halo)
	if animate:
		Juice.pop_in(_free_rig, 0.5)
		FX.confetti(_free_rig.global_position + Vector3.UP * 2.0, 40)
		Audio.jingle("star")


## Prüft beim Vorbeiziehen/Landen, ob ein Partner-Ereignis ausgelöst wird. Gibt true zurück, wenn der
## Zug für ein Partner-Minispiel unterbrochen wird.
func on_pass(p: int, sid: int) -> bool:
	if free_partner != "" and sid == free_space:
		Game.party["partner_trigger"] = {"slot": p, "partner": free_partner}
		return true
	# Abwerben: Überholt p den Besitzer eines Partners?
	for o in 4:
		if o != p and int(Game.players[o].space) == sid and partner_of(o) != "" and partner_of(p) == "":
			var id := partner_of(o)
			state().erase(str(o))
			state()[str(p)] = {"id": id, "until": int(Game.party.round) + 2}
			board._show_banner("%s wirbt %s ab!" % [board._pname(p), PARTNERS[id].name], Color("#ff9db0"), 1.0)
			board.rigs[p].react("taunt")
			board.rigs[o].react("frustrated")
			_update_companion(o)
			_update_companion(p)
		elif o != p and int(Game.players[o].space) == sid:
			_pass_abilities(p, o)
	return false


func _pass_abilities(p: int, victim: int) -> void:
	if has_ability(p, "steal_pass"):
		var n := Game.prng.randi_range(3, 8)
		var real: int = -Game.add_coins(victim, -n)
		Game.add_coins(p, real)
		if real > 0:
			FX.coins_burst(board.rigs[victim].global_position + Vector3.UP, real, false)
			board._show_banner("Summsi mopst %d Münzen!" % real, Color("#ffd23f"), 0.8)
	if has_ability(p, "copy_item"):
		var items: Array = Game.players[victim].items
		if not items.is_empty() and Game.players[p].items.size() < 3:
			Game.players[p].items.append(items[0])
			board._show_banner("Kraxi kopiert ein Item!", Color("#7fd6ff"), 0.8)


## Zugbeginn-Fähigkeiten.
func turn_start(p: int) -> void:
	if has_ability(p, "coins_turn"):
		var n := Game.prng.randi_range(3, 8)
		board._coins(p, n)
		await board._show_banner("Muhla schenkt %d Münzen!" % n, Color("#ffd23f"), 0.7)
	if has_ability(p, "item_turn") and Game.players[p].items.size() < 3:
		Game.players[p].items.append("double_dice")
		await board._show_banner("Robbi bringt einen Doppelwürfel!", Color("#7fd6ff"), 0.7)
	if has_ability(p, "warp_turn"):
		var go: bool = await board._ask(p, "Zippy: Zu einem zufälligen Feld beamen?", randf() < 0.4)
		if go:
			var cands: Array = []
			for sp in board.spaces:
				if int(sp.branch) < 0:
					cands.append(int(sp.id))
			var target: int = cands[Game.prng.randi() % cands.size()]
			Game.players[p].space = target
			board.rigs[p].position = board._space_pos(target)
			FX.sparks(board.rigs[p].global_position + Vector3.UP, Color(0.5, 0.95, 1.0), 24)
			Audio.sfx("zap")
			board.cam.snap_to(board.rigs[p])


## Würfel-Modifikation.
func modify_roll(p: int, value: int) -> int:
	if has_ability(p, "lucky_dice"):
		value = maxi(value, Game.prng.randi_range(1, board.DICE_MAX))
	if has_ability(p, "dice_plus"):
		value += Game.prng.randi_range(3, 8)
	return value


## Zugende: Münzfalle legen.
func turn_end(p: int) -> void:
	if has_ability(p, "trap_end"):
		if not Game.party.has("traps"):
			Game.party["traps"] = {}
		Game.party.traps[str(int(Game.players[p].space))] = p


## Landet jemand auf einer fremden Falle: halbe Münzen an den Besitzer.
func check_trap(p: int) -> void:
	if not Game.party.has("traps"):
		return
	var key := str(int(Game.players[p].space))
	if Game.party.traps.has(key) and int(Game.party.traps[key]) != p:
		var owner := int(Game.party.traps[key])
		var n := int(Game.players[p].coins) / 2
		Game.add_coins(p, -n)
		Game.add_coins(owner, n)
		Game.party.traps.erase(key)
		FX.coins_burst(board.rigs[p].global_position + Vector3.UP, mini(n, 12), false)
		board.rigs[p].react("coin_loss")
		await board._show_banner("Münzfalle! %d Münzen an %s" % [n, board._pname(owner)], Color("#ff9db0"), 1.0)


## Partner-Minispiel ist vorbei: Sieger bekommt den Partner.
func award(winner: int) -> void:
	var id := String(Game.party.get("free_partner", ""))
	Game.party["free_partner"] = ""
	Game.party["free_space"] = -1
	free_partner = ""
	if _free_rig:
		_free_rig.queue_free()
		_free_rig = null
	if id == "" or winner < 0:
		return
	state()[str(winner)] = {"id": id, "until": int(Game.party.round) + 2}
	_update_companion(winner)
	board.cam.target = board.rigs[winner]
	board.cam.overview = false
	FX.confetti(board.rigs[winner].global_position + Vector3.UP * 2.0, 60)
	board.rigs[winner].react("victory")
	Audio.jingle("star")
	await board._show_banner("%s ist jetzt Partner von %s!" % [PARTNERS[id].name, board._pname(winner)], Color("#ffd23f"), 1.4)
	await board._wait(0.8)


func _update_companion(p: int) -> void:
	var id := partner_of(p)
	var cur: Variant = _companions[p]
	if cur and is_instance_valid(cur) and String((cur as Node).get_meta("pid", "")) == id:
		return
	if cur and is_instance_valid(cur):
		(cur as Node).queue_free()
	_companions[p] = null
	if id == "":
		return
	var r := CharacterRig.new()
	board.rigs[p].add_child(r)
	var key: String = PARTNERS[id].model
	r.setup(key, -1, 0.75 if key.begins_with("pet/") else 1.0)
	r.position = Vector3(0.8, 0, 0.5)
	r.play("idle")
	r.set_meta("pid", id)
	_companions[p] = r
	Juice.pop_in(r, 0.4)
