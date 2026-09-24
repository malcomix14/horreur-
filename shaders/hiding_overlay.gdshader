shader_type canvas_item;
// Vue depuis une cachette : persiennes d'armoire (mode 0) ou dessous de lit (mode 1).

uniform float mode = 0.0;
uniform float opacity = 1.0;

void fragment() {
	vec2 uv = UV;
	float a = 0.0;
	if (mode < 0.5) {
		float region = step(0.18, uv.x) * step(uv.x, 0.82) * step(0.12, uv.y) * step(uv.y, 0.88);
		float slat = smoothstep(0.30, 0.42, fract(uv.y * 11.0)) * (1.0 - smoothstep(0.78, 0.9, fract(uv.y * 11.0)));
		float gap = 1.0 - slat;
		a = mix(0.97, gap * 0.92, region);
		float center = abs(uv.x - 0.5);
		a = max(a, smoothstep(0.015, 0.0, center) * 0.9);
	} else {
		float top = smoothstep(0.46, 0.36, uv.y);
		float bottom = smoothstep(0.86, 0.95, uv.y) * 0.6;
		a = max(top * 0.97, bottom);
		a = max(a, smoothstep(0.35, 0.5, abs(uv.x - 0.5)) * 0.8);
	}
	vec2 d = uv - 0.5;
	a = max(a, smoothstep(0.35, 0.75, length(d)) * 0.85);
	COLOR = vec4(0.0, 0.0, 0.0, a * opacity);
}
