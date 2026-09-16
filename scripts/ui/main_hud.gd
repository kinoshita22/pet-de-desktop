extends Control
## HUD recolhivel do MVP: resumo dos atributos, atividade atual e as tres acoes.
##
## Fica oculto por padrao e aparece ao clicar em Caramelo, como pede o `MVP_SPEC.md`
## secao 18. Recolhe sozinho depois de alguns segundos sem uso, e nunca cobre o cachorro:
## o painel mora no canto inferior esquerdo.
##
## **A interface nunca altera o modelo.** Ela le atributos para exibir e chama os sistemas
## para agir; quem aplica energia, forca e vinculo sao eles. Toda atualizacao vem de sinal
## — nao ha consulta por quadro.

const GROUP := &"main_hud"
## Tempo de inatividade antes de recolher. E comportamento de interface, nao balanceamento.
const COLLAPSE_SECONDS := 8.0
const TOAST_SECONDS := 3.2
const MARGIN := 24.0
const PANEL_WIDTH := 264.0
const HEADER_FONT := 17
const LINE_FONT := 14
const SUB_FONT := 11
const BUTTON_FONT := 15
const BUTTON_HEIGHT := 32.0
const SEPARATION := 6

## Textos de apresentacao. Os codigos de rejeicao continuam sendo a logica dos sistemas;
## a interface apenas os traduz.
const ACTIVITY_TEXTS := {
	"idle": "Ocioso",
	"walking": "Passeando",
	"walking_food": "Indo comer",
	"walking_training": "Indo treinar",
	"walking_rest": "Indo descansar",
	"eating": "Comendo",
	"training_push_ups": "Fazendo flexões",
	"training_dumbbells": "Treinando com halteres",
	"training": "Treinando",
	"resting": "Descansando",
	"happy": "Feliz",
}

var _model: ProgressionModel
var _feeding: FeedingSystem
var _exercise: ExerciseSystem
var _rest: RestSystem
var _dog: Caramelo
var _food_menu: Control
var _exercise_menu: Control

var _idle_seconds := 0.0
var _toast_seconds := 0.0
var _pointer_inside := false

@onready var _anchor: Control = $Anchor
@onready var _panel: PanelContainer = $Anchor/Panel
@onready var _layout: VBoxContainer = $Anchor/Panel/Layout
@onready var _header: Label = $Anchor/Panel/Layout/Header
@onready var _level_label: Label = $Anchor/Panel/Layout/Level
@onready var _energy_label: Label = $Anchor/Panel/Layout/Energy/Value
@onready var _energy_bar: ProgressBar = $Anchor/Panel/Layout/Energy/Bar
@onready var _strength_label: Label = $Anchor/Panel/Layout/Strength/Value
@onready var _strength_sub: Label = $Anchor/Panel/Layout/Strength/Sub
@onready var _bond_label: Label = $Anchor/Panel/Layout/Bond/Value
@onready var _bond_sub: Label = $Anchor/Panel/Layout/Bond/Sub
@onready var _activity_label: Label = $Anchor/Panel/Layout/CurrentActivity
@onready var _actions: HBoxContainer = $Anchor/Panel/Layout/ActionBar
@onready var _feed_button: Button = $Anchor/Panel/Layout/ActionBar/FeedButton
@onready var _train_button: Button = $Anchor/Panel/Layout/ActionBar/TrainButton
@onready var _rest_button: Button = $Anchor/Panel/Layout/ActionBar/RestButton
@onready var _context: Control = $Anchor/ContextContainer
@onready var _toast: Control = $Toast
@onready var _toast_panel: PanelContainer = $Toast/Panel
@onready var _toast_label: Label = $Toast/Panel/Label


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_toast.hide()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_pointer_entered)
	mouse_exited.connect(_on_pointer_exited)
	_panel.mouse_entered.connect(_on_pointer_entered)
	_panel.mouse_exited.connect(_on_pointer_exited)
	_feed_button.pressed.connect(_on_feed_pressed)
	_train_button.pressed.connect(_on_train_pressed)
	_rest_button.pressed.connect(_on_rest_pressed)
	for button in [_feed_button, _train_button, _rest_button]:
		button.focus_entered.connect(_keep_open)
	get_viewport().size_changed.connect(_reposition)
	var session := GameSession.find_in(get_tree())
	if session != null:
		attach(session)


## Liga o HUD a sessao. Separado de `_ready` para que os testes possam montar o HUD
## isolado. Todas as conexoes sao guardadas contra duplicata.
func attach(session: GameSession) -> void:
	if session == null:
		push_error("MainHUD: sessao ausente.")
		return
	_model = session.get_model()
	_feeding = session.get_feeding_system()
	_exercise = session.get_exercise_system()
	_rest = session.get_rest_system()
	_dog = session.get_caramelo()
	_food_menu = _first_in_group(&"food_menu")
	_exercise_menu = _first_in_group(&"exercise_menu")

	_connect(_dog.selected, _on_dog_selected)
	_connect(_dog.state_changed, _on_state_changed)
	_connect(_dog.activity_started, _on_activity_signal)
	_connect(_dog.activity_completed, _on_activity_signal)

	_connect(_model.energy_changed, _on_energy_changed)
	_connect(_model.strength_changed, _on_pair_changed)
	_connect(_model.bond_changed, _on_pair_changed)
	_connect(_model.level_changed, _on_level_changed)
	_connect(_model.unlock_granted, _on_unlock_granted)

	_connect(_feeding.feeding_completed, _on_feeding_completed)
	_connect(_feeding.feeding_rejected, _on_feeding_rejected)
	_connect(_feeding.cooldown_changed, _on_cooldown_changed)
	_connect(_feeding.bowl_selected, _keep_open)

	_connect(_exercise.exercise_started, _on_exercise_started)
	_connect(_exercise.exercise_completed, _on_exercise_completed)
	_connect(_exercise.exercise_rejected, _on_exercise_rejected)

	_connect(_rest.rest_started, _on_rest_started)
	_connect(_rest.rest_completed, _on_rest_completed)
	_connect(_rest.rest_rejected, _on_rest_rejected)

	if _food_menu != null and _food_menu.has_method("attach"):
		pass  # o menu ja se liga sozinho no proprio `_ready`
	refresh()


func _connect(target: Signal, callable: Callable) -> void:
	if not target.is_connected(callable):
		target.connect(callable)


func _first_in_group(group: StringName) -> Control:
	var nodes := get_tree().get_nodes_in_group(group)
	return nodes[0] as Control if not nodes.is_empty() else null


func _process(delta: float) -> void:
	simulate(delta)


# --------------------------------------------------------------------------------------
# API publica
# --------------------------------------------------------------------------------------

func open() -> void:
	if _model == null:
		return
	refresh()
	_reposition()
	show()
	_keep_open()


func close() -> void:
	_close_context_menus()
	hide()


func is_open() -> bool:
	return visible


## Leitura inicial completa. Depois disso o HUD so reage a sinais.
func refresh() -> void:
	if _model == null:
		return
	_refresh_attributes()
	_refresh_activity()
	_refresh_buttons()


## Avanca o recolhimento automatico e o toast em `delta` segundos.
##
## O motor chama isto por `_process`. E publico porque os testes precisam adiantar os oito
## segundos de inatividade sem esperar tempo real.
func simulate(delta: float) -> void:
	if delta <= 0.0:
		return
	if _toast_seconds > 0.0:
		_toast_seconds -= delta
		if _toast_seconds <= 0.0:
			_toast.hide()
	if not visible:
		return
	if _should_hold_open():
		_idle_seconds = 0.0
		return
	_idle_seconds += delta
	if _idle_seconds >= COLLAPSE_SECONDS:
		close()


func get_activity_text() -> String:
	return _activity_label.text


func get_toast_text() -> String:
	return _toast_label.text if _toast.visible else ""


func get_seconds_until_collapse() -> float:
	return maxf(COLLAPSE_SECONDS - _idle_seconds, 0.0)


func has_context_menu_open() -> bool:
	return (_food_menu != null and _food_menu.call("is_open")) \
		or (_exercise_menu != null and _exercise_menu.call("is_open"))


func set_pointer_inside(inside: bool) -> void:
	_pointer_inside = inside
	if inside:
		_keep_open()


# --------------------------------------------------------------------------------------
# Recolhimento
# --------------------------------------------------------------------------------------

func _should_hold_open() -> bool:
	if has_context_menu_open():
		return true
	if _pointer_inside:
		return true
	if _toast_seconds > 0.0:
		return true
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and is_ancestor_of(focused)


func _keep_open() -> void:
	_idle_seconds = 0.0


func _on_pointer_entered() -> void:
	set_pointer_inside(true)


func _on_pointer_exited() -> void:
	set_pointer_inside(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	# Escape fecha primeiro o menu contextual; so depois o HUD.
	if has_context_menu_open():
		_close_context_menus()
		_keep_open()
	else:
		close()
	get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------------------
# Acoes
# --------------------------------------------------------------------------------------

func _on_dog_selected() -> void:
	# Selecionar apenas revela o HUD: nao interrompe atividade nem altera estado.
	if visible:
		_keep_open()
		refresh()
	else:
		open()


func _on_feed_pressed() -> void:
	_keep_open()
	_close_context_menus(_food_menu)
	if _food_menu == null:
		return
	if _food_menu.call("is_open"):
		_food_menu.call("close")
		return
	_food_menu.call("set_anchor_rect", _context_rect())
	_food_menu.call("open")


func _on_train_pressed() -> void:
	_keep_open()
	_close_context_menus(_exercise_menu)
	if _exercise_menu == null:
		return
	if _exercise_menu.call("is_open"):
		_exercise_menu.call("close")
		return
	_exercise_menu.call("set_anchor_rect", _context_rect())
	_exercise_menu.call("open")


func _on_rest_pressed() -> void:
	_keep_open()
	_close_context_menus()
	# O HUD nao aplica energia: quem decide e o sistema de descanso.
	_rest.request_rest()


## Regiao a que os menus contextuais se encostam: a borda superior do painel do HUD.
## `ContextContainer` marca exatamente esse ponto, e é reposicionado junto com o painel.
func _context_rect() -> Rect2:
	return Rect2(_context.global_position, Vector2(maxf(_panel.size.x, 1.0), 1.0))


func _close_context_menus(keep: Control = null) -> void:
	for menu in [_food_menu, _exercise_menu]:
		if menu != null and menu != keep and menu.call("is_open"):
			menu.call("close")


# --------------------------------------------------------------------------------------
# Atualizacao por sinais
# --------------------------------------------------------------------------------------

func _on_energy_changed(_previous: int, _new_value: int) -> void:
	_refresh_attributes()
	_refresh_buttons()


func _on_pair_changed(_previous: int, _new_value: int) -> void:
	_refresh_attributes()


func _on_level_changed(_previous: int, new_level: int) -> void:
	_refresh_attributes()
	_refresh_buttons()
	_show_toast("Nível %d!" % new_level)


func _on_unlock_granted(unlock_id: StringName) -> void:
	if unlock_id == &"dumbbells":
		_show_toast("Halteres liberados.")


func _on_state_changed(_previous: int, _new_state: int) -> void:
	_refresh_activity()
	_refresh_buttons()


func _on_activity_signal(_activity: int) -> void:
	_refresh_activity()
	_refresh_buttons()


func _on_cooldown_changed(_food_id: StringName, _remaining: float) -> void:
	_refresh_buttons()


func _on_feeding_completed(_food_id: StringName, energy: int, bond: int) -> void:
	var parts: Array[String] = []
	if energy > 0:
		parts.append("+%d energia" % energy)
	if bond > 0:
		parts.append("+%d vínculo" % bond)
	_show_toast("  ".join(parts) if not parts.is_empty() else "Caramelo comeu.")


func _on_feeding_rejected(_food_id: StringName, reason: int) -> void:
	_show_toast(_feeding_reason_text(reason))


func _on_exercise_started(_exercise_id: StringName, energy_spent: int) -> void:
	_show_toast("−%d energia" % energy_spent)


func _on_exercise_completed(_exercise_id: StringName, strength_added: int) -> void:
	_show_toast("+%d força" % strength_added)


func _on_exercise_rejected(_exercise_id: StringName, reason: int) -> void:
	_show_toast(_exercise_reason_text(reason))


func _on_rest_started() -> void:
	_show_toast("Descanso iniciado.")
	_refresh_activity()
	_refresh_buttons()


func _on_rest_completed() -> void:
	_refresh_activity()
	_refresh_buttons()


func _on_rest_rejected(reason: int) -> void:
	_show_toast(_rest_reason_text(reason))


# --------------------------------------------------------------------------------------
# Textos
# --------------------------------------------------------------------------------------

func _feeding_reason_text(reason: int) -> String:
	match reason:
		FeedingSystem.Rejection.ON_COOLDOWN: return "Esse alimento ainda está descansando."
		FeedingSystem.Rejection.MEAL_PENDING: return "Caramelo já está indo comer."
		FeedingSystem.Rejection.DOG_BUSY, FeedingSystem.Rejection.ACTIVITY_RESERVED:
			return "Caramelo está ocupado."
		FeedingSystem.Rejection.UNKNOWN_FOOD: return "Alimento desconhecido."
	return "Não dá para alimentar agora."


func _exercise_reason_text(reason: int) -> String:
	match reason:
		ExerciseSystem.Rejection.LOCKED: return "Halteres liberados no nível 3."
		ExerciseSystem.Rejection.INSUFFICIENT_ENERGY: return "Energia insuficiente."
		ExerciseSystem.Rejection.EXERCISE_PENDING, ExerciseSystem.Rejection.DOG_BUSY, \
		ExerciseSystem.Rejection.ACTIVITY_RESERVED:
			return "Caramelo está ocupado."
		ExerciseSystem.Rejection.UNKNOWN_EXERCISE, ExerciseSystem.Rejection.POINT_NOT_FOUND:
			return "Equipamento indisponível."
	return "Não dá para treinar agora."


func _rest_reason_text(reason: int) -> String:
	match reason:
		RestSystem.Rejection.DOG_BUSY, RestSystem.Rejection.ACTIVITY_RESERVED:
			return "Caramelo está ocupado."
		RestSystem.Rejection.POINT_NOT_FOUND: return "Lugar de descanso indisponível."
	return "Não dá para descansar agora."


func _show_toast(message: String) -> void:
	# Uma mensagem nova substitui a anterior; nunca se empilham.
	_toast_label.text = message
	_toast_seconds = TOAST_SECONDS
	_reposition()
	_toast.show()


# --------------------------------------------------------------------------------------
# Leitura dos atributos
# --------------------------------------------------------------------------------------

func _refresh_attributes() -> void:
	var level := _model.get_level()
	_level_label.text = "Nível %d" % level
	_energy_label.text = "Energia %d/%d" % [_model.get_energy(), _model.get_max_energy()]
	_energy_bar.max_value = float(_model.get_max_energy())
	_energy_bar.value = float(_model.get_energy())

	var strength := _model.get_strength()
	_strength_label.text = "Força %d" % strength
	var config := _model.get_config()
	var next_threshold := -1
	for entry: Dictionary in config.get_levels():
		if int(entry["level"]) == level + 1:
			next_threshold = int(entry["required_strength"])
	_strength_sub.text = "Nível máximo" if next_threshold < 0 \
		else "Próximo nível: %d/%d" % [strength, next_threshold]

	var bond := _model.get_bond()
	_bond_label.text = "Vínculo %d" % bond
	var next_bond := -1
	for behavior: Dictionary in config.get_bond_behaviors():
		if int(behavior["required_bond"]) > bond and next_bond < 0:
			next_bond = int(behavior["required_bond"])
	_bond_sub.text = "Todas as reações liberadas" if next_bond < 0 \
		else "Próxima reação: %d/%d" % [bond, next_bond]


func _refresh_activity() -> void:
	_activity_label.text = ACTIVITY_TEXTS[_activity_key()]


## O texto nao sai so do estado: uma caminhada dirigida a uma atividade diz para onde vai.
func _activity_key() -> String:
	match _dog.get_current_state():
		Caramelo.State.WALKING:
			match _dog.get_reserved_activity():
				Caramelo.State.EATING: return "walking_food"
				Caramelo.State.TRAINING: return "walking_training"
				Caramelo.State.RESTING: return "walking_rest"
			return "walking"
		Caramelo.State.EATING:
			return "eating"
		Caramelo.State.TRAINING:
			var key := "training_%s" % _dog.get_training_style()
			return key if ACTIVITY_TEXTS.has(key) else "training"
		Caramelo.State.RESTING:
			return "resting"
		Caramelo.State.HAPPY:
			return "happy"
	return "idle"


func _refresh_buttons() -> void:
	# Alimentar e Treinar seguem habilitados mesmo com tudo bloqueado: abrir o menu e como
	# o jogador descobre os tempos de recarga e os niveis exigidos.
	_feed_button.disabled = false
	_train_button.disabled = false
	var busy := not _dog.is_interruptible() or _dog.has_reserved_activity()
	_rest_button.disabled = busy
	_rest_button.tooltip_text = "Caramelo está ocupado" if busy else "Mandar Caramelo descansar"


# --------------------------------------------------------------------------------------
# Posicionamento
# --------------------------------------------------------------------------------------

func _reposition() -> void:
	if _anchor == null or _panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var factor := UiScale.factor_for(self)
	_apply_scale(factor)
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_anchor.position = Vector2(
		MARGIN * factor,
		maxf(viewport_size.y - panel_size.y - MARGIN * factor, MARGIN * factor))
	# o marcador de encaixe acompanha o topo do painel
	_context.position = Vector2.ZERO
	_context.size = Vector2(panel_size.x, 0.0)

	var toast_size := _toast_panel.get_combined_minimum_size()
	_toast_panel.size = toast_size
	_toast.position = Vector2(
		(viewport_size.x - toast_size.x) * 0.5,
		MARGIN * factor)


func _apply_scale(factor: float) -> void:
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH * factor, 0.0)
	_header.add_theme_font_size_override("font_size", roundi(HEADER_FONT * factor))
	_layout.add_theme_constant_override("separation", roundi(SEPARATION * factor))
	_actions.add_theme_constant_override("separation", roundi(SEPARATION * factor))
	for label in [_level_label, _energy_label, _strength_label, _bond_label, _activity_label]:
		label.add_theme_font_size_override("font_size", roundi(LINE_FONT * factor))
	for label in [_strength_sub, _bond_sub]:
		label.add_theme_font_size_override("font_size", roundi(SUB_FONT * factor))
	_energy_bar.custom_minimum_size = Vector2(0.0, 8.0 * factor)
	for button in [_feed_button, _train_button, _rest_button]:
		button.add_theme_font_size_override("font_size", roundi(BUTTON_FONT * factor))
		button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT * factor)
	_toast_label.add_theme_font_size_override("font_size", roundi(LINE_FONT * factor))
	UiScale.scale_stylebox(_panel, factor)
	UiScale.scale_stylebox(_toast_panel, factor, 8.0, 6.0, 8, 2)
