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


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func _fit_to_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var factor: float = maxf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)
	scale = Vector2(factor, factor)
	position = (viewport_size - BASE_SIZE * factor) * 0.5
