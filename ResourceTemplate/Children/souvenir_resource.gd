class_name SouvenirResource

extends InventoryResource

const DEFAULT_CATEGORY = GameEnums.InventoryCategory.SOUVENIR

# ============================================================
# == 网格背包系统专用字段（供将来形状编辑器使用）
# ============================================================
# 设计约定见学习清单：
#   - 起始格恒定为相对坐标 (0,0)，作为旋转轴心 / 锚点。
#   - shape_offsets 只存"除起始格外"的剩余格相对坐标（不存起始格）。
#   - 旋转一律用 rotated_offsets() 公式现场计算，不硬编码 4 份坐标。

## 包围盒尺寸（宽×高）。注意：不等于实际占格数，仅用于碰撞扫描范围。
@export var size: Vector2i = Vector2i.ONE

## 基准方向（0°）下，除起始格之外的相对坐标数组。
## 例：5 格直角 L 形（起始格取直角拐点）→ [(0,1),(0,2),(1,2)]
@export var shape_offsets: Array[Vector2i] = []

## 物品静止摆放是否支持旋转（某些对称物品旋转无意义，可关掉）。
@export var is_rotatable: bool = true

## 展示大图（区别于 DataResource.icon 缩略图）。
@export var full_texture: Texture2D

## 贴图渲染时对准的格子锚点（=旋转轴心，默认起始格 (0,0)）。
@export var visual_anchor: Vector2i = Vector2i.ZERO

## 单个格子（单元格）在 UI 上的像素尺寸；0 表示用全局约定（GlobalConstants.CELL_SIZE）。
@export var cell_size: Vector2i = Vector2i.ZERO

## 堆叠上限（>1 表示可堆叠，单片占格的物品通常为 1）。
@export var stack_limit: int = 1

## 自动整理（best-fit）时的摆放优先级，值越大越先被摆放（大件/碎片大的优先）。
@export var sort_priority: int = 0

# ============================================================
# == 旋转枚举与派生方法
# ============================================================
enum Rot { DEG_0, DEG_90, DEG_180, DEG_270 }

## 派生：实际占用格子数（= 起始格 1 + shape_offsets 长度）。只读，勿存为独立字段。
func get_used_cell_count() -> int:
	return shape_offsets.size() + 1

## 返回某个旋转角度下，"除起始格外"所有格子的相对坐标（绕起始格 (0,0) 旋转）。
func rotated_offsets(rot: Rot) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for off in shape_offsets:
		match rot:
			Rot.DEG_90:
				result.append(Vector2i(-off.y, off.x))   # 顺时针 90°
			Rot.DEG_180:
				result.append(Vector2i(-off.x, -off.y))  # 180°
			Rot.DEG_270:
				result.append(Vector2i(off.y, -off.x))   # 顺时针 270°
			_:
				result.append(off)
	return result
