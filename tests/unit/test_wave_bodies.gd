extends GutTest
## Cuerpos de las oleadas: nunca quedan más que el tope en el suelo; se quitan los más antiguos
## (una espera larga en la azotea no llena la memoria).


func test_oldest_wave_bodies_are_removed_past_the_cap() -> void:
	# Primero se vacía lo que hubiera de otras pruebas (la lista es compartida).
	var flush: Array[Enemy] = []
	for index: int in WaveSpawner.MAX_BODIES:
		flush.append(Enemy.new())
		WaveSpawner.keep_body(flush[-1])
	for body: Enemy in flush:
		body.free()
	var bodies: Array[Enemy] = []
	for index: int in WaveSpawner.MAX_BODIES + 5:
		var body := Enemy.new()
		bodies.append(body)
		WaveSpawner.keep_body(body)
	for index: int in 5:
		assert_true(bodies[index].is_queued_for_deletion(), "el cuerpo %d se quita" % index)
	for index: int in range(5, bodies.size()):
		assert_false(bodies[index].is_queued_for_deletion(), "el cuerpo %d sigue" % index)
	assert_eq(WaveSpawner.body_count(), WaveSpawner.MAX_BODIES)
	for body: Enemy in bodies:
		if not body.is_queued_for_deletion():
			body.free()
	await wait_frames(2)
	assert_eq(WaveSpawner.body_count(), 0, "los cuerpos liberados no cuentan")
