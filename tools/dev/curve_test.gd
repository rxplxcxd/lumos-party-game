extends Node
func run() -> void:
	var c := Curve3D.new()
	c.add_point(Vector3(0, 0, 0))
	c.add_point(Vector3(10, 0, 0))
	c.add_point(Vector3(20, 0, 0))
	var t := c.sample_baked_with_rotation(5.0, true, true)
	print("straight +X: x=", t.basis.x.snapped(Vector3.ONE*0.01), " y=", t.basis.y.snapped(Vector3.ONE*0.01), " z=", t.basis.z.snapped(Vector3.ONE*0.01))
	# vertical loop along +X
	var l := Curve3D.new()
	var R := 10.0
	for k in 9:
		var th := TAU * k / 8.0
		var p := Vector3(sin(th) * R, R - cos(th) * R, -16.0 * k / 8.0)
		var tn := Vector3(cos(th) * R, sin(th) * R, -16.0 / 8.0 / (TAU/8.0)) * (TAU / 8.0) * 0.33
		l.add_point(p, -tn, tn)
	var L := l.get_baked_length()
	for f in [0.0, 0.25, 0.5, 0.75, 0.98]:
		var tt := l.sample_baked_with_rotation(L * f, true, true)
		print("loop f=", f, " pos=", tt.origin.snapped(Vector3.ONE*0.1), " up=", tt.basis.y.snapped(Vector3.ONE*0.01), " -z=", (-tt.basis.z).snapped(Vector3.ONE*0.01))
