class_name SaveManager
extends Node
## Persistencia local do progresso: monta, valida, escreve atomicamente e recupera.
##
## O save vive em `user://`, nunca no diretorio do executavel nem em `res://`, de modo que
## desinstalar ou mover o jogo nao apaga o progresso (`MVP_SPEC.md` secao 16).
##
## **Escrita atomica.** Nada e sobrescrito antes de existir outra copia valida: o snapshot
## vai para um temporario, e relido e validado, o principal antigo vira backup e so entao
## o temporario toma o lugar do principal. Se qualquer passo falhar, o ultimo save valido
## continua de pe.
##
## Nao ha criptografia nem ofuscacao: o `MVP_SPEC.md` secao 16 pede formato legivel, sem
## anticheat. O conteudo do JSON e **dado**, nunca executado.
##
## Este no nao calcula recompensa offline nem controla Caramelo — so serializa.

const SCHEMA_VERSION := 1
const DEFAULT_MAIN := "user://savegame.json"
const DEFAULT_BACKUP := "user://savegame.backup.json"
const DEFAULT_TEMP := "user://savegame.tmp.json"
## Onde um save ilegivel ou de versao futura e preservado, para que a sessao possa gravar
## por cima do principal sem destruir o arquivo original.
const REJECTED_SUFFIX := ".rejected.json"

## Infraestrutura, nao balanceamento: agrupa eventos proximos e garante escrita periodica.
const DEBOUNCE_SECONDS := 0.5
const AUTOSAVE_SECONDS := 30.0

## Origem do estado carregado.
enum Source { NEW_GAME, MAIN, BACKUP }

## Diretorio alternativo dentro de `user://`, aplicado a toda instancia criada depois de
## definido. Existe para que as suites trabalhem num diretorio isolado e nunca encostem no
## save real de quem esta jogando. Vazio no jogo entregue.
static var directory_override := ""


## Aponta as suites para um diretorio proprio e apaga o que houver nele.
static func use_isolated_directory(name: String) -> void:
	directory_override = "user://%s" % name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_override))
	for file in ["savegame.json", "savegame.backup.json", "savegame.tmp.json", "savegame.rejected.json"]:
		var path := "%s/%s" % [directory_override, file]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Remove o diretorio isolado e volta ao comportamento normal.
static func clear_isolated_directory() -> void:
	if directory_override.is_empty():
		return
	for file in ["savegame.json", "savegame.backup.json", "savegame.tmp.json", "savegame.rejected.json"]:
		var path := "%s/%s" % [directory_override, file]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory_override))
	directory_override = ""

signal save_started()
signal save_completed(path: String)
signal save_failed(reason: String)
signal load_completed(source: int)
signal load_failed(reason: String)
signal backup_recovered()


## Acesso a disco isolado atras de uma interface, para que os testes possam simular falhas
## previsiveis sem depender de permissoes do sistema.
class FileAdapter:
	extends RefCounted

	func exists(path: String) -> bool:
		return FileAccess.file_exists(path)

	func read_text(path: String) -> Variant:
		if not FileAccess.file_exists(path):
			return null
		var handle := FileAccess.open(path, FileAccess.READ)
		if handle == null:
			return null
		var text := handle.get_as_text()
		handle.close()
		return text

	func write_text(path: String, text: String) -> bool:
		var handle := FileAccess.open(path, FileAccess.WRITE)
		if handle == null:
			return false
		handle.store_string(text)
		handle.close()
		return FileAccess.file_exists(path)

	func copy(from_path: String, to_path: String) -> bool:
		var text: Variant = read_text(from_path)
		if not (text is String):
			return false
		return write_text(to_path, text)

	func remove(path: String) -> bool:
		if not FileAccess.file_exists(path):
			return true
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


var _config: GameConfig
var _model: ProgressionModel
var _feeding: FeedingSystem
var _exercise: ExerciseSystem
var _rest: RestSystem
var _dog: Caramelo

var _main_path := DEFAULT_MAIN
var _backup_path := DEFAULT_BACKUP
var _temp_path := DEFAULT_TEMP
var _files := FileAdapter.new()

var _dirty := false
var _debounce := 0.0
var _since_autosave := 0.0
var _enabled := false
var _last_error := ""


func _ready() -> void:
	if not directory_override.is_empty():
		set_paths("%s/savegame.json" % directory_override,
			"%s/savegame.backup.json" % directory_override,
			"%s/savegame.tmp.json" % directory_override)


func _process(delta: float) -> void:
	simulate(delta)


func _notification(what: int) -> void:
	# So o fechamento da janela forca a escrita, ignorando o debounce. `PREDELETE` fica de
	# fora de proposito: quando o no esta sendo destruido, o cachorro e os sistemas ja
	# podem ter sido liberados, e o snapshot sairia de referencias mortas.
	if what != NOTIFICATION_WM_CLOSE_REQUEST and what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _enabled and _dirty:
		save_now()


# --------------------------------------------------------------------------------------
# Configuracao
# --------------------------------------------------------------------------------------

func configure(config: GameConfig, model: ProgressionModel, feeding: FeedingSystem,
		exercise: ExerciseSystem, rest: RestSystem, dog: Caramelo) -> void:
	_config = config
	_model = model
	_feeding = feeding
	_exercise = exercise
	_rest = rest
	_dog = dog


## Caminhos alternativos, usados pelos testes para trabalhar num diretorio isolado.
func set_paths(main_path: String, backup_path: String, temp_path: String) -> void:
	_main_path = main_path
	_backup_path = backup_path
	_temp_path = temp_path


## Substitui o acesso a disco. Serve para simular falha de escrita nos testes.
func set_file_adapter(adapter: FileAdapter) -> void:
	_files = adapter if adapter != null else FileAdapter.new()


## Liga ou desliga o autosave. Fica desligado ate a sessao terminar de carregar.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func get_main_path() -> String:
	return _main_path


func get_last_error() -> String:
	return _last_error


func is_dirty() -> bool:
	return _dirty


# --------------------------------------------------------------------------------------
# Agendamento
# --------------------------------------------------------------------------------------

## Marca o estado como sujo. A escrita sai depois do debounce, agrupando eventos proximos.
func mark_dirty() -> void:
	_dirty = true
	_debounce = DEBOUNCE_SECONDS


## Avanca debounce e autosave em `delta` segundos. Publico para os testes adiantarem os
## trinta segundos do autosave sem esperar tempo real.
func simulate(delta: float) -> void:
	if delta <= 0.0 or not _enabled:
		return
	_since_autosave += delta
	if _dirty:
		_debounce -= delta
		if _debounce <= 0.0:
			save_now()
			return
	if _since_autosave >= AUTOSAVE_SECONDS:
		_since_autosave = 0.0
		if _dirty:
			save_now()


# --------------------------------------------------------------------------------------
# Snapshot
# --------------------------------------------------------------------------------------

## Estado atual como dicionario serializavel. Apenas dados: nada de nos, sinais ou objetos.
func build_snapshot(now_unix: int) -> Dictionary:
	if not is_instance_valid(_dog) or not is_instance_valid(_model):
		return {}
	var snapshot := {
		"schema_version": SCHEMA_VERSION,
		"saved_at_unix": now_unix,
		"progression": {
			"energy": _model.get_energy(),
			# `level` e os desbloqueios ficam de fora de proposito: sao derivados da forca
			# e persisti-los criaria uma segunda fonte de verdade capaz de divergir.
			"strength": _model.get_strength(),
			"bond": _model.get_bond(),
		},
		"food_cooldowns": _feeding.get_cooldowns(),
		"rest": {"accumulated_seconds": _rest.get_accumulated_seconds()},
		"dog": {
			"position": {"x": _dog.position.x, "y": _dog.position.y},
			"facing": _dog.get_facing(),
		},
		"activity": _build_activity(),
	}
	return snapshot


func _build_activity() -> Variant:
	var state := _dog.get_current_state()
	var reserved := _dog.get_reserved_activity()
	if _feeding.has_pending_meal():
		return {
			"type": "feeding",
			"phase": "running" if state == Caramelo.State.EATING else "walking",
			"content_id": String(_feeding.get_pending_food()),
			"remaining_seconds": _dog.get_state_remaining() if state == Caramelo.State.EATING else 0.0,
			"energy_already_spent": false,
			"reward_already_applied": false,
			"target_id": "FoodPoint",
		}
	if _exercise.has_pending_exercise():
		var running := _exercise.is_running()
		var exercise := _exercise.get_exercise(_exercise.get_pending_exercise())
		return {
			"type": "exercise",
			"phase": "running" if running else "walking",
			"content_id": String(_exercise.get_pending_exercise()),
			"remaining_seconds": _dog.get_state_remaining() if state == Caramelo.State.TRAINING else 0.0,
			# No treino a energia sai ao **entrar** em `TRAINING`, nunca antes.
			"energy_already_spent": running,
			"reward_already_applied": false,
			"target_id": String(exercise.get("training_point", "")),
		}
	if reserved == Caramelo.State.RESTING:
		return {
			"type": "rest",
			"phase": "running" if state == Caramelo.State.RESTING else "walking",
			"content_id": "",
			"remaining_seconds": 0.0,
			"energy_already_spent": false,
			"reward_already_applied": false,
			"target_id": "RestPoint",
		}
	return null


# --------------------------------------------------------------------------------------
# Validacao
# --------------------------------------------------------------------------------------

const ACTIVITY_TYPES := ["feeding", "exercise", "rest"]
const ACTIVITY_PHASES := ["reserved", "walking", "running"]


## Lista de problemas do snapshot; vazia quando ele esta bom. Campos desconhecidos sao
## ignorados de proposito, para que um save de uma versao futura menor ainda carregue.
func validate(snapshot: Variant, config: GameConfig, max_energy: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if not (snapshot is Dictionary):
		errors.append("a raiz do save deve ser um objeto JSON.")
		return errors
	var data: Dictionary = snapshot

	var version: Variant = _read_int(data, "schema_version", errors)
	if version != null and int(version) > SCHEMA_VERSION:
		errors.append("save da versao %d, mais nova que a suportada (%d)." % [version, SCHEMA_VERSION])
	var saved_at: Variant = _read_int(data, "saved_at_unix", errors)
	if saved_at != null and int(saved_at) < 0:
		errors.append("'saved_at_unix' nao pode ser negativo.")

	var progression: Variant = data.get("progression")
	if not (progression is Dictionary):
		errors.append("'progression' ausente ou nao e um objeto.")
	else:
		var energy: Variant = _read_int(progression, "energy", errors, "progression")
		var strength: Variant = _read_int(progression, "strength", errors, "progression")
		var bond: Variant = _read_int(progression, "bond", errors, "progression")
		if energy != null and (int(energy) < 0 or int(energy) > max_energy):
			errors.append("progression/energy %d fora de 0..%d." % [energy, max_energy])
		if strength != null and int(strength) < 0:
			errors.append("progression/strength nao pode ser negativa.")
		if bond != null and int(bond) < 0:
			errors.append("progression/bond nao pode ser negativo.")

	var cooldowns: Variant = data.get("food_cooldowns", {})
	if not (cooldowns is Dictionary):
		errors.append("'food_cooldowns' deve ser um objeto.")
	else:
		for key in (cooldowns as Dictionary):
			var remaining: Variant = (cooldowns as Dictionary)[key]
			if not (remaining is float or remaining is int) or not is_finite(float(remaining)):
				errors.append("food_cooldowns/%s deve ser numero finito." % key)
			elif float(remaining) < 0.0:
				errors.append("food_cooldowns/%s nao pode ser negativo." % key)
			elif config != null and config.get_food(StringName(key)).is_empty():
				errors.append("food_cooldowns/%s nao existe em foods.json." % key)

	var rest: Variant = data.get("rest", {})
	if not (rest is Dictionary):
		errors.append("'rest' deve ser um objeto.")
	else:
		var accumulated: Variant = _read_float(rest as Dictionary, "accumulated_seconds", errors, "rest")
		if accumulated != null and float(accumulated) < 0.0:
			errors.append("rest/accumulated_seconds nao pode ser negativo.")

	var dog: Variant = data.get("dog")
	if not (dog is Dictionary):
		errors.append("'dog' ausente ou nao e um objeto.")
	else:
		var position: Variant = (dog as Dictionary).get("position")
		if not (position is Dictionary):
			errors.append("dog/position ausente ou nao e um objeto.")
		else:
			_read_float(position as Dictionary, "x", errors, "dog/position")
			_read_float(position as Dictionary, "y", errors, "dog/position")
		var facing: Variant = _read_int(dog as Dictionary, "facing", errors, "dog")
		if facing != null and int(facing) != 1 and int(facing) != -1:
			errors.append("dog/facing deve ser 1 ou -1, veio %d." % facing)

	_validate_activity(data.get("activity"), config, errors)
	return errors


func _validate_activity(activity: Variant, config: GameConfig, errors: PackedStringArray) -> void:
	if activity == null:
		return
	if not (activity is Dictionary):
		errors.append("'activity' deve ser um objeto ou nulo.")
		return
	var data: Dictionary = activity
	var type := String(data.get("type", ""))
	if not ACTIVITY_TYPES.has(type):
		errors.append("activity/type desconhecido: '%s'." % type)
		return
	var phase := String(data.get("phase", ""))
	if not ACTIVITY_PHASES.has(phase):
		errors.append("activity/phase desconhecida: '%s'." % phase)
	var remaining: Variant = _read_float(data, "remaining_seconds", errors, "activity")
	if remaining != null and float(remaining) < 0.0:
		errors.append("activity/remaining_seconds nao pode ser negativo.")
	var spent: Variant = data.get("energy_already_spent")
	var applied: Variant = data.get("reward_already_applied")
	if not (spent is bool) or not (applied is bool):
		errors.append("activity: 'energy_already_spent' e 'reward_already_applied' devem ser booleanos.")
		return

	var content_id := StringName(String(data.get("content_id", "")))
	match type:
		"feeding":
			if config != null and config.get_food(content_id).is_empty():
				errors.append("activity/content_id '%s' nao existe em foods.json." % content_id)
			if bool(spent):
				errors.append("activity: comer nunca gasta energia; 'energy_already_spent' incoerente.")
		"exercise":
			if config != null and config.get_exercise(content_id).is_empty():
				errors.append("activity/content_id '%s' nao existe em exercises.json." % content_id)
			# Um treino em execucao tem a energia obrigatoriamente ja debitada.
			if phase == "running" and not bool(spent):
				errors.append("activity: treino em execucao com 'energy_already_spent' falso.")
			if phase != "running" and bool(spent):
				errors.append("activity: energia debitada sem o treino ter comecado.")
		"rest":
			if bool(spent) or bool(applied):
				errors.append("activity: descanso nao gasta energia nem concede recompensa.")
	if phase == "running" and remaining != null and float(remaining) <= 0.0 and type != "rest":
		errors.append("activity: atividade em execucao precisa de tempo restante positivo.")


func _read_int(source: Dictionary, key: String, errors: PackedStringArray, prefix := "") -> Variant:
	var where := key if prefix.is_empty() else "%s/%s" % [prefix, key]
	if not source.has(key):
		errors.append("campo obrigatorio '%s' ausente." % where)
		return null
	var raw: Variant = source[key]
	if raw is int:
		return int(raw)
	if raw is float and is_finite(float(raw)) and is_equal_approx(float(raw), roundf(float(raw))):
		return int(roundf(float(raw)))
	errors.append("'%s' deve ser inteiro finito." % where)
	return null


func _read_float(source: Dictionary, key: String, errors: PackedStringArray, prefix := "") -> Variant:
	var where := key if prefix.is_empty() else "%s/%s" % [prefix, key]
	if not source.has(key):
		errors.append("campo obrigatorio '%s' ausente." % where)
		return null
	var raw: Variant = source[key]
	if (raw is float or raw is int) and is_finite(float(raw)):
		return float(raw)
	errors.append("'%s' deve ser numero finito." % where)
	return null


# --------------------------------------------------------------------------------------
# Escrita atomica
# --------------------------------------------------------------------------------------

## Grava o estado atual. Devolve `true` somente quando o principal final pode ser lido de
## volta e validado.
##
## A ordem existe para que **nunca** faltem as duas copias ao mesmo tempo: o temporario e
## escrito e conferido primeiro, o principal antigo vira backup, e so entao o temporario
## assume. Qualquer falha no meio deixa o ultimo save valido de pe.
func save_now(now_unix: int = -1) -> bool:
	if _model == null:
		return _fail_save("sistemas ainda nao configurados.")
	save_started.emit()
	var stamp := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var snapshot := build_snapshot(stamp)

	var errors := validate(snapshot, _config, _model.get_max_energy())
	if not errors.is_empty():
		return _fail_save("snapshot invalido — %s" % errors[0])

	var text := JSON.stringify(snapshot, "\t")
	if not _files.write_text(_temp_path, text):
		_files.remove(_temp_path)
		return _fail_save("nao foi possivel escrever o temporario.")

	# Rele o temporario: escrita truncada ou parcial e apanhada aqui, antes de qualquer
	# coisa ser substituida.
	var written: Variant = _files.read_text(_temp_path)
	if not (written is String) or (written as String).length() != text.length():
		_files.remove(_temp_path)
		return _fail_save("temporario incompleto; o save anterior foi preservado.")
	var reparsed: Variant = JSON.parse_string(written as String)
	if validate(reparsed, _config, _model.get_max_energy()).size() > 0:
		_files.remove(_temp_path)
		return _fail_save("temporario nao passou na revalidacao.")

	# O principal anterior vira backup antes de perder o lugar.
	if _files.exists(_main_path) and not _files.copy(_main_path, _backup_path):
		_files.remove(_temp_path)
		return _fail_save("nao foi possivel preservar o backup.")

	if not _files.copy(_temp_path, _main_path):
		_files.remove(_temp_path)
		return _fail_save("nao foi possivel promover o temporario; o save anterior continua.")
	_files.remove(_temp_path)

	var final_text: Variant = _files.read_text(_main_path)
	if not (final_text is String) \
			or validate(JSON.parse_string(final_text as String), _config, _model.get_max_energy()).size() > 0:
		return _fail_save("o principal final nao pode ser lido de volta.")

	_dirty = false
	_debounce = 0.0
	_since_autosave = 0.0
	_last_error = ""
	save_completed.emit(_main_path)
	return true


## Falha de save nunca encerra o jogo: ela e registrada e anunciada, e a execucao segue.
func _fail_save(reason: String) -> bool:
	_last_error = reason
	push_warning("SaveManager: %s" % reason)
	save_failed.emit(reason)
	return false


# --------------------------------------------------------------------------------------
# Carga e recuperacao
# --------------------------------------------------------------------------------------

## Carrega o principal; se ele nao servir, tenta o backup; se nenhum servir, comeca novo.
##
## Devolve `{"source": Source, "snapshot": Dictionary ou null, "reason": String}`.
## **Nada e sobrescrito aqui** — um save corrompido ou de versao futura fica no disco
## exatamente como estava, para que o jogador possa recupera-lo a mao.
func load_snapshot(max_energy: int) -> Dictionary:
	var main_result := _try_load(_main_path, max_energy)
	if main_result["snapshot"] != null:
		load_completed.emit(Source.MAIN)
		return {"source": Source.MAIN, "snapshot": main_result["snapshot"], "reason": ""}

	# O principal existe mas nao serve. Antes que a sessao grave por cima, uma copia
	# intacta e guardada — inclusive quando o save e de uma versao futura do jogo.
	if _files.exists(_main_path):
		_files.copy(_main_path, _rejected_path())

	if not _files.exists(_main_path):
		# Jogo novo: nem principal nem aviso.
		var backup_only := _try_load(_backup_path, max_energy)
		if backup_only["snapshot"] != null:
			backup_recovered.emit()
			load_completed.emit(Source.BACKUP)
			return {"source": Source.BACKUP, "snapshot": backup_only["snapshot"],
				"reason": "o save principal nao existia; o backup foi usado."}
		load_completed.emit(Source.NEW_GAME)
		return {"source": Source.NEW_GAME, "snapshot": null, "reason": ""}

	var backup_result := _try_load(_backup_path, max_energy)
	if backup_result["snapshot"] != null:
		backup_recovered.emit()
		load_completed.emit(Source.BACKUP)
		return {"source": Source.BACKUP, "snapshot": backup_result["snapshot"],
			"reason": "o save principal estava ilegivel; o backup foi usado."}

	var reason := "principal e backup ilegiveis (%s); comecando um jogo novo." % main_result["reason"]
	_last_error = reason
	load_failed.emit(reason)
	load_completed.emit(Source.NEW_GAME)
	return {"source": Source.NEW_GAME, "snapshot": null, "reason": reason}


## Caminho onde um save recusado e preservado.
func _rejected_path() -> String:
	return _main_path.get_basename() + REJECTED_SUFFIX


func _try_load(path: String, max_energy: int) -> Dictionary:
	if not _files.exists(path):
		return {"snapshot": null, "reason": "arquivo ausente"}
	var text: Variant = _files.read_text(path)
	if not (text is String) or (text as String).strip_edges().is_empty():
		return {"snapshot": null, "reason": "arquivo vazio ou ilegivel"}
	var parsed: Variant = JSON.parse_string(text as String)
	if parsed == null:
		return {"snapshot": null, "reason": "JSON invalido"}
	var errors := validate(parsed, _config, max_energy)
	if not errors.is_empty():
		return {"snapshot": null, "reason": errors[0]}
	return {"snapshot": parsed as Dictionary, "reason": ""}


static func source_name(source: int) -> String:
	match source:
		Source.MAIN: return "principal"
		Source.BACKUP: return "backup"
	return "jogo novo"
