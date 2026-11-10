extends Node
## Eigene 3D-Avatare aus dem Lumos-Profil – bewusst OHNE Charakter-Editor.
##
## Herkunft (in dieser Reihenfolge):
##  1. Lumos One OS: Im Browser liefert `window.LumosOS.getAvatar()` (falls vorhanden) das Modell direkt.
##  2. Lumos Cloud:  GET {cloud}/v1/profile/avatar → {"url", "version", "forward", "name"}; danach wird die
##     GLB-Datei (mit Bearer-Token, falls sie auf dem Cloud-Server liegt) geladen.
##  3. Profil-Feld `avatar: {url, version}` (z. B. für Firebase-Konten).
##  4. Entwickler-Test: Startparameter `--avatar=/pfad/zum/modell.glb`.
## Geladene Modelle werden in user://avatars/ zwischengespeichert (Version wird verglichen).
##
## Pipeline: GLB/glTF → GLTFDocument (zur Laufzeit) → Animationen des Modells entfernen → auf Heldengröße
## normieren (Füße auf y = 0, mittig, Blick nach +Z) → Knochen automatisch dem KayKit-Rig_Medium zuordnen
## (AvatarRetarget.map_bones) → als PackedScene gecacht. CharacterRig spielt dann alle Standard-Clips auf einem
## unsichtbaren KayKit-Referenzskelett ab und überträgt die Pose live auf den Avatar (AvatarRetarget).

signal avatar_ready(id: String)
signal avatar_failed(id: String, reason: String)

const CACHE_DIR := "user://avatars/"
const MAX_BYTES := 24 * 1024 * 1024
const REFERENCE_HERO := "hero/knight"   # unsichtbares Referenzskelett (KayKit Rig_Medium)
const SIZE_HERO := "hero/rogue"         # Größenmaß ohne Helm/Hut

var _scenes: Dictionary = {}    # id -> PackedScene (normiertes Modell)
var _meta: Dictionary = {}      # id -> {name, version, url, forward, mapping}
var _busy: Dictionary = {}
var _asked_for := ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	_restore_cache("me")
	Account.changed.connect(_on_account)
	Account.bridge_event.connect(_on_bridge)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--avatar="):
			load_file("me", a.substr(9))
	_on_account.call_deferred()


# --- Öffentliche API --------------------------------------------------------------------------------------------

func has(id: String) -> bool:
	return _scenes.has(id)


## Helden-ID für Spielerprofile: "custom:<id>".
func hero_id(id := "me") -> String:
	return "custom:" + id


## Heldeneintrag wie in Game.HEROES – damit funktionieren Menüs, Badges und Minispiele ohne Sonderfälle.
func hero_entry(hero: String) -> Dictionary:
	var id := hero.substr(7) if hero.begins_with("custom:") else hero
	var m: Dictionary = _meta.get(id, {})
	var nm := String(m.get("name", ""))
	if nm == "":
		nm = Account.display_name() if id == "me" else "Gast-Avatar"
	return {"id": hero_id(id), "name": nm, "model": "custom/" + id, "accent": Color("#ffd27a"), "custom": true}


func instantiate(id: String) -> Node3D:
	var ps: PackedScene = _scenes.get(id)
	return ps.instantiate() as Node3D if ps else null


func mapping(id: String) -> Dictionary:
	return (_meta.get(id, {}) as Dictionary).get("mapping", {})


## Holt einen fremden Avatar (z. B. Online-Mitspieler), falls noch nicht geladen.
func ensure(id: String, url: String, version := 0) -> void:
	if has(id) and int((_meta.get(id, {}) as Dictionary).get("version", 0)) >= version:
		return
	_download(id, url, {"url": url, "version": version}, [])


func load_file(id: String, path: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		avatar_failed.emit(id, "Datei nicht lesbar: " + path)
		return false
	return ingest(id, bytes, {"name": path.get_file().get_basename(), "url": path, "version": 0})


## Kern: Bytes eines GLB (oder eingebetteten glTF) → normiertes, gemapptes Modell.
func ingest(id: String, bytes: PackedByteArray, meta: Dictionary) -> bool:
	if bytes.size() > MAX_BYTES:
		return _fail(id, "Modell ist zu groß (max. 24 MB).")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_buffer(bytes, "", state)
	if err != OK:
		return _fail(id, "Modell konnte nicht gelesen werden (GLB/glTF erwartet).")
	var raw := doc.generate_scene(state) as Node3D
	if raw == null:
		return _fail(id, "Modell ist leer.")
	var res := normalize(raw, String(meta.get("forward", "+z")))
	if res.has("error"):
		raw.free()
		return _fail(id, String(res.error))
	var root: Node3D = res.root
	var ps := PackedScene.new()
	_own(root, root)
	ps.pack(root)
	root.free()
	_scenes[id] = ps
	var m := meta.duplicate()
	m["mapping"] = res.mapping
	_meta[id] = m
	if id == "me":
		_save_cache(id, bytes, meta)
	print("[Avatar] %s geladen · %d Knochen zugeordnet" % [id, (res.mapping as Dictionary).size()])
	avatar_ready.emit(id)
	return true


## Normiert ein frisch geladenes Modell: Animationen weg, Größe wie KayKit-Held, Füße auf den Boden, Blick +Z.
## Gibt {root, mapping} oder {error} zurück.
static func normalize(raw: Node3D, forward := "+z") -> Dictionary:
	for ap in raw.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	var skels := raw.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return {"error": "Das Modell hat kein Skelett – bitte ein humanoides, geriggtes Modell hochladen."}
	var sk: Skeleton3D = skels[0]
	for s in skels:
		if (s as Skeleton3D).get_bone_count() > sk.get_bone_count():
			sk = s
	sk.reset_bone_poses()
	var mp := AvatarRetarget.map_bones(sk)
	var miss := AvatarRetarget.missing_required(mp)
	if not miss.is_empty():
		return {"error": "Skelett nicht erkannt (fehlt: %s)." % ", ".join(miss)}
	var root := Node3D.new()
	root.name = "CustomAvatar"
	root.add_child(raw)
	if forward == "-z":
		raw.rotation.y = PI
	var box := Assets.compute_aabb(root)
	var ref := Assets.model_aabb(SIZE_HERO)
	var h := maxf(box.size.y, 0.01)
	var k := clampf(ref.size.y / h, 0.0005, 2000.0)
	raw.scale *= k
	box = Assets.compute_aabb(root)
	raw.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	for mi in Assets.find_meshes(root):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return {"root": root, "mapping": mp}


# --- Herkunft: Lumos One OS / Lumos Cloud / Profil -------------------------------------------------------------

func _on_account() -> void:
	if not Account.signed_in():
		return
	var key := Account.uid() + "|" + str(Account.profile.get("avatar", {}))
	if key == _asked_for:
		return
	_asked_for = key
	request_own()


## Fragt das eigene Profil-Modell an (Web: über die JS-Brücke, nativ: per HTTP an die Lumos Cloud).
func request_own() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.LumosBridge && LumosBridge.lumosGetAvatar && LumosBridge.lumosGetAvatar(%s)" % JSON.stringify(_profile_avatar_url()), true)
		return
	var cached := int((_meta.get("me", {}) as Dictionary).get("version", -1))
	if String(Account.user.get("provider", "")) == "lumos":
		var req := HTTPRequest.new()
		add_child(req)
		req.timeout = 8.0
		var hdr := Account.auth_headers()
		if req.request(Account.lumos_url + "/v1/profile/avatar", hdr) == OK:
			var r: Array = await req.request_completed
			if int(r[1]) == 200:
				var j = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
				if j is Dictionary and String((j as Dictionary).get("url", "")) != "":
					var meta: Dictionary = j
					if int(meta.get("version", 0)) != cached or not has("me"):
						var url := String(meta.url)
						if url.begins_with("/"):
							url = Account.lumos_url + url
						_download("me", url, meta, hdr if url.begins_with(Account.lumos_url) else [])
		req.queue_free()
		return
	var pu := _profile_avatar_url()
	if pu != "":
		var pv := int((Account.profile.get("avatar", {}) as Dictionary).get("version", 0)) if Account.profile.get("avatar") is Dictionary else 0
		if pv != cached or not has("me"):
			_download("me", pu, {"url": pu, "version": pv}, [])


func _profile_avatar_url() -> String:
	var av: Variant = Account.profile.get("avatar", null)
	if av is Dictionary:
		return String((av as Dictionary).get("url", ""))
	if av is String:
		return String(av)
	return ""


func _on_bridge(type: String, data: Variant) -> void:
	match type:
		"avatar":
			var d: Dictionary = data
			var cached := int((_meta.get("me", {}) as Dictionary).get("version", -1))
			var meta: Dictionary = d.get("meta", {})
			if has("me") and int(meta.get("version", 0)) == cached and String(d.get("b64", "")) == "":
				return
			var bytes := Marshalls.base64_to_raw(String(d.get("b64", "")))
			if not bytes.is_empty():
				ingest("me", bytes, meta)
		"avatar_error":
			push_warning("[Avatar] " + str((data as Dictionary).get("message", "")))


func _download(id: String, url: String, meta: Dictionary, headers: Array) -> void:
	if _busy.get(id, false) or url == "":
		return
	if url.begins_with("user://") or url.begins_with("res://") or url.begins_with("/"):
		load_file(id, url)
		return
	_busy[id] = true
	var req := HTTPRequest.new()
	req.timeout = 30.0
	req.body_size_limit = MAX_BYTES
	add_child(req)
	if req.request(url, PackedStringArray(headers)) != OK:
		_busy[id] = false
		req.queue_free()
		_fail(id, "Download fehlgeschlagen.")
		return
	var r: Array = await req.request_completed
	req.queue_free()
	_busy[id] = false
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS or int(r[1]) >= 300:
		_fail(id, "Avatar-Download fehlgeschlagen (HTTP %d)." % int(r[1]))
		return
	ingest(id, r[3], meta)


# --- Cache ------------------------------------------------------------------------------------------------------

func _save_cache(id: String, bytes: PackedByteArray, meta: Dictionary) -> void:
	var f := FileAccess.open(CACHE_DIR + id + ".glb", FileAccess.WRITE)
	if f:
		f.store_buffer(bytes)
		f.close()
	var clean := meta.duplicate()
	clean.erase("mapping")
	var mf := FileAccess.open(CACHE_DIR + id + ".json", FileAccess.WRITE)
	if mf:
		mf.store_string(JSON.stringify(clean))
		mf.close()


func _restore_cache(id: String) -> void:
	var p := CACHE_DIR + id + ".glb"
	if not FileAccess.file_exists(p):
		return
	var meta: Dictionary = {}
	var j = JSON.parse_string(FileAccess.get_file_as_string(CACHE_DIR + id + ".json"))
	if j is Dictionary:
		meta = j
	ingest(id, FileAccess.get_file_as_bytes(p), meta)


func _fail(id: String, reason: String) -> bool:
	push_warning("[Avatar] %s: %s" % [id, reason])
	avatar_failed.emit(id, reason)
	if id == "me" and is_instance_valid(Account):
		Account.toast("Eigener Avatar: " + reason, Color("#ffb3b3"))
	return false


static func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		_own(c, owner_node)
