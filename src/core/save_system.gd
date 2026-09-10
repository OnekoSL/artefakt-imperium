class_name SaveSystem
extends RefCounted

const SAVE_DIRECTORY := "user://saves"

static func save_game(simulation: GameSimulation, slot: String) -> Dictionary:
	var safe_slot := slot.validate_filename()
	if safe_slot.is_empty():
		return _failure("invalid_slot", "Ungültiger Speicherplatz.")
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY)) != OK:
		return _failure("write_failed", "Speicherverzeichnis konnte nicht erstellt werden.")
	var final_path := SAVE_DIRECTORY.path_join("%s.json" % safe_slot)
	var temporary_path := final_path + ".tmp"
	var backup_path := final_path + ".bak"
	var snapshot := simulation.serialize()
	var validation := GameSimulation.new(simulation.registry).restore(snapshot)
	if not bool(validation.ok):
		return validation
	var contents := JSON.stringify(snapshot, "  ")
	var write_result := _write_verified(temporary_path, contents)
	if not bool(write_result.ok):
		return write_result
	# Keep a verified previous generation before replacing the main file.
	var previous := _read(final_path)
	if bool(previous.ok):
		var previous_validation := GameSimulation.new(simulation.registry).restore(previous.data)
		if bool(previous_validation.ok):
			var backup_result := _write_verified(backup_path + ".tmp", str(previous.text))
			if not bool(backup_result.ok):
				return backup_result
			if _rename(backup_path + ".tmp", backup_path) != OK:
				return _failure("backup_failed", "Sicherung konnte nicht übernommen werden; bisheriger Spielstand bleibt erhalten.")
			var verified_backup := _read(backup_path)
			if not bool(verified_backup.ok) or str(verified_backup.text) != str(previous.text):
				return _failure("backup_failed", "Sicherung konnte nicht verifiziert werden.")
		elif str(previous_validation.get("code", "")) != "corrupt":
			return previous_validation
	elif str(previous.get("code", "")) == "read_failed":
		return previous
	if _rename(temporary_path, final_path) != OK:
		return _failure("replace_failed", "Spielstand konnte nicht übernommen werden. Eine vorhandene Sicherung bleibt ladbar.")
	var final_read := _read(final_path)
	if not bool(final_read.ok) or str(final_read.text) != contents:
		return _failure("write_failed", "Geschriebener Spielstand konnte nicht verifiziert werden.")
	return {"ok":true, "code":"ok", "message":"Spiel gespeichert: %s" % safe_slot}

static func load_game(simulation: GameSimulation, slot: String) -> Dictionary:
	var path := SAVE_DIRECTORY.path_join("%s.json" % slot.validate_filename())
	var primary := _read(path)
	var result: Dictionary = simulation.restore(primary.data) if bool(primary.ok) else primary
	if bool(result.ok):
		result["recovered_from_backup"] = false
		return result
	if str(result.get("code", "")) not in ["missing", "corrupt"]:
		return result
	var backup := _read(path + ".bak")
	if not bool(backup.ok):
		return result
	var recovered := simulation.restore(backup.data)
	if not bool(recovered.ok):
		return recovered
	recovered["recovered_from_backup"] = true
	recovered["message"] = "Sicherung geladen / Backup recovered: %s" % slot.validate_filename()
	return recovered

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("missing", "Kein Spielstand in diesem Slot.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("read_failed", "Spielstand konnte nicht gelesen werden.")
	var contents := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error not in [OK, ERR_FILE_EOF]:
		return _failure("read_failed", "Spielstand konnte nicht vollständig gelesen werden.")
	var json := JSON.new()
	if json.parse(contents) != OK or not json.data is Dictionary:
		return _failure("corrupt", "Spielstand ist beschädigt: %s" % path.get_file())
	return {"ok":true, "data":json.data, "text":contents}

static func _write_verified(path: String, contents: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("write_failed", "Spielstand konnte nicht geschrieben werden.")
	file.store_string(contents)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _failure("write_failed", "Spielstand konnte nicht vollständig geschrieben werden.")
	var reread := _read(path)
	if not bool(reread.ok) or str(reread.text) != contents:
		return _failure("write_failed", "Spielstand konnte nach dem Schreiben nicht verifiziert werden.")
	return {"ok":true}

static func _rename(from_path: String, to_path: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path))

static func _failure(code: String, message: String) -> Dictionary:
	return {"ok":false, "code":code, "message":message}
