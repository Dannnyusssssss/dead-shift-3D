"""Mobiliario y decorado del centro comercial (modelos con color de vértice, sin texturas).

Uso: blender --background --factory-startup --python tools/blender/props.py

Escribe un .glb por modelo en assets/generated/props/. Cada modelo tiene el origen en el centro
de su base (suelo) y mira hacia -Z de Godot, con la misma huella que los bloques de colisión que
deja floorgen/decor.py (el juego funde su malla con la de la sala). Medidas en metros y en
coordenadas de Godot (x derecha, y arriba, z hacia el jugador); la conversión a Blender (z arriba)
la hace part(). Reproducible: sin aleatoriedad.
"""

import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb_writer import triangles_from_bmesh, write_glb  # noqa: E402

# Paleta (sRGB 0-1). Tonos apagados: el centro comercial está a oscuras y abandonado.
DARK = (0.1, 0.1, 0.11)
STEEL = (0.42, 0.44, 0.47)
CHROME = (0.62, 0.64, 0.66)
SKIN = (0.84, 0.8, 0.73)
CARDBOARD = (0.58, 0.44, 0.28)
TAPE = (0.74, 0.66, 0.48)
WOOD = (0.5, 0.36, 0.22)
WOOD_LIGHT = (0.64, 0.5, 0.32)
SCREEN = (0.04, 0.05, 0.07)
CONCRETE = (0.5, 0.5, 0.48)
SOIL = (0.2, 0.15, 0.1)
LEAF = (0.17, 0.3, 0.14)
LEAF_DARK = (0.11, 0.2, 0.1)
RED = (0.55, 0.12, 0.1)
GARMENTS = [(0.62, 0.18, 0.16), (0.16, 0.26, 0.45), (0.78, 0.74, 0.66), (0.2, 0.36, 0.26),
            (0.3, 0.3, 0.32), (0.72, 0.56, 0.22)]


class Model:
    """Acumula piezas en un único bmesh con color por esquina."""

    def __init__(self) -> None:
        self.bm = bmesh.new()
        self.color = self.bm.loops.layers.color.new("Color")

    def _faces_of(self, result) -> list:
        # Caras de los vértices que devolvió la operación: exactamente las de la pieza nueva
        # (las primitivas pueden reutilizar huecos de la lista de caras, así que el índice no
        # sirve para saber cuáles son).
        faces = []
        for vert in result["verts"]:
            for face in vert.link_faces:
                if face not in faces:
                    faces.append(face)
        return faces

    def _paint(self, faces, rgb) -> None:
        linear = tuple(srgb_to_linear(c) for c in rgb) + (1.0,)
        for face in faces:
            for loop in face.loops:
                loop[self.color] = linear

    def _matrix(self, x, y, z, rot_y_deg=0.0, rot_x_deg=0.0, rot_z_deg=0.0) -> Matrix:
        # Godot (x, y, z) -> Blender (x, -z, y). Giros en grados sobre los ejes de Godot.
        loc = Matrix.Translation(Vector((x, -z, y)))
        rot = (Matrix.Rotation(math.radians(rot_y_deg), 4, "Z")
               @ Matrix.Rotation(math.radians(rot_x_deg), 4, "X")
               @ Matrix.Rotation(math.radians(-rot_z_deg), 4, "Y"))
        return loc @ rot

    def box(self, sx, sy, sz, x, y_bottom, z, rgb, rot_y=0.0, rot_x=0.0, rot_z=0.0) -> None:
        """Caja de sx x sy x sz con la base en y_bottom (sin giro) y centro en (x, z)."""
        mat = self._matrix(x, y_bottom + sy * 0.5, z, rot_y, rot_x, rot_z)
        scale = Matrix.Diagonal(Vector((sx, sz, sy, 1.0)))
        result = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mat @ scale)
        self._paint(self._faces_of(result), rgb)

    def cylinder(self, r_bottom, r_top, h, x, y_bottom, z, rgb, segments=10, rot_x=0.0,
                 rot_z=0.0, squash_z=1.0) -> None:
        """Cilindro o tronco de cono vertical de alto h con la base en y_bottom."""
        mat = self._matrix(x, y_bottom + h * 0.5, z, 0.0, rot_x, rot_z)
        scale = Matrix.Diagonal(Vector((1.0, squash_z, 1.0, 1.0)))
        result = bmesh.ops.create_cone(
            self.bm, cap_ends=True, cap_tris=False, segments=segments, radius1=r_bottom,
            radius2=r_top, depth=h, matrix=mat @ scale)
        self._paint(self._faces_of(result), rgb)

    def sphere(self, r, x, y, z, rgb, sy=1.0, sz=1.0, segments=8) -> None:
        mat = self._matrix(x, y, z) @ Matrix.Diagonal(Vector((1.0, sz, sy, 1.0)))
        result = bmesh.ops.create_uvsphere(
            self.bm, u_segments=segments, v_segments=max(4, segments // 2), radius=r, matrix=mat)
        self._paint(self._faces_of(result), rgb)

    def bar(self, x0, y0, z0, x1, y1, z1, thickness, rgb) -> None:
        """Barra cuadrada entre dos puntos (coordenadas de Godot)."""
        a = Vector((x0, -z0, y0))
        b = Vector((x1, -z1, y1))
        length = (b - a).length
        if length < 1e-6:
            return
        direction = (b - a).normalized()
        rot = Vector((0.0, 0.0, 1.0)).rotation_difference(direction).to_matrix().to_4x4()
        mat = Matrix.Translation((a + b) * 0.5) @ rot
        scale = Matrix.Diagonal(Vector((thickness, thickness, length, 1.0)))
        result = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mat @ scale)
        self._paint(self._faces_of(result), rgb)


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# ---------------------------------------------------------------- modelos


def mannequin(m: Model, body=SKIN, shirt=None) -> None:
    m.cylinder(0.25, 0.25, 0.05, 0, 0, 0, DARK, segments=12)
    m.cylinder(0.025, 0.025, 0.86, 0, 0.05, 0, CHROME, segments=6)
    m.box(0.34, 0.2, 0.2, 0, 0.88, 0, body if shirt is None else DARK)
    m.cylinder(0.15, 0.2, 0.44, 0, 1.06, 0, body if shirt is None else shirt, segments=10,
               squash_z=0.6)
    m.sphere(0.075, -0.2, 1.47, 0, body if shirt is None else shirt, segments=6)
    m.sphere(0.075, 0.2, 1.47, 0, body if shirt is None else shirt, segments=6)
    m.cylinder(0.045, 0.045, 0.1, 0, 1.5, 0, body, segments=6)
    m.sphere(0.1, 0, 1.69, 0, body, sy=1.2, segments=10)


def clothes_rail(m: Model) -> None:
    for x in (-0.72, 0.72):
        m.cylinder(0.022, 0.022, 1.5, x, 0, 0, CHROME, segments=6)
        m.box(0.05, 0.03, 0.42, x, 0, 0, STEEL)
    m.bar(-0.72, 1.46, 0, 0.72, 1.46, 0, 0.03, CHROME)
    for i in range(9):
        x = -0.6 + i * 0.15
        length = 0.62 + 0.08 * ((i * 5) % 3)
        m.box(0.05, length, 0.4, x, 1.4 - length, 0, GARMENTS[(i * 4) % len(GARMENTS)])
        m.box(0.012, 0.06, 0.2, x, 1.4, 0, CHROME)


def screen_counter(m: Model) -> None:
    m.box(1.96, 0.88, 0.56, 0, 0.02, 0, (0.24, 0.25, 0.27))
    m.box(2.0, 0.05, 0.6, 0, 0.9, 0, (0.75, 0.75, 0.73))
    m.box(1.96, 0.06, 0.02, 0, 0.5, 0.29, (0.55, 0.12, 0.12))
    for x in (-0.5, 0.5):
        m.box(0.2, 0.015, 0.14, x, 0.95, 0, DARK)
        m.box(0.04, 0.12, 0.04, x, 0.95, 0, DARK)
        m.box(0.62, 0.4, 0.035, x, 1.07, 0, DARK)
        m.box(0.58, 0.36, 0.01, x, 1.09, 0.02, SCREEN)


def tv(m: Model) -> None:
    m.box(0.2, 0.2, 0.03, 0, 1.53, -0.02, DARK)
    m.box(0.9, 0.55, 0.04, 0, 1.35, 0, DARK)
    m.box(0.85, 0.5, 0.01, 0, 1.375, 0.022, SCREEN)


def boxes(m: Model, levels: int) -> None:
    stack = [(0, 0, (0.7, 0.5, 0.55), 0.0), (0.05, 0.02, (0.55, 0.42, 0.45), 0.5),
             (-0.04, 0, (0.45, 0.35, 0.4), 0.92)]
    for i, (dx, dz, (sx, sy, sz), y) in enumerate(stack[:levels]):
        shade = 1.0 - 0.08 * (i % 2)
        m.box(sx, sy, sz, dx, y, dz, tuple(c * shade for c in CARDBOARD))
        m.box(0.08, 0.004, sz + 0.002, dx, y + sy, dz, TAPE)


def stool(m: Model) -> None:
    m.cylinder(0.19, 0.19, 0.03, 0, 0, 0, DARK, segments=10)
    m.cylinder(0.03, 0.03, 0.66, 0, 0.03, 0, CHROME, segments=6)
    m.cylinder(0.12, 0.12, 0.02, 0, 0.3, 0, CHROME, segments=10)
    m.cylinder(0.19, 0.18, 0.06, 0, 0.68, 0, RED, segments=12)


def menu_board(m: Model, width: float) -> None:
    m.box(width, 0.8, 0.05, 0, 2.3, 0, DARK)
    panels = max(2, int(round(width)))
    inner = (width - 0.1) / panels
    warm = [(0.62, 0.38, 0.14), (0.55, 0.2, 0.12), (0.6, 0.52, 0.2)]
    for i in range(panels):
        x = -width / 2 + 0.05 + inner * (i + 0.5)
        m.box(inner - 0.06, 0.62, 0.01, x, 2.39, 0.03, warm[i % len(warm)])
        for row in range(3):
            m.box(inner * 0.6, 0.03, 0.005, x, 2.5 + row * 0.12, 0.037, (0.86, 0.82, 0.7))


def desk(m: Model) -> None:
    m.box(1.6, 0.04, 0.8, 0, 0.71, 0, WOOD)
    m.box(0.45, 0.69, 0.74, -0.55, 0.02, 0, (0.3, 0.3, 0.32))
    for i in range(3):
        m.box(0.4, 0.005, 0.01, -0.55, 0.2 + i * 0.22, 0.375, CHROME)
    m.box(0.04, 0.69, 0.7, 0.76, 0.02, 0, (0.3, 0.3, 0.32))
    m.box(0.18, 0.012, 0.14, 0.3, 0.75, -0.1, DARK)
    m.box(0.04, 0.16, 0.04, 0.3, 0.75, -0.12, DARK)
    m.box(0.5, 0.32, 0.03, 0.3, 0.88, -0.1, DARK)
    m.box(0.46, 0.28, 0.01, 0.3, 0.9, -0.08, SCREEN)
    m.box(0.42, 0.015, 0.14, 0.3, 0.75, 0.12, (0.2, 0.2, 0.22))
    # Silla de oficina delante del escritorio.
    m.cylinder(0.24, 0.24, 0.04, 0, 0.02, 0.75, DARK, segments=5)
    m.cylinder(0.03, 0.03, 0.38, 0, 0.06, 0.75, CHROME, segments=6)
    m.box(0.45, 0.08, 0.45, 0, 0.42, 0.75, (0.18, 0.2, 0.24))
    m.box(0.42, 0.48, 0.06, 0, 0.5, 0.97, (0.18, 0.2, 0.24))


def locker(m: Model) -> None:
    body = (0.33, 0.4, 0.46)
    m.box(0.5, 1.9, 0.5, 0, 0, 0, body)
    m.box(0.46, 1.84, 0.01, 0, 0.03, 0.25, (0.38, 0.45, 0.52))
    for i in range(4):
        m.box(0.24, 0.015, 0.006, 0, 1.55 + i * 0.05, 0.258, DARK)
    m.box(0.03, 0.12, 0.03, 0.17, 1.0, 0.265, CHROME)


def pallet(m: Model, stacked: bool) -> None:
    for x in (-0.5, 0.0, 0.5):
        m.box(0.12, 0.08, 1.0, x, 0, 0, WOOD_LIGHT)
    for z in (-0.44, -0.22, 0.0, 0.22, 0.44):
        m.box(1.2, 0.025, 0.11, 0, 0.08, z, WOOD_LIGHT)
    m.box(1.2, 0.025, 0.11, 0, 0.115, -0.44, WOOD_LIGHT)
    m.box(1.2, 0.025, 0.11, 0, 0.115, 0.44, WOOD_LIGHT)
    if stacked:
        m.box(0.55, 0.5, 0.9, -0.28, 0.14, 0, CARDBOARD)
        m.box(0.55, 0.45, 0.8, 0.3, 0.14, 0.05, tuple(c * 0.9 for c in CARDBOARD))
        m.box(0.08, 0.004, 0.9, -0.28, 0.64, 0, TAPE)


def fallen_cart(m: Model) -> None:
    # Carrito de lado: la cesta (marco de barras) apoyada en el suelo, ruedas al aire.
    t = 0.02
    x0, x1, y0, y1, z0, z1 = -0.47, 0.47, 0.0, 0.58, -0.27, 0.27
    corners = [(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
    edges = [(a, b) for a in corners for b in corners
             if a < b and sum(1 for i in range(3) if a[i] != b[i]) == 1]
    for a, b in edges:
        m.bar(*a, *b, t, CHROME)
    for i in range(1, 6):
        x = x0 + (x1 - x0) * i / 6
        m.bar(x, y0, z0, x, y1, z0, 0.01, CHROME)
        m.bar(x, y0, z1, x, y1, z1, 0.01, CHROME)
    m.bar(0.55, 0.45, -0.27, 0.55, 0.45, 0.27, 0.035, RED)
    for z in (-0.22, 0.22):
        m.cylinder(0.05, 0.05, 0.03, -0.4, 0.62, z, DARK, segments=8)
        m.cylinder(0.05, 0.05, 0.03, 0.4, 0.62, z, DARK, segments=8)


def bench(m: Model) -> None:
    for x in (-0.8, 0.8):
        m.box(0.06, 0.4, 0.5, x, 0, 0, STEEL)
    for z in (-0.2, -0.07, 0.07, 0.2):
        m.box(2.0, 0.04, 0.1, 0, 0.4, z, WOOD)


def planter(m: Model) -> None:
    m.box(1.2, 0.8, 1.2, 0, 0, 0, CONCRETE)
    m.box(1.1, 0.02, 1.1, 0, 0.78, 0, SOIL)
    m.cylinder(0.05, 0.04, 0.5, 0, 0.8, 0, (0.3, 0.22, 0.14), segments=6)
    leaves = [(0, 1.45, 0, 0.36), (0.18, 1.3, 0.12, 0.26), (-0.17, 1.28, -0.1, 0.27),
              (0.05, 1.68, -0.05, 0.22), (-0.12, 1.15, 0.18, 0.2)]
    for i, (x, y, z, r) in enumerate(leaves):
        m.sphere(r, x, y, z, LEAF if i % 2 == 0 else LEAF_DARK, sy=0.85, segments=8)


def bin_(m: Model) -> None:
    m.cylinder(0.23, 0.24, 0.86, 0, 0, 0, (0.18, 0.24, 0.2), segments=12)
    m.cylinder(0.25, 0.25, 0.04, 0, 0.86, 0, STEEL, segments=12)
    m.cylinder(0.17, 0.17, 0.005, 0, 0.9, 0, DARK, segments=12)


PRODUCTS = [(0.7, 0.2, 0.15), (0.2, 0.42, 0.62), (0.85, 0.75, 0.3), (0.3, 0.55, 0.3),
            (0.8, 0.8, 0.78), (0.55, 0.3, 0.55), (0.9, 0.5, 0.2), (0.25, 0.25, 0.3)]


def shelf(m: Model, length: float, height: float, depth: float, levels: int) -> None:
    """Góndola de tienda de doble cara con productos en cada balda (y huecos: saqueada)."""
    m.box(length, 0.1, depth - 0.04, 0, 0, 0, DARK)
    m.box(length - 0.04, height - 0.1, 0.03, 0, 0.1, 0, STEEL)
    for x in (-length / 2 + 0.02, length / 2 - 0.02):
        m.box(0.04, height, depth, x, 0, 0, STEEL)
    step = (height - 0.25) / levels
    for level in range(levels):
        y = 0.12 + level * step
        m.box(length - 0.08, 0.025, depth - 0.04, 0, y, 0, (0.6, 0.62, 0.64))
        for face in (-1, 1):
            z = face * depth / 4
            x = -length / 2 + 0.12
            k = level * 3 + (face + 1)
            while x < length / 2 - 0.4:
                kind = k % 4
                color = PRODUCTS[(k * 5 + level) % len(PRODUCTS)]
                if kind == 0:
                    w = 0.22
                    m.box(w, step * 0.62, depth * 0.36, x + w / 2, y + 0.025, z, color)
                elif kind == 1:
                    # Fila de latas o frascos como una sola caja estrecha (menos triángulos).
                    w = 0.18
                    m.box(w, step * 0.4, depth * 0.2, x + w / 2, y + 0.025, z, color)
                elif kind == 2:
                    w = 0.3
                    m.box(w, step * 0.45, depth * 0.38, x + w / 2, y + 0.025, z, color)
                else:
                    w = 0.12
                x += w + (0.18 if (k % 7) == 3 else 0.03)
                k += 1


def table_set(m: Model) -> None:
    m.cylinder(0.55, 0.55, 0.04, 0, 0.71, 0, (0.72, 0.7, 0.66), segments=14)
    m.cylinder(0.04, 0.04, 0.69, 0, 0.02, 0, CHROME, segments=6)
    m.cylinder(0.3, 0.3, 0.02, 0, 0, 0, DARK, segments=10)
    for angle in range(0, 360, 90):
        a = math.radians(angle)
        x, z = math.sin(a) * 0.95, math.cos(a) * 0.95
        m.box(0.42, 0.04, 0.42, x, 0.42, z, RED, rot_y=angle)
        for dx in (-0.18, 0.18):
            for dz in (-0.18, 0.18):
                lx = x + dx * math.cos(a) + dz * math.sin(a)
                lz = z - dx * math.sin(a) + dz * math.cos(a)
                m.box(0.025, 0.42, 0.025, lx, 0, lz, CHROME)
        bx, bz = math.sin(a) * 1.15, math.cos(a) * 1.15
        m.box(0.42, 0.4, 0.03, bx, 0.46, bz, RED, rot_y=angle)


def kiosk(m: Model) -> None:
    m.box(3.0, 0.1, 1.6, 0, 0, 0, DARK)
    m.box(2.96, 0.95, 1.56, 0, 0.1, 0, (0.3, 0.32, 0.36))
    m.box(3.04, 0.05, 1.64, 0, 1.05, 0, (0.75, 0.75, 0.72))
    for x, z in ((-1.4, -0.7), (1.4, 0.7)):
        m.box(0.15, 1.3, 0.15, x, 1.1, z, STEEL)
    m.box(3.4, 0.15, 2.0, 0, 2.4, 0, (0.2, 0.32, 0.5))
    m.box(3.42, 0.03, 2.02, 0, 2.4, 0, (0.75, 0.75, 0.72))
    for i in range(5):
        m.box(0.22, 0.32, 0.03, -1.0 + i * 0.5, 1.1, 0.3, PRODUCTS[i % len(PRODUCTS)])


def counter(m: Model, w: float, h: float, d: float) -> None:
    m.box(w - 0.04, 0.1, d - 0.08, 0, 0, 0, DARK)
    m.box(w - 0.02, h - 0.14, d - 0.02, 0, 0.1, 0, (0.28, 0.29, 0.31))
    m.box(w, 0.04, d, 0, h - 0.04, 0, (0.74, 0.73, 0.7))
    m.box(w - 0.02, 0.05, 0.01, 0, h * 0.55, d / 2, (0.55, 0.12, 0.12))
    m.box(0.36, 0.14, 0.3, w / 2 - 0.35, h, 0, DARK)
    m.box(0.3, 0.2, 0.02, w / 2 - 0.35, h + 0.14, -0.08, SCREEN)


def roof_hvac(m: Model) -> None:
    m.box(3.0, 0.12, 2.0, 0, 0, 0, DARK)
    m.box(2.9, 1.4, 1.9, 0, 0.12, 0, (0.55, 0.56, 0.55))
    for x in (-0.7, 0.7):
        m.cylinder(0.55, 0.55, 0.06, x, 1.52, 0, (0.15, 0.15, 0.16), segments=14)
        m.bar(x - 0.5, 1.6, 0, x + 0.5, 1.6, 0, 0.03, STEEL)
        m.bar(x, 1.6, -0.5, x, 1.6, 0.5, 0.03, STEEL)
    for i in range(8):
        m.box(2.6, 0.02, 0.01, 0, 0.3 + i * 0.13, 0.955, (0.35, 0.36, 0.36))


def water_tank(m: Model) -> None:
    for x in (-0.8, 0.8):
        m.box(0.12, 0.3, 2.2, x, 0, 0, STEEL)
    m.cylinder(1.05, 1.05, 2.2, 0, 0.3, 0, (0.6, 0.62, 0.6), segments=16)
    m.cylinder(1.1, 1.1, 0.06, 0, 1.1, 0, STEEL, segments=16)
    m.cylinder(0.3, 0.3, 0.1, 0, 2.5, 0, DARK, segments=10)


def antenna(m: Model) -> None:
    m.box(0.35, 0.1, 0.35, 0, 0, 0, DARK)
    m.cylinder(0.06, 0.04, 6.9, 0, 0.1, 0, STEEL, segments=6)
    for y in (3.0, 4.5, 6.0):
        m.bar(-0.6, y, 0, 0.6, y, 0, 0.03, STEEL)
    m.cylinder(0.45, 0.1, 0.25, 0, 5.0, 0.2, (0.75, 0.75, 0.74), segments=12, rot_x=80)
    m.sphere(0.06, 0, 7.0, 0, RED, segments=6)


def generator(m: Model) -> None:
    m.box(2.5, 0.12, 1.5, 0, 0, 0, DARK)
    m.box(2.4, 1.0, 1.4, 0, 0.12, 0, (0.45, 0.42, 0.2))
    for i in range(6):
        # Aletas por fuera de la cara del cuerpo (x = -1,2), sin compartir su plano.
        m.box(0.012, 0.6, 0.16, -1.214, 0.3, -0.45 + i * 0.18, DARK)
    m.cylinder(0.08, 0.08, 0.6, 0.9, 1.12, -0.4, (0.25, 0.22, 0.2), segments=8)
    m.box(0.5, 0.3, 0.02, 0.4, 0.6, 0.71, (0.12, 0.12, 0.13))


# ---------------------------------------------------------------- ascensor, baños y cafetería

PORCELAIN = (0.86, 0.87, 0.86)
STALL = (0.36, 0.42, 0.48)
MIRROR = (0.55, 0.62, 0.66)


def elevator(m: Model) -> None:
    """Hueco de ascensor que sale 1,9 m de la pared hasta el techo, con las puertas atascadas
    medio abiertas: por el hueco se ve la cabina (fondo, pasamanos, botonera y luz)."""
    w, d, h = 2.6, 1.9, 4.7
    front = -d / 2
    wall = (0.56, 0.56, 0.54)
    # Laterales, fondo y frente por encima y a los lados de la puerta.
    m.box(0.2, h, d, -w / 2 + 0.1, 0, 0, wall)
    m.box(0.2, h, d, w / 2 - 0.1, 0, 0, wall)
    m.box(w - 0.4, h, 0.2, 0, 0, d / 2 - 0.1, wall)
    m.box(w - 0.4, h - 2.45, 0.2, 0, 2.45, front + 0.1, wall)
    m.box(0.5, 2.45, 0.2, -0.85, 0, front + 0.1, wall)
    m.box(0.5, 2.45, 0.2, 0.85, 0, front + 0.1, wall)
    # Marco de acero e indicador de piso apagado.
    m.box(1.3, 0.12, 0.06, 0, 2.33, front - 0.03, CHROME)
    m.box(0.08, 2.33, 0.06, -0.62, 0, front - 0.03, CHROME)
    m.box(0.08, 2.33, 0.06, 0.62, 0, front - 0.03, CHROME)
    m.box(0.5, 0.16, 0.03, 0, 2.6, front - 0.015, DARK)
    # Cabina: suelo, techo con panel de luz, paredes de acero y pasamanos.
    cab_back = d / 2 - 0.2
    m.box(w - 0.4, 0.06, d - 0.4, 0, 0, 0, (0.22, 0.22, 0.23))
    m.box(w - 0.4, 0.05, d - 0.4, 0, 2.4, 0, (0.3, 0.3, 0.31))
    m.box(0.8, 0.02, 0.5, 0, 2.38, 0.1, (0.82, 0.84, 0.8))
    m.box(w - 0.44, 2.34, 0.02, 0, 0.06, cab_back - 0.012, (0.48, 0.5, 0.52))
    m.box(0.02, 2.34, d - 0.44, -w / 2 + 0.212, 0.06, 0, (0.44, 0.46, 0.48))
    m.box(0.02, 2.34, d - 0.44, w / 2 - 0.212, 0.06, 0, (0.44, 0.46, 0.48))
    m.bar(-0.9, 0.95, cab_back - 0.07, 0.9, 0.95, cab_back - 0.07, 0.04, CHROME)
    m.box(0.16, 0.5, 0.02, w / 2 - 0.25, 1.0, -0.2, DARK, rot_y=90)
    # Hojas de la puerta atascadas: queda un hueco de unos 50 cm en el centro.
    m.box(0.36, 2.28, 0.04, -0.43, 0.02, front - 0.08, (0.64, 0.66, 0.68))
    m.box(0.36, 2.28, 0.04, 0.43, 0.02, front - 0.08, (0.64, 0.66, 0.68))
    # Botonera de llamada junto a la puerta.
    m.box(0.12, 0.3, 0.03, 0.85, 1.0, front - 0.015, DARK)
    m.box(0.05, 0.05, 0.01, 0.85, 1.18, front - 0.035, (0.7, 0.66, 0.5))
    m.box(0.05, 0.05, 0.01, 0.85, 1.06, front - 0.035, (0.7, 0.66, 0.5))


def toilet(m: Model, x: float, z: float) -> None:
    """Inodoro mirando hacia -Z, con la cisterna atrás."""
    m.box(0.36, 0.38, 0.18, x, 0, z + 0.25, PORCELAIN)
    m.cylinder(0.19, 0.17, 0.38, x, 0, z, PORCELAIN, segments=10, squash_z=1.3)
    m.cylinder(0.2, 0.2, 0.03, x, 0.38, z, (0.92, 0.92, 0.9), segments=10, squash_z=1.3)
    m.box(0.4, 0.42, 0.06, x, 0.42, z + 0.3, (0.92, 0.92, 0.9), rot_x=-10)


def toilet_stall(m: Model) -> None:
    """Cubículo de 1 x 1,5 m: tabiques laterales, frente con la puerta entornada e inodoro."""
    w, d, h = 1.0, 1.5, 2.0
    for x in (-w / 2, w / 2):
        m.box(0.04, h - 0.15, d, x, 0.15, 0, STALL)
        m.box(0.05, 0.15, 0.05, x, 0, -d / 2 + 0.05, CHROME)
        m.box(0.05, 0.15, 0.05, x, 0, d / 2 - 0.05, CHROME)
    m.box(0.12, h - 0.15, 0.04, -w / 2 + 0.08, 0.15, -d / 2 - 0.03, STALL)
    # Puerta entornada (girada sobre su bisagra) con su pestillo.
    m.box(0.8, h - 0.3, 0.035, -0.08, 0.2, -d / 2 - 0.3, STALL, rot_y=-35)
    m.box(0.04, 0.08, 0.04, 0.2, 1.0, -d / 2 - 0.5, CHROME)
    toilet(m, 0, d / 2 - 0.45)
    m.cylinder(0.06, 0.06, 0.1, 0.38, 0.7, 0.2, PORCELAIN, segments=8, rot_z=90)


def sink_counter(m: Model) -> None:
    """Encimera de 2 m con dos lavabos, grifos y un espejo encima (todo contra la pared)."""
    m.box(2.0, 0.08, 0.55, 0, 0.82, 0, (0.7, 0.7, 0.68))
    m.box(1.96, 0.78, 0.04, 0, 0.04, 0.24, (0.4, 0.42, 0.44))
    for x in (-0.5, 0.5):
        m.cylinder(0.2, 0.16, 0.12, x, 0.72, -0.02, PORCELAIN, segments=12, squash_z=0.8)
        m.box(0.04, 0.2, 0.04, x, 0.9, 0.18, CHROME)
        m.box(0.04, 0.03, 0.14, x, 1.08, 0.12, CHROME)
    m.box(1.9, 0.9, 0.02, 0, 1.15, 0.27, MIRROR)
    m.box(1.96, 0.04, 0.03, 0, 2.05, 0.27, CHROME)


def hand_dryer(m: Model) -> None:
    m.box(0.3, 0.3, 0.2, 0, 1.25, 0, (0.8, 0.8, 0.8))
    m.box(0.12, 0.05, 0.08, 0, 1.2, -0.06, DARK)


def urinal(m: Model) -> None:
    m.box(0.4, 0.6, 0.3, 0, 0.5, 0, PORCELAIN)
    m.box(0.3, 0.42, 0.04, 0, 0.58, -0.17, (0.78, 0.8, 0.8))
    m.box(0.05, 0.4, 0.05, 0, 1.1, 0.1, CHROME)


def restroom_sign(m: Model) -> None:
    """Rótulo de baño con las figuras de hombre y mujer (se lee sin texto)."""
    m.box(0.5, 0.3, 0.02, 0, 0, 0, (0.15, 0.32, 0.55))
    white = (0.92, 0.92, 0.9)
    for x, skirt in ((-0.12, False), (0.12, True)):
        m.sphere(0.03, x, 0.24, -0.015, white, segments=6)
        m.box(0.1 if skirt else 0.06, 0.1, 0.01, x, 0.1, -0.015, white)
        m.box(0.07, 0.06, 0.01, x, 0.04, -0.015, white)
    m.box(0.01, 0.24, 0.01, 0, 0.03, -0.015, white)


def cafe_counter(m: Model) -> None:
    """Barra de cafetería de 6 m: vitrina de pasteles, cafetera, molinillo, tazas y
    servilleteros."""
    w, h, d = 6.0, 1.1, 0.9
    counter(m, w, h, d)
    # Vitrina con baldas y pasteles.
    m.box(1.6, 0.04, 0.6, -1.6, h, 0, (0.3, 0.3, 0.32))
    m.box(1.6, 0.5, 0.02, -1.6, h + 0.04, -0.29, (0.55, 0.62, 0.66))
    m.box(1.6, 0.02, 0.6, -1.6, h + 0.54, 0, (0.55, 0.62, 0.66))
    m.box(1.56, 0.02, 0.56, -1.6, h + 0.27, 0, (0.7, 0.7, 0.68))
    cakes = [(0.75, 0.55, 0.35), (0.45, 0.25, 0.15), (0.9, 0.85, 0.75), (0.7, 0.3, 0.3)]
    for i in range(6):
        x = -2.25 + i * 0.26
        m.cylinder(0.09, 0.09, 0.08, x, h + 0.04, 0.0, cakes[i % 4], segments=10)
        m.cylinder(0.08, 0.08, 0.07, x + 0.1, h + 0.29, 0.05, cakes[(i + 1) % 4], segments=10)
    # Cafetera de dos grupos y molinillo.
    m.box(0.8, 0.45, 0.5, 1.2, h, 0.1, (0.6, 0.6, 0.62))
    m.box(0.82, 0.06, 0.52, 1.2, h + 0.45, 0.1, CHROME)
    for x in (1.0, 1.4):
        m.box(0.08, 0.1, 0.12, x, h + 0.2, -0.21, DARK)
    m.cylinder(0.08, 0.1, 0.4, 1.8, h, 0.15, DARK, segments=8)
    m.cylinder(0.1, 0.06, 0.15, 1.8, h + 0.4, 0.15, (0.4, 0.3, 0.2), segments=8)
    # Tazas apiladas y servilleteros.
    for i in range(4):
        m.cylinder(0.04, 0.04, 0.07, 0.4 + i * 0.1, h, -0.2, PORCELAIN, segments=8)
    m.box(0.12, 0.12, 0.08, -0.3, h, -0.25, CHROME)
    m.box(0.12, 0.12, 0.08, 2.5, h, -0.25, CHROME)


def cafe_table_2(m: Model) -> None:
    """Mesa pequeña cuadrada con dos sillas enfrentadas."""
    m.box(0.7, 0.04, 0.7, 0, 0.72, 0, (0.55, 0.42, 0.3))
    m.box(0.05, 0.72, 0.05, 0, 0, 0, CHROME)
    m.box(0.4, 0.02, 0.4, 0, 0, 0, DARK)
    for z in (-0.65, 0.65):
        m.box(0.42, 0.04, 0.42, 0, 0.44, z, (0.25, 0.25, 0.27))
        m.box(0.42, 0.42, 0.03, 0, 0.48, z + (0.2 if z > 0 else -0.2), (0.25, 0.25, 0.27))
        for dx in (-0.18, 0.18):
            for dz in (-0.18, 0.18):
                m.box(0.025, 0.44, 0.025, dx, 0, z + dz, CHROME)


def sofa_bench(m: Model) -> None:
    """Banco tapizado contra la pared, de 3 m."""
    m.box(3.0, 0.42, 0.55, 0, 0, 0, (0.3, 0.18, 0.14))
    m.box(3.0, 0.5, 0.15, 0, 0.42, 0.22, (0.34, 0.2, 0.15))
    for x in (-1.0, 0.0, 1.0):
        m.box(0.02, 0.5, 0.17, x, 0.42, 0.22, (0.22, 0.12, 0.1))


# ---------------------------------------------------------------- escaparates de tiendas cerradas


def _display_base(m: Model) -> None:
    """Tarima del escaparate (3 x 1,1 m)."""
    m.box(3.0, 0.25, 1.1, 0, 0, 0, (0.24, 0.24, 0.26))
    m.box(2.98, 0.01, 1.08, 0, 0.25, 0, (0.4, 0.38, 0.36))


def display_books(m: Model) -> None:
    _display_base(m)
    covers = [(0.6, 0.15, 0.12), (0.15, 0.3, 0.5), (0.8, 0.7, 0.3), (0.2, 0.4, 0.25),
              (0.85, 0.85, 0.8), (0.4, 0.2, 0.45)]
    for i in range(5):
        x = -1.2 + i * 0.6
        for level in range(1 + i % 3):
            m.box(0.32, 0.06, 0.24, x, 0.26 + level * 0.06, 0.1, covers[(i + level) % 6],
                  rot_y=(level * 13) % 20)
        m.box(0.24, 0.32, 0.03, x, 0.26 + 0.06 * (1 + i % 3), 0.0, covers[(i * 2) % 6],
              rot_x=-15)
    m.box(0.9, 1.2, 0.02, 0.6, 0.6, 0.5, (0.7, 0.66, 0.55))


def display_toys(m: Model) -> None:
    _display_base(m)
    bright = [(0.85, 0.2, 0.15), (0.2, 0.5, 0.85), (0.95, 0.8, 0.2), (0.25, 0.65, 0.3)]
    for i in range(4):
        x = -1.1 + i * 0.75
        m.box(0.25, 0.25, 0.25, x, 0.26, 0.15, bright[i])
        m.box(0.2, 0.2, 0.2, x + 0.05, 0.51, 0.12, bright[(i + 1) % 4], rot_y=20)
    # Osito y una pelota.
    bear = (0.55, 0.38, 0.22)
    m.sphere(0.16, 0.3, 0.45, -0.15, bear, segments=8)
    m.sphere(0.12, 0.3, 0.7, -0.15, bear, segments=8)
    m.sphere(0.04, 0.22, 0.8, -0.15, bear, segments=6)
    m.sphere(0.04, 0.38, 0.8, -0.15, bear, segments=6)
    m.sphere(0.15, -0.6, 0.41, -0.2, (0.9, 0.3, 0.2), segments=10)
    m.box(1.0, 0.25, 0.4, 0.9, 0.26, -0.3, (0.3, 0.3, 0.35))
    m.box(0.3, 0.1, 0.2, 0.9, 0.51, -0.3, (0.85, 0.2, 0.15))


def display_optics(m: Model) -> None:
    _display_base(m)
    for i in range(5):
        x = -1.2 + i * 0.6
        m.box(0.06, 0.6, 0.06, x, 0.26, 0.1, CHROME)
        m.box(0.24, 0.3, 0.12, x, 0.86, 0.1, (0.82, 0.82, 0.8))
        # Gafas sobre el expositor: dos aros.
        m.cylinder(0.05, 0.05, 0.01, x - 0.06, 1.0, 0.03, DARK, segments=10, rot_x=90)
        m.cylinder(0.05, 0.05, 0.01, x + 0.06, 1.0, 0.03, DARK, segments=10, rot_x=90)
    m.box(1.0, 0.7, 0.02, -0.6, 1.2, 0.5, (0.3, 0.45, 0.6))


def display_jewelry(m: Model) -> None:
    _display_base(m)
    gold = (0.9, 0.75, 0.3)
    for i in range(3):
        x = -1.0 + i * 1.0
        m.box(0.7, 0.6, 0.5, x, 0.26, 0.0, (0.15, 0.15, 0.17))
        m.box(0.72, 0.02, 0.52, x, 0.86, 0.0, (0.6, 0.66, 0.7))
        m.box(0.6, 0.015, 0.4, x, 0.88, 0.0, (0.25, 0.1, 0.15))
        for k in range(3):
            m.cylinder(0.03, 0.03, 0.01, x - 0.15 + k * 0.15, 0.9, 0.0, gold, segments=8,
                       rot_x=90)
        m.box(0.08, 0.25, 0.04, x, 0.9, 0.15, (0.85, 0.85, 0.82))
        m.cylinder(0.05, 0.05, 0.01, x, 1.05, 0.12, gold, segments=10, rot_x=90)


def display_boutique(m: Model) -> None:
    _display_base(m)
    shirts = [(0.55, 0.15, 0.2), (0.85, 0.82, 0.75), (0.15, 0.2, 0.35)]
    for i, x in enumerate((-1.0, 0.0, 1.0)):
        m.cylinder(0.18, 0.18, 0.04, x, 0.26, 0.0, DARK, segments=10)
        m.cylinder(0.02, 0.02, 0.8, x, 0.3, 0.0, CHROME, segments=6)
        m.cylinder(0.15, 0.22, 0.55, x, 1.05, 0.0, shirts[i], segments=10, squash_z=0.6)
        m.cylinder(0.22, 0.28, 0.45, x, 0.6, 0.0, shirts[(i + 1) % 3], segments=10,
                   squash_z=0.6)
        m.sphere(0.1, x, 1.75, 0.0, (0.84, 0.8, 0.73), sy=1.2, segments=8)
    m.box(0.6, 0.3, 0.3, 1.3, 0.26, -0.3, (0.6, 0.45, 0.3))


def display_cinema(m: Model) -> None:
    _display_base(m)
    posters = [(0.5, 0.1, 0.1), (0.1, 0.2, 0.4), (0.15, 0.3, 0.15)]
    for i, x in enumerate((-1.0, 0.0, 1.0)):
        m.box(0.7, 1.0, 0.03, x, 0.6, 0.45, (0.08, 0.08, 0.09))
        m.box(0.62, 0.92, 0.01, x, 0.64, 0.425, posters[i])
        m.box(0.5, 0.08, 0.01, x, 1.3, 0.415, (0.9, 0.85, 0.6))
    m.cylinder(0.12, 0.16, 0.3, -0.5, 0.26, -0.2, (0.85, 0.15, 0.12), segments=10)
    m.sphere(0.13, -0.5, 0.58, -0.2, (0.95, 0.9, 0.7), sy=0.6, segments=8)


# ---------------------------------------------------------------- desorden por el suelo


def clutter_papers(m: Model) -> None:
    sheets = [(-0.3, 0.1, 15), (0.1, -0.2, 70), (0.35, 0.25, 40), (-0.1, 0.35, 110),
              (0.0, 0.0, 5)]
    for i, (x, z, rot) in enumerate(sheets):
        m.box(0.21, 0.004, 0.3, x, 0.003 * (i + 1), z, (0.85, 0.84, 0.8), rot_y=rot)


def clutter_clothes(m: Model) -> None:
    m.box(0.5, 0.05, 0.4, 0, 0, 0, GARMENTS[0], rot_y=20)
    m.box(0.4, 0.06, 0.35, 0.1, 0.05, 0.05, GARMENTS[1], rot_y=-35)
    m.box(0.3, 0.05, 0.3, -0.15, 0.04, -0.1, GARMENTS[2], rot_y=60)


def clutter_box(m: Model) -> None:
    # Caja de cartón volcada con lo que llevaba desparramado.
    m.box(0.35, 0.5, 0.4, 0, 0, 0, CARDBOARD)
    for i in range(4):
        m.box(0.14, 0.08, 0.1, 0.35 + i * 0.12, 0, -0.1 + (i % 2) * 0.2,
              PRODUCTS[i % len(PRODUCTS)], rot_y=i * 25)


def clutter_chair(m: Model) -> None:
    # Silla volcada de lado: asiento y respaldo en vertical, patas al aire.
    m.box(0.04, 0.42, 0.42, 0, 0.0, 0, RED)
    m.box(0.42, 0.42, 0.03, 0.2, 0.0, 0.21, RED)
    for dz in (-0.18, 0.18):
        m.bar(-0.02, 0.05, dz, -0.44, 0.05, dz, 0.025, CHROME)
        m.bar(-0.02, 0.37, dz, -0.44, 0.37, dz, 0.025, CHROME)


def clutter_bags(m: Model) -> None:
    m.box(0.35, 0.12, 0.3, 0, 0, 0, (0.75, 0.72, 0.62), rot_y=10)
    m.box(0.3, 0.1, 0.25, 0.35, 0, 0.2, (0.55, 0.15, 0.15), rot_y=-40)
    m.cylinder(0.04, 0.04, 0.2, -0.3, 0.04, 0.2, (0.3, 0.45, 0.3), segments=8, rot_z=90)


def clutter_debris(m: Model) -> None:
    # Trozos de techo caídos.
    m.box(0.6, 0.02, 0.6, 0, 0, 0, (0.45, 0.45, 0.43), rot_y=12)
    m.box(0.3, 0.04, 0.25, 0.2, 0.02, 0.1, (0.7, 0.7, 0.68), rot_y=40)
    m.box(0.22, 0.03, 0.2, -0.2, 0.025, -0.15, (0.7, 0.7, 0.68), rot_y=-25)
    m.box(0.15, 0.06, 0.1, 0.05, 0.03, -0.25, (0.5, 0.5, 0.5), rot_y=70)


def monitor_bank(m: Model) -> None:
    """Cuatro monitores de vigilancia (2 x 2) sobre un soporte. Las pantallas no van aquí: las
    pone el juego aparte para poder encenderlas al usarlas."""
    m.box(1.5, 0.06, 0.4, 0, 0, 0, DARK)
    m.box(0.08, 0.2, 0.08, 0, 0.06, 0.1, DARK)
    for row in range(2):
        for col in (-0.36, 0.36):
            m.box(0.7, 0.44, 0.12, col, 0.26 + row * 0.46, 0.08, (0.14, 0.14, 0.15))

# Mostradores modelados (ancho, alto, fondo); el nombre lleva las medidas en centímetros.
COUNTERS = [(2.0, 0.95, 0.9), (2.5, 1.0, 0.8), (6.0, 1.1, 0.9), (2.2, 0.9, 0.7), (6.0, 1.1, 1.0),
            (5.0, 1.1, 1.0)]


def counter_name(w: float, h: float, d: float) -> str:
    return "counter_%d_%d_%d" % (round(w * 100), round(h * 100), round(d * 100))


MODELS = {
    "mannequin": lambda m: mannequin(m),
    "mannequin_dark": lambda m: mannequin(m, body=(0.22, 0.22, 0.24), shirt=(0.15, 0.32, 0.55)),
    "clothes_rail": clothes_rail,
    "screen_counter": screen_counter,
    "tv": tv,
    "boxes_1": lambda m: boxes(m, 1),
    "boxes_2": lambda m: boxes(m, 2),
    "boxes_3": lambda m: boxes(m, 3),
    "stool": stool,
    "menu_board_3": lambda m: menu_board(m, 3.0),
    "menu_board_4": lambda m: menu_board(m, 4.0),
    "desk": desk,
    "locker": locker,
    "pallet_stacked": lambda m: pallet(m, True),
    "fallen_cart": fallen_cart,
    "bench": bench,
    "planter": planter,
    "bin": bin_,
    "shelf_large": lambda m: shelf(m, 3.0, 1.8, 0.6, 4),
    "shelf_small": lambda m: shelf(m, 1.6, 1.4, 0.5, 3),
    "table_set": table_set,
    "kiosk": kiosk,
    "roof_hvac": roof_hvac,
    "water_tank": water_tank,
    "antenna": antenna,
    "generator": generator,
    "elevator": elevator,
    "toilet_stall": toilet_stall,
    "sink_counter": sink_counter,
    "hand_dryer": hand_dryer,
    "urinal": urinal,
    "restroom_sign": restroom_sign,
    "cafe_counter": cafe_counter,
    "cafe_table_2": cafe_table_2,
    "sofa_bench": sofa_bench,
    "display_books": display_books,
    "display_toys": display_toys,
    "display_optics": display_optics,
    "display_jewelry": display_jewelry,
    "display_boutique": display_boutique,
    "display_cinema": display_cinema,
    "clutter_papers": clutter_papers,
    "clutter_clothes": clutter_clothes,
    "clutter_box": clutter_box,
    "clutter_chair": clutter_chair,
    "clutter_bags": clutter_bags,
    "clutter_debris": clutter_debris,
    "monitor_bank": monitor_bank,
}
for _size in COUNTERS:
    MODELS[counter_name(*_size)] = (lambda size: lambda m: counter(m, *size))(_size)


def export(name: str, build, out_dir: str) -> None:
    model = Model()
    build(model)
    # Triangulación propia con método fijo y escritura propia del GLB: el exportador de Blender
    # no da siempre el mismo orden de índices y el archivo cambiaría en cada ejecución.
    bmesh.ops.triangulate(model.bm, faces=model.bm.faces[:], quad_method="FIXED",
                          ngon_method="EAR_CLIP")
    model.bm.normal_update()
    triangles = triangles_from_bmesh(model.bm, model.color)
    model.bm.free()
    write_glb(os.path.join(out_dir, name + ".glb"), name, triangles)


def main() -> int:
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out_dir = os.path.join(root, "assets", "generated", "props")
    os.makedirs(out_dir, exist_ok=True)
    for name in sorted(MODELS):
        export(name, MODELS[name], out_dir)
    print("props: %d modelos" % len(MODELS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
