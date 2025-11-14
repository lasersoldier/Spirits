class_name ModelGenerator
extends RefCounted

# 生成六棱柱地形模型
static func create_hex_terrain_mesh(size: float = 1.5, height: float = 0.3) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# 生成六边形顶点（底面）
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# 六边形顶点（在XZ平面，平顶六边形，从右边开始）
	# 平顶六边形让顶点坐标更直观，顶点指向轴向坐标方向
	# 顶点从0度开始（右边），每60度一个，形成平顶六边形
	for i in range(6):
		var angle = i * PI / 3.0  # 从0度（右边）开始
		var x = size * cos(angle)
		var z = size * sin(angle)
		vertices.append(Vector3(x, 0, z))
		vertices.append(Vector3(x, height, z))
	
	# 添加中心点
	vertices.append(Vector3(0, 0, 0))
	vertices.append(Vector3(0, height, 0))
	
	# 生成索引（底面、顶面、侧面）
	var center_bottom = vertices.size() - 2
	var center_top = vertices.size() - 1
	
	# 底面
	for i in range(6):
		indices.append(center_bottom)
		indices.append(i * 2)
		indices.append((i * 2 + 2) % 12)
	
	# 顶面
	for i in range(6):
		indices.append(center_top)
		indices.append((i * 2 + 3) % 12 + 1)
		indices.append(i * 2 + 1)
	
	# 侧面
	for i in range(6):
		var next_i = (i + 1) % 6
		# 第一个三角形
		indices.append(i * 2)
		indices.append(i * 2 + 1)
		indices.append(next_i * 2)
		# 第二个三角形
		indices.append(i * 2 + 1)
		indices.append(next_i * 2 + 1)
		indices.append(next_i * 2)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# 生成精灵占位符模型（立方体+球体）
static func create_sprite_mesh_fire() -> ArrayMesh:
	# 简化版：使用立方体
	return create_box_mesh(0.4, 0.8, 0.4)

# 生成精灵占位符模型（鸟形）
static func create_sprite_mesh_wind() -> ArrayMesh:
	# 简化版：使用扁长方体
	return create_box_mesh(0.5, 0.3, 0.7)

# 生成精灵占位符模型（水滴）
static func create_sprite_mesh_water() -> ArrayMesh:
	# 简化版：使用球体（用多面体近似）
	return create_sphere_mesh(0.3, 8)

# 生成精灵占位符模型（立方体）
static func create_sprite_mesh_rock() -> ArrayMesh:
	return create_box_mesh(0.5, 0.9, 0.5)

# 生成立方体网格
static func create_box_mesh(width: float, height: float, depth: float) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var w = width / 2.0
	var h = height / 2.0
	var d = depth / 2.0
	
	var vertices = PackedVector3Array([
		# 前面
		Vector3(-w, -h, d), Vector3(w, -h, d), Vector3(w, h, d), Vector3(-w, h, d),
		# 后面
		Vector3(w, -h, -d), Vector3(-w, -h, -d), Vector3(-w, h, -d), Vector3(w, h, -d),
		# 左面
		Vector3(-w, -h, -d), Vector3(-w, -h, d), Vector3(-w, h, d), Vector3(-w, h, -d),
		# 右面
		Vector3(w, -h, d), Vector3(w, -h, -d), Vector3(w, h, -d), Vector3(w, h, d),
		# 上面
		Vector3(-w, h, d), Vector3(w, h, d), Vector3(w, h, -d), Vector3(-w, h, -d),
		# 下面
		Vector3(-w, -h, -d), Vector3(w, -h, -d), Vector3(w, -h, d), Vector3(-w, -h, d)
	])
	
	var indices = PackedInt32Array([
		0, 1, 2, 0, 2, 3,  # 前面
		4, 5, 6, 4, 6, 7,  # 后面
		8, 9, 10, 8, 10, 11,  # 左面
		12, 13, 14, 12, 14, 15,  # 右面
		16, 17, 18, 16, 18, 19,  # 上面
		20, 21, 22, 20, 22, 23   # 下面
	])
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# 生成球体网格（简化版）
static func create_sphere_mesh(radius: float, segments: int = 8) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# 生成顶点
	for i in range(segments + 1):
		var theta = i * PI / segments
		for j in range(segments):
			var phi = j * 2 * PI / segments
			var x = radius * sin(theta) * cos(phi)
			var y = radius * cos(theta)
			var z = radius * sin(theta) * sin(phi)
			vertices.append(Vector3(x, y, z))
	
	# 生成索引
	for i in range(segments):
		for j in range(segments):
			var current = i * segments + j
			var next = i * segments + (j + 1) % segments
			var below = (i + 1) * segments + j
			var below_next = (i + 1) * segments + (j + 1) % segments
			
			indices.append(current)
			indices.append(below)
			indices.append(next)
			
			indices.append(next)
			indices.append(below)
			indices.append(below_next)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# 生成赏金晶体模型（六棱柱）
static func create_bounty_crystal_mesh() -> ArrayMesh:
	return create_hex_terrain_mesh(0.3, 0.5)

# 生成争夺点标识模型（三棱柱）
static func create_contest_point_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var size = 0.2
	var height = 0.4
	
	var vertices = PackedVector3Array([
		# 底面三角形
		Vector3(0, 0, size),
		Vector3(size * cos(PI / 3), 0, -size * sin(PI / 3)),
		Vector3(-size * cos(PI / 3), 0, -size * sin(PI / 3)),
		# 顶面三角形
		Vector3(0, height, size),
		Vector3(size * cos(PI / 3), height, -size * sin(PI / 3)),
		Vector3(-size * cos(PI / 3), height, -size * sin(PI / 3))
	])
	
	var indices = PackedInt32Array([
		0, 1, 2,  # 底面
		3, 5, 4,  # 顶面
		0, 3, 4, 0, 4, 1,  # 侧面1
		1, 4, 5, 1, 5, 2,  # 侧面2
		2, 5, 3, 2, 3, 0   # 侧面3
	])
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

