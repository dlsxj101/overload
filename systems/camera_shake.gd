class_name DirectionalCameraShake
extends Node

var _offset := Vector2.ZERO
var _elapsed := 0.0
var _duration := 0.0
var _active := false
var _g0_enabled := true


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed = minf(_elapsed + delta, _duration)
	var progress := _elapsed / _duration
	var return_weight := pow(1.0 - progress, 3.0)
	get_viewport().canvas_transform = Transform2D(0.0, _offset * return_weight)
	if _elapsed >= _duration:
		_active = false
		get_viewport().canvas_transform = Transform2D.IDENTITY


func kick(direction: Vector2, distance: float, return_time: float) -> void:
	if not _g0_enabled:
		get_viewport().canvas_transform = Transform2D.IDENTITY
		return
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_offset = safe_direction * distance
	_elapsed = 0.0
	_duration = maxf(return_time, 0.001)
	_active = true
	get_viewport().canvas_transform = Transform2D(0.0, _offset)


func _exit_tree() -> void:
	if get_viewport() != null:
		get_viewport().canvas_transform = Transform2D.IDENTITY


func set_g0_enabled(enabled: bool) -> void:
	_g0_enabled = enabled
	if enabled:
		return
	_active = false
	get_viewport().canvas_transform = Transform2D.IDENTITY
