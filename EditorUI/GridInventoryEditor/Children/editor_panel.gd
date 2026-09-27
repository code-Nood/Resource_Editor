extends Panel

class_name EditorPanel

## 本格子在网格中的绝对坐标（由 GridEditor 赋值，左上为 (0,0)，y 向下递增）
var grid_coord: Vector2i = Vector2i.ZERO

## 是否已被选中（一旦选中不可自行取消，只能由 GridEditor 统一清空）
var is_selected: bool = false

## 是否为坐标系原点（= 第一个被选中的格子）
var is_origin: bool = false

## 点击本格子时发出的信号（由 GridEditor 接收）
signal pressed_panel(panel: EditorPanel)

@export var color_rect:ColorRect
@export var coordinate_label:Label
@export var button:Button


func _ready() -> void:
	# 初始：未选中 -> 灰色、隐藏坐标
	_apply_visual()
	if button != null and not button.pressed.is_connected(_on_pressed):
		button.pressed.connect(_on_pressed)


## GridEditor 用来指定本格子的网格坐标
func set_grid_coord(coord: Vector2i) -> void:
	grid_coord = coord


## 选中本格子（origin=true 表示它同时成为坐标系原点）
func select_as(is_origin_panel: bool) -> void:
	is_selected = true
	is_origin = is_origin_panel
	_apply_visual()


## 取消选中（仅由 GridEditor 清空时调用）
func deselect() -> void:
	is_selected = false
	is_origin = false
	# 一并清空显示的相对坐标，避免清空后 label 残留
	if coordinate_label != null:
		coordinate_label.text = ""
	_apply_visual()


## 根据当前“原点坐标”刷新本格显示的相对坐标
func refresh_label(origin_coord: Vector2i) -> void:
	if coordinate_label == null:
		return
	if not is_selected:
		coordinate_label.text = ""
		return
	var rel := grid_coord - origin_coord
	coordinate_label.text = "(%d,%d)" % [rel.x, rel.y]


## 应用选中状态对应的视觉（颜色）
func _apply_visual() -> void:
	if color_rect == null:
		return
	if not is_selected:
		# 未选中：灰色
		color_rect.color = Color(0.5, 0.5, 0.5, 0.3)
	elif is_origin:
		# 原点：更亮/高饱和的绿色，便于区分
		color_rect.color = Color(0.0, 1.0, 0.3, 0.5)
	else:
		# 普通选中：绿色
		color_rect.color = Color(0.0, 0.87, 0.45, 0.286)


func _on_pressed() -> void:
	# 已选中则不再响应（只能由顶部“清空选择”统一取消）
	if is_selected:
		return
	pressed_panel.emit(self)
