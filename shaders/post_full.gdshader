shader_type canvas_item;
// Post-traitement léger (qualité Moyenne/Haute) : aberration chromatique, étalonnage froid,
// vignette, grain de pellicule, flash rouge de peur. Une seule lecture d'écran.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette_strength = 0.55;
uniform float grain_amount = 0.04;
uniform float aberration = 0.0015;
uniform float fear = 0.0;
uniform float red_flash = 0.0;
uniform float desaturate = 0.22;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float ab = aberration + fear * 0.0035;
	vec3 col;
	col.r = texture(screen_tex, uv + d * ab).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - d * ab).b;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), desaturate + fear * 0.25);
	col *= vec3(0.96, 0.99, 1.05);
	float v = smoothstep(0.9, 0.2, length(d * vec2(1.0, 0.85)) * (1.0 + fear * 0.4));
	col *= mix(1.0 - vignette_strength, 1.0, v);
	float g = hash(uv * vec2(1280.0, 720.0) + fract(TIME * 7.13) * 91.7) - 0.5;
	col += g * grain_amount;
	col = mix(col, vec3(0.45, 0.0, 0.0), clamp(red_flash, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
