extends Control

class_name RotPreview

## 只读旋转预览叠加层：不参与选择逻辑，仅绘制“当前形状旋转到某档位”的占格。
## 由 GridInventoryEditor 驱动：喂入绝对网格坐标数组 + 单格像素尺寸，本层负责画。

## 待绘制的绝对网格坐标（含起始格）
var _cells: Array[Vector2i] = []
## 单格像素尺寸（= EditorPanel 的 custom_minimum_size，默认 32）
var _cell_px: int = 32
## 格 (0,0) 左上角在本层局部坐标系中的位置（由 GridInventoryEditor 传入，
## 取自真实格子的 global_position，避免本层自算原点导致漂移）。
var _origin: Vector2 = Vector2.ZERO
## 是否启用绘制（形状为空或非预览态时关闭）
var _active: bool = false


## 设置预览格、单格尺寸与格原点（局部坐标），并请求重绘
func set_cells(cells: Array[Vector2i], cell_px: int = 32, origin: Vector2 = Vector2.ZERO) -> void:
	_cells = cells
	_cell_px = cell_px
	_origin = origin
	_active = not cells.is_empty()
	queue_redraw()


## 清空预览
func clear_cells() -> void:
	_cells = []
	_active = false
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var idx := 0
	for c in _cells:
		var rect := Rect2(_origin + Vector2(c) * _cell_px, Vector2(_cell_px, _cell_px))
		if idx == 0:
			# 起始格：用醒目的描边强调“原点不动”
			draw_rect(rect, Color(1.0, 0.85, 0.2, 0.22), true)
			draw_rect(rect, Color(1.0, 0.85, 0.2, 0.9), false, 2.0)
		else:
			draw_rect(rect, Color(0.3, 0.7, 1.0, 0.22), true)
			draw_rect(rect, Color(0.3, 0.7, 1.0, 0.8), false, 2.0)
		idx += 1
