extends Node3D

# 显式类型，避免 Variant 推断警告
const PROFILES: Dictionary = {
	"melancholy": {
		"color": Color("#0033CC"),
		"emit": false, "emit_color": Color("#0033CC"), "emit_mul": 0.0,
		"rough": 0.65, "metal": 0.20, "spec": 0.5, "alpha": 1.0
	},
	"anger": {
		"color": Color("#FF0000"),
		"emit": true,  "emit_color": Color("#FF0000"), "emit_mul": 0.6,
		"rough": 0.35, "metal": 0.25, "spec": 0.6, "alpha": 1.0
	},
	"joy": {
		"color": Color("#FFAA00"),
		"emit": true,  "emit_color": Color("#FFAA00"), "emit_mul": 3.0,
		"rough": 0.20, "metal": 0.85, "spec": 0.7, "alpha": 1.0
	},
	"zen": {
		"color": Color("#00FFAA"),
		"emit": false, "emit_color": Color("#00FFAA"), "emit_mul": 0.0,
		"rough": 0.92, "metal": 0.05, "spec": 0.3, "alpha": 1.0
	},
	"glitch": {
		"color": Color("#AA00FF"),
		"emit": true,  "emit_color": Color("#AA00FF"), "emit_mul": 1.2,
		"rough": 0.45, "metal": 0.30, "spec": 0.6, "alpha": 0.95
	},
}

@onready var vending_machine: Node = $VendingMachine
@onready var can_factory: Node = $CanFactory
@onready var env_mgr: Node = $EnvironmentManager

# 机器是否进入故障锁定
var _machine_locked: bool = false

func _ready() -> void:
	var buttons: Node = vending_machine.get_node("Buttons")
	for b in buttons.get_children():
		if b.has_signal("pressed"):
			b.pressed.connect(_on_button_pressed)

func _on_button_pressed(emotion_id: String) -> void:
	# 故障状态后，所有按钮无效
	if _machine_locked:
		print("Vending machine locked. Ignored:", emotion_id)
		return

	# 按下 glitch 后立刻锁死（但这次仍会正常触发吐罐/切环境）
	if emotion_id == "glitch":
		_machine_locked = true

	var spawn: Marker3D = vending_machine.get_node("DispenserSpawn") as Marker3D
	var profile: Dictionary = PROFILES.get(emotion_id, PROFILES["melancholy"]) as Dictionary
	(can_factory as Node).call("spawn_can", spawn.global_transform, profile)
	(env_mgr as Node).call("set_mode", emotion_id)
