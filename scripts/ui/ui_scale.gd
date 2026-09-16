class_name UiScale
extends RefCounted
## Compensacao de escala comum a toda a interface.
##
## O projeto usa `stretch/aspect = "expand"`, entao o viewport cresce conforme a janela:
## em 640 x 1000 ele vira 1920 x 2849. Um painel de tamanho fixo em unidades do viewport
## encolheria a um terco na tela. Multiplicando as medidas pelo fator daqui, a interface
## ocupa sempre o mesmo espaco fisico.
##
## O fator e aplicado a **tamanhos de fonte e margens**, nunca a `scale` do no: escalar o
## no reamostraria o texto ja rasterizado e ele sairia borrado nas proporcoes extremas.
##
## Nasceu de codigo repetido em `food_menu.gd` e `training_feedback.gd`; agora serve
## tambem ao HUD e ao menu de exercicios.

const MIN_FACTOR := 0.5
const MAX_FACTOR := 8.0


## Quantas unidades de viewport equivalem a um pixel de tela, para este controle.
static func factor_for(control: Control) -> float:
	if control == null or not control.is_inside_tree():
		return 1.0
	var viewport_size := control.get_viewport_rect().size
	var window := control.get_window()
	var window_height := float(window.size.y) if window != null else viewport_size.y
	# viewport.y / janela.y e exatamente o inverso da escala do canvas.
	return clampf(viewport_size.y / maxf(window_height, 1.0), MIN_FACTOR, MAX_FACTOR)


## Ajusta margens, cantos e borda de um `StyleBoxFlat` ao fator. Sem isto o painel
## manteria o texto legivel mas com respiro proporcionalmente errado.
static func scale_stylebox(panel: Control, factor: float, margin := 12.0,
		extra_side := 2.0, radius := 10, border := 2) -> void:
	if panel == null:
		return
	var box := panel.get_theme_stylebox("panel")
	if not (box is StyleBoxFlat):
		return
	var flat := box as StyleBoxFlat
	flat.content_margin_left = (margin + extra_side) * factor
	flat.content_margin_right = (margin + extra_side) * factor
	flat.content_margin_top = margin * factor
	flat.content_margin_bottom = margin * factor
	flat.set_corner_radius_all(roundi(float(radius) * factor))
	flat.set_border_width_all(maxi(1, roundi(float(border) * factor)))
