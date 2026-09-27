extends GridContainer

class_name GridEditor

## 网格列数（默认 6x6）
@export var columns_count: int = 6
## 网格行数
@export var rows_count: int = 6

## 预加载格子场景
const PANEL_SCENE := preload("res://EditorUI/GridInventoryEditor/Children/editor_panel.tscn")

## 已选中格子的列表，按“点亮顺序”排列；[0] 即坐标系原点
var _selection: Array[EditorPanel] = []


func _ready() -> void:
	columns = columns_count
	_build_grid()


## 按 rows x columns 动态生成格子，并赋网格坐标
func _build_grid() -> void:
	# 清掉可能已有的子节点
	for c in get_children():
		c.queue_free()

	for row in rows_count:
		for col in columns_count:
			var panel: EditorPanel = PANEL_SCENE.instantiate()
			panel.set_grid_coord(Vector2i(col, row))
			add_child(panel)
			panel.pressed_panel.connect(_on_panel_pressed)


## 某个格子被点亮
func _on_panel_pressed(panel: EditorPanel) -> void:
	# 第一个被点亮的格子 = 坐标系原点
	var is_first := _selection.is_empty()
	panel.select_as(is_first)
	_selection.append(panel)
	_refresh_all_labels()


## 原点格子（可能尚未选择，返回 null）
func get_origin() -> EditorPanel:
	return _selection[0] if not _selection.is_empty() else null


## 刷新所有格子的相对坐标显示
func _refresh_all_labels() -> void:
	var origin := get_origin()
	var origin_coord := origin.grid_coord if origin != null else Vector2i.ZERO
	for panel in _panels():
		panel.refresh_label(origin_coord)


## 清空所有选择（顶部“清空选择”按钮调用）
func clear_all() -> void:
	_selection.clear()
	for panel in _panels():
		panel.deselect()


## 按“原点绝对坐标 + 相对偏移”回填一套选择（用于打开资源时还原已存形状）。
## origin_abs：起始格在网格中的绝对坐标；offsets：除起始格外的相对偏移数组。
func apply_shape(origin_abs: Vector2i, offsets: Array) -> void:
	clear_all()

	# 起始格优先：它必须成为原点（第一个被点亮）
	var origin_panel := _panel_at(origin_abs)
	if origin_panel == null:
		# 起始格越界，无法还原，保持空选择
		return
	origin_panel.select_as(true)
	_selection.append(origin_panel)

	# 其余格按相对偏移点亮（越界跳过，不参与选择记录）
	for off in offsets:
		var panel := _panel_at(origin_abs + off)
		if panel == null or panel.is_selected:
			continue
		panel.select_as(false)
		_selection.append(panel)

	_refresh_all_labels()


## 按绝对坐标取对应的 EditorPanel（越界返回 null）
func _panel_at(coord: Vector2i) -> EditorPanel:
	for panel in _panels():
		if panel.grid_coord == coord:
			return panel
	return null


## 导出为 shape_offsets：以原点为 (0,0)，去掉原点那格，返回其余格的相对坐标
func get_shape_offsets() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin := get_origin()
	if origin == null:
		return result
	var origin_coord := origin.grid_coord
	for panel in _selection:
		var rel := panel.grid_coord - origin_coord
		if rel == Vector2i.ZERO:
			continue  # 剔除原点（起始格）
		result.append(rel)
	return result


## 已占格数（含原点）
func get_used_cell_count() -> int:
	return _selection.size()


## 遍历所有 EditorPanel 子节点
func _panels() -> Array[EditorPanel]:
	var arr: Array[EditorPanel] = []
	for c in get_children():
		if c is EditorPanel:
			arr.append(c)
	return arr
