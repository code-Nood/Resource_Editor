extends GridContainer

class_name GridEditor

## 网格列数（默认 6x6）
@export var columns_count: int = 6
## 网格行数
@export var rows_count: int = 6

## 预加载格子场景
const PANEL_SCENE := preload("res://EditorUI/GridInventoryEditor/Children/editor_panel.tscn")

## 选择发生变化（点亮 / 清空 / 回填）时发出，供外部刷新旋转预览
signal selection_changed

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
	selection_changed.emit()


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
	selection_changed.emit()


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
	selection_changed.emit()


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


#region 网格几何（供 Reference 拖动吸附用）
## 单格像素尺寸：从真实格子读取，避免任何地方硬编码 32
func cell_px() -> int:
	for p in _panels():
		var m := (p as Control).custom_minimum_size
		if m.x > 0.0:
			return int(m.x)
	# 尚无格子时退回 0（调用方需先确保网格已构建）
	return 0


## 真实格 (0,0) 的全局原点位置（不是 GridContainer 容器位置——
## 容器位置会被 separation 等影响，只有格子自身的 global_position 才是格线基准）
func cell_origin() -> Vector2:
	var p := _panel_at(Vector2i.ZERO)
	if p != null:
		return (p as Control).global_position
	# 网格未建好时退回容器自身位置
	return global_position


## 格坐标 c 对应的全局矩形（左上角 + 单格边长）。
## 供预览层等外部消费者做"格坐标 -> 全局位置"换算，避免各处重复自算导致漂移。
func cell_rect_global(c: Vector2i) -> Rect2:
	var px := cell_px()
	return Rect2(cell_origin() + Vector2(c) * float(px), Vector2(px, px))


## 把矩形吸附到最近格位，并把左上角夹进合法范围 [0, cols-w] × [0, rows-h]。
## rect：目标的全局矩形（左上角为期望位置，size 为参考图尺寸）。
## 返回吸附 + clamp 后的全局矩形。
func snap_rect_to_cell(rect: Rect2) -> Rect2:
	var px := cell_px()
	if px <= 0:
		return rect
	var origin := cell_origin()
	# 尺寸换算成占用格数（向上取整，保证不溢出）
	var w := ceili(rect.size.x / float(px))
	var h := ceili(rect.size.y / float(px))
	# 最近格位（先转 float 再 round，避免整数除法向零截断的偏差）
	var c := Vector2i(
		roundi((rect.position.x - origin.x) / float(px)),
		roundi((rect.position.y - origin.y) / float(px))
	)
	c = clamp_to_legal(c, w, h)
	return Rect2(origin + Vector2(c) * float(px), rect.size)


## 把格坐标准夹进合法范围：左上角 >= 0，且右下角不超过 (cols, rows)。
func clamp_to_legal(c: Vector2i, w: int, h: int) -> Vector2i:
	# 参考图比网格还大时，退化为贴齐左上（0,0）
	var max_x: int = max(0, columns_count - w)
	var max_y: int = max(0, rows_count - h)
	return Vector2i(clampi(c.x, 0, max_x), clampi(c.y, 0, max_y))
#endregion


#region 旋转预览（只读，不改 _selection）
## 返回当前选择在指定 rot 下、除起始格外所有格的“绝对网格坐标”。
## 只读叠加：不改 _selection、不动任何 panel 的选中态，仅供预览层绘制。
func get_preview_cells_for_rot(rot: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin := get_origin()
	if origin == null:
		return result
	var o := origin.grid_coord
	# 起始格自身：绕 (0,0) 旋转后仍是 (0,0)，即原点不动
	result.append(o)
	for panel in _selection:
		var rel := panel.grid_coord - o
		if rel == Vector2i.ZERO:
			continue
		result.append(o + _rotate_offset(rel, rot))
	return result

## 与 SouvenirResource.rotated_offsets() 同一套公式（绕原点 (0,0) 顺时针）。
func _rotate_offset(off: Vector2i, rot: int) -> Vector2i:
	match rot:
		1:  # DEG_90
			return Vector2i(-off.y, off.x)
		2:  # DEG_180
			return Vector2i(-off.x, -off.y)
		3:  # DEG_270
			return Vector2i(off.y, -off.x)
		_:
			return off
#endregion
