class_name GameConfig
extends RefCounted
## Carrega e valida os tres arquivos de balanceamento do MVP.
##
## A secao 14 do `MVP_SPEC.md` proibe fixar qualquer numero de balanceamento no codigo:
## custo, duracao, recompensa, limiar, recarga e valores iniciais vem de
## `data/levels.json`, `data/foods.json` e `data/exercises.json`.
##
## A validacao e deliberadamente rigorosa. Um arquivo que existe mas esta errado nunca e
## corrigido em silencio nem substituido por padroes: a configuracao inteira e marcada
## como invalida, `errors` descreve cada problema com arquivo e campo, e os dados
## continuam inacessiveis. Quem consome so enxerga dados depois que tudo passa.
##
## Nao ha download, atualizacao remota nem recarga em tempo de execucao.

const LEVELS_PATH := "res://data/levels.json"
const FOODS_PATH := "res://data/foods.json"
const EXERCISES_PATH := "res://data/exercises.json"

## Contador de diagnostico: quantos arquivos foram efetivamente lidos do disco desde a
## abertura. Os testes usam isto para provar que a configuracao e lida uma unica vez por
## sessao. Nao influencia comportamento algum.
static var file_read_count: int = 0

var is_valid: bool = false
var errors: PackedStringArray = PackedStringArray()

var _max_level: int = 0
var _initial_attributes: Dictionary = {}
var _levels: Array[Dictionary] = []
var _bond_behaviors: Array[Dictionary] = []
var _foods: Array[Dictionary] = []
var _exercises: Array[Dictionary] = []
var _foods_by_id: Dictionary = {}
var _exercises_by_id: Dictionary = {}
var _unlock_level: Dictionary = {}          # unlock_id -> nivel que o concede


# --------------------------------------------------------------------------------------
# Construcao
# --------------------------------------------------------------------------------------

## Le e valida os tres arquivos padrao do projeto.
static func load_default() -> GameConfig:
	return load_from(LEVELS_PATH, FOODS_PATH, EXERCISES_PATH)


## Le e valida tres arquivos quaisquer. Usado pelos testes para exercitar entradas ruins
## sem encostar nos arquivos reais do jogo.
static func load_from(levels_path: String, foods_path: String, exercises_path: String) -> GameConfig:
	var config := GameConfig.new()
	var levels: Variant = config._read_json(levels_path)
	var foods: Variant = config._read_json(foods_path)
	var exercises: Variant = config._read_json(exercises_path)
	if not config.errors.is_empty():
		return config
	config._build(levels, foods, exercises)
	return config


## Valida dicionarios ja em memoria, sem tocar em disco. E o caminho usado pelos testes
## negativos: eles montam a configuracao errada em memoria em vez de corromper os
## arquivos do jogo.
static func from_dictionaries(levels: Variant, foods: Variant, exercises: Variant) -> GameConfig:
	var config := GameConfig.new()
	config._build(levels, foods, exercises)
	return config


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_fail("%s: arquivo nao encontrado." % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_fail("%s: arquivo vazio ou ilegivel (erro %d)." % [path, FileAccess.get_open_error()])
		return null
	file_read_count += 1
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		_fail("%s: JSON invalido na linha %d — %s."
			% [path, parser.get_error_line(), parser.get_error_message()])
		return null
	return parser.data


# --------------------------------------------------------------------------------------
# Acesso — vazio enquanto a configuracao nao for valida
# --------------------------------------------------------------------------------------

func get_max_level() -> int:
	return _max_level if is_valid else 0

func get_initial_attributes() -> Dictionary:
	return _initial_attributes.duplicate(true) if is_valid else {}

func get_levels() -> Array[Dictionary]:
	if not is_valid:
		return []
	return _levels.duplicate(true)

func get_bond_behaviors() -> Array[Dictionary]:
	if not is_valid:
		return []
	return _bond_behaviors.duplicate(true)

func get_foods() -> Array[Dictionary]:
	if not is_valid:
		return []
	return _foods.duplicate(true)

func get_exercises() -> Array[Dictionary]:
	if not is_valid:
		return []
	return _exercises.duplicate(true)

func get_food(food_id: StringName) -> Dictionary:
	if not is_valid or not _foods_by_id.has(food_id):
		return {}
	return (_foods_by_id[food_id] as Dictionary).duplicate(true)

func get_exercise(exercise_id: StringName) -> Dictionary:
	if not is_valid or not _exercises_by_id.has(exercise_id):
		return {}
	return (_exercises_by_id[exercise_id] as Dictionary).duplicate(true)

func has_exercise(exercise_id: StringName) -> bool:
	return is_valid and _exercises_by_id.has(exercise_id)

## Nivel correspondente a uma forca, sempre entre 1 e `max_level`.
func get_level_for_strength(strength: int) -> int:
	if not is_valid:
		return 1
	var level := 1
	for entry in _levels:
		if strength >= int(entry["required_strength"]):
			level = int(entry["level"])
	return level

## Desbloqueios concedidos exatamente ao alcancar `level`.
func get_unlocks_for_level(level: int) -> PackedStringArray:
	if not is_valid:
		return PackedStringArray()
	for entry in _levels:
		if int(entry["level"]) == level:
			return (entry["unlocks"] as PackedStringArray).duplicate()
	return PackedStringArray()

## Nivel em que um desbloqueio aparece; 0 quando o identificador nao existe.
func get_level_of_unlock(unlock_id: StringName) -> int:
	if not is_valid or not _unlock_level.has(unlock_id):
		return 0
	return int(_unlock_level[unlock_id])

func describe_errors() -> String:
	return "\n".join(errors)


# --------------------------------------------------------------------------------------
# Validacao
# --------------------------------------------------------------------------------------

func _fail(message: String) -> void:
	errors.append(message)


func _build(levels: Variant, foods: Variant, exercises: Variant) -> void:
	var bond_ids := _parse_levels(levels)
	_parse_foods(foods)
	_parse_exercises(exercises, bond_ids)
	is_valid = errors.is_empty()
	if not is_valid:
		_levels.clear()
		_bond_behaviors.clear()
		_foods.clear()
		_exercises.clear()
		_foods_by_id.clear()
		_exercises_by_id.clear()
		_unlock_level.clear()
		_initial_attributes.clear()
		_max_level = 0


## Numeros de JSON chegam como float em Godot. Aceita inteiros exatos e recusa o resto.
func _int_field(source: Dictionary, key: String, where: String) -> Variant:
	if not source.has(key):
		_fail("%s: campo obrigatorio '%s' ausente." % [where, key])
		return null
	var raw: Variant = source[key]
	if raw is int:
		return int(raw)
	if raw is float:
		var value: float = raw
		if is_equal_approx(value, roundf(value)):
			return int(roundf(value))
		_fail("%s: '%s' deve ser inteiro, veio %s." % [where, key, value])
		return null
	_fail("%s: '%s' deve ser numero inteiro, veio %s." % [where, key, type_string(typeof(raw))])
	return null


func _float_field(source: Dictionary, key: String, where: String) -> Variant:
	if not source.has(key):
		_fail("%s: campo obrigatorio '%s' ausente." % [where, key])
		return null
	var raw: Variant = source[key]
	if raw is int or raw is float:
		return float(raw)
	_fail("%s: '%s' deve ser numero, veio %s." % [where, key, type_string(typeof(raw))])
	return null


func _string_field(source: Dictionary, key: String, where: String) -> Variant:
	if not source.has(key):
		_fail("%s: campo obrigatorio '%s' ausente." % [where, key])
		return null
	var raw: Variant = source[key]
	if not (raw is String or raw is StringName):
		_fail("%s: '%s' deve ser texto, veio %s." % [where, key, type_string(typeof(raw))])
		return null
	var value := String(raw)
	if value.strip_edges().is_empty():
		_fail("%s: '%s' nao pode ser vazio." % [where, key])
		return null
	return value


func _array_field(source: Dictionary, key: String, where: String, allow_empty: bool = false) -> Variant:
	if not source.has(key):
		_fail("%s: campo obrigatorio '%s' ausente." % [where, key])
		return null
	var raw: Variant = source[key]
	if not (raw is Array):
		_fail("%s: '%s' deve ser lista, veio %s." % [where, key, type_string(typeof(raw))])
		return null
	var value: Array = raw
	if value.is_empty() and not allow_empty:
		_fail("%s: '%s' nao pode ser lista vazia." % [where, key])
		return null
	return value


func _root_dictionary(source: Variant, where: String) -> Variant:
	if not (source is Dictionary):
		_fail("%s: a raiz do arquivo deve ser um objeto JSON, veio %s."
			% [where, type_string(typeof(source))])
		return null
	return source


## Valida `levels.json`. Devolve os identificadores de comportamento de vinculo, para que
## a checagem de colisao de identificadores possa cobrir os dois conjuntos.
func _parse_levels(source: Variant) -> Dictionary:
	var bond_ids: Dictionary = {}
	var root: Variant = _root_dictionary(source, "levels.json")
	if root == null:
		return bond_ids
	var data: Dictionary = root

	var max_level: Variant = _int_field(data, "max_level", "levels.json")
	var attributes_raw: Variant = data.get("initial_attributes")
	if not (attributes_raw is Dictionary):
		_fail("levels.json: 'initial_attributes' deve ser um objeto.")
		attributes_raw = null
	var entries: Variant = _array_field(data, "strength_levels", "levels.json")
	var behaviors: Variant = _array_field(data, "bond_behaviors", "levels.json")

	# --- valores iniciais dos atributos ---
	if attributes_raw != null:
		var attributes: Dictionary = attributes_raw
		var where := "levels.json/initial_attributes"
		var max_energy: Variant = _int_field(attributes, "max_energy", where)
		var energy: Variant = _int_field(attributes, "energy", where)
		var strength: Variant = _int_field(attributes, "strength", where)
		var bond: Variant = _int_field(attributes, "bond", where)
		if max_energy != null and int(max_energy) <= 0:
			_fail("%s: 'max_energy' deve ser maior que zero, veio %d." % [where, max_energy])
			max_energy = null
		if energy != null and max_energy != null and (int(energy) < 0 or int(energy) > int(max_energy)):
			_fail("%s: 'energy' inicial (%d) precisa estar entre 0 e max_energy (%d)."
				% [where, energy, max_energy])
		if strength != null and int(strength) < 0:
			_fail("%s: 'strength' inicial nao pode ser negativa." % where)
		if bond != null and int(bond) < 0:
			_fail("%s: 'bond' inicial nao pode ser negativo." % where)
		if energy != null and max_energy != null and strength != null and bond != null:
			_initial_attributes = {
				"energy": int(energy), "max_energy": int(max_energy),
				"strength": int(strength), "bond": int(bond),
			}

	# --- tabela de forca ---
	var seen_levels: Dictionary = {}
	var seen_thresholds: Dictionary = {}
	var seen_unlocks: Dictionary = {}
	var previous_threshold := -1
	if entries != null:
		var list: Array = entries
		for index in list.size():
			var raw: Variant = list[index]
			var where := "levels.json/strength_levels[%d]" % index
			if not (raw is Dictionary):
				_fail("%s: cada nivel deve ser um objeto." % where)
				continue
			var entry: Dictionary = raw
			var level: Variant = _int_field(entry, "level", where)
			var threshold: Variant = _int_field(entry, "required_strength", where)
			var unlocks_raw: Variant = _array_field(entry, "unlocks", where, true)
			var description: Variant = _string_field(entry, "description", where)
			if level == null or threshold == null or unlocks_raw == null or description == null:
				continue

			if int(level) != index + 1:
				_fail("%s: os niveis devem ser 1..N em ordem; esperado %d, veio %d."
					% [where, index + 1, level])
			if seen_levels.has(level):
				_fail("%s: nivel %d duplicado." % [where, level])
			seen_levels[level] = true
			if seen_thresholds.has(threshold):
				_fail("%s: limiar de forca %d duplicado." % [where, threshold])
			seen_thresholds[threshold] = true
			if index == 0 and int(threshold) != 0:
				_fail("%s: o primeiro nivel deve exigir forca 0, veio %d." % [where, threshold])
			if int(threshold) <= previous_threshold:
				_fail("%s: limiares devem ser estritamente crescentes; %d nao supera %d."
					% [where, threshold, previous_threshold])
			previous_threshold = int(threshold)

			var unlocks := PackedStringArray()
			var local_unlocks: Dictionary = {}
			for unlock_raw in (unlocks_raw as Array):
				if not (unlock_raw is String or unlock_raw is StringName):
					_fail("%s: cada desbloqueio deve ser texto, veio %s."
						% [where, type_string(typeof(unlock_raw))])
					continue
				var unlock_id := String(unlock_raw)
				if unlock_id.strip_edges().is_empty():
					_fail("%s: identificador de desbloqueio vazio." % where)
					continue
				if local_unlocks.has(unlock_id):
					_fail("%s: desbloqueio '%s' repetido no mesmo nivel." % [where, unlock_id])
					continue
				if seen_unlocks.has(unlock_id):
					_fail("%s: desbloqueio '%s' ja aparece no nivel %d."
						% [where, unlock_id, seen_unlocks[unlock_id]])
					continue
				local_unlocks[unlock_id] = true
				seen_unlocks[unlock_id] = int(level)
				_unlock_level[StringName(unlock_id)] = int(level)
				unlocks.append(unlock_id)
			_levels.append({
				"level": int(level), "required_strength": int(threshold),
				"description": String(description), "unlocks": unlocks,
			})

		if max_level != null and int(max_level) != _levels.size():
			_fail("levels.json: 'max_level' e %d, mas a tabela tem %d niveis."
				% [max_level, _levels.size()])
		elif max_level != null:
			_max_level = int(max_level)

	# --- limiares de vinculo ---
	var previous_bond := 0
	if behaviors != null:
		var list: Array = behaviors
		for index in list.size():
			var raw: Variant = list[index]
			var where := "levels.json/bond_behaviors[%d]" % index
			if not (raw is Dictionary):
				_fail("%s: cada comportamento deve ser um objeto." % where)
				continue
			var entry: Dictionary = raw
			var behavior_id: Variant = _string_field(entry, "id", where)
			var required: Variant = _int_field(entry, "required_bond", where)
			var display_name: Variant = _string_field(entry, "display_name", where)
			if behavior_id == null or required == null or display_name == null:
				continue
			if int(required) <= 0:
				_fail("%s: 'required_bond' deve ser maior que zero, veio %d." % [where, required])
			if int(required) <= previous_bond:
				_fail("%s: limiares de vinculo devem ser estritamente crescentes; %d nao supera %d."
					% [where, required, previous_bond])
			previous_bond = int(required)
			if bond_ids.has(behavior_id):
				_fail("%s: comportamento de vinculo '%s' duplicado." % [where, behavior_id])
				continue
			if seen_unlocks.has(behavior_id):
				_fail("%s: '%s' colide com um desbloqueio de nivel; os identificadores compartilham o mesmo espaco."
					% [where, behavior_id])
				continue
			bond_ids[behavior_id] = true
			_bond_behaviors.append({
				"id": String(behavior_id), "required_bond": int(required),
				"display_name": String(display_name),
			})
	return bond_ids


func _parse_foods(source: Variant) -> void:
	var root: Variant = _root_dictionary(source, "foods.json")
	if root == null:
		return
	var entries: Variant = _array_field(root as Dictionary, "foods", "foods.json")
	if entries == null:
		return
	var list: Array = entries
	for index in list.size():
		var raw: Variant = list[index]
		var where := "foods.json/foods[%d]" % index
		if not (raw is Dictionary):
			_fail("%s: cada alimento deve ser um objeto." % where)
			continue
		var entry: Dictionary = raw
		var food_id: Variant = _string_field(entry, "id", where)
		var display_name: Variant = _string_field(entry, "display_name", where)
		var energy: Variant = _int_field(entry, "energy", where)
		var bond: Variant = _int_field(entry, "bond", where)
		var cooldown: Variant = _int_field(entry, "cooldown_seconds", where)
		var animation: Variant = _float_field(entry, "animation_seconds", where)
		if food_id == null or display_name == null or energy == null or bond == null \
				or cooldown == null or animation == null:
			continue
		if int(energy) <= 0:
			_fail("%s: 'energy' deve ser positiva, veio %d." % [where, energy])
		if int(bond) <= 0:
			_fail("%s: 'bond' deve ser positivo, veio %d." % [where, bond])
		if int(cooldown) < 0:
			_fail("%s: 'cooldown_seconds' nao pode ser negativo, veio %d." % [where, cooldown])
		if float(animation) <= 0.0:
			_fail("%s: 'animation_seconds' deve ser positiva, veio %s." % [where, animation])
		var key := StringName(food_id)
		if _foods_by_id.has(key):
			_fail("%s: identificador de alimento '%s' duplicado." % [where, food_id])
			continue
		var food := {
			"id": String(food_id), "display_name": String(display_name),
			"energy": int(energy), "bond": int(bond),
			"cooldown_seconds": int(cooldown), "animation_seconds": float(animation),
		}
		_foods.append(food)
		_foods_by_id[key] = food


func _parse_exercises(source: Variant, bond_ids: Dictionary) -> void:
	var root: Variant = _root_dictionary(source, "exercises.json")
	if root == null:
		return
	var entries: Variant = _array_field(root as Dictionary, "exercises", "exercises.json")
	if entries == null:
		return
	var list: Array = entries
	for index in list.size():
		var raw: Variant = list[index]
		var where := "exercises.json/exercises[%d]" % index
		if not (raw is Dictionary):
			_fail("%s: cada exercicio deve ser um objeto." % where)
			continue
		var entry: Dictionary = raw
		var exercise_id: Variant = _string_field(entry, "id", where)
		var display_name: Variant = _string_field(entry, "display_name", where)
		var cost: Variant = _int_field(entry, "energy_cost", where)
		var duration: Variant = _int_field(entry, "duration_seconds", where)
		var gain: Variant = _int_field(entry, "strength_gain", where)
		var required_level: Variant = _int_field(entry, "required_level", where)
		var unlock_id: Variant = _string_field(entry, "unlock_id", where)
		var training_point: Variant = _string_field(entry, "training_point", where)
		var chance: Variant = _float_field(entry, "comic_reaction_chance", where)
		if exercise_id == null or display_name == null or cost == null or duration == null \
				or gain == null or required_level == null or unlock_id == null \
				or training_point == null or chance == null:
			continue
		if int(cost) <= 0:
			_fail("%s: 'energy_cost' deve ser positivo, veio %d." % [where, cost])
		if int(duration) <= 0:
			_fail("%s: 'duration_seconds' deve ser positiva, veio %d." % [where, duration])
		if int(gain) <= 0:
			_fail("%s: 'strength_gain' deve ser positivo, veio %d." % [where, gain])
		if float(chance) < 0.0 or float(chance) > 1.0:
			_fail("%s: 'comic_reaction_chance' deve estar entre 0 e 1, veio %s." % [where, chance])

		# --- relacoes com levels.json ---
		if _max_level > 0 and (int(required_level) < 1 or int(required_level) > _max_level):
			_fail("%s: 'required_level' %d nao existe; a tabela vai de 1 a %d."
				% [where, required_level, _max_level])
		var unlock_key := StringName(unlock_id)
		if bond_ids.has(String(unlock_id)):
			_fail("%s: 'unlock_id' '%s' e um comportamento de vinculo, nao um desbloqueio de nivel."
				% [where, unlock_id])
		elif not _unlock_level.has(unlock_key):
			_fail("%s: 'unlock_id' '%s' nao existe em levels.json." % [where, unlock_id])
		elif int(_unlock_level[unlock_key]) != int(required_level):
			_fail("%s: '%s' e concedido no nivel %d, mas 'required_level' diz %d."
				% [where, unlock_id, _unlock_level[unlock_key], required_level])

		var key := StringName(exercise_id)
		if _exercises_by_id.has(key):
			_fail("%s: identificador de exercicio '%s' duplicado." % [where, exercise_id])
			continue
		var exercise := {
			"id": String(exercise_id), "display_name": String(display_name),
			"energy_cost": int(cost), "duration_seconds": int(duration),
			"strength_gain": int(gain), "required_level": int(required_level),
			"unlock_id": String(unlock_id), "training_point": String(training_point),
			"comic_reaction_chance": float(chance),
		}
		_exercises.append(exercise)
		_exercises_by_id[key] = exercise
