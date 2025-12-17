extends Node3D

signal pressed(emotion_id: String)

@export var emotion_id: String = "melancholy"
@export var area_path: NodePath = NodePath("Area3D")

func _ready() -> void:
	var area := get_node_or_null(area_path) as Area3D
	if area == null:
		push_error("Area3D not found on " + name)
		return

	area.input_event.connect(_on_area_input_event)

func _on_area_input_event(_camera, event, _pos, _normal, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(emotion_id)
