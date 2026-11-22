"""Escritor mínimo de GLB (glTF 2.0 binario) para los modelos generados por script.

Escribe una sola malla de triángulos sin índices con POSITION, NORMAL (por cara o por esquina) y
COLOR_0 (lineal). No usa el exportador de Blender: así el archivo sale byte a byte igual en
cada ejecución. Sin texturas, materiales, animaciones ni extensiones.
"""

import json
import struct


def _pad(data: bytes, filler: bytes) -> bytes:
    return data + filler * ((4 - len(data) % 4) % 4)


def write_glb(path: str, name: str, triangles) -> None:
    """triangles: lista de (normal, [(pos, color) x 3]) en coordenadas de glTF (y arriba).

    pos y normal son tuplas de 3 floats; color, de 4 floats en lineal. normal también puede ser
    una tupla de 3 normales (una por esquina, para superficies suavizadas)."""
    positions = bytearray()
    normals = bytearray()
    colors = bytearray()
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3
    count = 0
    for normal, corners in triangles:
        per_corner = isinstance(normal[0], (tuple, list))
        for index, (pos, color) in enumerate(corners):
            positions += struct.pack("<3f", *pos)
            normals += struct.pack("<3f", *(normal[index] if per_corner else normal))
            colors += struct.pack("<4f", *color)
            # min y max se toman de los valores ya redondeados a float32, como pide glTF.
            stored = struct.unpack("<3f", struct.pack("<3f", *pos))
            for i in range(3):
                lo[i] = min(lo[i], stored[i])
                hi[i] = max(hi[i], stored[i])
            count += 1
    blob = bytes(positions) + bytes(normals) + bytes(colors)
    views = []
    offset = 0
    for chunk in (positions, normals, colors):
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(chunk), "target": 34962})
        offset += len(chunk)
    gltf = {
        "asset": {"version": "2.0", "generator": "dead-shift-3d tools/blender"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
        "meshes": [{"name": name, "primitives": [
            {"attributes": {"POSITION": 0, "NORMAL": 1, "COLOR_0": 2}, "mode": 4}]}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": count, "type": "VEC3",
             "min": lo, "max": hi},
            {"bufferView": 1, "componentType": 5126, "count": count, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": count, "type": "VEC4"},
        ],
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    json_chunk = _pad(json.dumps(gltf, separators=(",", ":"), sort_keys=True).encode("ascii"), b" ")
    bin_chunk = _pad(blob, b"\x00")
    total = 12 + 8 + len(json_chunk) + 8 + len(bin_chunk)
    with open(path, "wb") as handle:
        handle.write(struct.pack("<4sII", b"glTF", 2, total))
        handle.write(struct.pack("<I4s", len(json_chunk), b"JSON"))
        handle.write(json_chunk)
        handle.write(struct.pack("<I4s", len(bin_chunk), b"BIN\x00"))
        handle.write(bin_chunk)


def triangles_from_bmesh(bm, color_layer):
    """Triángulos de un bmesh ya triangulado, pasados de Blender (z arriba) a glTF (y arriba)."""

    def to_gltf(v):
        return (v.x, v.z, -v.y)

    out = []
    for face in bm.faces:
        corners = [(to_gltf(loop.vert.co), tuple(loop[color_layer])) for loop in face.loops]
        # Empieza por la esquina menor (mismo sentido de giro): el triángulo es el mismo
        # aunque bmesh lo recorra desde otra esquina.
        keys = [tuple(round(c, 5) for c in pos) for pos, _color in corners]
        first = keys.index(min(keys))
        corners = corners[first:] + corners[:first]
        out.append((to_gltf(face.normal), corners))
    # Orden fijo por posición (el recorrido de bmesh depende de la memoria); el orden de los
    # triángulos no cambia el dibujo.
    out.sort(key=lambda tri: [round(c, 5) for pos, _color in tri[1] for c in pos])
    return out
