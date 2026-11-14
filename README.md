# Dead Shift 3D

Juego de supervivencia en primera persona para navegador, en PC y en celular. Un guardia nocturno queda atrapado en un centro comercial lleno de zombis y debe subir hasta la azotea para que lo rescaten.

**Edad orientativa: 16+.** Contiene violencia fuerte, sangre y terror. Es una orientación propia, no una clasificación oficial.

## Estado

En desarrollo. Hoy existe un corte jugable de la **planta baja** con arte provisional (formas simples en gris):

- Movimiento, mirada e interacción en primera persona, con teclado y ratón o con controles táctiles.
- Pistola con munición limitada y armas cuerpo a cuerpo que se desgastan y se rompen.
- Caminantes y un policía zombi que suelta balas y su chaleco.
- Objetos para recoger, cajones y casilleros con munición escondida, mochila limitada y combinación de objetos (por ejemplo, bate y clavos).
- Calidad gráfica Baja, Media y Alta.

Todavía no hay sonido, guardado de partida ni los pisos superiores.

## Controles

| Acción | PC | Celular o tableta (en horizontal) |
|---|---|---|
| Moverse | W A S D | Palanca a la izquierda |
| Mirar | Ratón | Arrastrar en la mitad derecha |
| Atacar o disparar | Clic izquierdo | Botón «Atacar» |
| Apuntar | Clic derecho | Botón «Apuntar» |
| Recargar | R | Botón «Recargar» |
| Usar o recoger | E | Botón «Usar» |
| Mochila y combinar | Tab o I | Botón «Mochila» |
| Cambiar de arma | Q o rueda del ratón, 1 a 3 | Botón «Arma» |
| Agacharse | Ctrl o C | Botón «Agachar» |
| Correr | Mayús | Empujar la palanca hasta el borde |
| Pausa y opciones | P o Esc | Botón «Pausa» |
| Mostrar rendimiento | F3 | Desde la pausa |

## Datos y privacidad

El juego no recolecta datos, no tiene cuentas, analítica ni publicidad, y no se conecta a ningún servidor. Solo guarda los ajustes en el almacenamiento del navegador, en el propio dispositivo. Detalle en [docs/PRIVACY-INVENTORY.md](docs/PRIVACY-INVENTORY.md).

## Desarrollo

### Requisitos

- Windows con Windows PowerShell 5.1.
- [Godot 4.7.2](https://godotengine.org/), edición estándar (no .NET), con sus plantillas de exportación 4.7.2.
- Variable de entorno `GODOT_BIN` con la ruta del ejecutable de consola de Godot (ver `.env.example`).
- Python 3.12 para las herramientas de verificación:

```powershell
py -3.12 -m venv tools/.venv
tools/.venv/Scripts/python -m pip install -r tools/requirements.txt
tools/.venv/Scripts/python -m playwright install chromium
```

### Verificación

```powershell
# Lint, formato, importación limpia y tests
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verify.ps1 quick

# Lo anterior más el bot de recorrido, el export web, los pesos, la búsqueda de
# secretos y la prueba de humo en Chromium (directa, en iframe y táctil)
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verify.ps1 full

# Licencias de terceros y auditoría de las herramientas de Python
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verify.ps1 deps
```

### Probar el export web

`verify.ps1 full` genera el juego en `build/web/`. Para abrirlo en el navegador:

```powershell
python -m http.server 8060 --bind 127.0.0.1 --directory build/web
```

y entrar a http://127.0.0.1:8060.

### Editor

```powershell
& $env:GODOT_BIN --path . --editor
```

La organización del código y cómo extenderlo están en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Licencia

Todos los derechos reservados. Ver [LICENSE](LICENSE). Los componentes de terceros conservan su propia licencia: [docs/LICENSES.md](docs/LICENSES.md).

Responsable: Danny Sivinta, Quito, Ecuador. Contacto: cuartojuegos.contacto@gmail.com
