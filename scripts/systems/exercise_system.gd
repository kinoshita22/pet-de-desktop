class_name ExerciseSystem
extends Node
## Ciclo completo de um treino: pedido, caminhada, debito, execucao e recompensa.
##
## O custo sai da energia **ao entrar de fato em `TRAINING`**, nunca no pedido nem durante
## a caminhada. A forca entra **so na conclusao natural**, uma unica vez. Entre um e outro
## Caramelo fica parado no ponto, executando a animacao.
##
## Como o sistema de alimentacao, ele nao conhece o outro: a disputa entre atividades e
## resolvida pela reserva mantida em `Caramelo`, que e a fonte unica de verdade.
##
## Nenhum numero de balanceamento vive aqui: custo, duracao, ganho, nivel minimo e chance
## comica saem de `data/exercises.json`, relidos dos dados validados quando sao usados.

## Codigos estaveis de recusa. Quem exibe traduz; o sistema nunca devolve frase livre.
enum Rejection {
	NOT_CONFIGURED,        ## dependencias ainda nao entregues
	UNKNOWN_EXERCISE,      ## identificador ausente de exercises.json
	LOCKED,                ## nivel atual abaixo do exigido
	INSUFFICIENT_ENERGY,   ## energia menor que o custo
	EXERCISE_PENDING,      ## ja existe um treino em andamento
	DOG_BUSY,              ## Caramelo em estado nao interrompivel
	ACTIVITY_RESERVED,     ## Caramelo ja tem outra atividade reservada (ex.: refeicao)
	POINT_NOT_FOUND,       ## o marcador do exercicio nao existe na cena
	DOG_REFUSED,           ## Caramelo recusou o pedido por outro motivo
	ENERGY_DEBIT_FAILED,   ## falha defensiva ao cobrar o custo na entrada
}

const REJECTION_NAMES: Array = [
	"NOT_CONFIGURED", "UNKNOWN_EXERCISE", "LOCKED", "INSUFFICIENT_ENERGY", "EXERCISE_PENDING",
	"DOG_BUSY", "ACTIVITY_RESERVED", "POINT_NOT_FOUND", "DOG_REFUSED", "ENERGY_DEBIT_FAILED",
]

signal exercise_requested(exercise_id: StringName)
signal exercise_rejected(exercise_id: StringName, reason: int)
## Energia ja debitada; Caramelo acabou de entrar em `TRAINING`.
signal exercise_started(exercise_id: StringName, energy_spent: int)
## Forca ja creditada; o modelo ja recalculou nivel e desbloqueios.
signal exercise_completed(exercise_id: StringName, strength_added: int)
## Sorteada depois da recompensa. Puramente visual.
signal comic_reaction_triggered(exercise_id: StringName)
## Um hotspot foi apontado ou selecionado. Serve ao feedback contextual.
signal hotspot_hovered(exercise_id: StringName, hovered: bool)

var _config: GameConfig
var _model: ProgressionModel
var _dog: Caramelo
var _points: Dictionary = {}          ## nome do marcador -> Vector2

var _pending_exercise: StringName = &""
var _started := false
var _rng := RandomNumberGenerator.new()
var _seed_is_fixed := false


func _ready() -> void:
	if not _seed_is_fixed:
		_rng.randomize()


# --------------------------------------------------------------------------------------
# Configuracao
# --------------------------------------------------------------------------------------

func configure(config: GameConfig, model: ProgressionModel, dog: Caramelo, points: Dictionary) -> void:
	if config == null or not config.is_valid:
		push_error("ExerciseSystem: configuracao ausente ou invalida.")
		return
	if model == null:
		push_error("ExerciseSystem: modelo de progressao ausente.")
		return
	if dog == null:
		push_error("ExerciseSystem: referencia de Caramelo ausente.")
		return
	_config = config
	_model = model
	_dog = dog
	_points = points.duplicate()
	if not _dog.activity_started.is_connected(_on_activity_started):
		_dog.activity_started.connect(_on_activity_started)
	if not _dog.activity_completed.is_connected(_on_activity_completed):
		_dog.activity_completed.connect(_on_activity_completed)


## Liga um hotspot de equipamento ao sistema. Chamado uma unica vez, na inicializacao.
func attach_hotspot(hotspot: Node) -> void:
	if hotspot == null or not hotspot.has_signal("selected"):
		push_error("ExerciseSystem: hotspot ausente ou sem o sinal 'selected'.")
		return
	if not hotspot.is_connected("selected", _on_hotspot_selected):
		hotspot.connect("selected", _on_hotspot_selected)
	if hotspot.has_signal("hover_changed") and not hotspot.is_connected("hover_changed", _on_hotspot_hover):
		hotspot.connect("hover_changed", _on_hotspot_hover)


func is_configured() -> bool:
	return _config != null and _model != null and _dog != null


## Fixa a semente do sorteio da reacao comica, tornando-o reproduzivel nos testes. Sem
## esta chamada o gerador e aleatorizado na abertura.
func set_random_seed(value: int) -> void:
	_rng.seed = value
	_seed_is_fixed = true


# --------------------------------------------------------------------------------------
# Consultas
# --------------------------------------------------------------------------------------

func get_exercises() -> Array[Dictionary]:
	if _config == null:
		return []
	return _config.get_exercises()


func get_exercise(exercise_id: StringName) -> Dictionary:
	if _config == null:
		return {}
	return _config.get_exercise(exercise_id)


## Marcador do exercicio, ja no espaco de coordenadas de Caramelo; `null` se nao existir.
func get_exercise_point(exercise_id: StringName) -> Variant:
	var exercise := get_exercise(exercise_id)
	if exercise.is_empty():
		return null
	return _points.get(StringName(exercise["training_point"]))


## Desbloqueado pelo nivel atual. Independe de energia e de Caramelo estar ocupado.
func is_unlocked(exercise_id: StringName) -> bool:
	if _model == null:
		return false
	return _model.is_exercise_unlocked(exercise_id)


## Primeiro motivo pelo qual o exercicio nao pode comecar agora, ou -1 se puder.
## E o que o feedback contextual usa para explicar um botao indisponivel.
func get_blocking_reason(exercise_id: StringName) -> int:
	if not is_configured():
		return Rejection.NOT_CONFIGURED
	var exercise := get_exercise(exercise_id)
	if exercise.is_empty():
		return Rejection.UNKNOWN_EXERCISE
	if not is_unlocked(exercise_id):
		return Rejection.LOCKED
	if _model.get_energy() < int(exercise["energy_cost"]):
		return Rejection.INSUFFICIENT_ENERGY
	if has_pending_exercise():
		return Rejection.EXERCISE_PENDING
	if not _dog.is_interruptible():
		return Rejection.DOG_BUSY
	if _dog.has_reserved_activity():
		return Rejection.ACTIVITY_RESERVED
	if get_exercise_point(exercise_id) == null:
		return Rejection.POINT_NOT_FOUND
	return -1


func get_pending_exercise() -> StringName:
	return _pending_exercise


func has_pending_exercise() -> bool:
	return _pending_exercise != &""


func is_running() -> bool:
	return _started


static func rejection_name(reason: int) -> String:
	if reason < 0 or reason >= REJECTION_NAMES.size():
		return "DESCONHECIDO(%d)" % reason
	return REJECTION_NAMES[reason]


# --------------------------------------------------------------------------------------
# Pedido
# --------------------------------------------------------------------------------------

## Pede que Caramelo execute `exercise_id`. Devolve `true` somente quando o pedido e aceito.
##
## Aceitar significa apenas que ele foi mandado ao equipamento: a energia so sai ao chegar
## e a forca so entra ao terminar. Pedidos nunca sao enfileirados.
func request_exercise(exercise_id: StringName) -> bool:
	var blocking := get_blocking_reason(exercise_id)
	if blocking != -1:
		return _reject(exercise_id, blocking)
	var target: Variant = get_exercise_point(exercise_id)

	var exercise := get_exercise(exercise_id)
	_pending_exercise = exercise_id
	_started = false
	_dog.set_training_style(exercise_id)
	# A duracao exibida e exatamente a registrada no dado — nao ha tempo visual proprio.
	_dog.set_activity_duration(Caramelo.State.TRAINING, float(exercise["duration_seconds"]))
	if not _dog.request_activity(Caramelo.State.TRAINING, target as Vector2):
		_pending_exercise = &""
		return _reject(exercise_id, Rejection.DOG_REFUSED)
	exercise_requested.emit(exercise_id)
	return true


func _reject(exercise_id: StringName, reason: int) -> bool:
	exercise_rejected.emit(exercise_id, reason)
	return false


func _on_hotspot_selected(exercise_id: StringName) -> void:
	request_exercise(exercise_id)


func _on_hotspot_hover(exercise_id: StringName, hovered: bool) -> void:
	hotspot_hovered.emit(exercise_id, hovered)


# --------------------------------------------------------------------------------------
# Inicio: o custo sai aqui
# --------------------------------------------------------------------------------------

func _on_activity_started(activity: int) -> void:
	if activity != Caramelo.State.TRAINING:
		return
	if not has_pending_exercise() or _started:
		return
	var exercise := _config.get_exercise(_pending_exercise)
	if exercise.is_empty():
		push_warning("ExerciseSystem: exercicio pendente '%s' sumiu da configuracao." % _pending_exercise)
		_abort(_pending_exercise, Rejection.UNKNOWN_EXERCISE)
		return
	var cost := int(exercise["energy_cost"])
	if not _model.try_spend_energy(cost):
		# Nao deveria acontecer: a energia foi conferida no pedido e nada mais a consome.
		# Ainda assim, treino nenhum sai de graca — a reserva e desfeita e a forca nao vem.
		_abort(_pending_exercise, Rejection.ENERGY_DEBIT_FAILED)
		return
	_started = true
	exercise_started.emit(_pending_exercise, cost)


## Desfaz a reserva sem conceder nada e devolve Caramelo a um estado permitido.
func _abort(exercise_id: StringName, reason: int) -> void:
	_pending_exercise = &""
	_started = false
	_dog.cancel_reserved_activity()
	exercise_rejected.emit(exercise_id, reason)


# --------------------------------------------------------------------------------------
# Conclusao: a forca entra aqui
# --------------------------------------------------------------------------------------

func _on_activity_completed(activity: int) -> void:
	if activity != Caramelo.State.TRAINING:
		return
	# Sem treino iniciado nao ha o que pagar: conclusoes repetidas, de outra atividade ou
	# de um treino ja quitado caem aqui e sao ignoradas.
	if not has_pending_exercise() or not _started:
		return
	var exercise_id := _pending_exercise
	var exercise := _config.get_exercise(exercise_id)
	if exercise.is_empty():
		push_warning("ExerciseSystem: exercicio '%s' sumiu da configuracao." % exercise_id)
		_pending_exercise = &""
		_started = false
		return

	var gain := int(exercise["strength_gain"])
	_pending_exercise = &""
	_started = false
	_model.add_strength(gain)
	exercise_completed.emit(exercise_id, gain)

	# O sorteio acontece **depois** de a forca ja estar creditada, como exige a decisao
	# D-5 do `MVP_SPEC.md`: nenhum resultado de sorteio pode influenciar a recompensa.
	if _rng.randf() < float(exercise["comic_reaction_chance"]):
		_dog.play_comic_reaction()
		comic_reaction_triggered.emit(exercise_id)
