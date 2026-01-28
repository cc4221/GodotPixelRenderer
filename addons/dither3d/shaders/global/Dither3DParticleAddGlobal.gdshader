shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color;
uniform float proximity_fade_distance = 1.0;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

#define USE_DITHER_GLOBAL_UNIFORMS
#include "../Dither3DInclude.gdshaderinc"

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	vec4 col = albedo * albedo_tex * COLOR; // COLOR comes from vertex color (particle color)
	
	// Apply Dither
	vec3 dithered_col = get_dither_3d_color(UV, SCREEN_UV, col.rgb, PROJECTION_MATRIX, dFdx(UV), dFdy(UV));
	
	ALBEDO = dithered_col;
	ALPHA = col.a;
}
