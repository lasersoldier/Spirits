shader_type canvas_item;

// 磨砂玻璃效果 Shader
// 使用屏幕纹理实现背景模糊和半透明效果

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 10.0) = 2.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.3);
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

// 高斯模糊采样函数
vec4 gaussian_blur(sampler2D tex, vec2 uv, vec2 pixel_size, float radius) {
	vec4 color = vec4(0.0);
	float total_weight = 0.0;
	
	// 5x5 高斯核
	float weights[25];
	weights[0] = 0.003765; weights[1] = 0.015019; weights[2] = 0.023792; weights[3] = 0.015019; weights[4] = 0.003765;
	weights[5] = 0.015019; weights[6] = 0.059912; weights[7] = 0.094907; weights[8] = 0.059912; weights[9] = 0.015019;
	weights[10] = 0.023792; weights[11] = 0.094907; weights[12] = 0.150342; weights[13] = 0.094907; weights[14] = 0.023792;
	weights[15] = 0.015019; weights[16] = 0.059912; weights[17] = 0.094907; weights[18] = 0.059912; weights[19] = 0.015019;
	weights[20] = 0.003765; weights[21] = 0.015019; weights[22] = 0.023792; weights[23] = 0.015019; weights[24] = 0.003765;
	
	int index = 0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 offset = vec2(float(x), float(y)) * pixel_size * radius;
			vec4 sample_color = texture(tex, uv + offset);
			color += sample_color * weights[index];
			total_weight += weights[index];
			index++;
		}
	}
	
	return color / total_weight;
}

void fragment() {
	// 获取屏幕背景纹理
	vec2 screen_uv = SCREEN_UV;
	
	// 应用高斯模糊
	vec2 pixel_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec4 blurred_bg = gaussian_blur(SCREEN_TEXTURE, screen_uv, pixel_size, blur_amount);
	
	// 调整亮度和饱和度
	vec3 gray = vec3(dot(blurred_bg.rgb, vec3(0.299, 0.587, 0.114)));
	blurred_bg.rgb = mix(gray, blurred_bg.rgb, saturation) * brightness;
	
	// 应用半透明tint
	vec4 final_color = blurred_bg * tint_color;
	
	// 混合原始纹理（如果有）
	vec4 original = texture(TEXTURE, UV);
	final_color = mix(final_color, original, 0.1);
	
	COLOR = final_color;
}

