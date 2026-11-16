"""Brazos del guardia en primera persona: piezas rígidas por hueso (color de vértice).

Uso: blender --background --factory-startup --python tools/blender/arms.py

Escribe en assets/generated/arms/:
  - upper_arm.glb: brazo con la manga del uniforme (origen en el hombro, apunta a -Z).
  - forearm_right.glb y forearm_left.glb: antebrazo con el puño de la manga (origen en el
    codo); el izquierdo lleva el reloj.
  - hand_grip_right/left.glb: puño de cuerpo a cuerpo, con los dedos apilados a lo largo del
    mango (que pasa por debajo de la muñeca); hand_pistol_right/left.glb: puño de arma de fuego,
    con la empuñadura vertical y el índice en el gatillo; hand_open_right/left.glb: mano
    abierta. Origen en la muñeca.
El juego monta el esqueleto (hombro -> codo -> muñeca) con estas piezas y lo anima por código.
Medidas de un adulto; reproducible.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props import DARK, Model, export  # noqa: E402
from items import rod  # noqa: E402

SLEEVE = (0.13, 0.17, 0.27)
SLEEVE_DARK = (0.09, 0.12, 0.2)
PATCH = (0.72, 0.62, 0.22)
SKIN = (0.72, 0.55, 0.43)
SKIN_DARK = (0.6, 0.44, 0.34)
NAIL = (0.82, 0.68, 0.6)

UPPER_LENGTH = 0.28
FOREARM_LENGTH = 0.26
# Eje del mango de las armas cuerpo a cuerpo (debajo de la muñeca, como en el juego: GRIP_POINT)
# y eje de la empuñadura de las armas de fuego, en coordenadas de la muñeca.
GRIP_Y = -0.05
PISTOL_AXIS = (0.0, -0.095, -0.05)


def upper_arm(m: Model) -> None:
    rod(m, 0.055, 0.048, 0.03, -UPPER_LENGTH, SLEEVE, segments=16)
    m.sphere(0.058, 0, 0, 0, SLEEVE, segments=16)
    # Parche del hombro (seguridad) en la cara exterior; se ve al girar el brazo.
    m.box(0.004, 0.05, 0.06, 0.055, 0.0, -0.07, PATCH)
    m.box(0.005, 0.03, 0.04, 0.056, 0.0, -0.07, SLEEVE_DARK)
    m.sphere(0.05, 0, 0, -UPPER_LENGTH, SLEEVE, segments=16)


def forearm(m: Model, watch: bool) -> None:
    rod(m, 0.047, 0.042, 0.0, -0.1, SLEEVE, segments=16)
    rod(m, 0.05, 0.05, -0.1, -0.13, SLEEVE_DARK, segments=16)
    rod(m, 0.038, 0.03, -0.13, -FOREARM_LENGTH, SKIN, segments=16)
    if watch:
        rod(m, 0.034, 0.034, -0.2, -0.225, DARK, segments=16)
        m.box(0.03, 0.012, 0.03, 0, 0.032, -0.2125, (0.2, 0.2, 0.22))
        m.box(0.022, 0.003, 0.022, 0, 0.039, -0.2125, (0.55, 0.62, 0.6))


def cyl(m: Model, r0: float, r1: float, h: float, x: float, y: float, z: float, rgb,
        segments=8, rot_x=0.0, rot_z=0.0, squash_z=1.0) -> None:
    """Cilindro de alto h con el centro en (x, y, z) (Model.cylinder recibe la base en y)."""
    m.cylinder(r0, r1, h, x, y - h * 0.5, z, rgb, segments=segments, rot_x=rot_x, rot_z=rot_z,
               squash_z=squash_z)


def _finger_ring(m: Model, side: float, along: float, axis: str, center, radius: float,
                 width: float, rgb) -> None:
    """Un dedo doblado alrededor de un mango: tres falanges (cilindros cortos) que rodean el eje
    del mango por delante, por el lado del pulgar y por debajo, y nudillos redondeados.

    axis "z": mango a lo largo de -Z (cuerpo a cuerpo); el dedo está en z = along.
    axis "y": mango vertical (empuñadura de pistola); el dedo está a la altura y = along.
    center: (x, y, z) del eje del mango; side 1 derecha, -1 izquierda."""
    cx, cy, cz = center
    r = radius + 0.009
    if axis == "z":
        # Falange 1: sale del nudillo (lado exterior, arriba) y pasa por encima del mango.
        cyl(m, 0.0085, 0.008, 0.034, cx + 0.004 * side, cy + r, along, rgb, segments=8,
                   rot_z=90)
        m.sphere(0.0095, cx + 0.022 * side, cy + r, along, rgb, segments=8)
        # Falange 2: baja por el lado del pulgar.
        cyl(m, 0.008, 0.0075, 0.03, cx - r * side, cy - 0.002, along, rgb, segments=8)
        m.sphere(0.0085, cx - r * side, cy + r - 0.004, along, rgb, segments=8)
        # Falange 3 (punta): vuelve por debajo del mango hacia la palma.
        cyl(m, 0.0072, 0.0065, 0.022, cx - 0.006 * side, cy - r, along, rgb, segments=8,
                   rot_z=90)
        m.sphere(0.0075, cx - r * side + 0.003 * side, cy - r + 0.004, along, rgb, segments=8)
    else:
        # Mango vertical: el dedo rodea el eje por delante (-Z), por el lado del pulgar y vuelve.
        cyl(m, 0.0085, 0.008, 0.034, cx + 0.004 * side, along, cz - r, rgb, segments=8,
                   rot_z=90)
        m.sphere(0.0095, cx + 0.022 * side, along, cz - r, rgb, segments=8)
        cyl(m, 0.008, 0.0075, 0.03, cx - r * side, along, cz - 0.002, rgb, segments=8,
                   rot_x=90)
        m.sphere(0.0085, cx - r * side, along, cz - r + 0.004, rgb, segments=8)
        cyl(m, 0.0072, 0.0065, 0.02, cx - 0.006 * side, along, cz + r, rgb, segments=8,
                   rot_z=90)


def hand_melee(m: Model, side: float) -> None:
    """Puño de cuerpo a cuerpo: el mango pasa a lo largo de -Z por debajo de la muñeca (eje en
    y = GRIP_Y) y los cuatro dedos lo rodean apilados a lo largo del mango (índice delante),
    como se agarra un bate o una espada. El pulgar cierra por el otro lado."""
    axis = (0.0, GRIP_Y, 0.0)
    # Dorso de la mano en el lado exterior, uniendo la muñeca con los nudillos.
    m.box(0.024, 0.06, 0.09, 0.03 * side, GRIP_Y + 0.012, -0.058, SKIN)
    cyl(m, 0.026, 0.024, 0.05, 0.022 * side, -0.005, -0.012, SKIN, segments=12, rot_x=90,
               squash_z=0.7)
    for i in range(4):
        z = -0.097 + i * 0.019
        radius = 0.019 - 0.0012 * i
        _finger_ring(m, side, z, "z", axis, radius, 0.017, SKIN if i % 2 == 0 else SKIN_DARK)
    # Pulgar: por el lado interior, sobre el índice.
    cyl(m, 0.0095, 0.009, 0.045, -0.02 * side, GRIP_Y + 0.024, -0.075, SKIN_DARK,
               segments=8, rot_x=90)
    m.sphere(0.0095, -0.02 * side, GRIP_Y + 0.024, -0.098, NAIL, segments=8)


def hand_pistol(m: Model, side: float) -> None:
    """Puño de arma de fuego: la empuñadura vertical pasa entre la palma y los dedos (eje en
    PISTOL_AXIS), con tres dedos apilados alrededor y el índice estirado hacia el gatillo."""
    ax, ay, az = PISTOL_AXIS
    # Palma y dorso del lado exterior, que suben hasta la muñeca.
    m.box(0.024, 0.085, 0.07, ax + 0.03 * side, ay + 0.012, az + 0.005, SKIN)
    cyl(m, 0.03, 0.026, 0.06, 0.016 * side, -0.03, -0.012, SKIN, segments=12,
               squash_z=0.7)
    for i in range(3):
        y = ay - 0.006 - i * 0.019
        _finger_ring(m, side, y, "y", PISTOL_AXIS, 0.02, 0.017,
                     SKIN if i % 2 == 0 else SKIN_DARK)
    # Índice estirado por el costado hasta el gatillo.
    cyl(m, 0.0085, 0.0075, 0.06, ax - 0.022 * side, ay + 0.022, az - 0.045, SKIN,
               segments=8, rot_x=90)
    m.sphere(0.008, ax - 0.022 * side, ay + 0.022, az - 0.075, NAIL, segments=8)
    # Pulgar por el otro lado, arriba.
    cyl(m, 0.0095, 0.009, 0.045, ax + 0.02 * side, ay + 0.04, az - 0.03, SKIN_DARK,
               segments=8, rot_x=90)


def hand_open(m: Model, side: float) -> None:
    """Mano abierta y algo relajada: palma redondeada, dedos de dos falanges y pulgar."""
    m.box(0.074, 0.028, 0.075, 0, 0, -0.045, SKIN)
    cyl(m, 0.037, 0.037, 0.028, 0, -0.014, -0.045, SKIN, segments=14, squash_z=1.05)
    for i in range(4):
        x = (-0.027 + i * 0.018) * side
        length = (0.04, 0.046, 0.044, 0.036)[i]
        rgb = SKIN if i % 2 == 0 else SKIN_DARK
        m.sphere(0.0095, x, 0.0, -0.085, rgb, segments=8)
        rod(m, 0.0085, 0.008, -0.085, -0.085 - length * 0.55, rgb, segments=8)
        # Segunda falange algo doblada hacia abajo.
        cyl(m, 0.0078, 0.007, length * 0.5, x, -0.006 - length * 0.12,
                   -0.085 - length * 0.78, rgb, segments=8, rot_x=-70)
    cyl(m, 0.01, 0.009, 0.05, -0.045 * side, -0.006, -0.05, SKIN_DARK, segments=8,
               rot_x=-90, rot_z=-35 * side)


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
