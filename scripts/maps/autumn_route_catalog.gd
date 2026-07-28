class_name AutumnRouteCatalog
extends RefCounted

const FLOOR_PROFILE_ORDER: Array[String] = [
	"level",
	"rise_48",
	"fall_48",
	"hill_48",
	"basin_48",
	"mesa_64",
	"shallow_roll",
]

const PLATFORM_ASSEMBLY_ORDER: Array[String] = [
	"low_steps",
	"split_ledges",
	"bridge_arc",
	"staggered",
	"canopy_rise",
	"double_deck",
	"canopy_fall",
	"broken_crown",
]


static func floor_profile(profile_id: String) -> PackedFloat32Array:
	match profile_id:
		"rise_48":
			return PackedFloat32Array([
				0.0, 0.0, -16.0, -32.0, -48.0,
				-48.0, -48.0, -48.0, -48.0, -48.0,
			])
		"fall_48":
			return PackedFloat32Array([
				0.0, 0.0, 16.0, 32.0, 48.0,
				48.0, 48.0, 48.0, 48.0, 48.0,
			])
		"hill_48":
			return PackedFloat32Array([
				0.0, 0.0, -16.0, -32.0, -48.0,
				-48.0, -32.0, -16.0, 0.0, 0.0,
			])
		"basin_48":
			return PackedFloat32Array([
				0.0, 0.0, 16.0, 32.0, 48.0,
				48.0, 32.0, 16.0, 0.0, 0.0,
			])
		"mesa_64":
			return PackedFloat32Array([
				0.0, -16.0, -32.0, -48.0, -64.0,
				-64.0, -48.0, -32.0, -16.0, 0.0,
			])
		"shallow_roll":
			return PackedFloat32Array([
				0.0, 0.0, -12.0, -24.0, -24.0,
				-12.0, 0.0, 0.0, 0.0, 0.0,
			])
		_:
			return PackedFloat32Array([
				0.0, 0.0, 0.0, 0.0, 0.0,
				0.0, 0.0, 0.0, 0.0, 0.0,
			])


static func platform_assembly(assembly_id: String) -> Array[Dictionary]:
	match assembly_id:
		"low_steps":
			return [
				{"x": 78.0, "lift": 62.0, "kind": "small"},
				{"x": 218.0, "lift": 92.0, "kind": "small"},
				{"x": 360.0, "lift": 62.0, "kind": "small"},
			]
		"split_ledges":
			return [
				{"x": 104.0, "lift": 82.0, "kind": "medium"},
				{"x": 338.0, "lift": 112.0, "kind": "small"},
			]
		"bridge_arc":
			return [
				{"x": 80.0, "lift": 66.0, "kind": "small"},
				{"x": 270.0, "lift": 126.0, "kind": "bridge"},
			]
		"staggered":
			return [
				{"x": 82.0, "lift": 58.0, "kind": "small"},
				{"x": 224.0, "lift": 116.0, "kind": "small"},
				{"x": 362.0, "lift": 86.0, "kind": "small"},
			]
		"canopy_rise":
			return [
				{"x": 72.0, "lift": 58.0, "kind": "small"},
				{"x": 200.0, "lift": 116.0, "kind": "small"},
				{"x": 334.0, "lift": 174.0, "kind": "small"},
			]
		"double_deck":
			return [
				{"x": 130.0, "lift": 72.0, "kind": "bridge"},
				{"x": 326.0, "lift": 142.0, "kind": "small"},
			]
		"canopy_fall":
			return [
				{"x": 88.0, "lift": 170.0, "kind": "small"},
				{"x": 222.0, "lift": 112.0, "kind": "small"},
				{"x": 360.0, "lift": 58.0, "kind": "small"},
			]
		"broken_crown":
			return [
				{"x": 72.0, "lift": 66.0, "kind": "small"},
				{"x": 196.0, "lift": 126.0, "kind": "small"},
				{"x": 332.0, "lift": 184.0, "kind": "medium"},
			]
		_:
			return []
