class_name FeedingSystem
extends Node
## Ciclo completo de uma refeicao: pedido, caminhada, `EATING`, recompensa e recarga.
##
## E o unico lugar que liga jogador, Caramelo e modelo. Cada parte segue sem conhecer as
## outras:
##
## * Caramelo caminha e come, mas nao sabe **qual** alimento nem quanto ele vale.
## * O modelo recebe `restore_energy` e `add_bond`, mas nao sabe que houve uma refeicao.
## * A interface encaminha a escolha e mostra o resultado, mas nunca toca no modelo.
##
## Nenhum numero de balanceamento vive aqui: energia, vinculo e recarga saem de
## `data/foods.json`, relidos dos dados validados no momento de pagar.
##
## Nada e gravado em disco. Recargas correm so com o aplicativo aberto; persistencia e
## continuacao offline sao da Etapa 10.

## Codigos estaveis de recusa. A interface traduz; o sistema nunca devolve frase livre.
enum Rejection {
	NOT_CONFIGURED,   ## dependencias ainda nao entregues
	UNKNOWN_FOOD,     ## identificador ausente de foods.json
	ON_COOLDOWN,      ## aquele alimento ainda esta em recarga
	MEAL_PENDING,     ## ja existe uma refeicao a caminho
	DOG_BUSY,          ## Caramelo esta em atividade nao interrompivel
	DOG_REFUSED,       ## Caramelo recusou o pedido por outro motivo
	ACTIVITY_RESERVED, ## Caramelo ja tem outra atividade reservada (ex.: um treino)
}

const REJECTION_NAMES: Array = [
	"NOT_CONFIGURED", "UNKNOWN_FOOD", "ON_COOLDOWN", "MEAL_PENDING", "DOG_BUSY", "DOG_REFUSED",
	"ACTIVITY_RESERVED",
]

## Emitido quando o pote e selecionado. A interface escuta isto para abrir o menu; o
## sistema so repassa, para que a interface nao precise procurar nada na arvore do mundo.
signal bowl_selected()

## Pedido aceito. Ainda **nao** houve recompensa nem recarga.
signal feeding_requested(food_id: StringName)
## Pedido recusado. `reason` e um valor de `Rejection`.
signal feeding_rejected(food_id: StringName, reason: int)
## Refeicao concluida. Os valores sao os **efetivamente aplicados**, ja com clamp.
signal feeding_completed(food_id: StringName, energy_applied: int, bond_applied: int)
## Recarga alterada. Emitido ao comecar, a cada segundo inteiro e ao chegar a zero —
## nunca a cada quadro.
signal cooldown_changed(food_id: StringName, remaining_seconds: float)

var _config: GameConfig
var _model: ProgressionModel
var _dog: Caramelo

var _pending_food: StringName = &""
var _cooldowns: Dictionary = {}          # StringName -> segundos restantes
var _signalled_second: Dictionary = {}   # StringName -> ultimo segundo inteiro emitido


func _process(delta: float) -> void:
	simulate(delta)


# --------------------------------------------------------------------------------------
# Configuracao
# --------------------------------------------------------------------------------------

## Recebe as dependencias de quem as resolveu — nesta base, `GameSession`. O sistema nao
## procura nada na arvore por conta propria.
func configure(config: GameConfig, model: ProgressionModel, dog: Caramelo) -> void:
	if config == null or not config.is_valid:
		push_error("FeedingSystem: configuracao ausente ou invalida.")
		return
	if model == null:
		push_error("FeedingSystem: modelo de progressao ausente.")
		return
	if dog == null:
		push_error("FeedingSystem: referencia de Caramelo ausente.")
		return
	_config = config
	_model = model
	_dog = dog
	if not _dog.activity_completed.is_connected(_on_activity_completed):
		_dog.activity_completed.connect(_on_activity_completed)


## Liga o pote ao sistema. Chamado uma unica vez, na inicializacao.
func attach_bowl(bowl: Node) -> void:
	if bowl == null or not bowl.has_signal("selected"):
		push_error("FeedingSystem: pote ausente ou sem o sinal 'selected'.")
		return
	if not bowl.is_connected("selected", _on_bowl_selected):
		bowl.connect("selected", _on_bowl_selected)


func is_configured() -> bool:
	return _config != null and _model != null and _dog != null


# --------------------------------------------------------------------------------------
# Consultas
# --------------------------------------------------------------------------------------

## Alimentos validados, na ordem do arquivo. Vazio enquanto nao houver configuracao.
func get_foods() -> Array[Dictionary]:
	if _config == null:
		return []
	return _config.get_foods()


## Dados validados de um alimento; dicionario vazio quando o identificador nao existe.
func get_food(food_id: StringName) -> Dictionary:
	if _config == null:
		return {}
	return _config.get_food(food_id)


## Segundos que faltam para o alimento voltar; zero quando ja esta disponivel.
func get_remaining_cooldown(food_id: StringName) -> float:
	return maxf(0.0, float(_cooldowns.get(food_id, 0.0)))


func is_available(food_id: StringName) -> bool:
	if _config == null or _config.get_food(food_id).is_empty():
		return false
	return get_remaining_cooldown(food_id) <= 0.0


## Alimento da refeicao a caminho, ou `&""` quando nao ha nenhuma.
func get_pending_food() -> StringName:
	return _pending_food


func has_pending_meal() -> bool:
	return _pending_food != &""


static func rejection_name(reason: int) -> String:
	if reason < 0 or reason >= REJECTION_NAMES.size():
		return "DESCONHECIDO(%d)" % reason
	return REJECTION_NAMES[reason]


# --------------------------------------------------------------------------------------
# Pedido
# --------------------------------------------------------------------------------------

## Pede que Caramelo coma `food_id`. Devolve `true` somente quando o pedido e aceito.
##
## Aceitar significa apenas que Caramelo foi mandado ao pote: energia, vinculo e recarga
## continuam intocados ate a refeicao terminar de verdade. Pedidos nunca sao enfileirados
## — um pedido recusado simplesmente nao acontece.
func request_feeding(food_id: StringName) -> bool:
	if not is_configured():
		return _reject(food_id, Rejection.NOT_CONFIGURED)
	if _config.get_food(food_id).is_empty():
		return _reject(food_id, Rejection.UNKNOWN_FOOD)
	if has_pending_meal():
		return _reject(food_id, Rejection.MEAL_PENDING)
	if get_remaining_cooldown(food_id) > 0.0:
		return _reject(food_id, Rejection.ON_COOLDOWN)
	if not _dog.is_interruptible():
		return _reject(food_id, Rejection.DOG_BUSY)
	# A reserva mantida em Caramelo e a fonte unica da disputa entre atividades: e assim
	# que um treino em andamento bloqueia a alimentacao, sem que os dois sistemas precisem
	# conhecer um ao outro.
	if _dog.has_reserved_activity():
		return _reject(food_id, Rejection.ACTIVITY_RESERVED)

	# Marca a pendencia antes de pedir, para que um sinal de conclusao disparado no mesmo
	# quadro ja encontre a refeicao registrada.
	_pending_food = food_id
	if not _dog.request_activity(Caramelo.State.EATING):
		_pending_food = &""
		return _reject(food_id, Rejection.DOG_REFUSED)
	feeding_requested.emit(food_id)
	return true


func _reject(food_id: StringName, reason: int) -> bool:
	feeding_rejected.emit(food_id, reason)
	return false


func _on_bowl_selected() -> void:
	bowl_selected.emit()


# --------------------------------------------------------------------------------------
# Conclusao e recompensa
# --------------------------------------------------------------------------------------

## So paga quando a conclusao e de `EATING` e existe refeicao pendente. Qualquer outra
## conclusao — treino, descanso, ou um segundo sinal repetido — e ignorada em silencio.
func _on_activity_completed(activity: int) -> void:
	if activity != Caramelo.State.EATING:
		return
	if not has_pending_meal():
		return
	var food_id := _pending_food
	var food := _config.get_food(food_id)
	if food.is_empty():
		push_warning("FeedingSystem: alimento pendente '%s' sumiu da configuracao." % food_id)
		_pending_food = &""
		return

	# Ordem obrigatoria: energia, vinculo (e seus desbloqueios), conclusao, recarga.
	var energy_applied := _model.restore_energy(int(food["energy"]))
	var bond_before := _model.get_bond()
	_model.add_bond(int(food["bond"]))
	var bond_applied := _model.get_bond() - bond_before

	_pending_food = &""
	feeding_completed.emit(food_id, energy_applied, bond_applied)
	_start_cooldown(food_id, float(food["cooldown_seconds"]))


# --------------------------------------------------------------------------------------
# Recargas
# --------------------------------------------------------------------------------------

func _start_cooldown(food_id: StringName, seconds: float) -> void:
	if seconds <= 0.0:
		_cooldowns.erase(food_id)
		_signalled_second.erase(food_id)
		cooldown_changed.emit(food_id, 0.0)
		return
	_cooldowns[food_id] = seconds
	_signalled_second[food_id] = -1
	_emit_cooldown_if_second_changed(food_id)


## Avanca as recargas em `delta` segundos.
##
## O motor chama isto por `_process`. E publico porque os testes precisam adiantar
## minutos de recarga instantaneamente, sem esperar tempo real.
func simulate(delta: float) -> void:
	if delta <= 0.0 or _cooldowns.is_empty():
		return
	for food_id: StringName in _cooldowns.keys():
		var remaining: float = maxf(0.0, float(_cooldowns[food_id]) - delta)
		if is_zero_approx(remaining):
			remaining = 0.0
		_cooldowns[food_id] = remaining
		_emit_cooldown_if_second_changed(food_id)
		if remaining <= 0.0:
			_cooldowns.erase(food_id)
			_signalled_second.erase(food_id)


## Emite so quando o segundo inteiro exibido muda. Sem isso, uma recarga de 300 s geraria
## 18 000 sinais; assim gera 301.
func _emit_cooldown_if_second_changed(food_id: StringName) -> void:
	var remaining := get_remaining_cooldown(food_id)
	var second := ceili(remaining)
	if int(_signalled_second.get(food_id, -1)) == second:
		return
	_signalled_second[food_id] = second
	cooldown_changed.emit(food_id, remaining)
