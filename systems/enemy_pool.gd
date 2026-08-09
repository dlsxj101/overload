class_name EnemyPool
extends Node2D

const ENEMY_RADIUS := 23.0
const OUTLINE_COLOR := Color("00e5d0")
const BODY_COLOR := Color("05090b")
const FLASH_COLOR := Color.WHITE
const ARC_POINTS := 48

var positions: Array[Vector2] = []
var spawn_positions: Array[Vector2] = []
var knockback_echo_positions: Array[Vector2] = []
var knockback_echo_active: Array[bool] = []
var knockback_directions: Array[Vector2] = []
var knockback_elapsed: Array[float] = []
var knockback_durations: Array[float] = []
var knockback_distances: Array[float] = []
var flash_frames_remaining: Array[int] = []
var _tuning: JuiceTuning
var _g0_render_enabled := true


func configure(tuning_resource: JuiceTuning, spawn_points: Array[Vector2]) -> void:
	_tuning = tuning_resource
	positions = spawn_points.duplicate()
	spawn_positions = spawn_points.duplicate()
	knockback_echo_positions = spawn_points.duplicate()
	knockback_echo_active.clear()
	knockback_directions.clear()
	knockback_elapsed.clear()
	knockback_durations.clear()
	knockback_distances.clear()
	flash_frames_remaining.clear()
	for _spawn_point in spawn_points:
		knockback_echo_active.append(false)
		knockback_directions.append(Vector2.ZERO)
		knockback_elapsed.append(0.0)
		knockback_durations.append(0.0)
		knockback_distances.append(0.0)
		flash_frames_remaining.append(0)
	queue_redraw()


func _process(delta: float) -> void:
	var needs_redraw := false
	for index in positions.size():
		if knockback_echo_active[index]:
			knockback_elapsed[index] = minf(knockback_elapsed[index] + delta, knockback_durations[index])
			var progress := knockback_elapsed[index] / knockback_durations[index]
			var eased_distance := knockback_distances[index] * (1.0 - pow(1.0 - progress, 2.0))
			knockback_echo_positions[index] = spawn_positions[index] + knockback_directions[index] * eased_distance
			if knockback_elapsed[index] >= knockback_durations[index]:
				knockback_echo_active[index] = false
			needs_redraw = true
		if flash_frames_remaining[index] > 0:
			flash_frames_remaining[index] -= 1
			needs_redraw = true
	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	if not _g0_render_enabled:
		return
	for index in positions.size():
		_draw_active_enemy(positions[index])
		if knockback_echo_active[index]:
			_draw_knockback_echo(index)


func find_swept_hit(origin: Vector2, aim_angle: float, from_local_angle: float, to_local_angle: float, reach: float) -> int:
	for index in positions.size():
		var offset := positions[index] - origin
		var distance := offset.length()
		if distance <= 0.001 or distance > reach + ENEMY_RADIUS:
			continue
		var relative_angle := wrapf(offset.angle() - aim_angle, -PI, PI)
		var angular_padding := asin(minf(1.0, ENEMY_RADIUS / distance))
		if relative_angle >= from_local_angle - angular_padding and relative_angle <= to_local_angle + angular_padding:
			return index
	return -1


func hit_enemy(index: int, direction: Vector2) -> void:
	positions[index] = spawn_positions[index]
	knockback_echo_positions[index] = spawn_positions[index]
	knockback_echo_active[index] = true
	knockback_directions[index] = direction.normalized()
	knockback_elapsed[index] = 0.0
	knockback_durations[index] = maxf(_tuning.knockback_decay, 0.001)
	knockback_distances[index] = _tuning.knockback_distance
	flash_frames_remaining[index] = _tuning.flash_frames
	queue_redraw()


func get_enemy_position(index: int) -> Vector2:
	return positions[index]


func set_g0_render_enabled(enabled: bool) -> void:
	_g0_render_enabled = enabled
	queue_redraw()


func _draw_active_enemy(center: Vector2) -> void:
	draw_circle(center, ENEMY_RADIUS + 9.0, Color(0.0, 0.898, 0.816, 0.07))
	draw_circle(center, ENEMY_RADIUS + 5.0, Color(0.0, 0.898, 0.816, 0.14))
	draw_circle(center, ENEMY_RADIUS, BODY_COLOR)
	draw_arc(center, ENEMY_RADIUS + 1.5, 0.0, TAU, ARC_POINTS, OUTLINE_COLOR, 2.5, true)


func _draw_knockback_echo(index: int) -> void:
	var center := knockback_echo_positions[index]
	if flash_frames_remaining[index] > 0:
		draw_circle(center, ENEMY_RADIUS + 2.0, FLASH_COLOR)
		return
	var life_ratio := 1.0 - knockback_elapsed[index] / knockback_durations[index]
	draw_circle(center, ENEMY_RADIUS, Color(BODY_COLOR.r, BODY_COLOR.g, BODY_COLOR.b, life_ratio * 0.72))
	draw_arc(center, ENEMY_RADIUS + 1.5, 0.0, TAU, ARC_POINTS, Color(OUTLINE_COLOR.r, OUTLINE_COLOR.g, OUTLINE_COLOR.b, life_ratio), 2.0, true)
