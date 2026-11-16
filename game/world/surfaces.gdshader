// Material único del edificio: toda la estructura y el decorado de una sala en una sola
// superficie. El color del vértice trae el tono (rgb, ya en lineal, con la luz por vértice
// aplicada) y la capa de textura en el alfa (dieciseisavos; 15 = sin textura). La textura se
// proyecta según la posición en el mundo y la cara dominante, así no hacen falta UV propias.
// La capa 14 es emisiva (paneles de luz, carteles de emergencia): brilla con su propio color,
// escalado por emission_scale (cada piso tiene su copia del material; el apagón lo baja).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2DArray layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_meters[16];
uniform float emission_scale = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float layer = floor(COLOR.a * 16.0);
	vec3 base = COLOR.rgb;
	if (layer < 13.5) {
		vec3 n = abs(world_normal);
		vec2 uv;
		if (n.y >= n.x && n.y >= n.z) {
			uv = world_pos.xz;
		} else if (n.x >= n.z) {
			uv = vec2(world_pos.z, -world_pos.y);
		} else {
			uv = vec2(world_pos.x, -world_pos.y);
		}
		uv /= tile_meters[int(layer)];
		base *= texture(layers, vec3(uv, layer)).rgb;
	}
	if (layer > 13.5 && layer < 14.5) {
		ALBEDO = COLOR.rgb * 0.4 * max(emission_scale, 0.3);
		EMISSION = COLOR.rgb * 1.8 * emission_scale;
	} else {
		ALBEDO = base;
	}
	ROUGHNESS = 0.9;
}
