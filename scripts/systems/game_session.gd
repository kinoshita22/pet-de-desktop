class_name GameSession
extends Node
## Dono da configuracao e do modelo de progressao durante a execucao.
##
## Existe para que o modelo tenha um ciclo de vida ligado a cena sem virar Autoload: um
## Autoload seria estado global vivo tambem no editor e em cenas de teste, e nada aqui
## precisa disso. Quem precisar da sessao a encontra pelo grupo, nunca por caminho fixo.
##
## A sessao resolve as referencias **uma unica vez**, na abertura, e as entrega a quem
## precisa. Ela nao vira controlador: nao le nem escreve na maquina de estados de Caramelo
## e nao concede recompensa alguma — quem faz isso e o `FeedingSystem`.
##
## Nesta etapa nada e gravado em disco.

const GROUP := &"game_session"

## Emitido uma unica vez, quando o estado ja foi carregado, reconciliado e aplicado.
## Antes disso os sistemas nao estao configurados e nenhuma interacao e aceita.
signal session_ready()
## Relatorio estruturado da reconciliacao offline; a interface e quem o transforma em texto.
signal offline_progress_applied(report: Dictionary)

var _config: GameConfig
var _model: ProgressionModel
var _feeding: FeedingSystem
var _exercise: ExerciseSystem
var _rest: RestSystem
var _evolution: EvolutionSystem
var _affection: AffectionSystem
var _save: SaveManager
var _dog: Caramelo
var _ready_emitted := false
var _last_report: Dictionary = {}
var _food_point: Marker2D


func _ready() -> void:
	add_to_group(GROUP)
	_config = GameConfig.load_default()
	if not _config.is_valid:
		for message in _config.errors:
			push_error("Configuracao invalida — %s" % message)
		# Falha ruidosa em desenvolvimento: seguir com dados errados esconderia o problema
		# ate virar comportamento estranho de jogo.
		assert(false, "Configuracao de jogo invalida:\n%s" % _config.describe_errors())
		return
	_model = ProgressionModel.new(_config)
	_wire_dependencies()


## Resolve Caramelo, o pote e o `FoodPoint` uma unica vez e entrega ao sistema de
## alimentacao.
##
## A varredura acontece aqui, e nao em `_ready` de cada parte, porque a arvore inteira ja
## esta montada quando o primeiro `_ready` roda — instanciar uma cena constroi todo o
## ramo antes de adiciona-lo. Por isso nao e preciso esperar quadro nenhum, e nao ha
## caminho fragil do tipo `../../World/Backyard`.
func _wire_dependencies() -> void:
	_feeding = _find_descendant(self, func(node: Node) -> bool: return node is FeedingSystem) as FeedingSystem
	if _feeding == null:
		push_error("GameSession: nenhum FeedingSystem entre os filhos.")
		return
	var scope: Node = get_parent() if get_parent() != null else self
	_dog = _find_descendant(scope, func(node: Node) -> bool: return node is Caramelo) as Caramelo
	var bowl := _find_descendant(scope, func(node: Node) -> bool: return node is FoodBowl)
	_food_point = _find_descendant(scope, func(node: Node) -> bool:
		return node is Marker2D and node.name == &"FoodPoint") as Marker2D
	if _dog == null:
		push_error("GameSession: Caramelo nao encontrado na cena.")
		return
	if _food_point == null:
		push_error("GameSession: FoodPoint nao encontrado na cena.")
		return
	_feeding.configure(_config, _model, _dog)
	if bowl == null:
		push_error("GameSession: pote de comida nao encontrado na cena.")
	else:
		_feeding.attach_bowl(bowl)

	_exercise = _find_descendant(self, func(node: Node) -> bool: return node is ExerciseSystem) as ExerciseSystem
	if _exercise == null:
		push_error("GameSession: nenhum ExerciseSystem entre os filhos.")
		return
	_exercise.configure(_config, _model, _dog, _collect_training_points(scope))
	var hotspots := _collect_hotspots(scope)
	if hotspots.is_empty():
		push_error("GameSession: nenhum hotspot de equipamento encontrado na cena.")
	for hotspot in hotspots:
		_exercise.attach_hotspot(hotspot)

	_rest = _find_descendant(self, func(node: Node) -> bool: return node is RestSystem) as RestSystem
	if _rest == null:
		push_error("GameSession: nenhum RestSystem entre os filhos.")
		return
	var training_points := _collect_training_points(scope)
	_rest.configure(_config, _model, _dog, training_points.get(&"RestPoint"))

	_evolution = _find_descendant(self, func(node: Node) -> bool: return node is EvolutionSystem) as EvolutionSystem
	if _evolution != null:
		_evolution.configure(_model, _dog)
	_affection = _find_descendant(self, func(node: Node) -> bool: return node is AffectionSystem) as AffectionSystem
	if _affection != null:
		_affection.configure(_config, _model, _dog, _evolution)

	_save = _find_descendant(self, func(node: Node) -> bool: return node is SaveManager) as SaveManager
	if _save == null:
		push_error("GameSession: nenhum SaveManager entre os filhos.")
		return
	_save.configure(_config, _model, _feeding, _exercise, _rest, _dog, _affection)
	_connect_save_triggers()
	_start_session(training_points)


## Eventos que tornam o estado digno de ir a disco. Cada um apenas **marca** o save como
## sujo; o `SaveManager` agrupa os proximos e escreve uma vez so depois do debounce, de
## modo que a recarga pingando por segundo nunca vira escrita por quadro.
func _connect_save_triggers() -> void:
	_feeding.feeding_completed.connect(func(_id: StringName, _e: int, _b: int) -> void:
		_save.mark_dirty())
	# O treino marca ao **iniciar**, ja com a energia debitada, e ao concluir.
	_exercise.exercise_started.connect(func(_id: StringName, _spent: int) -> void:
		_save.mark_dirty())
	_exercise.exercise_completed.connect(func(_id: StringName, _gain: int) -> void:
		_save.mark_dirty())
	_rest.rest_energy_restored.connect(func(_amount: int) -> void: _save.mark_dirty())
	if _affection != null:
		_affection.pet_completed.connect(func(_bond: int) -> void: _save.mark_dirty())
		_affection.pet_cooldown_changed.connect(func(remaining: float) -> void:
			if remaining <= 0.0:
				_save.mark_dirty())
	_save.save_migrated.connect(func(_from: int, _to: int) -> void: _save.mark_dirty())
	_model.level_changed.connect(func(_p: int, _n: int) -> void: _save.mark_dirty())
	# Recarga so importa quando muda de estado material: virar disponivel.
	_feeding.cooldown_changed.connect(func(_id: StringName, remaining: float) -> void:
		if remaining <= 0.0:
			_save.mark_dirty())


## Ordem explicita de abertura. Tudo acontece dentro de `_ready`, antes do primeiro quadro,
## de modo que a interface nunca chega a mostrar valores iniciais falsos.
##
##   1. carregar principal ou backup      5. restaurar ou cancelar a atividade
##   2. validar o snapshot                6. ligar o autosave
##   3. restaurar o estado base           7. anunciar `session_ready`
##   4. reconciliar o tempo ausente       8. gravar o estado reconciliado
func _start_session(training_points: Dictionary) -> void:
	var loaded := _save.load_snapshot(_model.get_max_energy())
	var snapshot: Variant = loaded["snapshot"]
	var report: Dictionary = {}

	if snapshot is Dictionary:
		var now_unix := int(Time.get_unix_time_from_system())
		var reconciled := OfflineProgress.reconcile(snapshot as Dictionary, _config, now_unix,
			_model.get_max_energy())
		var final_snapshot: Dictionary = reconciled["snapshot"]
		report = reconciled["report"]
		_apply_snapshot(final_snapshot, training_points)
		if String(loaded["reason"]) != "":
			report["recovery_message"] = loaded["reason"]
			report["has_events"] = true
	elif String(loaded["reason"]) != "":
		report = {"has_events": true, "recovery_message": loaded["reason"],
			"elapsed_seconds": 0.0, "clock_went_backwards": false}

	_last_report = report
	_save.set_enabled(true)
	_ready_emitted = true
	if _affection != null:
		_affection.set_session_ready(true)
	session_ready.emit()
	if not report.is_empty() and bool(report.get("has_events", false)):
		offline_progress_applied.emit(report)
	# O estado reconciliado precisa ir a disco agora: sem isso, uma segunda abertura
	# reaplicaria as mesmas recompensas.
	_save.save_now()


## Aplica um snapshot ja reconciliado ao modelo, aos sistemas e a Caramelo.
func _apply_snapshot(snapshot: Dictionary, training_points: Dictionary) -> void:
	var progression: Dictionary = snapshot.get("progression", {})
	_model.restore(int(progression.get("energy", 0)), int(progression.get("strength", 0)),
		int(progression.get("bond", 0)))
	_feeding.restore_cooldowns(snapshot.get("food_cooldowns", {}))
	if _affection != null:
		_affection.restore_cooldown(float((snapshot.get("affection", {}) as Dictionary)
			.get("cooldown_remaining", 0.0)))
	_rest.restore_accumulated(float((snapshot.get("rest", {}) as Dictionary)
		.get("accumulated_seconds", 0.0)))

	var dog_data: Dictionary = snapshot.get("dog", {})
	var position_data: Dictionary = dog_data.get("position", {})
	var saved_position := Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
	var facing := int(dog_data.get("facing", 1))
	if not _dog.restore_placement(saved_position, facing):
		# Posicao invalida: Caramelo vai para um ponto seguro. O poligono nao e afrouxado.
		push_warning("GameSession: posicao salva fora da area caminhavel; usando ponto seguro.")
		_dog.set_walkable_polygon(_dog_polygon())

	var activity: Variant = snapshot.get("activity")
	if activity is Dictionary:
		_restore_activity(activity as Dictionary, training_points)


func _dog_polygon() -> PackedVector2Array:
	var walkable := _find_descendant(get_parent(), func(node: Node) -> bool:
		return node is CollisionPolygon2D) as CollisionPolygon2D
	return walkable.polygon if walkable != null else PackedVector2Array()


## Recoloca uma atividade que ficou pela metade: o cachorro volta direto ao ponto, sem
## repetir a caminhada, sem novo debito e sem recompensa antecipada.
func _restore_activity(activity: Dictionary, training_points: Dictionary) -> void:
	var type := String(activity.get("type", ""))
	var phase := String(activity.get("phase", ""))
	var content_id := StringName(String(activity.get("content_id", "")))
	var remaining := float(activity.get("remaining_seconds", 0.0))
	if phase != "running" or remaining <= 0.0:
		return
	match type:
		"feeding":
			var point: Variant = training_points.get(&"FoodPoint")
			if _feeding.restore_pending_meal(content_id) and point is Vector2:
				_dog.restore_activity(Caramelo.State.EATING, remaining, point as Vector2)
		"exercise":
			var exercise := _config.get_exercise(content_id)
			var marker := StringName(String(exercise.get("training_point", "")))
			var target: Variant = training_points.get(marker)
			# `already_started = true`: a energia ja saiu antes de fechar o jogo.
			if _exercise.restore_pending_exercise(content_id, true) and target is Vector2:
				_dog.restore_activity(Caramelo.State.TRAINING, remaining, target as Vector2)


## Marcadores de treino, por nome, ja no espaco de coordenadas de Caramelo. O sistema de
## exercicios recebe o mapa pronto e nunca procura nada na arvore.
func _collect_training_points(scope: Node) -> Dictionary:
	var layer := _dog.get_parent() as Node2D
	if layer == null:
		return {}
	var to_layer := layer.get_global_transform().affine_inverse()
	var points: Dictionary = {}
	var queue: Array[Node] = [scope]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is Marker2D and node.get_parent() != null and node.get_parent().name == &"InteractionPoints":
			points[StringName(node.name)] = to_layer * (node as Marker2D).global_position
		for child in node.get_children():
			queue.append(child)
	return points


func _collect_hotspots(scope: Node) -> Array[Node]:
	var found: Array[Node] = []
	var queue: Array[Node] = [scope]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is EquipmentHotspot:
			found.append(node)
		for child in node.get_children():
			queue.append(child)
	return found


func _find_descendant(from: Node, predicate: Callable) -> Node:
	var queue: Array[Node] = [from]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node != from and predicate.call(node):
			return node
		for child in node.get_children():
			queue.append(child)
	return null


func get_feeding_system() -> FeedingSystem:
	return _feeding


func get_exercise_system() -> ExerciseSystem:
	return _exercise


func get_rest_system() -> RestSystem:
	return _rest


func get_save_manager() -> SaveManager:
	return _save


func get_evolution_system() -> EvolutionSystem:
	return _evolution


func get_affection_system() -> AffectionSystem:
	return _affection


## A sessao ja carregou e liberou interacao?
func is_session_ready() -> bool:
	return _ready_emitted


## Relatorio da ultima reconciliacao offline; vazio quando nao houve nenhuma.
func get_offline_report() -> Dictionary:
	return _last_report.duplicate(true)


func get_caramelo() -> Caramelo:
	return _dog


## Posicao do `FoodPoint` no espaco do proprio marcador. Caramelo ja recebe esse ponto do
## quintal; aqui ele serve para alinhamento e verificacao.
func get_food_point() -> Marker2D:
	return _food_point


## A sessao presente na arvore, ou `null`. Usar isto em vez de caminhos como `../../`.
static func find_in(tree: SceneTree) -> GameSession:
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group(GROUP)
	if nodes.is_empty():
		return null
	return nodes[0] as GameSession


## `null` enquanto a configuracao nao tiver sido carregada com sucesso.
func get_model() -> ProgressionModel:
	return _model


func get_config() -> GameConfig:
	return _config


func is_ready() -> bool:
	return _model != null
