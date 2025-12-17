extends Node3D

@export var vending_light_path: NodePath = NodePath("../VendingMachine/InternalLight")
@export var rain_particles_path: NodePath = NodePath("RainParticles")
@export var firefly_particles_path: NodePath = NodePath("FireflyParticles")
@export var audio_a_path: NodePath = NodePath("AudioA")
@export var audio_b_path: NodePath = NodePath("AudioB")

@export var sfx_rain: AudioStream
@export var sfx_thunder_amb: AudioStream
@export var sfx_joy_amb: AudioStream
@export var sfx_zen_amb: AudioStream
@export var sfx_glitch_amb: AudioStream

@export var thunder_player_path: NodePath = NodePath("ThunderOneShot")
@export var sfx_thunder_hit: AudioStream

@export var zen_fog_particles_path: NodePath = NodePath("ZenFogParticles")
@export var zen_fog_textures: Array[Texture2D] = []

@export var zen_fog_fade_in: float = 0.5
@export var zen_fog_fade_out: float = 2.0

var _light: OmniLight3D
var _rain: GPUParticles3D
var _firefly: GPUParticles3D

var _zen_fog: GPUParticles3D
var _zen_fog_mat: StandardMaterial3D
var _zen_fog_tw: Tween

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _use_a: bool = true

var _mode: String = "melancholy"
var _t: float = 0.0

var _next_flash: float = 0.0
var _flash_end: float = -1.0

var _thunder: AudioStreamPlayer


func _ready() -> void:
	_light = get_node(vending_light_path) as OmniLight3D
	_rain = get_node(rain_particles_path) as GPUParticles3D
	_firefly = get_node(firefly_particles_path) as GPUParticles3D
	_a = get_node(audio_a_path) as AudioStreamPlayer
	_b = get_node(audio_b_path) as AudioStreamPlayer

	_thunder = get_node_or_null(thunder_player_path) as AudioStreamPlayer

	_zen_fog = get_node_or_null(zen_fog_particles_path) as GPUParticles3D
	if _zen_fog == null:
		_zen_fog = _find_particles_by_name("ZenFogParticles")
		if _zen_fog != null:
			print("READY FIX: ZenFogParticles found by search:", _zen_fog)

	_rain.emitting = false
	_firefly.emitting = false

	# 初始关薄雾 + 正确获取 Draw Pass 材质
	if _zen_fog != null:
		_zen_fog.emitting = false
		_zen_fog.amount_ratio = 0.0

		_zen_fog_mat = _get_particles_drawpass_material(_zen_fog)
		print("READY: ZenFogParticles => ", _zen_fog, " mat=", _zen_fog_mat)
	else:
		print("READY WARNING: ZenFogParticles is NULL. Please set zen_fog_particles_path.")


func _find_particles_by_name(target_name: String) -> GPUParticles3D:
	var root := get_tree().current_scene
	if root == null:
		return null
	var list := root.find_children(target_name, "GPUParticles3D", true, false)
	if list.size() > 0:
		return list[0] as GPUParticles3D
	return null


# 从 draw_pass_1 的 Mesh 上取材质
func _get_particles_drawpass_material(p: GPUParticles3D) -> StandardMaterial3D:
	if p == null:
		return null

	var mesh: Mesh = p.draw_pass_1
	if mesh == null:
		push_warning("ZenFogParticles has no draw_pass_1 mesh. Set Drawing -> Draw Pass 1 Mesh (QuadMesh).")
		return null

	if mesh.get_surface_count() <= 0:
		push_warning("ZenFogParticles draw_pass_1 mesh has no surfaces.")
		return null

	var mat: Material = mesh.surface_get_material(0)
	if mat == null:
		push_warning("ZenFogParticles draw_pass_1 surface material is null. Assign a StandardMaterial3D to QuadMesh surface 0.")
		return null

	if mat is StandardMaterial3D:
		return mat as StandardMaterial3D

	push_warning("ZenFogParticles material is not StandardMaterial3D. Current: " + str(mat))
	return null


func set_mode(mode: String) -> void:
	print("set_mode called:", mode)
	_mode = mode
	_t = 0.0

	if _thunder != null and _thunder.playing:
		_thunder.stop()

	_rain.emitting = false
	_firefly.emitting = false

	if mode != "zen":
		_fade_out_zen_fog()

	_light.light_energy = 1.0

	match mode:
		"melancholy":
			_light.light_color = Color("#0033CC")
			_rain.emitting = true
			_crossfade_to(sfx_rain)

		"anger":
			_light.light_color = Color("#FF0000")
			_light.light_energy = 0.6
			_next_flash = randf_range(3.0, 5.0)
			_flash_end = -1.0
			_crossfade_to(sfx_thunder_amb)

		"joy":
			_light.light_color = Color("#FFAA00")
			_firefly.emitting = true
			_crossfade_to(sfx_joy_amb)

		"zen":
			_light.light_color = Color("#00FFAA")
			_light.light_energy = 1.2
			_fade_in_zen_fog()
			_crossfade_to(sfx_zen_amb)

		"glitch":
			_light.light_color = Color("#AA00FF")
			_crossfade_to(sfx_glitch_amb)

		_:
			_crossfade_to(null)


func _process(delta: float) -> void:
	_t += delta

	if _mode == "joy":
		_light.light_energy = 2.5 + sin(_t * 2.0) * 0.5

	elif _mode == "anger":
		_next_flash -= delta
		if _flash_end > 0.0:
			_flash_end -= delta
			if _flash_end <= 0.0:
				_light.light_energy = 0.6
		else:
			if _next_flash <= 0.0:
				_light.light_energy = 10.0
				_play_thunder_hit()
				_flash_end = 0.1
				_next_flash = randf_range(3.0, 5.0)

	elif _mode == "glitch":
		if int(_t / 0.05) != int((_t - delta) / 0.05):
			_light.light_energy = 5.0 if randf() > 0.5 else 0.0


func _crossfade_to(stream: AudioStream) -> void:
	var from_player: AudioStreamPlayer = _a if _use_a else _b
	var to_player: AudioStreamPlayer = _b if _use_a else _a
	_use_a = not _use_a

	to_player.stop()
	to_player.stream = stream
	if stream != null:
		to_player.volume_db = -80.0
		to_player.play()

	var tw := create_tween()
	tw.tween_property(from_player, "volume_db", -80.0, 2.0)
	if stream != null:
		tw.tween_property(to_player, "volume_db", -10.0, 2.0)

	tw.finished.connect(func():
		from_player.stop()
	)


func _play_thunder_hit() -> void:
	if sfx_thunder_hit == null:
		return
	if _thunder == null:
		return
	_thunder.stop()
	_thunder.stream = sfx_thunder_hit
	_thunder.volume_db = -6.0
	_thunder.play()


func _randomize_zen_fog_texture() -> void:
	if _zen_fog_mat == null:
		if _zen_fog != null:
			_zen_fog_mat = _get_particles_drawpass_material(_zen_fog)
		if _zen_fog_mat == null:
			print("ZEN: _zen_fog_mat is NULL (check QuadMesh surface material).")
			return

	if zen_fog_textures.is_empty():
		print("ZEN: zen_fog_textures is empty.")
		return

	var tex: Texture2D = zen_fog_textures[randi() % zen_fog_textures.size()]
	_zen_fog_mat.albedo_texture = tex


func _fade_in_zen_fog() -> void:
	if _zen_fog == null:
		print("ZEN: _zen_fog is NULL (path wrong).")
		return

	if _zen_fog_tw != null and _zen_fog_tw.is_valid():
		_zen_fog_tw.kill()

	_randomize_zen_fog_texture()

	_zen_fog.emitting = true
	_zen_fog.amount_ratio = 0.0

	_zen_fog_tw = create_tween()
	_zen_fog_tw.tween_property(_zen_fog, "amount_ratio", 1.0, zen_fog_fade_in)


func _fade_out_zen_fog() -> void:
	if _zen_fog == null:
		return

	if _zen_fog_tw != null and _zen_fog_tw.is_valid():
		_zen_fog_tw.kill()

	_zen_fog_tw = create_tween()
	_zen_fog_tw.tween_property(_zen_fog, "amount_ratio", 0.0, zen_fog_fade_out)
	_zen_fog_tw.finished.connect(func():
		_zen_fog.emitting = false
	)
