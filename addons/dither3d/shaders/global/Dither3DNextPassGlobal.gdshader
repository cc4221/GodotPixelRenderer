shader_type spatial;
// Unshaded: We use the lighting from the previous pass (captured in screen_texture)
// Depth Draw Never: We don't write depth, the base pass already did
// Depth Test Equal: We only render exactly where the base pass rendered (handling occlusion and cutout automatically)
render_mode unshaded, depth_draw_never, cull_back;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// Disable the built-in screen texture logic from include to avoid conflicts/redundancy
#define DITHER_NO_SCREEN_TEXTURE
#define USE_DITHER_GLOBAL_UNIFORMS
#include "../Dither3DInclude.gdshaderinc"

void fragment() {
	// 1. Read Pass 1 Screen Color (Lit Color)
	// This samples the color buffer which contains the fully lit result of the base material
	vec3 lit_color = texture(screen_texture, SCREEN_UV).rgb;
	
	// 2. Apply Dither
	// We use the mesh's UV for the dither pattern lookup.
	// This ensures "Surface Stability" - the dither pattern is mapped to the object surface
	// and moves/rotates with it, rather than swimming in screen space.
	ALBEDO = get_dither_3d_color(UV, SCREEN_UV, lit_color, PROJECTION_MATRIX, dFdx(UV), dFdy(UV));
}
