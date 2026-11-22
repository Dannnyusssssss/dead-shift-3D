"""Brazos del guardia en primera persona: piezas rígidas por hueso (color de vértice).

Uso: blender --background --factory-startup --python tools/blender/arms.py

Escribe en assets/generated/arms/:
  - upper_arm.glb: brazo con la manga del uniforme (origen en el hombro, apunta a -Z).
  - forearm_right.glb y forearm_left.glb: antebrazo con la manga larga hasta cerca de la muñeca
    y su puño (origen en el codo); el izquierdo lleva el reloj.
  - hand_grip_right/left.glb (puño alrededor de un mango), hand_pistol_right/left.glb (empuñadura
    de arma de fuego, índice en el gatillo) y hand_open_right/left.glb (mano relajada): la mano
    modelada del maniquí de Quaternius colocada con sus huesos (tools/blender/hands.py), con
    origen en la muñeca. Al exportar imprime dónde va cada arma en la mano (HOLD_FRAMES de
    game/actors/player/player_arms.gd).
El juego monta el esqueleto (hombro -> codo -> muñeca) con estas piezas y lo anima por código.
Medidas de un adulto delgado; reproducible.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hands  # noqa: E402
from glb_writer import write_glb  # noqa: E402
from items import rod  # noqa: E402
from props import DARK, Model, export  # noqa: E402

SLEEVE = (0.13, 0.17, 0.27)
SLEEVE_DARK = (0.09, 0.12, 0.2)
PATCH = (0.72, 0.62, 0.22)
SKIN = hands.SKIN
UPPER_LENGTH = 0.28
FOREARM_LENGTH = 0.26
# Lados de los cilindros: suficientes para que de cerca no se vean facetas.
ROUND = 14


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


MODELS = {
    "upper_arm": upper_arm,
    "forearm_right": lambda m: forearm(m, False),
    "forearm_left": lambda m: forearm(m, True),
}


def main() -> int:
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out_dir = os.path.join(root, "assets", "generated", "arms")
    os.makedirs(out_dir, exist_ok=True)
    for name in sorted(MODELS):
        export(name, MODELS[name], out_dir)
    # Las manos salen del maniquí (hands.py), que carga su propia escena: van al final.
    shapes, info = hands.build_all()
    for shape in sorted(shapes):
        right = shapes[shape]
        write_glb(os.path.join(out_dir, "hand_%s_right.glb" % shape), "hand_%s_right" % shape,
                  hands.to_triangles(right))
        write_glb(os.path.join(out_dir, "hand_%s_left.glb" % shape), "hand_%s_left" % shape,
                  hands.to_triangles(hands.mirror(right)))
    # Colocación de las armas en la mano para game/actors/player/player_arms.gd (HOLD_FRAMES).
    for key in sorted(info):
        value = info[key]
        if isinstance(value, float):
            print("agarre %s = %.4f" % (key, value))
        else:
            basis, origin = value
            columns = [[basis[r][c] for r in range(3)] for c in range(3)] + [list(origin)]
            vectors = ["Vector3(%s)" % ", ".join("%.4f" % n for n in col) for col in columns]
            print('agarre "%s": Transform3D(Basis(%s), %s),'
                  % (key, ", ".join(vectors[:3]), vectors[3]))
    print("arms: %d modelos y %d manos" % (len(MODELS), len(shapes) * 2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
