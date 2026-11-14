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

Ninguno por ahora: el arte del juego es provisional y se genera con primitivas del motor.
