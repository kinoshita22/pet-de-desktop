class_name EvolutionSystem
extends Node
## Evolucao visual por nivel e fila de apresentacoes.
##
## O `MVP_SPEC.md` secao 15 fixa duas formas: inicial nos niveis 1-3 e musculosa nos 4-5.
## A aparencia e **derivada do nivel** — ela nunca e salva, e recalcular o nivel a partir
## da forca ja basta para saber qual forma usar.
##
## Nada aqui altera atributo. O sistema so escuta o modelo e manda o visual desenhar.
##
## Eventos que chegam enquanto Caramelo esta ocupado nao se perdem nem se duplicam: vao
## para uma fila curta, sem repetidos, que escoa quando ele fica livre. `EATING` e
## `TRAINING` nunca sao interrompidos por causa de animacao.

signal evolution_started(level: int)
signal evolution_completed(level: int)
signal presentation_started(presentation_id: StringName)

## Ordem de prioridade da fila, do mais importante ao menos.
const PRIORITY: Array = [
	&"level_4", &"level_5", &"level_2", &"startup_celebration",
	&"rare_affection_idle", &"petting_reaction", &"simple_affection",
]

var _model: ProgressionModel
var _dog: Caramelo
var _queue: Array[StringName] = []
var _current: StringName = &""
var _blocked := false


func _process(delta: float) -> void:
	simulate(delta)


func configure(model: ProgressionModel, dog: Caramelo) -> void:
	if model == null or dog == null:
		push_error("EvolutionSystem: modelo ou Caramelo ausente.")
		return
	_model = model
	_dog = dog
	if not _model.level_changed.is_connected(_on_level_changed):
		_model.level_changed.connect(_on_level_changed)
	# Restaurar um save aplica a forma em silencio: nada evoluiu ali.
	if not _model.restored.is_connected(_on_restored):
		_model.restored.connect(_on_restored)
	_dog.apply_body_form(BodyForms.form_for_level(_model.get_level()), false)


func is_configured() -> bool:
	return _model != null and _dog != null


## Impede que apresentacoes escoem — usado enquanto o resumo offline esta na tela.
func set_blocked(blocked: bool) -> void:
	_blocked = blocked


func is_busy() -> bool:
	return _current != &"" or (_dog != null and _dog.is_presenting())


func get_queue() -> Array:
	return _queue.duplicate()


## Enfileira uma apresentacao. Duplicatas sao descartadas.
func enqueue(presentation_id: StringName) -> void:
	if presentation_id == &"" or _queue.has(presentation_id) or _current == presentation_id:
		return
	_queue.append(presentation_id)
	_queue.sort_custom(func(a: StringName, b: StringName) -> bool:
		return PRIORITY.find(a) < PRIORITY.find(b))


## Avanca a fila. Publico para os testes escoarem sem esperar tempo real.
func simulate(delta: float) -> void:
	if delta <= 0.0 or not is_configured():
		return
	if _current != &"" and not _dog.is_presenting():
		var finished := _current
		_current = &""
		if finished == &"level_4":
			evolution_completed.emit(4)
	if _current != &"" or _queue.is_empty() or _blocked:
		return
	# Atividade dirigida tem prioridade sobre qualquer animacao: o evento espera.
	if not _dog.is_interruptible() or _dog.has_reserved_activity():
		return
	_current = _queue.pop_front()
	if _current == &"level_4":
		evolution_started.emit(4)
		_dog.apply_body_form(BodyForms.Form.MUSCULAR, true)
	else:
		_dog.play_presentation(_current)
	presentation_started.emit(_current)


func _on_level_changed(previous_level: int, new_level: int) -> void:
	# Cruzar varios niveis de uma vez nao perde os eventos do caminho.
	for level in range(previous_level + 1, new_level + 1):
		match level:
			2: enqueue(&"level_2")
			4: enqueue(&"level_4")
			5: enqueue(&"level_5")


func _on_restored() -> void:
	# Restauracao silenciosa: a forma certa entra sem transformacao e sem comemoracao.
	_queue.clear()
	_current = &""
	_dog.apply_body_form(BodyForms.form_for_level(_model.get_level()), false)
