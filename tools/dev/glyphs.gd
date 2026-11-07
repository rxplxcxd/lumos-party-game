extends Node
func run() -> void:
	var chars := "◀▶♥✕✓Ⓐ Ⓑ Ⓧ Ⓨ ★ € ↓ ← → ▲ ▼ ‖ ⬇ − – … ß ä ö ü Ä Ö Ü"
	for fp in [Assets.FONT_TITLE, Assets.FONT_BODY]:
		var f: FontFile = load(fp)
		var missing := ""
		for c in chars:
			if c != " " and not f.has_char(c.unicode_at(0)):
				missing += c
		print(fp.get_file(), " fehlt: ", missing)
