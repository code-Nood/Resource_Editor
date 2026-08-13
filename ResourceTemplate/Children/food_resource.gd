class_name FoodResource

extends InventoryResource

const DEFAULT_CATEGORY = GameEnums.InventoryCategory.FOOD
#饥饿值回复、理智值回复、最大新鲜度
@export var hunger_restore :int
@export var sanity_restore :int
@export var max_freshness :int
