class_name RestSystem
extends Node
## Recuperacao de energia pelo descanso e tendencia de descanso autonomo.
##
## A energia so sobe enquanto Caramelo esta **efetivamente** em `RESTING`: caminhar ate a
## cadeira nao conta, nem `IDLE`, nem nenhum outro estado. O tempo e acumulado numa fracao
## e vira energia em unidades inteiras, de modo que varios descansos curtos somam — 30 s
## mais 20 s mais 10 s valem exatamente +1.
##
## Como os outros sistemas, ele nao conhece alimentacao nem treino: a disputa por Caramelo
## e resolvida pela reserva unica mantida no proprio controlador.
##
## Nada e gravado em disco e nada acontece com o aplicativo fechado. O progresso offline e
## da Etapa 10; o acumulador fracionario vive apenas nesta execucao.

## Codigos estaveis de recusa. Quem exibe traduz; o sistema nunca devolve frase livre.
enum Rejection {
	NOT_CONFIGURED,    ## dependencias ainda nao entregues
	POINT_NOT_FOUND,   ## `RestPoint` ausente da cena
	DOG_BUSY,          ## Caramelo em estado nao interrompivel (`EATING` ou `TRAINING`)
	ACTIVITY_RESERVED, ## Caramelo ja tem outra atividade reservada (refeicao ou treino)
	DOG_REFUSED,       ## Caramelo recusou o pedido por outro motivo
}

const REJECTION_NAMES: Array = [
	"NOT_CONFIGURED", "POINT_NOT_FOUND", "DOG_BUSY", "ACTIVITY_RESERVED", "DOG_REFUSED",
]

const SECONDS_PER_MINUTE := 60.0

## Pedido de descanso aceito. Descanso autonomo **nao** emite este sinal.
signal rest_requested()
signal rest_rejected(reason: int)
## Caramelo entrou em `RESTING`, por pedido ou por conta propria.
signal rest_started()
## Energia efetivamente creditada pelo descanso; so sai quando o valor realmente sobe.
signal rest_energy_restored(amount: int)
## Caramelo saiu de `RESTING`.
signal rest_completed()

var _config: GameConfig
var _model: ProgressionModel
var _dog: Caramelo
var _rest_point: Variant = null

var _rest: Dictionary = {}
## Segundos de descanso ainda nao convertidos em energia. Sobrevive entre descansos
## durante a mesma execucao, para que sessoes curtas somem.
var _accumulated := 0.0
var _resting := false


func _process(delta: float) -> void:
	simulate(delta)


# --------------------------------------------------------------------------------------
# Configuracao
# --------------------------------------------------------------------------------------

func configure(config: GameConfig, model: ProgressionModel, dog: Caramelo, rest_point: Variant) -> void:
	if config == null or not config.is_valid:
		push_error("RestSystem: configuracao ausente ou invalida.")
		return
	if model == null:
		push_error("RestSystem: modelo de progressao ausente.")
		return
	if dog == null:
		push_error("RestSystem: referencia de Caramelo ausente.")
		return
	_config = config
	_model = model
	_dog = dog
	_rest_point = rest_point if rest_point is Vector2 else null
	_rest = config.get_rest()
	if _rest.is_empty():
		push_error("RestSystem: secao 'rest' ausente da configuracao.")
		return
	if _rest_point == null:
		push_error("RestSystem: RestPoint nao encontrado na cena.")
	if not _dog.state_changed.is_connected(_on_state_changed):
		_dog.state_changed.connect(_on_state_changed)
	if not _model.energy_changed.is_connected(_on_energy_changed):
		_model.energy_changed.connect(_on_energy_changed)
	_resting = _dog.get_current_state() == Caramelo.State.RESTING
	_update_rest_tendency()


func is_configured() -> bool:
	return _config != null and _model != null and _dog != null and not _rest.is_empty()


# --------------------------------------------------------------------------------------
# Consultas
# --------------------------------------------------------------------------------------

## Segundos necessarios para cada ponto de energia, derivados de `energy_per_minute`.
func get_seconds_per_energy() -> float:
	if _rest.is_empty():
		return 0.0
	return SECONDS_PER_MINUTE / float(_rest["energy_per_minute"])


func get_energy_per_minute() -> float:
	return float(_rest.get("energy_per_minute", 0.0))


func get_low_energy_threshold() -> int:
	return int(_rest.get("low_energy_threshold", 0))


func get_preferred_recovery_target() -> int:
	return int(_rest.get("preferred_recovery_target", 0))


## Fracao de segundo ja acumulada e ainda nao convertida em energia. Serve ao feedback
## futuro — uma barra de progresso do descanso, por exemplo.
func get_accumulated_seconds() -> float:
	return _accumulated


func is_resting() -> bool:
	return _resting


## Tendencia atual de descanso autonomo, de 0 a 1. Ver `_weight_for_energy`.
func get_rest_tendency() -> float:
	return _weight_for_energy(_model.get_energy() if _model != null else 0)


static func rejection_name(reason: int) -> String:
	if reason < 0 or reason >= REJECTION_NAMES.size():
		return "DESCONHECIDO(%d)" % reason
	return REJECTION_NAMES[reason]


# --------------------------------------------------------------------------------------
# Pedido
# --------------------------------------------------------------------------------------

## Manda Caramelo descansar na cadeira. Devolve `true` somente quando o pedido e aceito.
##
## Aceitar significa que ele foi mandado ao `RestPoint`: a recuperacao so comeca quando ele
## chega e entra em `RESTING`. Pedidos nunca sao enfileirados.
func request_rest() -> bool:
	if not is_configured():
		return _reject(Rejection.NOT_CONFIGURED)
	if _rest_point == null:
		return _reject(Rejection.POINT_NOT_FOUND)
	if not _dog.is_interruptible():
		return _reject(Rejection.DOG_BUSY)
	# A reserva mantida em Caramelo e a fonte unica da disputa: refeicao ou treino em
	# andamento aparecem aqui sem que este sistema conheca os outros.
	if _dog.has_reserved_activity():
		return _reject(Rejection.ACTIVITY_RESERVED)
	if not _dog.request_activity(Caramelo.State.RESTING, _rest_point as Vector2):
		return _reject(Rejection.DOG_REFUSED)
	rest_requested.emit()
	return true


func _reject(reason: int) -> bool:
	rest_rejected.emit(reason)
	return false


# --------------------------------------------------------------------------------------
# Recuperacao
# --------------------------------------------------------------------------------------

func _on_state_changed(_previous: int, new_state: int) -> void:
	var resting_now := new_state == Caramelo.State.RESTING
	if resting_now == _resting:
		return
	_resting = resting_now
	if resting_now:
		rest_started.emit()
	else:
		rest_completed.emit()


func _on_energy_changed(_previous: int, _new_value: int) -> void:
	_update_rest_tendency()


## Avanca a recuperacao em `delta` segundos.
##
## O motor chama isto por `_process`. E publico porque os testes precisam simular minutos
## de descanso instantaneamente, sem depender de tempo real.
func simulate(delta: float) -> void:
	if delta <= 0.0 or not is_configured():
		return
	if _dog.get_current_state() != Caramelo.State.RESTING:
		return
	if _model.get_energy() >= _model.get_max_energy():
		# Saturado: o tempo passa sem virar credito guardado para depois.
		_accumulated = 0.0
		return
	var seconds_per_energy := get_seconds_per_energy()
	if seconds_per_energy <= 0.0:
		return
	_accumulated += delta
	var units := int(floor(_accumulated / seconds_per_energy))
	if units <= 0:
		return
	_accumulated -= float(units) * seconds_per_energy
	var applied := _model.restore_energy(units)
	if applied < units:
		# Encheu no meio do intervalo: o excedente daquele periodo e descartado.
		_accumulated = 0.0
	if applied > 0:
		rest_energy_restored.emit(applied)


# --------------------------------------------------------------------------------------
# Tendencia de descanso autonomo
# --------------------------------------------------------------------------------------

## Peso do descanso no proximo sorteio autonomo de Caramelo, de 0 a 1.
##
## Tres faixas, interpoladas linearmente entre os pesos de `data/levels.json`:
##
##   energia >= alvo (50)        -> peso "rested"    (0,28): descanso ocasional
##   limiar (30) <= e < alvo     -> de "rested" a "low" (0,60), crescendo conforme cai
##   energia < limiar (30)       -> de "low" a "critical" (0,90), ate a energia zerar
##
## O peso e so a chance do sorteio: Caramelo continua alternando, porque logo apos um
## descanso o proximo passo e sempre caminhar. E o que faz energia baixa aumentar a
## tendencia sem congelar o personagem.
func _weight_for_energy(energy: int) -> float:
	if _rest.is_empty():
		return Caramelo.DEFAULT_REST_TENDENCY
	var low := float(_rest["low_energy_threshold"])
	var target := float(_rest["preferred_recovery_target"])
	var rested := float(_rest["autonomous_weight_rested"])
	var low_weight := float(_rest["autonomous_weight_low"])
	var critical := float(_rest["autonomous_weight_critical"])
	var value := float(energy)
	if value >= target:
		return rested
	if value >= low:
		return lerpf(rested, low_weight, (target - value) / maxf(target - low, 0.001))
	return lerpf(low_weight, critical, (low - value) / maxf(low, 0.001))


func _update_rest_tendency() -> void:
	if _dog == null or _model == null:
		return
	_dog.set_rest_tendency(_weight_for_energy(_model.get_energy()))
