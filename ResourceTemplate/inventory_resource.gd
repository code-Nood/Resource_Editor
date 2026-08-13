class_name InventoryResource

extends DataResource

#region exports
@export var name :String
@export var texture :Texture2D
@export var description :String
@export var price :int
@export var can_sell :bool
@export var stackable :bool
@export var usable :bool
@export var unique :bool
@export var type :GameEnums.InventoryType

#endregion



static func generate_id(category: int ,existing_ids: Array) -> int:
	var base = category * 1000 
	#分类基础值，如食物为1000系列
	var max_serial = 0
	
	#检查这个 ID 是否属于当前分类
	for id_value in existing_ids:
		if id_value / 1000 == category:
			var serial = id_value % 1000
			if serial > max_serial:
				max_serial = serial
	
	return base + max_serial + 1
