class_name FoodBowl
extends Node2D
## Pote de comida do quintal: visual provisorio e area clicavel.
##
## Feito com poligonos do proprio Godot, sem asset externo. Vive em `PropsLayer`, entao
## acompanha a escala uniforme do `Backyard` e e desenhado a frente de Caramelo.
##
## O pote nao conhece alimento, recarga nem modelo: ele so avisa que foi selecionado. Quem
## decide o que fazer com isso e o sistema de alimentacao.
##
## Nao bloqueia Caramelo fisicamente: a `Area2D` existe apenas para captar o clique
## (`monitoring` e `monitorable` desligados), e Caramelo nem usa fisica para andar.

## Emitido a cada selecao pelo jogador.
signal selected()

const HOVER_SCALE := 1.06
const HOVER_LERP := 14.0

var _hovered := false

@onready var _visual: Node2D = $Visual
@onready var _area: Area2D = $Area2D


func _ready() -> void:
	# A captacao de clique em 2D depende disto; o padrao varia conforme o viewport.
	get_viewport().physics_object_picking = true
	_area.mouse_entered.connect(_on_mouse_entered)
	_area.mouse_exited.connect(_on_mouse_exited)
	_area.input_event.connect(_on_input_event)


func _process(delta: float) -> void:
	var target := HOVER_SCALE if _hovered else 1.0
	var weight := clampf(delta * HOVER_LERP, 0.0, 1.0)
	_visual.scale = _visual.scale.lerp(Vector2(target, target), weight)
	_visual.modulate = _visual.modulate.lerp(
		Color(1.12, 1.12, 1.12) if _hovered else Color.WHITE, weight)


## Selecao explicita, sem depender de evento de entrada. E o que o teste usa e tambem o
## caminho por onde o clique real passa.
func select() -> void:
	selected.emit()


func is_hovered() -> bool:
	return _hovered


func _on_mouse_entered() -> void:
	_hovered = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _on_mouse_exited() -> void:
	_hovered = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _on_input_event(_viewport: Node, event: InputEvent, _shape: int) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			select()
