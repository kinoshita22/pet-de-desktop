extends Control
## Menu compacto de exercicios: lista os dois, com custo, ganho e o motivo do bloqueio.
##
## Como o menu de alimentos, ele **nao aplica nada**: le a configuracao validada e chama
## `ExerciseSystem.request_exercise`. Nao toca no modelo de progressao.

const MENU_GROUP := &"exercise_menu"
const PANEL_WIDTH := 320.0
const MARGIN_BOTTOM := 28.0
const TITLE_FONT := 16
const BUTTON_FONT := 17
const DETAIL_FONT := 12
const CLOSE_FONT := 14
const BUTTON_HEIGHT := 30.0
const SEPARATION := 8

var _system: ExerciseSystem
var _anchor_rect := Rect2()
var _buttons: Dictionary = {}     # StringName -> Button
var _details: Dictionary = {}     # StringName -> Label

@onready var _anchor: Control = $Anchor
@onready var _panel: PanelContainer = $Anchor/Panel
@onready var _layout: VBoxContainer = $Anchor/Panel/Layout
@onready var _title: Label = $Anchor/Panel/Layout/Title
@onready var _items: VBoxContainer = $Anchor/Panel/Layout/Items
@onready var _close_button: Button = $Anchor/Panel/Layout/CloseButton


func _ready() -> void:
	add_to_group(MENU_GROUP)
	hide()
	_close_button.pressed.connect(close)
	get_viewport().size_changed.connect(_reposition)
	var session := GameSession.find_in(get_tree())
	if session != null:
		attach(session.get_exercise_system(), session.get_model())


## `model` serve so para reagir a `level_changed` e `energy_changed`: a disponibilidade e
## sempre perguntada ao sistema, nunca calculada aqui.
func attach(system: ExerciseSystem, model: ProgressionModel) -> void:
	if system == null:
		push_error("ExerciseMenu: sistema de exercicios ausente.")
		return
	_system = system
	_system.exercise_requested.connect(_on_exercise_requested)
	if model != null:
		model.level_changed.connect(_on_model_changed)
		model.energy_changed.connect(_on_model_changed)
	_build_items()
	_reposition()


func set_anchor_rect(rect: Rect2) -> void:
	_anchor_rect = rect
	if visible:
		_reposition()


func open() -> void:
	if _system == null:
		return
	_refresh()
	_reposition()
	show()


func close() -> void:
	hide()


func is_open() -> bool:
	return visible


func get_item_ids() -> Array:
	return _buttons.keys()


func get_button(exercise_id: StringName) -> Button:
	return _buttons.get(exercise_id) as Button


func get_detail_text(exercise_id: StringName) -> String:
	var label := _details.get(exercise_id) as Label
	return label.text if label != null else ""


# --------------------------------------------------------------------------------------

func _build_items() -> void:
	for child in _items.get_children():
		child.queue_free()
	_buttons.clear()
	_details.clear()
	for exercise: Dictionary in _system.get_exercises():
		var exercise_id := StringName(exercise["id"])
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)

		var button := Button.new()
		button.text = String(exercise["display_name"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_exercise_pressed.bind(exercise_id))

		var detail := Label.new()
		detail.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))

		row.add_child(button)
		row.add_child(detail)
		_items.add_child(row)
		_buttons[exercise_id] = button
		_details[exercise_id] = detail
	_refresh()


## Estado de cada exercicio, sempre perguntado ao sistema. Chamado ao abrir e a cada
## mudanca de nivel ou energia — nunca por quadro.
func _refresh() -> void:
	if _system == null:
		return
	for exercise: Dictionary in _system.get_exercises():
		var exercise_id := StringName(exercise["id"])
		var button := _buttons.get(exercise_id) as Button
		var detail := _details.get(exercise_id) as Label
		if button == null or detail == null:
			continue
		var line := "%d energia   →   +%d força" % [
			int(exercise["energy_cost"]), int(exercise["strength_gain"])]
		var reason := _system.get_blocking_reason(exercise_id)
		button.disabled = reason != -1
		match reason:
			-1:
				detail.text = line
				button.tooltip_text = "Treinar: %s" % String(exercise["display_name"])
			ExerciseSystem.Rejection.LOCKED:
				detail.text = "%s   ·   bloqueado até o nível %d" % [line, int(exercise["required_level"])]
				button.tooltip_text = "Precisa do nível %d" % int(exercise["required_level"])
			ExerciseSystem.Rejection.INSUFFICIENT_ENERGY:
				detail.text = "%s   ·   Caramelo está cansado" % line
				button.tooltip_text = "Energia insuficiente"
			_:
				detail.text = "%s   ·   Caramelo está ocupado" % line
				button.tooltip_text = "Caramelo está ocupado"


func _on_model_changed(_previous: int, _new_value: int) -> void:
	if _system != null:
		_refresh()


func _on_exercise_pressed(exercise_id: StringName) -> void:
	# A interface so encaminha. Quem aceita ou recusa e o sistema.
	_system.request_exercise(exercise_id)


func _on_exercise_requested(_exercise_id: StringName) -> void:
	close()


func _reposition() -> void:
	if _anchor == null or _panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var factor := UiScale.factor_for(self)
	_apply_scale(factor)
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	if _anchor_rect.size != Vector2.ZERO:
		_anchor.position = Vector2(
			clampf(_anchor_rect.position.x, 8.0 * factor,
				maxf(viewport_size.x - panel_size.x - 8.0 * factor, 8.0 * factor)),
			maxf(_anchor_rect.position.y - panel_size.y - 8.0 * factor, 8.0 * factor))
		return
	_anchor.position = Vector2(
		(viewport_size.x - panel_size.x) * 0.5,
		viewport_size.y - panel_size.y - MARGIN_BOTTOM * factor)


func _apply_scale(factor: float) -> void:
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH * factor, 0.0)
	_title.add_theme_font_size_override("font_size", roundi(TITLE_FONT * factor))
	_close_button.add_theme_font_size_override("font_size", roundi(CLOSE_FONT * factor))
	_layout.add_theme_constant_override("separation", roundi(SEPARATION * factor))
	_items.add_theme_constant_override("separation", roundi(SEPARATION * factor))
	for exercise_id: StringName in _buttons:
		var button := _buttons[exercise_id] as Button
		button.add_theme_font_size_override("font_size", roundi(BUTTON_FONT * factor))
		button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT * factor)
		(_details[exercise_id] as Label).add_theme_font_size_override(
			"font_size", roundi(DETAIL_FONT * factor))
	UiScale.scale_stylebox(_panel, factor)
