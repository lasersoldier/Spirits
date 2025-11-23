shader_type canvas_item;

// 灰度 Shader - 用于未拥有的卡牌
uniform float grayscale_amount : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 0.6;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	
	// 转换为灰度
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grayscale = vec3(gray);
	
	// 混合原色和灰度
	vec3 final_color = mix(color.rgb, grayscale, grayscale_amount);
	
	// 调整亮度
	final_color *= brightness;
	
	COLOR = vec4(final_color, color.a);
}


