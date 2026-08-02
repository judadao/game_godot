extends Node2D

const CAPTURE_PATH_ENV := "PRIEST_ANIMATION_CAPTURE_PATH"
const CAPTURE_FRAME_ENV := "PRIEST_ANIMATION_CAPTURE_FRAME"

@onready var previews: Array[Node] = [
	$FrontIdle,
	$FrontChat,
	$SideWalk,
	$SideChat,
]


func _ready() -> void:
	if OS.has_environment(CAPTURE_FRAME_ENV):
		var requested_frame := int(OS.get_environment(CAPTURE_FRAME_ENV))
		for preview in previews:
			preview.call("set_frame_for_review", requested_frame)
	if OS.has_environment(CAPTURE_PATH_ENV) and get_viewport() == get_tree().root:
		call_deferred("_capture_preview")


func _capture_preview() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var path := OS.get_environment(CAPTURE_PATH_ENV).strip_edges()
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Failed to save priest animation preview to %s." % path)
	get_tree().quit(0 if error == OK else 1)
