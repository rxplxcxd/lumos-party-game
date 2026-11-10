class_name AvatarRetarget
extends SkeletonModifier3D
## Überträgt die Pose eines (unsichtbaren) KayKit-Rig_Medium-Referenzskeletts Bild für Bild auf das Skelett
## eines eigenen Avatars. Verfahren: globale Rest-Delta-Rotation je Knochen
##   Ziel_global = (Pose_src · Rest_src⁻¹) · Rest_dst
## (in den jeweiligen Skelett-Räumen, über die Weltrotation beider Skelette ineinander umgerechnet).
## Dadurch laufen ALLE Rig-Clips, Reaktionen und der prozedurale SlapstickModifier ohne eigene Animationen –
## der Avatar muss nur ein humanoides Skelett in T-Pose mitbringen (Mixamo, VRM, Unity-Humanoid, Blender-Rigify-
## Deform, Bip01 …). Die Knochennamen werden automatisch zugeordnet (map_bones).

## Logische KayKit-Knochen (Rig_Medium) und ihre üblichen Namen in anderen Rigs (ohne Seite, kleingeschrieben).
const CANON := {
	"hips": ["hips", "pelvis", "hip", "root_hips"],
	"spine": ["spine", "spine0", "spine01", "abdomen", "torso", "spinelower"],
	"chest": ["chest", "spine2", "upperchest", "spine02", "spine1", "spine03", "spine3", "spineupper", "thorax"],
	"head": ["head"],
	"upperarm": ["upperarm", "arm", "uparm", "shoulderjoint"],
	"lowerarm": ["lowerarm", "forearm", "elbow", "lowarm"],
	"hand": ["hand", "wrist"],
	"upperleg": ["upperleg", "upleg", "thigh", "femur"],
	"lowerleg": ["lowerleg", "leg", "shin", "calf", "knee", "lowleg"],
	"foot": ["foot", "ankle"],
	"toes": ["toes", "toebase", "toe", "ball"],
}
const KAYKIT_BONES := ["hips", "spine", "chest", "head",
	"upperarm.l", "lowerarm.l", "hand.l", "upperarm.r", "lowerarm.r", "hand.r",
	"upperleg.l", "lowerleg.l", "foot.l", "toes.l", "upperleg.r", "lowerleg.r", "foot.r", "toes.r"]
## Pflichtknochen: ohne sie wird ein Modell abgelehnt (es würde sonst steif herumgleiten).
const REQUIRED := ["hips", "head", "upperarm.l", "upperarm.r", "upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r"]
## Namensteile ohne Bedeutung (Präfixe gängiger Exporter).
const NOISE := ["j", "bip", "bip01", "bip001", "bip1", "c", "def", "org", "mch", "armature", "rig", "bone", "jnt",
	"b", "cc", "base", "valvebiped", "sk", "ctrl", "skel", "humanoid", "char", "character"]

var source: Skeleton3D
var pairs: Array = []                       # [src_idx, dst_idx]
var _src_rest: Array[Transform3D] = []      # globale Rest-Transformation Quelle
var _dst_rest: Array[Transform3D] = []      # globale Rest-Transformation Ziel
var _cache: Array[Transform3D] = []         # zuletzt erfasste Quell-Pose (global, inkl. Slapstick)
var _hips := -1
var _hips_k := 1.0
var _captured := false


## Zerlegt einen beliebigen Knochennamen in [Kern, Seite] – z. B. "mixamorig:LeftUpLeg" → ["upleg", "l"],
## "J_Bip_R_LowerArm" → ["lowerarm", "r"], "upperarm.l" → ["upperarm", "l"], "Bip01 L Thigh" → ["thigh", "l"].
static func canon(raw: String) -> Array:
	var t := raw.to_lower()
	for sep in [":", ".", "-", " ", "|", "/"]:
		t = t.replace(sep, "_")
	var side := ""
	var core := ""
	for part in t.split("_", false):
		if part in NOISE or part.begins_with("mixamorig"):
			continue
		if part in ["l", "left", "lft"]:
			side = "l"
			continue
		if part in ["r", "right", "rgt"]:
			side = "r"
			continue
		core += part
	if side == "":
		for pre in [["left", "l"], ["right", "r"]]:
			if core.begins_with(pre[0]):
				side = pre[1]
				core = core.substr(String(pre[0]).length())
				break
			if core.ends_with(pre[0]):
				side = pre[1]
				core = core.substr(0, core.length() - String(pre[0]).length())
				break
	return [core, side]


## Ordnet die Knochen eines fremden Skeletts den KayKit-Knochen zu: {"upperarm.l": dst_index, …}.
static func map_bones(skel: Skeleton3D) -> Dictionary:
	var by_name := {}
	for i in skel.get_bone_count():
		var c := canon(skel.get_bone_name(i))
		var key := String(c[0]) + ("." + String(c[1]) if String(c[1]) != "" else "")
		if not by_name.has(key):
			by_name[key] = i   # Knochen sind eltern-zuerst sortiert: erster Treffer = der rumpfnähere
	var out := {}
	for kb: String in KAYKIT_BONES:
		var base := kb.get_slice(".", 0)
		var side := kb.get_slice(".", 1) if kb.contains(".") else ""
		for cand: String in CANON[base]:
			var key := cand + ("." + side if side != "" else "")
			if by_name.has(key) and not (int(by_name[key]) in out.values()):
				out[kb] = int(by_name[key])
				break
	return out


static func missing_required(mapping: Dictionary) -> Array:
	return REQUIRED.filter(func(b: String) -> bool: return not mapping.has(b))


## Verbindet Quelle (KayKit-Referenz) und Ziel (dieses Modifiers Skelett).
func bind(src: Skeleton3D, dst: Skeleton3D, mapping: Dictionary) -> void:
	source = src
	pairs.clear()
	var depth := func(sk: Skeleton3D, b: int) -> int:
		var d := 0
		var p := sk.get_bone_parent(b)
		while p >= 0:
			d += 1
			p = sk.get_bone_parent(p)
		return d
	for kb: String in mapping:
		var si := src.find_bone(kb)
		if si >= 0:
			pairs.append([si, int(mapping[kb])])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return depth.call(dst, int(a[1])) < depth.call(dst, int(b[1])))
	_src_rest.clear()
	_dst_rest.clear()
	_cache.clear()
	for k in pairs.size():
		_src_rest.append(src.get_bone_global_rest(int(pairs[k][0])))
		_dst_rest.append(dst.get_bone_global_rest(int(pairs[k][1])))
		_cache.append(_src_rest[k])
		if src.get_bone_name(int(pairs[k][0])) == "hips":
			_hips = k
	_hips_k = -1.0
	if not src.skeleton_updated.is_connected(_capture):
		src.skeleton_updated.connect(_capture)


## Nach allen Modifikatoren der Quelle (also inkl. Slapstick-Torkeln) die finale Pose merken.
func _capture() -> void:
	if not is_instance_valid(source):
		return
	for k in pairs.size():
		_cache[k] = source.get_bone_global_pose(int(pairs[k][0]))
	_captured = true


func _process_modification() -> void:
	var dst := get_skeleton()
	if dst == null or not is_instance_valid(source) or not _captured:
		return
	var a_full := source.global_basis
	var b_full := dst.global_basis
	var a := a_full.orthonormalized()
	var b := b_full.orthonormalized()
	var ab := b.inverse() * a          # Richtungen: Quell-Skelettraum → Ziel-Skelettraum
	var ab_inv := ab.inverse()
	if _hips_k < 0.0 and _hips >= 0:
		# Hüfthöhe beider Figuren in Welt-Einheiten → Verhältnis für Hüft-Verschiebungen (Sprünge, Hinsetzen)
		var hs := (a_full * _src_rest[_hips].origin).y
		var hd := (b_full * _dst_rest[_hips].origin).y
		_hips_k = clampf(hd / hs, 0.2, 5.0) if absf(hs) > 0.0001 else 1.0
	for k in pairs.size():
		var di := int(pairs[k][1])
		var pose_g := _cache[k].basis.orthonormalized()
		var delta := pose_g * _src_rest[k].basis.orthonormalized().inverse()
		var tgt := (ab * delta * ab_inv) * _dst_rest[k].basis.orthonormalized()
		var par := dst.get_bone_parent(di)
		var pg := dst.get_bone_global_pose(par) if par >= 0 else Transform3D()
		dst.set_bone_pose_rotation(di, (pg.basis.orthonormalized().inverse() * tgt).get_rotation_quaternion())
		if k == _hips:
			var dp_world := a_full * (_cache[k].origin - _src_rest[k].origin)
			var dp_dst := b_full.inverse() * dp_world * _hips_k
			var tgt_o := _dst_rest[k].origin + dp_dst
			dst.set_bone_pose_position(di, pg.affine_inverse() * tgt_o)
