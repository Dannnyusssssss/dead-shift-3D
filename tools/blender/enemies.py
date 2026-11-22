"""Enemigos: cuerpos de Quaternius (CC0) con ropa pintada por zonas y animaciones de UAL.

Uso: blender --background --factory-startup --python tools/blender/enemies.py

Para cada enemigo: importa el cuerpo base (assets/third_party/quaternius-ubc), quita ojos y
cejas, une las costuras (sin grietas al adelgazar), lo simplifica (unos 3000 triángulos, para el celular), pinta la ropa y la piel en el
color de vértice según el hueso que mueve cada vértice (cabeza, torso, brazos, piernas, pies),
lo adelgaza hacia el eje de sus huesos, le alisa el relieve de músculos y le acerca los brazos
al cuerpo (el cuerpo base es de complexión de superhéroe; El Técnico se queda corpulento),
añade pelo con volumen (una capa sobre el cuero cabelludo, con los pesos de la cabeza) y
accesorios rígidos en la cabeza (gorra, máscara, moño) y le pone las animaciones de
assets/third_party/quaternius-ual1/2 con nombres propios (idle, walk, run, attack, hit,
hit_head, stun, death). Escribe assets/generated/enemies/<id>.glb. Siluetas distintas:
caminante (civil roto), oyente (capucha), policía (uniforme y gorra), acechador (delgado,
corre agachado) y El Técnico (traje amarillo y máscara antigás).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
UBC = os.path.join(ROOT, "assets", "third_party", "quaternius-ubc", "body")
UAL1 = os.path.join(ROOT, "assets", "third_party", "quaternius-ual1", "UAL1_Standard.glb")
UAL2 = os.path.join(ROOT, "assets", "third_party", "quaternius-ual2", "UAL2_Standard.glb")
OUT = os.path.join(ROOT, "assets", "generated", "enemies")
PEOPLE_OUT = os.path.join(ROOT, "assets", "generated", "people")

TARGET_TRIANGLES = 3000

# Animación propia -> acción de UAL.
ANIMATIONS = {
    "idle": "Zombie_Idle_Loop",
    "walk": "Zombie_Walk_Fwd_Loop",
    "run": "Sprint_Loop",
    "attack": "Zombie_Scratch",
    "hit": "Hit_Chest",
    "hit_head": "Hit_Head",
    "stun": "Hit_Knockback",
    "death": "Death01",
}

# Personas de la intro (no son enemigos): animaciones normales de UAL.
HUMAN_ANIMATIONS = {
    "idle": "Idle_Loop",
    "sit": "Sitting_Idle_Loop",
    "talk": "Idle_TalkingPhone_Loop",
    "fix": "Fixing_Kneeling",
    "wake": "LayToIdle",
    "panic": "Hit_Knockback",
    "run": "Sprint_Loop",
    "walk": "Walk_Loop",
    # Intro: sobresalto con la alarma, desplomarse con el gas y levantarse de la silla.
    "flinch": "Hit_Chest",
    "collapse": "Death01",
    "stand_up": "Sitting_Exit",
}

# Zonas por hueso (el prefijo basta: index_01_l -> mano).
ZONES = [
    ("Head", "head"), ("neck", "head"),
    ("hand", "hand"), ("index", "hand"), ("middle", "hand"), ("pinky", "hand"),
    ("ring", "hand"), ("thumb", "hand"),
    ("lowerarm", "forearm"), ("upperarm", "upperarm"), ("clavicle", "torso"),
    ("spine", "torso"), ("pelvis", "hips"), ("thigh", "legs"), ("calf", "legs"),
    ("foot", "feet"), ("ball", "feet"), ("root", "hips"),
]

ZOMBIE_SKIN = (0.42, 0.47, 0.37)
PALE_SKIN = (0.6, 0.6, 0.55)
BLUE_SKIN = (0.44, 0.48, 0.52)
DIRT = (0.22, 0.17, 0.12)

ENEMIES = {
    "walker": {
        "body": "Superhero_Male_FullBody.gltf",
        "colors": {"head": ZOMBIE_SKIN, "hand": ZOMBIE_SKIN, "forearm": ZOMBIE_SKIN,
                   "upperarm": (0.55, 0.5, 0.4), "torso": (0.55, 0.5, 0.4),
                   "hips": (0.22, 0.27, 0.38), "legs": (0.22, 0.27, 0.38),
                   "feet": (0.12, 0.1, 0.09)},
        "tears": 0.18,
        "hair": {"color": (0.17, 0.12, 0.08), "messy": 1.2, "thickness": 0.013},
    },
    "listener": {
        "body": "Superhero_Female_FullBody.gltf",
        "colors": {"head": PALE_SKIN, "hand": PALE_SKIN, "forearm": (0.18, 0.18, 0.22),
                   "upperarm": (0.18, 0.18, 0.22), "torso": (0.18, 0.18, 0.22),
                   "hips": (0.3, 0.3, 0.32), "legs": (0.3, 0.3, 0.32), "feet": (0.5, 0.5, 0.5)},
        "hood": (0.18, 0.18, 0.22),
        "tears": 0.1,
    },
    "police": {
        "body": "Superhero_Male_FullBody.gltf",
        "colors": {"head": ZOMBIE_SKIN, "hand": ZOMBIE_SKIN, "forearm": (0.12, 0.16, 0.28),
                   "upperarm": (0.12, 0.16, 0.28), "torso": (0.12, 0.16, 0.28),
                   "hips": (0.08, 0.1, 0.16), "legs": (0.08, 0.1, 0.16),
                   "feet": (0.05, 0.05, 0.05)},
        "cap": (0.1, 0.13, 0.22),
        "tears": 0.08,
        "hair": {"color": (0.09, 0.08, 0.07), "under_cap": True, "low": 0.38,
                 "thickness": 0.01},
    },
    "stalker": {
        "body": "Superhero_Female_FullBody.gltf",
        "colors": {"head": BLUE_SKIN, "hand": BLUE_SKIN, "forearm": BLUE_SKIN,
                   "upperarm": BLUE_SKIN, "torso": (0.4, 0.12, 0.1),
                   "hips": (0.16, 0.16, 0.18), "legs": BLUE_SKIN, "feet": (0.1, 0.1, 0.1)},
        "lean": 0.86,
        "tears": 0.15,
        "hair": {"color": (0.36, 0.14, 0.07), "long": 0.05, "messy": 0.8, "thickness": 0.016},
    },
    "technician": {
        "body": "Superhero_Male_FullBody.gltf",
        "colors": {"head": (0.78, 0.66, 0.14), "hand": (0.06, 0.06, 0.06),
                   "forearm": (0.78, 0.66, 0.14), "upperarm": (0.78, 0.66, 0.14),
                   "torso": (0.78, 0.66, 0.14), "hips": (0.78, 0.66, 0.14),
                   "legs": (0.78, 0.66, 0.14), "feet": (0.06, 0.06, 0.06)},
        "mask": True,
        "tears": 0.07,
        # El jefe sí es corpulento: menos adelgazado, sin estrechar los hombros y poco alisado.
        "slim": 0.45,
        "smooth": 2,
        "narrow": 0.0,
    },
}


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def zone_of(bone: str) -> str:
    for prefix, zone in ZONES:
        if bone.startswith(prefix):
            return zone
    return "torso"


def noise(i: int) -> float:
    """Ruido fijo por índice (0 a 1), sin aleatoriedad."""
    x = math.sin(i * 12.9898 + 78.233) * 43758.5453
    return x - math.floor(x)


def import_body(filename: str):
    bpy.ops.import_scene.gltf(filepath=os.path.join(UBC, filename))
    armature = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = None
    for obj in list(bpy.data.objects):
        if obj.type != "MESH":
            continue
        if obj.name.startswith(("Eyes", "Eyebrows", "Icosphere")):
            bpy.data.objects.remove(obj, do_unlink=True)
        else:
            body = obj
    return armature, body


# Distancia (m) a la que se unen los vértices repetidos de las costuras del modelo base.
WELD_DISTANCE = 0.0001


def weld(body) -> None:
    """Une los vértices repetidos de las costuras: el cuerpo base viene partido en piezas (cada
    costura con sus vértices duplicados y sin unir). Sin esto, al simplificar y al alisar cada
    lado de una costura se mueve por su cuenta y se abren grietas en hombros, cintura y piernas."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD_DISTANCE)
    bm.to_mesh(body.data)
    bm.free()


def check_closed(body, name: str) -> None:
    """Falla si la malla del cuerpo tiene bordes abiertos (una grieta se vería en el juego)."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    open_edges = sum(1 for e in bm.edges if e.is_boundary)
    bm.free()
    if open_edges:
        raise RuntimeError("%s: %d bordes abiertos en el cuerpo" % (name, open_edges))


def simplify(body) -> None:
    triangles = sum(len(p.vertices) - 2 for p in body.data.polygons)
    mod = body.modifiers.new("Simplificar", "DECIMATE")
    mod.ratio = min(1.0, TARGET_TRIANGLES / max(triangles, 1))
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = body
    while body.modifiers[0] != mod:
        bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def paint(body, spec: dict) -> None:
    mesh = body.data
    groups = {g.index: g.name for g in body.vertex_groups}
    # Solo queda el color propio (el modelo base trae otros atributos de color).
    for old in list(mesh.color_attributes):
        mesh.color_attributes.remove(old)
    attr = mesh.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    head_top = max(v.co.z for v in mesh.vertices)
    for v in mesh.vertices:
        best = max(v.groups, key=lambda g: g.weight, default=None)
        zone = zone_of(groups[best.group]) if best is not None else "torso"
        rgb = spec["colors"][zone]
        # Capucha: la parte alta y trasera de la cabeza del color de la sudadera.
        if spec.get("hood") and zone == "head" and (v.co.z > head_top - 0.2 or v.co.y > 0.02):
            rgb = spec["hood"]
        # Ropa rota y manchada: trozos de piel y suciedad en sitios fijos.
        # Ruido por celdas de 9 cm: rotos y manchas en parches, no motas sueltas.
        cell = (math.floor(v.co.x / 0.09), math.floor(v.co.y / 0.09), math.floor(v.co.z / 0.09))
        n = noise(cell[0] * 73 + cell[1] * 179 + cell[2] * 283)
        if zone in ("torso", "upperarm", "legs", "hips") and n < spec.get("tears", 0.0):
            rgb = spec["colors"]["head"] if not spec.get("mask") else (0.5, 0.42, 0.36)
        elif n > 0.93:
            rgb = tuple(c * 0.5 + d * 0.5 for c, d in zip(rgb, DIRT))
        shade = 0.88 + 0.12 * noise(v.index * 7 + 3)
        attr.data[v.index].color = tuple(srgb_to_linear(c * shade) for c in rgb) + (1.0,)
    mesh.color_attributes.active_color = attr


# Cuerpo menos musculoso: cuánto se acerca cada zona al eje de su hueso (0 = sin cambio).
# El cuerpo base es de complexión de superhéroe; con esto queda una persona corriente.
SLIM = {"torso": 0.3, "upperarm": 0.34, "forearm": 0.28, "legs": 0.22, "hips": 0.12}
# El cuello (zona de la cabeza) lleva el trapecio abultado: se estrecha aparte.
SLIM_NECK = 0.25


def slim(body, armature, scale: float = 1.0) -> None:
    """Estrecha cada vértice hacia el eje de los huesos que lo mueven, mezclando por el peso de
    cada hueso: así no hay escalones entre zonas (el codo queda entre brazo y antebrazo). Cabeza,
    manos y pies no cambian. Solo mueve vértices: mismos triángulos, esqueleto y animaciones."""
    groups = {g.index: g.name for g in body.vertex_groups}
    to_world = body.matrix_world
    to_local = to_world.inverted()
    # Eje de cada hueso (inicio y fin) en el mundo, en la pose de reposo.
    axes = {}
    for bone in armature.data.bones:
        axes[bone.name] = (armature.matrix_world @ bone.head_local,
                           armature.matrix_world @ bone.tail_local)
    for v in body.data.vertices:
        total = sum(g.weight for g in v.groups)
        if total <= 0.0:
            continue
        point = to_world @ v.co
        shift = Vector((0.0, 0.0, 0.0))
        for g in v.groups:
            name = groups[g.group]
            amount = SLIM_NECK if name.startswith("neck") else SLIM.get(zone_of(name), 0.0)
            amount *= scale
            if amount <= 0.0 or name not in axes:
                continue
            # Punto más cercano del eje del hueso (segmento de inicio a fin).
            start, end = axes[name]
            line = end - start
            length = line.length_squared
            t = 0.0 if length < 1e-9 else max(0.0, min(1.0, (point - start).dot(line) / length))
            closest = start + line * t
            shift += (closest - point) * amount * (g.weight / total)
        v.co = to_local @ (point + shift)


# Zonas que se alisan: el cuerpo base trae pectorales, abdominales y bíceps marcados de
# superhéroe; alisados queda la silueta de una persona corriente con ropa.
SMOOTH_ZONES = ("torso", "upperarm", "forearm", "hips", "legs")
# Hombros: el cuerpo masculino base tiene la clavícula larga (42 cm entre hombros); se acercan
# los brazos al cuerpo hasta unos 37 cm, como el maniquí de UAL.
NARROW_MALE = 0.025
# Huesos de cada brazo (todo lo que cuelga de la clavícula se mueve junto).
ARM_PREFIXES = ("upperarm", "lowerarm", "hand", "index", "middle", "ring", "pinky", "thumb")


def smooth_body(body, iterations: int) -> None:
    """Alisa los vértices que solo mueven huesos del cuerpo (no la cabeza, las manos ni los
    pies): quita el relieve de músculos sin tocar los bordes con la cabeza o las manos."""
    if iterations <= 0:
        return
    groups = {g.index: g.name for g in body.vertex_groups}
    movable = set()
    for v in body.data.vertices:
        zones = {zone_of(groups[g.group]) for g in v.groups if g.weight > 0.01}
        if zones and zones.issubset(SMOOTH_ZONES):
            movable.add(v.index)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    verts = [bm.verts[i] for i in sorted(movable)]
    for _ in range(iterations):
        bmesh.ops.smooth_vert(bm, verts=verts, factor=0.5, use_axis_x=True, use_axis_y=True,
                              use_axis_z=True)
    bm.to_mesh(body.data)
    bm.free()


def narrow_shoulders(body, armature, amount: float) -> None:
    """Acerca los brazos al cuerpo `amount` metros por lado: mueve los huesos del brazo (y la
    punta de la clavícula) en el esqueleto de reposo y los vértices con el mismo reparto de
    pesos. Las animaciones giran los huesos, así que siguen valiendo."""
    if amount <= 0.0:
        return
    world_to_arm = armature.matrix_world.inverted().to_3x3()

    def shift_of(name: str) -> Vector:
        side = 1.0 if name.endswith("_l") else -1.0 if name.endswith("_r") else 0.0
        if side == 0.0:
            return Vector((0.0, 0.0, 0.0))
        if name.startswith(ARM_PREFIXES):
            return Vector((-side * amount, 0.0, 0.0))
        if name.startswith("clavicle"):
            return Vector((-side * amount * 0.5, 0.0, 0.0))
        return Vector((0.0, 0.0, 0.0))

    # Lado de cada hueso según su posición en el mundo (x > 0 es el lado izquierdo).
    for bone in armature.data.bones:
        head = armature.matrix_world @ bone.head_local
        if bone.name.endswith(("_l", "_r")) and abs(head.x) > 0.01:
            expected = "_l" if head.x > 0 else "_r"
            if not bone.name.endswith(expected):
                raise RuntimeError("Lado inesperado del hueso " + bone.name)
    groups = {g.index: g.name for g in body.vertex_groups}
    to_world = body.matrix_world
    to_local = to_world.inverted()
    for v in body.data.vertices:
        total = sum(g.weight for g in v.groups)
        if total <= 0.0:
            continue
        shift = Vector((0.0, 0.0, 0.0))
        for g in v.groups:
            shift += shift_of(groups[g.group]) * (g.weight / total)
        if shift.length > 0.0:
            v.co = to_local @ (to_world @ v.co + shift)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in armature.data.edit_bones:
        if bone.name.startswith(ARM_PREFIXES):
            delta = world_to_arm @ shift_of(bone.name)
            bone.head += delta
            bone.tail += delta
        elif bone.name.startswith("clavicle"):
            bone.tail += world_to_arm @ (shift_of(bone.name) * 2.0)
    bpy.ops.object.mode_set(mode="OBJECT")


def head_matrix(armature) -> Matrix:
    """Punto de giro de la cabeza en el mundo, sin giro: las piezas se dibujan en ejes de
    Blender (z arriba, el personaje mira hacia -Y)."""
    bone = armature.data.bones["Head"]
    return Matrix.Translation(armature.matrix_world @ bone.head_local)


def add_rigid(body, armature, build, color) -> None:
    """Pieza rígida unida al hueso de la cabeza (gorra, máscara) con su color."""
    bm = bmesh.new()
    build(bm)
    me = bpy.data.meshes.new("pieza")
    bm.to_mesh(me)
    bm.free()
    piece = bpy.data.objects.new("pieza", me)
    bpy.context.scene.collection.objects.link(piece)
    piece.matrix_world = head_matrix(armature)
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    for i in range(len(me.vertices)):
        attr.data[i].color = tuple(srgb_to_linear(c) for c in color) + (1.0,)
    group = piece.vertex_groups.new(name="Head")
    group.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    piece.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()


def cap(bm) -> None:
    # Copa de la gorra sobre la cabeza y visera hacia delante (-Y).
    bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.115, radius2=0.1,
                          depth=0.08, matrix=Matrix.Translation((0, 0.0, 0.2)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, -0.13, 0.165))
                          @ Matrix.Diagonal(Vector((0.19, 0.1, 0.015, 1.0))))


def mask(bm) -> None:
    # Máscara antigás sobre la cara y filtro redondo hacia delante.
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, -0.09, 0.07))
                          @ Matrix.Diagonal(Vector((0.17, 0.08, 0.16, 1.0))))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.05, radius2=0.045,
                          depth=0.08, matrix=Matrix.Translation((0, -0.16, 0.03))
                          @ Matrix.Rotation(math.radians(90), 4, "X"))


# Pelo: una capa sobre el cuero cabelludo sacada de la propia cabeza (mismos pesos de hueso, así
# sigue a la cabeza en las animaciones). Alturas en fracción de la cabeza (0 = giro del cuello,
# 1 = coronilla) y profundidad en fracción hacia la nuca (-1 = la cara, 1 = la nuca).
HAIR_FRINGE = 0.8
HAIR_FACE = -0.45


def _in_hair(z: float, y: float, style: dict) -> bool:
    """Si un punto de la cabeza (altura z, profundidad y, en fracciones) queda bajo el pelo."""
    if style.get("under_cap") and z > 0.72:
        return False
    if y < HAIR_FACE and z < style.get("fringe", HAIR_FRINGE):
        return False
    low = style.get("low", 0.42)
    if style.get("long") and y > -0.1:
        low = style["long"]
    return z >= low


def hair(body, armature, style: dict) -> None:
    """Pelo con volumen: duplica las caras del cuero cabelludo, las separa hacia fuera (más
    revuelto con «messy») y pinta capa y cuero cabelludo del color del pelo. Con «long» baja
    por la nuca (melena); el moño o la coleta se añaden aparte como piezas rígidas."""
    groups = {g.index: g.name for g in body.vertex_groups}
    mesh = body.data
    to_world = body.matrix_world
    pivot = head_matrix(armature).translation
    allowed = ("Head", "neck") if style.get("long") else ("Head",)
    candidates = {}
    for v in mesh.vertices:
        best = max(v.groups, key=lambda g: g.weight, default=None)
        if best is not None and groups[best.group].startswith(allowed):
            candidates[v.index] = to_world @ v.co
    heads = [w for i, w in candidates.items()
             if groups[max(mesh.vertices[i].groups, key=lambda g: g.weight).group]
             .startswith("Head")]
    top = max(w.z for w in heads) - pivot.z
    face = pivot.y - min(w.y for w in heads)
    covered = set()
    for index, w in candidates.items():
        if _in_hair((w.z - pivot.z) / top, (w.y - pivot.y) / face, style):
            covered.add(index)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    color = bm.verts.layers.float_color.get("Color")
    faces = [f for f in bm.faces if all(v.index in covered for v in f.verts)]
    rgba = tuple(srgb_to_linear(c) for c in style["color"]) + (1.0,)
    root = tuple(srgb_to_linear(c * 0.7) for c in style["color"]) + (1.0,)
    scalp = {v for f in faces for v in f.verts}
    normals = {v: v.normal.copy() for v in scalp}
    for v in scalp:
        v[color] = root
    made = bmesh.ops.duplicate(bm, geom=faces)
    mapping = made["vert_map"]
    thickness = style.get("thickness", 0.012)
    messy = style.get("messy", 0.0)
    for old, new in mapping.items():
        if not isinstance(old, bmesh.types.BMVert) or old not in normals:
            continue
        lift = thickness * (1.0 + messy * (noise(old.index * 13 + 5) - 0.3))
        new.co = old.co + normals[old] * lift
        new[color] = tuple(c * (0.9 + 0.2 * noise(old.index * 3 + 1)) for c in rgba[:3]) + (1.0,)
    bm.to_mesh(mesh)
    bm.free()


def bun(bm) -> None:
    # Moño en la parte alta de la nuca.
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=7, radius=0.05,
                              matrix=Matrix.Translation((0, 0.1, 0.17)))


def bring_animations(armature, animations=None) -> None:
    """Importa las bibliotecas de UAL, se queda con las acciones necesarias renombradas y
    borra sus objetos."""
    animations = animations or ANIMATIONS
    before = set(bpy.data.objects)
    for path in (UAL1, UAL2):
        bpy.ops.import_scene.gltf(filepath=path)
    for obj in set(bpy.data.objects) - before:
        bpy.data.objects.remove(obj, do_unlink=True)
    wanted = {source: name for name, source in animations.items()}
    for action in list(bpy.data.actions):
        base = action.name.split(".")[0]
        if base in wanted and wanted[base] not in bpy.data.actions:
            action.name = wanted[base]
            action.use_fake_user = True
        elif action.name not in animations:
            bpy.data.actions.remove(action)
    armature.animation_data_create()
    track_owner = armature.animation_data
    for name in sorted(animations):
        action = bpy.data.actions.get(name)
        if action is None:
            raise RuntimeError("Falta la animación " + animations[name])
        track = track_owner.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, int(action.frame_range[0]), action)
        strip.name = name
        track.mute = True
    track_owner.action = None


def build(enemy_id: str, spec: dict, out_dir: str = OUT) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature, body = import_body(spec["body"])
    body.data.materials.clear()
    weld(body)
    simplify(body)
    paint(body, spec)
    # Después de pintar: los rotos y manchas quedan en los mismos sitios del cuerpo.
    slim(body, armature, spec.get("slim", 1.0))
    smooth_body(body, spec.get("smooth", 6))
    male = spec["body"].startswith("Superhero_Male")
    narrow_shoulders(body, armature, spec.get("narrow", NARROW_MALE if male else 0.0))
    if spec.get("lean"):
        # Delgado: se estrecha el cuerpo en su sitio (no cambia el esqueleto).
        for v in body.data.vertices:
            v.co.x *= spec["lean"]
            v.co.y *= spec["lean"]
    check_closed(body, enemy_id)
    if spec.get("hair"):
        hair(body, armature, spec["hair"])
        if spec["hair"].get("bun"):
            add_rigid(body, armature, bun, spec["hair"]["color"])
    if spec.get("cap"):
        add_rigid(body, armature, cap, spec["cap"])
    if spec.get("mask"):
        add_rigid(body, armature, mask, (0.12, 0.12, 0.13))
    bring_animations(armature, spec.get("animations"))
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out_dir, enemy_id + ".glb"),
        export_format="GLB",
        use_selection=True,
        export_materials="NONE",
        export_texcoords=False,
        export_normals=True,
        export_vertex_color="ACTIVE",
        export_skins=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_extras=False,
        export_yup=True,
    )


SKIN = (0.72, 0.55, 0.43)
SKIN_DARK = (0.48, 0.34, 0.24)
# Personas de la intro: trabajadores de la central y el guardia (mismo uniforme que sus brazos).
HUMANS = {
    "worker": {
        "body": "Superhero_Male_FullBody.gltf",
        "colors": {"head": SKIN, "hand": SKIN, "forearm": (0.85, 0.42, 0.1),
                   "upperarm": (0.85, 0.42, 0.1), "torso": (0.85, 0.42, 0.1),
                   "hips": (0.85, 0.42, 0.1), "legs": (0.85, 0.42, 0.1), "feet": (0.1, 0.1, 0.1)},
        "animations": HUMAN_ANIMATIONS,
        "hair": {"color": (0.1, 0.08, 0.06), "messy": 0.4},
    },
    "worker_f": {
        "body": "Superhero_Female_FullBody.gltf",
        "colors": {"head": SKIN_DARK, "hand": SKIN_DARK, "forearm": (0.86, 0.88, 0.9),
                   "upperarm": (0.86, 0.88, 0.9), "torso": (0.86, 0.88, 0.9),
                   "hips": (0.2, 0.25, 0.4), "legs": (0.2, 0.25, 0.4), "feet": (0.1, 0.1, 0.1)},
        "animations": HUMAN_ANIMATIONS,
        "hair": {"color": (0.08, 0.06, 0.05), "low": 0.5, "bun": True, "thickness": 0.011},
    },
    "guard": {
        "body": "Superhero_Male_FullBody.gltf",
        "colors": {"head": SKIN, "hand": SKIN, "forearm": (0.13, 0.17, 0.27),
                   "upperarm": (0.13, 0.17, 0.27), "torso": (0.13, 0.17, 0.27),
                   "hips": (0.09, 0.12, 0.2), "legs": (0.09, 0.12, 0.2),
                   "feet": (0.05, 0.05, 0.05)},
        "cap": (0.1, 0.13, 0.22),
        "animations": HUMAN_ANIMATIONS,
        "hair": {"color": (0.2, 0.14, 0.09), "under_cap": True, "low": 0.38,
                 "thickness": 0.01},
    },
}


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for enemy_id in sorted(ENEMIES):
        if only and enemy_id not in only:
            continue
        build(enemy_id, ENEMIES[enemy_id])
    os.makedirs(PEOPLE_OUT, exist_ok=True)
    for person_id in sorted(HUMANS):
        if only and person_id not in only:
            continue
        build(person_id, HUMANS[person_id], PEOPLE_OUT)
    print("enemies: listo")
    return 0


if __name__ == "__main__":
    sys.exit(main())
