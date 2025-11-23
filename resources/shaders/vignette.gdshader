shader_type canvas_item;

// 径向渐变暗角效果
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float radius : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv_offset = UV - center;
	float dist = length(uv_offset);
	
	// 计算暗角强度（距离中心越远，越暗）
	float vignette = smoothstep(radius, 1.0, dist);
	
	// 应用暗角
	vec4 color = texture(TEXTURE, UV);
	color.rgb *= (1.0 - vignette * intensity);
	
	COLOR = color;
}


