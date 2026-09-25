shader_type canvas_item;
// Post-traitement « PC faible » : aucune lecture d'écran, simple voile (vignette + grain).

uniform float vignette_strength = 0.36;
uniform float grain_amount = 0.03;
uniform float fear = 0.0;
uniform float red_flash = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 d = UV - 0.5;
	float v = smoothstep(0.9, 0.2, length(d * vec2(1.0, 0.85)) * (1.0 + fear * 0.4));
	float a = (1.0 - v) * vignette_strength;
	float g = hash(UV * vec2(640.0, 360.0) + fract(TIME * 7.13) * 91.7);
	a += g * grain_amount;
	vec3 c = mix(vec3(0.0), vec3(0.45, 0.0, 0.0), clamp(red_flash, 0.0, 1.0));
	COLOR = vec4(c, clamp(a + red_flash * 0.6, 0.0, 1.0));
}
