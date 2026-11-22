"""Manos del guardia en primera persona a partir de la malla del maniquí de Quaternius (UAL1, CC0).

Lo usa tools/blender/arms.py. La mano derecha del maniquí (palma, nudillos y dedos modelados) se
coloca con sus propios huesos en cada forma y se hornea a una malla estática:
  - grip: puño cerrado alrededor de un mango que corre a lo largo del antebrazo (-Z), como lo
    monta el juego; el pulgar cierra por fuera sobre el índice.
  - pistol: corazón, anular y meñique alrededor de la empuñadura vertical, el índice estirado
    por el costado hasta el gatillo y el pulgar por el otro lado.
  - open: mano relajada, con los dedos algo doblados.
Los ángulos de los dedos y el giro de la muñeca se buscan midiendo la propia malla: el hueco que
dejan los dedos tiene el radio del mango y su eje va en la dirección que pide el arma. La mano
izquierda es el reflejo de la derecha. El origen es la muñeca y el antebrazo va hacia +Z.
Normales suavizadas por vértice. Reproducible: búsquedas en rejilla fija, sin azar.
"""

import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
UAL1 = os.path.join(ROOT, "assets", "third_party", "quaternius-ual1", "UAL1_Standard.glb")

FINGERS = ("index", "middle", "ring", "pinky")
HAND_BONES = ("hand",) + FINGERS + ("thumb",)
# Radio libre que deja el puño cerrado (medido sobre la malla) y el de la empuñadura de la pistola
# (3 x 4,5 cm de sección). Los dedos del maniquí son gruesos: el mango (1,7 a 2,8 cm de radio)
# entra unos milímetros en el puño, que lo tapa; con más hueco la mano queda medio abierta.
GRIP_RADIUS = 0.016
PISTOL_RADIUS = 0.0195
# Ángulos base de las tres falanges (grados) en un puño; se escalan hasta el radio pedido.
FIST_CURL = (72.0, 95.0, 55.0)
OPEN_CURL = (12.0, 18.0, 10.0)
# Inclinación de la empuñadura de la pistola (tools/blender/items.py: rot_x = 14).
PISTOL_RAKE_DEG = 14.0
# Puntos del arma en sus coordenadas (items.py): centro de la empuñadura de la pistola y de la
# escopeta, y gatillo de la pistola.
PISTOL_GRIP_CENTER = Vector((0.0, -0.045, 0.01))
SHOTGUN_GRIP_CENTER = Vector((0.0, -0.04, 0.04))
TRIGGER = Vector((0.0, -0.042, -0.022))
# Punta del pulgar en la pistola: por el lado interior del armazón, delante de la empuñadura.
THUMB_ON_PISTOL = Vector((-0.026, -0.015, -0.045))
# Giro de la muñeca hacia el meñique en el puño (grados, negativo) y márgenes del giro de la
# pistola: una muñeca de verdad se dobla unos 35 grados hacia el meñique y 20 hacia el pulgar.
FIST_DEVIATION = -30.0
PISTOL_DEVIATION_RANGE = (-35.0, 20.0)
# Medio tramo del mango (m) en el que se mide el hueco libre: el puño más lo que asoma el mango
# por los dos lados (el talón de la mano y el pulgar no pueden tocarlo).
FIST_HALF_WIDTH = 0.065
# Separación extra (m) entre las articulaciones del pulgar y el mango: el pulgar es más grueso
# que su hueso.
THUMB_MARGIN = 0.008
# Un punto está rodeado por la mano si en casi todos los sectores del corte hay mano a menos de
# este margen más allá del hueco libre.
SECTORS = 8
ENCLOSE_MARGIN = 0.02
# Parte del antebrazo que se queda con la mano (m antes de la muñeca): la tapa la manga.
WRIST_KEEP = 0.025
# Fracción de triángulos del maniquí que se conserva (unos 1500 por mano).
HAND_DETAIL = 0.3
SKIN = (0.72, 0.55, 0.43)
NAIL = (0.8, 0.66, 0.58)


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


class Rig:
    """Maniquí cargado con su esqueleto en reposo y el marco de la muñeca derecha."""

    def __init__(self) -> None:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=UAL1)
        self.arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
        self.body = next(o for o in bpy.data.objects
                         if o.type == "MESH" and o.name.startswith("Mannequin"))
        for obj in list(bpy.data.objects):
            if obj.type == "MESH" and obj is not self.body:
                bpy.data.objects.remove(obj, do_unlink=True)
        if self.arm.animation_data is not None:
            self.arm.animation_data.action = None
            for track in list(self.arm.animation_data.nla_tracks):
                self.arm.animation_data.nla_tracks.remove(track)
        self._simplify()
        for pb in self.arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
        self.reset()
        # Marco de la muñeca (Godot): -Z por el antebrazo, +X por el dorso (lado exterior).
        wrist = self.head("hand_r")
        forward = (wrist - self.head("lowerarm_r")).normalized()
        lateral = (self.head("index_01_r") - self.head("pinky_01_r")).normalized()
        back = forward.cross(lateral).normalized()
        self.origin = wrist
        self.gz = -forward
        self.gx = back
        self.gy = self.gz.cross(self.gx).normalized()
        self.gx = self.gy.cross(self.gz).normalized()
        self.rest_lateral = lateral
        self.curl_sign = self._find_curl_sign()
        groups = {g.index: g.name for g in self.body.vertex_groups}
        self.hand_indices = []
        for v in self.body.data.vertices:
            best = max(v.groups, key=lambda g: g.weight, default=None)
            name = groups[best.group] if best is not None else ""
            if name.endswith("_r") and name.split("_")[0] in HAND_BONES:
                self.hand_indices.append(v.index)
        self.finger_radius = self._finger_radius()

    def _simplify(self) -> None:
        """Menos triángulos (para el peso de la web y el celular), con los pesos de los huesos."""
        mod = self.body.modifiers.new("Simplificar", "DECIMATE")
        mod.ratio = HAND_DETAIL
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = self.body
        while self.body.modifiers[0] != mod:
            bpy.ops.object.modifier_move_up(modifier=mod.name)
        bpy.ops.object.modifier_apply(modifier=mod.name)

    def reset(self) -> None:
        for pb in self.arm.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector()
            pb.scale = Vector((1.0, 1.0, 1.0))
        bpy.context.view_layer.update()

    def head(self, name: str) -> Vector:
        return self.arm.matrix_world @ self.arm.pose.bones[name].head

    def godot(self, world: Vector) -> Vector:
        d = world - self.origin
        return Vector((d.dot(self.gx), d.dot(self.gy), d.dot(self.gz)))

    def world_dir(self, g: Vector) -> Vector:
        return (self.gx * g.x + self.gy * g.y + self.gz * g.z).normalized()

    def local_axis(self, name: str, world_axis: Vector) -> Vector:
        """Eje del mundo en el marco de reposo del hueso (los padres aún sin girar)."""
        rest = (self.arm.matrix_world @ self.arm.pose.bones[name].bone.matrix_local).to_3x3()
        return (rest.inverted() @ world_axis).normalized()

    def rotate(self, name: str, world_axis: Vector, degrees: float) -> None:
        axis = self.local_axis(name, world_axis)
        self.arm.pose.bones[name].rotation_quaternion = Quaternion(axis, math.radians(degrees))

    def _find_curl_sign(self) -> float:
        palm = -self.gx
        before = self.head("index_04_leaf_r")
        self.rotate("index_01_r", self.rest_lateral, 30.0)
        bpy.context.view_layer.update()
        moved = self.head("index_04_leaf_r") - before
        self.reset()
        return 1.0 if moved.dot(palm) > 0.0 else -1.0

    def _finger_radius(self) -> float:
        groups = {g.index: g.name for g in self.body.vertex_groups}
        a, b = self.head("middle_02_r"), self.head("middle_03_r")
        line = b - a
        total, count = 0.0, 0
        for v in self.body.data.vertices:
            best = max(v.groups, key=lambda g: g.weight, default=None)
            if best is None or groups[best.group] != "middle_02_r":
                continue
            p = self.body.matrix_world @ v.co
            t = max(0.0, min(1.0, (p - a).dot(line) / line.length_squared))
            total += (p - (a + line * t)).length
            count += 1
        return total / max(count, 1)

    def curl_finger(self, finger: str, angles) -> None:
        for i, angle in enumerate(angles):
            self.rotate("%s_0%d_r" % (finger, i + 1), self.rest_lateral, angle * self.curl_sign)

    def update(self) -> None:
        bpy.context.view_layer.update()


def circle_center(points, axis: Vector):
    """Centro y radio del círculo que mejor pasa por los puntos, en el plano normal al eje."""
    u = axis.normalized()
    ref = Vector((1.0, 0.0, 0.0)) if abs(u.x) < 0.9 else Vector((0.0, 1.0, 0.0))
    e1 = u.cross(ref).normalized()
    e2 = u.cross(e1).normalized()
    origin = points[0]
    xy = np.array([[(p - origin).dot(e1), (p - origin).dot(e2)] for p in points])
    mat = np.column_stack([xy[:, 0], xy[:, 1], np.ones(len(points))])
    rhs = -(xy[:, 0] ** 2 + xy[:, 1] ** 2)
    a, b, c = np.linalg.lstsq(mat, rhs, rcond=None)[0]
    cx, cy = -a / 2.0, -b / 2.0
    radius = math.sqrt(max(cx * cx + cy * cy - c, 0.0))
    along = sum((p - origin).dot(u) for p in points) / len(points)
    center = origin + e1 * cx + e2 * cy + u * along
    return center, radius


def channel(rig: Rig, fingers):
    """Eje del hueco que dejan los dedos doblados: centro, dirección (del meñique al índice) y
    radio interior medio."""
    lateral = (rig.head("index_01_r") - rig.head("pinky_01_r")).normalized()
    centers, radii = [], []
    for finger in fingers:
        pts = [rig.head("%s_0%d_r" % (finger, i)) for i in (1, 2, 3)]
        pts.append(rig.head("%s_04_leaf_r" % finger))
        center, radius = circle_center(pts, lateral)
        centers.append(center)
        radii.append(radius - rig.finger_radius)
    direction = (centers[0] - centers[-1]).normalized()
    middle = sum(centers, Vector()) / len(centers)
    return middle, direction, sum(radii) / len(radii)


def hand_points(rig: Rig) -> np.ndarray:
    """Vértices de la mano en la pose actual (coordenadas del mundo)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = rig.body.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    world = rig.body.matrix_world
    points = np.array([tuple(world @ mesh.vertices[i].co) for i in rig.hand_indices])
    evaluated.to_mesh_clear()
    return points


def free_channel(rig: Rig, fingers):
    """Hueco libre de verdad dentro del puño, medido sobre la malla (palma incluida): con la
    dirección del eje que dan los dedos, busca en el corte el punto más alejado de todos los
    vértices del tramo del puño. Devuelve centro, dirección y radio libre."""
    guess, direction, _radius = channel(rig, fingers)
    points = hand_points(rig)
    u = np.array(tuple(direction))
    g = np.array(tuple(guess))
    rel = points - g
    along = rel @ u
    near = rel[np.abs(along) < FIST_HALF_WIDTH]
    radial = near - np.outer(near @ u, u)
    ref = np.array([1.0, 0.0, 0.0]) if abs(u[0]) < 0.9 else np.array([0.0, 1.0, 0.0])
    e1 = np.cross(u, ref)
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(u, e1)
    px = radial @ e1
    py = radial @ e2
    best = (-1.0, g)
    steps = np.arange(-0.03, 0.0301, 0.002)
    for a in steps:
        for b in steps:
            dx = px - a
            dy = py - b
            dist = np.hypot(dx, dy)
            clearance = float(np.min(dist))
            if clearance <= best[0]:
                continue
            # Solo cuenta un hueco rodeado por la mano (no el aire de fuera del puño): en casi
            # todas las direcciones del corte tiene que haber mano cerca.
            close = dist < clearance + ENCLOSE_MARGIN
            sectors = np.floor((np.arctan2(dy[close], dx[close]) + math.pi) / (2 * math.pi)
                               * SECTORS).astype(int) % SECTORS
            if len(set(sectors.tolist())) >= SECTORS - 2:
                best = (clearance, g + e1 * a + e2 * b)
    if best[0] < 0.0:
        # Mano demasiado abierta: ningún punto queda rodeado.
        return guess, direction, 1.0
    return Vector(best[1]), direction, best[0]


def fit_curl(rig: Rig, fingers, base, target_radius: float, deviation) -> float:
    """Escala de los ángulos base: la más cerrada que aún deja el hueco del radio pedido (los
    dedos abrazan el mango sin atravesarlo). Se prueba en pasos fijos."""
    scans = []
    scale = 0.5
    while scale <= 1.6 + 1e-6:
        pose(rig, fingers, base, scale, deviation)
        _c, _d, radius = free_channel(rig, fingers)
        scans.append((scale, radius))
        scale += 0.05
    fitting = [sr for sr in scans if target_radius <= sr[1] < 0.5]
    if fitting:
        return max(fitting)[0]
    enclosed = [sr for sr in scans if sr[1] < 0.5]
    return max(enclosed, key=lambda sr: sr[1])[0] if enclosed else 1.0


def pose(rig: Rig, fingers, base, scale: float, deviation) -> None:
    rig.reset()
    if deviation is not None:
        rig.rotate("hand_r", deviation[0], deviation[1])
    for finger in fingers:
        rig.curl_finger(finger, [a * scale for a in base])
    rig.update()


def best_deviation(rig: Rig, fingers, base, scale: float, want: Vector) -> float:
    """Giro de la muñeca (alrededor del dorso) que alinea el eje del puño con want."""
    best, best_angle = -2.0, 0.0
    step_list = [(PISTOL_DEVIATION_RANGE[0], PISTOL_DEVIATION_RANGE[1], 5.0)]
    for lo, hi, step in step_list:
        angle = lo
        while angle <= hi + 1e-6:
            pose(rig, fingers, base, scale, (rig.gx, angle))
            _c, direction, _r = channel(rig, fingers)
            score = direction.dot(want)
            if score > best:
                best, best_angle = score, angle
            angle += step
    # Afinado de grado en grado alrededor del mejor.
    for k in range(-5, 6):
        angle = best_angle + k
        if angle < PISTOL_DEVIATION_RANGE[0] or angle > PISTOL_DEVIATION_RANGE[1]:
            continue
        pose(rig, fingers, base, scale, (rig.gx, angle))
        _c, direction, _r = channel(rig, fingers)
        score = direction.dot(want)
        if score > best:
            best, best_angle = score, angle
    return best_angle


def search_thumb(rig: Rig, target: Vector, avoid_center: Vector, avoid_dir: Vector,
                 avoid_radius: float) -> None:
    """Coloca el pulgar con la punta lo más cerca posible del objetivo sin entrar en el mango.
    Rejilla fija de giros del primer hueso y flexión de los otros dos."""
    base = {}
    for name in ("thumb_01_r", "thumb_02_r", "thumb_03_r"):
        base[name] = Quaternion(rig.arm.pose.bones[name].rotation_quaternion)
    palm = -rig.gx
    best = (1e9, None)
    angles = [-75.0, -50.0, -25.0, 0.0, 25.0, 50.0, 75.0]
    flex = [0.0, 25.0, 50.0]
    # Ejes del mundo en reposo: lateral, adelante y normal de la palma.
    forward = -rig.gz
    for a in angles:
        for b in angles:
            for f in flex:
                q = (Quaternion(rig.local_axis("thumb_01_r", rig.rest_lateral), math.radians(a))
                     @ Quaternion(rig.local_axis("thumb_01_r", forward), math.radians(b)))
                rig.arm.pose.bones["thumb_01_r"].rotation_quaternion = q
                for name in ("thumb_02_r", "thumb_03_r"):
                    axis = rig.local_axis(name, palm.cross(forward))
                    rig.arm.pose.bones[name].rotation_quaternion = Quaternion(axis, math.radians(f))
                rig.update()
                tip = rig.head("thumb_04_leaf_r")
                cost = (tip - target).length
                for name in ("thumb_02_r", "thumb_03_r", "thumb_04_leaf_r"):
                    p = rig.head(name)
                    d = p - avoid_center
                    radial = (d - avoid_dir * d.dot(avoid_dir)).length
                    if radial < avoid_radius + rig.finger_radius + THUMB_MARGIN:
                        cost += 1.0
                if cost < best[0]:
                    best = (cost, (q, f))
    q, f = best[1]
    rig.arm.pose.bones["thumb_01_r"].rotation_quaternion = q
    for name in ("thumb_02_r", "thumb_03_r"):
        axis = rig.local_axis(name, palm.cross(forward))
        rig.arm.pose.bones[name].rotation_quaternion = Quaternion(axis, math.radians(f))
    rig.update()


def search_index(rig: Rig, to_weapon, target_weapon: Vector) -> None:
    """Índice estirado por el costado del arma con la punta en el gatillo (coordenadas del arma)."""
    best = (1e9, None)
    for c1 in range(0, 61, 10):
        for c2 in range(0, 91, 10):
            for c3 in range(0, 61, 15):
                rig.curl_finger("index", (c1, c2, c3))
                rig.update()
                tip = to_weapon(rig.head("index_04_leaf_r"))
                cost = (tip - target_weapon).length
                # Las falanges no pueden atravesar la corredera: van por el costado exterior.
                for name in ("index_02_r", "index_03_r"):
                    p = to_weapon(rig.head(name))
                    if p.x < 0.016 + rig.finger_radius and p.y > -0.03:
                        cost += 0.5
                    # Y por debajo de la corredera, no por encima.
                    if p.y > -0.012:
                        cost += 0.5
                if cost < best[0]:
                    best = (cost, (c1, c2, c3))
    rig.curl_finger("index", best[1])
    rig.update()


def bake(rig: Rig):
    """Malla de la mano en la pose actual, en coordenadas de la muñeca (Godot): lista de
    triángulos (posiciones, normales, colores por esquina)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = rig.body.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    groups = {g.index: g.name for g in rig.body.vertex_groups}
    keep = []
    tip = []
    for v in rig.body.data.vertices:
        best = max(v.groups, key=lambda g: g.weight, default=None)
        name = groups[best.group] if best is not None else ""
        world = rig.body.matrix_world @ mesh.vertices[v.index].co
        local = rig.godot(world)
        inside = name.endswith("_r") and name.split("_")[0] in HAND_BONES
        if name == "lowerarm_r" and local.z < WRIST_KEEP:
            inside = True
        keep.append(inside)
        tip.append(name.endswith("_03_r") and name.split("_")[0] in FINGERS)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    for vert in bm.verts:
        vert.co = rig.godot(rig.body.matrix_world @ vert.co)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(keep[v.index] for v in f.verts)],
                     context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
    bm.normal_update()
    tris = []
    skin = tuple(srgb_to_linear(c) for c in SKIN) + (1.0,)
    nail = tuple(srgb_to_linear(c) for c in NAIL) + (1.0,)
    for face in bm.faces:
        corners = []
        for loop in face.loops:
            vert = loop.vert
            color = nail if tip[vert.index] else skin
            # Godot (x, y, z) es también glTF (y arriba): se escribe tal cual.
            corners.append((tuple(vert.co), tuple(vert.normal), color))
        tris.append(corners)
    bm.free()
    evaluated.to_mesh_clear()
    return tris


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


def hold_frame(rig: Rig, center: Vector, direction: Vector, weapon_axis: Vector,
               weapon_point: Vector):
    """Colocación del arma en coordenadas de la muñeca: su eje de agarre (weapon_axis, en sus
    coordenadas) va por el eje del puño y su punto de agarre (weapon_point) al centro del puño;
    su +X queda hacia el dorso. Devuelve (base 3x3 como columnas, origen)."""
    axis_g = rig.godot(rig.origin + direction).normalized()
    hint = Vector((1.0, 0.0, 0.0))
    x_t = (hint - axis_g * hint.dot(axis_g)).normalized()
    target = Matrix((x_t, axis_g, x_t.cross(axis_g))).transposed()
    a_w = weapon_axis.normalized()
    x_w = Vector((1.0, 0.0, 0.0))
    x_w = (x_w - a_w * x_w.dot(a_w)).normalized()
    weapon = Matrix((x_w, a_w, x_w.cross(a_w))).transposed()
    basis = target @ weapon.transposed()
    origin = rig.godot(center) - basis @ weapon_point
    return basis, origin


def build_all():
    """Hornea las tres formas. Devuelve {nombre: triángulos} y la colocación de las armas que
    usa el juego (base y origen en coordenadas de la muñeca)."""
    rig = Rig()
    results = {}
    info = {}
    forward = -rig.gz
    # Puño: hueco del radio del mango y la muñeca algo caída hacia el meñique (sin pasar de lo
    # que dobla una muñeca de verdad); el mango sale por el lado del pulgar.
    deviation = (rig.gx, FIST_DEVIATION)
    scale = fit_curl(rig, FINGERS, FIST_CURL, GRIP_RADIUS, deviation)
    pose(rig, FINGERS, FIST_CURL, scale, deviation)
    center, direction, radius = free_channel(rig, FINGERS)
    # El pulgar cierra por el lado interior (el de la palma), sobre el índice y el corazón.
    inner = -rig.gx
    inner = (inner - direction * inner.dot(direction)).normalized()
    thumb_target = center + inner * (radius + rig.finger_radius * 2.0) + direction * 0.012
    search_thumb(rig, thumb_target, center, direction, radius)
    results["grip"] = bake(rig)
    # Armas de cuerpo a cuerpo y objetos: apuntan a -Z desde su punto de agarre (el origen).
    info["melee"] = hold_frame(rig, center, direction, Vector((0.0, 0.0, -1.0)), Vector())
    info["grip_radius"] = radius
    # Pistola: corazón, anular y meñique alrededor de la empuñadura inclinada.
    rake = math.radians(PISTOL_RAKE_DEG)
    pistol_axis = Vector((0.0, math.cos(rake), math.sin(rake)))
    want = rig.world_dir(pistol_axis)
    fingers = ("middle", "ring", "pinky")
    scale = fit_curl(rig, fingers, FIST_CURL, PISTOL_RADIUS, None)
    angle = best_deviation(rig, fingers, FIST_CURL, scale, want)
    deviation = (rig.gx, angle)
    scale = fit_curl(rig, fingers, FIST_CURL, PISTOL_RADIUS, deviation)
    pose(rig, fingers, FIST_CURL, scale, deviation)
    center, direction, radius = free_channel(rig, fingers)
    basis, origin = hold_frame(rig, center, direction, pistol_axis, PISTOL_GRIP_CENTER)
    inverse = basis.inverted()

    def to_weapon(world: Vector) -> Vector:
        return inverse @ (rig.godot(world) - origin)

    search_index(rig, to_weapon, TRIGGER)
    side = basis @ THUMB_ON_PISTOL + origin
    thumb_target = rig.origin + rig.gx * side.x + rig.gy * side.y + rig.gz * side.z
    search_thumb(rig, thumb_target, center, direction, radius)
    results["pistol"] = bake(rig)
    info["pistol"] = (basis, origin)
    info["shotgun"] = hold_frame(rig, center, direction, Vector((0.0, 1.0, 0.0)),
                                 SHOTGUN_GRIP_CENTER)
    info["pistol_deviation"] = angle
    info["pistol_radius"] = radius
    # Abierta y relajada.
    pose(rig, FINGERS, OPEN_CURL, 1.0, None)
    rig.rotate("thumb_02_r", (-rig.gx).cross(forward), 15.0)
    rig.update()
    results["open"] = bake(rig)
    return results, info
