extends GutTest
## Línea de infección del HUD: sin golpes no se ve; con exposición, barra de texto y porcentaje
## (no depende del color); con infección, la cuenta atrás.


func test_infection_line_shows_exposure_then_countdown() -> void:
	var state := PlayerState.new(GameState.items)
	assert_eq(Hud.infection_text(state), "", "sin golpes no se ve")
	state.infection.add_exposure(0.25)
	var text := Hud.infection_text(state)
	assert_string_contains(text, tr("hud_exposure"))
	assert_string_contains(text, "[##---]")
	assert_string_contains(text, "25 %")
	state.infection.add_exposure(0.5)
	assert_string_contains(Hud.infection_text(state), "[####-]")
	state.infection.add_exposure(0.25)
	var infected := Hud.infection_text(state)
	assert_string_contains(infected, tr("hud_infected"))
	assert_string_contains(infected, "4:00")
	assert_false(infected.contains(tr("hud_exposure")))
