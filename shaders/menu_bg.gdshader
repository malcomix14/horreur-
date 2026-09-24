shader_type canvas_item;
// Fond animé du menu : brume sombre, fenêtre lointaine et éclairs.

uniform float flash = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.03;
	float n = noise(uv * 3.0 + vec2(t, t * 0.5)) * 0.5 + noise(uv * 7.0 - vec2(t * 1.7, 0.0)) * 0.25;
	vec3 col = mix(vec3(0.01, 0.008, 0.012), vec3(0.06, 0.05, 0.07), n * (1.0 - uv.y * 0.6));
	vec2 w = uv - vec2(0.74, 0.4);
	float win = step(abs(w.x), 0.07) * step(abs(w.y), 0.12);
	float bars = step(0.006, abs(w.x)) * step(0.006, abs(w.y + 0.02));
	col += vec3(0.08, 0.1, 0.16) * win * bars * (0.6 + flash * 3.0);
	col += vec3(0.25, 0.28, 0.35) * flash * (1.0 - uv.y) * 0.4;
	float v = smoothstep(0.95, 0.3, length((uv - 0.5) * vec2(1.2, 1.0)));
	col *= v;
	float g = hash(uv * 900.0 + fract(TIME) * 50.0) - 0.5;
	col += g * 0.025;
	COLOR = vec4(col, 1.0);
}
