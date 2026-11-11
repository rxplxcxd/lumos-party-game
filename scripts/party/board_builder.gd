class_name BoardBuilder
extends RefCounted
## Baut die 3D-Welt eines Spielbretts: Felder, Pfade, thematische Kulisse, bewegliche Routen, NPCs.
## Assets werden quer durch die Themen zweckentfremdet (Piratentruhen = Glücksrad-Kisten,
## Dungeon-Fackeln = Fallen-Felder, Kanonen = Wolkenkanonen, Krabbe = Händler …).

const TILE_KEYS := {"B": "bg/tile_blue", "R": "bg/tile_red", "L": "bg/tile_yellow", "P": "bg/tile_green", "C": "bg/tile_purple",
	"T": "bg/tile_purple", "K": "bg/tile_green", "N": "bg/tile_yellow", "S": "bg/tile_green", "G": "bg/tile_purple",
	"E": "bg/tile_blue", "W": "bg/tile_green", "D": "bg/tile_yellow", "U": "bg/tile_green", "Z": "bg/tile_yellow", "X": "bg/tile_yellow"}
const SYMBOLS := {"B": "+", "R": "-", "L": "?", "P": "!", "C": "?!", "T": "!", "K": "!", "N": "$", "S": "GO", "G": "~", "E": "»", "W": "@", "D": "VS", "U": "^", "Z": "TOP", "X": "X"}
const SYMBOL_COLORS := {"B": Color("#dff2ff"), "R": Color("#ffe0e0"), "L": Color("#7a4a00"), "P": Color("#eaffea"),
	"C": Color("#f2e0ff"), "T": Color("#ffd0a0"), "K": Color("#eaffea"), "N": Color("#7a4a00"), "S": Color("#ffffff"),
	"G": Color("#d8ffe8"), "E": Color("#e8fbff"), "W": Color("#eaffea"), "D": Color("#7a2a00"), "U": Color("#eaffea"), "Z": Color("#7a4a00"), "X": Color("#a8001e")}
const TILE_SCALE := 2.3

var root: Node3D
var def: Dictionary
var spaces: Array
var board_id := ""
var space_nodes: Array[Node3D] = []
var toggle_visuals := {}      # branch index -> Array[Node3D] (bewegliche Teile)
var gate_npc: CharacterRig
var merchant: CharacterRig
var trap_nodes := {}            # Feld → Münzfallen-Modell
var secret_paths := {}          # Abzweig → MultiMesh der Wegpunkte (unsichtbar bis entdeckt)
var gate_nodes := {}            # Abzweig → Schlüsseltor
var sleepers: Array[Node3D] = []
var traps: Array[Node3D] = []
var star_node: Node3D
var _rng := RandomNumberGenerator.new()


func build(parent: Node3D, id: String, graph: Array) -> void:
	board_id = id
	def = BoardDefs.get_def(id)
	spaces = graph
	_rng.seed = hash(id)
	root = Node3D.new()
	root.name = "Board"
	parent.add_child(root)
	# Jahreszeit der Vegetation (Upgrade-Pools in Assets): Zauberwald bemoost, sonst nach Umgebung
	if id == "glowforest":
		Assets.season = "moss"
	match id:
		"pirates":
			_build_pirates()
		"sky":
			_build_sky()
		"graveyard":
			_build_graveyard()
		"frost":
			_build_frost()
		"station":
			_build_station()
		"glowforest":
			_build_glowforest()
		"meadow":
			_build_meadow()
		"cake":
			_build_cake()
		"tower":
			_build_tower()
		_:
			_build_dungeon()
	_build_extra()
	_build_spaces()
	_build_paths()
	_build_star()


# --- Felder ------------------------------------------------------------------------------------------

func _build_spaces() -> void:
	var title_font: Font = load(Assets.FONT_TITLE)
	for sp in spaces:
		var t: String = sp.type
		var holder := Node3D.new()
		root.add_child(holder)
		holder.position = sp.pos
		var tile := Assets.spawn(TILE_KEYS.get(t, "bg/tile_blue"), holder, Vector3.ZERO, 0.0, TILE_SCALE)
		tile.scale.y = TILE_SCALE * 0.9
		var lbl := Label3D.new()
		lbl.text = SYMBOLS.get(t, "")
		lbl.font = title_font
		lbl.font_size = 140 if lbl.text.length() == 1 else 96
		lbl.outline_size = 0
		lbl.modulate = SYMBOL_COLORS.get(t, Color.WHITE)
		lbl.rotation_degrees.x = -90
		lbl.position.y = 0.5
		lbl.pixel_size = 0.0075
		lbl.shaded = false
		lbl.double_sided = false
		holder.add_child(lbl)
		_space_prop(holder, t, sp)
		if board_id == "sky":
			var island := Assets.spawn("plat/block_grass_large", holder, Vector3(0, -2.05, 0), _rng.randf() * 360.0, 1.4)
			island.scale.y = 2.0
		elif board_id == "tower":
			# Laufsteg-Planke unter jedem Feld, zum Turm hin ausgerichtet
			var plank := WorldKit.box(holder, Vector3(3.4, 0.35, 3.0), Vector3(0, -0.2, 0), Color("#e8c79a") if sp.branch < 0 else Color("#8fd16a"), false)
			plank.look_at(Vector3(0, holder.global_position.y - 0.2, 0), Vector3.UP)
		space_nodes.append(holder)


## Schlüsseltore, Geheimgänge (versteckt bis entdeckt) und Schatzkammer-Schild
func _build_route_features() -> void:
	var revealed: Dictionary = Game.party.get("revealed", {})
	for bi in def.branches.size():
		var br: Dictionary = def.branches[bi]
		var first := -1
		for sp in spaces:
			if int(sp.branch) == bi:
				first = int(sp.id)
				break
		if first < 0:
			continue
		if bool(br.get("lock", false)):
			var a: Vector3 = spaces[br.from].pos
			var b: Vector3 = spaces[first].pos
			var gate := Node3D.new()
			root.add_child(gate)
			gate.position = a.lerp(b, 0.5)
			gate.look_at(gate.position + (b - a).normalized(), Vector3.UP)
			var door := Assets.spawn("qp/door", gate, Vector3.ZERO, 0.0, 0.42)
			door.name = "Door"
			var lock := Label3D.new()
			lock.text = "Schlüssel"
			lock.font = UI.title_font()
			lock.font_size = 72
			lock.outline_size = 16
			lock.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lock.pixel_size = 0.006
			lock.position = Vector3.UP * 2.3
			lock.modulate = Color("#ffd166")
			gate.add_child(lock)
			gate_nodes[bi] = gate
		if bool(br.get("secret", false)) and not bool(revealed.get(bi, revealed.get(str(bi), false))):
			reveal_branch(bi, false, false)
		if bool(br.get("detour", false)):
			var sign := Assets.spawn("plat/sign", root, (spaces[br.from].pos as Vector3) + _outward(spaces[br.from]) * 2.2, 0.0, 1.0)
			sign.look_at(Vector3(0, sign.position.y, 0), Vector3.UP)


## Geheimgang zeigen/verbergen (Felder + Wegpunkte), mit kleinem Auftauch-Effekt
func reveal_branch(bi: int, show: bool, animate := true) -> void:
	if secret_paths.has(bi):
		(secret_paths[bi] as Node3D).visible = show
	for sp in spaces:
		if int(sp.branch) != bi:
			continue
		var node: Node3D = space_nodes[int(sp.id)] if int(sp.id) < space_nodes.size() else null
		if node == null:
			continue
		node.visible = show
		if show and animate:
			node.scale = Vector3.ONE * 0.05
			node.create_tween().tween_property(node, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK)
			FX.sparks(node.global_position + Vector3.UP, Color(0.8, 0.7, 1.0), 10)


## Tor kurz öffnen (Schlüssel benutzt)
func open_gate(bi: int) -> void:
	var g: Node3D = gate_nodes.get(bi)
	if g == null:
		return
	var door := g.get_node_or_null("Door") as Node3D
	if door:
		var tw := door.create_tween()
		tw.tween_property(door, "rotation:y", 1.6, 0.35).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(1.6)
		tw.tween_property(door, "rotation:y", 0.0, 0.4)
	Audio.sfx("chest_open", g.global_position)
	FX.sparks(g.global_position + Vector3.UP * 1.5, Color(1, 0.9, 0.4), 12)


## Münzfallen-Modell auf einem Feld (in Spielerfarbe)
func set_trap_visual(sp: int, on: bool, col := Color.WHITE) -> void:
	if trap_nodes.has(sp):
		(trap_nodes[sp] as Node3D).queue_free()
		trap_nodes.erase(sp)
	if not on or sp < 0 or sp >= space_nodes.size():
		return
	var t := Assets.spawn("qp/spike_trap", space_nodes[sp], Vector3(0, 0.45, 0), 0.0, 0.55)
	Assets.tint(t, col.lerp(Color.WHITE, 0.3))
	trap_nodes[sp] = t


func _space_prop(holder: Node3D, t: String, sp: Dictionary) -> void:
	var side := _outward(sp) * 1.9
	match t:
		"X":
			var tr := Assets.spawn("mt/treasure", holder, side * 1.35, 0.0, 1.5)   # frei neben der Feldkante
			tr.look_at(holder.global_position + Vector3(0, tr.global_position.y - holder.global_position.y, 0), Vector3.UP)
		"L":
			var key: String = {"dungeon": "dun/chest", "sky": "plat/chest", "graveyard": "dun/chest", "frost": "hol/present_red", "station": "plat/chest", "glowforest": "plat/chest", "meadow": "plat/chest", "cake": "hol/present_red"}.get(board_id, "pirate/chest")
			var chest := Assets.spawn(key, holder, side, 0.0, 0.9 if board_id == "dungeon" else 1.2)
			chest.look_at(holder.global_position + Vector3(0, chest.global_position.y - holder.global_position.y, 0), Vector3.UP)
			chest.rotate_object_local(Vector3.UP, PI)
			chest.set_meta("chest", true)
			traps.append(chest)
		"P":
			var plank := Assets.spawn("pirate/platform_planks", holder, side * 0.8 + Vector3.UP * 0.25, 0.0, 1.0)
			plank.scale = Vector3(0.8, 1.0, 1.4)
			plank.look_at(holder.global_position + Vector3.UP * 0.25, Vector3.UP)
			Assets.spawn("pirate/barrel", holder, side * 1.4, _rng.randf() * 360.0, 0.8)
			traps.append(plank)
		"C":
			var g := Assets.spawn("grave/gravestone_round", holder, side, 0.0, 2.0)
			g.look_at(holder.global_position + Vector3(0, g.global_position.y - holder.global_position.y, 0), Vector3.UP)
			g.rotate_object_local(Vector3.UP, PI)
			Assets.spawn("grave/candles", holder, side * 1.3 + Vector3(0.6, 0, 0), 0.0, 2.0)
			traps.append(g)
		"T":
			for s in [-1.0, 1.0]:
				var perp: Vector3 = Vector3(-side.z, 0, side.x).normalized() * 1.3 * float(s)
				Assets.spawn("dun/torch", holder, perp + Vector3.UP * 0.55, 0.0, 1.6)
			WorldKit.torch_light(holder, Vector3(0, 1.6, 0), Color(1.0, 0.55, 0.2), 1.4, 5.0)
			traps.append(holder)
		"K":
			if board_id == "meadow":
				var dd := _dandelion(holder, side * 1.1, 1.1)
				traps.append(dd)
			elif board_id == "station":
				var rk := _toy_rocket(holder, side * 1.2, 0.9)
				traps.append(rk)
			else:
				var c := Assets.spawn("pirate/cannon", holder, side, 0.0, 1.3)
				c.look_at(holder.global_position + Vector3(0, c.global_position.y - holder.global_position.y, 0), Vector3.UP)
				c.rotate_object_local(Vector3.UP, PI)                  # Mündung (-Z) vom Feld weg …
				c.rotate_object_local(Vector3.RIGHT, deg_to_rad(38))   # … und schräg in den Himmel
				traps.append(c)
		"G":
			var lamp := Assets.spawn("grave/lantern", holder, side, 0.0, 2.0)
			traps.append(lamp)
			var gl := OmniLight3D.new()
			gl.light_color = Color(0.45, 1.0, 0.7)
			gl.light_energy = 1.2
			gl.omni_range = 4.0
			gl.position = side + Vector3.UP * 1.2
			holder.add_child(gl)
		"E":
			var ice := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 1.5
			cm.bottom_radius = 1.6
			cm.height = 0.06
			var im := WorldKit.mat(Color(0.75, 0.92, 1.0, 0.75), 0.05, 0.25)
			im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			im.metallic_specular = 1.0
			cm.material = im
			ice.mesh = cm
			ice.position.y = 0.42
			holder.add_child(ice)
			Assets.spawn("hk/snow_pile", holder, side * 1.1, _rng.randf() * 360.0, 1.4)
			traps.append(holder)
		"D":
			for sd in [-1.0, 1.0]:
				var fl := Assets.spawn("plat/flag", holder, Vector3(-side.z, 0, side.x) * 1.2 * float(sd), 0.0, 1.4)
				Assets.tint(fl, Color("#ff9f1a") if sd < 0 else Color("#7ec8ff"))
		"W":
			if board_id == "glowforest":
				for m in 8:
					var am := TAU * m / 8.0
					var mush := Assets.spawn("plat/mushrooms", holder, Vector3(cos(am), 0, sin(am)) * 1.5, randf() * 360.0, 0.9)
					Assets.tint(mush, Color(1.0, 0.85, 1.2), false, 0.5)
			else:
				var pad := MeshInstance3D.new()
				var pcm := CylinderMesh.new()
				pcm.top_radius = 1.4
				pcm.bottom_radius = 1.5
				pcm.height = 0.12
				pcm.material = WorldKit.mat(Color("#ffe9a8"), 0.5, 0.3)
				pad.mesh = pcm
				pad.position.y = 0.02
				holder.add_child(pad)
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 1.25
			tm.outer_radius = 1.45
			tm.material = WorldKit.mat(Color("#ffd27a") if board_id != "glowforest" else Color("#d9a8ff"), 0.4, 0.9)
			ring.mesh = tm
			ring.position.y = 0.5
			holder.add_child(ring)
			var tw := ring.create_tween().set_loops()
			tw.tween_property(ring, "position:y", 1.1, 0.9).set_trans(Tween.TRANS_SINE)
			tw.tween_property(ring, "position:y", 0.5, 0.9).set_trans(Tween.TRANS_SINE)
			traps.append(holder)
		"N":
			var stall := Assets.spawn("town/stall", holder, side * 1.2, 0.0, 2.2)
			stall.look_at(holder.global_position + Vector3(0, stall.global_position.y - holder.global_position.y, 0), Vector3.UP)
			stall.rotate_object_local(Vector3.UP, PI)
			if merchant == null:
				merchant = CharacterRig.new()
				holder.add_child(merchant)
				var mkey: String = {"frost": "pet/deer", "station": "pet/chick", "glowforest": "pet/deer", "meadow": "pet/cow", "cake": "pet/bunny", "graveyard": "npc/ghost", "dungeon": "npc/bear"}.get(board_id, "pet/crab")
				merchant.setup(mkey, -1, 0.9 if mkey.begins_with("pet/") else 1.3)
				merchant.position = side * 0.75
				merchant.face_now(-side)
				merchant.play("idle")
		"S":
			Assets.spawn("bg/flag_red", holder, side, 0.0, 2.5)
		"U":
			# Aufwind: wirbelnde Blätter über dem Feld
			var swirl := FX.emitter({"amount": 14, "life": 1.4, "one_shot": false, "explosive": 0.0, "spread": 25.0, "dir": Vector3.UP,
				"vel_min": 2.0, "vel_max": 3.4, "gravity": Vector3.ZERO, "size": 0.16, "color": Color(0.7, 1.0, 0.75), "box": Vector3(1.2, 0.1, 1.2)})
			holder.add_child(swirl)
			swirl.position = Vector3(0, 0.4, 0)
			swirl.emitting = true
			traps.append(holder)
		"Z":
			# Gipfel: goldener Stern-Sockel
			var ped := WorldKit.cylinder(holder, 1.2, 0.5, Vector3(0, 0.3, 0), Color("#ffd23f"), false)
			ped.name = "Summit"
			var crown := Assets.spawn("plat/star", holder, Vector3(0, 2.6, 0), 0.0, 1.8)
			Assets.tint(crown, Color(1.1, 1.0, 0.6), false, 0.8)
			var spin := crown.create_tween().set_loops()
			spin.tween_property(crown, "rotation:y", TAU, 3.0).as_relative()


func _outward(sp: Dictionary) -> Vector3:
	var p: Vector3 = sp.pos
	var flat := Vector3(p.x, 0, p.z)
	if flat.length() < 0.5:
		return Vector3.BACK
	return flat.normalized()


func _secret_of(sp: Dictionary, nb: Dictionary) -> int:
	for bi in [int(sp.branch), int(nb.branch)]:
		if bi >= 0 and bool(def.branches[bi].get("secret", false)):
			return bi
	return -1


func _build_paths() -> void:
	var xfs: Array = []
	var secret_xfs := {}
	for sp in spaces:
		for nid in sp.next:
			var sb := _secret_of(sp, spaces[nid])
			var a: Vector3 = sp.pos
			var b: Vector3 = spaces[nid].pos
			var d := a.distance_to(b)
			var steps := int(d / 0.8)
			for k in range(1, steps):
				var t := float(k) / steps
				if t * d < 1.3 or (1.0 - t) * d < 1.3:
					continue
				var p := a.lerp(b, t) + Vector3.UP * 0.06
				var xf := Transform3D(Basis().scaled(Vector3(0.28, 0.12, 0.28)), p)
				if sb >= 0:
					if not secret_xfs.has(sb):
						secret_xfs[sb] = []
					(secret_xfs[sb] as Array).append(xf)
				else:
					xfs.append(xf)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 10
	sm.rings = 5
	sm.material = WorldKit.mat(Color(1, 0.95, 0.8), 0.6, 0.15)
	mm.mesh = sm
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	for sb in secret_xfs:
		var smm := MultiMesh.new()
		smm.transform_format = MultiMesh.TRANSFORM_3D
		smm.mesh = sm
		var arr: Array = secret_xfs[sb]
		smm.instance_count = arr.size()
		for i in arr.size():
			smm.set_instance_transform(i, arr[i])
		var smi := MultiMeshInstance3D.new()
		smi.multimesh = smm
		smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(smi)
		secret_paths[sb] = smi
	_build_route_features()


func _build_star() -> void:
	star_node = Node3D.new()
	root.add_child(star_node)
	var s := Assets.spawn("plat/star", star_node, Vector3.ZERO, 0.0, 6.0)
	Assets.tint(s, Color(1.2, 1.1, 0.6), false, 0.6)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.85, 0.3)
	l.light_energy = 2.0
	l.omni_range = 6.0
	l.position.y = 0.8
	star_node.add_child(l)
	var sparkle := FX.make_trail(star_node, "embers")
	sparkle.color_ramp = null
	sparkle.color = Color(1, 0.95, 0.5)
	sparkle.emitting = true
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "rotation:y", TAU, 2.5).as_relative()
	var tw2 := star_node.create_tween().set_loops()
	tw2.tween_property(s, "position:y", 0.4, 0.9).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(s, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	star_node.visible = false


## Platz-für-Kulisse prüfen (nicht auf Feldern/Pfaden).
func _free_spot(p: Vector3, min_d := 3.2, tall := false) -> bool:
	for sp in spaces:
		var q: Vector3 = sp.pos
		if Vector2(p.x - q.x, p.z - q.z).length() < min_d:
			return false
		# Hohe Deko nicht in den Kamerakorridor (Kamera steht hinter dem Spieler auf +Z)
		if tall and p.z > q.z and p.z - q.z < 10.0 and absf(p.x - q.x) < 4.5:
			return false
	return true


## Etappe 3: Themen-Details aus den neuen Low-Poly-Packs – Felder, Ufer, Lager, Ruinen, Grubenbahn, Strandgut.
## Alles über _scatter_free (hält Abstand zu Feldern und Wegen), daher nie im Weg der Figuren.
func _build_extra() -> void:
	var A := Rect2(-30, -22, 60, 44)
	match board_id:
		"meadow":
			_scatter_free(["qn/corn", "qn/corn_b", "qn/wheat"], 22, A, 0.0, Vector2(0.9, 1.2), 3.0)
			_scatter_free(["mt/cattail", "mt/cattail_b", "mt/grass_clump", "env/plant_lotus"], 18, A, 0.0, Vector2(1.4, 2.0), 2.6)
			_scatter_free(["mt/hollow_trunk", "mt/sit_log", "mt/wood_pile", "qn/log_moss", "mt/stepping", "mt/stepping_b"], 10, A, 0.0, Vector2(1.3, 1.7), 3.4)
			_scatter_free(["mt/campfire", "mt/lean_to"], 2, A, 0.0, Vector2(1.4, 1.6), 5.0)
			_scatter_free(["qp/tree_fruit", "qp/bush_fruit"], 5, A, 0.0, Vector2(0.28, 0.36), 4.5)
		"pirates":
			_scatter_free(["mt/shell", "mt/shell_b", "mt/starfish"], 26, A, 0.02, Vector2(4.0, 6.0), 2.4)
			_scatter_free(["mt/coconut", "mt/treasure", "qp/chest"], 7, A, 0.0, Vector2(1.3, 1.8), 3.6)
			_scatter_free(["mt/palm", "mt/dock_steps"], 6, A, 0.0, Vector2(1.1, 1.4), 4.5)
		"dungeon":
			_scatter_free(["mt/stalagmite", "mt/stalagmite_s", "mt/minecart", "mt/pick", "mt/support", "mt/rail_stop"], 16, A, 0.0, Vector2(1.4, 2.2), 3.4)
			_scatter_free(["qp/gem_blue", "qp/gem_pink", "qp/gem_green"], 8, A, 0.3, Vector2(0.3, 0.45), 3.0)
		"graveyard":
			_scatter_free(["qn/tree_dead", "mt/ruin", "mt/ruin_b", "mt/ruin_c", "qn/log_moss", "qn/stump_moss"], 14, A, 0.0, Vector2(1.1, 1.6), 3.6)
		"frost":
			_scatter_free(["qn/tree_dead_snow", "mt/wood_pile", "mt/lean_to", "mt/sit_log"], 10, A, 0.0, Vector2(1.1, 1.5), 3.8)
		"glowforest":
			_scatter_free(["mt/hollow_trunk", "qn/log_moss", "qn/stump_moss", "qn/rock_moss", "env/plant_bulb", "env/plant_lotus", "mt/cattail"], 22, A, 0.0, Vector2(1.2, 1.8), 3.0)
			_scatter_free(["qn/willow_autumn", "qn/birch_autumn"], 4, A, 0.0, Vector2(0.9, 1.1), 5.0)
		"cake":
			_scatter_free(["qp/tree_fruit", "qp/bush_fruit", "qp/fruit"], 10, A, 0.0, Vector2(0.25, 0.34), 4.0)
		"sky":
			_scatter_free(["qp/cloud_a", "qp/cloud_b", "qp/cloud_c"], 8, A, -1.2, Vector2(1.2, 1.8), 4.5)


func _scatter_free(keys: Array, count: int, area: Rect2, y := 0.0, scl := Vector2(0.8, 1.2), min_d := 3.2) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var p := Vector3(_rng.randf_range(area.position.x, area.end.x), y, _rng.randf_range(area.position.y, area.end.y))
		var tall := false
		for k in keys:
			if String(k).contains("palm") or String(k).contains("tree") or String(k).contains("tower") or String(k).contains("pillar"):
				tall = true
		if _free_spot(p, min_d, tall):
			WorldKit.place(root, keys[_rng.randi() % keys.size()], p, _rng.randf() * 360.0, _rng.randf_range(scl.x, scl.y))
			placed += 1


# --- Dungeon Deep ------------------------------------------------------------------------------------

func _build_dungeon() -> void:
	# Boden aus Dungeon-Platten (MultiMesh), Lavakanal in der Mitte
	var floor_x: Array = []
	for x in range(-30, 31, 4):
		for z in range(-22, 23, 4):
			if z > -6 and z < 6 and x > -18 and x < 20:
				continue
			floor_x.append(Transform3D(Basis(), Vector3(x, 0, z)))
	WorldKit.multimesh(root, "dun/floor_large", floor_x)
	WorldKit.box(root, Vector3(64, 1, 48), Vector3(0, -1.8, 0), Color(0.16, 0.12, 0.16), false)
	WorldKit.lava(root, Vector2(40, 12), -0.45, Vector2(0.12, 0.0))
	# Kanalränder
	for x in range(-18, 21, 2):
		WorldKit.place(root, "dun/barrier", Vector3(x, 0, -6.2), 0.0, 1.0)
		WorldKit.place(root, "dun/barrier", Vector3(x, 0, 6.2), 180.0, 1.0)
	# Außenmauern mit Fackeln
	for x in range(-28, 29, 4):
		WorldKit.place(root, "dun/wall" if (x / 4) % 3 != 0 else "dun/wall_arched", Vector3(x, 0, -22), 0.0, 1.0)
	for z in range(-20, 21, 4):
		WorldKit.place(root, "dun/wall", Vector3(-30, 0, z), 90.0, 1.0)
		WorldKit.place(root, "dun/wall", Vector3(30, 0, z), -90.0, 1.0)
	for x in range(-26, 27, 12):
		var t := WorldKit.place(root, "dun/torch_mounted", Vector3(x, 2.6, -21.4), 0.0, 1.4)
		t.rotation_degrees.y = 180
		WorldKit.torch_light(root, Vector3(x, 3.3, -20.6), Color(1.0, 0.55, 0.2), 2.2, 10.0)
	for p in [Vector3(-26, 0, -18), Vector3(26, 0, -18), Vector3(-26, 0, 18), Vector3(26, 0, 18), Vector3(0, 0, 19), Vector3(-12, 0, -18), Vector3(12, 0, 18)]:
		WorldKit.place(root, "dun/pillar_deco", p, 0.0, 1.0)
	WorldKit.torch_light(root, Vector3(0, 4, 0), Color(1.0, 0.45, 0.2), 2.0, 22.0)
	_scatter_free(["dun/barrel", "dun/crates", "dun/box_stacked", "dun/keg", "dun/coin_stack", "dun/rubble", "dun/candle", "dun/sword_shield", "dun/shelf", "dun/table"],
		34, Rect2(-27, -20, 54, 40), 0.0, Vector2(0.8, 1.1), 3.0)
	for i in 4:
		WorldKit.place(root, "dun/banner" if i % 2 == 0 else "dun/banner_blue", Vector3(-21 + i * 14, 0, -21.5), 0.0, 1.0)
	# Schlafende Skelette & Geister (Runden-Intro)
	for p in [Vector3(-24, 0, 6), Vector3(24, 0, -14), Vector3(-6, 0, 19)]:
		var sk := CharacterRig.new()
		root.add_child(sk)
		sk.setup("npc/skeleton", -1, 2.6)
		sk.position = p
		sk.rotation.y = _rng.randf() * TAU
		sk.play("sit")
		sleepers.append(sk)
	# Lava-Steg (Route 0) – Plattformen unter den Abzweig-Feldern
	_toggle_platforms(0, "plat/block_moving", 0.75, Vector3(0, -0.85, 0))
	# Skelett-Wächter am Tor (Route 1)
	var gate_space := _branch_first_space(1)
	if gate_space >= 0:
		gate_npc = CharacterRig.new()
		root.add_child(gate_npc)
		gate_npc.setup("npc/skeleton", -1, 3.0)
		var gp: Vector3 = spaces[gate_space].pos
		var fwd: Vector3 = (spaces[spaces[gate_space].next[0]].pos - gp).normalized()
		gate_npc.position = gp + Vector3(-fwd.z, 0, fwd.x) * 1.8
		gate_npc.face_now(-Vector3(-fwd.z, 0, fwd.x))
		gate_npc.play("idle")
		var portal := WorldKit.place(root, "dun/wall_gated", gp - fwd * 1.6, 0.0, 0.8)
		portal.look_at(gp - fwd * 1.6 + fwd, Vector3.UP)


# --- Pirates Cove ---------------------------------------------------------------------------------------

func _build_pirates() -> void:
	WorldKit.water(root, Vector2(240, 240), -0.45)
	var sand := WorldKit.cylinder(root, 1.0, 1.0, Vector3(0, -0.5, 0), Color("#dcb878"), false)
	sand.scale = Vector3(27, 0.9, 20)
	var grass := WorldKit.cylinder(root, 1.0, 1.0, Vector3(0, -0.02, 0), Color("#8fd16a"), false)
	grass.scale = Vector3(14, 0.06, 8)
	_scatter_free(["pirate/palm", "pirate/palm_bend", "pirate/palm_detailed", "nat/tree_palm", "nat/tree_palm_bend"], 26, Rect2(-24, -18, 48, 36), 0.0, Vector2(0.9, 1.3), 3.4)
	_scatter_free(["pirate/rocks_a", "pirate/rocks_b", "pirate/patch_sand", "pirate/grass", "pirate/barrel", "pirate/crate", "pirate/crate_bottles", "pirate/bottle", "nat/flower_red", "nat/bush"],
		30, Rect2(-24, -17, 48, 34), 0.0, Vector2(0.8, 1.3), 2.8)
	WorldKit.place(root, "pirate/ship_large", Vector3(-34, -1.2, -10), 80.0, 1.2)
	WorldKit.place(root, "pirate/ship_medium", Vector3(30, -1.0, 16), -110.0, 1.2)
	WorldKit.place(root, "pirate/ship_wreck", Vector3(18, -0.8, -30), 20.0, 1.3)
	WorldKit.place(root, "pirate/ship_ghost", Vector3(-26, -1.0, 30), -30.0, 1.0)
	WorldKit.place(root, "pirate/tower", Vector3(-22, 0, -16), 30.0, 1.0)
	WorldKit.place(root, "pirate/tower_watch", Vector3(23, 0, -14), -20.0, 1.0)
	WorldKit.place(root, "pirate/flag", Vector3(0, 0, 0), 0.0, 1.6)
	WorldKit.place(root, "water/buoy", Vector3(10, -0.4, 24), 0.0, 2.0)
	WorldKit.place(root, "water/boat_sail", Vector3(-8, -0.5, 26), 40.0, 2.0)
	for p in [Vector3(-14, 0, 15), Vector3(14, 0, -2)]:
		WorldKit.place(root, "pirate/cannon", p, _rng.randf() * 360.0, 1.4)
	# Schlafende Piraten-Tiere
	for p in [Vector3(-10, 0, -2), Vector3(12, 0, 4), Vector3(-2, 0, 18)]:
		var r := CharacterRig.new()
		root.add_child(r)
		r.setup(["pet/cat", "pet/bunny", "pet/cow"][sleepers.size() % 3], -1, 1.0)
		r.position = p
		r.rotation.y = _rng.randf() * TAU
		r.play("idle")
		sleepers.append(r)
	# Ebbe-Route: Sandbänke unter den Feldern
	_toggle_platforms(0, "pirate/platform", 1.3, Vector3(0, -0.2, 0))
	_toggle_platforms(1, "pirate/dock_small", 1.0, Vector3(0, -1.1, 0), false)


# --- Sky Kingdom -----------------------------------------------------------------------------------------

func _build_sky() -> void:
	var clouds := WorldKit.water(root, Vector2(300, 300), -10.0, Color(0.92, 0.94, 1.0), Color(1, 1, 1))
	(clouds.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("wave_height", 0.8)
	(clouds.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("alpha", 1.0)
	for i in 26:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(32, 70)
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = _rng.randf_range(3, 8)
		sm.height = sm.radius * 1.2
		sm.material = WorldKit.mat(Color(1, 1, 1), 1.0, 0.25)
		puff.mesh = sm
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(puff)
		puff.position = Vector3(cos(a) * r, _rng.randf_range(-12, 6), sin(a) * r)
	# Zentrale Burginsel
	var isle := Assets.spawn("plat/block_grass_large", root, Vector3(0, -6, 0), 0.0, 5.0)
	isle.scale.y = 6.0
	for p in [Vector3(-3, 0, -2), Vector3(3, 0, -2), Vector3(0, 0, 2)]:
		var base := Assets.spawn("castle/tower_base", root, p, 0.0, 3.0)
		Assets.spawn("castle/tower_mid", base, Vector3(0, 1.0, 0), 0.0, 1.0)
		Assets.spawn("castle/tower_mid", base, Vector3(0, 2.0, 0), 0.0, 1.0)
		Assets.spawn("castle/tower_roof", base, Vector3(0, 3.0, 0), 0.0, 1.0)
	WorldKit.place(root, "castle/flag", Vector3(0, 12, 2), 0.0, 3.0)
	WorldKit.place(root, "town/windmill", Vector3(-24, -1, 6), 40.0, 2.4)
	WorldKit.place(root, "town/fountain", Vector3(22, -1, 0), 0.0, 2.2)
	for p in [Vector3(-26, -2, -8), Vector3(26, -2, 10), Vector3(0, -2, -22), Vector3(-6, -1, 22)]:
		var island := Assets.spawn("plat/block_grass_overhang", root, p, _rng.randf() * 360.0, 3.0)
		Assets.spawn(["plat/tree", "plat/tree_pine", "castle/tree", "nat/tree_oak"][_rng.randi() % 4], island, Vector3(0, 1, 0), 0.0, 1.2)
	_scatter_free(["plat/flowers", "plat/mushrooms", "nat/flower_yellow", "nat/flower_purple", "plat/tree", "castle/tree", "plat/flag", "plat/heart"],
		22, Rect2(-24, -18, 48, 36), -0.2, Vector2(1.2, 1.8), 3.5)
	for p in [Vector3(-16, 0, 3), Vector3(15, 0, -1), Vector3(5, 0, 19)]:
		var r := CharacterRig.new()
		root.add_child(r)
		r.setup(["pet/chick", "pet/bee", "pet/deer"][sleepers.size() % 3], -1, 1.0)
		r.position = p + Vector3.UP * 2.0
		r.play("idle")
		sleepers.append(r)
	# Zugbrücken
	_toggle_platforms(0, "castle/bridge_draw", 2.6, Vector3(0, 0.05, 0), false)
	_toggle_platforms(1, "castle/bridge_draw", 2.6, Vector3(0, 0.05, 0), false)


# --- Geisterfriedhof ---------------------------------------------------------------------------------------

func _build_graveyard() -> void:
	WorldKit.box(root, Vector3(70, 1, 52), Vector3(0, -0.5, 0), Color("#2c3a2c"), false)
	# Moosige Grabfelder, Zäune und Krypten
	_scatter_free(["grave/gravestone", "grave/gravestone_round", "grave/gravestone", "grave/debris", "grave/pumpkin", "grave/candles"],
		46, Rect2(-28, -20, 56, 40), 0.0, Vector2(1.6, 2.2), 2.6)
	_scatter_free(["grave/pine", "nat/stump", "grave/pine", "nat/rock_tall"], 16, Rect2(-30, -22, 60, 44), 0.0, Vector2(2.0, 2.8), 3.6)
	for x in range(-30, 31, 3):
		WorldKit.place(root, "grave/fence", Vector3(x, 0, -22), 0.0, 2.0)
	for z in range(-20, 21, 3):
		WorldKit.place(root, "grave/fence", Vector3(-31, 0, z), 90.0, 2.0)
		WorldKit.place(root, "grave/fence", Vector3(31, 0, z), -90.0, 2.0)
	WorldKit.place(root, "grave/crypt", Vector3(0, 0, -2), 0.0, 3.0)
	WorldKit.place(root, "grave/crypt_small", Vector3(-25, 0, -16), 40.0, 2.6)
	WorldKit.place(root, "grave/crypt_small", Vector3(25, 0, 17), -140.0, 2.6)
	WorldKit.place(root, "grave/obelisk", Vector3(-8, 0, 1), 0.0, 2.4)
	WorldKit.place(root, "grave/obelisk", Vector3(8, 0, -1), 0.0, 2.4)
	WorldKit.place(root, "grave/altar", Vector3(14, 0, 1), -90.0, 2.4)
	for p in [Vector3(-26, 0, 8), Vector3(26, 0, -10), Vector3(-6, 0, -20), Vector3(14, 0, 19), Vector3(-16, 0, 18)]:
		WorldKit.place(root, "grave/lightpost", p, 0.0, 2.2)
		WorldKit.torch_light(root, p + Vector3.UP * 3.6, Color(1.0, 0.7, 0.35), 1.8, 9.0)
	for p in [Vector3(-12, 0, 6), Vector3(4, 0, 8), Vector3(16, 0, -8)]:
		WorldKit.place(root, "grave/fire_basket", p, 0.0, 2.0)
		WorldKit.torch_light(root, p + Vector3.UP * 1.6, Color(0.5, 1.0, 0.6), 1.6, 7.0)
	# Mond + Bodennebel
	var moon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 6.0
	sm.height = 12.0
	sm.material = WorldKit.mat(Color("#f0f0ff"), 1.0, 1.6)
	moon.mesh = sm
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(moon)
	moon.position = Vector3(-40, 34, -70)
	var mist := FX.emitter({"amount": 40, "life": 7.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "dir": Vector3(1, 0, 0),
		"vel_min": 0.2, "vel_max": 0.6, "gravity": Vector3.ZERO, "size": 9.0, "color": Color(0.6, 0.65, 0.9, 0.08), "box": Vector3(30, 0.4, 22)})
	root.add_child(mist)
	mist.position = Vector3(0, 0.6, 0)
	mist.emitting = true
	# Schlafende Untote
	for p in [Vector3(-22, 0, -4), Vector3(22, 0, 10), Vector3(6, 0, 19)]:
		var sk := CharacterRig.new()
		root.add_child(sk)
		sk.setup(["npc/skeleton", "npc/vampire", "npc/ghost"][sleepers.size() % 3], -1, 2.0 if sleepers.size() == 0 else 1.4)
		sk.position = p
		sk.rotation.y = _rng.randf() * TAU
		sk.play("sit" if sleepers.size() == 0 else "idle")
		sleepers.append(sk)
	# Geisterbrücke (Route 0): schwebende Grabplatten
	_toggle_platforms(0, "plat/block_moving", 0.75, Vector3(0, -0.85, 0))
	for part in toggle_visuals.get(0, []):
		Assets.tint(part, Color(0.6, 1.2, 0.9, 0.85), false, 0.6)
	# Krypta-Wächter (Route 1)
	var gs := _branch_first_space(1)
	if gs >= 0:
		gate_npc = CharacterRig.new()
		root.add_child(gate_npc)
		gate_npc.setup("npc/keeper", -1, 1.6)
		var gp: Vector3 = spaces[gs].pos
		var fwd: Vector3 = (spaces[spaces[gs].next[0]].pos - gp).normalized()
		gate_npc.position = gp + Vector3(-fwd.z, 0, fwd.x) * 1.8
		gate_npc.face_now(-Vector3(-fwd.z, 0, fwd.x))
		gate_npc.play("idle")
		var arch := WorldKit.place(root, "grave/crypt_small", gp - fwd * 2.4 + Vector3(-fwd.z, 0, fwd.x) * -2.4, 0.0, 1.6)
		arch.look_at(arch.position + fwd, Vector3.UP)


# --- Frostdorf ----------------------------------------------------------------------------------------------

func _build_frost() -> void:
	WorldKit.box(root, Vector3(76, 1, 56), Vector3(0, -0.5, 0), Color("#e8f0fa"), false)
	# Zugefrorener See in der Mitte (Eis-Route 0 führt drüber)
	var lake := WorldKit.water(root, Vector2(22, 9), 0.02, Color(0.55, 0.78, 0.95), Color(0.85, 0.95, 1.0))
	lake.position = Vector3(2, 0.03, -7)
	(lake.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("wave_height", 0.0)
	_scatter_free(["nat/pine_snow", "hk/tree_snow", "hk/tree_snow_b", "nat/pine_snow"], 30, Rect2(-34, -24, 68, 48), 0.0, Vector2(2.0, 3.0), 3.8)
	_scatter_free(["hk/snow_pile", "hk/rocks", "hol/snowball_pile", "hk/candy_cane", "hol/present_red", "hol/present_green", "hk/lantern"],
		30, Rect2(-28, -20, 56, 40), 0.0, Vector2(1.4, 2.0), 2.8)
	# Dorf: Hütten, Lebkuchenhaus, Weihnachtsbaum, Schlitten, Zug
	WorldKit.place(root, "hol/christmas_tree", Vector3(0, 0, 4), 0.0, 3.4)
	WorldKit.place(root, "hol/gingerbread_house", Vector3(-24, 0, -14), 40.0, 3.2)
	WorldKit.place(root, "hol/gingerbread_house", Vector3(24, 0, 16), -140.0, 3.2)
	WorldKit.place(root, "hk/sled", Vector3(-10, 0, 9), 20.0, 2.4)
	WorldKit.place(root, "hk/train", Vector3(12, 0, -22), 0.0, 2.6)
	WorldKit.place(root, "hk/nutcracker", Vector3(-6, 0, -1), 0.0, 2.6)
	WorldKit.place(root, "hk/nutcracker", Vector3(6, 0, -1), 0.0, 2.6)
	for p in [Vector3(-26, 0, 6), Vector3(26, 0, -6), Vector3(-14, 0, 19), Vector3(12, 0, 20)]:
		WorldKit.place(root, "hol/snowman", p, _rng.randf() * 360.0, 2.6)
	for p in [Vector3(-18, 0, -2), Vector3(16, 0, 4), Vector3(0, 0, 19), Vector3(-2, 0, -20)]:
		WorldKit.place(root, "hk/lantern", p, 0.0, 2.4)
		WorldKit.torch_light(root, p + Vector3.UP * 2.2, Color(1.0, 0.75, 0.45), 1.5, 8.0)
	var snow := FX.emitter({"amount": 120, "life": 8.0, "one_shot": false, "explosive": 0.0, "spread": 15.0, "dir": Vector3(0, -1, 0),
		"vel_min": 0.8, "vel_max": 1.6, "gravity": Vector3(0.4, -0.5, 0), "size": 0.25, "color": Color(1, 1, 1, 0.9), "box": Vector3(36, 1, 26)})
	root.add_child(snow)
	snow.position = Vector3(0, 16, 0)
	snow.emitting = true
	for p in [Vector3(-12, 0, -3), Vector3(14, 0, -4), Vector3(-3, 0, 18)]:
		var r := CharacterRig.new()
		root.add_child(r)
		r.setup(["pet/deer", "pet/bunny", "pet/chick"][sleepers.size() % 3], -1, 1.0)
		r.position = p
		r.rotation.y = _rng.randf() * TAU
		r.play("idle")
		sleepers.append(r)
	# Eis-Route 0: Eisschollen unter den Feldern
	_toggle_platforms(0, "plat/block_snow", 0.75, Vector3(0, -0.85, 0))


# --- Orbit-Station -------------------------------------------------------------------------------------------

func _build_station() -> void:
	# Gemütliche Sternwarte auf einer schwebenden Wiesen-Insel im Abendhimmel
	var isle := WorldKit.cylinder(root, 30.0, 3.0, Vector3(0, -1.5, 0), Color("#7cc46a"), false)
	isle.name = "Isle"
	WorldKit.cylinder(root, 27.0, 6.0, Vector3(0, -6.0, 0), Color("#a88a6a"), false)
	for i in 30:
		var a := TAU * i / 30.0
		WorldKit.place(root, ["plat/flowers", "nat/bush", "plat/mushrooms", "nat/flower_purple"][i % 4], Vector3(cos(a), 0, sin(a)) * 28.0, randf() * 360.0, 1.8)
	# Sternwarte: Turm + Kuppel + Fernrohr
	var tower := WorldKit.cylinder(root, 2.6, 6.0, Vector3(0, 3.0, -1), Color("#f2ead8"), false)
	tower.name = "Observatory"
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 2.8
	dm.height = 2.8
	dm.is_hemisphere = true
	dm.material = WorldKit.mat(Color("#8fb0ff"), 0.5, 0.15)
	dome.mesh = dm
	dome.position = Vector3(0, 6.0, -1)
	root.add_child(dome)
	var scope := WorldKit.cylinder(root, 0.45, 4.0, Vector3(0, 7.6, 0.2), Color("#c9a86a"), false)
	scope.rotation.x = -0.7
	for p in [Vector3(-3, 0, 2), Vector3(3, 0, 2)]:
		WorldKit.torch_light(root, p + Vector3.UP * 2.2, Color(1.0, 0.8, 0.5), 1.4, 7.0)
		WorldKit.place(root, "town/lantern", p, 0.0, 2.0)
	_toy_rocket(root, Vector3(-22, 0, -14), 2.4)
	_patches([Color("#6fb85e"), Color("#8acb6c"), Color("#a6d884"), Color("#f2e6a0")], 22, Rect2(-24, -20, 48, 40))
	_ring(["nat/bush", "plat/tree", "nat/flower_purple", "plat/flowers"], 34, 24.5, 27.0, Vector2(1.8, 2.6))
	WorldKit.place(root, "town/windmill", Vector3(23, 0, 14), -140.0, 2.4)
	# Pastell-Planeten mit Ringen am Himmel
	var cols := [Color("#ffb3c7"), Color("#a8dcff"), Color("#ffe08a"), Color("#c9b5ff")]
	for k in 4:
		var pl := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = [9.0, 5.0, 7.0, 4.0][k]
		sm.height = sm.radius * 2.0
		sm.material = WorldKit.mat(cols[k], 0.9, 0.35)
		pl.mesh = sm
		pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pl)
		pl.position = [Vector3(-60, 30, -90), Vector3(55, 22, -70), Vector3(70, 40, 40), Vector3(-70, 18, 50)][k]
		if k % 2 == 0:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = sm.radius * 1.4
			tm.outer_radius = sm.radius * 1.9
			tm.material = WorldKit.mat(Color(1, 1, 1, 1).lerp(cols[k], 0.4), 0.9, 0.3)
			ring.mesh = tm
			ring.scale = Vector3(1, 0.05, 1)
			ring.rotation_degrees = Vector3(20, 0, 15)
			pl.add_child(ring)
	var stars := FX.emitter({"amount": 180, "life": 40.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.0, "vel_max": 0.03,
		"gravity": Vector3.ZERO, "size": 0.7, "tex": FX.tex_star, "additive": true, "color": Color(1, 0.95, 0.8, 0.9), "box": Vector3(140, 30, 30)})
	root.add_child(stars)
	stars.position = Vector3(0, 40, -80)
	stars.preprocess = 40.0
	stars.emitting = true
	for p in [Vector3(-14, 0, 4), Vector3(14, 0, -3), Vector3(-4, 0, 18)]:
		var r := CharacterRig.new()
		root.add_child(r)
		r.setup(["pet/bunny", "pet/cat", "pet/deer"][sleepers.size() % 3], -1, 1.1)
		r.position = p
		r.rotation.y = _rng.randf() * TAU
		r.play("idle")
		sleepers.append(r)
	# Sternenbrücken (Routen): Wolkenplatten
	_toggle_platforms(0, "plat/block_snow", 0.75, Vector3(0, -0.85, 0))
	_toggle_platforms(1, "plat/block_snow", 0.75, Vector3(0, -0.85, 0))


# --- Der Wolkenturm ------------------------------------------------------------------------------------------

var tower_h := 40.0
var _cloud_rings: Array[Node3D] = []


func _build_tower() -> void:
	tower_h = float(def.helix.h)
	var R := float(def.helix.r)
	# Wolkeninsel am Fuß des Turms
	var base := WorldKit.cylinder(root, R + 6.0, 2.0, Vector3(0, -1.2, 0), Color("#86d06a"), false)
	base.name = "BaseIsle"
	WorldKit.cylinder(root, R + 6.4, 1.2, Vector3(0, -2.6, 0), Color("#f4f0ff"), false)
	for i in 18:
		var a := TAU * i / 18.0
		WorldKit.place(root, ["plat/flowers", "nat/bush", "plat/mushrooms", "plat/tree"][i % 4], Vector3(cos(a) * (R + 4.5), 0, sin(a) * (R + 4.5)), _rng.randf() * 360.0, 1.6)
	# Der Turm: gestapelte Trommeln (Pastell), Fenster, Balkone, Blumenkästen – nach oben schmaler
	var floors := 9
	for f in floors:
		var y := f * tower_h / floors
		var r := lerpf(R - 2.6, R - 4.4, float(f) / floors)
		var col: Color = [Color("#fff1d8"), Color("#ffe0ec"), Color("#e6f0ff"), Color("#eaffe6")][f % 4]
		WorldKit.cylinder(root, r, tower_h / floors, Vector3(0, y + tower_h / floors * 0.5, 0), col, false)
		WorldKit.cylinder(root, r + 0.35, 0.3, Vector3(0, y + 0.15, 0), Color("#c9a0dc"), false)
		for w in 6:
			var a2 := TAU * w / 6.0 + f * 0.5
			var win := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.9, 1.3, 0.1)
			bm.material = WorldKit.mat(Color("#ffe8a8"), 0.3, 0.6)
			win.mesh = bm
			win.position = Vector3(sin(a2) * (r + 0.02), y + tower_h / floors * 0.55, cos(a2) * (r + 0.02))
			win.rotation.y = a2
			root.add_child(win)
		if f % 2 == 1:
			# Blumenkasten-Balkon
			var a3 := f * 1.3
			WorldKit.box(root, Vector3(2.2, 0.3, 1.0), Vector3(sin(a3) * (r + 0.6), y + 1.0, cos(a3) * (r + 0.6)), Color("#c98d5a"), false).rotation.y = a3
			WorldKit.place(root, "plat/flowers", Vector3(sin(a3) * (r + 0.7), y + 1.2, cos(a3) * (r + 0.7)), 0.0, 1.2)
	# Dachspitze mit Leuchtfeuer
	var roof := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = R - 3.6
	cm.height = 6.0
	cm.material = WorldKit.mat(Color("#b07aff"), 0.5)
	roof.mesh = cm
	roof.position = Vector3(0, tower_h + 3.0, 0)
	root.add_child(roof)
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.9, 0.6)
	beacon.light_energy = 2.0
	beacon.omni_range = 18.0
	beacon.position = Vector3(0, tower_h + 6.5, 0)
	root.add_child(beacon)
	var bstar := Assets.spawn("plat/star", root, Vector3(0, tower_h + 7.0, 0), 0.0, 3.0)
	Assets.tint(bstar, Color(1.1, 1.0, 0.6), false, 1.0)
	var bt := bstar.create_tween().set_loops()
	bt.tween_property(bstar, "rotation:y", TAU, 4.0).as_relative()
	# Ranken, die sich um den Turm winden (dicke grüne Perlen-Kette mit Blättern)
	for v in 2:
		for k in 90:
			var t := float(k) / 90.0
			var a4 := TAU * 3.2 * t + v * PI
			var rr := lerpf(R - 2.4, R - 4.2, t)
			var p := Vector3(sin(a4) * rr, t * tower_h, cos(a4) * rr)
			var bead := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.32
			sm.height = 0.64
			sm.radial_segments = 8
			sm.rings = 4
			sm.material = WorldKit.mat(Color("#5fae4a"), 0.8)
			bead.mesh = sm
			bead.position = p
			root.add_child(bead)
			if k % 6 == 0:
				WorldKit.place(root, "nat/flower_yellow" if k % 12 == 0 else "plat/flowers", p + Vector3(sin(a4), 0, cos(a4)) * 0.3, 0.0, 0.8)
	# Regenbogen-Rutsche vom Gipfel zurück zum Fuß (außen, zwei Windungen)
	var cols := [Color("#ff6b6b"), Color("#ffd23f"), Color("#7ed957"), Color("#3fa7ff"), Color("#c06bff")]
	for k in 120:
		var t2 := float(k) / 120.0
		var a5 := -TAU * 2.0 * t2 + PI
		var p2 := Vector3(sin(a5) * (R + 4.2), tower_h * (1.0 - t2) - 0.6, cos(a5) * (R + 4.2))
		for c in cols.size():
			var seg := MeshInstance3D.new()
			var bm2 := BoxMesh.new()
			bm2.size = Vector3(0.32, 0.12, 1.3)
			bm2.material = WorldKit.mat(cols[c], 0.6, 0.15)
			seg.mesh = bm2
			seg.position = p2 + Vector3(sin(a5), 0, cos(a5)) * (c - 2) * 0.32
			seg.rotation.y = a5 + PI * 0.5
			root.add_child(seg)
	# Wolkenringe in mehreren Höhen – drehen unterschiedlich schnell (Parallaxe beim Aufstieg)
	for h in [8.0, 18.0, 28.0, 38.0]:
		var ring := Node3D.new()
		root.add_child(ring)
		ring.position.y = h - 2.5
		for k in 10:
			var a6 := TAU * k / 10.0 + _rng.randf() * 0.3
			var dist := _rng.randf_range(R + 9.0, R + 16.0)
			var puff := MeshInstance3D.new()
			var ps := SphereMesh.new()
			ps.radius = _rng.randf_range(1.8, 3.4)
			ps.height = ps.radius * 1.2
			ps.material = WorldKit.mat(Color(1, 1, 1), 1.0, 0.2)
			puff.mesh = ps
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			puff.position = Vector3(cos(a6) * dist, _rng.randf_range(-1.0, 1.0), sin(a6) * dist)
			ring.add_child(puff)
		var rt := ring.create_tween().set_loops()
		rt.tween_property(ring, "rotation:y", TAU * (1.0 if int(h) % 20 == 8 else -1.0), 80.0 + h * 2.0).as_relative()
		_cloud_rings.append(ring)
	# Schwebende Inselchen mit Bewohnern ringsum
	for k in 6:
		var a7 := TAU * k / 6.0 + 0.4
		var isle := Assets.spawn("plat/block_grass_overhang", root, Vector3(cos(a7) * (R + 20.0), 6.0 + k * 6.0, sin(a7) * (R + 20.0)), _rng.randf() * 360.0, 2.0)
		var tw := isle.create_tween().set_loops()
		tw.tween_property(isle, "position:y", isle.position.y + 1.2, 3.0 + k * 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(isle, "position:y", isle.position.y, 3.0 + k * 0.3).set_trans(Tween.TRANS_SINE)
		var r2 := CharacterRig.new()
		isle.add_child(r2)
		r2.setup(["pet/chick", "pet/bunny", "pet/bee", "pet/deer", "pet/cat", "pet/cow"][k], -1, 0.5)
		r2.position = Vector3(0, 0.55, 0)
		r2.play("idle")
		sleepers.append(r2)
	# Wind-Partikel, die mit der Höhe zunehmen
	var wind := FX.emitter({"amount": 80, "life": 3.0, "one_shot": false, "explosive": 0.0, "spread": 15.0, "dir": Vector3(1, 0, 0),
		"vel_min": 4.0, "vel_max": 7.0, "gravity": Vector3.ZERO, "size": 0.12, "color": Color(1, 1, 1, 0.6), "box": Vector3(30, 14, 30)})
	root.add_child(wind)
	wind.position = Vector3(0, tower_h * 0.8, 0)
	wind.emitting = true
	_toggle_platforms(1, "plat/block_snow", 0.9, Vector3(0, -0.7, 0))


# --- Glühwürmchen-Zauberwald ----------------------------------------------------------------------------------

var _night_lights: Array[OmniLight3D] = []
var _night_glows: Array[Node3D] = []


func _build_glowforest() -> void:
	WorldKit.box(root, Vector3(96, 1, 76), Vector3(0, -0.5, 0), Color("#4f9a46"), false)
	_patches([Color("#3f8a3a"), Color("#5aa84c"), Color("#6bb256"), Color("#3a7d40"), Color("#77b85a")], 34, Rect2(-36, -27, 72, 54))
	_ring(["nat/tree_fat", "nat/tree_oak", "nat/tree_pine", "nat/tree_default", "castle/tree", "plat/tree"], 52, 31.0, 40.0, Vector2(4.2, 6.4))
	_ring(["nat/bush", "nat/tree_pine", "plat/tree_pine"], 30, 28.0, 31.0, Vector2(2.4, 3.4))
	_scatter_free(["nat/tree_oak", "nat/tree_fat", "nat/tree_default", "nat/tree_pine", "plat/tree", "castle/tree"], 34, Rect2(-28, -21, 56, 42), 0.0, Vector2(2.4, 3.6), 3.7)
	_scatter_free(["nat/bush", "nat/flower_purple", "nat/flower_yellow", "nat/grass", "nat/mushroom", "nat/stump", "nat/log", "nat/rock_small", "plat/flowers"], 80, Rect2(-28, -21, 56, 42), 0.0, Vector2(1.4, 2.2), 2.5)
	_pond(Vector2(11, 8), [Vector3(-19, 0, 12), Vector3(19, 0, -12), Vector3(-20, 0, -10), Vector3(18, 0, 13), Vector3(0, 0, 15)], Color(0.08, 0.32, 0.42), Color(0.35, 0.75, 0.7), "nat/lily")
	# Zauberbaum in der Mitte mit Laternen
	WorldKit.place(root, "nat/tree_fat", Vector3(0, 0, -1), 0.0, 7.5)
	for k in 6:
		var a := TAU * k / 6.0
		var lp := Vector3(cos(a) * 3.4, 0, sin(a) * 3.4 - 1.0)
		WorldKit.place(root, "town/lantern", lp, rad_to_deg(-a), 1.6)
		var ll := OmniLight3D.new()
		ll.light_color = Color(1.0, 0.8, 0.5)
		ll.light_energy = 0.6
		ll.omni_range = 4.0
		ll.position = lp + Vector3.UP * 1.8
		root.add_child(ll)
		_night_lights.append(ll)
	# Leuchtpilze: tagsüber bunt, nachts erhellen sie den Weg
	var k2 := 0
	for sp in spaces:
		if k2 % 2 == 0:
			var side := _outward(sp) * (2.4 if k2 % 4 == 0 else -2.4)
			var col: Color = [Color("#d9a8ff"), Color("#8fe8ff"), Color("#ffb3e6"), Color("#b6f29a")][(k2 / 2) % 4]
			var m := Assets.spawn("plat/mushrooms", root, (sp.pos as Vector3) + side, _rng.randf() * 360.0, 1.6)
			Assets.tint(m, col.lightened(0.2))
			m.set_meta("glow", col)
			_night_glows.append(m)
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 0.0
			l.omni_range = 5.5
			l.position = (sp.pos as Vector3) + side + Vector3.UP * 1.3
			root.add_child(l)
			_night_lights.append(l)
		k2 += 1
	var fireflies := FX.emitter({"amount": 160, "life": 5.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.1, "vel_max": 0.5,
		"gravity": Vector3(0, 0.05, 0), "size": 0.22, "additive": true, "color": Color(1.0, 0.95, 0.55, 0.95), "box": Vector3(30, 3, 22)})
	root.add_child(fireflies)
	fireflies.position = Vector3(0, 2.5, 0)
	fireflies.emitting = true
	fireflies.name = "Fireflies"
	for p in [Vector3(-22, 0, -4), Vector3(22, 0, 10), Vector3(6, 0, 19), Vector3(-8, 0, -18)]:
		var r := CharacterRig.new()
		root.add_child(r)
		r.setup(["pet/deer", "pet/bunny", "pet/cat", "pet/bee"][sleepers.size() % 4], -1, 1.1)
		r.position = p + (Vector3.UP * 1.6 if sleepers.size() % 4 == 3 else Vector3.ZERO)
		r.rotation.y = _rng.randf() * TAU
		r.play("idle")
		sleepers.append(r)
	_toggle_platforms(0, "plat/mushrooms", 1.6, Vector3(0, -0.9, 0))


## Bodenflecken (Moos, Blumenteppich, Sand …) für mehr Tiefe: flache Scheiben knapp über dem Boden.
func _patches(cols: Array, count: int, area: Rect2, rad := Vector2(2.5, 6.5)) -> void:
	for i in count:
		var d := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := _rng.randf_range(rad.x, rad.y)
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.04
		cm.radial_segments = 24
		cm.material = WorldKit.mat(cols[i % cols.size()], 1.0)
		d.mesh = cm
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(d)
		d.position = Vector3(_rng.randf_range(area.position.x, area.end.x), 0.004 + i * 0.0006, _rng.randf_range(area.position.y, area.end.y))
		d.scale = Vector3(1, 1, _rng.randf_range(0.55, 1.0))
		d.rotation.y = _rng.randf() * TAU


## Kulissenring um das Brett, damit der Horizont nie leer wirkt (vorne kleiner für freie Kamerasicht).
func _ring(keys: Array, count: int, r_min: float, r_max: float, scl: Vector2, y := 0.0) -> void:
	for i in count:
		var a := TAU * i / count + _rng.randf_range(-0.07, 0.07)
		var r := _rng.randf_range(r_min, r_max)
		var p := Vector3(cos(a) * r, y, sin(a) * r * 0.78)
		var front := clampf(sin(a), 0.0, 1.0)
		WorldKit.place(root, keys[_rng.randi() % keys.size()], p, _rng.randf() * 360.0, _rng.randf_range(scl.x, scl.y) * (1.0 - front * 0.45))


## Kleiner Teich an der ersten freien Kandidaten-Stelle, mit Seerosen.
func _pond(size: Vector2, cands: Array, deep: Color, shallow: Color, deco := "") -> Vector3:
	for c in cands:
		var p: Vector3 = c
		if _free_spot(p, maxf(size.x, size.y) * 0.5 + 2.6):
			var rim := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = size.x * 0.5 + 0.8
			cm.bottom_radius = size.x * 0.5 + 0.8
			cm.height = 0.1
			cm.material = WorldKit.mat(Color("#b9a27a"), 1.0)
			rim.mesh = cm
			rim.scale = Vector3(1, 1, (size.y + 1.6) / (size.x + 1.6))
			rim.position = p + Vector3(0, 0.02, 0)
			root.add_child(rim)
			var w := WorldKit.water(root, size, 0.09, deep, shallow)
			w.position.x = p.x
			w.position.z = p.z
			for k in 6:
				WorldKit.place(root, "nat/rock_small", p + Vector3(cos(TAU * k / 6.0) * size.x * 0.55, 0, sin(TAU * k / 6.0) * size.y * 0.55), _rng.randf() * 360.0, 1.3)
			if deco != "":
				for k in 4:
					WorldKit.place(root, deco, p + Vector3(_rng.randf_range(-size.x, size.x) * 0.3, 0.12, _rng.randf_range(-size.y, size.y) * 0.3), _rng.randf() * 360.0, 1.4)
			return p
	return Vector3.INF


## Spielzeugrakete (Sternwarte): weißer Rumpf, rote Spitze, Bullauge und Flossen.
func _toy_rocket(parent: Node3D, pos: Vector3, s := 1.0) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = pos
	WorldKit.cylinder(n, 0.55 * s, 2.0 * s, Vector3(0, 1.4 * s, 0), Color("#fbf6ec"), false)
	var nose := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.55 * s
	cm.height = 1.0 * s
	cm.material = WorldKit.mat(Color("#ff6b6b"), 0.6)
	nose.mesh = cm
	nose.position = Vector3(0, 2.9 * s, 0)
	n.add_child(nose)
	var win := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.26 * s
	sm.height = 0.52 * s
	sm.material = WorldKit.mat(Color("#8fd0ff"), 0.2, 0.3)
	win.mesh = sm
	win.position = Vector3(0, 1.8 * s, 0.48 * s)
	n.add_child(win)
	for k in 3:
		var fin := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.8, 0.6) * s
		bm.material = WorldKit.mat(Color("#ff9f43"), 0.6)
		fin.mesh = bm
		var a := TAU * k / 3.0
		fin.position = Vector3(cos(a) * 0.6, 0.55, sin(a) * 0.6) * s
		fin.rotation.y = -a
		n.add_child(fin)
	return n


## Pusteblume (Wuschel-Wiesen): Stiel + flauschiger Samenkopf.
func _dandelion(parent: Node3D, pos: Vector3, s := 1.0) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = pos
	var stem := WorldKit.cylinder(n, 0.07 * s, 2.2 * s, Vector3(0, 1.1 * s, 0), Color("#6cbf4a"), false)
	stem.rotation.z = 0.06
	var puff := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.75 * s
	sm.height = 1.5 * s
	sm.material = WorldKit.mat(Color("#fffdf6"), 1.0, 0.12)
	puff.mesh = sm
	puff.position = Vector3(0.1 * s, 2.35 * s, 0)
	n.add_child(puff)
	var core := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.22 * s
	cs.height = 0.44 * s
	cs.material = WorldKit.mat(Color("#e8c25a"), 0.9)
	core.mesh = cs
	core.position = puff.position
	n.add_child(core)
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "rotation:z", 0.05, 1.4 + _rng.randf() * 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "rotation:z", -0.05, 1.4 + _rng.randf() * 0.6).set_trans(Tween.TRANS_SINE)
	return n


## Tag/Nacht (Zauberwald): nachts dunkler Himmel, Leuchtpilze und Glühwürmchen strahlen.
func apply_time_of_day(night: bool, board: Node, animate := true) -> void:
	var env: WorldEnvironment = null
	var sun: DirectionalLight3D = null
	for c in board.get_children():
		if c is WorldEnvironment:
			env = c
		for cc in c.get_children():
			if cc is DirectionalLight3D:
				sun = cc
		if c is DirectionalLight3D:
			sun = c
	var dur := 1.6 if animate else 0.0
	if env and env.environment:
		var e := env.environment
		var tw := board.create_tween().set_parallel(true)
		var amb_day := float(env.get_meta("ambient_day", 0.45))
		tw.tween_property(e, "ambient_light_energy", amb_day * 0.8 if night else amb_day, maxf(dur, 0.01))
		tw.tween_property(e, "ambient_light_color", Color("#5a6aa8") if night else Color("#9fb8dc"), maxf(dur, 0.01))
		tw.tween_property(e, "background_energy_multiplier", 0.25 if night else 1.0, maxf(dur, 0.01))
		if e.fog_enabled:
			tw.tween_property(e, "fog_light_color", Color("#283060") if night else Color("#a9cfee"), maxf(dur, 0.01))
	if sun:
		board.create_tween().tween_property(sun, "light_energy", 0.25 if night else 1.0, maxf(dur, 0.01))
	for l in _night_lights:
		board.create_tween().tween_property(l, "light_energy", 1.8 if night else 0.0, maxf(dur, 0.01))
	for m in _night_glows:
		var gc: Color = m.get_meta("glow", Color(1, 0.9, 1))
		for mi in Assets.find_meshes(m):
			for si in mi.get_surface_override_material_count():
				var mat := mi.get_surface_override_material(si) as StandardMaterial3D
				if mat == null:
					continue
				mat.emission_enabled = true
				mat.emission = gc
				board.create_tween().tween_property(mat, "emission_energy_multiplier", 1.6 if night else 0.0, maxf(dur, 0.01))
	var ff := root.get_node_or_null("Fireflies") as GPUParticles3D
	if ff:
		ff.amount_ratio = 1.0 if night else 0.35


# --- Wuschel-Wiesen -----------------------------------------------------------------------------------------------

func _build_meadow() -> void:
	WorldKit.box(root, Vector3(96, 1, 76), Vector3(0, -0.5, 0), Color("#86d06a"), false)
	_patches([Color("#9bdc76"), Color("#7cc860"), Color("#a6e283"), Color("#f2e6a0"), Color("#93d470")], 34, Rect2(-36, -27, 72, 54))
	for i in 14:
		var hill := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = _rng.randf_range(7, 12)
		sm.height = sm.radius * 0.9
		sm.material = WorldKit.mat(Color("#7cc860").lerp(Color("#a6dc7a"), _rng.randf()), 1.0)
		hill.mesh = sm
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(hill)
		var a := TAU * i / 14.0
		hill.position = Vector3(cos(a) * 42.0, -2.2, sin(a) * 33.0)
	_ring(["plat/tree", "nat/tree_oak", "castle/tree", "nat/tree_default"], 34, 31.0, 38.0, Vector2(3.2, 4.6))
	_scatter_free(["plat/flowers", "nat/flower_yellow", "nat/flower_red", "nat/flower_purple", "plat/mushrooms", "nat/bush", "nat/grass", "nat/grass"], 90, Rect2(-30, -22, 60, 44), 0.0, Vector2(1.4, 2.2), 2.4)
	_scatter_free(["plat/tree", "nat/tree_oak", "castle/tree"], 18, Rect2(-30, -22, 60, 44), 0.0, Vector2(2.2, 3.0), 4.0)
	for i in 12:
		var dp := Vector3(_rng.randf_range(-28, 28), 0, _rng.randf_range(-21, 21))
		if _free_spot(dp, 3.0, true):
			_dandelion(root, dp, _rng.randf_range(1.0, 1.6))
	WorldKit.place(root, "town/windmill", Vector3(-25, 0, -15), 30.0, 2.8)
	WorldKit.cottage(root, Vector3(25, 0, -14), -140.0, 1.6, Color("#fff1d8"), Color("#7fb8ff"))
	WorldKit.place(root, "town/fountain", Vector3(0, 0, -1), 0.0, 2.2)
	for k in 8:
		WorldKit.place(root, "nat/fence", Vector3(-30 + k * 2.2, 0, -21), 0.0, 1.6)
	var pond := _pond(Vector2(10, 7), [Vector3(19, 0, 12), Vector3(-19, 0, 12), Vector3(0, 0, 16), Vector3(-20, 0, -8)], Color(0.1, 0.4, 0.6), Color(0.45, 0.85, 0.9), "nat/lily")
	if pond != Vector3.INF:
		for k in 2:
			var duck := CharacterRig.new()
			root.add_child(duck)
			duck.setup("npc/duck", -1, 0.9)
			duck.position = pond + Vector3(-1.5 + k * 3.0, 0.05, 0)
			duck.play("idle")
			var tw := duck.create_tween().set_loops()
			tw.tween_property(duck, "position:x", duck.position.x + 1.6, 3.0 + k).set_trans(Tween.TRANS_SINE)
			tw.tween_property(duck, "position:x", duck.position.x - 0.4, 3.0 + k).set_trans(Tween.TRANS_SINE)
	# Wuschelige Schäfchen (weiche Kugeln mit Köpfchen und Beinchen)
	for i in 12:
		var p := Vector3(_rng.randf_range(-28, 28), 0, _rng.randf_range(-21, 21))
		if not _free_spot(p, 3.4):
			continue
		var sheep := Node3D.new()
		root.add_child(sheep)
		sheep.position = p
		sheep.rotation.y = _rng.randf() * TAU
		var body := Node3D.new()
		sheep.add_child(body)
		body.position.y = 0.95
		for q in [Vector3(0, 0, 0), Vector3(0.45, 0.15, 0.2), Vector3(-0.45, 0.12, -0.1), Vector3(0, 0.3, -0.35), Vector3(0.1, 0.25, 0.45)]:
			var puff := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = 0.62
			bm.height = 1.15
			bm.material = WorldKit.mat(Color("#fbf8f0"), 1.0, 0.04)
			puff.mesh = bm
			puff.position = q
			body.add_child(puff)
		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.36
		hm.height = 0.66
		hm.material = WorldKit.mat(Color("#4a3a3a"), 0.8)
		head.mesh = hm
		head.position = Vector3(0, 0.2, -0.95)
		body.add_child(head)
		for lx in [-0.3, 0.3]:
			for lz in [-0.35, 0.35]:
				var leg := WorldKit.cylinder(sheep, 0.09, 0.6, Vector3(lx, 0.3, lz), Color("#4a3a3a"), false)
				leg.name = "Leg"
		var tw2 := sheep.create_tween().set_loops()
		tw2.tween_property(body, "position:y", 1.08, 0.7 + i * 0.04).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(body, "position:y", 0.95, 0.7 + i * 0.04).set_trans(Tween.TRANS_SINE)
	for p in [Vector3(-14, 0, 3), Vector3(15, 0, -2), Vector3(4, 0, 19)]:
		var r := CharacterRig.new()
		root.add_child(r)
		r.setup(["pet/bunny", "pet/chick", "pet/cow"][sleepers.size() % 3], -1, 1.1)
		r.position = p
		r.rotation.y = _rng.randf() * TAU
		r.play("idle")
		sleepers.append(r)
	_toggle_platforms(0, "nat/flower_yellow", 3.0, Vector3(0, -0.2, 0))


# --- Zuckerback-Torte ------------------------------------------------------------------------------------------------

func _build_cake() -> void:
	# Drei Tortenstockwerke, Sahnetupfen, Kerzen und Kirschen
	var layers := [[30.0, Color("#f7d6e0")], [26.0, Color("#fff3d6")]]
	WorldKit.cylinder(root, 31.0, 6.0, Vector3(0, -3.2, 0), Color("#c98d5a"), false)
	for k in 2:
		WorldKit.cylinder(root, float(layers[k][0]), 0.4, Vector3(0, -0.2 - k * 0.01, 0), layers[k][1], false)
	for i in 36:
		var a := TAU * i / 36.0
		var dollop := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 1.3
		sm.material = WorldKit.mat(Color("#fffaf2"), 0.6)
		dollop.mesh = sm
		root.add_child(dollop)
		dollop.position = Vector3(cos(a) * 29.0, 0.4, sin(a) * 29.0)
		if i % 3 == 0:
			var cherry := MeshInstance3D.new()
			var cs := SphereMesh.new()
			cs.radius = 0.5
			cs.height = 1.0
			cs.material = WorldKit.mat(Color("#e8304a"), 0.25, 0.1)
			cherry.mesh = cs
			cherry.position = Vector3(0, 0.9, 0)
			dollop.add_child(cherry)
	for i in 10:
		var a2 := TAU * i / 10.0 + 0.15
		var p := Vector3(cos(a2), 0, sin(a2)) * 24.5
		var candle := WorldKit.cylinder(root, 0.35, 3.0, p + Vector3.UP * 1.5, [Color("#ffb3c7"), Color("#a8dcff"), Color("#ffe08a")][i % 3], false)
		candle.name = "Candle"
		WorldKit.torch_light(root, p + Vector3.UP * 3.3, Color(1.0, 0.75, 0.45), 1.4, 6.0)
	_scatter_free(["hol/cookie", "hol/present_red", "hk/candy_cane", "hol/present_blue", "plat/mushrooms", "hol/gingerbread_house"], 26, Rect2(-22, -18, 44, 36), 0.0, Vector2(1.6, 2.4), 3.0)
	WorldKit.place(root, "hol/gingerbread_house", Vector3(0, 0, -1), 0.0, 3.0)
	for p in [Vector3(-14, 0, 3), Vector3(14, 0, -2), Vector3(4, 0, 19)]:
		var r := CharacterRig.new()
		root.add_child(r)
		r.setup(["pet/bunny", "pet/chick", "pet/cat"][sleepers.size() % 3], -1, 1.1)
		r.position = p
		r.rotation.y = _rng.randf() * TAU
		r.play("idle")
		sleepers.append(r)
	_toggle_platforms(0, "hol/cookie", 2.6, Vector3(0, -0.3, 0))
	_toggle_platforms(1, "hol/cookie", 2.6, Vector3(0, -0.3, 0))


# --- Wechselnde Routen ---------------------------------------------------------------------------------------

func _branch_first_space(bi: int) -> int:
	for sp in spaces:
		if sp.branch == bi:
			return sp.id
	return -1


func _toggle_platforms(bi: int, key: String, scl: float, offset: Vector3, under_tile := true) -> void:
	var parts: Array[Node3D] = []
	for sp in spaces:
		if sp.branch != bi:
			continue
		var holder: Node3D = Node3D.new()
		root.add_child(holder)
		holder.position = sp.pos + offset
		var model := Assets.spawn(key, holder, Vector3.ZERO, 0.0, scl)
		if not under_tile:
			model.scale = Vector3(scl, scl, scl * 1.6)
		parts.append(holder)
	toggle_visuals[bi] = parts


## Wendet den Offen/Zu-Zustand einer Route visuell an (animiert).
func set_route_open(bi: int, open: bool, animate := true) -> void:
	var kind: String = def.branches[bi].get("kind", "")
	var parts: Array = toggle_visuals.get(bi, [])
	var ids: Array[int] = []
	for sp in spaces:
		if sp.branch == bi:
			ids.append(sp.id)
	var dy := 0.0
	match kind:
		"lava_bridge":
			dy = 0.0 if open else -2.4
		"tide":
			dy = 0.0 if open else -1.4
		"drawbridge":
			dy = 0.0 if open else -0.3
		"fog_bridge", "ice_bridge", "mushroom_path":
			dy = 0.0 if open else -2.4
		"sunflower_path", "cherry_lift", "cloud_lift":
			dy = 0.0 if open else -1.8
		"airlock":
			dy = 0.0 if open else -1.6
	for k in ids.size():
		var node: Node3D = space_nodes[ids[k]]
		var target := (spaces[ids[k]].pos as Vector3) + Vector3.UP * dy
		var tilt := Vector3(deg_to_rad(0 if open else 25), 0, 0) if kind == "drawbridge" else Vector3.ZERO
		if animate:
			var tw := node.create_tween().set_parallel(true)
			tw.tween_property(node, "position", target, 0.9).set_trans(Tween.TRANS_BACK).set_delay(k * 0.08)
			tw.tween_property(node, "rotation", tilt, 0.9).set_delay(k * 0.08)
		else:
			node.position = target
			node.rotation = tilt
		if k < parts.size():
			var part: Node3D = parts[k]
			var sink: float = {"lava_bridge": 0.85, "fog_bridge": 0.85, "ice_bridge": 0.85, "mushroom_path": 0.9, "tide": 0.2, "airlock": 0.25, "sunflower_path": 0.2, "cherry_lift": 0.3, "cloud_lift": 0.4}.get(kind, 0.0)
			var ptarget := (spaces[ids[k]].pos as Vector3) + Vector3.UP * (dy - sink)
			if animate:
				var tw2 := part.create_tween().set_parallel(true)
				tw2.tween_property(part, "position", ptarget, 0.9).set_trans(Tween.TRANS_BACK).set_delay(k * 0.08)
				tw2.tween_property(part, "rotation", tilt * 2.0, 0.9).set_delay(k * 0.08)
			else:
				part.position = ptarget
				part.rotation = tilt * 2.0
