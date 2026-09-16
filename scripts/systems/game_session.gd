class_name GameSession
extends Node
## Dono da configuracao e do modelo de progressao durante a execucao.
##
## Existe para que o modelo tenha um ciclo de vida ligado a cena sem virar Autoload: um
## Autoload seria estado global vivo tambem no editor e em cenas de teste, e nada aqui
## precisa disso. Quem precisar da sessao a encontra pelo grupo, nunca por caminho fixo.
##
## A sessao **nao** conhece Caramelo: nao le nem escreve na maquina de estados, nao se
## liga aos sinais dele e nao concede recompensa alguma. O acoplamento entre atributos e
## comportamento so aparece na Etapa 6.
##
## Nesta etapa nada e gravado em disco.

const GROUP := &"game_session"

var _config: GameConfig
var _model: ProgressionModel


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
