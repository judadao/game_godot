class_name AutumnRouteCatalog
extends RefCounted

const FLOOR_PROFILE_ORDER: Array[String] = [
	"level",
	"grand_hill",
	"grand_basin",
	"high_plateau",
	"rolling",
	"double_ridge",
	"broken_steps",
	"long_climb",
	"long_descent",
	"high_terrace",
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
		"grand_hill":
			return PackedFloat32Array([
				0.0, -24.0, -48.0, -72.0, -96.0,
				-96.0, -72.0, -48.0, -24.0, 0.0,
			])
		"grand_basin":
			return PackedFloat32Array([
				0.0, 12.0, 24.0, 36.0, 48.0,
				48.0, 36.0, 24.0, 12.0, 0.0,
			])
		"high_plateau":
			return PackedFloat32Array([
				0.0, -20.0, -40.0, -64.0, -64.0,
				-64.0, -64.0, -40.0, -20.0, 0.0,
			])
		"rolling":
			return PackedFloat32Array([
				0.0, -16.0, -32.0, -16.0, 0.0,
				16.0, 32.0, 16.0, 0.0, 0.0,
			])
		"double_ridge":
			return PackedFloat32Array([
				0.0, -24.0, -48.0, -24.0, 0.0,
				-24.0, -48.0, -24.0, 0.0, 0.0,
			])
		"broken_steps":
			return PackedFloat32Array([
				0.0, -16.0, -16.0, -32.0, -32.0,
				-48.0, -48.0, -24.0, -24.0, 0.0,
			])
		"long_climb":
			return PackedFloat32Array([
				0.0, -12.0, -24.0, -36.0, -48.0,
				-60.0, -72.0, -84.0, -96.0, -96.0,
			])
		"long_descent":
			return PackedFloat32Array([
				0.0, 12.0, 24.0, 36.0, 48.0,
				60.0, 72.0, 84.0, 96.0, 96.0,
			])
		"high_terrace":
			return PackedFloat32Array([
				0.0, -16.0, -32.0, -48.0, -64.0,
				-64.0, -64.0, -64.0, -64.0, -64.0,
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
