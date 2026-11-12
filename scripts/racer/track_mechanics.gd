class_name TrackMechanics
extends Node3D
## Streckenmechaniken von Nitro Dash: Optik und (für zeitgesteuerte Gefahren) Logik.
##
##  * Trennwände (dividers): feste Mittelinsel → zwei Routen (z. B. Felsinsel, Häuserblock, Tempelruine).
##  * Sprungfelder (bounces): Leuchtpilz, Kaugummi, Sternfeder, Düne – je nach Thema. Danach ist ein Trick möglich.
##  * Gefahren (hazards): Lavafontäne ("geyser") und rollender Baumstamm ("log") – immer mit Vorwarnung (Glühen,
##    Grollen, Staub), feste Takte aus der Rennzeit: auf allen Geräten gleich, nie überraschend.
##  * Baumtunnel (tunnel), Wasserfall (falls), Pfützen auf nassen Abschnitten (wet).
## Treffer durch Gefahren gelten nur für eigene Karts (Opfer-Autorität) – gemeldet über on_hit(racer, kind).

var track: RaceTrack
var def: Dictionary
var theme := ""
var on_hit: Callable          # (Racer, String) → void
var _hz_nodes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _falls_s: Array[float] = []
var _prev_s: Dictionary = {}   # Racer-Index → s im letzten Takt (Durchfahrt durch den Wasserfall)


func build(t: RaceTrack, d: Dictionary) -> void:
	track = t
	def = d
	theme = String(d.get("theme", ""))
	_rng.seed = hash(String(d.get("id", ""))) + 7
	_build_dividers()
	_build_bounces()
	_build_hazards()
	for tu in d.get("tunnel", []):
		_build_tunnel(track.point_s[int(tu[0])], track.point_s[int(tu[1])])
	for fi in d.get("falls", []):
		_build_falls(track.point_s[int(fi)])
	for w in track.wet_ranges:
		_build_puddles(w.x, w.y)


func _xf(s: float, x: float, h := 0.0) -> Transform3D:
	var fr := track.frame(s)
	return Transform3D(fr.basis, fr.origin + fr.basis.x * x + fr.basis.y * h)


static func _mat(col: Color, rough := 0.7, emit := 0.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color(col.r, col.g, col.b)
		m.emission_energy_multiplier = emit
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# --- Trennwände -----------------------------------------------------------------------------------------

func _build_dividers() -> void:
	var col: Color = {"pirates": Color("#8a8f86"), "city": Color("#b9bcc4"), "jungle": Color("#8a8466")}.get(theme, Color("#9a9aa2"))
	var props: Array = {"pirates": [["pirate/rocks_a", 0.8], ["pirate/palm", 1.6]], "city": [["sub/tree", 5.0], ["sub/planter", 6.0], ["race/light_post", 4.5]],
		"jungle": [["dun/pillar", 1.4], ["arena/statue", 3.5], ["nat/bush", 6.0]]}.get(theme, [["nat/rock_large", 4.0], ["nat/bush", 6.0]])
	var mat := _mat(col, 0.85)
	var cap := _mat(col.lightened(0.25), 0.8)
	for dv in track.dividers:
		var s := float(dv.s0)
		var k := 0
		while s < float(dv.s1):
			var info := track.divider_at(s + 2.0)
			if not info.is_empty() and float(info.half) > 0.3:
				var half := float(info.half)
				var seg := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(half * 2.0, 1.1, 4.2)
				bm.material = mat
				seg.mesh = bm
				add_child(seg)
				seg.global_transform = _xf(s + 2.0, float(info.mid), 0.55)
				var top := MeshInstance3D.new()
				var bm2 := BoxMesh.new()
				bm2.size = Vector3(half * 2.0 + 0.3, 0.15, 4.25)
				bm2.material = cap
				top.mesh = bm2
				seg.add_child(top)
				top.position.y = 0.6
				if k % 3 == 1 and half > 1.4:
					var pr: Array = props[_rng.randi() % props.size()]
					var p := WorldKit.place(self, String(pr[0]), Vector3.ZERO, 0.0, float(pr[1]), false, true)
					p.global_transform = _xf(s + 2.0, float(info.mid), 1.15) * Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3.ZERO)
					p.scale = Vector3.ONE * float(pr[1])
			s += 4.0
			k += 1
		# Warnpfeile an der Spitze: hier teilt sich die Strecke
		var nose := WorldKit.place(self, "race/barrier_white", Vector3.ZERO, 0.0, 3.0, false, false)
		nose.global_transform = _xf(float(dv.s0) + 1.0, (float(dv.x0) + float(dv.x1)) * 0.5, 0.0)
		nose.scale = Vector3.ONE * 3.0


# --- Sprungfelder ---------------------------------------------------------------------------------------

func _build_bounces() -> void:
	for b in track.bounces:
		var n := Node3D.new()
		add_child(n)
		n.global_transform = _xf(float(b.s), float(b.x), 0.0)
		var w := float(b.w)
		match theme:
			"forest":   # Leuchtpilz
				var col: Color = [Color("#d9a8ff"), Color("#8fe8ff"), Color("#ffb3e6")][_rng.randi() % 3]
				# Pilzhut (Halbkugel) auf dunklem Sockelring, helle Punkte – Leuchtkraft < 1, damit die Farbe erhalten bleibt
				var base := MeshInstance3D.new()
				var bm := CylinderMesh.new()
				bm.top_radius = w * 0.5
				bm.bottom_radius = w * 0.52
				bm.height = 0.12
				bm.material = _mat(col.darkened(0.55), 0.8)
				base.mesh = bm
				base.position.y = 0.06
				n.add_child(base)
				var capm := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = w * 0.47
				sm.height = w * 0.3
				sm.is_hemisphere = true
				sm.material = _mat(col, 0.45, 0.6)
				capm.mesh = sm
				capm.position.y = 0.1
				n.add_child(capm)
				for k in 6:
					var dot := MeshInstance3D.new()
					var ds := SphereMesh.new()
					ds.radius = w * 0.06
					ds.height = w * 0.05
					ds.material = _mat(Color("#fff8ee"), 0.5, 0.35)
					dot.mesh = ds
					var a := TAU * k / 6.0 + 0.4
					var rr := w * (0.24 if k % 2 == 0 else 0.33)
					dot.position = Vector3(cos(a) * rr, 0.1 + w * 0.3 * sqrt(maxf(1.0 - pow(rr / (w * 0.47), 2.0), 0.0)), sin(a) * rr)
					n.add_child(dot)
				var l := OmniLight3D.new()
				l.light_color = col
				l.light_energy = 1.4
				l.omni_range = 7.0
				l.position.y = 1.5
				n.add_child(l)
			"candy":    # Kaugummi-Kissen
				var gm := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = w * 0.45
				cm.bottom_radius = w * 0.5
				cm.height = 0.3
				cm.material = _mat(Color("#ff7fbf"), 0.25)
				gm.mesh = cm
				gm.position.y = 0.15
				n.add_child(gm)
				var bub := MeshInstance3D.new()
				var bs := SphereMesh.new()
				bs.radius = w * 0.22
				bs.height = w * 0.3
				bs.material = _mat(Color(1.0, 0.6, 0.85, 0.75), 0.15)
				bub.mesh = bs
				bub.position = Vector3(w * 0.15, 0.4, 0)
				n.add_child(bub)
			"desert":   # Sanddüne
				var du := MeshInstance3D.new()
				var dm := SphereMesh.new()
				dm.radius = w * 0.6
				dm.height = w * 0.6
				dm.material = _mat(Color("#e2c48a"), 0.95)
				du.mesh = dm
				du.scale = Vector3(1, 0.25, 1.4)
				n.add_child(du)
			_:          # Sternfeder
				var plate := MeshInstance3D.new()
				var pm := CylinderMesh.new()
				pm.top_radius = w * 0.45
				pm.bottom_radius = w * 0.45
				pm.height = 0.18
				pm.material = _mat(Color("#ffd23f"), 0.3, 0.8)
				plate.mesh = pm
				plate.position.y = 0.35
				n.add_child(plate)
				var spr := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = w * 0.18
				tm.outer_radius = w * 0.28
				tm.material = _mat(Color("#c8ccd8"), 0.3, 0.0, 0.8)
				spr.mesh = tm
				spr.position.y = 0.15
				n.add_child(spr)
		b["node"] = n


## Sprungfeld wurde überfahren: kurz zusammendrücken (Optik).
func bounce_fx(s: float, x: float) -> void:
	for b in track.bounces:
		if absf(track.wrap_s(s - float(b.s) + track.length * 0.5) - track.length * 0.5) < 4.0 and absf(x - float(b.x)) < float(b.w):
			var n: Node3D = b.get("node")
			if n:
				Juice.squash(n, 1.3, 0.4, 0.3, Vector3.ONE)
			FX.burst(n.global_position + Vector3.UP * 0.5, {"amount": 10, "life": 0.5, "spread": 60.0, "vel_min": 2.0, "vel_max": 4.0, "size": 0.25,
				"color": Color(1, 0.85, 1.0)})
			return


# --- Gefahren ------------------------------------------------------------------------------------------

func _build_hazards() -> void:
	for h in track.hazards:
		var root := Node3D.new()
		add_child(root)
		var e := {"h": h, "root": root}
		match String(h.type):
			"geyser":
				root.global_transform = _xf(float(h.s), float(h.x), 0.02)
				var rim := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = float(h.w) * 0.32
				tm.outer_radius = float(h.w) * 0.5
				tm.material = _mat(Color("#3a2a26"), 0.95)
				rim.mesh = tm
				rim.scale = Vector3(1, 0.5, 1)
				root.add_child(rim)
				var pool := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = float(h.w) * 0.34
				cm.bottom_radius = float(h.w) * 0.34
				cm.height = 0.05
				var lm := _mat(Color("#ff6a1a"), 0.4, 1.0)
				cm.material = lm
				pool.mesh = cm
				root.add_child(pool)
				e["pool_mat"] = lm
				var col := FX.emitter({"amount": 60, "life": 0.9, "one_shot": false, "explosive": 0.0, "spread": 12.0, "dir": Vector3.UP, "vel_min": 9.0,
					"vel_max": 14.0, "gravity": Vector3(0, -6, 0), "size": 0.7, "additive": true, "color": Color(1.0, 0.5, 0.15, 0.95), "box": Vector3(1.2, 0.2, 1.2)})
				root.add_child(col)
				col.emitting = false
				e["column"] = col
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.5, 0.2)
				l.light_energy = 0.0
				l.omni_range = 10.0
				l.position.y = 2.0
				root.add_child(l)
				e["light"] = l
			"log":
				var lg := MeshInstance3D.new()
				var cm2 := CylinderMesh.new()
				cm2.top_radius = 0.75
				cm2.bottom_radius = 0.75
				cm2.height = 4.4
				cm2.radial_segments = 12
				cm2.material = _mat(Color("#7a5232"), 0.9)
				lg.mesh = cm2
				lg.rotation.x = PI * 0.5   # Achse entlang der Fahrtrichtung, rollt quer über die Strecke
				var holder := Node3D.new()
				root.add_child(holder)
				holder.add_child(lg)
				for sd: float in [-1.0, 1.0]:
					var ring := MeshInstance3D.new()
					var rc := CylinderMesh.new()
					rc.top_radius = 0.6
					rc.bottom_radius = 0.6
					rc.height = 0.05
					rc.material = _mat(Color("#c9a26a"), 0.8)
					ring.mesh = rc
					ring.position.y = sd * 2.22
					lg.add_child(ring)
				e["log"] = holder
				e["mesh"] = lg
				root.visible = false
		_hz_nodes.append(e)


## Pro Physik-Schritt: Gefahren animieren und eigene Karts treffen.
func tick(race_t: float, racers: Array) -> void:
	if not _falls_s.is_empty():   # Durchfahrt durch den Wasserfall: Platsch und Gischt (rein optisch, für alle Karts)
		for r in racers:
			var rr := r as Racer
			var ps := float(_prev_s.get(rr.idx, rr.s))
			_prev_s[rr.idx] = rr.s
			for fs in _falls_s:
				if ps < fs and rr.s >= fs and rr.s - ps < 5.0:
					FX.splash(rr.global_position + Vector3.UP * 1.2, 1.3)
					Audio.sfx("splash", rr.global_position, -6.0 if rr.is_cpu else 0.0, 1.1)
	for e in _hz_nodes:
		var h: Dictionary = e.h
		var ph := RaceTrack.hazard_phase(h, race_t)
		match String(h.type):
			"geyser":
				var col: CPUParticles3D = e.column
				col.emitting = ph >= 1.0
				var l: OmniLight3D = e.light
				var pm: StandardMaterial3D = e.pool_mat
				if ph >= 1.0:
					l.light_energy = 3.0
					pm.emission_energy_multiplier = 2.5
				elif ph < 0.0:   # Vorwarnung: das Becken glüht auf und blubbert
					l.light_energy = -ph * 1.5
					pm.emission_energy_multiplier = 1.0 - ph * 1.5 + sin(race_t * 30.0) * 0.3
				else:
					l.light_energy = 0.0
					pm.emission_energy_multiplier = 1.0
				if ph >= 1.0:
					for r in racers:
						var rr := r as Racer
						if rr.remote or rr.h > 4.0:
							continue
						var ds := absf(track.wrap_s(rr.s - float(h.s) + track.length * 0.5) - track.length * 0.5)
						if ds < 2.4 and absf(rr.x - float(h.x)) < float(h.w) * 0.5 + 0.6:
							on_hit.call(rr, "geyser")
			"log":
				var root: Node3D = e.root
				var period := float(h.get("period", 5.0))
				var on := float(h.get("on", 2.0))
				var u := fposmod(race_t + float(h.get("phase", 0.0)), period)
				var hw := track.width * 0.5 + 2.0
				var cycle := int(floor((race_t + float(h.get("phase", 0.0))) / period))
				var dir := 1.0 if cycle % 2 == 0 else -1.0
				if u < on:
					root.visible = true
					var x := lerpf(-hw * dir, hw * dir, u / on)
					root.global_transform = _xf(float(h.s), x, 0.75)
					var mesh: Node3D = e.mesh
					mesh.rotation = Vector3(PI * 0.5, 0.0, -x / 0.75)   # rollt
					if int(u * 5.0) != int((u - 0.016) * 5.0):
						FX.dust(root.global_position + Vector3.DOWN * 0.6, Color(0.6, 0.5, 0.35), 3, 0.6)
					for r in racers:
						var rr := r as Racer
						if rr.remote or rr.h > 1.2:
							continue
						var ds := absf(track.wrap_s(rr.s - float(h.s) + track.length * 0.5) - track.length * 0.5)
						if ds < 2.6 and absf(rr.x - x) < 1.4:
							on_hit.call(rr, "log")
				else:
					root.visible = false


## Ist eine Gefahr bei (s, x) in Kürze aktiv? (für die KI: lieber ausweichen)
func danger_at(s: float, x: float, race_t: float) -> bool:
	for e in _hz_nodes:
		var h: Dictionary = e.h
		var ds := track.wrap_s(float(h.s) - s)
		if ds > 28.0:
			continue
		var ph := RaceTrack.hazard_phase(h, race_t + ds / 25.0)
		if ph != 0.0 and String(h.type) == "geyser" and absf(x - float(h.x)) < float(h.w) * 0.5 + 1.6:
			return true
	return false


# --- Baumtunnel, Wasserfall, Pfützen ---------------------------------------------------------------------

func _build_tunnel(s0: float, s1: float) -> void:
	var bark := _mat(Color("#4a3322"), 0.9)
	var moss := _mat(Color("#3f6a32"), 0.9)
	var r := track.width * 0.5 + 1.6
	var s := s0
	var k := 0
	while s < s1:
		var arch := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r
		tm.outer_radius = r + 1.4
		tm.rings = 18
		tm.ring_segments = 8
		tm.material = bark if k % 3 != 2 else moss
		arch.mesh = tm
		add_child(arch)
		arch.global_transform = _xf(s, 0.0, 0.0) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
		arch.scale = Vector3(1.0, 1.0, 1.0 + 0.15 * sin(k * 1.7))
		if k % 2 == 0:
			var glow := OmniLight3D.new()
			glow.light_color = [Color("#d9a8ff"), Color("#8fe8ff")][k % 2]
			glow.light_energy = 0.9
			glow.omni_range = 9.0
			add_child(glow)
			glow.global_position = _xf(s, (k % 4 - 1.5) * 3.0, 3.5).origin
		s += 6.0
		k += 1


func _build_falls(s: float) -> void:
	_falls_s.append(s)
	var fr := _xf(s, 0.0, 0.0)
	var hw := track.width * 0.5
	var left := -fr.basis.x
	var rock := Color("#6a767c")
	# Felswand links, Überhang quer über die Fahrbahn, Stützfels rechts – daraus stürzt der Wasserfall auf die Straße
	var cliff := WorldKit.box(self, Vector3(5, 26, 22), Vector3.ZERO, rock, false)
	cliff.global_transform = Transform3D(fr.basis, fr.origin + left * (hw + 4.5) + Vector3.UP * 12.0)
	var ledge := WorldKit.box(self, Vector3(track.width + 9.0, 2.2, 5.0), Vector3.ZERO, rock.darkened(0.1), false)
	ledge.global_transform = Transform3D(fr.basis, fr.origin + left * 1.5 + Vector3.UP * 8.6)
	var pillar := WorldKit.box(self, Vector3(3.2, 9.5, 4.2), Vector3.ZERO, rock.lightened(0.08), false)
	pillar.global_transform = Transform3D(fr.basis, fr.origin - left * (hw + 2.2) + Vector3.UP * 4.0)
	for k in 3:   # Moos und Büsche auf dem Überhang
		var bp := fr.origin + fr.basis.x * lerpf(-hw, hw, k / 2.0) + Vector3.UP * 9.8
		WorldKit.place(self, "nat/bush", bp, _rng.randf() * 360.0, 4.5, false, false)
	# Vorhang quer über der Fahrbahn (zum Durchfahren) und der hohe Fall an der Felswand
	# durchscheinend (der Wasser-Shader ist deckend – dahinter muss man Karts und Items sehen können)
	var across := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(track.width + 2.0, 7.6)
	across.mesh = qm
	across.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.78, 0.92, 1.0, 0.42)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.roughness = 0.1
	cm.emission_enabled = true
	cm.emission = Color(0.55, 0.75, 0.95)
	cm.emission_energy_multiplier = 0.35
	var nt := NoiseTexture2D.new()
	nt.width = 64
	nt.height = 128
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.06
	nt.noise = fn
	cm.albedo_texture = nt
	cm.uv1_scale = Vector3(7.0, 0.7, 1.0)   # senkrechte Schlieren
	across.material_override = cm
	add_child(across)
	across.global_transform = Transform3D(fr.basis, fr.origin + Vector3.UP * 3.8)
	across.create_tween().set_loops().tween_property(cm, "uv1_offset:y", -1.0, 0.9).as_relative()
	var side := WorldKit.water(self, Vector2(10.0, 22.0), 0.0, Color(0.45, 0.72, 0.95), Color(0.9, 0.97, 1.0))
	side.global_transform = Transform3D(fr.basis * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, PI * 0.5), fr.origin + left * (hw + 1.8) + Vector3.UP * 11.0)
	for sd: float in [-1.0, 1.0]:   # Gischt am Boden vor und hinter dem Vorhang
		var mist := FX.emitter({"amount": 60, "life": 1.8, "one_shot": false, "explosive": 0.0, "spread": 80.0, "dir": Vector3.UP, "vel_min": 1.0,
			"vel_max": 3.0, "gravity": Vector3(0, -1.2, 0), "size": 0.9, "color": Color(1, 1, 1, 0.3), "box": Vector3(hw, 0.5, 1.5)})
		add_child(mist)
		mist.global_transform = Transform3D(fr.basis, fr.origin + fr.basis.z * sd * 1.6 + Vector3.UP * 0.6)
		mist.emitting = true
	var pool := WorldKit.water(self, Vector2(10.0, 22.0), 0.0, Color(0.2, 0.45, 0.7), Color(0.6, 0.88, 1.0))
	pool.global_position = fr.origin + left * (hw + 3.5) + Vector3.UP * -0.2


func _build_puddles(s0: float, s1: float) -> void:
	var mat := _mat(Color(0.35, 0.5, 0.65, 0.45), 0.04, 0.0, 0.3)
	var s := s0 + 4.0
	while s < s1:
		var pd := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = _rng.randf_range(1.0, 2.2)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.02
		cm.radial_segments = 16
		cm.material = mat
		pd.mesh = cm
		pd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pd)
		pd.global_transform = _xf(s, _rng.randf_range(-track.width * 0.35, track.width * 0.35), 0.04)
		pd.scale = Vector3(1.0, 1.0, _rng.randf_range(1.2, 2.0))
		s += _rng.randf_range(5.0, 9.0)
