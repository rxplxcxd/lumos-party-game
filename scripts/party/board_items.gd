class_name BoardItems
extends RefCounted
## Item-Sortiment des Bretts (Shop, Glücksfelder, Partner). Bis zu MAX Items pro Spieler.
## Persistenz: Items liegen in Game.players[i].items und werden NUR durch Benutzung oder gewollte Mechaniken
## (Tausch-/Diebstahlkarten, Boss-Zange) entfernt – siehe PartyBoard._verify_inventory().

const MAX := 3

## kind: "dice" (vor dem Wurf), "card" (vor dem Wurf, Ziel wählen), "trap" (auf eigenes Feld legen), "passive"
const ITEMS := {
	"double_dice": {"name": "Doppelwürfel", "desc": "Zwei Würfel: 2–20 Felder", "price": 8, "kind": "dice", "icon": "double_dice"},
	"triple_dice": {"name": "Dreifachwürfel", "desc": "Drei Würfel: 3–30 Felder", "price": 15, "kind": "dice", "icon": "double_dice"},
	"custom_dice": {"name": "Wunschwürfel", "desc": "Du bestimmst die Zahl (1–10)", "price": 10, "kind": "dice", "icon": "dice"},
	"slow_dice": {"name": "Schneckenwürfel", "desc": "Nur 1–3 Felder – zum genauen Ansteuern", "price": 3, "kind": "dice", "icon": "dice"},
	"warp_card": {"name": "Platztausch-Karte", "desc": "Tausche den Platz mit einem Mitspieler", "price": 12, "kind": "card", "icon": "question"},
	"coin_card": {"name": "Münz-Mopser", "desc": "Schnapp dir bis zu 8 Münzen eines Mitspielers", "price": 7, "kind": "card", "icon": "coin"},
	"item_swap": {"name": "Item-Tausch-Karte", "desc": "Tausche alle Items mit einem Mitspieler", "price": 5, "kind": "card", "icon": "question"},
	"trap": {"name": "Münzfalle", "desc": "Auf dein Feld legen: Wer dort landet, zahlt dir 10 Münzen", "price": 6, "kind": "trap", "icon": "cannonball"},
	"key": {"name": "Schlüssel", "desc": "Öffnet ein verschlossenes Abkürzungstor", "price": 5, "kind": "passive", "icon": "crown"},
}

## Shop-Angebot einer Runde (gemeinsamer Brett-Zufall → online überall gleich)
static func shop_stock(round_i: int, board_id: String) -> Array:
	var pool := ITEMS.keys()
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s:%d:%d" % [board_id, round_i, int(Game.party.get("seed", 0))])
	var out: Array = ["double_dice"]
	while out.size() < 4:
		var k: String = pool[r.randi() % pool.size()]
		if not k in out:
			out.append(k)
	return out


static func usable(items: Array) -> Array:
	var out: Array = []
	for it in items:
		if ITEMS.has(it) and String(ITEMS[it].kind) != "passive" and not it in out:
			out.append(it)
	return out


static func label(id: String) -> String:
	return String(ITEMS.get(id, {}).get("name", id))


# --- CPU-Taktik -------------------------------------------------------------------------------------------------
# Leicht: benutzt Items eher zufällig. Mittel: einfache Faustregeln. Profi: rechnet Wege zum Stern.
# Insane: rechnet alle Optionen durch (Sternabstand, Münzbedarf, Gegnerlage), kombiniert Karte + Würfel
# über mehrere Züge (z. B. erst Schlüssel kaufen, dann Abkürzung) – ohne je den Würfel zu beeinflussen.

## Welches Item vor dem Wurf? "" = keins.
static func cpu_pick(board: Node, p: int, items: Array) -> String:
	var lvl := int(Game.players[p].cpu_level)
	var u := usable(items)
	if u.is_empty():
		return ""
	if lvl == 0:
		return String(u[randi() % u.size()]) if randf() < 0.45 else ""
	var star := int(Game.party.get("star_space", -1))
	var here := int(Game.players[p].space)
	var d := int(board.call("_dist", here, star)) if star >= 0 else 99
	var coins := int(Game.players[p].coins)
	var cost := int(board.call("_star_cost", p))
	var best := ""
	var best_v := 0.2 if lvl >= 2 else 0.5
	for it in u:
		var v := _value(board, p, String(it), d, coins, cost, lvl)
		if v > best_v:
			best_v = v
			best = String(it)
	return best


static func _value(board: Node, p: int, it: String, d: int, coins: int, cost: int, lvl: int) -> float:
	var can_buy := coins >= cost
	match it:
		"custom_dice":
			# Stern exakt erreichbar und bezahlbar → fast immer richtig
			if d >= 1 and d <= 10 and can_buy:
				return 3.0
			return 0.6 if lvl >= 3 and d > 10 else 0.0
		"double_dice":
			if d > 6 and d <= 20:
				return 1.6 if can_buy or lvl < 3 else 1.0
			return 0.3 if d > 20 else 0.0
		"triple_dice":
			if d > 12:
				return 2.0 if can_buy or lvl < 3 else 1.2
			return 0.0
		"slow_dice":
			return 2.2 if d >= 1 and d <= 3 and can_buy else 0.0
		"coin_card":
			var rich := _richest_other(p)
			var gain := mini(8, int(Game.players[rich].coins))
			# Insane: spart die Karte, bis sie den Sternkauf ermöglicht
			if lvl >= 3 and not can_buy and coins + gain >= cost and d <= 14:
				return 2.4
			return 0.4 + gain * 0.12
		"warp_card":
			var tgt := _closest_to_star(board, p)
			if tgt < 0:
				return 0.0
			var their := int(board.call("_dist", int(Game.players[tgt].space), int(Game.party.get("star_space", -1))))
			return clampf((d - their) / 8.0, 0.0, 2.6)
		"item_swap":
			var best_items := 0
			for o in 4:
				if o != p:
					best_items = maxi(best_items, (Game.players[o].items as Array).size())
			return 0.0 if best_items <= (Game.players[p].items as Array).size() else 0.5 + best_items * 0.3
		"trap":
			# Fallen am besten kurz vor dem Stern bzw. auf dem Hauptweg
			return 1.3 if d <= 8 else 0.7
	return 0.0


static func cpu_target(board: Node, p: int, it: String) -> int:
	match it:
		"warp_card":
			return _closest_to_star(board, p)
		"coin_card":
			return _richest_other(p)
		"item_swap":
			var best := -1
			var n := -1
			for o in 4:
				if o != p and (Game.players[o].items as Array).size() > n:
					n = (Game.players[o].items as Array).size()
					best = o
			return best
	return (p + 1) % 4


static func cpu_custom_number(board: Node, p: int) -> int:
	var star := int(Game.party.get("star_space", -1))
	var d := int(board.call("_dist", int(Game.players[p].space), star))
	if d >= 1 and d <= 10:
		return d
	return 10


static func _richest_other(p: int) -> int:
	var best := (p + 1) % 4
	for o in 4:
		if o != p and int(Game.players[o].coins) > int(Game.players[best].coins):
			best = o
	return best


static func _closest_to_star(board: Node, p: int) -> int:
	var star := int(Game.party.get("star_space", -1))
	var best := -1
	var bd := 999
	for o in 4:
		if o == p:
			continue
		var dd := int(board.call("_dist", int(Game.players[o].space), star))
		if dd < bd:
			bd = dd
			best = o
	return best


## Kaufentscheidung im Shop: Index im Angebot oder -1. Hält Münzen für den Stern zurück (außer Leicht).
static func cpu_buy(board: Node, p: int, stock: Array, prices: Array) -> int:
	var lvl := int(Game.players[p].cpu_level)
	var coins := int(Game.players[p].coins)
	var reserve := 0 if lvl == 0 else int(board.call("_star_cost", p)) * (1 if lvl >= 2 else 0)
	if (Game.players[p].items as Array).size() >= MAX:
		return -1
	var star := int(Game.party.get("star_space", -1))
	var d := int(board.call("_dist", int(Game.players[p].space), star))
	var best := -1
	var bv := 0.0
	for k in stock.size():
		var price := int(prices[k])
		if price > coins or (lvl >= 1 and coins - price < reserve and lvl < 3):
			continue
		var id := String(stock[k])
		var v := 0.0
		match id:
			"triple_dice":
				v = 1.5 if d > 12 else 0.4
			"double_dice":
				v = 1.2 if d > 6 else 0.5
			"custom_dice":
				v = 1.6 if d <= 14 else 0.6
			"key":
				v = 1.4 if bool(board.call("_lock_ahead", p)) else 0.1
			"warp_card", "coin_card":
				v = 0.9
			"trap":
				v = 0.6
			"slow_dice":
				v = 0.8 if d <= 5 else 0.1
			"item_swap":
				v = 0.4
		if lvl == 0:
			v = randf()
		# Insane darf unter die Stern-Reserve gehen, wenn das Item den Sternkauf wahrscheinlicher macht
		if lvl >= 3 and coins - price < int(board.call("_star_cost", p)) and not id in ["custom_dice", "key", "coin_card"]:
			v *= 0.4
		v -= price * 0.03
		if v > bv:
			bv = v
			best = k
	return best if bv > 0.35 else -1
