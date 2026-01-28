shader_type sky;

uniform vec4 tint_color : source_color = vec4(0.5, 0.5, 0.5, 0.5);
uniform float exposure : hint_range(0, 8) = 1.0;
uniform float rotation : hint_range(0, 360) = 0.0;

uniform sampler2D source_panorama : source_color, filter_linear, hint_default_black;

// Dither uniforms
#define DITHER_NO_SCREEN_TEXTURE
#define USE_DITHER_GLOBAL_UNIFORMS
#include "../Dither3DInclude.gdshaderinc"

vec3 rotate_around_y_in_degrees(vec3 vertex, float degrees) {
	float alpha = degrees * PI / 180.0;
	float sina = sin(alpha);
	float cosa = cos(alpha);
	mat2 m = mat2(vec2(cosa, -sina), vec2(sina, cosa));
	return vec3((m * vertex.xz).x, vertex.y, (m * vertex.xz).y).xzy;
}

void sky() {
	vec3 dir = EYEDIR;
	dir = rotate_around_y_in_degrees(dir, rotation);
	
	// Standard equirectangular mapping
	vec2 uv = vec2(atan(dir.x, -dir.z) / (2.0 * PI) + 0.5, acos(dir.y) / PI);
	vec3 c = texture(source_panorama, uv).rgb;
	
	c = c * tint_color.rgb * exposure;
	
	// Dithering UV calculation
	float u = atan(-dir.z, dir.x) * 2.0 / PI + 1.0;
	float u2 = atan(dir.z, -dir.x) * 2.0 / PI + 1.0;
	float v = acos(-dir.y) * 2.0 / PI - 1.0;
	
	float a = v * 0.5 * PI;
	v = 0.731746 * log((sin(a) + 1.0) / cos(a));
	
	vec2 uvA = vec2(u, v);
	vec2 uvB = vec2(u2, v);
	
	COLOR = get_dither_3d_color_alt_uv(uvA, uvB, vec2(0.0), c, mat4(1.0), dFdx(uvA), dFdy(uvA), dFdx(uvB), dFdy(uvB));
}
