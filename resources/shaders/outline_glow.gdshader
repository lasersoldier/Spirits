shader_type canvas_item;

// 外发光呼吸效果 Shader
// 用于选中卡牌、按钮悬停时的发光边框

uniform vec4 glow_color : source_color = vec4(1.0, 0.65, 0.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float glow_width : hint_range(0.0, 20.0) = 5.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_max : hint_range(0.0, 2.0) = 1.5;

// 计算距离边缘的距离
float edge_distance(vec2 uv, vec2 size) {
	vec2 pixel_size = 1.0 / size;
	vec2 edge_dist = min(uv, 1.0 - uv) * size;
	return min(edge_dist.x, edge_dist.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	
	// 计算到边缘的距离
	float dist = edge_distance(uv, size);
	
	// 呼吸动画
	float time = TIME * pulse_speed;
	float pulse = pulse_min + (pulse_max - pulse_min) * (sin(time) * 0.5 + 0.5);
	
	// 计算发光强度（距离边缘越近，发光越强）
	float glow_strength = 1.0 - smoothstep(0.0, glow_width * pulse, dist);
	
	// 获取原始纹理颜色
	vec4 tex_color = texture(TEXTURE, uv);
	
	// 应用发光
	vec4 glow = glow_color * glow_strength * glow_intensity * pulse;
	
	// 混合原始颜色和发光
	COLOR = tex_color + glow;
	COLOR.a = max(tex_color.a, glow.a * glow_strength);
}

