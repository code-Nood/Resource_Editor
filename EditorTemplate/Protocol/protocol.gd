class_name Protocol

extends PanelContainer

signal value_changed(new_value: Variant)

## 可选：某些编辑器（如 res_picker 处理 AtlasTexture）需要一次性回传"一对"关联贴图。
## 约定参数：full_texture（底图，内嵌整图）、atlas_texture（引用底图 + region）。
## 大多数模板不 emit 此信号，连接后无副作用。
signal texture_pair_changed(full_texture: Texture2D, atlas_texture: AtlasTexture)

func setup(property_name: String, property_hint: String, initial_value: Variant) -> void:
	pass
