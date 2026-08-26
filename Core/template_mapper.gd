extends Node

var name_mapping :Dictionary = {
	"icon": "res://EditorTemplate/Children/texture/texture_picker.tscn",
	"texture": "res://EditorTemplate/Children/texture/texture_picker.tscn",
}

var hint_mapping :Dictionary = {
	PROPERTY_HINT_ENUM: "res://EditorTemplate/Children/option/option.tscn",
	PROPERTY_HINT_RESOURCE_TYPE: "res://EditorTemplate/Children/res/res_picker.tscn"
}

var type_fallback :Dictionary = {
	TYPE_INT:"res://EditorTemplate/Children/spin/spinbox.tscn",
	TYPE_STRING:"res://EditorTemplate/Children/line/line_edit.tscn",
	TYPE_BOOL:"res://EditorTemplate/Children/bool/bool_button.tscn",
	TYPE_FLOAT:"res://EditorTemplate/Children/spin/spinbox.tscn",
	TYPE_OBJECT:"res://EditorTemplate/Children/res/res_picker.tscn"
}

func get_template_path(prop:Dictionary) -> String:
	if prop.has("name") and prop.name in name_mapping:
		return name_mapping[prop.name]
	
	if prop.has("hint") and prop.hint in hint_mapping:
		return hint_mapping[prop.hint]

	if prop.has("type") and prop.type in type_fallback:
		return type_fallback[prop.type]
	return ""

func set_name_mapping(property_name: String, template_path: String) -> void:
	name_mapping[property_name] = template_path

func remove_name_mapping(property_name: String) -> void:
	name_mapping.erase(property_name)



