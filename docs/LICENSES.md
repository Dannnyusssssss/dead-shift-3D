# Licencias de terceros

Dead Shift 3D: todos los derechos reservados. Los componentes y recursos de terceros conservan su propia licencia, indicada aquí.

## Se distribuyen con el juego

| Componente | Versión | Licencia | Origen | Notas |
|---|---|---|---|---|
| Godot Engine (motor y plantillas de exportación web) | 4.7.2-stable | MIT | https://godotengine.org · https://github.com/godotengine/godot | El motor incluye componentes de terceros con sus propias licencias (lista en `COPYRIGHT.txt` del repositorio de Godot). Su aviso de licencia se mostrará en los créditos del juego. Plantillas comprobadas con el archivo oficial `SHA512-SUMS.txt` de la versión. |

## Solo desarrollo (no se incluyen en el export)

| Componente | Versión | Licencia | Origen | Notas |
|---|---|---|---|---|
| gut (Godot Unit Test, carpeta `addons/gut/`) | 9.7.1 | MIT | https://github.com/bitwes/Gut | Pruebas automáticas. Incluye las fuentes Anonymous Pro, Courier Prime y Lobster Two bajo SIL Open Font License 1.1 (`addons/gut/fonts/OFL.txt`). Excluido del export web. |
| gdtoolkit (`gdlint`, `gdformat`) | 4.5.0 | MIT | https://github.com/Scony/godot-gdscript-toolkit | Lint y formato de GDScript. |
| pip-audit | 2.10.1 | Apache-2.0 | https://github.com/pypa/pip-audit | Auditoría de las herramientas de Python. |
| Playwright para Python | 1.65.2 | Apache-2.0 | https://github.com/microsoft/playwright-python | Prueba de humo del export web en Chromium. El navegador que descarga se instala fuera del repositorio. |

Las dependencias transitivas de las herramientas de Python están fijadas con versión exacta en `tools/requirements.txt`; solo se usan en desarrollo y no se distribuyen.

## Recursos gráficos y de sonido

Cada pack vive en `assets/third_party/<pack>/` con su archivo de licencia, una tabla de origen (`SOURCES.md`) y la huella SHA-256 de cada archivo (`MANIFEST.sha256`). Solo se guardan formatos que no ejecutan código al cargarse (imágenes, audio, modelos glTF y texto).

| Pack (carpeta) | Licencia | Origen | Contenido y cambios |
|---|---|---|---|
| ambientCG (`ambientcg`) | CC0 1.0 Universal | https://ambientcg.com · licencia en https://docs.ambientcg.com/license/ | 11 materiales: Tiles078, Tiles074, WoodFloor051, Concrete031, Concrete034, PaintedPlaster017, OfficeCeiling001, CorrugatedSteel005, DiamondPlate008A, Metal064 y Asphalt031. Mapas de color, normales y rugosidad reducidos de 1024 a 512 px; página y huella del archivo original de cada uno en `SOURCES.md`. |
| Quaternius: Universal Animation Library (`quaternius-ual1`) | CC0 1.0 Universal | https://quaternius.com/packs/universalanimationlibrary.html | Biblioteca de animaciones humanoides (GLB, sin root motion) y maniquí. |
| Quaternius: Universal Animation Library 2 (`quaternius-ual2`) | CC0 1.0 Universal | https://quaternius.com/packs/universalanimationlibrary2.html | Segunda biblioteca de animaciones (GLB) y maniquí femenino. |
| Quaternius: Universal Base Characters, versión gratuita (`quaternius-ubc`) | CC0 1.0 Universal | https://quaternius.com/packs/universalbasecharacters.html | Dos cuerpos con esqueleto humanoide (glTF), peinados y cejas; texturas reducidas a 1024 px. |
| Kenney: Impact Sounds 1.0 (`kenney-impact-sounds`) | CC0 1.0 Universal | https://kenney.nl/assets/impact-sounds | Pasos por superficie y golpes (OGG). |
| Kenney: Interface Sounds 1.0 (`kenney-interface-sounds`) | CC0 1.0 Universal | https://kenney.nl/assets/interface-sounds | Sonidos de interfaz (OGG). |
| Kenney: RPG Audio (`kenney-rpg-audio`) | CC0 1.0 Universal | https://kenney.nl/assets/rpg-audio | Pasos, objetos y armas (OGG). |
| Kenney: Sci-Fi Sounds 1.0 (`kenney-sci-fi-sounds`) | CC0 1.0 Universal | https://kenney.nl/assets/sci-fi-sounds | Ruidos eléctricos y de máquinas (OGG). |

Los packs se guardan como fuente: el juego solo incluye lo que se usa, ya procesado (atlas de texturas, modelos y sonidos elegidos).

El resto del arte (escenario, mobiliario, rótulos con marcas inventadas y armas) se genera con scripts propios de Blender y forma parte del juego. La portada (`docs/cover.png`) es una captura del propio juego.
