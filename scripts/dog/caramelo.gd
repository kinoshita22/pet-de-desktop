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

## Duracoes provisorias desta etapa, em segundos. Comer e a reacao feliz seguem a
## suposicao S-4 do `MVP_SPEC.md`; o treino e um marcador temporario, porque a duracao
## real de cada exercicio nasce de `data/exercises.json` na Etapa 5. Nenhum valor aqui
## e balanceamento: nada concede energia, forca, vinculo nem nivel.
const EATING_DURATION := 4.0
const TRAINING_DURATION := 6.0
const HAPPY_DURATION := 2.0
const IDLE_DURATION := Vector2(2.5, 6.0)
const REST_DURATION := Vector2(7.0, 14.0)
const WALK_PROBABILITY := 0.72

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

var _waypoints: PackedVector2Array = PackedVector2Array()
var _pending_activity: int = -1
var _facing := 1
## Impede dois descansos seguidos, seguindo o principio da secao 9 do `MVP_SPEC.md`
## de nao repetir o mesmo comportamento autonomo duas vezes em sequencia.
var _rested_last := false

var _walkable: PackedVector2Array = PackedVector2Array()
var _bounds := Rect2()
var _hub := Vector2.ZERO
var _points: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _seed_is_fixed := false

@onready var _visual: Node = $Visual


func _ready() -> void:
	if not _seed_is_fixed:
		_rng.randomize()
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
func request_activity(activity: int) -> bool:
	if not ACTIVITIES.has(activity):
		return false
	if not _points.has(activity):
		return false
	if not is_interruptible():
		return false
	var target: Vector2 = _points[activity]
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
	if at_target:
		return request_state(activity)
	var route := _route_to(target)
	if route.is_empty():
		return false
	_waypoints = route
	_pending_activity = activity
	if _state == State.WALKING:
		return true
	return _change_state(State.WALKING)


func get_current_state() -> int:
	return _state


## Destino final do trajeto em curso; a propria posicao quando Caramelo nao caminha.
func get_destination() -> Vector2:
	if _waypoints.is_empty():
		return position
	return _waypoints[_waypoints.size() - 1]


func is_interruptible() -> bool:
	return not UNINTERRUPTIBLE.has(_state)


## Fixa a semente do gerador proprio de Caramelo, tornando as decisoes reproduziveis.
## Tambem resorteia a espera ociosa em curso, para que a sequencia inteira dependa so
## da semente. Sem esta chamada o gerador e aleatorizado na abertura, de modo que o jogo
## entregue nao fica preso a uma unica sequencia.
func set_random_seed(value: int) -> void:
	_rng.seed = value
	_seed_is_fixed = true
	if _state == State.IDLE:
		_reset_idle_timer()


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
	return true


func _enter_state(state: int) -> void:
	_state_elapsed = 0.0
	_state_duration = 0.0
	velocity = Vector2.ZERO
	match state:
		State.IDLE:
			_waypoints = PackedVector2Array()
			_pending_activity = -1
			_reset_idle_timer()
		State.WALKING:
			_rested_last = false
		State.EATING:
			_waypoints = PackedVector2Array()
			_state_duration = EATING_DURATION
		State.TRAINING:
			_waypoints = PackedVector2Array()
			_state_duration = TRAINING_DURATION
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


## Decisao autonoma tomada ao fim de cada espera ociosa. Nunca por quadro: o sorteio
## acontece em pontos discretos, o que evita tremores e trocas de estado frequentes.
func _decide_next_action() -> void:
	# O `or` curto-circuita: logo apos um descanso o sorteio nem acontece.
	if _rested_last or _rng.randf() < WALK_PROBABILITY:
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


func _set_facing(direction: int) -> void:
	if direction == _facing:
		return
	_facing = direction
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
