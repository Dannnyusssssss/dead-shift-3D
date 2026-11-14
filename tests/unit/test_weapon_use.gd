extends GutTest
@warning_ignore_start("unsafe_call_argument")
## Armas: munición, recarga y desgaste por golpe con rotura en pleno golpe.

const Fixtures = preload("res://tests/helpers/fixtures.gd")


func test_fire_spends_ammo_until_empty() -> void:
	var gun := ItemStack.new(Fixtures.pistol())
	gun.ammo_loaded = 2
	assert_true(WeaponUse.fire(gun))
	assert_true(WeaponUse.fire(gun))
	assert_false(WeaponUse.fire(gun), "sin balas no dispara")
	assert_eq(gun.ammo_loaded, 0)


func test_reload_takes_only_what_fits() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(Fixtures.material("ammo", 60), 20)
	var gun := ItemStack.new(Fixtures.pistol(8))
	gun.ammo_loaded = 3
	assert_eq(WeaponUse.reload_from(gun, inventory), 5)
	assert_eq(gun.ammo_loaded, 8)
	assert_eq(inventory.count_of("ammo"), 15)
	assert_false(WeaponUse.can_reload(gun, inventory), "cargador lleno")


func test_reload_with_little_ammo() -> void:
	var inventory := Inventory.new(4)
	inventory.add_item(Fixtures.material("ammo", 60), 2)
	var gun := ItemStack.new(Fixtures.pistol(8))
	assert_eq(WeaponUse.reload_from(gun, inventory), 2)
	assert_false(WeaponUse.can_reload(gun, inventory), "sin munición")


func test_pistol_never_wears() -> void:
	var gun := ItemStack.new(Fixtures.pistol())
	assert_true(gun.durability.is_unbreakable())


func test_melee_hit_wears_and_breaks_mid_swing() -> void:
	var pipe := ItemStack.new(Fixtures.melee("pipe", 3.0, 1.0))
	assert_eq(WeaponUse.melee_hit(pipe), WeaponUse.HIT_OK)
	assert_eq(WeaponUse.melee_hit(pipe), WeaponUse.HIT_OK)
	assert_eq(WeaponUse.melee_hit(pipe), WeaponUse.HIT_BROKE, "el golpe que la rompe cuenta")
	assert_eq(WeaponUse.melee_hit(pipe), WeaponUse.HIT_NONE, "rota ya no golpea")


func test_melee_cannot_fire() -> void:
	assert_false(WeaponUse.can_fire(ItemStack.new(Fixtures.melee("bat"))))
