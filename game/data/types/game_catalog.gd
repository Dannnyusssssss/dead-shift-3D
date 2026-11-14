class_name GameCatalog
extends Resource
## Catálogo único de datos del juego: todos los objetos, recetas y enemigos se registran aquí.

@export var items: Array[ItemData] = []
@export var recipes: Array[RecipeData] = []
@export var enemies: Array[EnemyData] = []


## Registro de objetos por identificador para la lógica.
func item_catalog() -> ItemCatalog:
	return ItemCatalog.new(items)


func find_enemy(enemy_id: String) -> EnemyData:
	for enemy: EnemyData in enemies:
		if enemy.id == enemy_id:
			return enemy
	return null
