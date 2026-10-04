shader_type canvas_item;
// Full-screen cover of Flow's scene transitions (scripts/core/transition_cover.gd). Owner: core.
//
// Everything outside the "opening" takes the ColorRect's colour; the opening itself stays transparent.
// Distances are whole pixels of the rectangle, so the edge stays crisp at the base resolution.

// Defs.Transition: 1 = fade, 2 = curtain, 3 = iris.
uniform int shape = 1;
// 0 = nothing covered, 1 = everything covered. Only the fade reads it directly.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// Size of the rectangle in px.
uniform vec2 rect_size = vec2(640.0, 360.0);
// Centre of the iris / the column where the two curtain panels meet, in px.
uniform vec2 focus = vec2(320.0, 180.0);
// Curtain: half width of the gap between the panels. Iris: radius of the hole. In px.
uniform float opening = 0.0;

void fragment() {
	vec2 at = floor(UV * rect_size) + vec2(0.5);
	float cover = amount;
	if (shape == 2) {
		cover = step(opening, abs(at.x - focus.x));
	} else if (shape == 3) {
		cover = step(opening, distance(at, focus));
	}
	COLOR = vec4(COLOR.rgb, COLOR.a * cover);
}
