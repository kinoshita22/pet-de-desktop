class_name Caramelo
extends CharacterBody2D
## Controlador de Caramelo: maquina de estados explicita e movimento autonomo.
##
## Esta etapa entrega presenca e comportamento, nao jogabilidade. Nao existem aqui
## `energy`, `strength`, `bond` nem `level`: os estados `EATING`, `TRAINING` e `HAPPY`
## rodam apenas o comportamento visual e terminam sozinhos, sem conceder recompensa.
##
## A matriz de transicoes reproduz literalmente a secao 10 do `MVP_SPEC.md`. Transicoes
## fora dela sao rejeitadas, nunca tratadas como caso especial silencioso.

## Emitido uma unica vez por transicao aceita. Os valores sao membros de `State`.
## Transicoes rejeitadas nao emitem nada.
signal state_changed(previous_state: int, new_state: int)

## Emitido quando uma atividade termina **naturalmente**, ao esgotar a propria duracao.
##
## Nao e emitido ao entrar no estado, nem por transicao recusada, nem quando o estado muda
## por comando. Nao transporta recompensa alguma: Caramelo nao sabe o que a atividade
## vale — quem paga e o sistema dono dela.
signal activity_completed(activity: int)

## Emitido quando Caramelo entra **de fato** numa atividade — ja no ponto, nao durante a
## caminhada. Sai exatamente uma vez por atividade, sempre antes da conclusao, e nunca
## para um pedido recusado. E o gancho por onde um sistema cobra o custo da atividade.
signal activity_started(activity: int)

## Emitido a cada troca de microcomportamento ocioso, inclusive ao entrar e sair de
## `IDLE` (com `IdleBehavior.NONE` de um dos lados). E informativo: nao altera atributo,
## nao reserva atividade e nao deve mover jogabilidade alguma.
signal idle_behavior_changed(previous_behavior: int, new_behavior: int)

## Emitido quando o jogador clica em Caramelo. O controlador **nao conhece a interface**:
## ele so avisa que foi selecionado, e quem escuta decide o que fazer. Selecionar nunca
## interrompe atividade nem altera estado.
signal selected()

## Emitido quando a geometria do corpo realmente troca. Restaurar um save que ja estava
## na forma correta **nao** emite: nada evoluiu ali.
signal body_form_changed(previous_form: int, new_form: int)

enum State { IDLE, WALKING, EATING, TRAINING, RESTING, HAPPY }

## Estados que `request_activity` aceita e que, ao terminar sozinhos, emitem
## `activity_completed`. `HAPPY` fica de fora: e reacao, nao atividade pedida.
const ACTIVITIES: Array = [State.EATING, State.TRAINING, State.RESTING]

## Matriz de transicoes do `MVP_SPEC.md` secao 10. Qualquer par fora dela e invalido.
const TRANSITIONS: Dictionary = {
	State.IDLE: [State.WALKING, State.EATING, State.TRAINING, State.RESTING, State.HAPPY],
	State.WALKING: [State.IDLE, State.EATING, State.TRAINING, State.RESTING],
	State.EATING: [State.HAPPY, State.IDLE],
	State.TRAINING: [State.HAPPY, State.RESTING],
	State.RESTING: [State.IDLE, State.EATING, State.TRAINING],
	State.HAPPY: [State.IDLE, State.RESTING],
}

## `EATING` e `TRAINING` nao sao interrompiveis (MVP_SPEC secao 10). Comandos recebidos
## durante eles sao descartados, e nunca enfileirados.
const UNINTERRUPTIBLE: Array = [State.EATING, State.TRAINING]

const STATE_NAMES: Array = ["IDLE", "WALKING", "EATING", "TRAINING", "RESTING", "HAPPY"]

## Microcomportamentos visuais de `IDLE`. **Nao sao estados publicos**: nao entram na
## matriz de transicoes, nao mudam atributo e nao reservam atividade. Cobrem quatro dos
## cinco comportamentos autonomos do `MVP_SPEC.md` secao 9 — o quinto, caminhar ate um
## ponto aleatorio, ja e o estado `WALKING`.
enum IdleBehavior { NONE = -1, LOOK_AROUND = 0, STRETCH = 1, SNIFF_GROUND = 2, TAIL_WAG = 3, CHASE_FLY = 4 }

const IDLE_BEHAVIOR_NAMES: Array = [
	"LOOK_AROUND", "STRETCH", "SNIFF_GROUND", "TAIL_WAG", "CHASE_FLY",
]

## Cada microcomportamento dura pouco, para que varios apareçam numa mesma ociosidade,
## sem virar agitacao — o `MVP_SPEC.md` secao 9 pede um cenario calmo.
const IDLE_BEHAVIOR_DURATION := Vector2(1.2, 2.6)

## Duracoes de reserva, em segundos. Valem apenas quando ninguem informa a duracao da
## atividade por `set_activity_duration` — por exemplo ao chamar `request_state` direto.
## Comer e a reacao feliz seguem a suposicao S-4 do `MVP_SPEC.md`. A duracao real de cada
## exercicio vem de `data/exercises.json`, entregue pelo sistema de exercicios.
const EATING_DURATION := 4.0
const TRAINING_DURATION := 6.0
const HAPPY_DURATION := 2.0
const IDLE_DURATION := Vector2(2.5, 6.0)
const REST_DURATION := Vector2(7.0, 14.0)
## Peso de reserva do descanso autonomo, usado enquanto ninguem informar a tendencia por
## `set_rest_tendency`. Quem calcula a tendencia real e o sistema de descanso, a partir
## da energia — Caramelo nao conhece atributo algum.
const DEFAULT_REST_TENDENCY := 0.28

const WALK_SPEED := 130.0
## Distancia minima da borda do poligono. Mantem as patas — e a origem do no — dentro
## da area caminhavel com folga para a largura do corpo.
const BODY_MARGIN := 26.0
const ARRIVAL_TOLERANCE := 4.0
const MIN_WALK_DISTANCE := 160.0
const PATH_SAMPLE_STEP := 24.0
const MAX_DESTINATION_ATTEMPTS := 24
const HUB_GRID := Vector2i(48, 24)

## Acelera as duracoes das atividades, como exige a secao 20 do `MVP_SPEC.md`
## ("Testabilidade"). Vale 1.0 no jogo entregue.
@export_range(0.1, 100.0, 0.1) var development_time_scale: float = 1.0

var _state: int = State.IDLE
var _state_elapsed := 0.0
var _state_duration := 0.0
var _decision_elapsed := 0.0
var _decision_duration := 0.0
var _idle_behavior: int = IdleBehavior.NONE
## Ultimo microcomportamento realmente escolhido. Diferente de `_idle_behavior`, ele
## sobrevive a saida de `IDLE`, para que a regra de nao repetir valha tambem entre duas
## ociosidades separadas por uma caminhada.
var _last_idle_behavior: int = IdleBehavior.NONE
var _idle_behavior_elapsed := 0.0
var _idle_behavior_duration := 0.0
## Probabilidade de o proximo sorteio autonomo escolher descansar. Chega pronta de fora.
var _rest_tendency := DEFAULT_REST_TENDENCY

var _waypoints: PackedVector2Array = PackedVector2Array()
var _pending_activity: int = -1
## Atividade reservada por um sistema, de `WALKING` ate a conclusao. E a **fonte unica de
## verdade** da disputa entre alimentacao e treino: os dois sistemas consultam isto em vez
## de conhecerem um ao outro. Vale -1 quando Caramelo esta livre.
var _reserved_activity: int = -1
## Estilo visual do treino em curso. Caramelo so conhece o nome do estilo — nunca custo,
## duracao ou recompensa.
var _training_style: StringName = &""
## Duracao informada por quem pediu a atividade, por estado. Caramelo nao conhece custo
## nem recompensa — apenas por quanto tempo executar a pose.
var _activity_durations: Dictionary = {}
var _facing := 1
## Impede dois descansos seguidos, seguindo o principio da secao 9 do `MVP_SPEC.md`
## de nao repetir o mesmo comportamento autonomo duas vezes em sequencia.
var _rested_last := false
## Marca que a sessao ja recolocou Caramelo numa atividade retomada de um save. Como
## `_ready` de Caramelo roda **depois** do `_ready` da sessao (ele esta mais fundo na
## arvore), sem isto a inicializacao padrao zeraria a duracao da atividade restaurada.
var _restored := false
## Forma corporal em uso. Derivada do nivel por quem manda aplicar; nunca persistida.
var _body_form: int = BodyForms.Form.INITIAL

var _walkable: PackedVector2Array = PackedVector2Array()
var _bounds := Rect2()
var _hub := Vector2.ZERO
var _points: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _seed_is_fixed := false

@onready var _visual: Node = $Visual
@onready var _selection_area: Area2D = $SelectionArea
@onready var _selection_shape: CollisionShape2D = $SelectionArea/CollisionShape2D


func _ready() -> void:
	if not _seed_is_fixed:
		_rng.randomize()
	# A captacao de clique em 2D depende disto; o padrao varia conforme o viewport.
	get_viewport().physics_object_picking = true
	_selection_area.input_event.connect(_on_selection_input)
	# A area clicavel espelha conforme a direcao, que pode ter vindo de um save.
	_selection_shape.position.x = absf(_selection_shape.position.x) * -signf(float(_facing))
	if _restored:
		# Estado ja veio de um save: so falta o visual, que ainda nao existia.
		if _visual != null and _visual.has_method("play_state"):
			_visual.call("play_state", _state)
		return
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	simulate(delta)


# --------------------------------------------------------------------------------------
# API publica
# --------------------------------------------------------------------------------------

## Pede uma transicao direta. Devolve `true` somente quando a transicao acontece.
##
## Rejeita, sem emitir sinal: estado inexistente, estado atual nao interrompivel
## (`EATING` e `TRAINING`, cujos comandos sao descartados e nao enfileirados), par
## ausente da matriz, e reentrada no estado atual — que e ignorada em vez de reiniciar
## o estado.
func request_state(new_state: int) -> bool:
	if not _is_known_state(new_state):
		return false
	if new_state == _state:
		return false
	if not is_interruptible():
		return false
	if not _transition_allowed(_state, new_state):
		return false
	return _change_state(new_state)


## Pede uma atividade com ponto proprio no quintal (`EATING`, `TRAINING` ou `RESTING`).
##
## O `MVP_SPEC.md` separa o deslocamento da atividade: Caramelo entra em `WALKING` ate o
## ponto e so ao chegar entra na atividade. Se ja estiver no ponto, entra direto.
## Devolve `true` quando o comando e aceito, ainda que o estado resultante seja `WALKING`.
func request_activity(activity: int, target_override := Vector2.INF) -> bool:
	if not ACTIVITIES.has(activity):
		return false
	if not is_interruptible():
		return false
	# Uma caminhada dirigida a uma atividade nao pode ser substituida por outra: quem
	# reservou primeiro fica com o destino. Caminhada autonoma nao reserva nada e por isso
	# pode ser trocada livremente.
	if has_reserved_activity():
		return false
	var target: Vector2
	if target_override.is_finite():
		target = target_override
	elif _points.has(activity):
		target = _points[activity]
	else:
		return false
	var at_target := position.distance_to(target) <= ARRIVAL_TOLERANCE
	var next_state := activity if at_target else State.WALKING
	# A matriz nao liga `RESTING` nem `HAPPY` a `WALKING`, nem `HAPPY` a `EATING`. Nesses
	# casos Caramelo primeiro se levanta ou se acalma (-> `IDLE`) e so entao segue. Toda
	# aresta percorrida continua sendo valida — e o que permite pedir uma refeicao logo
	# depois de outra, enquanto ele ainda comemora.
	if _state != next_state and not _transition_allowed(_state, next_state):
		if not _transition_allowed(_state, State.IDLE):
			return false
		_change_state(State.IDLE)
	_reserved_activity = activity
	if at_target:
		if request_state(activity):
			return true
		_reserved_activity = -1
		return false
	var route := _route_to(target)
	if route.is_empty():
		_reserved_activity = -1
		return false
	_waypoints = route
	_pending_activity = activity
	# Ja caminhando (caminhada autonoma): basta trocar o destino, sem nova transicao.
	if _state == State.WALKING:
		return true
	if _change_state(State.WALKING):
		return true
	_reserved_activity = -1
	return false


func get_current_state() -> int:
	return _state


## Destino final do trajeto em curso; a propria posicao quando Caramelo nao caminha.
func get_destination() -> Vector2:
	if _waypoints.is_empty():
		return position
	return _waypoints[_waypoints.size() - 1]


func is_interruptible() -> bool:
	return not UNINTERRUPTIBLE.has(_state)


## Atividade reservada no momento, ou -1. Enquanto houver reserva, nenhuma outra atividade
## pode tomar o lugar dela.
func get_reserved_activity() -> int:
	return _reserved_activity


## Segundos que faltam para o estado atual terminar sozinho; zero quando ele nao tem
## duracao propria (`IDLE` e `WALKING`).
func get_state_remaining() -> float:
	if _state_duration <= 0.0:
		return 0.0
	return maxf(_state_duration - _state_elapsed, 0.0)


func get_facing() -> int:
	return _facing


func has_reserved_activity() -> bool:
	return _reserved_activity != -1


## Cancela a reserva e tira Caramelo da atividade, por uma aresta valida da matriz.
##
## Existe so para o sistema que reservou desfazer o proprio pedido quando nao consegue
## prosseguir — por exemplo, se o debito de energia falhar. **Nao e um comando do jogador**:
## `request_state` continua recusando qualquer coisa durante `EATING` e `TRAINING`.
## Nao emite `activity_completed`, porque a atividade nao foi concluida.
func cancel_reserved_activity() -> bool:
	if _reserved_activity == -1:
		return false
	_reserved_activity = -1
	_pending_activity = -1
	_waypoints = PackedVector2Array()
	match _state:
		State.TRAINING:
			_change_state(State.RESTING)
		State.EATING, State.WALKING:
			_change_state(State.IDLE)
	return true


## Duracao da proxima execucao de `activity`, em segundos, vinda dos dados de quem a
## pediu. Sem isto, valem as constantes de reserva acima.
func set_activity_duration(activity: int, seconds: float) -> void:
	if seconds > 0.0:
		_activity_durations[activity] = seconds
	else:
		_activity_durations.erase(activity)


## Tendencia de descanso autonomo, de 0 a 1: com que probabilidade o proximo sorteio
## escolhe descansar em vez de caminhar. Quem calcula e o sistema de descanso, a partir da
## energia; Caramelo so recebe o numero pronto e nunca consulta o modelo.
func set_rest_tendency(weight: float) -> void:
	_rest_tendency = clampf(weight, 0.0, 1.0)


func get_rest_tendency() -> float:
	return _rest_tendency


## Microcomportamento ocioso em execucao, ou `IdleBehavior.NONE` fora de `IDLE`.
func get_idle_behavior() -> int:
	return _idle_behavior


static func idle_behavior_name(behavior: int) -> String:
	if behavior < 0 or behavior >= IDLE_BEHAVIOR_NAMES.size():
		return "NONE"
	return IDLE_BEHAVIOR_NAMES[behavior]


## Estilo do treino em curso, para quem precise descrever a atividade.
func get_training_style() -> StringName:
	return _training_style


## Recoloca Caramelo numa posicao e direcao vindas de um save, sem transicao de estado.
## A posicao e recusada se cair fora da area caminhavel — o poligono nunca e afrouxado
## para aceitar um save ruim.
func restore_placement(target: Vector2, facing: int) -> bool:
	if not target.is_finite():
		return false
	_set_facing(1 if facing >= 0 else -1)
	if _walkable.size() >= 3 and not _is_position_valid(target):
		return false
	position = target
	return true


## Recoloca Caramelo dentro de uma atividade ja em andamento, com o tempo que falta.
##
## Nao emite `activity_started`: a atividade nao esta comecando agora, ela continua de
## onde parou — emitir de novo faria o sistema cobrar a energia uma segunda vez. So
## `state_changed` sai, para que visual e HUD se sincronizem.
func restore_activity(activity: int, remaining_seconds: float, at_position: Vector2) -> bool:
	if not ACTIVITIES.has(activity) or remaining_seconds <= 0.0:
		return false
	if at_position.is_finite():
		position = at_position
	var previous := _state
	_waypoints = PackedVector2Array()
	_pending_activity = -1
	_reserved_activity = activity
	_state = activity
	_state_elapsed = 0.0
	_state_duration = remaining_seconds
	_restored = true
	velocity = Vector2.ZERO
	if _visual != null and _visual.has_method("play_state"):
		_visual.call("play_state", activity)
	if previous != activity:
		state_changed.emit(previous, activity)
	return true


## Troca a forma do corpo e ajusta colisao e area clicavel junto.
##
## `animate = false` aplica na hora, sem transformacao — e o que a restauracao de um save
## usa. A **posicao logica nao muda**: so a geometria desenhada e as caixas.
func apply_body_form(form: int, animate: bool = true) -> bool:
	if form == _body_form and not animate:
		return false
	var previous := _body_form
	_body_form = form
	var geometry := BodyForms.geometry(form)
	if _visual != null and _visual.has_method("set_body_form"):
		_visual.call("set_body_form", form, animate)
	var collision: Dictionary = geometry["_collision"]
	# As caixas sao buscadas por caminho, e nao pelas referencias `@onready`: a restauracao
	# de um save aplica a forma enquanto a sessao inicializa, antes do `_ready` daqui.
	var shape := $CollisionShape2D as CollisionShape2D
	var selection_shape := $SelectionArea/CollisionShape2D as CollisionShape2D
	shape.position = collision["position"]
	var capsule := shape.shape as CapsuleShape2D
	if capsule != null:
		capsule.radius = float(collision["radius"])
		capsule.height = float(collision["height"])
	var selection: Dictionary = geometry["_selection"]
	var rectangle := selection_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = selection["size"]
	var offset: Vector2 = selection["position"]
	selection_shape.position = Vector2(absf(offset.x) * -signf(float(_facing)), offset.y)
	if previous != form:
		body_form_changed.emit(previous, form)
	return previous != form


func get_body_form() -> int:
	return _body_form


## Entrega o gerenciador de desempenho ao no visual, que usa o perfil para decidir com que
## frequencia desenhar. O controlador segue andando por `delta`, sempre.
##
## O no e buscado por caminho: a sessao configura a plataforma durante o proprio `_ready`
## dela, que roda antes do `_ready` daqui — a referencia `@onready` ainda nao existe.
func set_performance_manager(manager: PerformanceManager) -> void:
	var visual := $Visual as Node
	if visual != null and visual.has_method("set_performance_manager"):
		visual.call("set_performance_manager", manager)


## Apresentacao visual curta — comemoracao de nivel, pose final ou reacao afetiva.
## Nao muda estado publico nem atributo algum.
func play_presentation(presentation_id: StringName) -> void:
	if _visual == null:
		return
	if presentation_id.begins_with("level_") and _visual.has_method("play_level_celebration"):
		_visual.call("play_level_celebration", int(String(presentation_id).get_slice("_", 1)))
		return
	if _visual.has_method("play_affection_behavior"):
		_visual.call("play_affection_behavior", presentation_id)


func is_presenting() -> bool:
	if _visual == null:
		return false
	return String(_visual.call("get_presentation")) != "" or bool(_visual.call("is_morphing"))


## Seleciona Caramelo sem passar por evento de entrada. E o caminho que o clique real
## tambem percorre, e o que os testes usam.
func select() -> void:
	selected.emit()


## Estilo visual do proximo treino. Puramente cosmetico.
func set_training_style(style: StringName) -> void:
	_training_style = style
	if _visual != null and _visual.has_method("set_training_style"):
		_visual.call("set_training_style", style)


## Marca a proxima reacao de alegria como comica. Nao altera estado, duracao nem atributo.
func play_comic_reaction() -> void:
	if _visual != null and _visual.has_method("play_comic_reaction"):
		_visual.call("play_comic_reaction")


## Fixa a semente do gerador proprio de Caramelo, tornando as decisoes reproduziveis.
## Tambem resorteia a espera ociosa em curso, para que a sequencia inteira dependa so
## da semente. Sem esta chamada o gerador e aleatorizado na abertura, de modo que o jogo
## entregue nao fica preso a uma unica sequencia.
func set_random_seed(value: int) -> void:
	_rng.seed = value
	_seed_is_fixed = true
	if _state == State.IDLE:
		_reset_idle_timer()
		# O microcomportamento em curso foi sorteado antes da semente; refaze-lo aqui e o
		# que torna toda a sequencia seguinte reproduzivel.
		_last_idle_behavior = IdleBehavior.NONE
		_pick_idle_behavior()


## Recebe do ambiente a area caminhavel, ja no espaco de coordenadas do pai de Caramelo.
## Sem poligono, Caramelo permanece parado em vez de caminhar para fora do piso.
func set_walkable_polygon(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		_walkable = PackedVector2Array()
		push_warning("Caramelo: poligono caminhavel invalido; movimento autonomo desligado.")
		return
	_walkable = polygon
	_bounds = _compute_bounds(polygon)
	_hub = _compute_hub()
	if not _is_position_valid(position):
		push_warning("Caramelo: posicao inicial fora da area caminhavel; reposicionado.")
		position = _hub


## Recebe do ambiente os tres pontos de interacao, no mesmo espaco do poligono.
func set_interaction_points(food_point: Vector2, training_point: Vector2, rest_point: Vector2) -> void:
	_points[State.EATING] = food_point
	_points[State.TRAINING] = training_point
	_points[State.RESTING] = rest_point


## Avanca a simulacao em `delta` segundos.
##
## O motor chama isto a cada quadro de fisica. E publico porque os testes precisam
## simular minutos de jogo em milissegundos, sem depender de tempo real nem de
## `Engine.time_scale`.
func simulate(delta: float) -> void:
	if delta <= 0.0:
		return
	var step := delta * maxf(development_time_scale, 0.0)
	if step <= 0.0:
		return
	_state_elapsed += step
	match _state:
		State.IDLE:
			_idle_behavior_elapsed += step
			if _idle_behavior_elapsed >= _idle_behavior_duration:
				_pick_idle_behavior()
			_decision_elapsed += step
			if _decision_elapsed >= _decision_duration:
				_decide_next_action()
		State.WALKING:
			_advance_along_route(step)
		_:
			if _state_duration > 0.0 and _state_elapsed >= _state_duration:
				var finished := _state
				# So avisa se a transicao de saida realmente aconteceu, e so para as
				# atividades — assim o sinal sai exatamente uma vez por atividade.
				if _change_state(_default_exit_state()) and ACTIVITIES.has(finished):
					activity_completed.emit(finished)


static func state_name(state: int) -> String:
	if state < 0 or state >= STATE_NAMES.size():
		return "DESCONHECIDO(%d)" % state
	return STATE_NAMES[state]


# --------------------------------------------------------------------------------------
# Maquina de estados
# --------------------------------------------------------------------------------------

func _is_known_state(state: int) -> bool:
	return state >= 0 and state < STATE_NAMES.size()


func _transition_allowed(from_state: int, to_state: int) -> bool:
	if not TRANSITIONS.has(from_state):
		return false
	return (TRANSITIONS[from_state] as Array).has(to_state)


func _change_state(new_state: int) -> bool:
	if new_state == _state:
		return false
	if not _transition_allowed(_state, new_state):
		push_warning("Caramelo: transicao invalida %s -> %s rejeitada."
			% [state_name(_state), state_name(new_state)])
		return false
	var previous := _state
	_exit_state(previous)
	_state = new_state
	_enter_state(new_state)
	state_changed.emit(previous, new_state)
	if ACTIVITIES.has(new_state):
		activity_started.emit(new_state)
	return true


func _enter_state(state: int) -> void:
	_state_elapsed = 0.0
	_state_duration = 0.0
	velocity = Vector2.ZERO
	# A reserva vale do inicio da caminhada ate o fim da atividade. Qualquer outro estado
	# significa que o fluxo acabou — inclusive `HAPPY`, ja alcancado quando a conclusao e
	# anunciada, de modo que os sistemas ja veem Caramelo livre.
	if state != State.WALKING and state != _reserved_activity:
		_reserved_activity = -1
	match state:
		State.IDLE:
			_waypoints = PackedVector2Array()
			_pending_activity = -1
			_reset_idle_timer()
			_pick_idle_behavior()
		State.WALKING:
			_rested_last = false
		State.EATING:
			_waypoints = PackedVector2Array()
			_state_duration = float(_activity_durations.get(State.EATING, EATING_DURATION))
		State.TRAINING:
			_waypoints = PackedVector2Array()
			_state_duration = float(_activity_durations.get(State.TRAINING, TRAINING_DURATION))
		State.RESTING:
			_waypoints = PackedVector2Array()
			_pending_activity = -1
			_rested_last = true
			_state_duration = _rng.randf_range(REST_DURATION.x, REST_DURATION.y)
		State.HAPPY:
			_waypoints = PackedVector2Array()
			_state_duration = HAPPY_DURATION
	if _visual != null and _visual.has_method("play_state"):
		_visual.call("play_state", state)


func _exit_state(state: int) -> void:
	if state == State.WALKING:
		velocity = Vector2.ZERO
	if state == State.IDLE:
		# Sair de `IDLE` encerra o microcomportamento — inclusive quando uma atividade
		# aceita interrompe a ociosidade no meio.
		_set_idle_behavior(IdleBehavior.NONE)


## Para onde cada estado com duracao vai sozinho ao terminar. Todos constam da matriz.
func _default_exit_state() -> int:
	match _state:
		State.EATING, State.TRAINING:
			return State.HAPPY
		State.HAPPY, State.RESTING:
			return State.IDLE
	return State.IDLE


func _reset_idle_timer() -> void:
	_decision_elapsed = 0.0
	_decision_duration = _rng.randf_range(IDLE_DURATION.x, IDLE_DURATION.y)


## Escolhe o proximo microcomportamento, nunca repetindo o anterior — a regra de
## variedade da secao 9 do `MVP_SPEC.md`. Usa o gerador proprio de Caramelo, de modo que
## uma semente fixa reproduz a sequencia inteira.
func _pick_idle_behavior() -> void:
	_idle_behavior_elapsed = 0.0
	_idle_behavior_duration = _rng.randf_range(
		IDLE_BEHAVIOR_DURATION.x, IDLE_BEHAVIOR_DURATION.y)
	var count := IDLE_BEHAVIOR_NAMES.size()
	var choice := _rng.randi_range(0, count - 1)
	if choice == _last_idle_behavior:
		# Desloca para um dos outros quatro, mantendo a escolha uniforme entre eles.
		choice = (choice + 1 + _rng.randi_range(0, count - 2)) % count
	_last_idle_behavior = choice
	_set_idle_behavior(choice)


func _set_idle_behavior(behavior: int) -> void:
	if behavior == _idle_behavior:
		return
	var previous := _idle_behavior
	_idle_behavior = behavior
	if _visual != null and _visual.has_method("play_idle_behavior"):
		_visual.call("play_idle_behavior", behavior)
	idle_behavior_changed.emit(previous, behavior)


## Decisao autonoma tomada ao fim de cada espera ociosa. Nunca por quadro: o sorteio
## acontece em pontos discretos, o que evita tremores e trocas de estado frequentes.
func _decide_next_action() -> void:
	# O `or` curto-circuita: logo apos um descanso o sorteio nem acontece, e ele sai para
	# caminhar. E o que impede descansos encadeados sem fim, mesmo com energia no chao.
	if _rested_last or _rng.randf() >= _rest_tendency:
		var destination: Variant = _pick_destination()
		if destination is Vector2 and _start_walk_to(destination):
			return
		_reset_idle_timer()
		return
	_change_state(State.RESTING)


# --------------------------------------------------------------------------------------
# Movimento
# --------------------------------------------------------------------------------------

func _start_walk_to(target: Vector2) -> bool:
	var route := _route_to(target)
	if route.is_empty():
		return false
	_waypoints = route
	_pending_activity = -1
	if _state == State.WALKING:
		return true
	return _change_state(State.WALKING)


## Trajeto ate `target`. Linha reta quando ela cabe inteira na area caminhavel; caso
## contrario, desvio por um unico ponto interno seguro. Nao ha pathfinding: se nenhuma
## das duas rotas serve, o destino e recusado.
func _route_to(target: Vector2) -> PackedVector2Array:
	if not _is_position_valid(target):
		return PackedVector2Array()
	if _is_path_clear(position, target):
		return PackedVector2Array([target])
	if _is_path_clear(position, _hub) and _is_path_clear(_hub, target):
		return PackedVector2Array([_hub, target])
	return PackedVector2Array()


func _advance_along_route(step: float) -> void:
	if _waypoints.is_empty():
		_arrive()
		return
	var remaining := WALK_SPEED * step
	while remaining > 0.0 and not _waypoints.is_empty():
		var target: Vector2 = _waypoints[0]
		var offset := target - position
		var distance := offset.length()
		if distance <= maxf(remaining, ARRIVAL_TOLERANCE):
			# Encaixa exatamente no ponto: sem ultrapassar e sem oscilar em volta dele.
			position = target
			_waypoints.remove_at(0)
			remaining -= distance
			continue
		var direction := offset / distance
		position += direction * remaining
		velocity = direction * WALK_SPEED
		if absf(direction.x) > 0.05:
			_set_facing(1 if direction.x > 0.0 else -1)
		return
	velocity = Vector2.ZERO
	_arrive()


func _arrive() -> void:
	velocity = Vector2.ZERO
	var activity := _pending_activity
	_pending_activity = -1
	if activity != -1 and _transition_allowed(_state, activity):
		_change_state(activity)
		return
	_change_state(State.IDLE)


func _on_selection_input(_viewport: Node, event: InputEvent, _shape: int) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			select()


func _set_facing(direction: int) -> void:
	if direction == _facing:
		return
	_facing = direction
	# A area clicavel espelha junto, para acompanhar o corpo virado.
	if _selection_shape != null:
		_selection_shape.position.x = absf(_selection_shape.position.x) * -signf(float(direction))

	if _visual != null and _visual.has_method("set_facing"):
		_visual.call("set_facing", direction)


func _pick_destination() -> Variant:
	if _walkable.size() < 3:
		return null
	for _attempt in MAX_DESTINATION_ATTEMPTS:
		var candidate := Vector2(
			_rng.randf_range(_bounds.position.x, _bounds.end.x),
			_rng.randf_range(_bounds.position.y, _bounds.end.y))
		if not _is_position_valid(candidate):
			continue
		if candidate.distance_to(position) < MIN_WALK_DISTANCE:
			continue
		if not _is_path_clear(position, candidate):
			continue
		return candidate
	return null


## Um ponto so vale se estiver dentro do poligono real — nao do retangulo envolvente —
## e a pelo menos `BODY_MARGIN` de qualquer aresta.
func _is_position_valid(point: Vector2) -> bool:
	if _walkable.size() < 3:
		return false
	if not Geometry2D.is_point_in_polygon(point, _walkable):
		return false
	return _distance_to_border(point) >= BODY_MARGIN


## Amostra o segmento inteiro. E o que impede atravessar uma reentrancia do poligono:
## os dois extremos podem ser validos e o meio do caminho, nao.
func _is_path_clear(from_point: Vector2, to_point: Vector2) -> bool:
	var length := from_point.distance_to(to_point)
	var steps := maxi(1, int(ceil(length / PATH_SAMPLE_STEP)))
	for i in steps + 1:
		if not _is_position_valid(from_point.lerp(to_point, float(i) / float(steps))):
			return false
	return true


func _distance_to_border(point: Vector2) -> float:
	var closest := INF
	var count := _walkable.size()
	for i in count:
		var a := _walkable[i]
		var b := _walkable[(i + 1) % count]
		closest = minf(closest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)))
	return closest


func _compute_bounds(polygon: PackedVector2Array) -> Rect2:
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		rect = rect.expand(point)
	return rect


## Ponto mais distante da borda, por varredura em grade. Serve de desvio unico quando a
## linha reta ate um destino sai da area. Deterministico: nao consome o gerador.
func _compute_hub() -> Vector2:
	var best := _walkable[0]
	var best_clearance := -1.0
	for i in HUB_GRID.x:
		for j in HUB_GRID.y:
			var candidate := _bounds.position + Vector2(
				_bounds.size.x * (float(i) + 0.5) / float(HUB_GRID.x),
				_bounds.size.y * (float(j) + 0.5) / float(HUB_GRID.y))
			if not Geometry2D.is_point_in_polygon(candidate, _walkable):
				continue
			var clearance := _distance_to_border(candidate)
			if clearance > best_clearance:
				best_clearance = clearance
				best = candidate
	return best
