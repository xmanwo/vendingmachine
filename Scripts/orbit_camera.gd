extends Node3D

@export var camera_path: NodePath = NodePath("Camera3D")

# 在 Inspector 里拖一个节点进来当限制中心（VendingMachine 或 Marker3D）
@export var limit_center_path: NodePath = NodePath("../VendingMachine")

@export var rotate_speed: float = 0.01
@export var zoom_speed: float = 0.8
@export var min_distance: float = 1.5
@export var max_distance: float = 6.0

@export var move_speed: float = 2.5
@export var sprint_mul: float = 2.0

# 盒子范围（相对中心点的偏移范围）
@export var min_x: float = -1.0
@export var max_x: float =  1.0
@export var min_z: float =  0.7
@export var max_z: float =  1.2
@export var min_y: float =  0.5
@export var max_y: float =  1.5

var _cam: Camera3D
var _center: Node3D

var _distance: float = 3.0
var _yaw: float = 0.0
var _pitch: float = -0.2
var _dragging: bool = false

func _ready() -> void:
	_cam = get_node(camera_path) as Camera3D
	_distance = _cam.transform.origin.length()

	_center = get_node_or_null(limit_center_path) as Node3D
	if _center == null:
		push_warning("Limit center not found. Movement won't be clamped.")

	_update_camera()

func _process(delta: float) -> void:
	# WASD：按 Pivot 当前水平朝向移动（跟随 yaw）
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir += forward
	if Input.is_key_pressed(KEY_S): dir -= forward
	if Input.is_key_pressed(KEY_D): dir += right
	if Input.is_key_pressed(KEY_A): dir -= right
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir += Vector3.DOWN

	if dir != Vector3.ZERO:
		var spd := move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			spd *= sprint_mul

		global_position += dir.normalized() * spd * delta
		_clamp_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_distance = max(min_distance, _distance - zoom_speed)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_distance = min(max_distance, _distance + zoom_speed)
			_update_camera()

	if event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * rotate_speed
		_pitch -= event.relative.y * rotate_speed
		_pitch = clamp(_pitch, -1.2, 0.2)
		_update_camera()

func _update_camera() -> void:
	rotation.y = _yaw
	rotation.x = _pitch
	_cam.transform.origin = Vector3(0, 0, _distance)
	_cam.look_at(global_transform.origin, Vector3.UP)

func _clamp_position() -> void:
	if _center == null:
		return

	var p := global_position
	var c := _center.global_position

	# 以中心点为参考做盒子限制（相对中心的偏移）
	var dx := p.x - c.x
	var dy := p.y - c.y
	var dz := p.z - c.z

	dx = clamp(dx, min_x, max_x)
	dy = clamp(dy, min_y, max_y)
	dz = clamp(dz, min_z, max_z)

	global_position = Vector3(c.x + dx, c.y + dy, c.z + dz)
