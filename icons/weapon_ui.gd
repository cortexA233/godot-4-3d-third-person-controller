extends PanelContainer

const ICONE_SCENE := preload("res://icons/icone.tscn")
const BOMB_ICON := preload("res://icons/bomb_icon.png")

var nodes := {}
var selected_node: String = ""


func _ready() -> void:
	# The default weapon icon (%Flash) is authored in the scene. The grenade icon
	# reuses the same icon component with the bomb texture, added next to it.
	nodes["DEFAULT"] = %Flash
	nodes["GRENADE"] = _create_grenade_icon()
	# Highlight the default weapon from the start, regardless of signal timing.
	switch_to("DEFAULT")


func _create_grenade_icon() -> Node:
	var row: Node = %Flash.get_parent().get_parent()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	row.add_child(margin)

	var icon := ICONE_SCENE.instantiate()
	margin.add_child(icon)
	icon.texture = BOMB_ICON
	return icon


func switch_to(node_name : String):
	if not nodes.has(node_name):
		return
	# Return if same node
	if node_name == selected_node: return
	if selected_node != "":
		# Unselect previous
		nodes[selected_node].set_state(false)
	# Select node
	nodes[node_name].set_state(true)
	selected_node = node_name
