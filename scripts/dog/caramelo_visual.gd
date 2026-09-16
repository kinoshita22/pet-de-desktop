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
const STYLE_DUMBBELLS := &"dumbbells"

var _state: int = Caramelo.State.IDLE
var _time := 0.0
var _facing := 1
## 0 = de pe, 1 = deitado. Interpolado para que deitar e levantar sejam graduais.
var _lie := 0.0
## Estilo do treino em curso. So muda a pose — nunca duracao nem recompensa.
var _training_style: StringName = &""
## Marca a proxima alegria como comica: pulo mais alto e um giro. Puramente visual.
var _comic := false

@onready var _tail: Node2D = $Tail
@onready var _legs_front: Node2D = $LegsFront
@onready var _legs_back: Node2D = $LegsBack
@onready var _head: Node2D = $Head
@onready var _head_rest: Vector2 = $Head.position
@onready var _dumbbell: Node2D = $Dumbbell
@onready var _dumbbell_rest: Vector2 = $Dumbbell.position


## Chamado pelo controlador antes do treino comecar.
func set_training_style(style: StringName) -> void:
	_training_style = style


## Marca a proxima entrada em `HAPPY` como reacao comica.
func play_comic_reaction() -> void:
	_comic = true


## Chamado pelo controlador a cada transicao aceita.
func play_state(state: int) -> void:
	# A reacao comica vale para uma alegria so: sai de cena assim que ela termina.
	if _state == Caramelo.State.HAPPY and state != Caramelo.State.HAPPY:
		_comic = false
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
	var squash := 0.0

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
			if _training_style == STYLE_DUMBBELLS:
				# Halteres: patas dianteiras sobem e descem com o peso, corpo erguido.
				var lift := sin(_time * 5.0)
				leg_swing = 0.50 * lift
				bob = -4.0 * absf(lift)
				head_offset = Vector2(0.0, -3.0 * absf(lift))
			else:
				# Flexoes: o corpo desce e sobe, sem sair do lugar e sem levantar as patas.
				var press := absf(sin(_time * 4.6))
				squash = -0.20 * press
				leg_swing = -0.18 * press
				head_offset = Vector2(4.0, 12.0 * press)
		Caramelo.State.RESTING:
			breath = BREATH_REST * sin(_time * 1.1)
			tail_swing = 0.10 * sin(_time * 0.9)
		Caramelo.State.HAPPY:
			if _comic:
				bob = -34.0 * absf(sin(_time * 7.5))
				tail_swing = 1.20 * sin(_time * 18.0)
				pitch = 0.32 * sin(_time * 7.5)
			else:
				bob = -22.0 * absf(sin(_time * 6.0))
				tail_swing = 0.90 * sin(_time * 14.0)
				pitch = 0.075 * sin(_time * 6.0)

	# A origem do no fica nas patas, entao encolher em Y assenta o corpo no chao.
	position.y = bob
	rotation = pitch
	scale = Vector2(float(_facing), (1.0 + breath + squash) * (1.0 - _lie * 0.36))

	# O halter so existe enquanto o exercicio dos halteres esta em execucao.
	var lifting := _state == Caramelo.State.TRAINING and _training_style == STYLE_DUMBBELLS
	_dumbbell.visible = lifting
	if lifting:
		_dumbbell.position = _dumbbell_rest + Vector2(0.0, -16.0 * (0.5 + 0.5 * sin(_time * 5.0)))

	_tail.rotation = tail_swing - _lie * 0.35
	_legs_front.rotation = leg_swing * (1.0 - _lie)
	_legs_back.rotation = -leg_swing * (1.0 - _lie)
	_head.position = _head_rest + head_offset + Vector2(0.0, _lie * 6.0)
	_head.rotation = _lie * 0.18 + head_offset.y * 0.012
