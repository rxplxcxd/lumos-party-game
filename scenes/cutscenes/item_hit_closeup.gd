extends Cutscene
## Item-Treffer-Closeup: Trifft eine Super-Waffe, schaltet die Kamera für ~0,5 Sekunden in eine
## kinoreife Zeitlupe und dreht sich Matrix-artig um das Opfer. Das Rennen läuft (in Zeitlupe) weiter.

func run(d: Node, ctx: Dictionary) -> void:
	var victim: Node3D = ctx.victim
	if not is_instance_valid(victim):
		return
	Juice.slowmo(0.15, 0.62)
	var c := victim.global_position + victim.global_basis.y * 1.2
	var back := victim.global_basis.z
	var a0 := rad_to_deg(atan2(back.x, back.z)) - 60.0
	d.cut(c + Vector3(sin(deg_to_rad(a0)), 0.3, cos(deg_to_rad(a0))) * 6.0, c, 42.0)
	Audio.sfx("whoosh", c, 0.0, 0.5)
	# Dauer in Spielzeit: 0.085 s * (1/0.15) ≈ 0.55 s Echtzeit
	await d.orbit(c, 6.0, 1.6, a0, a0 + 150.0, 0.085, 36.0, 0.0, 4.6, 1.0)
