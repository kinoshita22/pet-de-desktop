class_name AffectionSystem
extends Node
## Carinho e comportamentos afetivos.
##
## O `MVP_SPEC.md` secao 11 e explicito: vinculo **nunca** concede bonus de forca, energia
## ou velocidade. Ele so libera comportamentos, nos limiares 10, 25 e 50 vindos dos dados.
##
## O carinho e uma interacao pontual, nao um estado: `IDLE`, `WALKING` autonomo, `RESTING`
## e `HAPPY` o aceitam **sem mudar de estado publico** — a reacao e uma camada visual.
## `EATING` e `TRAINING` recusam, como manda a secao 8.
##
## Este sistema nao toca em forca nem energia, nao conhece geometria e nao grava em disco.

enum Rejection {
	NOT_CONFIGURED,
	ON_COOLDOWN,
	DOG_BUSY,              ## `EATING` ou `TRAINING`
	ACTIVITY_RESERVED,     ## ha refeicao, treino ou descanso dirigido em andamento
	EVOLUTION_IN_PROGRESS, ## transformacao visual rodando
	SESSION_NOT_READY,     ## ainda carregando
	INTERACTION_BLOCKED,   ## resumo offline na tela
}

const REJECTION_NAMES: Array = [
	"NOT_CONFIGURED", "ON_COOLDOWN", "DOG_BUSY", "ACTIVITY_RESERVED",
	"EVOLUTION_IN_PROGRESS", "SESSION_NOT_READY", "INTERACTION_BLOCKED",
]

## Identificadores das reacoes. Os tres ultimos vem de `bond_behaviors` em levels.json.
const SIMPLE_REACTION := &"simple_affection"

signal pet_requested()
signal pet_rejected(reason: int)
signal pet_completed(bond_added: int)
signal pet_cooldown_changed(remaining_seconds: float)
signal affection_behavior_started(behavior_id: StringName)

var _config: GameConfig
var _model: ProgressionModel
var _dog: Caramelo
var _evolution: EvolutionSystem

var _affection: Dictionary = {}
var _cooldown := 0.0
var _signalled_second := -1
var _ready_for_interaction := false
var _blocked := false
var _startup_celebration_done := false
var _last_behavior: StringName = &""
var _rng := RandomNumberGenerator.new()
var _seed_is_fixed := false


func _ready() -> void:
	if not _seed_is_fixed:
		_rng.randomize()


func _process(delta: float) -> void:
	simulate(delta)


# --------------------------------------------------------------------------------------
# Configuracao
# --------------------------------------------------------------------------------------

func configure(config: GameConfig, model: ProgressionModel, dog: Caramelo,
		evolution: EvolutionSystem) -> void:
	if config == null or not config.is_valid or model == null or dog == null:
		push_error("AffectionSystem: dependencias ausentes ou invalidas.")
		return
	_config = config
	_model = model
	_dog = dog
	_evolution = evolution
	_affection = config.get_affection()
	if _affection.is_empty():
		push_error("AffectionSystem: secao 'affection' ausente da configuracao.")


func is_configured() -> bool:
	return _config != null and _model != null and _dog != null and not _affection.is_empty()


## Libera a interacao. Chamado pela sessao depois de `session_ready`.
func set_session_ready(ready_now: bool) -> void:
	_ready_for_interaction = ready_now


## Bloqueia a interacao enquanto o resumo offline estiver na tela.
func set_interaction_blocked(blocked: bool) -> void:
	_blocked = blocked


func set_random_seed(value: int) -> void:
	_rng.seed = value
	_seed_is_fixed = true


# --------------------------------------------------------------------------------------
# Consultas
# --------------------------------------------------------------------------------------

func get_bond_gain() -> int:
	return int(_affection.get("pet_bond_gain", 0))


func get_cooldown_seconds() -> float:
	return float(_affection.get("pet_cooldown_seconds", 0.0))


func get_rare_chance() -> float:
	return float(_affection.get("rare_behavior_chance", 0.0))


func get_cooldown_remaining() -> float:
	return maxf(_cooldown, 0.0)


func is_available() -> bool:
	return get_blocking_reason() == -1


## Primeiro motivo pelo qual o carinho nao pode acontecer agora, ou -1.
func get_blocking_reason() -> int:
	if not is_configured():
		return Rejection.NOT_CONFIGURED
	if not _ready_for_interaction:
		return Rejection.SESSION_NOT_READY
	if _blocked:
		return Rejection.INTERACTION_BLOCKED
	if _cooldown > 0.0:
		return Rejection.ON_COOLDOWN
	if not _dog.is_interruptible():
		return Rejection.DOG_BUSY
	if _dog.has_reserved_activity():
		return Rejection.ACTIVITY_RESERVED
	if _evolution != null and _evolution.is_busy():
		return Rejection.EVOLUTION_IN_PROGRESS
	return -1


## Comportamentos afetivos ja liberados pelo vinculo atual.
func get_unlocked_behaviors() -> PackedStringArray:
	if _model == null:
		return PackedStringArray()
	return _model.get_unlocked_bond_behaviors()


static func rejection_name(reason: int) -> String:
	if reason < 0 or reason >= REJECTION_NAMES.size():
		return "DESCONHECIDO(%d)" % reason
	return REJECTION_NAMES[reason]


# --------------------------------------------------------------------------------------
# Carinho
# --------------------------------------------------------------------------------------

## Faz carinho em Caramelo. Devolve `true` somente quando o vinculo e creditado.
##
## Nunca enfileira: um pedido recusado simplesmente nao acontece. E nunca muda o estado
## publico — Caramelo continua descansando ou passeando enquanto recebe o carinho.
func request_pet() -> bool:
	var blocking := get_blocking_reason()
	if blocking != -1:
		pet_rejected.emit(blocking)
		return false
	pet_requested.emit()
	var gain := get_bond_gain()
	var before := _model.get_bond()
	_model.add_bond(gain)
	var applied := _model.get_bond() - before
	_start_cooldown(get_cooldown_seconds())
	_play_reaction()
	pet_completed.emit(applied)
	return true


## Escolhe a reacao conforme a faixa de vinculo, e sorteia a rara quando liberada.
func _play_reaction() -> void:
	var unlocked := get_unlocked_behaviors()
	var behavior := SIMPLE_REACTION
	if unlocked.has("petting_reaction"):
		behavior = &"petting_reaction"
	if unlocked.has("rare_affection_idle") and _last_behavior != &"rare_affection_idle" \
			and _rng.randf() < get_rare_chance():
		behavior = &"rare_affection_idle"
	_last_behavior = behavior
	if _evolution != null:
		_evolution.enqueue(behavior)
	else:
		_dog.play_presentation(behavior)
	affection_behavior_started.emit(behavior)


## Comemoracao de inicio de sessao, liberada a partir de vinculo 25. Acontece no maximo
## uma vez por sessao e a flag **nao** e persistida: ela e de sessao, nao de progresso.
func try_startup_celebration() -> bool:
	if _startup_celebration_done or not is_configured() or not _ready_for_interaction or _blocked:
		return false
	if not get_unlocked_behaviors().has("startup_celebration"):
		return false
	_startup_celebration_done = true
	if _evolution != null:
		_evolution.enqueue(&"startup_celebration")
	affection_behavior_started.emit(&"startup_celebration")
	return true


func has_played_startup_celebration() -> bool:
	return _startup_celebration_done


# --------------------------------------------------------------------------------------
# Recarga
# --------------------------------------------------------------------------------------

func _start_cooldown(seconds: float) -> void:
	_cooldown = maxf(seconds, 0.0)
	_signalled_second = -1
	_emit_cooldown_if_second_changed()


## Restaura a recarga vinda de um save.
func restore_cooldown(seconds: float) -> void:
	_cooldown = seconds if is_finite(seconds) and seconds > 0.0 else 0.0
	_signalled_second = ceili(_cooldown)


## Avanca a recarga. O motor chama por `_process`; os testes adiantam sem esperar.
func simulate(delta: float) -> void:
	if delta <= 0.0 or _cooldown <= 0.0:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_emit_cooldown_if_second_changed()


## Emite so quando o segundo exibido muda — nunca a cada quadro.
func _emit_cooldown_if_second_changed() -> void:
	var second := ceili(_cooldown)
	if second == _signalled_second:
		return
	_signalled_second = second
	pet_cooldown_changed.emit(_cooldown)
