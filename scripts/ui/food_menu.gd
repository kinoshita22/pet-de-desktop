extends Control
## Menu contextual do pote: lista os tres alimentos e encaminha a escolha.
##
## A interface **nao** aplica recompensa e nao toca no modelo de progressao. Ela lê os
## alimentos da configuracao validada, mostra disponibilidade e chama
## `FeedingSystem.request_feeding`. Tudo o que acontece depois e responsabilidade do
## sistema.
##
## Nao e um sistema generico de janelas: e um painel so, com tres botoes.

const MENU_GROUP := &"food_menu"

## Medidas do painel em **pixels de tela**, nao em unidades do viewport.
##
## Com `stretch/aspect = "expand"` o viewport cresce conforme a janela: em 640 x 1000 ele
## vira 1920 x 2849. Um painel de tamanho fixo em unidades do viewport encolheria a um
## terco na tela. Aqui as medidas sao multiplicadas pelo fator de compensacao, de modo
## que o menu ocupe sempre o mesmo espaco fisico.
##
## O fator e aplicado aos **tamanhos de fonte**, e nao a `scale` do no: escalar o no
## reamostraria o texto ja rasterizado e ele sairia borrado nas proporcoes extremas.
const PANEL_WIDTH := 300.0
const MARGIN_BOTTOM := 28.0
const TITLE_FONT := 16
const BUTTON_FONT := 17
const DETAIL_FONT := 12
const CLOSE_FONT := 14
const BUTTON_HEIGHT := 30.0
const SEPARATION := 8

var _system: FeedingSystem
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
	if session == null:
		push_error("FoodMenu: nenhuma GameSession na arvore; o menu ficara inerte.")
		return
	attach(session.get_feeding_system())


## Liga o menu ao sistema. Separado de `_ready` para que os testes possam montar o menu
## isolado, sem depender da cena principal inteira.
func attach(system: FeedingSystem) -> void:
	if system == null:
		push_error("FoodMenu: sistema de alimentacao ausente.")
		return
	_system = system
	_system.bowl_selected.connect(_on_bowl_selected)
	_system.feeding_requested.connect(_on_feeding_requested)
	_system.cooldown_changed.connect(_on_cooldown_changed)
	_build_items()
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


## Identificadores dos alimentos exibidos, na ordem do arquivo de dados.
func get_item_ids() -> Array:
	return _buttons.keys()


func get_button(food_id: StringName) -> Button:
	return _buttons.get(food_id) as Button


# --------------------------------------------------------------------------------------
# Construcao e atualizacao
# --------------------------------------------------------------------------------------

func _build_items() -> void:
	for child in _items.get_children():
		child.queue_free()
	_buttons.clear()
	_details.clear()
	for food: Dictionary in _system.get_foods():
		var food_id := StringName(food["id"])
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)

		var button := Button.new()
		button.text = String(food["display_name"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_food_pressed.bind(food_id))

		var detail := Label.new()
		detail.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))

		row.add_child(button)
		row.add_child(detail)
		_items.add_child(row)
		_buttons[food_id] = button
		_details[food_id] = detail
	_refresh()


func _refresh() -> void:
	if _system == null:
		return
	for food: Dictionary in _system.get_foods():
		var food_id := StringName(food["id"])
		_refresh_item(food_id, _system.get_remaining_cooldown(food_id))


func _refresh_item(food_id: StringName, remaining: float) -> void:
	var button := _buttons.get(food_id) as Button
	var detail := _details.get(food_id) as Label
	if button == null or detail == null or _system == null:
		return
	var food := _system.get_food(food_id)
	if food.is_empty():
		return
	var gains := "+%d energia   +%d vinculo" % [int(food["energy"]), int(food["bond"])]
	if remaining > 0.0:
		button.disabled = true
		detail.text = "%s   ·   volta em %s" % [gains, _format_clock(remaining)]
	else:
		button.disabled = false
		detail.text = gains


static func _format_clock(seconds: float) -> String:
	var total := ceili(maxf(seconds, 0.0))
	return "%d:%02d" % [total / 60, total % 60]


# --------------------------------------------------------------------------------------
# Posicionamento
# --------------------------------------------------------------------------------------

## Mantem o painel com tamanho fisico constante e encostado na base do viewport.
func _reposition() -> void:
	if _anchor == null or _panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var window := get_window()
	var window_height := float(window.size.y) if window != null else viewport_size.y
	# viewport.y / janela.y e exatamente o inverso da escala do canvas.
	var factor: float = clampf(viewport_size.y / maxf(window_height, 1.0), 0.5, 8.0)
	_apply_scale(factor)
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_anchor.position = Vector2(
		(viewport_size.x - panel_size.x) * 0.5,
		viewport_size.y - panel_size.y - MARGIN_BOTTOM * factor)


func _apply_scale(factor: float) -> void:
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH * factor, 0.0)
	_title.add_theme_font_size_override("font_size", roundi(TITLE_FONT * factor))
	_close_button.add_theme_font_size_override("font_size", roundi(CLOSE_FONT * factor))
	_layout.add_theme_constant_override("separation", roundi(SEPARATION * factor))
	_items.add_theme_constant_override("separation", roundi(SEPARATION * factor))
	for food_id: StringName in _buttons:
		var button := _buttons[food_id] as Button
		button.add_theme_font_size_override("font_size", roundi(BUTTON_FONT * factor))
		button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT * factor)
		(_details[food_id] as Label).add_theme_font_size_override(
			"font_size", roundi(DETAIL_FONT * factor))
	var box := _panel.get_theme_stylebox("panel")
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		var margin := 12.0 * factor
		flat.content_margin_left = margin + 2.0 * factor
		flat.content_margin_right = margin + 2.0 * factor
		flat.content_margin_top = margin
		flat.content_margin_bottom = margin
		flat.set_corner_radius_all(roundi(10 * factor))
		flat.set_border_width_all(maxi(1, roundi(2 * factor)))


# --------------------------------------------------------------------------------------
# Reacoes
# --------------------------------------------------------------------------------------

func _on_bowl_selected() -> void:
	if is_open():
		close()
	else:
		open()


func _on_food_pressed(food_id: StringName) -> void:
	# A interface so encaminha. Quem decide aceitar ou recusar e o sistema.
	_system.request_feeding(food_id)


func _on_feeding_requested(_food_id: StringName) -> void:
	# Fecha so quando o pedido foi aceito; uma recusa mantem o menu utilizavel.
	close()


func _on_cooldown_changed(food_id: StringName, remaining: float) -> void:
	_refresh_item(food_id, remaining)
