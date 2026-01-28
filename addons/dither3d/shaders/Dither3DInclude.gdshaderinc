// Dither3DInclude.gdshaderinc

#ifndef DITHER_NO_SCREEN_TEXTURE
uniform bool inherit_albedo = false;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
#endif

// Uniforms
#ifdef USE_DITHER_GLOBAL_UNIFORMS

	// Global Uniforms (must be registered in Project Settings)
	global uniform float dither_input_exposure;
	global uniform float dither_input_offset;
	
	global uniform int dither_mode;
	global uniform sampler3D dither_tex; // Global textures
	global uniform sampler2D dither_ramp_tex;
	global uniform float dither_dot_scale;
	global uniform float dither_size_variability;
	global uniform float dither_contrast;
	global uniform float dither_stretch_smoothness;
	global uniform bool dither_inverse_dots;
	global uniform bool dither_radial_compensation;
	global uniform bool dither_quantize_layers;
	global uniform bool dither_debug_fractal;

	// Macros to map internal names to global uniforms
	#define u_input_exposure dither_input_exposure
	#define u_input_offset dither_input_offset
	#define u_dither_mode dither_mode
	#define u_dither_tex dither_tex
	#define u_dither_ramp_tex dither_ramp_tex
	#define u_dot_scale dither_dot_scale
	#define u_size_variability dither_size_variability
	#define u_contrast dither_contrast
	#define u_stretch_smoothness dither_stretch_smoothness
	#define u_inverse_dots dither_inverse_dots
	#define u_radial_compensation dither_radial_compensation
	#define u_quantize_layers dither_quantize_layers
	#define u_debug_fractal dither_debug_fractal

#else

	// Local Uniforms (Fallback)
	group_uniforms Dither_Input_Brightness;
	uniform float input_exposure : hint_range(0, 5) = 1.0;
	uniform float input_offset : hint_range(-1, 1) = 0.0;

	group_uniforms Dither_Settings;
	uniform int dither_mode : hint_range(0, 2) = 1; // 0=Grayscale, 1=RGB, 2=CMYK
	uniform sampler3D dither_tex;
	uniform sampler2D dither_ramp_tex;
	uniform float dot_scale : hint_range(2, 10) = 5.0;
	uniform float size_variability : hint_range(0, 1) = 0.0;
	uniform float contrast : hint_range(0, 2) = 1.0;
	uniform float stretch_smoothness : hint_range(0, 2) = 1.0;
	uniform bool inverse_dots = false;
	uniform bool radial_compensation = false;
	uniform bool quantize_layers = false;
	uniform bool debug_fractal = false;

	// Macros to map internal names to local uniforms
	#define u_input_exposure input_exposure
	#define u_input_offset input_offset
	#define u_dither_mode dither_mode
	#define u_dither_tex dither_tex
	#define u_dither_ramp_tex dither_ramp_tex
	#define u_dot_scale dot_scale
	#define u_size_variability size_variability
	#define u_contrast contrast
	#define u_stretch_smoothness stretch_smoothness
	#define u_inverse_dots inverse_dots
	#define u_radial_compensation radial_compensation
	#define u_quantize_layers quantize_layers
	#define u_debug_fractal debug_fractal

#endif



// Helper functions
float get_grayscale(vec3 color) {
	return clamp(0.299 * color.r + 0.587 * color.g + 0.114 * color.b, 0.0, 1.0);
}

vec3 cmyk_to_rgb(vec4 cmyk) {
	float c = cmyk.x;
	float m = cmyk.y;
	float y = cmyk.z;
	float k = cmyk.w;
	float invK = 1.0 - k;
	float r = 1.0 - min(1.0, c * invK + k);
	float g = 1.0 - min(1.0, m * invK + k);
	float b = 1.0 - min(1.0, y * invK + k);
	return clamp(vec3(r, g, b), 0.0, 1.0);
}

vec4 rgb_to_cmyk(vec3 rgb) {
	float r = rgb.r;
	float g = rgb.g;
	float b = rgb.b;
	float k = min(1.0 - r, min(1.0 - g, 1.0 - b));
	vec3 cmy = vec3(0.0);
	float invK = 1.0 - k;
	if (invK != 0.0) {
		cmy.x = (1.0 - r - k) / invK;
		cmy.y = (1.0 - g - k) / invK;
		cmy.z = (1.0 - b - k) / invK;
	}
	return clamp(vec4(cmy.x, cmy.y, cmy.z, k), 0.0, 1.0);
}

vec2 rotate_uv(vec2 uv, vec2 xUnitDir) {
	return vec2(uv.x * xUnitDir.x + uv.y * -xUnitDir.y, uv.x * xUnitDir.y + uv.y * xUnitDir.x);
}

vec4 get_dither_3d(vec2 uv_dither_tex, vec2 screen_uv, vec2 dx, vec2 dy, float brightness, mat4 proj_matrix) {
	float b = brightness;
	if (u_inverse_dots) {
		b = 1.0 - b;
	}

	ivec3 tex_size_i = textureSize(u_dither_tex, 0);
	float xRes = float(tex_size_i.x);
	float invXres = 1.0 / xRes;

	float dotsPerSide = xRes / 16.0;
	float dotsTotal = pow(dotsPerSide, 2.0);
	float invZres = 1.0 / dotsTotal;

	vec2 lookup = vec2((0.5 * invXres + (1.0 - invXres) * b), 0.5);
	float brightnessCurve = texture(u_dither_ramp_tex, lookup).r;

	if (u_radial_compensation) {
		vec2 screenP = (screen_uv - 0.5) * 2.0;
		vec2 viewDirProj = vec2(
			screenP.x / proj_matrix[0][0],
			screenP.y / proj_matrix[1][1]
		);
		float radialComp = dot(viewDirProj, viewDirProj) + 1.0;
		dx *= radialComp;
		dy *= radialComp;
	}

	float Q = dot(dx, dx) + dot(dy, dy);
	float R = dx.x * dy.y - dx.y * dy.x;
	float discriminantSqr = max(0.0, Q*Q - 4.0*R*R);
	float discriminant = sqrt(discriminantSqr);
	vec2 freq = sqrt(vec2(Q + discriminant, Q - discriminant) / 2.0);

	float spacing = freq.y;
	float scaleExp = exp2(u_dot_scale);
	spacing *= scaleExp;
	spacing *= dotsPerSide * 0.125;

	float brightnessSpacingMultiplier = pow(brightnessCurve * 2.0 + 0.001, -(1.0 - u_size_variability));
	spacing *= brightnessSpacingMultiplier;

	float spacingLog = log2(spacing);
	int patternScaleLevel = int(floor(spacingLog));
	float f = spacingLog - float(patternScaleLevel);

	vec2 uv = uv_dither_tex / exp2(float(patternScaleLevel));
	float subLayer = mix(0.25 * dotsTotal, dotsTotal, 1.0 - f);
	
	float thresholdTweak = 1.0;
	if (u_quantize_layers) {
		float origSubLayer = subLayer;
		subLayer = floor(subLayer + 0.5);
		thresholdTweak = sqrt(subLayer / origSubLayer);
	}

	subLayer = (subLayer - 0.5) * invZres;
	float pattern = texture(u_dither_tex, vec3(uv, subLayer)).r;

	float contrast_val = u_contrast * scaleExp * brightnessSpacingMultiplier * 0.1;
	contrast_val *= pow(freq.y / freq.x, u_stretch_smoothness);

	float baseVal = mix(0.5, b, clamp(1.05 / (1.0 + contrast_val), 0.0, 1.0));
	float threshold = 1.0 - brightnessCurve;
	if (u_quantize_layers) {
		threshold = 1.0 - brightnessCurve * thresholdTweak;
	}

	float bw = clamp((pattern - threshold) * contrast_val + baseVal, 0.0, 1.0);

	if (u_inverse_dots) {
		bw = 1.0 - bw;
	}

	return vec4(bw, fract(uv.x), fract(uv.y), subLayer);
}

vec3 get_dither_3d_color(vec2 uv_dither_tex, vec2 screen_uv, vec3 color, mat4 proj_matrix, vec2 dx, vec2 dy) {
	vec3 input_c = color;
#ifndef DITHER_NO_SCREEN_TEXTURE
	if (inherit_albedo) {
		input_c = texture(screen_texture, screen_uv).rgb;
	}
#endif
	vec3 c = clamp(input_c * u_input_exposure + u_input_offset, 0.0, 1.0);
	
	if (u_dither_mode == 0) { // Grayscale
		vec4 dither = get_dither_3d(uv_dither_tex, screen_uv, dx, dy, get_grayscale(c), proj_matrix);
		c = vec3(dither.x);
		if (u_debug_fractal) {
			c = mix(c, dither.yzw, 0.7);
		}
	} else if (u_dither_mode == 1) { // RGB
		c.r = get_dither_3d(uv_dither_tex, screen_uv, dx, dy, c.r, proj_matrix).x;
		c.g = get_dither_3d(uv_dither_tex, screen_uv, dx, dy, c.g, proj_matrix).x;
		c.b = get_dither_3d(uv_dither_tex, screen_uv, dx, dy, c.b, proj_matrix).x;
	} else if (u_dither_mode == 2) { // CMYK
		vec4 cmyk = rgb_to_cmyk(c);
		cmyk.x = get_dither_3d(rotate_uv(uv_dither_tex, vec2(0.966, 0.259)), screen_uv, dx, dy, cmyk.x, proj_matrix).x;
		cmyk.y = get_dither_3d(rotate_uv(uv_dither_tex, vec2(0.259, 0.966)), screen_uv, dx, dy, cmyk.y, proj_matrix).x;
		cmyk.z = get_dither_3d(rotate_uv(uv_dither_tex, vec2(1.000, 0.000)), screen_uv, dx, dy, cmyk.z, proj_matrix).x;
		cmyk.w = get_dither_3d(rotate_uv(uv_dither_tex, vec2(0.707, 0.707)), screen_uv, dx, dy, cmyk.w, proj_matrix).x;
		c = cmyk_to_rgb(cmyk);
	}
	return c;
}

vec3 get_dither_3d_color_alt_uv(vec2 uv_dither_tex, vec2 uv_dither_tex_alt, vec2 screen_uv, vec3 color, mat4 proj_matrix, vec2 dxA, vec2 dyA, vec2 dxB, vec2 dyB) {
	vec3 input_c = color;
#ifndef DITHER_NO_SCREEN_TEXTURE
	if (inherit_albedo) {
		input_c = texture(screen_texture, screen_uv).rgb;
	}
#endif
	vec3 c = clamp(input_c * u_input_exposure + u_input_offset, 0.0, 1.0);
	
	vec2 dx = dot(dxA, dxA) < dot(dxB, dxB) ? dxA : dxB;
	vec2 dy = dot(dyA, dyA) < dot(dyB, dyB) ? dyA : dyB;
	
	// Note: We use uv_dither_tex for the actual sampling, assuming the scale is similar enough
	// or that we just want the derivatives to be stable.
	// The original code uses GetDither3D_ which takes dx, dy explicitly.
	// So we can pass uv_dither_tex but use the better derivatives.
	
	if (u_dither_mode == 0) { // Grayscale
		vec4 dither = get_dither_3d(uv_dither_tex, screen_uv, dx, dy, get_grayscale(c), proj_matrix);
		c = vec3(dither.x);
		if (u_debug_fractal) {
			c = mix(c, dither.yzw, 0.7);
		}
	} else if (u_dither_mode == 1) { // RGB
		c.r = get_dither_3d(uv_dither_tex, screen_uv, dx, dy, c.r, proj_matrix).x;
		c.g = get_dither_3d(uv_dither_tex, screen_uv, dx, dy, c.g, proj_matrix).x;
		c.b = get_dither_3d(uv_dither_tex, screen_uv, dx, dy, c.b, proj_matrix).x;
	} else if (u_dither_mode == 2) { // CMYK
		vec4 cmyk = rgb_to_cmyk(c);
		cmyk.x = get_dither_3d(rotate_uv(uv_dither_tex, vec2(0.966, 0.259)), screen_uv, dx, dy, cmyk.x, proj_matrix).x;
		cmyk.y = get_dither_3d(rotate_uv(uv_dither_tex, vec2(0.259, 0.966)), screen_uv, dx, dy, cmyk.y, proj_matrix).x;
		cmyk.z = get_dither_3d(rotate_uv(uv_dither_tex, vec2(1.000, 0.000)), screen_uv, dx, dy, cmyk.z, proj_matrix).x;
		cmyk.w = get_dither_3d(rotate_uv(uv_dither_tex, vec2(0.707, 0.707)), screen_uv, dx, dy, cmyk.w, proj_matrix).x;
		c = cmyk_to_rgb(cmyk);
	}
	return c;
}
