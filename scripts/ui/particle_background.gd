class_name ParticleBackground
extends Control

# 粒子定义
class Particle:
	var position: Vector2
	var velocity: Vector2
	var size: float
	var color: Color
	var life: float
	var max_life: float
	
	func _init(pos: Vector2, vel: Vector2, s: float, c: Color, ml: float):
		position = pos
		velocity = vel
		size = s
		color = c
		life = 0.0
		max_life = ml

var particles: Array[Particle] = []
var particle_count: int = 100

# 粒子颜色（对应 TSX 中的颜色）
var colors: Array[Color] = [
	Color(1.0, 0.5, 0.0, 0.6),  # Fire - rgba(255, 128, 0, 0.6)
	Color(0.0, 0.5, 1.0, 0.6),  # Water - rgba(0, 128, 255, 0.6)
	Color(0.5, 0.8, 1.0, 0.6),  # Wind - rgba(128, 204, 255, 0.6)
	Color(1.0, 0.85, 0.2, 0.4)  # Gold Energy - rgba(255, 217, 51, 0.4)
]

func _ready():
	# 确保在绘制时更新
	set_process(true)
	
	# 初始化粒子
	_initialize_particles()

func _initialize_particles():
	particles.clear()
	await get_tree().process_frame  # 等待一帧确保视口已初始化
	var canvas_size = size
	if canvas_size.x == 0 or canvas_size.y == 0:
		canvas_size = get_viewport().get_visible_rect().size
	if canvas_size.x == 0 or canvas_size.y == 0:
		canvas_size = Vector2(1920, 1080)  # 默认大小
	
	for i in range(particle_count):
		var pos = Vector2(
			randf() * canvas_size.x,
			randf() * canvas_size.y
		)
		var vel = Vector2(
			(randf() - 0.5) * 0.5,
			(randf() - 0.5) * 0.5 - 0.2  # 轻微向上漂移
		)
		var particle_size = randf() * 3.0 + 1.0
		var color = colors[randi() % colors.size()]
		var max_life = randf() * 200.0 + 100.0
		
		particles.append(Particle.new(pos, vel, particle_size, color, max_life))

func _process(_delta):
	queue_redraw()

func _draw():
	var draw_size = size
	if draw_size.x == 0 or draw_size.y == 0:
		draw_size = get_viewport().get_visible_rect().size
	if draw_size.x == 0 or draw_size.y == 0:
		draw_size = Vector2(1920, 1080)  # 默认大小
	
	# 绘制深色背景
	draw_rect(Rect2(0, 0, draw_size.x, draw_size.y), Color(0.06, 0.07, 0.10, 1.0))  # #0f1219
	
	# 绘制径向渐变叠加层
	var center = Vector2(draw_size.x / 2, draw_size.y)
	var gradient_radius = draw_size.length()
	# 使用多个圆形来模拟渐变效果
	for i in range(20):
		var radius = gradient_radius * (i / 20.0)
		var alpha = 0.4 * (1.0 - i / 20.0)
		draw_circle(center, radius, Color(0.08, 0.12, 0.24, alpha))
	
	# 更新并绘制粒子
	for i in range(particles.size()):
		var p = particles[i]
		
		# 更新位置
		p.position += p.velocity
		p.life += 1.0
		
		# 重置超出边界或生命结束的粒子
		if p.life > p.max_life or p.position.x < 0 or p.position.x > draw_size.x or p.position.y < 0 or p.position.y > draw_size.y:
			p.position = Vector2(
				randf() * draw_size.x,
				randf() * draw_size.y
			)
			p.velocity = Vector2(
				(randf() - 0.5) * 0.5,
				(randf() - 0.5) * 0.5 - 0.2
			)
			p.life = 0.0
			p.max_life = randf() * 200.0 + 100.0
			p.color = colors[randi() % colors.size()]
			p.size = randf() * 3.0 + 1.0
		
		# 绘制粒子
		draw_circle(p.position, p.size, p.color)

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		# 窗口大小改变时重新初始化粒子
		_initialize_particles()
