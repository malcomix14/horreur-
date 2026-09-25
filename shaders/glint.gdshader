shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Reflet pulsant des objets utiles (clés, fusible, piles, documents non lus) :
// petit éclat en croix toujours tourné vers la caméra. Aucun calcul d'éclairage.

uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform float strength = 0.9;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	float core = exp(-r * r * 14.0);
	float rays = exp(-abs(d.x) * 60.0) * exp(-abs(d.y) * 5.0) + exp(-abs(d.y) * 60.0) * exp(-abs(d.x) * 5.0);
	float phase = dot(NODE_POSITION_WORLD, vec3(1.7, 3.1, 2.3));
	float pulse = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(TIME * 2.2 + phase), 3.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp((core * 0.75 + rays * 0.55) * pulse * strength, 0.0, 1.0);
}
