class_name GameEnums

extends RefCounted
#物品类型枚举:纪念品、奢侈品、原料、食物、种子、工具、药品、家具
enum InventoryType {
	SOUVENIR,
	LUXURY,
	MATERIAL,
	FOOD,
	SEED,
	TOOL,
	MADICINE,
	FURNITURE,
}
#抽象类型枚举：任务、记忆、
enum AbstractType {
	QUEST,
	MEMORY,
}

#物品类型对应序号枚举
enum InventoryCategory {
	SOUVENIR = 1,
	LUXURY = 2,
	MATERIAL = 3,
	FOOD = 4,
	SEED = 5,
	TOOL = 6,
	MADICINE = 7,
	FURNITURE = 8,
}
