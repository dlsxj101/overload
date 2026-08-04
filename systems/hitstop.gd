class_name Hitstop
extends Node

signal finished(measured_seconds: float, had_buffered_attack: bool)

var last_measured_duration := 0.0
var _active := false
var _started_usec := 0
var _finish_usec := 0
var _buffered_attack := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not _active or Time.get_ticks_usec() < _finish_usec:
		return

	_active = false
	last_measured_duration = float(Time.get_ticks_usec() - _started_usec) / 1_000_000.0
	get_tree().paused = false
	var had_buffer := _buffered_attack
	_buffered_attack = false
	finished.emit(last_measured_duration, had_buffer)


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_buffered_attack = true
		get_viewport().set_input_as_handled()


func begin(duration_seconds: float) -> void:
	if _active or duration_seconds <= 0.0:
		return
	_active = true
	_buffered_attack = false
	_started_usec = Time.get_ticks_usec()
	_finish_usec = _started_usec + int(duration_seconds * 1_000_000.0)
	get_tree().paused = true


func is_active() -> bool:
	return _active


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false
