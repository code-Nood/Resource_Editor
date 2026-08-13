class_name SeedResource

extends InventoryResource

const DEFAULT_CATEGORY = GameEnums.InventoryCategory.SEED
#从上往下分别是：作物数量、最大储水量、种子额外掉落率、成长四个阶段进行下去所需的时间、具体作物
@export var crop_count :int
@export var max_water :int
@export var seed_drop_bonus :float
@export var seed_stage :int
@export var sprout_stage :int
@export var growinng_stage :int
@export var mature_stage :int
@export var crop :InventoryResource
