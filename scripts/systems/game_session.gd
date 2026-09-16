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

var _config: GameConfig
var _model: ProgressionModel
var _feeding: FeedingSystem
var _exercise: ExerciseSystem
var _rest: RestSystem
var _dog: Caramelo
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
