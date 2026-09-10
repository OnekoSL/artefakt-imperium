extends RefCounted
## Small, shared validator for JSON-shaped data. Returns the first failing field.

static func check(value: Variant, schema: Variant, path: String = "$", depth: int = 0) -> String:
	if depth > 64:
		return path + ": Daten sind zu tief verschachtelt."
	var spec: Dictionary = {"type":schema} if schema is String else schema
	var kind := str(spec.get("type", "json"))
	var valid := true
	match kind:
		"string": valid = value is String or value is StringName
		"bool": valid = value is bool
		"number", "integer":
			valid = (value is int or value is float) and is_finite(float(value))
			if valid and kind == "integer":
				valid = float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0
			if valid:
				valid = float(value) >= float(spec.get("min", -INF)) and float(value) <= float(spec.get("max", INF))
		"object", "map": valid = value is Dictionary
		"array": valid = value is Array
		"json": valid = value == null or value is String or value is bool or value is int or value is float or value is Dictionary or value is Array
	if not valid:
		return "%s: Erwartet %s mit gültigem Wertebereich." % [path, kind]
	if spec.has("enum") and not (spec.enum as Array).has(value):
		return path + ": Ungültiger Wert."
	if kind == "string" and str(value).length() < int(spec.get("min_length", 0)):
		return path + ": Text darf nicht leer sein."
	if value is float and not is_finite(value):
		return path + ": Zahl muss endlich sein."
	if value is Dictionary:
		var fields: Dictionary = spec.get("fields", {})
		for key: String in spec.get("required", []):
			if not value.has(key):
				return path + "." + key + ": Pflichtfeld fehlt."
		for key: Variant in value:
			if not (key is String or key is StringName):
				return path + ": Objektschlüssel muss Text sein."
			var child: Variant = spec.get("item", "json") if kind == "map" else fields.get(key, "json")
			var error := check(value[key], child, path + "." + key, depth + 1)
			if not error.is_empty():
				return error
	if value is Array:
		if spec.has("size") and value.size() != int(spec.size):
			return "%s: Erwartet %d Einträge." % [path, spec.size]
		for index: int in value.size():
			var error := check(value[index], spec.get("item", "json"), "%s[%d]" % [path, index], depth + 1)
			if not error.is_empty():
				return error
	return ""

static func object(fields: Dictionary, required: Array = []) -> Dictionary:
	return {"type":"object", "fields":fields, "required":required}

static func array(item: Variant, size: int = -1) -> Dictionary:
	var result := {"type":"array", "item":item}
	if size >= 0:
		result["size"] = size
	return result

static func map(item: Variant) -> Dictionary:
	return {"type":"map", "item":item}

static func number(minimum: float = -INF, maximum: float = INF) -> Dictionary:
	return {"type":"number", "min":minimum, "max":maximum}

static func integer(minimum: int = 0, maximum: int = 2147483647) -> Dictionary:
	return {"type":"integer", "min":minimum, "max":maximum}
