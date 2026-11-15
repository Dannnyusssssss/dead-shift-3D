# Dead Shift 3D

Juego de supervivencia en primera persona para navegador, en PC y en celular. Un guardia nocturno queda atrapado en un centro comercial lleno de zombis y debe subir hasta la azotea para que lo rescaten.

**Edad orientativa: 16+.** Contiene violencia fuerte, sangre y terror. Es una orientación propia, no una clasificación oficial.

## Estado

En desarrollo. El juego completo se puede jugar de principio a fin con arte provisional (formas simples en gris):

- Un solo edificio de cuatro pisos (planta baja, Nivel 1, Nivel 2 y azotea) que se recorre sin pantallas de carga: atrio central abierto, escaleras mecánicas paradas, escalera de servicio con atajos que se abren desde un lado y tiendas con escaparate a ambos lados del pasillo.
- Pistola, escopeta escondida tras una reja con llave y armas cuerpo a cuerpo que se desgastan y se rompen; mochila con iconos, detalle de cada objeto y una pestaña con las combinaciones que se pueden hacer con lo que se lleva.
- Cuaderno del guardia con el objetivo actual, dónde buscar las piezas del teléfono y todas las combinaciones.
- Enemigos con comportamientos distintos: caminantes, oyentes que acuden al ruido, policías zombis con chaleco, acechadores que rodean al jugador y el jefe, El Técnico.
- Sigilo: agacharse, lanzar objetos con la trayectoria marcada para distraer, indicador de ruido y subtítulos con dirección (se puede jugar sin sonido).
- Infección por mordidas con cuenta atrás; vendas, antibióticos (suman tiempo a la cuenta) y Neutrax, con un panel que muestra qué hace cada cura. Curarse y combinar ocupan las manos: se puede mirar y caminar despacio, pero no atacar.
- Teléfono por piezas, plano con zonas probables, cámaras de seguridad y rescate en helicóptero; la llamada atrae oleadas a la azotea mientras se espera. Tres desenlaces: rescate, rescate perdido y muerte, con estadísticas y nota.
- Guardado automático en zonas seguras y al cambiar de piso, y «Continuar».
- Opciones de imagen, sonido, teclas reasignables, controles táctiles y accesibilidad (reducir movimiento, destellos y sangre; subtítulos).

Todavía no hay sonidos (los volúmenes ya se pueden ajustar) ni arte definitivo.

## Controles

| Acción | PC | Celular o tableta (en horizontal) |
|---|---|---|
| Moverse | W A S D | Palanca a la izquierda |
| Mirar | Ratón | Arrastrar en la mitad derecha |
| Atacar o disparar | Clic izquierdo | Botón «Atacar» |
| Apuntar | Clic derecho | Botón «Apuntar» |
| Recargar | R | Botón «Recargar» |
| Usar o recoger | E | Botón «Usar» |
| Lanzar un objeto (prepararlo y lanzarlo; clic derecho cancela) | G, y G o clic para lanzar | Botón «Lanzar» dos veces |
| Curarse (elige la cura que hace falta) | H | Botón «Curarse» |
| Mochila, combinar y teléfono | Tab o I | Botón «Mochila» |
| Cuaderno (objetivo y pistas) | N | En la mochila |
| Mapa (con el plano) | M | Botón «Mapa» |
| Cambiar de arma | Q o rueda del ratón, 1 a 3 | Botón «Arma» |
| Agacharse | Ctrl o C | Botón «Agachar» |
| Correr | Mayús | Empujar la palanca hasta el borde |
| Pausa, guardar y opciones | P o Esc | Botón «Pausa» |
| Mostrar rendimiento | F3 | Desde la pausa |

## Datos y privacidad

El juego no recolecta datos, no tiene cuentas, analítica ni publicidad, y no se conecta a ningún servidor. Solo guarda los ajustes, una partida y la mejor nota en el almacenamiento del navegador, en el propio dispositivo; el menú principal tiene «Borrar datos guardados». Detalle en [docs/PRIVACY-INVENTORY.md](docs/PRIVACY-INVENTORY.md).

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

# Lo anterior más el bot de recorrido (la partida completa con varias semillas, el jefe
# con y sin escopeta, el rescate perdido y la muerte), el export web, los pesos, la
# búsqueda de secretos y la prueba de humo en Chromium (directa, en iframe y táctil)
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
