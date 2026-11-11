extends Node
## Bildzeit-Sonde: misst die Dauer jedes Bilds (ohne Rendern im Headless-Betrieb = reine Rechenzeit) und meldet
## Ausreißer über --spike=ms (Standard 25). Startet optional eine Szene (--probe-scene=res://…).
##   godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/frame_probe.gd
##     --probe-scene=res://scenes/party/PartyBoard.tscn --test-roulette --perf-log --secs=40

var _last := 0
var _t0 := 0
var _spike := 25.0
var _worst := 0.0
var _n := 0
var _sum := 0.0


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_spike = float(args.get("spike", "25"))
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	process_mode = Node.PROCESS_MODE_ALWAYS
	if args.has("probe-scene"):
		tree.change_scene_to_file(String(args["probe-scene"]))
	_t0 = Time.get_ticks_msec()
	_last = Time.get_ticks_usec()
	await tree.create_timer(float(args.get("secs", "30")), true, false, true).timeout
	print("[PERF] Bilder %d · Mittel %.1f ms · schlechtestes %.1f ms" % [_n, _sum / maxf(1, _n), _worst])
	tree.quit()


func _process(_d: float) -> void:
	if _t0 == 0:
		return
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	_n += 1
	_sum += dt
	_worst = maxf(_worst, dt)
	if dt > _spike:
		print("[PERF] Spitze %.0f ms bei t=%d" % [dt, Time.get_ticks_msec()])
