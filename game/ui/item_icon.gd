class_name ItemIcon
extends Control
## Icono propio de cada objeto, dibujado con formas simples (sin imágenes externas). Las formas
## se describen en coordenadas de 0 a 1 y se escalan al tamaño del control. Un objeto sin icono
## muestra un signo de interrogación.
## Formas: ["rect", color, x, y, ancho, alto], ["poly", color, [x1, y1, x2, y2, ...]],
## ["line", color, ancho, x1, y1, x2, y2], ["circle", color, x, y, radio],
## ["ring", color, ancho, x, y, radio].

const METAL := Color(0.62, 0.64, 0.68)
const DARK := Color(0.22, 0.23, 0.26)
const WOOD := Color(0.62, 0.45, 0.28)
const CLOTH := Color(0.85, 0.85, 0.8)
const BRASS := Color(0.85, 0.7, 0.3)
const RED := Color(0.75, 0.2, 0.18)
const GREEN := Color(0.3, 0.6, 0.35)
const BLUE := Color(0.3, 0.5, 0.8)

const SHAPES: Dictionary = {
	"pistol":
	[
		["rect", DARK, 0.12, 0.32, 0.72, 0.16],
		["poly", DARK, [0.18, 0.46, 0.38, 0.46, 0.34, 0.82, 0.14, 0.82]],
		["line", METAL, 0.04, 0.4, 0.48, 0.46, 0.58],
	],
	"shotgun":
	[
		["rect", DARK, 0.3, 0.4, 0.66, 0.07],
		["rect", WOOD, 0.46, 0.48, 0.2, 0.07],
		["poly", WOOD, [0.04, 0.44, 0.32, 0.4, 0.32, 0.52, 0.06, 0.62]],
	],
	"bat":
	[["line", WOOD, 0.07, 0.22, 0.82, 0.48, 0.52], ["line", WOOD, 0.15, 0.45, 0.55, 0.82, 0.18]],
	"bat_nails":
	[
		["line", WOOD, 0.07, 0.22, 0.82, 0.48, 0.52],
		["line", WOOD, 0.15, 0.45, 0.55, 0.82, 0.18],
		["line", METAL, 0.025, 0.58, 0.3, 0.7, 0.36],
		["line", METAL, 0.025, 0.66, 0.2, 0.78, 0.28],
		["line", METAL, 0.025, 0.56, 0.44, 0.66, 0.52],
	],
	"pipe": [["line", METAL, 0.1, 0.18, 0.82, 0.82, 0.18], ["ring", DARK, 0.03, 0.82, 0.18, 0.06]],
	"pipe_grip":
	[
		["line", METAL, 0.1, 0.18, 0.82, 0.82, 0.18],
		["line", CLOTH, 0.13, 0.18, 0.82, 0.42, 0.58],
		["line", DARK, 0.02, 0.24, 0.7, 0.32, 0.8],
		["line", DARK, 0.02, 0.32, 0.62, 0.4, 0.72],
	],
	"pipe_nails":
	[
		["line", METAL, 0.1, 0.18, 0.82, 0.82, 0.18],
		["line", METAL, 0.025, 0.62, 0.3, 0.74, 0.4],
		["line", METAL, 0.025, 0.7, 0.22, 0.82, 0.32],
		["line", METAL, 0.025, 0.54, 0.4, 0.62, 0.5],
	],
	"knife":
	[
		["poly", METAL, [0.42, 0.52, 0.88, 0.14, 0.92, 0.2, 0.5, 0.6]],
		["line", DARK, 0.09, 0.14, 0.86, 0.44, 0.56],
	],
	"extinguisher":
	[
		["rect", RED, 0.34, 0.28, 0.32, 0.62],
		["rect", DARK, 0.4, 0.16, 0.2, 0.12],
		["line", DARK, 0.04, 0.6, 0.2, 0.82, 0.36],
	],
	"bottle":
	[
		[
			"poly",
			GREEN,
			[
				0.38,
				0.4,
				0.46,
				0.3,
				0.46,
				0.12,
				0.54,
				0.12,
				0.54,
				0.3,
				0.62,
				0.4,
				0.62,
				0.9,
				0.38,
				0.9
			]
		],
	],
	"nails":
	[
		["line", METAL, 0.04, 0.3, 0.2, 0.3, 0.84],
		["line", METAL, 0.04, 0.5, 0.2, 0.5, 0.84],
		["line", METAL, 0.04, 0.7, 0.2, 0.7, 0.84],
		["line", METAL, 0.1, 0.24, 0.2, 0.36, 0.2],
		["line", METAL, 0.1, 0.44, 0.2, 0.56, 0.2],
		["line", METAL, 0.1, 0.64, 0.2, 0.76, 0.2],
	],
	"tape": [["ring", METAL, 0.16, 0.5, 0.5, 0.26], ["ring", DARK, 0.03, 0.5, 0.5, 0.12]],
	"batteries":
	[
		["rect", DARK, 0.22, 0.26, 0.22, 0.56],
		["rect", METAL, 0.27, 0.2, 0.12, 0.08],
		["rect", DARK, 0.56, 0.26, 0.22, 0.56],
		["rect", METAL, 0.61, 0.2, 0.12, 0.08],
	],
	"rag":
	[
		["poly", CLOTH, [0.16, 0.3, 0.5, 0.2, 0.84, 0.3, 0.78, 0.78, 0.46, 0.84, 0.2, 0.74]],
		["line", DARK, 0.02, 0.3, 0.46, 0.7, 0.42],
	],
	"improvised_bandage":
	[
		["poly", CLOTH, [0.18, 0.34, 0.66, 0.28, 0.7, 0.66, 0.22, 0.72]],
		["rect", METAL, 0.36, 0.26, 0.12, 0.5],
	],
	"noise_bottle":
	[
		[
			"poly",
			GREEN,
			[0.38, 0.4, 0.46, 0.3, 0.46, 0.2, 0.54, 0.2, 0.54, 0.3, 0.62, 0.4, 0.62, 0.9, 0.38, 0.9]
		],
		["poly", CLOTH, [0.44, 0.22, 0.56, 0.22, 0.6, 0.06, 0.42, 0.08]],
		["ring", BRASS, 0.03, 0.78, 0.3, 0.1],
		["ring", BRASS, 0.03, 0.78, 0.3, 0.18],
	],
	"bandage":
	[
		["rect", CLOTH, 0.22, 0.3, 0.42, 0.4],
		["ring", CLOTH, 0.08, 0.64, 0.5, 0.2],
		["line", Color(0.7, 0.7, 0.65), 0.03, 0.3, 0.36, 0.3, 0.64],
	],
	"antibiotics":
	[
		["rect", Color(0.9, 0.9, 0.85), 0.3, 0.3, 0.4, 0.56],
		["rect", BLUE, 0.28, 0.16, 0.44, 0.14],
		["rect", Color(0.55, 0.75, 0.95), 0.36, 0.48, 0.28, 0.16],
	],
	"neutrax":
	[
		["rect", Color(0.75, 0.9, 0.95), 0.3, 0.3, 0.32, 0.48],
		["rect", BLUE, 0.3, 0.46, 0.32, 0.18],
		["line", METAL, 0.04, 0.46, 0.3, 0.46, 0.12],
		["rect", DARK, 0.36, 0.78, 0.2, 0.08],
	],
	"pistol_ammo":
	[
		["rect", Color(0.4, 0.42, 0.3), 0.16, 0.44, 0.68, 0.4],
		["rect", BRASS, 0.24, 0.24, 0.1, 0.22],
		["rect", BRASS, 0.44, 0.24, 0.1, 0.22],
		["rect", BRASS, 0.64, 0.24, 0.1, 0.22],
	],
	"shotgun_shells":
	[
		["rect", RED, 0.24, 0.22, 0.16, 0.48],
		["rect", BRASS, 0.24, 0.68, 0.16, 0.12],
		["rect", RED, 0.56, 0.22, 0.16, 0.48],
		["rect", BRASS, 0.56, 0.68, 0.16, 0.12],
	],
	"vest":
	[
		[
			"poly",
			Color(0.2, 0.28, 0.45),
			[0.26, 0.16, 0.4, 0.16, 0.5, 0.3, 0.6, 0.16, 0.74, 0.16, 0.8, 0.86, 0.2, 0.86]
		],
		["rect", Color(0.85, 0.85, 0.8), 0.32, 0.5, 0.36, 0.08],
	],
	"mall_map":
	[
		[
			"poly",
			CLOTH,
			[
				0.14,
				0.24,
				0.38,
				0.18,
				0.62,
				0.24,
				0.86,
				0.18,
				0.86,
				0.78,
				0.62,
				0.84,
				0.38,
				0.78,
				0.14,
				0.84
			]
		],
		["line", DARK, 0.02, 0.38, 0.18, 0.38, 0.78],
		["line", DARK, 0.02, 0.62, 0.24, 0.62, 0.84],
		["circle", RED, 0.5, 0.5, 0.05],
	],
	"security_key":
	[
		["ring", BLUE, 0.07, 0.3, 0.5, 0.14],
		["line", BLUE, 0.07, 0.44, 0.5, 0.86, 0.5],
		["line", BLUE, 0.06, 0.74, 0.5, 0.74, 0.64],
		["line", BLUE, 0.06, 0.84, 0.5, 0.84, 0.66],
	],
	"roof_key":
	[
		["ring", BRASS, 0.07, 0.3, 0.5, 0.14],
		["line", BRASS, 0.07, 0.44, 0.5, 0.86, 0.5],
		["line", BRASS, 0.06, 0.74, 0.5, 0.74, 0.64],
		["line", BRASS, 0.06, 0.84, 0.5, 0.84, 0.66],
	],
	"phone_antenna": [["line", METAL, 0.05, 0.3, 0.86, 0.7, 0.2], ["circle", DARK, 0.7, 0.2, 0.07]],
	"phone_battery":
	[
		["rect", DARK, 0.22, 0.28, 0.56, 0.48],
		["rect", METAL, 0.42, 0.2, 0.16, 0.08],
		["rect", GREEN, 0.3, 0.4, 0.4, 0.08],
	],
	"phone_board":
	[
		["rect", GREEN, 0.14, 0.24, 0.72, 0.52],
		["rect", DARK, 0.24, 0.34, 0.16, 0.14],
		["rect", DARK, 0.5, 0.34, 0.24, 0.24],
		["line", BRASS, 0.02, 0.24, 0.62, 0.74, 0.62],
	],
	"phone":
	[
		["rect", DARK, 0.3, 0.12, 0.4, 0.78],
		["rect", Color(0.55, 0.75, 0.9), 0.34, 0.2, 0.32, 0.4],
		["line", METAL, 0.04, 0.62, 0.12, 0.72, 0.02],
	],
}

@export var item_id: String = "":
	set(value):
		item_id = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func has_icon(id: String) -> bool:
	return SHAPES.has(id)


func _draw() -> void:
	if item_id.is_empty():
		return
	var side := minf(size.x, size.y)
	var origin := (size - Vector2(side, side)) * 0.5
	if not SHAPES.has(item_id):
		var font := get_theme_default_font()
		draw_string(font, origin + Vector2(side * 0.3, side * 0.7), "?", 0, -1, int(side * 0.5))
		return
	var shapes: Array = SHAPES[item_id]
	for shape: Array in shapes:
		_draw_shape(shape, origin, side)


func _draw_shape(shape: Array, origin: Vector2, side: float) -> void:
	var kind: String = shape[0]
	var color: Color = shape[1]
	match kind:
		"rect":
			var x: float = shape[2]
			var y: float = shape[3]
			var w: float = shape[4]
			var h: float = shape[5]
			draw_rect(Rect2(origin + Vector2(x, y) * side, Vector2(w, h) * side), color)
		"poly":
			var raw: Array = shape[2]
			var points := PackedVector2Array()
			for index: int in range(0, raw.size() - 1, 2):
				var px: float = raw[index]
				var py: float = raw[index + 1]
				points.append(origin + Vector2(px, py) * side)
			draw_colored_polygon(points, color)
		"line":
			var width: float = shape[2]
			var a := _point(shape, 3)
			var b := _point(shape, 5)
			draw_line(origin + a * side, origin + b * side, color, maxf(width * side, 1.0), true)
		"circle":
			var center := _point(shape, 2)
			var radius: float = shape[4]
			draw_circle(origin + center * side, radius * side, color)
		"ring":
			var ring_width: float = shape[2]
			var ring_center := _point(shape, 3)
			var ring_radius: float = shape[5]
			draw_arc(
				origin + ring_center * side,
				ring_radius * side,
				0.0,
				TAU,
				32,
				color,
				maxf(ring_width * side, 1.0),
				true
			)


## Punto (x, y) guardado en dos posiciones seguidas de la forma.
static func _point(shape: Array, index: int) -> Vector2:
	var x: float = shape[index]
	var y: float = shape[index + 1]
	return Vector2(x, y)
