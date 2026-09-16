extends Control
## Feedback mínimo do treino: o que o equipamento faz, por que não dá para usar agora e
## o que foi ganho ao terminar.
##
## É só uma faixa curta de texto, não o HUD da Etapa 9: não mostra energia nem força
## atuais, não tem barras e some sozinha. Como qualquer interface deste projeto, **não
## toca no modelo** — apenas lê o que o sistema de exercícios informa.

const GROUP := &"training_feedback"
const HOLD_SECONDS := 2.6
const BASE_FONT := 15
const MARGIN_BOTTOM := 96.0

var _system: ExerciseSystem
var _hold := 0.0
var _hovered: StringName = &""

@onready var _panel: PanelContainer = $Anchor/Panel
@onready var _anchor: Control = $Anchor
@onready var _label: Label = $Anchor/Panel/Label


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	get_viewport().size_changed.connect(_reposition)
	var session := GameSession.find_in(get_tree())
	if session != null:
		attach(session.get_exercise_system())


func attach(system: ExerciseSystem) -> void:
	if system == null:
		push_error("TrainingFeedback: sistema de exercicios ausente.")
		return
	_system = system
	_system.hotspot_hovered.connect(_on_hover)
	_system.exercise_rejected.connect(_on_rejected)
	_system.exercise_started.connect(_on_started)
	_system.exercise_completed.connect(_on_completed)
	_reposition()


func _process(delta: float) -> void:
	if _hold <= 0.0:
		return
	_hold -= delta
	if _hold <= 0.0 and _hovered == &"":
		hide()


## Texto exibido no momento; vazio quando nada aparece.
func get_text() -> String:
	return _label.text if visible else ""


# --------------------------------------------------------------------------------------

func _show(text: String, hold: bool) -> void:
	_label.text = text
	_hold = HOLD_SECONDS if hold else 0.0
	_reposition()
	show()


func _on_hover(exercise_id: StringName, hovered: bool) -> void:
	if not hovered:
		_hovered = &""
		if _hold <= 0.0:
			hide()
		return
	_hovered = exercise_id
	_show(_describe(exercise_id), false)


func _describe(exercise_id: StringName) -> String:
	var exercise := _system.get_exercise(exercise_id)
	if exercise.is_empty():
		return "Equipamento desconhecido"
	var name := String(exercise["display_name"])
	if not _system.is_unlocked(exercise_id):
		return "%s  ·  bloqueado até o nível %d" % [name, int(exercise["required_level"])]
	var line := "%s  ·  %d energia  →  +%d força" % [
		name, int(exercise["energy_cost"]), int(exercise["strength_gain"])]
	var blocking := _system.get_blocking_reason(exercise_id)
	if blocking != -1:
		line += "  ·  " + _reason_text(blocking, exercise)
	return line


func _reason_text(reason: int, exercise: Dictionary) -> String:
	match reason:
		ExerciseSystem.Rejection.LOCKED:
			return "bloqueado até o nível %d" % int(exercise.get("required_level", 0))
		ExerciseSystem.Rejection.INSUFFICIENT_ENERGY:
			return "Caramelo está cansado"
		ExerciseSystem.Rejection.EXERCISE_PENDING, ExerciseSystem.Rejection.ACTIVITY_RESERVED, \
		ExerciseSystem.Rejection.DOG_BUSY:
			return "Caramelo está ocupado"
		ExerciseSystem.Rejection.UNKNOWN_EXERCISE, ExerciseSystem.Rejection.POINT_NOT_FOUND:
			return "equipamento indisponível"
	return "não dá agora"


func _on_rejected(exercise_id: StringName, reason: int) -> void:
	_show(_reason_text(reason, _system.get_exercise(exercise_id)).capitalize(), true)


func _on_started(exercise_id: StringName, energy_spent: int) -> void:
	var exercise := _system.get_exercise(exercise_id)
	_show("%s  ·  −%d energia" % [String(exercise.get("display_name", exercise_id)), energy_spent], true)


func _on_completed(exercise_id: StringName, strength_added: int) -> void:
	var exercise := _system.get_exercise(exercise_id)
	_show("%s concluído  ·  +%d força" % [
		String(exercise.get("display_name", exercise_id)), strength_added], true)


## Mesma compensação do menu de alimentos: tamanho físico constante em qualquer resolução,
## aplicado ao tamanho da fonte para o texto não sair borrado.
func _reposition() -> void:
	if _anchor == null:
		return
	var viewport_size := get_viewport_rect().size
	var window := get_window()
	var window_height := float(window.size.y) if window != null else viewport_size.y
	var factor: float = clampf(viewport_size.y / maxf(window_height, 1.0), 0.5, 8.0)
	_label.add_theme_font_size_override("font_size", roundi(BASE_FONT * factor))
	var box := _panel.get_theme_stylebox("panel")
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		flat.content_margin_left = 14.0 * factor
		flat.content_margin_right = 14.0 * factor
		flat.content_margin_top = 8.0 * factor
		flat.content_margin_bottom = 8.0 * factor
		flat.set_corner_radius_all(roundi(8 * factor))
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_anchor.position = Vector2(
		(viewport_size.x - panel_size.x) * 0.5,
		viewport_size.y - panel_size.y - MARGIN_BOTTOM * factor)
