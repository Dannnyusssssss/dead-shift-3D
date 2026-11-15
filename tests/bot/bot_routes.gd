class_name BotRoutes
extends RefCounted
## Rutas del bot de recorrido por el edificio continuo (posiciones del mundo, con la altura de
## cada piso): punto y si hay que usar lo que esté ahí.

## Ruta del escenario del jefe: entra al almacén y, vencido, abre la reja y sube a la azotea.
const BOSS: Array = [
	[Vector3(5.0, 10.0, 4.0), false],
	[Vector3(8.0, 10.0, 9.0), false],
	[Vector3(12.0, 10.0, 9.0), false],
	[Vector3(17.0, 10.0, 4.0), false],
	[Vector3(23.2, 10.0, -4.0), true],
	[Vector3(21.0, 15.0, -4.0), false],
]
## Ruta de la partida completa por el edificio (posiciones del mundo, con la altura del piso):
## punto y si hay que usar lo que esté ahí. Entre pisos camina por la navegación común, que
## sube por las escaleras mecánicas.
const FULL: Array = [
	# Planta baja: sala de seguridad (chaleco, munición, curas y plano).
	[Vector3(-30.0, 0.0, -4.0), true],
	[Vector3(-24.9, 0.0, -4.6), true],
	[Vector3(-30.6, 0.0, 0.4), true],
	[Vector3(-27.5, 0.0, 0.4), true],
	[Vector3(-21.0, 0.0, -2.0), false],
	# Ferretería.
	[Vector3(-18.0, 0.0, -4.0), false],
	[Vector3(-21.0, 0.0, -9.0), true],
	[Vector3(-13.6, 0.0, -15.0), true],
	[Vector3(-16.0, 0.0, -8.6), true],
	[Vector3(-18.0, 0.0, -4.0), false],
	# Deportes.
	[Vector3(-12.0, 0.0, 4.0), false],
	[Vector3(-15.0, 0.0, 10.5), true],
	[Vector3(-10.0, 0.0, 9.0), true],
	[Vector3(-7.2, 0.0, 15.0), true],
	[Vector3(-12.0, 0.0, 4.0), false],
	# Hogar.
	[Vector3(11.0, 0.0, -4.5), false],
	[Vector3(10.0, 0.0, -11.0), true],
	[Vector3(8.0, 0.0, -12.0), true],
	[Vector3(14.4, 0.0, -15.0), true],
	[Vector3(11.0, 0.0, -4.5), false],
	# Depósito.
	[Vector3(22.0, 0.0, 0.0), false],
	[Vector3(30.8, 0.0, -4.4), true],
	[Vector3(22.0, 0.0, 0.0), false],
	# Escalera mecánica al Nivel 1.
	[Vector3(7.0, 0.0, -0.9), false],
	[Vector3(20.0, 5.0, -0.9), false],
	# Nivel 1: electrónica (dos piezas del teléfono).
	[Vector3(8.0, 5.0, -4.5), false],
	[Vector3(8.0, 5.0, -9.0), true],
	[Vector3(11.8, 5.0, -15.0), true],
	[Vector3(3.6, 5.0, -15.2), true],
	[Vector3(8.0, 5.0, -4.5), false],
	# Ropa (llave del puesto de seguridad).
	[Vector3(-17.0, 5.0, -4.5), false],
	[Vector3(-11.1, 5.0, -15.2), true],
	[Vector3(-17.0, 5.0, -4.5), false],
	# Puesto de seguridad (reja con llave, escopeta).
	[Vector3(3.0, 5.0, 4.5), false],
	[Vector3(3.0, 5.0, 5.4), true],
	[Vector3(3.0, 5.0, 12.0), true],
	[Vector3(-0.4, 5.0, 15.2), true],
	[Vector3(6.4, 5.0, 15.2), true],
	[Vector3(0.5, 5.0, 10.0), true],
	[Vector3(3.0, 5.0, 4.5), false],
	# Farmacia.
	[Vector3(-18.0, 5.0, 4.5), false],
	[Vector3(-18.0, 5.0, 11.5), true],
	[Vector3(-22.4, 5.0, 15.2), true],
	[Vector3(-13.2, 5.0, 15.2), true],
	[Vector3(-18.0, 5.0, 4.5), false],
	# Escalera mecánica al Nivel 2.
	[Vector3(-8.8, 5.0, 0.9), false],
	[Vector3(-20.0, 10.0, 0.9), false],
	# Nivel 2: sala del personal (zona segura) y atajo abierto desde el pasillo.
	[Vector3(-22.0, 10.0, -2.0), false],
	[Vector3(-25.2, 10.0, -4.6), true],
	[Vector3(-30.4, 10.0, -4.6), true],
	[Vector3(-28.0, 10.0, -3.0), true],
	[Vector3(-22.0, 10.0, -2.0), false],
	[Vector3(-22.6, 10.0, 4.0), true],
	# Reparaciones (última pieza).
	[Vector3(6.0, 10.0, -4.5), false],
	[Vector3(6.0, 10.0, -9.0), true],
	[Vector3(9.8, 10.0, -15.0), true],
	[Vector3(6.0, 10.0, -4.5), false],
	# Mantenimiento.
	[Vector3(22.0, 10.0, 1.0), false],
	[Vector3(30.4, 10.0, 4.4), true],
	[Vector3(22.0, 10.0, 1.0), false],
	# Almacén del jefe, reja de la azotea y subida.
	[Vector3(5.0, 10.0, 4.0), false],
	[Vector3(8.0, 10.0, 9.0), false],
	[Vector3(12.0, 10.0, 9.0), false],
	[Vector3(17.0, 10.0, 4.0), false],
	[Vector3(23.2, 10.0, -4.0), true],
	[Vector3(21.0, 15.0, -4.0), false],
]
## En la azotea: ir al helipuerto y esperar.
const ROOFTOP: Array = [
	[Vector3(21.6, 15.0, 0.4), true],
	[Vector3(-25.6, 15.0, 13.4), true],
	[Vector3(-20.0, 15.0, 0.0), false],
]
