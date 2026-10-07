extends RefCounted

static func pooled(pairs: Array) -> Dictionary:
	var numerator := [0, 0]
	var denominator := [0, 0]
	for pair in pairs:
		for version in range(2):
			numerator[version] += int(pair[version]["joint_skills_numerator"])
			denominator[version] += int(pair[version]["eligible_rounds_denominator"])
	var rates: Array = [null, null]
	for version in range(2):
		if denominator[version] > 0: rates[version] = float(numerator[version]) / denominator[version]
	return {"numerators": numerator, "denominators": denominator, "rates": rates, "difference": null if rates[0] == null or rates[1] == null else rates[0] - rates[1]}

static func bootstrap(pairs: Array, seed_value := 991, repetitions := 2000, confidence := 0.975) -> Dictionary:
	var result := pooled(pairs)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var differences: Array[float] = []
	for _i in range(repetitions):
		var sample: Array = []
		for _j in range(pairs.size()):
			sample.append(pairs[rng.randi_range(0, pairs.size() - 1)])
		var estimate := pooled(sample)
		if estimate["difference"] != null: differences.append(float(estimate["difference"]))
	differences.sort()
	result["bootstrap_valid"] = differences.size()
	result["bootstrap_undefined"] = repetitions - differences.size()
	result["seed_pairs"] = pairs.size()
	result["confidence"] = confidence
	if not differences.is_empty():
		var tail := (1.0 - confidence) / 2.0
		result["interval"] = [differences[clampi(floori(tail * differences.size()), 0, differences.size() - 1)], differences[clampi(ceili((1.0 - tail) * differences.size()) - 1, 0, differences.size() - 1)]]
	else: result["interval"] = null
	return result
