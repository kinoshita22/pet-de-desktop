class_name BodyForms
extends RefCounted
## Geometria das duas formas de Caramelo, gerada a partir das mesmas primitivas.
##
## O `MVP_SPEC.md` secao 15 fixa **exatamente duas formas**: inicial nos niveis 1-3 e
## musculosa nos 4-5. O nivel 5 nao cria uma terceira — ele reaproveita a musculosa.
##
## O que muda entre elas: largura do peito, volume do ombro, espessura das patas,
## postura e silhueta. O que **nao** muda: cor, cabeca, focinho, orelhas, olho, nariz,
## cauda e coleira — a identidade do personagem sai inteira do mesmo lugar.
##
## Tudo aqui e dado. Nenhuma verificacao de nivel mora nas partes do desenho: o visual
## troca o conjunto inteiro de uma vez.

enum Form { INITIAL, MUSCULAR }

const FORM_NAMES: Array = ["INITIAL", "MUSCULAR"]

static var INITIAL := {
	"Shadow": PackedVector2Array([Vector2(35.7, -2.5), Vector2(34.6, -0.5), Vector2(31.5, 1.5), Vector2(26.4, 3.3), Vector2(19.7, 4.8), Vector2(11.6, 5.9), Vector2(2.7, 6.6), Vector2(-6.8, 6.8), Vector2(-16.3, 6.6), Vector2(-25.2, 5.9), Vector2(-33.3, 4.8), Vector2(-40.0, 3.3), Vector2(-45.1, 1.5), Vector2(-48.2, -0.5), Vector2(-49.3, -2.5), Vector2(-48.2, -4.6), Vector2(-45.1, -6.6), Vector2(-40.0, -8.4), Vector2(-33.3, -9.9), Vector2(-25.2, -11.0), Vector2(-16.3, -11.7), Vector2(-6.8, -11.9), Vector2(2.7, -11.7), Vector2(11.6, -11.0), Vector2(19.7, -9.9), Vector2(26.4, -8.4), Vector2(31.5, -6.6), Vector2(34.6, -4.6)]),
	"Tail/TailShape": PackedVector2Array([Vector2(2.0, -7.4), Vector2(-0.9, -7.8), Vector2(-3.4, -8.3), Vector2(-5.7, -8.9), Vector2(-7.8, -9.7), Vector2(-9.9, -10.7), Vector2(-11.8, -11.8), Vector2(-13.6, -13.1), Vector2(-15.3, -14.7), Vector2(-16.9, -16.5), Vector2(-18.4, -18.5), Vector2(-19.8, -20.8), Vector2(-21.0, -23.4), Vector2(-22.1, -26.2), Vector2(-23.0, -29.3), Vector2(-28.0, -28.5), Vector2(-27.8, -25.0), Vector2(-27.3, -21.6), Vector2(-26.6, -18.3), Vector2(-25.7, -15.1), Vector2(-24.5, -12.1), Vector2(-23.0, -9.2), Vector2(-21.2, -6.4), Vector2(-19.2, -3.8), Vector2(-16.9, -1.4), Vector2(-14.4, 0.8), Vector2(-11.6, 2.8), Vector2(-8.5, 4.6), Vector2(-5.2, 6.1), Vector2(-2.0, 7.4)]),
	"LegsBack/LegBackFar": PackedVector2Array([Vector2(-15.7, 25.1), Vector2(-15.6, 27.1), Vector2(-15.0, 29.0), Vector2(-13.7, 30.6), Vector2(-12.1, 31.7), Vector2(-10.2, 32.2), Vector2(-8.2, 32.2), Vector2(-6.3, 31.5), Vector2(-4.7, 30.3), Vector2(-3.6, 28.7), Vector2(-3.0, 26.8), Vector2(0.4, 0.8), Vector2(0.3, -1.2), Vector2(-0.3, -3.0), Vector2(-1.6, -4.6), Vector2(-3.2, -5.8), Vector2(-5.1, -6.3), Vector2(-7.1, -6.3), Vector2(-9.0, -5.6), Vector2(-10.6, -4.4), Vector2(-11.7, -2.7), Vector2(-12.3, -0.8)]),
	"LegsBack/LegBackNear": PackedVector2Array([Vector2(-1.3, 25.5), Vector2(-1.1, 27.5), Vector2(-0.3, 29.3), Vector2(1.0, 30.8), Vector2(2.7, 31.8), Vector2(4.7, 32.3), Vector2(6.7, 32.1), Vector2(8.5, 31.3), Vector2(10.0, 30.0), Vector2(11.0, 28.3), Vector2(11.5, 26.3), Vector2(13.2, 0.4), Vector2(13.0, -1.6), Vector2(12.2, -3.4), Vector2(10.9, -4.9), Vector2(9.2, -5.9), Vector2(7.2, -6.4), Vector2(5.2, -6.2), Vector2(3.4, -5.4), Vector2(1.9, -4.1), Vector2(0.9, -2.4), Vector2(0.4, -0.4)]),
	"Body/Torso": PackedVector2Array([Vector2(28.9, -47.6), Vector2(27.9, -42.9), Vector2(25.0, -38.4), Vector2(20.4, -34.4), Vector2(14.2, -31.0), Vector2(6.8, -28.5), Vector2(-1.5, -26.9), Vector2(-10.2, -26.3), Vector2(-18.9, -26.9), Vector2(-27.2, -28.5), Vector2(-34.6, -31.0), Vector2(-40.8, -34.4), Vector2(-45.4, -38.4), Vector2(-48.3, -42.9), Vector2(-49.3, -47.6), Vector2(-48.3, -52.3), Vector2(-45.4, -56.8), Vector2(-40.8, -60.8), Vector2(-34.6, -64.2), Vector2(-27.2, -66.7), Vector2(-18.9, -68.3), Vector2(-10.2, -68.8), Vector2(-1.5, -68.3), Vector2(6.8, -66.7), Vector2(14.2, -64.2), Vector2(20.4, -60.8), Vector2(25.0, -56.8), Vector2(27.9, -52.3)]),
	"Body/Belly": PackedVector2Array([Vector2(14.4, -37.4), Vector2(13.7, -35.1), Vector2(11.7, -33.0), Vector2(8.3, -31.0), Vector2(3.9, -29.4), Vector2(-1.4, -28.2), Vector2(-7.4, -27.5), Vector2(-13.6, -27.2), Vector2(-19.8, -27.5), Vector2(-25.8, -28.2), Vector2(-31.1, -29.4), Vector2(-35.5, -31.0), Vector2(-38.9, -33.0), Vector2(-40.9, -35.1), Vector2(-41.6, -37.4), Vector2(-40.9, -39.7), Vector2(-38.9, -41.8), Vector2(-35.5, -43.8), Vector2(-31.1, -45.4), Vector2(-25.8, -46.6), Vector2(-19.8, -47.3), Vector2(-13.6, -47.6), Vector2(-7.4, -47.3), Vector2(-1.4, -46.6), Vector2(3.9, -45.4), Vector2(8.3, -43.8), Vector2(11.7, -41.8), Vector2(13.7, -39.7)]),
	"LegsFront/LegFrontFar": PackedVector2Array([Vector2(-11.5, 26.3), Vector2(-11.0, 28.3), Vector2(-10.0, 30.0), Vector2(-8.5, 31.3), Vector2(-6.7, 32.1), Vector2(-4.7, 32.3), Vector2(-2.7, 31.8), Vector2(-1.0, 30.8), Vector2(0.3, 29.3), Vector2(1.1, 27.5), Vector2(1.3, 25.5), Vector2(-0.4, -0.4), Vector2(-0.9, -2.4), Vector2(-1.9, -4.1), Vector2(-3.4, -5.4), Vector2(-5.2, -6.2), Vector2(-7.2, -6.4), Vector2(-9.2, -5.9), Vector2(-10.9, -4.9), Vector2(-12.2, -3.4), Vector2(-13.0, -1.6), Vector2(-13.2, 0.4)]),
	"LegsFront/LegFrontNear": PackedVector2Array([Vector2(3.0, 26.3), Vector2(3.4, 28.3), Vector2(4.4, 30.0), Vector2(5.9, 31.3), Vector2(7.8, 32.1), Vector2(9.8, 32.3), Vector2(11.7, 31.8), Vector2(13.4, 30.8), Vector2(14.7, 29.3), Vector2(15.5, 27.5), Vector2(15.7, 25.5), Vector2(14.0, -0.4), Vector2(13.6, -2.4), Vector2(12.6, -4.1), Vector2(11.1, -5.4), Vector2(9.2, -6.2), Vector2(7.2, -6.4), Vector2(5.3, -5.9), Vector2(3.6, -4.9), Vector2(2.3, -3.4), Vector2(1.5, -1.6), Vector2(1.3, 0.4)]),
	"Collar": PackedVector2Array([Vector2(5.1, -69.7), Vector2(17.8, -62.9), Vector2(12.8, -37.4), Vector2(0.0, -44.2)]),
	"_pivots": {
		"Tail": Vector2(-45.9, -57.8),
		"LegsBack": Vector2(-34.0, -32.3),
		"LegsFront": Vector2(20.4, -32.3),
		"Head": Vector2(22.1, -62.9),
	},
	"_collision": {"position": Vector2(-10.2, -47.6), "radius": 17.0, "height": 66.3},
	"_selection": {"size": Vector2(129.2, 81.6), "position": Vector2(-2.5, -39.1)},
}

static var MUSCULAR := {
	"Shadow": PackedVector2Array([Vector2(39.9, -2.5), Vector2(38.8, -0.3), Vector2(35.3, 1.9), Vector2(29.8, 3.8), Vector2(22.3, 5.4), Vector2(13.5, 6.6), Vector2(3.6, 7.4), Vector2(-6.8, 7.6), Vector2(-17.2, 7.4), Vector2(-27.1, 6.6), Vector2(-35.9, 5.4), Vector2(-43.4, 3.8), Vector2(-48.9, 1.9), Vector2(-52.4, -0.3), Vector2(-53.5, -2.5), Vector2(-52.4, -4.8), Vector2(-48.9, -7.0), Vector2(-43.4, -8.9), Vector2(-35.9, -10.5), Vector2(-27.1, -11.7), Vector2(-17.2, -12.5), Vector2(-6.8, -12.8), Vector2(3.6, -12.5), Vector2(13.5, -11.7), Vector2(22.3, -10.5), Vector2(29.8, -8.9), Vector2(35.3, -7.0), Vector2(38.8, -4.8)]),
	"Tail/TailShape": PackedVector2Array([Vector2(2.0, -7.4), Vector2(-0.9, -7.8), Vector2(-3.4, -8.3), Vector2(-5.7, -8.9), Vector2(-7.8, -9.7), Vector2(-9.9, -10.7), Vector2(-11.8, -11.8), Vector2(-13.6, -13.1), Vector2(-15.3, -14.7), Vector2(-16.9, -16.5), Vector2(-18.4, -18.5), Vector2(-19.8, -20.8), Vector2(-21.0, -23.4), Vector2(-22.1, -26.2), Vector2(-23.0, -29.3), Vector2(-28.0, -28.5), Vector2(-27.8, -25.0), Vector2(-27.3, -21.6), Vector2(-26.6, -18.3), Vector2(-25.7, -15.1), Vector2(-24.5, -12.1), Vector2(-23.0, -9.2), Vector2(-21.2, -6.4), Vector2(-19.2, -3.8), Vector2(-16.9, -1.4), Vector2(-14.4, 0.8), Vector2(-11.6, 2.8), Vector2(-8.5, 4.6), Vector2(-5.2, 6.1), Vector2(-2.0, 7.4)]),
	"LegsBack/LegBackFar": PackedVector2Array([Vector2(-16.9, 23.2), Vector2(-16.9, 25.6), Vector2(-16.1, 27.8), Vector2(-14.7, 29.7), Vector2(-12.7, 31.1), Vector2(-10.4, 31.8), Vector2(-8.0, 31.8), Vector2(-5.8, 31.0), Vector2(-3.8, 29.5), Vector2(-2.5, 27.6), Vector2(-1.8, 25.3), Vector2(1.6, 1.1), Vector2(1.6, -1.3), Vector2(0.8, -3.6), Vector2(-0.6, -5.5), Vector2(-2.6, -6.9), Vector2(-4.9, -7.6), Vector2(-7.3, -7.5), Vector2(-9.5, -6.8), Vector2(-11.5, -5.3), Vector2(-12.8, -3.4), Vector2(-13.5, -1.1)]),
	"LegsBack/LegBackNear": PackedVector2Array([Vector2(-2.5, 23.7), Vector2(-2.3, 26.1), Vector2(-1.4, 28.3), Vector2(0.2, 30.1), Vector2(2.2, 31.3), Vector2(4.6, 31.9), Vector2(6.9, 31.6), Vector2(9.2, 30.7), Vector2(11.0, 29.1), Vector2(12.2, 27.1), Vector2(12.7, 24.8), Vector2(14.4, 0.5), Vector2(14.2, -1.8), Vector2(13.3, -4.1), Vector2(11.7, -5.9), Vector2(9.7, -7.1), Vector2(7.3, -7.6), Vector2(5.0, -7.4), Vector2(2.7, -6.5), Vector2(0.9, -4.9), Vector2(-0.3, -2.9), Vector2(-0.8, -0.5)]),
	"Body/Torso": PackedVector2Array([Vector2(43.4, -49.3), Vector2(42.2, -44.9), Vector2(38.8, -40.7), Vector2(33.5, -36.8), Vector2(26.5, -33.3), Vector2(18.3, -30.3), Vector2(9.6, -28.0), Vector2(0.7, -26.4), Vector2(-7.9, -25.6), Vector2(-15.8, -25.6), Vector2(-23.5, -26.4), Vector2(-30.8, -28.0), Vector2(-37.5, -30.3), Vector2(-43.3, -33.3), Vector2(-48.0, -36.8), Vector2(-51.5, -40.7), Vector2(-53.7, -44.9), Vector2(-54.4, -49.3), Vector2(-53.7, -53.7), Vector2(-51.5, -57.9), Vector2(-48.0, -61.8), Vector2(-43.3, -65.3), Vector2(-37.5, -68.3), Vector2(-30.8, -70.6), Vector2(-23.5, -72.2), Vector2(-15.8, -73.0), Vector2(-7.9, -73.7), Vector2(0.7, -74.2), Vector2(9.6, -73.5), Vector2(18.3, -71.4), Vector2(26.5, -68.0), Vector2(33.5, -63.7), Vector2(38.8, -58.9), Vector2(42.2, -53.9)]),
	"Body/Belly": PackedVector2Array([Vector2(15.3, -37.4), Vector2(14.5, -34.9), Vector2(12.3, -32.6), Vector2(8.6, -30.5), Vector2(3.8, -28.8), Vector2(-2.0, -27.4), Vector2(-8.5, -26.6), Vector2(-15.3, -26.3), Vector2(-22.1, -26.6), Vector2(-28.6, -27.4), Vector2(-34.4, -28.8), Vector2(-39.2, -30.5), Vector2(-42.9, -32.6), Vector2(-45.1, -34.9), Vector2(-45.9, -37.4), Vector2(-45.1, -39.9), Vector2(-42.9, -42.2), Vector2(-39.2, -44.3), Vector2(-34.4, -46.0), Vector2(-28.6, -47.4), Vector2(-22.1, -48.2), Vector2(-15.3, -48.4), Vector2(-8.5, -48.2), Vector2(-2.0, -47.4), Vector2(3.8, -46.0), Vector2(8.6, -44.3), Vector2(12.3, -42.2), Vector2(14.5, -39.9)]),
	"LegsFront/LegFrontFar": PackedVector2Array([Vector2(-14.0, 24.8), Vector2(-13.4, 27.6), Vector2(-11.9, 30.0), Vector2(-9.8, 31.8), Vector2(-7.3, 32.9), Vector2(-4.5, 33.1), Vector2(-1.8, 32.5), Vector2(0.6, 31.1), Vector2(2.5, 29.0), Vector2(3.6, 26.4), Vector2(3.8, 23.6), Vector2(2.1, -0.6), Vector2(1.5, -3.3), Vector2(0.0, -5.7), Vector2(-2.1, -7.6), Vector2(-4.6, -8.7), Vector2(-7.4, -8.9), Vector2(-10.1, -8.3), Vector2(-12.5, -6.8), Vector2(-14.4, -4.7), Vector2(-15.5, -2.2), Vector2(-15.7, 0.6)]),
	"LegsFront/LegFrontNear": PackedVector2Array([Vector2(0.4, 24.8), Vector2(1.1, 27.6), Vector2(2.5, 30.0), Vector2(4.6, 31.8), Vector2(7.2, 32.9), Vector2(10.0, 33.1), Vector2(12.7, 32.5), Vector2(15.1, 31.1), Vector2(16.9, 29.0), Vector2(18.0, 26.4), Vector2(18.3, 23.6), Vector2(16.6, -0.6), Vector2(15.9, -3.3), Vector2(14.5, -5.7), Vector2(12.4, -7.6), Vector2(9.8, -8.7), Vector2(7.0, -8.9), Vector2(4.3, -8.3), Vector2(1.9, -6.8), Vector2(0.1, -4.7), Vector2(-1.0, -2.2), Vector2(-1.3, 0.6)]),
	"Collar": PackedVector2Array([Vector2(7.6, -73.1), Vector2(20.4, -66.3), Vector2(15.3, -39.9), Vector2(2.5, -46.8)]),
	"_pivots": {
		"Tail": Vector2(-49.3, -59.5),
		"LegsBack": Vector2(-35.7, -33.1),
		"LegsFront": Vector2(22.1, -34.0),
		"Head": Vector2(24.6, -66.3),
	},
	"_collision": {"position": Vector2(-11.9, -49.3), "radius": 20.4, "height": 73.1},
	"_selection": {"size": Vector2(141.1, 88.4), "position": Vector2(-2.5, -42.5)},
}


## Conjunto de geometria de uma forma.
static func geometry(form: int) -> Dictionary:
	return MUSCULAR if form == Form.MUSCULAR else INITIAL


## Forma correspondente a um nivel. **A aparencia e derivada do nivel** — ela nunca e
## persistida nem guardada como segunda fonte de verdade.
static func form_for_level(level: int) -> int:
	return Form.MUSCULAR if level >= 4 else Form.INITIAL


static func form_name(form: int) -> String:
	if form < 0 or form >= FORM_NAMES.size():
		return "DESCONHECIDA"
	return FORM_NAMES[form]
