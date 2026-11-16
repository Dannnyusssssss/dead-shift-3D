"""Textura por capas de las superficies del edificio (suelos, paredes, techos, metal).

Uso: blender --background --factory-startup --python tools/blender/surfaces.py

Lee los mapas de color de assets/third_party/ambientcg/ y escribe en assets/generated/textures/:
  - surfaces_albedo.png: una columna de capas de LAYER_SIZE x LAYER_SIZE (Godot la importa como
    Texture2DArray con una capa por fila).
  - surfaces.json: el orden de las capas (world/surfaces.gd debe coincidir; lo comprueba un test).
Reproducible: mismas fuentes, mismo resultado (sin aleatoriedad ni fechas en el archivo).
"""

import json
import os
import sys

import bpy
import numpy as np

LAYER_SIZE = 512

# Orden de las capas: id de superficie, material de ambientCG y brillo relativo (para que todas
# queden en un rango parecido y el tono de la sala lo dé el color de vértice).
LAYERS = [
    ("plaster", "PaintedPlaster017", 1.0),
    ("concrete_light", "Concrete034", 1.0),
    ("concrete_dark", "Concrete031", 1.15),
    ("tiles_marble", "Tiles078", 1.0),
    ("tiles_checker", "Tiles074", 1.0),
    ("wood_floor", "WoodFloor051", 1.0),
    ("ceiling_tiles", "OfficeCeiling001", 0.9),
    ("corrugated", "CorrugatedSteel005", 1.0),
    ("diamond_plate", "DiamondPlate008A", 1.0),
    ("rust", "Metal064", 1.0),
    ("asphalt", "Asphalt031", 1.05),
]


def root_dir() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def load_layer(path: str) -> np.ndarray:
    image = bpy.data.images.load(path, check_existing=False)
    image.colorspace_settings.name = "sRGB"
    if image.size[0] != LAYER_SIZE or image.size[1] != LAYER_SIZE:
        image.scale(LAYER_SIZE, LAYER_SIZE)
    pixels = np.empty(LAYER_SIZE * LAYER_SIZE * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    # Blender guarda las filas de abajo arriba: se invierten para que la capa quede derecha.
    return pixels.reshape(LAYER_SIZE, LAYER_SIZE, 4)[::-1]


def main() -> int:
    root = root_dir()
    source = os.path.join(root, "assets", "third_party", "ambientcg")
    out_dir = os.path.join(root, "assets", "generated", "textures")
    os.makedirs(out_dir, exist_ok=True)
    stack = []
    for _surface, material, gain in LAYERS:
        path = os.path.join(source, material, material + "_512_Color.jpg")
        if not os.path.isfile(path):
            print("Falta la fuente: " + path)
            return 1
        layer = load_layer(path)
        layer[:, :, :3] = np.clip(layer[:, :, :3] * gain, 0.0, 1.0)
        layer[:, :, 3] = 1.0
        stack.append(layer)
    column = np.concatenate(stack, axis=0)
    height = column.shape[0]
    # Cuantizar a 8 bits aquí hace el resultado independiente del redondeo del guardado.
    column = np.round(column * 255.0) / 255.0
    out = bpy.data.images.new("surfaces_albedo", LAYER_SIZE, height, alpha=False)
    out.colorspace_settings.name = "sRGB"
    out.pixels.foreach_set(column[::-1].reshape(-1))
    out.filepath_raw = os.path.join(out_dir, "surfaces_albedo.png")
    out.file_format = "PNG"
    scene = bpy.context.scene
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 90
    out.save()
    with open(os.path.join(out_dir, "surfaces.json"), "w", encoding="ascii", newline="\n") as handle:
        json.dump({"layer_size": LAYER_SIZE, "layers": [l[0] for l in LAYERS]}, handle, indent=1)
        handle.write("\n")
    print("surfaces: %d capas de %d px" % (len(LAYERS), LAYER_SIZE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
