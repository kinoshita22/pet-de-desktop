class_name OfflineProgress
extends RefCounted
## Reconciliacao do tempo em que o jogo ficou fechado.
##
## E **pura**: nao abre arquivo, nao consulta o relogio e nao conhece cena alguma. Recebe
## o snapshot salvo, a configuracao e o `now_unix` de quem a chamou, e devolve um snapshot
## reconciliado mais um relatorio estruturado. Quem transforma o relatorio em texto e a
## interface; quem le e grava e o `SaveManager`.
##
## As regras vem da secao 17 do `MVP_SPEC.md`: teto de oito horas, nenhuma punicao por
## ausencia, recompensa paga uma unica vez e relogio atrasado tratado como tempo zero.

## Teto de ausencia aplicada, em segundos (8 h). Vem da secao 17 do `MVP_SPEC.md`.
const MAX_ELAPSED_SECONDS := 28800.0


## Reconcilia o snapshot. Devolve
## `{"snapshot": Dictionary, "report": Dictionary}`.
##
## O relatorio traz apenas fatos: quanto tempo passou, o que foi de fato aplicado e o que
## foi cancelado. Ganhos zero nao viram linha.
static func reconcile(snapshot: Dictionary, config: GameConfig, now_unix: int,
		max_energy: int) -> Dictionary:
	var result := snapshot.duplicate(true)
	var report := {
		"elapsed_seconds": 0.0,
		"capped": false,
		"clock_went_backwards": false,
		"energy_restored": 0,
		"bond_gained": 0,
		"strength_gained": 0,
		"meal_completed": "",
		"exercise_completed": "",
		"activity_cancelled": "",
		"activity_resumed": "",
		"foods_ready": [],
		"has_events": false,
	}

	var raw_elapsed := float(now_unix) - float(int(snapshot.get("saved_at_unix", 0)))
	if raw_elapsed < 0.0:
		# Relogio atrasado: zero progresso e **zero punicao**.
		report["clock_went_backwards"] = true
		report["has_events"] = true
		result["saved_at_unix"] = now_unix
		return {"snapshot": result, "report": report}
	var elapsed: float = minf(raw_elapsed, MAX_ELAPSED_SECONDS)
	report["capped"] = raw_elapsed > MAX_ELAPSED_SECONDS
	report["elapsed_seconds"] = elapsed
	if elapsed <= 0.0:
		result["saved_at_unix"] = now_unix
		return {"snapshot": result, "report": report}

	var progression: Dictionary = result["progression"]
	var cooldowns: Dictionary = (result.get("food_cooldowns", {}) as Dictionary).duplicate()
	var before_ready := _ready_foods(cooldowns)

	# 1. As recargas que ja existiam correm durante toda a ausencia.
	for key in cooldowns.keys():
		cooldowns[key] = maxf(0.0, float(cooldowns[key]) - elapsed)

	# 2. A atividade persistida decide quanto da ausencia sobra para o descanso.
	var rest_seconds := elapsed
	var activity: Variant = result.get("activity")
	if activity is Dictionary:
		rest_seconds = _resolve_activity(activity as Dictionary, result, progression, cooldowns,
			config, elapsed, max_energy, report)
	result["activity"] = result.get("activity")

	# 3. O que sobrou vira descanso, na taxa configurada em levels.json.
	if rest_seconds > 0.0:
		_apply_rest(result, progression, rest_seconds, _seconds_per_energy(config),
			max_energy, report)

	result["food_cooldowns"] = cooldowns
	result["saved_at_unix"] = now_unix

	for food_id in _ready_foods(cooldowns):
		if not before_ready.has(food_id):
			(report["foods_ready"] as Array).append(food_id)

	report["has_events"] = int(report["energy_restored"]) > 0 or int(report["bond_gained"]) > 0 \
		or int(report["strength_gained"]) > 0 or not (report["foods_ready"] as Array).is_empty() \
		or String(report["meal_completed"]) != "" or String(report["exercise_completed"]) != "" \
		or bool(report["clock_went_backwards"])
	return {"snapshot": result, "report": report}


static func _ready_foods(cooldowns: Dictionary) -> Array:
	var ready: Array = []
	for key in cooldowns:
		if float(cooldowns[key]) <= 0.0:
			ready.append(String(key))
	return ready


## Resolve a atividade salva e devolve quantos segundos sobram para descanso.
static func _resolve_activity(activity: Dictionary, result: Dictionary, progression: Dictionary,
		cooldowns: Dictionary, config: GameConfig, elapsed: float, max_energy: int,
		report: Dictionary) -> float:
	var type := String(activity.get("type", ""))
	var phase := String(activity.get("phase", ""))
	var content_id := StringName(String(activity.get("content_id", "")))
	var remaining := float(activity.get("remaining_seconds", 0.0))

	# Reservada ou a caminho: nada foi cobrado e nada e concedido. A reserva e desfeita.
	if phase != "running" or type == "rest":
		result["activity"] = null
		if type != "rest":
			report["activity_cancelled"] = type
		return elapsed

	if bool(activity.get("reward_already_applied", false)):
		result["activity"] = null
		return elapsed

	if elapsed < remaining:
		# Nao terminou: guarda so o tempo que falta e retoma quando o jogo abrir.
		activity["remaining_seconds"] = remaining - elapsed
		result["activity"] = activity
		report["activity_resumed"] = type
		return 0.0

	# Terminou durante a ausencia. O momento logico da conclusao e `remaining` segundos
	# depois da abertura da ausencia; o resto do tempo vira descanso.
	var leftover := elapsed - remaining
	result["activity"] = null
	match type:
		"feeding":
			var food := config.get_food(content_id)
			if not food.is_empty():
				var energy := int(progression["energy"])
				var applied: int = mini(int(food["energy"]), max_energy - energy)
				progression["energy"] = energy + applied
				progression["bond"] = int(progression["bond"]) + int(food["bond"])
				report["energy_restored"] = int(report["energy_restored"]) + applied
				report["bond_gained"] = int(report["bond_gained"]) + int(food["bond"])
				report["meal_completed"] = String(food["display_name"])
				# A recarga comeca na conclusao e corre so pelo tempo posterior a ela.
				cooldowns[String(content_id)] = maxf(0.0, float(food["cooldown_seconds"]) - leftover)
		"exercise":
			var exercise := config.get_exercise(content_id)
			if not exercise.is_empty():
				# A energia ja saiu ao entrar em `TRAINING`; nao se cobra de novo.
				progression["strength"] = int(progression["strength"]) + int(exercise["strength_gain"])
				report["strength_gained"] = int(exercise["strength_gain"])
				report["exercise_completed"] = String(exercise["display_name"])
	return leftover


## Converte tempo de descanso em energia, respeitando o acumulador fracionario e o teto.
static func _seconds_per_energy(config: GameConfig) -> float:
	var rest := config.get_rest() if config != null else {}
	var rate := float(rest.get("energy_per_minute", 1.0))
	return 60.0 / maxf(rate, 0.0001)


static func _apply_rest(result: Dictionary, progression: Dictionary, seconds: float,
		seconds_per_energy: float, max_energy: int, report: Dictionary) -> void:
	var rest_config := result.get("rest", {}) as Dictionary
	var accumulated := float(rest_config.get("accumulated_seconds", 0.0))
	var energy := int(progression["energy"])
	if energy >= max_energy:
		# Ja cheio: o tempo passa sem virar credito guardado.
		rest_config["accumulated_seconds"] = 0.0
		result["rest"] = rest_config
		return

	accumulated += seconds
	var units := int(floor(accumulated / seconds_per_energy))
	if units > 0:
		var applied: int = mini(units, max_energy - energy)
		progression["energy"] = energy + applied
		report["energy_restored"] = int(report["energy_restored"]) + applied
		if applied < units:
			# Encheu no meio: o excedente daquele periodo e descartado.
			accumulated = 0.0
		else:
			accumulated -= float(units) * seconds_per_energy
	rest_config["accumulated_seconds"] = accumulated
	result["rest"] = rest_config


## Duracao curta e legivel, do jeito que o resumo mostra.
static func format_duration(seconds: float) -> String:
	var total := int(round(maxf(seconds, 0.0)))
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	if hours > 0 and minutes > 0:
		return "%dh %dmin" % [hours, minutes]
	if hours > 0:
		return "%dh" % hours
	if minutes > 0:
		return "%dmin" % minutes
	return "%ds" % total
