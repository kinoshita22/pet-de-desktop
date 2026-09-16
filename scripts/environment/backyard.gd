extends Node2D
## Encaixa o quintal no viewport sem deformar a arte.
##
## A cena e autorada no sistema de coordenadas-base 1920 x 1080 (MVP_SPEC secao 3).
## Como "display/window/stretch/aspect" esta em "expand", o viewport cresce em uma das
## dimensoes conforme a proporcao da janela: em 1024 x 768 ele vira 1920 x 1440 e em
## 3440 x 1440 vira 2580 x 1080. Um fundo de escala fixa deixaria faixas vazias nesses
## formatos, e esticar a imagem para preencher a deformaria.
##
## A regra aplicada aqui e a mesma de "background-size: cover": escala uniforme igual ao
## maior fator necessario, com o excedente recortado simetricamente nas bordas.
##
## O no inteiro e escalado, e nao apenas o fundo, para que a area caminhavel e os pontos
## de interacao permanecam colados ao piso desenhado em qualquer resolucao.
##
## Este script cuida apenas de enquadramento. Nao ha logica de jogo aqui.

const BASE_SIZE := Vector2(1920.0, 1080.0)

@onready var _walkable: CollisionPolygon2D = $WorldBounds/WalkableCollision
@onready var _character_layer: Node2D = $CharacterLayer
@onready var _food_point: Marker2D = $InteractionPoints/FoodPoint
@onready var _push_ups_point: Marker2D = $InteractionPoints/PushUpsPoint
@onready var _dumbbells_point: Marker2D = $InteractionPoints/DumbbellsPoint
@onready var _rest_point: Marker2D = $InteractionPoints/RestPoint


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()
	_configure_characters()


## Entrega a cada personagem de `CharacterLayer` a area caminhavel e os tres pontos de
## interacao, convertidos para o espaco de coordenadas do proprio `CharacterLayer`.
##
## O ambiente e quem conhece a geometria; o personagem apenas recebe. Assim Caramelo nao
## precisa procurar nada com caminhos frageis do tipo `../../WorldBounds`, e a checagem
## por `has_method` evita que o quintal dependa do tipo do personagem.
## Posicao de um ponto de interacao no espaco de `CharacterLayer`, por nome do marcador.
## E assim que o sistema de exercicios descobre para onde mandar Caramelo.
func get_interaction_point(point_name: StringName) -> Variant:
	var marker := $InteractionPoints.get_node_or_null(NodePath(String(point_name))) as Marker2D
	if marker == null:
		return null
	return _character_layer.get_global_transform().affine_inverse() * marker.global_position


func _configure_characters() -> void:
	var to_layer := _character_layer.get_global_transform().affine_inverse()
	var from_walkable := to_layer * _walkable.get_global_transform()
	var polygon := PackedVector2Array()
	for point in _walkable.polygon:
		polygon.append(from_walkable * point)
	for character in _character_layer.get_children():
		if character.has_method("set_walkable_polygon"):
			character.call("set_walkable_polygon", polygon)
		if character.has_method("set_interaction_points"):
			# O ponto de treino entregue aqui e apenas o padrao. Cada exercicio tem o seu
			# proprio marcador, e o sistema de exercicios passa o destino exato no pedido.
			character.call("set_interaction_points",
				to_layer * _food_point.global_position,
				to_layer * _push_ups_point.global_position,
				to_layer * _rest_point.global_position)


func _fit_to_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var factor: float = maxf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)
	scale = Vector2(factor, factor)
	position = (viewport_size - BASE_SIZE * factor) * 0.5
