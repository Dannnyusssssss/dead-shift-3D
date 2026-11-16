"""Helicóptero de rescate y piezas de la sala de control de la central (intro).

Uso: blender --background --factory-startup --python tools/blender/vehicles.py

Escribe en assets/generated/vehicles/:
  - helicopter_body.glb: fuselaje (morro hacia -X de Godot, cola hacia +X), patines, puerta
    abierta en el lado +Z; sin insignias ni marcas reales.
  - helicopter_rotor.glb y helicopter_tail_rotor.glb: rotores aparte para girarlos.
  - control_console.glb y control_wall.glb: consola con pantallas y panel mural de la sala de
    control (escena de la intro).
Origen: base del modelo en el suelo (rotores: en su eje). Reproducible.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from props import CHROME, DARK, SCREEN, STEEL, Model, export  # noqa: E402

PAINT = (0.85, 0.42, 0.12)
WHITE = (0.86, 0.86, 0.84)
GLASS = (0.1, 0.16, 0.2)
INTERIOR = (0.06, 0.06, 0.07)


def along_x(m: Model, r_tail: float, r_nose: float, x_tail: float, x_nose: float, y: float,
            rgb, segments=14) -> None:
    """Tronco de cono a lo largo del eje X, de x_tail (radio r_tail) a x_nose (radio r_nose)."""
    length = x_tail - x_nose
    m.cylinder(r_tail, r_nose, length, (x_tail + x_nose) * 0.5, y - length * 0.5, 0, rgb,
               segments=segments, rot_z=90)


def helicopter_body(m: Model) -> None:
    # Fuselaje: cabina redondeada delante y cuerpo que se estrecha hacia la cola.
    m.sphere(1.0, -1.5, 1.45, 0, GLASS, sy=0.95, sz=0.95, segments=14)
    along_x(m, 0.75, 1.0, 1.4, -1.5, 1.45, PAINT)
    m.box(2.2, 0.5, 1.9, -0.1, 0.55, 0, WHITE)
    m.box(1.7, 0.5, 1.2, 0.2, 2.35, 0, WHITE)
    m.cylinder(0.3, 0.25, 0.25, 0.3, 2.85, 0, DARK, segments=10)
    # Puerta abierta en el lado +Z (por donde sube el guardia) y ventanillas.
    m.box(1.2, 1.2, 0.04, 0.1, 0.95, 0.99, INTERIOR)
    m.box(0.5, 0.45, 0.03, 1.0, 1.6, 0.85, GLASS)
    m.box(0.5, 0.45, 0.03, 1.0, 1.6, -0.85, GLASS)
    m.box(2.6, 0.12, 0.03, -0.3, 1.0, 1.0, WHITE)
    m.box(2.6, 0.12, 0.03, -0.3, 1.0, -1.0, WHITE)
    # Cola: viga, deriva y estabilizador.
    along_x(m, 0.18, 0.4, 5.6, 1.4, 1.75, PAINT, segments=10)
    m.box(0.7, 1.1, 0.08, 5.5, 1.75, 0, PAINT)
    m.box(0.5, 0.06, 1.3, 5.0, 1.7, 0, WHITE)
    # Patines y sus soportes.
    for z in (-0.9, 0.9):
        along_x(m, 0.05, 0.05, 1.5, -2.1, 0.05, STEEL, segments=6)
        m.bar(-1.2, 0.05, z, -1.0, 0.6, z * 0.75, 0.06, STEEL)
        m.bar(0.8, 0.05, z, 0.6, 0.6, z * 0.75, 0.06, STEEL)
        m.box(3.6, 0.1, 0.1, -0.3, 0.0, z, STEEL)
    # Luz de búsqueda bajo el morro (apagada) y antena.
    m.cylinder(0.12, 0.12, 0.15, -1.9, 0.6, 0, CHROME, segments=8)
    m.box(0.04, 0.4, 0.04, 0.9, 2.85, 0.3, DARK)


def helicopter_rotor(m: Model) -> None:
    m.cylinder(0.25, 0.25, 0.15, 0, -0.075, 0, STEEL, segments=10)
    # Cuatro palas: dos cajas largas cruzadas que pasan por el eje.
    for angle in (0, 90):
        m.box(7.8, 0.04, 0.26, 0, -0.02, 0, DARK, rot_y=angle)


def helicopter_tail_rotor(m: Model) -> None:
    m.cylinder(0.08, 0.08, 0.12, 0, -0.06, 0, STEEL, segments=8, rot_x=90)
    m.box(0.12, 1.1, 0.03, 0, -0.55, 0, DARK)
    m.box(1.1, 0.12, 0.03, 0, -0.06, 0, DARK)


def control_console(m: Model) -> None:
    """Consola de 3 m con pupitre inclinado, pantallas y botoneras."""
    m.box(3.0, 0.75, 0.8, 0, 0, 0, (0.32, 0.34, 0.36))
    m.box(3.0, 0.06, 0.55, 0, 0.75, 0.05, (0.2, 0.22, 0.24), rot_x=-15)
    for i in range(3):
        x = -1.0 + i
        m.box(0.7, 0.45, 0.05, x, 0.9, -0.28, DARK, rot_x=-8)
        m.box(0.64, 0.38, 0.01, x, 0.935, -0.25, SCREEN, rot_x=-8)
        for j in range(5):
            color = [(0.75, 0.15, 0.1), (0.2, 0.6, 0.25), (0.85, 0.7, 0.2)][(i + j) % 3]
            m.box(0.06, 0.02, 0.06, x - 0.24 + j * 0.12, 0.8, 0.15, color)


def control_wall(m: Model) -> None:
    """Panel mural de 6 x 3 m con esquema de la planta y pilotos."""
    m.box(6.0, 3.0, 0.15, 0, 0, 0, (0.24, 0.26, 0.28))
    m.box(3.2, 1.8, 0.02, -1.0, 0.8, 0.085, SCREEN)
    m.box(1.4, 0.04, 0.025, -1.6, 1.8, 0.09, (0.3, 0.6, 0.8))
    m.box(0.04, 1.0, 0.025, -0.4, 1.0, 0.09, (0.3, 0.6, 0.8))
    m.cylinder(0.3, 0.3, 0.025, -1.2, 1.4, 0.09, (0.8, 0.3, 0.12), segments=12, rot_x=90)
    for row in range(4):
        for col in range(6):
            color = [(0.75, 0.15, 0.1), (0.2, 0.6, 0.25), (0.85, 0.7, 0.2)][(row * 2 + col) % 3]
            m.box(0.12, 0.12, 0.03, 1.2 + col * 0.25, 0.8 + row * 0.35, 0.085, color)


MODELS = {
    "helicopter_body": helicopter_body,
    "helicopter_rotor": helicopter_rotor,
    "helicopter_tail_rotor": helicopter_tail_rotor,
    "control_console": control_console,
    "control_wall": control_wall,
}


def main() -> int:
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out_dir = os.path.join(root, "assets", "generated", "vehicles")
    os.makedirs(out_dir, exist_ok=True)
    for name in sorted(MODELS):
        export(name, MODELS[name], out_dir)
    print("vehicles: %d modelos" % len(MODELS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
