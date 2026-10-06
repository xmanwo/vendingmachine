extends Node3D

var _last_can: Node = null

@export var can_scene: PackedScene

func spawn_can(spawn_transform: Transform3D, profile: Dictionary) -> void:
	if can_scene == null:
		push_error("Can scene not assigned!")
		return

	# 只保留最新一个罐头
	if _last_can != null and is_instance_valid(_last_can):
		_last_can.queue_free()
		_last_can = null

	var can: Node3D = can_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(can)
	_last_can = can

	can.global_transform = spawn_transform

	# 随机旋转一点
	can.rotate_x(randf_range(-0.05, 0.10))
	can.rotate_y(randf_range(-0.05, 0.10))
	can.rotate_z(randf_range(-0.05, 0.10))

	# 给罐头一个吐出的初速度
	var rb := can as RigidBody3D
	if rb != null:
		rb.linear_velocity = -spawn_transform.basis.z * 1.2 + Vector3.DOWN * 0.1

	_apply_material_recursive(can, profile)

func _apply_material_recursive(node: Node, profile: Dictionary) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			_apply_to_mesh(c as MeshInstance3D, profile)
		_apply_material_recursive(c, profile)

func _apply_to_mesh(mesh: MeshInstance3D, profile: Dictionary) -> void:
	var mat: Material = mesh.get_active_material(0)

	# 如果没有材质，给一个
	if mat == null:
		var fresh: StandardMaterial3D = StandardMaterial3D.new()
		mesh.set_surface_override_material(0, fresh)
		mat = fresh

	# 只处理 StandardMaterial3D
	if mat is StandardMaterial3D:
		# 复制一份，避免多个罐头共用同一材质导致“一起变色/一起变质感”
		var unique: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
		mesh.set_surface_override_material(0, unique)

		# 颜色和发光
		unique.albedo_color = profile["color"]
		unique.emission_enabled = profile["emit"]
		unique.emission = profile["emit_color"]
		unique.emission_energy_multiplier = profile["emit_mul"]

		# 质感参数
		unique.roughness = float(profile.get("rough", 0.5))
		unique.metallic = float(profile.get("metal", 0.0))
		unique.specular = float(profile.get("spec", 0.5))

		# 透明度（alpha < 1 才启用透明）
		var a: float = float(profile.get("alpha", 1.0))
		var c: Color = unique.albedo_color
		c.a = a
		unique.albedo_color = c

		if a < 1.0:
			unique.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			# 透明也写入深度，让贩卖机可以正确遮挡罐子
			unique.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		else:
			# 显式关掉透明 同时 恢复不透明深度模式（防止继承旧状态）
			unique.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			unique.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
