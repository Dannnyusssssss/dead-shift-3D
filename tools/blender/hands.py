"""Manos del guardia en primera persona: guantes de formas sencillas hechos por script.

Lo usa tools/blender/arms.py. Cada mano es un guante (palma, cuatro dedos, pulgar y puño de la
manga) hecho con tubos redondeados, en el mismo estilo de piezas sencillas que las armas. Los
dedos se construyen alrededor del mango del arma: el hueco del puño es un cilindro de radio y eje
conocidos y el arma se coloca justo en ese eje, así el mango nunca flota ni atraviesa la mano.
  - grip: puño cerrado alrededor de un mango que sale hacia delante por el lado del pulgar
    (armas de cuerpo a cuerpo y objetos); el pulgar cierra por fuera sobre los dedos.
  - pistol: corazón, anular y meñique alrededor de la empuñadura inclinada, el índice estirado
    por el costado hasta el gatillo y el pulgar por el otro lado.
  - open: mano relajada, con los dedos algo doblados.
Coordenadas de la muñeca (Godot): origen en la muñeca, la mano hacia -Z (el antebrazo hacia +Z),
+X el dorso, -X la palma y +Y el lado del pulgar. La mano izquierda es el reflejo de la derecha.
Normales suavizadas por vértice. Reproducible: solo geometría fija, sin azar.
"""

import math

from mathutils import Matrix, Vector

# Piel de la muñeca (la usa arms.py) y colores del guante de cuero y de su puño.
SKIN = (0.72, 0.55, 0.43)
GLOVE = (0.5, 0.35, 0.22)
CUFF = (0.27, 0.18, 0.11)
# Lados de los tubos de los dedos y de la palma.
FINGER_SIDES = 10
PALM_SIDES = 16
# Palma: centro en el grosor (x) y estaciones de la muñeca a los nudillos (z, ancho, grosor).
PALM_X = -0.004
PALM_STATIONS = (
    (0.004, 0.058, 0.03),
    (-0.03, 0.08, 0.034),
    (-0.06, 0.086, 0.032),
    (-0.084, 0.084, 0.027),
)
# Nudillos: z de la base de los dedos, y (lado) y radio de cada dedo.
KNUCKLE_Z = -0.08
FINGERS = (
    ("index", 0.029, 0.0095),
    ("middle", 0.0095, 0.0098),
    ("ring", -0.0095, 0.0093),
    ("pinky", -0.027, 0.0082),
)
# Vuelta de cada dedo alrededor del mango (grados): el meñique es más corto.
CURL_DEG = {"index": 205.0, "middle": 215.0, "ring": 205.0, "pinky": 190.0}
THUMB_RADIUS = 0.0105
# Puño del arma de cuerpo a cuerpo: centro y eje del hueco del puño (el mango sale por el lado
# del pulgar e inclinado hacia delante) y su radio (mangos de 1,8 a 3 cm).
GRIP_CENTER = Vector((-0.034, 0.0, -0.07))
GRIP_AXIS = Vector((0.0, 0.79, -0.61)).normalized()
GRIP_RADIUS = 0.021
# Empuñadura de la pistola: hueco del puño (eje casi vertical, hacia el pulgar) y radio (la
# empuñadura mide 3 x 4,5 cm de sección).
PISTOL_CENTER = Vector((-0.036, -0.004, -0.07))
PISTOL_AXIS = Vector((0.0, 0.99, 0.14)).normalized()
PISTOL_RADIUS = 0.021
# Pistola (tools/blender/items.py): inclinación de la empuñadura, punto de agarre (en su eje,
# algo por encima del centro) y gatillo. Escopeta: punto de su empuñadura vertical.
PISTOL_RAKE_DEG = 14.0
PISTOL_GRIP_POINT = Vector((0.0, -0.071, 0.017))
TRIGGER = Vector((0.0, -0.046, -0.026))
SHOTGUN_GRIP_POINT = Vector((0.0, -0.075, 0.04))


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _linear(rgb):
    return tuple(srgb_to_linear(c) for c in rgb) + (1.0,)


def _perpendicular(t: Vector) -> Vector:
    helper = Vector((1.0, 0.0, 0.0)) if abs(t.x) < 0.9 else Vector((0.0, 1.0, 0.0))
    return (helper - t * helper.dot(t)).normalized()


def _section(angle: float, exponent: float):
    """Punto y normal (sin escalar) de una sección superelíptica: 2 = círculo, más = caja."""
    c, s = math.cos(angle), math.sin(angle)
    p = 2.0 / exponent
    q = 2.0 - p
    point = (math.copysign(abs(c) ** p, c), math.copysign(abs(s) ** p, s))
    normal = (math.copysign(abs(c) ** q, c), math.copysign(abs(s) ** q, s))
    return point, normal


def tube(tris, points, radii, color, sides=FINGER_SIDES, widths=None, exponent=2.0,
         first_normal=None, cap=0.6):
    """Tubo por una línea de puntos con su radio en cada uno (o ancho y grosor con `widths`),
    cerrado en los dos extremos con una cúpula (`cap`: fondo de la cúpula en radios)."""
    rgba = _linear(color)
    count = len(points)
    tangents = []
    for i in range(count):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, count - 1)]
        tangents.append((b - a).normalized())
    normal = first_normal if first_normal is not None else _perpendicular(tangents[0])
    rings = []
    for i in range(count):
        t = tangents[i]
        normal = (normal - t * normal.dot(t)).normalized()
        binormal = t.cross(normal)
        if widths is None:
            rn = rb = radii[i]
        else:
            rn, rb = widths[i]
        rings.append((points[i], normal, binormal, rn, rb, t))
    # Cúpulas: anillos que se cierran hacia fuera en cada extremo.
    steps = 3
    start = []
    end = []
    for k in range(steps, 0, -1):
        phi = (math.pi / 2.0) * k / (steps + 0.0)
        for target, ring, sign in ((start, rings[0], -1.0), (end, rings[-1], 1.0)):
            center, n, b, rn, rb, t = ring
            depth = cap * min(rn, rb)
            target.append((center + t * (sign * depth * math.sin(phi)), n, b,
                           rn * math.cos(phi), rb * math.cos(phi), t, sign * math.sin(phi)))
    sequence = start + [r + (0.0,) for r in rings] + list(reversed(end))
    verts = []
    for center, n, b, rn, rb, t, axial in sequence:
        row = []
        for j in range(sides):
            angle = 2.0 * math.pi * j / sides
            (pc, ps), (nc, ns) = _section(angle, exponent)
            pos = center + n * (rn * pc) + b * (rb * ps)
            radial = (n * (nc / max(rn, 1e-5)) + b * (ns / max(rb, 1e-5))).normalized()
            nrm = (radial * math.sqrt(max(1.0 - axial * axial, 0.0)) + t * axial).normalized()
            row.append((pos, nrm))
        verts.append(row)
    for i in range(len(verts) - 1):
        for j in range(sides):
            a = verts[i][j]
            b = verts[i][(j + 1) % sides]
            c = verts[i + 1][(j + 1) % sides]
            d = verts[i + 1][j]
            for tri in ((a, c, d), (a, b, c)):
                if (tri[1][0] - tri[0][0]).cross(tri[2][0] - tri[0][0]).length < 1e-12:
                    continue
                tris.append([(tuple(p), tuple(nv), rgba) for p, nv in tri])


def _arc(center: Vector, axis: Vector, radius: float, start_deg: float, sweep_deg: float,
         steps: int):
    """Puntos de un arco alrededor de `axis` (desde el dorso, +X, hacia delante y la palma)."""
    e1 = (Vector((1.0, 0.0, 0.0)) - axis * axis.x).normalized()
    e2 = axis.cross(e1)
    out = []
    for k in range(steps + 1):
        angle = math.radians(start_deg + sweep_deg * k / steps)
        out.append(center + (e1 * math.cos(angle) + e2 * math.sin(angle)) * radius)
    return out


def _angle_of(point: Vector, center: Vector, axis: Vector) -> float:
    e1 = (Vector((1.0, 0.0, 0.0)) - axis * axis.x).normalized()
    e2 = axis.cross(e1)
    d = point - center
    return math.degrees(math.atan2(d.dot(e2), d.dot(e1)))


def palm(tris) -> None:
    points = [Vector((PALM_X, 0.0, z)) for z, _w, _t in PALM_STATIONS]
    widths = [(t * 0.5, w * 0.5) for _z, w, t in PALM_STATIONS]
    tube(tris, points, None, GLOVE, sides=PALM_SIDES, widths=widths, exponent=3.0,
         first_normal=Vector((1.0, 0.0, 0.0)), cap=0.35)
    # Puño de la manga del guante, algo más ancho que la muñeca.
    cuff = [Vector((0.0, 0.0, 0.04)), Vector((0.0, 0.0, 0.012)), Vector((0.0, 0.0, -0.004))]
    tube(tris, cuff, [0.034, 0.034, 0.032], CUFF, sides=PALM_SIDES, cap=0.2)


def knuckle(y: float) -> Vector:
    return Vector((PALM_X + 0.002, y, KNUCKLE_Z))


def curled_finger(tris, name: str, y: float, radius: float, center: Vector, axis: Vector,
                  hole: float) -> None:
    """Dedo que sale del nudillo y da la vuelta al mango (hueco de radio `hole`)."""
    along = (y - center.y) / axis.y
    ring_center = center + axis * along
    base = knuckle(y)
    start = _angle_of(base, ring_center, axis)
    arc = _arc(ring_center, axis, hole + radius, start + 18.0, CURL_DEG[name] - 18.0, 9)
    points = [base] + arc
    radii = [radius * 1.05] + [radius * (1.0 - 0.18 * k / (len(arc) - 1)) for k in range(len(arc))]
    tube(tris, points, radii, GLOVE)


def grip_hand(tris) -> None:
    palm(tris)
    for name, y, radius in FINGERS:
        curled_finger(tris, name, y, radius, GRIP_CENTER, GRIP_AXIS, GRIP_RADIUS)
    # Pulgar: de la base de la palma, por fuera sobre el índice y el corazón.
    thumb = [Vector((-0.012, 0.034, -0.02)), Vector((-0.036, 0.05, -0.04)),
             Vector((-0.062, 0.036, -0.06)), Vector((-0.07, 0.016, -0.076))]
    tube(tris, thumb, [THUMB_RADIUS * 1.15, THUMB_RADIUS, THUMB_RADIUS * 0.95,
                       THUMB_RADIUS * 0.85], GLOVE)


def pistol_hand(tris, trigger: Vector) -> None:
    palm(tris)
    for name, y, radius in FINGERS[1:]:
        curled_finger(tris, name, y, radius, PISTOL_CENTER, PISTOL_AXIS, PISTOL_RADIUS)
    # Índice estirado por el costado derecho del armazón hasta el gatillo.
    _name, y, radius = FINGERS[0]
    base = knuckle(y)
    side_x = PISTOL_CENTER.x + 0.015 + radius
    index = [base, Vector((side_x, y, base.z - 0.022)),
             Vector((side_x - 0.004, trigger.y + 0.002, trigger.z + 0.012)),
             trigger + Vector((0.008, 0.0, 0.0))]
    tube(tris, index, [radius * 1.05, radius, radius * 0.92, radius * 0.82], GLOVE)
    # Pulgar: rodea la parte de atrás de la empuñadura y sigue por el costado izquierdo.
    left_x = PISTOL_CENTER.x - 0.015 - THUMB_RADIUS
    thumb = [Vector((-0.012, 0.034, -0.022)), Vector((-0.03, 0.044, -0.036)),
             Vector((left_x + 0.004, 0.04, -0.056)), Vector((left_x, 0.034, -0.08))]
    tube(tris, thumb, [THUMB_RADIUS * 1.15, THUMB_RADIUS, THUMB_RADIUS * 0.95,
                       THUMB_RADIUS * 0.85], GLOVE)


def open_hand(tris) -> None:
    palm(tris)
    for name, y, radius in FINGERS:
        length = 0.07 if name != "pinky" else 0.055
        points = [knuckle(y)]
        direction = Vector((0.0, 0.0, -1.0))
        bends = (12.0, 18.0, 14.0)
        pieces = (0.45, 0.32, 0.23)
        for bend, piece in zip(bends, pieces):
            angle = math.radians(bend)
            # Se dobla hacia la palma (-X).
            direction = Vector((direction.x * math.cos(angle) + direction.z * math.sin(angle),
                                direction.y,
                                -direction.x * math.sin(angle) + direction.z * math.cos(angle)))
            points.append(points[-1] + direction * (length * piece))
        tube(tris, points, [radius * (1.05 - 0.07 * k) for k in range(len(points))], GLOVE)
    thumb = [Vector((-0.01, 0.034, -0.018)), Vector((-0.022, 0.05, -0.04)),
             Vector((-0.03, 0.058, -0.062)), Vector((-0.034, 0.058, -0.08))]
    tube(tris, thumb, [THUMB_RADIUS * 1.15, THUMB_RADIUS, THUMB_RADIUS * 0.95,
                       THUMB_RADIUS * 0.85], GLOVE)


def hold_frame(center: Vector, axis: Vector, weapon_axis: Vector, weapon_point: Vector):
    """Colocación del arma en coordenadas de la muñeca: su eje de agarre (weapon_axis, en sus
    coordenadas) va por el eje del hueco del puño y su punto de agarre (weapon_point) a su
    centro; su +X queda hacia el dorso. Devuelve (base 3x3 como columnas, origen)."""
    axis_g = axis.normalized()
    hint = Vector((1.0, 0.0, 0.0))
    x_t = (hint - axis_g * hint.dot(axis_g)).normalized()
    target = Matrix((x_t, axis_g, x_t.cross(axis_g))).transposed()
    a_w = weapon_axis.normalized()
    x_w = (hint - a_w * hint.dot(a_w)).normalized()
    weapon = Matrix((x_w, a_w, x_w.cross(a_w))).transposed()
    basis = target @ weapon.transposed()
    origin = center - basis @ weapon_point
    return basis, origin


def build_all():
    """Hace las tres formas. Devuelve {nombre: triángulos} y la colocación de las armas que usa
    el juego (base y origen en coordenadas de la muñeca)."""
    info = {}
    info["melee"] = hold_frame(GRIP_CENTER, GRIP_AXIS, Vector((0.0, 0.0, -1.0)), Vector())
    rake = math.radians(PISTOL_RAKE_DEG)
    pistol_axis = Vector((0.0, math.cos(rake), math.sin(rake)))
    basis, origin = hold_frame(PISTOL_CENTER, PISTOL_AXIS, pistol_axis, PISTOL_GRIP_POINT)
    info["pistol"] = (basis, origin)
    info["shotgun"] = hold_frame(PISTOL_CENTER, PISTOL_AXIS, Vector((0.0, 1.0, 0.0)),
                                 SHOTGUN_GRIP_POINT)
    trigger = basis @ TRIGGER + origin
    results = {"grip": [], "pistol": [], "open": []}
    grip_hand(results["grip"])
    pistol_hand(results["pistol"], trigger)
    open_hand(results["open"])
    return results, info


def to_triangles(tris):
    """Triángulos para glb_writer.write_glb con normal por esquina, en orden fijo (empieza por
    la esquina menor y se ordenan por posición): el archivo sale igual en cada ejecución."""
    out = []
    for corners in tris:
        keys = [tuple(round(c, 5) for c in p) for p, _n, _c in corners]
        first = keys.index(min(keys))
        corners = corners[first:] + corners[:first]
        normals = tuple(tuple(n) for _p, n, _c in corners)
        out.append((normals, [(p, c) for p, _n, c in corners]))
    out.sort(key=lambda tri: [round(c, 5) for pos, _color in tri[1] for c in pos])
    return out


def mirror(tris):
    """Reflejo en X (mano izquierda): x cambia de signo y se invierte el giro de cada triángulo."""
    out = []
    for corners in tris:
        flipped = [((-p[0], p[1], p[2]), (-n[0], n[1], n[2]), c) for p, n, c in corners]
        out.append([flipped[0], flipped[2], flipped[1]])
    return out
