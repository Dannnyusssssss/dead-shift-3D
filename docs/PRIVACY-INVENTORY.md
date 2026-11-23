# Inventario de datos

## Qué se recolecta
Nada. El juego no tiene cuentas, formularios, analítica, publicidad, cookies ni contenido embebido de terceros, y no envía datos a ningún servidor.

## Qué se guarda en el dispositivo
Solo en el almacenamiento del navegador (IndexedDB, en una carpeta propia del juego), para el sitio del juego, y nunca sale del dispositivo. No se usan cookies ni `localStorage`:

| Dato | Para qué | Cuándo se borra |
|---|---|---|
| Ajustes (calidad gráfica, sensibilidad, campo de visión, volúmenes, teclas reasignadas, opciones de accesibilidad y de controles táctiles) | Recordar las preferencias del jugador | Con «Borrar datos guardados» en el menú principal o al borrar los datos del sitio en el navegador |
| Partida guardada (una sola ranura: dificultad, piso y punto de reaparición, salud, exposición e infección, inventario y bolsa de materiales, carga de la linterna, objetos importantes, estado del teléfono y del helicóptero, qué se ha abierto, roto o derrotado en cada piso, lo descubierto y los consejos ya vistos, semilla y estadísticas de la partida) | Continuar la partida después | Al terminar la historia (rescate o rescate perdido), con «Borrar datos guardados» o al borrar los datos del sitio |
| Mejor nota (una letra por dificultad) | Mostrar el récord en este dispositivo | Con «Borrar datos guardados» o al borrar los datos del sitio |

Si el navegador no permite guardar (por ejemplo, en una ventana privada), el juego lo avisa una vez y se puede seguir jugando sin guardar.

## Terceros
- **Hosting de archivos estáticos:** al descargar el juego, el servidor puede registrar la dirección IP y datos técnicos de la petición, como cualquier sitio web. El juego no recibe ni usa esos datos.

## Datos que lee de la página
- **Zona segura de la pantalla:** la página del juego mide los márgenes de la muesca del celular y el juego los lee (cuatro números validados) para no tapar la interfaz. No se guarda ni sale del dispositivo.

## Parámetros de la dirección
- `seed`: número entero opcional que fija el azar de la partida (por ejemplo, el reparto del botín). No identifica a nadie.
