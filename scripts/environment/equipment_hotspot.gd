class_name EquipmentHotspot
extends Node2D
## Area clicavel alinhada a um equipamento **ja pintado no fundo**.
##
## Nao desenha o equipamento: a arte continua sendo a do quintal. O hotspot so ocupa a
## regiao correspondente, capta o clique e desenha um contorno discreto no hover, para
## que o jogador perceba que ali ha algo selecionavel.
##
## Vive em `PropsLayer`, entao acompanha a escala uniforme do quintal. A `Area2D` tem
## `monitoring` e `monitorable` desligados: existe apenas para o clique e nao bloqueia
## Caramelo, que nem usa fisica para andar.

## Emitido a cada selecao. Quem decide o que fazer e o sistema de exercicios.
signal selected(exercise_id: StringName)
signal hover_changed(exercise_id: StringName, hovered: bool)

## Exercicio que este hotspot representa, como em `data/exercises.json`.
@export var exercise_id: StringName = &""
## Tamanho da area clicavel, em coordenadas-base.
@export var area_size := Vector2(200.0, 120.0)

const OUTLINE_LERP := 12.0

var _hovered := false
var _glow := 0.0

@onready var _outline: Line2D = $Outline
@onready var _area: Area2D = $Area2D
@onready var _shape: CollisionShape2D = $Area2D/CollisionShape2D


func _ready() -> void:
	get_viewport().physics_object_picking = true
	var half := area_size * 0.5
	(_shape.shape as RectangleShape2D).size = area_size
	_outline.points = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y)])
	_outline.modulate.a = 0.0
	_area.mouse_entered.connect(_on_mouse_entered)
	_area.mouse_exited.connect(_on_mouse_exited)
	_area.input_event.connect(_on_input_event)


func _process(delta: float) -> void:
	var target := 1.0 if _hovered else 0.0
	_glow = move_toward(_glow, target, delta * OUTLINE_LERP)
	_outline.modulate.a = _glow * 0.85


func select() -> void:
	selected.emit(exercise_id)


func is_hovered() -> bool:
	return _hovered


func _on_mouse_entered() -> void:
	_hovered = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	hover_changed.emit(exercise_id, true)


func _on_mouse_exited() -> void:
	_hovered = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	hover_changed.emit(exercise_id, false)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			select()
