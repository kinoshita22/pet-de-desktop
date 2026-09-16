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
## Microcomportamento ocioso em execucao. So muda a pose: a posicao logica de Caramelo
## nunca sai do lugar, nem durante `CHASE_FLY`.
var _idle_behavior: int = Caramelo.IdleBehavior.NONE
var _idle_time := 0.0

@onready var _tail: Node2D = $Tail
@onready var _legs_front: Node2D = $LegsFront
@onready var _legs_back: Node2D = $LegsBack
@onready var _head: Node2D = $Head
@onready var _head_rest: Vector2 = $Head.position
@onready var _dumbbell: Node2D = $Dumbbell
@onready var _dumbbell_rest: Vector2 = $Dumbbell.position
@onready var _eye: Polygon2D = $Head/Eye
@onready var _eye_rest: Vector2 = $Head/Eye.scale


## Chamado pelo controlador a cada troca de microcomportamento ocioso.
func play_idle_behavior(behavior: int) -> void:
	_idle_behavior = behavior
	_idle_time = 0.0


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
	_idle_time += delta
	_lie = move_toward(_lie, 1.0 if _state == Caramelo.State.RESTING else 0.0, delta * LIE_SPEED)

	var bob := 0.0
	var pitch := 0.0
	var leg_swing := 0.0
	var tail_swing := 0.0
	var head_offset := Vector2.ZERO
	var breath := 0.0
	var squash := 0.0
	var stretch := 0.0
	var head_turn := 0.0
	var drift := Vector2.ZERO

	match _state:
		Caramelo.State.IDLE:
			breath = BREATH_IDLE * sin(_time * 2.2)
			tail_swing = 0.22 * sin(_time * 1.9)
			# Microcomportamentos: variacoes curtas em cima da pose parada. Nenhum deles
			# altera `position` do controlador — o deslocamento e so do no visual.
			match _idle_behavior:
				Caramelo.IdleBehavior.LOOK_AROUND:
					head_turn = 0.30 * sin(_idle_time * 1.6)
					head_offset = Vector2(0.0, -1.5 * absf(sin(_idle_time * 1.6)))
				Caramelo.IdleBehavior.STRETCH:
					var reach := absf(sin(_idle_time * 1.3))
					stretch = 0.12 * reach
					squash = -0.10 * reach
					head_offset = Vector2(6.0 * reach, 7.0 * reach)
					tail_swing = 0.10 * sin(_idle_time * 1.1)
				Caramelo.IdleBehavior.SNIFF_GROUND:
					head_offset = Vector2(3.0, 13.0 + 1.8 * sin(_idle_time * 7.0))
					head_turn = 0.10 * sin(_idle_time * 5.0)
					tail_swing = 0.18 * sin(_idle_time * 3.0)
				Caramelo.IdleBehavior.TAIL_WAG:
					tail_swing = 0.75 * sin(_idle_time * 11.0)
					pitch = 0.012 * sin(_idle_time * 11.0)
					head_turn = 0.05 * sin(_idle_time * 5.5)
				Caramelo.IdleBehavior.CHASE_FLY:
					# Deslocamento puramente visual, de poucos pixels e sempre em torno
					# da base: o no volta a zero quando o comportamento termina.
					drift = Vector2(9.0 * sin(_idle_time * 2.3), -4.0 * absf(sin(_idle_time * 4.6)))
					bob = -7.0 * absf(sin(_idle_time * 4.6))
					head_turn = 0.26 * sin(_idle_time * 4.6)
					tail_swing = 0.45 * sin(_idle_time * 9.0)
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
			# Deitado, respirando devagar e de olhos fechados. Baixa intensidade de
			# proposito: o jogo passa horas visivel como papel de parede.
			breath = BREATH_REST * sin(_time * 1.1)
			tail_swing = 0.10 * sin(_time * 0.9)
			head_offset = Vector2(2.0, 2.0)
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
	position = Vector2(drift.x * float(_facing), bob + drift.y)
	rotation = pitch
	scale = Vector2(float(_facing) * (1.0 + stretch),
		(1.0 + breath + squash) * (1.0 - _lie * 0.36))

	# Olho quase fechado enquanto dorme.
	_eye.scale = Vector2(_eye_rest.x, _eye_rest.y * (1.0 - _lie * 0.86))

	# O halter so existe enquanto o exercicio dos halteres esta em execucao.
	var lifting := _state == Caramelo.State.TRAINING and _training_style == STYLE_DUMBBELLS
	_dumbbell.visible = lifting
	if lifting:
		_dumbbell.position = _dumbbell_rest + Vector2(0.0, -16.0 * (0.5 + 0.5 * sin(_time * 5.0)))

	_tail.rotation = tail_swing - _lie * 0.35
	_legs_front.rotation = leg_swing * (1.0 - _lie)
	_legs_back.rotation = -leg_swing * (1.0 - _lie)
	_head.position = _head_rest + head_offset + Vector2(0.0, _lie * 6.0)
	_head.rotation = _lie * 0.18 + head_offset.y * 0.012 + head_turn
