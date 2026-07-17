shader_type canvas_item;

// Screen-space (pixel) position of the transparent hole's center. Updated
// every frame by cave_darkness_overlay.gd to track the player on screen.
uniform vec2 light_center = vec2(576.0, 324.0);

// Distance (in pixels) from light_center. Fully see-through out to
// inner_radius, then fades to dark_color by outer_radius, staying fully
// dark beyond that.
uniform float inner_radius : hint_range(0.0, 2000.0) = 120.0;
uniform float outer_radius : hint_range(0.0, 2000.0) = 340.0;

uniform vec4 dark_color : source_color = vec4(0.0, 0.0, 0.0, 0.92);

void fragment() {
	float dist = distance(FRAGCOORD.xy, light_center);
	float darkness = smoothstep(inner_radius, outer_radius, dist);
	COLOR = vec4(dark_color.rgb, dark_color.a * darkness);
}
