extends GutTest
## Privacidad y Términos: todos los párrafos existen en los textos, llevan el contacto del
## responsable y la fecha, y la privacidad dice lo que el juego hace (guardado local, sin envío).


func _check_keys(keys: Array[String]) -> void:
	for key: String in keys:
		assert_ne(TranslationServer.translate(key), key, "falta el texto " + key)


func test_every_paragraph_has_text() -> void:
	_check_keys(TextPageView.PRIVACY_KEYS)
	_check_keys(TextPageView.TERMS_KEYS)
	_check_keys(["privacy_title", "terms_title", "legal_updated", "legal_back"] as Array[String])


func test_pages_name_the_contact_and_the_date() -> void:
	for keys: Array[String] in [TextPageView.PRIVACY_KEYS, TextPageView.TERMS_KEYS]:
		var text := TextPageView.page_text(keys)
		assert_string_contains(text, "cuartojuegos.contacto@gmail.com")
		assert_string_contains(text, "2026")
		assert_false(text.contains("COMPLETAR"), "sin huecos sin rellenar")


func test_privacy_matches_what_the_game_stores() -> void:
	var text := TextPageView.page_text(TextPageView.PRIVACY_KEYS)
	assert_string_contains(text, "IndexedDB")
	assert_string_contains(text, "Borrar datos guardados")
	assert_string_contains(text, "GitHub Pages")
