class_name ProgressionModel
extends RefCounted
## Modelo de atributos e progressao de Caramelo, em memoria.
##
## Nao conhece a cena, a interface nem o controlador do personagem: recebe apenas um
## `GameConfig` e responde a chamadas. Essa separacao e um criterio de aceitacao — o
## modelo tem de poder ser testado sem abrir cena nenhuma.
##
## `level` **nao e armazenado**. Ele e sempre derivado de `strength` pela tabela de
## `levels.json`, de modo que nao existe uma segunda fonte de verdade que possa divergir,
## e nao ha como escreve-lo diretamente.
##
## Esta etapa nao concede recompensa alguma: nada aqui e chamado por estados de Caramelo.

## Ordem fixa dos sinais, valida para toda operacao:
##
##   `add_strength` ->  strength_changed  ->  level_changed  ->  unlock_granted (1..N)
##   `add_bond`     ->  bond_changed      ->  unlock_granted (1..N)
##   `restore_energy` / `try_spend_energy` ->  energy_changed
##
## O atributo muda primeiro; as consequencias derivadas vem depois, do mais geral
## (nivel) para o mais especifico (cada desbloqueio). Os desbloqueios saem em ordem
## crescente de nivel — ou de vinculo exigido — e, dentro do mesmo nivel, na ordem em
## que aparecem no arquivo de dados.
signal energy_changed(previous_value: int, new_value: int)
signal strength_changed(previous_value: int, new_value: int)
signal bond_changed(previous_value: int, new_value: int)
signal level_changed(previous_level: int, new_level: int)
signal unlock_granted(unlock_id: StringName)

var _config: GameConfig
var _energy: int = 0
var _max_energy: int = 0
var _strength: int = 0
var _bond: int = 0


## `config` precisa estar valido. Nao ha construcao com valores padrao: os iniciais vem
## de `levels.json`, porque a secao 14 do `MVP_SPEC.md` proibe balanceamento no codigo.
func _init(config: GameConfig) -> void:
	assert(config != null and config.is_valid,
		"ProgressionModel exige um GameConfig valido.")
	_config = config
	var initial := config.get_initial_attributes()
	_max_energy = int(initial.get("max_energy", 0))
	_energy = int(initial.get("energy", 0))
	_strength = int(initial.get("strength", 0))
	_bond = int(initial.get("bond", 0))


# --------------------------------------------------------------------------------------
# Consultas — nunca emitem sinais
# --------------------------------------------------------------------------------------

func get_energy() -> int:
	return _energy

func get_max_energy() -> int:
	return _max_energy

func get_strength() -> int:
	return _strength

func get_bond() -> int:
	return _bond

## Sempre derivado de `strength`; nunca lido de um campo proprio.
func get_level() -> int:
	return _config.get_level_for_strength(_strength)

func get_config() -> GameConfig:
	return _config

## Copia dos valores atuais. Alterar o dicionario devolvido nao afeta o modelo.
func get_snapshot() -> Dictionary:
	return {
		"energy": _energy,
		"max_energy": _max_energy,
		"strength": _strength,
		"bond": _bond,
		"level": get_level(),
		"unlocks": get_unlocks(),
		"bond_behaviors": get_unlocked_bond_behaviors(),
	}


## Verdadeiro para desbloqueios de nivel ja alcancados e para comportamentos de vinculo
## ja atingidos: os dois compartilham um unico espaco de identificadores, e o carregador
## garante que nao haja colisao entre eles.
func has_unlock(unlock_id: StringName) -> bool:
	return get_unlocks().has(String(unlock_id))


## Todos os desbloqueios de nivel concedidos ate agora, em ordem de nivel.
func get_unlocks() -> PackedStringArray:
	var result := PackedStringArray()
	var level := get_level()
	for entry in _config.get_levels():
		if int(entry["level"]) > level:
			break
		result.append_array(entry["unlocks"] as PackedStringArray)
	for behavior in _config.get_bond_behaviors():
		if _bond >= int(behavior["required_bond"]):
			result.append(String(behavior["id"]))
	return result


## Comportamentos afetivos ja liberados pelo vinculo, em ordem crescente de limiar.
func get_unlocked_bond_behaviors() -> PackedStringArray:
	var result := PackedStringArray()
	for behavior in _config.get_bond_behaviors():
		if _bond >= int(behavior["required_bond"]):
			result.append(String(behavior["id"]))
	return result


## Falso tambem para exercicios inexistentes — nao ha aceite silencioso de identificador
## desconhecido.
func is_exercise_unlocked(exercise_id: StringName) -> bool:
	var exercise := _config.get_exercise(exercise_id)
	if exercise.is_empty():
		return false
	return get_level() >= int(exercise["required_level"])


# --------------------------------------------------------------------------------------
# Operacoes
# --------------------------------------------------------------------------------------

## Gasta energia de forma atomica. Devolve `true` somente quando o gasto acontece.
##
## Recusa, sem alterar nada e sem emitir sinal: `amount` menor ou igual a zero, e saldo
## insuficiente. Nunca gasta parcialmente.
func try_spend_energy(amount: int) -> bool:
	if amount <= 0:
		push_warning("ProgressionModel: gasto de energia invalido (%d); precisa ser positivo." % amount)
		return false
	if _energy < amount:
		return false
	var previous := _energy
	_energy -= amount
	energy_changed.emit(previous, _energy)
	return true


## Recupera energia respeitando o teto. Devolve **quanto foi efetivamente restaurado**,
## que e zero quando a energia ja estava cheia — e, nesse caso, nenhum sinal e emitido.
func restore_energy(amount: int) -> int:
	if amount <= 0:
		push_warning("ProgressionModel: recuperacao de energia invalida (%d); precisa ser positiva." % amount)
		return 0
	var previous := _energy
	_energy = mini(_energy + amount, _max_energy)
	var applied := _energy - previous
	if applied > 0:
		energy_changed.emit(previous, _energy)
	return applied


## Credita forca. Devolve o **novo total** de forca.
##
## Recusa `amount` menor ou igual a zero sem alterar nada e sem emitir sinal. Forca nunca
## diminui. Se a operacao cruzar varios limiares de uma vez, todos os desbloqueios
## intermediarios sao emitidos, em ordem de nivel.
func add_strength(amount: int) -> int:
	if amount <= 0:
		push_warning("ProgressionModel: ganho de forca invalido (%d); precisa ser positivo." % amount)
		return _strength
	var previous_strength := _strength
	var previous_level := get_level()
	_strength += amount
	var new_level := get_level()
	strength_changed.emit(previous_strength, _strength)
	if new_level != previous_level:
		level_changed.emit(previous_level, new_level)
		for level in range(previous_level + 1, new_level + 1):
			for unlock_id in _config.get_unlocks_for_level(level):
				unlock_granted.emit(StringName(unlock_id))
	return _strength


## Credita vinculo. Devolve o **novo total** de vinculo.
##
## Recusa `amount` menor ou igual a zero. Vinculo nunca diminui e nao tem teto no MVP.
## Nao concede bonus numerico algum: so libera comportamentos afetivos.
func add_bond(amount: int) -> int:
	if amount <= 0:
		push_warning("ProgressionModel: ganho de vinculo invalido (%d); precisa ser positivo." % amount)
		return _bond
	var previous_bond := _bond
	_bond += amount
	bond_changed.emit(previous_bond, _bond)
	for behavior in _config.get_bond_behaviors():
		var required := int(behavior["required_bond"])
		if previous_bond < required and _bond >= required:
			unlock_granted.emit(StringName(behavior["id"]))
	return _bond
