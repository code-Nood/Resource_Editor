class_name PropertyHelper
extends RefCounted

# Resource/Object 自带的内置属性，不应作为业务属性编辑
const RESOURCE_BUILTINS := [
	"resource_name",
	"resource_path",
	"resource_local_to_scene",
	"resource_scene_unique_id",
	"resource_base_type",
	"resource_external_path",
	"resource_uid",
	"id",
]

static func get_editable_properties(script: Script) -> Array:
	var props = []
	var temp = script.new()
	if temp == null:
		return props
	for prop in temp.get_property_list():
		if (prop.usage & PROPERTY_USAGE_EDITOR) and (prop.usage & PROPERTY_USAGE_STORAGE):
			if prop.name in ["script", "id"] or prop.name in RESOURCE_BUILTINS:
				continue
			props.append({
				"name": prop.name,
				"type": prop.type,
				"hint": prop.hint,
				"hint_string": prop.hint_string
			})
	return props
