extends GutTest
## Las herramientas de desarrollo son opcionales: sin la carpeta (como en el repositorio y en la
## versión publicada) la partida no crea nada y no falla.


func test_missing_dev_tools_create_nothing() -> void:
	assert_null(Game.dev_tools_from("res://dev/no_existe.gd"))


func test_dev_tools_are_excluded_from_the_export() -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_string_contains(presets, "dev/*", "el export web deja fuera la carpeta de desarrollo")
