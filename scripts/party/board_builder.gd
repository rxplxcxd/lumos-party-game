class_name BoardBuilder
extends RefCounted
## Baut die 3D-Welt eines Spielbretts: Felder, Pfade, thematische Kulisse, bewegliche Routen, NPCs.
## Assets werden quer durch die Themen zweckentfremdet (Piratentruhen = Glücksrad-Kisten,
## Dungeon-Fackeln = Fallen-Felder, Kanonen = Wolkenkanonen, Krabbe = Händler …).

const TILE_KEYS := {"B": "bg/tile_blue", "R": "bg/tile_red", "L": "bg/tile_yellow", "P": "bg/tile_green", "C": "bg/tile_purple",
	"T": "bg/tile_purple", "K": "bg/tile_green", "N": "bg/tile_yellow", "S": "bg/tile_green"}
const SYMBOLS := {"B": "+", "R": "-", "L": "?", "P": "!", "C": "?!", "T": "!", "K": "!", "N": "$", "S": "GO"}
const SYMBOL_COLORS := {"B": Color("#dff2ff"), "R": Color("#ffe0e0"), "L": Color("#7a4a00"), "P": Color("#eaffea"),
	"C": Color("#f2e0ff"), "T": Color("#ffd0a0"), "K": Color("#eaffea"), "N": Color("#7a4a00"), "S": Color("#ffffff")}
const TILE_SCALE := 2.3

var root: Node3D
var def: Dictionary
var spaces: Array
var board_id := ""
var space_nodes: Array[Node3D] = []
var toggle_visuals := {}      # branch index -> Array[Node3D] (bewegliche Teile)
var gate_npc: CharacterRig
var merchant: CharacterRig
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
	match id:
		"pirates":
			_build_pirates()
		"sky":
			_build_sky()
		_:
			_build_dungeon()
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
		space_nodes.append(holder)


func _space_prop(holder: Node3D, t: String, sp: Dictionary) -> void:
	var side := _outward(sp) * 1.9
	match t:
		"L":
			var key := "dun/chest" if board_id == "dungeon" else ("plat/chest" if board_id == "sky" else "pirate/chest")
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
			var c := Assets.spawn("pirate/cannon", holder, side, 0.0, 1.3)
			c.look_at(holder.global_position + Vector3(0, c.global_position.y - holder.global_position.y, 0), Vector3.UP)
			c.rotate_object_local(Vector3.RIGHT, deg_to_rad(-35))
			traps.append(c)
		"N":
			var stall := Assets.spawn("town/stall", holder, side * 1.2, 0.0, 2.2)
			stall.look_at(holder.global_position + Vector3(0, stall.global_position.y - holder.global_position.y, 0), Vector3.UP)
			stall.rotate_object_local(Vector3.UP, PI)
			if merchant == null:
				merchant = CharacterRig.new()
				holder.add_child(merchant)
				merchant.setup("pet/crab", -1, 0.9)
				merchant.position = side * 0.75
				merchant.face_now(-side)
				merchant.play("idle")
		"S":
			Assets.spawn("bg/flag_red", holder, side, 0.0, 2.5)


func _outward(sp: Dictionary) -> Vector3:
	var p: Vector3 = sp.pos
	var flat := Vector3(p.x, 0, p.z)
	if flat.length() < 0.5:
		return Vector3.BACK
	return flat.normalized()


func _build_paths() -> void:
	var xfs: Array = []
	for sp in spaces:
		for nid in sp.next:
			var a: Vector3 = sp.pos
			var b: Vector3 = spaces[nid].pos
			var d := a.distance_to(b)
			var steps := int(d / 0.8)
			for k in range(1, steps):
				var t := float(k) / steps
				if t * d < 1.3 or (1.0 - t) * d < 1.3:
					continue
				var p := a.lerp(b, t) + Vector3.UP * 0.06
				xfs.append(Transform3D(Basis().scaled(Vector3(0.28, 0.12, 0.28)), p))
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
			var ptarget := (spaces[ids[k]].pos as Vector3) + Vector3.UP * (dy - (0.85 if kind == "lava_bridge" else (0.2 if kind == "tide" else 0.0)))
			if animate:
				var tw2 := part.create_tween().set_parallel(true)
				tw2.tween_property(part, "position", ptarget, 0.9).set_trans(Tween.TRANS_BACK).set_delay(k * 0.08)
				tw2.tween_property(part, "rotation", tilt * 2.0, 0.9).set_delay(k * 0.08)
			else:
				part.position = ptarget
				part.rotation = tilt * 2.0
