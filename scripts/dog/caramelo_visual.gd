extends Node2D
## Representacao visual provisoria de Caramelo, montada com poligonos do proprio Godot.
##
## Nao existe arte de cachorro no projeto e esta etapa nao pode criar assets externos.
## A silhueta e feita de `Polygon2D`: corpo, cabeca, orelhas, focinho, coleira, rabo,
## quatro patas e uma sombra — cerca de 143 x 88 px no sistema de coordenadas-base.
##
## Nao ha `AnimationPlayer`. As poses sao funcoes continuas do tempo aplicadas a quatro
## pivos (rabo, patas dianteiras, patas traseiras e cabeca), o que evita manter um
## recurso de animacao com faixas de keyframes que sera descartado assim que a arte
## definitiva chegar. Como sao funcoes continuas e sem sorteio, nao ha tremor nem salto
## entre quadros.
##
## Este no so desenha. Ele nao conhece a area caminhavel, nao decide nada e nao altera
## atributo algum — a logica inteira vive em `caramelo.gd`.

const LIE_SPEED := 2.4
const BREATH_IDLE := 0.018
const BREATH_REST := 0.030

var _state: int = Caramelo.State.IDLE
var _time := 0.0
var _facing := 1
## 0 = de pe, 1 = deitado. Interpolado para que deitar e levantar sejam graduais.
var _lie := 0.0

@onready var _tail: Node2D = $Tail
@onready var _legs_front: Node2D = $LegsFront
@onready var _legs_back: Node2D = $LegsBack
@onready var _head: Node2D = $Head
@onready var _head_rest: Vector2 = $Head.position


## Chamado pelo controlador a cada transicao aceita.
func play_state(state: int) -> void:
	_state = state
	_time = 0.0


## `1` olha para a direita, `-1` para a esquerda.
func set_facing(direction: int) -> void:
	_facing = -1 if direction < 0 else 1


func _process(delta: float) -> void:
	_time += delta
	_lie = move_toward(_lie, 1.0 if _state == Caramelo.State.RESTING else 0.0, delta * LIE_SPEED)

	var bob := 0.0
	var pitch := 0.0
	var leg_swing := 0.0
	var tail_swing := 0.0
	var head_offset := Vector2.ZERO
	var breath := 0.0

	match _state:
		Caramelo.State.IDLE:
			breath = BREATH_IDLE * sin(_time * 2.2)
			tail_swing = 0.22 * sin(_time * 1.9)
		Caramelo.State.WALKING:
			bob = -3.0 * absf(sin(_time * 7.5))
			leg_swing = 0.42 * sin(_time * 7.5)
			tail_swing = 0.40 * sin(_time * 7.5)
			pitch = 0.020 * sin(_time * 7.5)
		Caramelo.State.EATING:
			head_offset = Vector2(5.0, 15.0)
			tail_swing = 0.70 * sin(_time * 9.0)
		Caramelo.State.TRAINING:
			bob = -9.0 * absf(sin(_time * 4.2))
			leg_swing = 0.30 * sin(_time * 8.4)
			head_offset = Vector2(2.0, 5.0)
		Caramelo.State.RESTING:
			breath = BREATH_REST * sin(_time * 1.1)
			tail_swing = 0.10 * sin(_time * 0.9)
		Caramelo.State.HAPPY:
			bob = -22.0 * absf(sin(_time * 6.0))
			tail_swing = 0.90 * sin(_time * 14.0)
			pitch = 0.075 * sin(_time * 6.0)

	# A origem do no fica nas patas, entao encolher em Y assenta o corpo no chao.
	position.y = bob
	rotation = pitch
	scale = Vector2(float(_facing), (1.0 + breath) * (1.0 - _lie * 0.36))

	_tail.rotation = tail_swing - _lie * 0.35
	_legs_front.rotation = leg_swing * (1.0 - _lie)
	_legs_back.rotation = -leg_swing * (1.0 - _lie)
	_head.position = _head_rest + head_offset + Vector2(0.0, _lie * 6.0)
	_head.rotation = _lie * 0.18 + head_offset.y * 0.012
