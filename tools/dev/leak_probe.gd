extends Node
## Leck-Sonde: spielt wie der Soak-Test eine CPU-Party und gibt bei jedem Szenenwechsel (ohne geladene Szene) die
## Größe aller Listen/Dictionaries der Autoloads aus – die Einträge, die stetig wachsen, sind die Lecks.
##   ./godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/leak_probe.gd --changes=30
var _args := {}
var _first := {}


func run() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	for p in Game.players:
		p.cpu = true
	Game.start_party(String(_args.get("board", "meadow")), 30, "classic")
	Router.log_scenes = true
	var changes := int(_args.get("changes", "30"))
	var t := 0.0
	var last := 0
	Router.goto("res://scenes/party/PartyBoard.tscn")
	while t < 7200.0:
		await tree.process_frame
		t += get_process_delta_time()
		if Router._empty_samples.size() != last:
			last = Router._empty_samples.size()
			_report(last)
			if last >= changes:
				break
	for o in [get_tree().root, EventBus]:
		for sig in (o as Object).get_signal_list():
			var cl: Array = (o as Object).get_signal_connection_list(sig.name)
			if cl.size() > 1:
				var tg: Array = cl.map(func(c: Dictionary) -> String:
					var cb: Callable = c.callable
					var ob := cb.get_object()
					return "%s:%s" % [(ob.get_script().resource_path.get_file() if ob and ob.get_script() else (ob.get_class() if ob else "?")), cb.get_method()])
				print("[LEAK] %s.%s: %d · %s" % [o.name, sig.name, cl.size(), ", ".join(tg.slice(0, 12))])
	tree.quit()


func _report(n: int) -> void:
	var sizes := {}
	for c in get_tree().root.get_children():
		if c == self or c == get_tree().current_scene:
			continue
		_scan(c, String(c.name), sizes)
		for cc in c.get_children():
			if cc.get_script():
				_scan(cc, "%s/%s" % [c.name, cc.name], sizes)
	# Signal-Verbindungen langlebiger Objekte: wachsen sie, hängen Lambdas (samt eingefangener Daten) an toten Szenen
	var conn_objs: Array = [get_tree(), get_tree().root]
	for c in get_tree().root.get_children():
		if c != get_tree().current_scene:
			conn_objs.append(c)
	for o in conn_objs:
		var total := 0
		for sig in (o as Object).get_signal_list():
			total += (o as Object).get_signal_connection_list(sig.name).size()
		sizes["~Signale %s" % (o.name if o is Node else "SceneTree")] = total
	if "--music-off" in OS.get_cmdline_user_args():
		for k in Audio._cache.keys():
			if String(k).contains("/music/"):
				Audio._cache.erase(k)
	sizes["static UI"] = UI.cache_size()
	sizes["static PropSettler"] = PropSettler.cache_size()
	sizes["~Kinder-Nodes Autoloads"] = _count_nodes(get_tree().root) - (_count_nodes(get_tree().current_scene) if get_tree().current_scene else 0)
	if _first.is_empty():
		_first = sizes
	var grow: Array = []
	for k in sizes:
		var d := int(sizes[k]) - int(_first.get(k, 0))
		if d > 0:
			grow.append("%s +%d (%d)" % [k, d, int(sizes[k])])
	print("[LEAK] %2d %.1f MB · %s" % [n, Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6, ", ".join(grow)])


func _count_nodes(n: Node) -> int:
	if n == null:
		return 0
	var k := 1
	for c in n.get_children():
		k += _count_nodes(c)
	return k


func _scan(o: Object, prefix: String, out: Dictionary) -> void:
	for prop in o.get_property_list():
		if not (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v: Variant = o.get(prop.name)
		if v is Dictionary or v is Array:
			out["%s.%s" % [prefix, prop.name]] = _deep_size(v, 0)


func _deep_size(v: Variant, depth: int) -> int:
	var n := 0
	if v is Dictionary:
		n = (v as Dictionary).size()
		if depth < 2:
			for e in (v as Dictionary).values():
				n += _deep_size(e, depth + 1)
	elif v is Array:
		n = (v as Array).size()
		if depth < 2:
			for e in v:
				n += _deep_size(e, depth + 1)
	return n
