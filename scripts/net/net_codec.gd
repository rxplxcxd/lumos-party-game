class_name NetCodec
extends RefCounted
## Typsichere Kodierung von Spielzuständen für JSON-Nachrichten.
## JSON kennt nur Zahlen (immer float), Text-Schlüssel und Listen. Spielzustände brauchen aber Ganzzahlen,
## Ganzzahl-Schlüssel (z. B. Fallen je Feld) und Vektoren. enc() markiert diese Typen, dec() stellt sie wieder her.
## Bewusst ohne str_to_var(): Netzdaten dürfen nie beliebige Objekte erzeugen können.


static func enc(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return {"~f": v}
		TYPE_VECTOR2:
			return {"~v2": [v.x, v.y]}
		TYPE_VECTOR3:
			return {"~v3": [v.x, v.y, v.z]}
		TYPE_COLOR:
			return {"~c": [v.r, v.g, v.b, v.a]}
		TYPE_ARRAY:
			return (v as Array).map(func(e: Variant) -> Variant: return enc(e))
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return enc(Array(v))
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				var key: String = ("~i%d" % k) if typeof(k) == TYPE_INT else String(k)
				out[key] = enc(v[k])
			return out
		TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME, TYPE_NIL:
			return v
	return null   # Objekte, Callables usw. werden nie übertragen


static func dec(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if is_equal_approx(v, roundf(v)) and absf(v) < 9.0e15 else v
		TYPE_ARRAY:
			return (v as Array).map(func(e: Variant) -> Variant: return dec(e))
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.size() == 1:
				if d.has("~f"):
					return float(d["~f"])
				if d.has("~v2") and d["~v2"] is Array and (d["~v2"] as Array).size() == 2:
					return Vector2(float(d["~v2"][0]), float(d["~v2"][1]))
				if d.has("~v3") and d["~v3"] is Array and (d["~v3"] as Array).size() == 3:
					return Vector3(float(d["~v3"][0]), float(d["~v3"][1]), float(d["~v3"][2]))
				if d.has("~c") and d["~c"] is Array and (d["~c"] as Array).size() == 4:
					return Color(float(d["~c"][0]), float(d["~c"][1]), float(d["~c"][2]), float(d["~c"][3]))
			var out := {}
			for k in d:
				var key: Variant = k
				var ks := String(k)
				if ks.begins_with("~i") and ks.substr(2).is_valid_int():
					key = int(ks.substr(2))
				out[key] = dec(d[k])
			return out
	return v


## Kodieren und wie über das Netz (JSON) zurücklesen – für Tests und um lokal denselben Typ zu erhalten.
static func roundtrip(v: Variant) -> Variant:
	return dec(JSON.parse_string(JSON.stringify(enc(v))))
