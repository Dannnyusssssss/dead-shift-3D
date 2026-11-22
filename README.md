# Dead Shift 3D

Juego de supervivencia en primera persona para navegador, en PC y en celular. Un guardia nocturno queda atrapado en un centro comercial lleno de zombis y debe subir hasta la azotea para que lo rescaten.

**Edad orientativa: 16+.** Contiene violencia fuerte, sangre y terror. Es una orientación propia, no una clasificación oficial.

## Estado

En desarrollo. El juego completo se puede jugar de principio a fin, con su arte, sonido, intro y final:

- Un solo edificio de cuatro pisos (planta baja, Nivel 1, Nivel 2 y azotea) que se recorre sin pantallas de carga: atrio central abierto, escaleras mecánicas paradas, escalera de servicio con atajos que se abren desde un lado y tiendas con escaparate a ambos lados del pasillo.
- Tres dificultades (Fácil, Medio y Difícil) que se eligen al empezar, se guardan con la partida y tienen su propia mejor nota.
- Pistola, escopeta escondida tras una reja con llave (sin munición golpea con la culata), la porra del guardia (débil, pero nunca se rompe ni se pierde) y armas cuerpo a cuerpo que se desgastan y se rompen; mochila con iconos, detalle de cada objeto, una bolsa de materiales que no ocupa casillas (con tope por material) y una pestaña con las combinaciones que se pueden hacer con lo que se lleva.
- Cuaderno del guardia con el objetivo actual y solo lo que ya se descubrió: el teléfono, dónde buscar sus piezas y las combinaciones.
- Decoración por tipo de tienda, ascensor averiado y escaparates que se rompen con un disparo, un golpe o un objeto lanzado: hacen ruido y se quedan rotos.
- Linterna en el hombro, con pilas, que se usa a la vez que se dispara o se golpea y avisa con texto (y un haz que baja suave) cuando se agota; al empezar la pelea, El Técnico deja su piso a oscuras.
- Enemigos con comportamientos distintos: caminantes, oyentes que acuden al ruido, policías zombis con chaleco, acechadores que rodean al jugador y el jefe, El Técnico.
- Sigilo: agacharse, lanzar objetos con la trayectoria marcada para distraer (la botella ruidosa atrae a todos los enemigos cercanos), una tecla para elegir qué se lanza, indicador de ruido y subtítulos con dirección (se puede jugar sin sonido).
- Infección por mordidas sin azar: cada golpe llena una barra de exposición visible y, al llenarse, empieza la infección, con cuenta atrás y aviso en pantalla en los últimos 30 segundos; vendas, antibióticos (suman tiempo a la cuenta) y Neutrax (una dosis en la farmacia y otra que se prepara con un vial y una jeringa), con un panel que muestra qué hace cada cura. Curarse y combinar ocupan las manos: se puede mirar y caminar despacio, pero no atacar.
- Teléfono por piezas con una nota del técnico que dice qué hace falta, plano que marca lo que falta con una lista escrita (también se abre tocándolo en la mochila), cámaras de seguridad con imagen real y rescate en helicóptero; la llamada atrae oleadas a la azotea mientras se espera. Desenlaces: rescate, caída del helicóptero si se sube infectado, rescate perdido y muerte, con estadísticas y nota.
- Intro que cuenta el accidente de la central y el viaje de la nube hasta el centro comercial, escenas finales (el helicóptero aterriza, el guardia sube y se va, o cae) y créditos con las licencias. Todas se pueden saltar.
- Centro comercial con texturas, mobiliario por tipo de tienda, tiendas cerradas con persiana y escaparate, baños, cafetería, desorden del ataque por el suelo, rótulos con marcas inventadas, luces rotas que dejan zonas oscuras y carteles de emergencia.
- Objetos que se reconocen: cada uno con su modelo y su nombre de cerca; los contenedores se abren y enseñan lo que tenían, y un aviso con icono y nombre confirma lo que se recoge.
- Enemigos con modelo y animaciones propias de cada tipo, brazos del guardia animados por arma y armas cuyo desgaste se ve (rayas, grietas, cinta).
- Sangre, polvo y chispas en los impactos, con tope por calidad; «Reducir sangre» la cambia por polvo.
- Sonido: pasos según el suelo, armas, voces de cada enemigo, crepitar del jefe, ambiente de cada piso y música mínima.
- Reparto del botín distinto en cada partida (la semilla se puede fijar con `?seed=` en la dirección), siempre completable.
- Guardado automático en zonas seguras y al cambiar de piso, y «Continuar».
- Resumen de la partida en la pausa y al terminar.
- Opciones de imagen, sonido, teclas reasignables, controles táctiles y accesibilidad (reducir movimiento, destellos y sangre; tamaño de la interfaz; subtítulos; consejos de primera vez).

## Controles

| Acción | PC | Celular o tableta (en horizontal) |
|---|---|---|
| Moverse | W A S D | Palanca a la izquierda |
| Mirar | Ratón | Arrastrar en la mitad derecha |
| Atacar o disparar | Clic izquierdo | Botón «Atacar» |
| Apuntar | Clic derecho | Botón «Apuntar» |
| Recargar | R | Botón «Recargar» |
| Usar o recoger (E también cierra la nota y las cámaras) | E | Botón «Usar» |
| Lanzar un objeto (prepararlo y lanzarlo; clic derecho cancela) | G, y G o clic para lanzar | Botón «Lanzar» dos veces |
| Cambiar lo que se lanza con la tecla rápida | V | Botón «Otro» |
| Curarse (elige la cura que hace falta) | H | Botón «Curarse» |
| Mochila, combinar y teléfono | Tab o I | Botón «Mochila» |
| Cuaderno (objetivo y pistas) | N | En la mochila |
| Mapa (con el plano; también tocándolo en la mochila) | M | Botón «Mapa» |
| Linterna | F | Botón «Linterna» |
| Cambiar de cámara (en los monitores de seguridad) | Flechas izquierda y derecha | Botones «Anterior» y «Siguiente» |
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

### Regenerar el arte y el sonido

El arte y el sonido de `assets/generated/` y `assets/audio/` salen de los scripts de `tools/blender/` (con [Blender](https://www.blender.org/) 5.2) a partir de los recursos de `assets/third_party/`. Cada script da siempre el mismo resultado:

```powershell
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
foreach ($script in "surfaces", "props", "items", "arms", "vehicles", "enemies", "audio") {
    & $blender --background --factory-startup --python "tools/blender/$script.py"
}
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
