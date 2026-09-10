class_name DeterministicRng
extends RefCounted

var state: int

func _init(initial_seed: int = 1) -> void:
	state = initial_seed & 0x7fffffff
	if state == 0:
		state = 1

func next_int() -> int:
	state = int((state * 1103515245 + 12345) & 0x7fffffff)
	return state

func randf() -> float:
	return float(next_int()) / 2147483647.0

func range_int(minimum: int, maximum: int) -> int:
	if maximum <= minimum:
		return minimum
	return minimum + (next_int() % (maximum - minimum + 1))

