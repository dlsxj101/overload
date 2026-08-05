class_name PlayerController
extends Node2D

enum AttackPhase { IDLE, WINDUP, SWING }

const PLAYER_RADIUS := 20.0
const PLAYER_SPEED := 245.0
const BODY_COLOR := Color.WHITE
const BODY_CORE_COLOR := Color("18242c")
const TRAIL_COLOR := Color(0.0, 0.898, 0.816, 0.26)

var _tuning: JuiceTuning
var _combat: CombatSystem
var _hitstop: Hitstop
var _combo: ComboSystem
var _arena_center := Vector2.ZERO
var _arena_radius := 0.0
var _aim_angle := 0.0
var _attack_aim_angle := 0.0
var _attack_elapsed := 0.0
var _attack_windup_time := 0.0
var _cooldown_remaining := 0.0
var _previous_swing_angle := 0.0
var _attack_hit_registered := false
var _attack_queued := false
var _phase := AttackPhase.IDLE
var _afterimage_angles: Array[float] = []
var _afterimage_reaches: Array[float] = []
var _afterimage_lifetimes: Array[float] = []


func configure(
	tuning_resource: JuiceTuning,
	combat: CombatSystem,
	hitstop: Hitstop,
	combo: ComboSystem,
	arena_center: Vector2,
	arena_radius: float
) -> void:
	_tuning = tuning_resource
	_combat = combat
	_hitstop = hitstop
	_combo = combo
	_arena_center = arena_center
	_arena_radius = arena_radius
	_hitstop.finished.connect(_on_hitstop_finished)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_attack_queued = true
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_afterimages(delta)
	_update_movement(delta)
	_update_aim()
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)

	match _phase:
		AttackPhase.IDLE:
			if _attack_queued and _cooldown_remaining <= 0.0:
				_begin_attack()
		AttackPhase.WINDUP:
			_update_windup(delta)
		AttackPhase.SWING:
			_update_swing(delta)
	queue_redraw()


func _update_movement(delta: float) -> void:
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += movement * PLAYER_SPEED * delta
	var center_offset := position - _arena_center
	var maximum_distance := _arena_radius - PLAYER_RADIUS
	if center_offset.length_squared() > maximum_distance * maximum_distance:
		position = _arena_center + center_offset.normalized() * maximum_distance


func _update_aim() -> void:
	var mouse_offset := get_global_mouse_position() - global_position
	if not mouse_offset.is_zero_approx():
		_aim_angle = mouse_offset.angle()


func _begin_attack() -> void:
	_attack_queued = false
	_attack_hit_registered = false
	_attack_elapsed = 0.0
	_attack_windup_time = _combo.get_windup_time()
	_attack_aim_angle = _aim_angle
	_previous_swing_angle = -deg_to_rad(_tuning.sword_arc_degrees) * 0.5
	_cooldown_remaining = _tuning.attack_cooldown
	_phase = AttackPhase.WINDUP


func _update_windup(delta: float) -> void:
	_attack_elapsed += delta
	if _attack_elapsed < _attack_windup_time:
		return
	_attack_elapsed = 0.0
	_phase = AttackPhase.SWING


func _update_swing(delta: float) -> void:
	_attack_elapsed = minf(_attack_elapsed + delta, _tuning.swing_time)
	var progress := _attack_elapsed / maxf(_tuning.swing_time, 0.001)
	var half_arc := deg_to_rad(_tuning.sword_arc_degrees) * 0.5
	var current_swing_angle := lerpf(-half_arc, half_arc, progress)
	var effective_reach := get_effective_sword_reach()
	if _combo.current_tier >= 2:
		_record_afterimage(_attack_aim_angle + _previous_swing_angle, effective_reach)

	if not _attack_hit_registered:
		_attack_hit_registered = _combat.perform_sweep(
			global_position,
			_attack_aim_angle,
			_previous_swing_angle,
			current_swing_angle,
			effective_reach
		)
	_previous_swing_angle = current_swing_angle

	if _attack_elapsed >= _tuning.swing_time:
		_phase = AttackPhase.IDLE
		_attack_elapsed = 0.0


func _draw() -> void:
	_draw_afterimages()
	var facing := Vector2.from_angle(_aim_angle)
	var side := facing.orthogonal()
	var body_points := PackedVector2Array([
		facing * PLAYER_RADIUS,
		-side * PLAYER_RADIUS * 0.72 - facing * PLAYER_RADIUS * 0.72,
		side * PLAYER_RADIUS * 0.72 - facing * PLAYER_RADIUS * 0.72,
	])
	draw_colored_polygon(body_points, BODY_COLOR)
	draw_circle(Vector2.ZERO, PLAYER_RADIUS * 0.42, BODY_CORE_COLOR)

	if _phase == AttackPhase.IDLE:
		return
	var sword_scale := _combo.get_sword_scale()
	var effective_reach := get_effective_sword_reach()
	var sword_angle := _current_sword_angle()
	if _phase == AttackPhase.SWING:
		var half_arc := deg_to_rad(_tuning.sword_arc_degrees) * 0.5
		draw_arc(Vector2.ZERO, effective_reach * 0.88, _attack_aim_angle - half_arc, sword_angle, 28, TRAIL_COLOR, 10.0 * sword_scale, true)
	var sword_direction := Vector2.from_angle(sword_angle)
	var blade_start := sword_direction * PLAYER_RADIUS * 0.62
	var blade_end := sword_direction * effective_reach
	if _combo.current_tier >= 1:
		draw_line(
			blade_start,
			blade_end,
			Color(0.0, 0.898, 0.816, _tuning.blade_glow_opacity),
			_tuning.blade_glow_width * sword_scale,
			true
		)
	draw_line(blade_start, blade_end, Color("081015"), 10.0 * sword_scale, true)
	draw_line(blade_start, blade_end, Color.WHITE, 5.0 * sword_scale, true)
	draw_circle(blade_end, 3.2 * sword_scale, Color("00e5d0"))


func _current_sword_angle() -> float:
	var half_arc := deg_to_rad(_tuning.sword_arc_degrees) * 0.5
	if _phase == AttackPhase.WINDUP:
		var progress := clampf(_attack_elapsed / maxf(_attack_windup_time, 0.001), 0.0, 1.0)
		return _attack_aim_angle + lerpf(0.0, -half_arc, ease(progress, 2.0))
	var swing_progress := clampf(_attack_elapsed / maxf(_tuning.swing_time, 0.001), 0.0, 1.0)
	return _attack_aim_angle + lerpf(-half_arc, half_arc, swing_progress)


func get_effective_sword_reach() -> float:
	return _tuning.sword_reach * _combo.get_sword_scale()


func _record_afterimage(angle: float, reach: float) -> void:
	_afterimage_angles.append(angle)
	_afterimage_reaches.append(reach)
	_afterimage_lifetimes.append(_tuning.afterimage_lifetime)
	while _afterimage_angles.size() > _tuning.afterimage_max_count:
		_afterimage_angles.pop_front()
		_afterimage_reaches.pop_front()
		_afterimage_lifetimes.pop_front()


func _update_afterimages(delta: float) -> void:
	for index in range(_afterimage_angles.size() - 1, -1, -1):
		_afterimage_lifetimes[index] -= delta
		if _afterimage_lifetimes[index] <= 0.0:
			_afterimage_angles.remove_at(index)
			_afterimage_reaches.remove_at(index)
			_afterimage_lifetimes.remove_at(index)
	if not _afterimage_angles.is_empty():
		queue_redraw()


func _draw_afterimages() -> void:
	for index in _afterimage_angles.size():
		var life_ratio := _afterimage_lifetimes[index] / maxf(_tuning.afterimage_lifetime, 0.001)
		var direction := Vector2.from_angle(_afterimage_angles[index])
		var blade_start := direction * PLAYER_RADIUS * 0.62
		var blade_end := direction * _afterimage_reaches[index]
		var width_scale := sqrt(_afterimage_reaches[index] / maxf(_tuning.sword_reach, 0.001))
		draw_line(
			blade_start,
			blade_end,
			Color(0.0, 0.898, 0.816, life_ratio * _tuning.afterimage_opacity),
			5.0 * width_scale,
			true
		)


func _on_hitstop_finished(_measured_seconds: float, had_buffered_attack: bool) -> void:
	if had_buffered_attack:
		_attack_queued = true
