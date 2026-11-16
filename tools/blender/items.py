"""Armas y objetos de mano (modelos con color de vértice, sin texturas).

Uso: blender --background --factory-startup --python tools/blender/items.py

Escribe en assets/generated/items/:
  - <arma>_w0.glb, _w1.glb y _w2.glb: estado bueno, dañado y crítico. El desgaste se ve por
    forma y no solo por color: rayas y abolladuras (dañado); grietas, cinta y óxido (crítico).
  - <objeto>.glb: objetos que se sostienen al combinar, curarse o lanzar, y que se ven en el
    suelo al soltarlos.
Origen en el punto de agarre; el arma apunta hacia -Z de Godot (hacia delante). Reproducible.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props import CHROME, DARK, STEEL, WOOD, Model, export  # noqa: E402

RUST = (0.42, 0.22, 0.1)
TAPE_GRAY = (0.58, 0.58, 0.6)
CRACK = (0.05, 0.04, 0.03)
SCRATCH = (0.78, 0.78, 0.76)
CLOTH = (0.78, 0.75, 0.66)
RED_PAINT = (0.7, 0.1, 0.08)
GUN_METAL = (0.16, 0.16, 0.18)


def rod(m: Model, r0: float, r1: float, z_back: float, z_front: float, rgb, segments=8) -> None:
    """Cilindro (o tronco de cono) a lo largo de -Z, de z_back (radio r0) a z_front (radio r1)."""
    length = z_back - z_front
    center = (z_back + z_front) * 0.5
    m.cylinder(r0, r1, length, 0, -length * 0.5, center, rgb, segments=segments, rot_x=-90)


def wear_marks(m: Model, state: int, radius: float, z_from: float, z_to: float,
               base_dark: bool = False) -> None:
    """Marcas de desgaste a lo largo de un mango o cañón de radio dado."""
    if state <= 0:
        return
    span = z_from - z_to
    scratch = CRACK if not base_dark else SCRATCH
    # Dañado: rayas finas en la cara de arriba y a un lado.
    for i in range(3):
        z = z_from - span * (0.3 + 0.22 * i)
        m.box(0.004, 0.003, span * 0.12, radius * 0.4, radius * 0.98, z, scratch, rot_y=12 * i)
        m.box(0.003, span * 0.1, 0.004, radius * 0.99, -0.01 + 0.01 * i, z - 0.02, scratch)
    if state < 2:
        return
    # Crítico: grietas profundas, dos vueltas de cinta y manchas de óxido o suciedad.
    for i in range(3):
        z = z_from - span * (0.45 + 0.15 * i)
        m.box(radius * 2.15, 0.006, 0.006, 0, radius * 0.2 * (i - 1), z, CRACK, rot_z=35 * (i - 1))
    for z in (z_from - span * 0.35, z_from - span * 0.62):
        rod(m, radius * 1.12, radius * 1.12, z + 0.02, z - 0.02, TAPE_GRAY, segments=8)
    for i in range(2):
        m.box(radius * 0.9, 0.004, 0.03, -radius * 0.3, radius * 1.0,
              z_from - span * (0.55 + 0.2 * i), RUST)


def knife(m: Model, state: int) -> None:
    m.box(0.024, 0.03, 0.11, 0, -0.015, 0.0, DARK)
    m.box(0.05, 0.036, 0.012, 0, -0.018, -0.058, STEEL)
    m.box(0.004, 0.03, 0.16, 0, -0.012, -0.144, CHROME)
    m.box(0.004, 0.018, 0.05, 0, -0.012, -0.24, CHROME, rot_x=-14)
    if state >= 1:
        m.box(0.0045, 0.004, 0.08, 0, 0.012, -0.15, CRACK)
    if state >= 2:
        m.box(0.0045, 0.012, 0.02, 0, -0.024, -0.12, CRACK)
        m.box(0.0045, 0.01, 0.015, 0, -0.024, -0.19, CRACK)
        rod(m, 0.02, 0.02, 0.03, -0.01, TAPE_GRAY)


def bat(m: Model, state: int, nails: bool = False) -> None:
    rod(m, 0.03, 0.03, 0.14, 0.12, WOOD, segments=10)
    rod(m, 0.018, 0.036, 0.12, -0.73, WOOD, segments=10)
    rod(m, 0.02, 0.02, 0.06, -0.06, DARK, segments=10)
    if nails:
        for i in range(8):
            z = -0.5 - 0.025 * i
            if i % 2 == 0:
                m.box(0.004, 0.09, 0.004, 0, 0.0, z, CHROME, rot_z=45 * i)
            else:
                m.box(0.09, 0.004, 0.004, 0, 0.0, z, CHROME, rot_y=20 * i)
    wear_marks(m, state, 0.033, -0.1, -0.72)


def pipe(m: Model, state: int, grip: bool = False, nails: bool = False) -> None:
    rod(m, 0.02, 0.02, 0.1, -0.7, STEEL, segments=8)
    rod(m, 0.024, 0.024, 0.1, 0.07, (0.3, 0.31, 0.33), segments=8)
    rod(m, 0.024, 0.024, -0.67, -0.7, (0.3, 0.31, 0.33), segments=8)
    if grip:
        rod(m, 0.028, 0.028, 0.08, -0.14, CLOTH, segments=8)
        for z in (0.06, -0.04, -0.12):
            rod(m, 0.03, 0.03, z + 0.008, z - 0.008, TAPE_GRAY, segments=8)
    if nails:
        for i in range(8):
            z = -0.5 - 0.022 * i
            if i % 2 == 0:
                m.box(0.004, 0.075, 0.004, 0, 0.0, z, CHROME, rot_z=45 * i)
            else:
                m.box(0.075, 0.004, 0.004, 0, 0.0, z, CHROME)
    wear_marks(m, state, 0.02, -0.15, -0.66, base_dark=False)


def pistol(m: Model, state: int) -> None:
    m.box(0.03, 0.11, 0.045, 0, -0.1, 0.01, GUN_METAL, rot_x=14)
    m.box(0.032, 0.036, 0.2, 0, 0.0, -0.06, (0.22, 0.22, 0.24))
    m.box(0.028, 0.02, 0.17, 0, -0.025, -0.05, GUN_METAL)
    rod(m, 0.007, 0.007, -0.16, -0.17, DARK, segments=6)
    m.bar(0, -0.035, -0.0, 0, -0.06, -0.04, 0.006, GUN_METAL)
    m.box(0.004, 0.012, 0.004, 0, 0.038, -0.15, (0.8, 0.8, 0.75))
    if state >= 1:
        for i in range(3):
            m.box(0.033, 0.003, 0.02, 0, 0.037, -0.03 - 0.05 * i, SCRATCH)
    if state >= 2:
        m.box(0.034, 0.03, 0.03, 0, -0.07, 0.005, TAPE_GRAY, rot_x=14)
        m.box(0.033, 0.012, 0.03, 0, 0.012, -0.12, RUST)


def shotgun(m: Model, state: int) -> None:
    m.box(0.04, 0.09, 0.26, 0, -0.06, 0.2, WOOD, rot_x=-8)
    m.box(0.045, 0.06, 0.16, 0, -0.01, 0.0, GUN_METAL)
    m.box(0.022, 0.06, 0.03, 0, -0.07, 0.04, GUN_METAL)
    rod(m, 0.013, 0.013, -0.08, -0.62, (0.2, 0.2, 0.22), segments=8)
    rod(m, 0.011, 0.011, -0.08, -0.5, (0.25, 0.25, 0.27), segments=8)
    m.box(0.045, 0.045, 0.16, 0, -0.045, -0.3, (0.42, 0.28, 0.16))
    if state >= 1:
        m.box(0.041, 0.004, 0.12, 0.0, -0.016, 0.22, CRACK, rot_x=-8)
        m.box(0.046, 0.003, 0.03, 0, 0.032, -0.02, SCRATCH)
    if state >= 2:
        rod(m, 0.017, 0.017, -0.4, -0.44, TAPE_GRAY, segments=8)
        m.box(0.042, 0.03, 0.05, 0, -0.04, 0.25, TAPE_GRAY, rot_x=-8)
        m.box(0.046, 0.02, 0.05, 0, 0.0, 0.03, RUST)


def extinguisher(m: Model, state: int) -> None:
    rod(m, 0.07, 0.07, 0.04, -0.36, RED_PAINT, segments=12)
    rod(m, 0.05, 0.03, -0.36, -0.4, RED_PAINT, segments=12)
    rod(m, 0.015, 0.015, -0.4, -0.45, DARK, segments=6)
    m.box(0.02, 0.02, 0.12, 0, 0.075, -0.38, DARK)
    m.bar(0.0, 0.0, -0.44, 0.05, -0.02, -0.5, 0.012, DARK)
    m.box(0.1, 0.004, 0.12, 0, 0.0705, -0.16, (0.92, 0.9, 0.84))
    if state >= 1:
        for i in range(3):
            m.box(0.02, 0.004, 0.06, 0.03, 0.068, -0.05 - 0.09 * i, SCRATCH, rot_y=25)
    if state >= 2:
        m.box(0.12, 0.03, 0.05, 0, -0.06, -0.1, (0.3, 0.06, 0.05))
        m.box(0.05, 0.004, 0.08, -0.03, 0.07, -0.28, RUST)


def baton(m: Model) -> None:
    """Porra reglamentaria: mango de goma con tope y cuerpo negro. No se desgasta: un solo
    modelo (sin estados de desgaste)."""
    rod(m, 0.022, 0.022, 0.1, 0.085, (0.12, 0.12, 0.13), segments=10)
    rod(m, 0.017, 0.017, 0.085, -0.08, (0.2, 0.2, 0.22), segments=10)
    for z in (0.05, 0.0, -0.05):
        rod(m, 0.0185, 0.0185, z + 0.006, z - 0.006, (0.14, 0.14, 0.15), segments=10)
    rod(m, 0.015, 0.016, -0.08, -0.5, (0.08, 0.08, 0.09), segments=10)
    rod(m, 0.017, 0.017, -0.5, -0.52, (0.1, 0.1, 0.11), segments=10)


WEAPONS = {
    "knife": knife,
    "bat": lambda m, s: bat(m, s),
    "bat_nails": lambda m, s: bat(m, s, nails=True),
    "pipe": lambda m, s: pipe(m, s),
    "pipe_grip": lambda m, s: pipe(m, s, grip=True),
    "pipe_nails": lambda m, s: pipe(m, s, nails=True),
    "pistol": pistol,
    "shotgun": shotgun,
    "extinguisher": extinguisher,
}


# ---------------------------------------------------------------- objetos


def nails(m: Model) -> None:
    m.box(0.06, 0.035, 0.12, 0, -0.018, -0.03, (0.62, 0.5, 0.3))
    m.box(0.062, 0.012, 0.08, 0, 0.005, -0.03, (0.82, 0.8, 0.72))
    for i in range(4):
        m.box(0.003, 0.003, 0.05, -0.02 + i * 0.013, 0.02, -0.03, CHROME)


def rag(m: Model) -> None:
    m.box(0.14, 0.02, 0.12, 0, -0.01, -0.05, CLOTH, rot_y=8)
    m.box(0.1, 0.012, 0.08, 0.01, 0.008, -0.05, (0.7, 0.66, 0.56), rot_y=-14)


def tape(m: Model) -> None:
    m.cylinder(0.05, 0.05, 0.045, 0, -0.022, -0.05, TAPE_GRAY, segments=12, rot_z=90)
    m.cylinder(0.028, 0.028, 0.047, 0, -0.023, -0.05, (0.5, 0.42, 0.3), segments=10, rot_z=90)


def bottle(m: Model, rag_top: bool = False) -> None:
    glass = (0.24, 0.42, 0.26)
    m.cylinder(0.032, 0.032, 0.15, 0, -0.06, 0.0, glass, segments=10)
    m.cylinder(0.03, 0.012, 0.04, 0, 0.09, 0.0, glass, segments=10)
    m.cylinder(0.012, 0.012, 0.04, 0, 0.13, 0.0, glass, segments=8)
    if rag_top:
        m.box(0.035, 0.06, 0.03, 0, 0.16, 0.0, CLOTH, rot_z=12)


def bandage(m: Model, improvised: bool = False) -> None:
    color = CLOTH if improvised else (0.93, 0.93, 0.9)
    m.cylinder(0.035, 0.035, 0.08, 0, -0.04, -0.04, color, segments=10, rot_z=90)
    if improvised:
        m.cylinder(0.038, 0.038, 0.02, 0, -0.01, -0.04, TAPE_GRAY, segments=10, rot_z=90)
    else:
        m.box(0.05, 0.004, 0.03, 0, 0.033, -0.04, (0.75, 0.1, 0.1))


def antibiotics(m: Model) -> None:
    m.cylinder(0.025, 0.025, 0.07, 0, -0.03, -0.03, (0.9, 0.86, 0.78), segments=10)
    m.cylinder(0.027, 0.027, 0.02, 0, 0.04, -0.03, (0.9, 0.5, 0.15), segments=10)
    m.box(0.052, 0.035, 0.002, 0, -0.01, -0.004, (0.95, 0.95, 0.95))


def neutrax(m: Model) -> None:
    rod(m, 0.014, 0.014, 0.05, -0.08, (0.85, 0.88, 0.9), segments=8)
    rod(m, 0.011, 0.011, -0.04, -0.07, (0.4, 0.68, 0.92), segments=8)
    rod(m, 0.016, 0.016, 0.06, 0.03, (0.2, 0.45, 0.75), segments=8)
    rod(m, 0.004, 0.002, -0.08, -0.1, CHROME, segments=6)


def antiviral_vial(m: Model) -> None:
    """Vial de cristal con líquido azul y tapón de goma con precinto."""
    rod(m, 0.016, 0.016, 0.03, -0.03, (0.75, 0.85, 0.9), segments=10)
    rod(m, 0.0145, 0.0145, 0.02, -0.02, (0.3, 0.55, 0.9), segments=10)
    rod(m, 0.012, 0.012, -0.03, -0.045, (0.55, 0.12, 0.12), segments=10)
    rod(m, 0.013, 0.013, -0.045, -0.05, CHROME, segments=10)


def syringe(m: Model) -> None:
    """Jeringa precintada: cuerpo transparente, émbolo y aguja con capuchón."""
    rod(m, 0.011, 0.011, 0.04, -0.05, (0.85, 0.88, 0.9), segments=8)
    rod(m, 0.004, 0.004, 0.09, 0.04, (0.9, 0.9, 0.9), segments=6)
    m.box(0.03, 0.004, 0.006, 0, 0, 0.09, (0.9, 0.9, 0.9))
    m.box(0.034, 0.004, 0.006, 0, 0, 0.04, (0.9, 0.9, 0.9))
    rod(m, 0.004, 0.003, -0.05, -0.08, (0.3, 0.6, 0.85), segments=6)


def batteries(m: Model) -> None:
    for x in (-0.016, 0.016):
        m.cylinder(0.014, 0.014, 0.05, x, -0.025, -0.03, (0.15, 0.15, 0.17), segments=8)
        m.cylinder(0.0145, 0.0145, 0.018, x, 0.008, -0.03, (0.85, 0.6, 0.15), segments=8)


def ammo_box(m: Model, shells: bool = False) -> None:
    color = (0.55, 0.12, 0.1) if shells else (0.3, 0.35, 0.22)
    m.box(0.09, 0.05, 0.06, 0, 0, 0, color)
    m.box(0.092, 0.012, 0.04, 0, 0.02, 0, (0.85, 0.8, 0.6))


VEST = (0.18, 0.2, 0.22)
VEST_DARK = (0.12, 0.13, 0.14)
VEST_STRAP = (0.09, 0.09, 0.1)


def vest(m: Model) -> None:
    """Chaleco tendido en el suelo, visto desde arriba: cuerpo con sisas, cuello en V, hombreras,
    bolsillos y la franja clara del pecho."""
    # Parte baja (a todo lo ancho) y parte alta más estrecha: quedan las sisas a los lados.
    m.box(0.4, 0.035, 0.22, 0, 0, 0.08, VEST)
    m.box(0.3, 0.035, 0.12, 0, 0, -0.09, VEST)
    # Hombreras a cada lado del cuello (el hueco del centro es el cuello).
    for x in (-0.1, 0.1):
        m.box(0.09, 0.035, 0.12, x, 0, -0.2, VEST)
        m.box(0.07, 0.012, 0.1, x, 0.035, -0.2, VEST_STRAP)
    # Cuello en V: dos piezas oscuras en diagonal.
    m.box(0.12, 0.006, 0.02, -0.045, 0.035, -0.13, VEST_DARK, rot_y=35)
    m.box(0.12, 0.006, 0.02, 0.045, 0.035, -0.13, VEST_DARK, rot_y=-35)
    # Bolsillos y franja.
    for x in (-0.12, 0.0, 0.12):
        m.box(0.09, 0.03, 0.08, x, 0.035, 0.13, VEST_DARK)
        m.box(0.09, 0.008, 0.025, x, 0.065, 0.1, VEST_STRAP)
    m.box(0.26, 0.006, 0.05, 0, 0.035, 0.0, (0.85, 0.85, 0.8))
    # Cinchas laterales sueltas.
    for x in (-0.21, 0.21):
        m.box(0.03, 0.01, 0.16, x, 0, 0.06, VEST_STRAP)


def vest_worn(m: Model) -> None:
    """Chaleco puesto, ceñido al torso (origen en su centro, frente hacia -Z): peto y espaldar,
    laterales, hombreras por encima de los hombros, cuello abierto y bolsillos en el pecho."""
    w, h, d = 0.42, 0.42, 0.28
    plate = 0.035
    # Peto y espaldar, con el cuello abierto arriba (dos piezas a los lados del cuello).
    m.box(w, h - 0.08, plate, 0, -h / 2, -d / 2, VEST)
    m.box(w, h - 0.06, plate, 0, -h / 2, d / 2, VEST)
    for x in (-0.13, 0.13):
        m.box(0.12, 0.08, plate, x, h / 2 - 0.08, -d / 2, VEST)
    # Laterales (algo más bajos que el peto, por debajo de las axilas).
    for x in (-w / 2, w / 2):
        m.box(plate, h - 0.14, d, x, -h / 2, 0, VEST_DARK)
    # Hombreras: van del peto al espaldar por encima de los hombros.
    for x in (-0.13, 0.13):
        m.box(0.08, plate, d + plate, x, h / 2 - 0.005, 0, VEST_STRAP)
    # Bolsillos del pecho y franja clara.
    for x in (-0.12, 0.0, 0.12):
        m.box(0.09, 0.09, 0.03, x, -0.17, -d / 2 - 0.03, VEST_DARK)
        m.box(0.09, 0.025, 0.012, x, -0.08, -d / 2 - 0.036, VEST_STRAP)
    m.box(0.3, 0.05, 0.006, 0, 0.0, -d / 2 - 0.02, (0.85, 0.85, 0.8))
    # Cincha de la cintura.
    m.box(w + 0.02, 0.03, d + 0.02, 0, -h / 2 + 0.02, 0, VEST_STRAP)


def key(m: Model, color) -> None:
    m.cylinder(0.02, 0.02, 0.006, 0, 0, 0.03, color, segments=10)
    m.box(0.008, 0.006, 0.06, 0, 0, -0.01, CHROME)
    m.box(0.012, 0.006, 0.008, 0.006, 0, -0.03, CHROME)


def phone_part(m: Model, kind: str) -> None:
    if kind == "board":
        m.box(0.1, 0.006, 0.07, 0, 0, 0, (0.1, 0.36, 0.18))
        for i in range(3):
            m.box(0.018, 0.008, 0.018, -0.03 + i * 0.03, 0.006, 0.01, DARK)
    elif kind == "battery":
        m.box(0.06, 0.012, 0.09, 0, 0, 0, (0.18, 0.18, 0.2))
        m.box(0.062, 0.002, 0.03, 0, 0.007, 0.0, (0.8, 0.6, 0.15))
    else:
        rod(m, 0.006, 0.004, 0.02, -0.14, DARK, segments=6)
        m.box(0.02, 0.015, 0.02, 0, 0, 0.03, (0.3, 0.3, 0.32))


def mall_map(m: Model) -> None:
    m.box(0.16, 0.004, 0.11, 0, 0, 0, (0.88, 0.85, 0.76), rot_y=6)
    m.box(0.06, 0.005, 0.04, 0.02, 0.001, 0.01, (0.4, 0.55, 0.7), rot_y=6)


ITEMS = {
    "nails": nails,
    "rag": rag,
    "tape": tape,
    "bottle": bottle,
    "noise_bottle": lambda m: bottle(m, rag_top=True),
    "bandage": bandage,
    "improvised_bandage": lambda m: bandage(m, improvised=True),
    "antibiotics": antibiotics,
    "neutrax": neutrax,
    "batteries": batteries,
    "pistol_ammo": ammo_box,
    "shotgun_shells": lambda m: ammo_box(m, shells=True),
    "vest": vest,
    "vest_worn": vest_worn,
    "baton": baton,
    "antiviral_vial": antiviral_vial,
    "syringe": syringe,
    "security_key": lambda m: key(m, (0.2, 0.4, 0.75)),
    "roof_key": lambda m: key(m, (0.75, 0.2, 0.15)),
    "phone_board": lambda m: phone_part(m, "board"),
    "phone_battery": lambda m: phone_part(m, "battery"),
    "phone_antenna": lambda m: phone_part(m, "antenna"),
    "mall_map": mall_map,
}


def main() -> int:
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out_dir = os.path.join(root, "assets", "generated", "items")
    os.makedirs(out_dir, exist_ok=True)
    count = 0
    for name in sorted(WEAPONS):
        for state in range(3):
            export("%s_w%d" % (name, state), lambda m, n=name, s=state: WEAPONS[n](m, s), out_dir)
            count += 1
    for name in sorted(ITEMS):
        export(name, ITEMS[name], out_dir)
        count += 1
    print("items: %d modelos" % count)
    return 0


if __name__ == "__main__":
    sys.exit(main())
