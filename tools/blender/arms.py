"""Brazos del guardia en primera persona: piezas rígidas por hueso (color de vértice).

Uso: blender --background --factory-startup --python tools/blender/arms.py

Escribe en assets/generated/arms/:
  - upper_arm.glb: brazo con la manga del uniforme (origen en el hombro, apunta a -Z).
  - forearm_right.glb y forearm_left.glb: antebrazo con la manga larga hasta cerca de la muñeca
    y su puño (origen en el codo); el izquierdo lleva el reloj.
  - hand_grip_right/left.glb: puño de cuerpo a cuerpo, con los dedos rodeando el mango (que pasa
    por debajo de la muñeca a lo largo de -Z); hand_pistol_right/left.glb: puño de arma de fuego,
    con la empuñadura vertical, los dedos alrededor por delante, el índice estirado hacia el
    gatillo y el pulgar por el otro lado; hand_open_right/left.glb: mano abierta y relajada.
    Origen en la muñeca.
Cada dedo es una cadena de tubos con una esfera del mismo radio en cada articulación, así sale de
la palma sin huecos ni piezas sueltas. El juego monta el esqueleto (hombro -> codo -> muñeca) con
estas piezas y lo anima por código. Medidas de un adulto delgado; reproducible.
"""

import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props import DARK, Model, export  # noqa: E402
from items import rod  # noqa: E402

SLEEVE = (0.13, 0.17, 0.27)
SLEEVE_DARK = (0.09, 0.12, 0.2)
PATCH = (0.72, 0.62, 0.22)
SKIN = (0.72, 0.55, 0.43)
SKIN_DARK = (0.64, 0.48, 0.37)
NAIL = (0.8, 0.66, 0.58)

UPPER_LENGTH = 0.28
FOREARM_LENGTH = 0.26
# Eje del mango de las armas cuerpo a cuerpo (debajo de la muñeca, como en el juego: GRIP_POINT)
# y eje de la empuñadura de las armas de fuego, en coordenadas de la muñeca.
GRIP_Y = -0.05
PISTOL_AXIS = (0.0, -0.095, -0.05)
# Lados de los tubos: suficientes para que de cerca no se vean facetas.
ROUND = 14
# Radio de los mangos que rodean los dedos.
HANDLE_RADIUS = 0.018


def tube(m: Model, a, b, r0: float, r1: float, rgb, segments: int = ROUND) -> None:
    """Tronco de cono entre dos puntos (coordenadas de Godot), de radio r0 en a y r1 en b."""
    pa = Vector((a[0], -a[2], a[1]))
    pb = Vector((b[0], -b[2], b[1]))
    length = (pb - pa).length
    if length < 1e-6:
        return
    direction = (pb - pa).normalized()
    # create_cone pone el radio 1 abajo (-Z local) y el 2 arriba: se alinea Z con a -> b.
    rot = Vector((0.0, 0.0, 1.0)).rotation_difference(direction).to_matrix().to_4x4()
    mat = Matrix.Translation((pa + pb) * 0.5) @ rot
    result = bmesh.ops.create_cone(
        m.bm, cap_ends=True, cap_tris=False, segments=segments, radius1=r0, radius2=r1,
        depth=length, matrix=mat)
    m._paint(m._faces_of(result), rgb)


def joint(m: Model, p, r: float, rgb) -> None:
    """Articulación: esfera del radio del tubo, para que los tramos se unan sin hueco."""
    m.sphere(r, p[0], p[1], p[2], rgb, segments=ROUND)


def finger(m: Model, points, radii, rgb, tip_rgb=NAIL) -> None:
    """Dedo como cadena: tramos entre puntos consecutivos y una esfera en cada punto. El último
    tramo termina en una yema algo más clara."""
    for i in range(len(points) - 1):
        tube(m, points[i], points[i + 1], radii[i], radii[i + 1], rgb)
        joint(m, points[i], radii[i], rgb)
    joint(m, points[-1], radii[-1], tip_rgb)


def palm(m: Model, center, size, thin: str, rgb) -> None:
    """Palma como losa de bordes redondeados (sección de estadio): caja con un tubo a lo largo de
    cada borde largo. size = (x, y, z) en metros; thin = eje fino ("x" o "y"). El largo va en z."""
    cx, cy, cz = center
    sx, sy, sz = size
    half_z = sz * 0.5
    if thin == "x":
        r = sx * 0.5
        m.box(sx, sy - sx, sz, cx, cy - (sy - sx) * 0.5, cz, rgb)
        for dy in (-(sy - sx) * 0.5, (sy - sx) * 0.5):
            tube(m, (cx, cy + dy, cz + half_z), (cx, cy + dy, cz - half_z), r, r, rgb)
    else:
        r = sy * 0.5
        m.box(sx - sy, sy, sz, cx, cy - r, cz, rgb)
        for dx in (-(sx - sy) * 0.5, (sx - sy) * 0.5):
            tube(m, (cx + dx, cy, cz + half_z), (cx + dx, cy, cz - half_z), r, r, rgb)


def wrist_to(m: Model, end, r_end: float, rgb=SKIN) -> None:
    """Talón de la mano: tubo continuo desde la muñeca (radio de la muñeca) hasta la palma."""
    tube(m, (0.0, 0.0, 0.0), end, 0.024, r_end, rgb)
    joint(m, end, r_end, rgb)


def upper_arm(m: Model) -> None:
    rod(m, 0.046, 0.041, 0.03, -UPPER_LENGTH, SLEEVE, segments=ROUND)
    m.sphere(0.048, 0, 0, 0, SLEEVE, segments=ROUND)
    # Parche del hombro (seguridad) en la cara exterior; se ve al girar el brazo.
    m.box(0.004, 0.05, 0.06, 0.046, 0.0, -0.07, PATCH)
    m.box(0.005, 0.03, 0.04, 0.047, 0.0, -0.07, SLEEVE_DARK)
    m.sphere(0.042, 0, 0, -UPPER_LENGTH, SLEEVE, segments=ROUND)


def forearm(m: Model, watch: bool) -> None:
    # Manga larga del uniforme hasta cerca de la muñeca: casi todo el antebrazo es azul.
    rod(m, 0.04, 0.034, 0.0, -0.19, SLEEVE, segments=ROUND)
    # Puño de la manga, algo más ancho y oscuro.
    rod(m, 0.037, 0.036, -0.19, -0.215, SLEEVE_DARK, segments=ROUND)
    # Muñeca (piel) que llega hasta la mano.
    rod(m, 0.028, 0.025, -0.215, -FOREARM_LENGTH, SKIN, segments=ROUND)
    if watch:
        rod(m, 0.03, 0.03, -0.222, -0.24, DARK, segments=ROUND)
        m.box(0.026, 0.01, 0.024, 0, 0.028, -0.231, (0.2, 0.2, 0.22))
        m.box(0.019, 0.003, 0.018, 0, 0.035, -0.231, (0.55, 0.62, 0.6))


def _ring(cx: float, cy: float, angle_deg: float, radius: float, side: float):
    """Punto (x, y) en un círculo alrededor del eje (cx, cy); 0 grados = lado exterior de la
    mano, 90 = arriba. side 1 derecha, -1 izquierda (refleja x)."""
    a = math.radians(angle_deg)
    return cx + math.cos(a) * radius * side, cy + math.sin(a) * radius


def hand_melee(m: Model, side: float) -> None:
    """Puño de cuerpo a cuerpo: el mango pasa a lo largo de -Z por debajo de la muñeca (eje en
    y = GRIP_Y). La palma queda en el lado exterior del mango y los cuatro dedos salen de ella,
    pasan por encima, bajan por el lado del pulgar y vuelven por debajo (índice delante). El
    pulgar cierra por el lado interior, sobre el índice."""
    # Talón: de la muñeca al dorso, que queda en el lado exterior del mango.
    wrist_to(m, (0.022 * side, GRIP_Y + 0.03, -0.04), 0.015)
    # Dorso y palma: losa vertical en el lado exterior, de los nudillos hacia la muñeca.
    palm(m, (0.026 * side, GRIP_Y + 0.006, -0.066), (0.02, 0.04, 0.06), "x", SKIN)
    lengths = (1.0, 1.04, 0.98, 0.86)
    for i in range(4):
        z = -0.094 + i * 0.0185
        r = 0.0088 - 0.0005 * i
        ring = HANDLE_RADIUS + r
        scale = lengths[i]
        # Nudillo en la palma (arriba y afuera), luego por encima, por el lado interior y debajo.
        angles = (40.0, 105.0, 175.0, 175.0 + 70.0 * scale)
        points = []
        for angle in angles:
            x, y = _ring(0.0, GRIP_Y, angle, ring, side)
            points.append((x, y, z))
        finger(m, points, (r * 1.08, r, r * 0.95, r * 0.88), SKIN if i % 2 == 0 else SKIN_DARK)
    # Pulgar: sale del talón por el lado interior y cierra sobre el índice.
    finger(
        m,
        [(-0.02 * side, -0.02, -0.035), (-0.026 * side, GRIP_Y + 0.016, -0.07),
         (-0.016 * side, GRIP_Y + 0.026, -0.098)],
        (0.012, 0.0105, 0.009),
        SKIN_DARK,
    )


def hand_pistol(m: Model, side: float) -> None:
    """Puño de arma de fuego: la empuñadura vertical (eje en PISTOL_AXIS) pasa entre la palma y
    los dedos. La palma rodea la parte de atrás y el lado exterior; corazón, anular y meñique
    salen de ella por delante hacia el lado del pulgar; el índice va estirado por el lado
    exterior hasta el gatillo y el pulgar sube por el lado interior."""
    ax, ay, az = PISTOL_AXIS
    # Talón: de la muñeca a la parte alta de la palma, detrás de la empuñadura.
    wrist_to(m, (ax + 0.02 * side, ay + 0.035, az + 0.03), 0.015)
    # Palma: losa vertical detrás y al lado exterior de la empuñadura.
    palm(m, (ax + 0.026 * side, ay - 0.004, az + 0.012), (0.02, 0.07, 0.034), "x", SKIN)
    lengths = (1.0, 0.95, 0.84)
    for i in range(3):
        y = ay - 0.004 - i * 0.0185
        r = 0.0088 - 0.0006 * i
        ring = HANDLE_RADIUS + r
        # Ángulos en el plano horizontal: 0 = exterior, 90 = delante (-Z), 180 = interior.
        angles = (20.0, 85.0, 150.0, 150.0 + 70.0 * lengths[i])
        points = []
        for angle in angles:
            a = math.radians(angle)
            points.append((ax + math.cos(a) * ring * side, y, az - math.sin(a) * ring))
        finger(m, points, (r * 1.08, r, r * 0.95, r * 0.88), SKIN if i % 2 == 0 else SKIN_DARK)
    # Índice: nudillo arriba y afuera, estirado por el costado y la punta curvada al gatillo.
    finger(
        m,
        [(ax + 0.025 * side, ay + 0.02, az - 0.006), (ax + 0.022 * side, ay + 0.02, az - 0.05),
         (ax + 0.014 * side, ay + 0.012, az - 0.072), (ax + 0.004 * side, ay + 0.004, az - 0.08)],
        (0.0095, 0.009, 0.0085, 0.008),
        SKIN,
    )
    # Pulgar: sale del talón por el lado interior y sube junto a la empuñadura.
    finger(
        m,
        [(-0.012 * side, -0.045, -0.028), (ax - 0.024 * side, ay + 0.03, az - 0.012),
         (ax - 0.02 * side, ay + 0.04, az - 0.045)],
        (0.012, 0.0105, 0.009),
        SKIN_DARK,
    )


def hand_open(m: Model, side: float) -> None:
    """Mano abierta y relajada: palma redondeada y cuatro dedos de tres falanges que salen de
    ella algo doblados hacia abajo; el pulgar sale del lado interior."""
    # Palma: losa horizontal de la muñeca a los nudillos.
    palm(m, (0.0, 0.0, -0.052), (0.078, 0.02, 0.07), "y", SKIN)
    wrist_to(m, (0.0, 0.0, -0.02), 0.02)
    lengths = (0.042, 0.048, 0.045, 0.036)
    for i in range(4):
        x = (-0.027 + i * 0.018) * side
        base = (x, 0.0, -0.088)
        length = lengths[i]
        r = 0.0088 - 0.0004 * i
        # Tres falanges con una curva suave hacia abajo (mano relajada).
        p1 = (x * 1.04, -0.004, base[2] - length * 0.5)
        p2 = (x * 1.06, -0.012, base[2] - length * 0.82)
        p3 = (x * 1.07, -0.022, base[2] - length * 1.0)
        finger(m, [base, p1, p2, p3], (r * 1.1, r, r * 0.93, r * 0.85),
               SKIN if i % 2 == 0 else SKIN_DARK)
    finger(
        m,
        [(-0.03 * side, -0.006, -0.03), (-0.05 * side, -0.01, -0.056),
         (-0.058 * side, -0.014, -0.078)],
        (0.012, 0.0105, 0.009),
        SKIN_DARK,
    )


MODELS = {
    "upper_arm": upper_arm,
    "forearm_right": lambda m: forearm(m, False),
    "forearm_left": lambda m: forearm(m, True),
    "hand_grip_right": lambda m: hand_melee(m, 1.0),
    "hand_grip_left": lambda m: hand_melee(m, -1.0),
    "hand_pistol_right": lambda m: hand_pistol(m, 1.0),
    "hand_pistol_left": lambda m: hand_pistol(m, -1.0),
    "hand_open_right": lambda m: hand_open(m, 1.0),
    "hand_open_left": lambda m: hand_open(m, -1.0),
}


def main() -> int:
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out_dir = os.path.join(root, "assets", "generated", "arms")
    os.makedirs(out_dir, exist_ok=True)
    for name in sorted(MODELS):
        export(name, MODELS[name], out_dir)
    print("arms: %d modelos" % len(MODELS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
