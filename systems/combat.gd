class_name CombatSystem
extends Node2D

const SPARK_COUNT := 6
const SPARK_SPEED := 180.0
const SPARK_LIFETIME := 0.11
const SPARK_SPREAD_RADIANS := 0.75
const SPARK_COLOR := Color("00e5d0")
const ELECTRIC_SEGMENTS := 4

var _tuning: JuiceTuning
var _enemy_pool: EnemyPool
var _hitstop: Hitstop
var _camera_shake: DirectionalCameraShake
var _audio_hit: LayeredHitAudio
var _combo: ComboSystem
var _spark_positions: Array[Vector2] = []
var _spark_velocities: Array[Vector2] = []
var _spark_lifetimes: Array[float] = []
var _electric_origins: Array[Vector2] = []
var _electric_directions: Array[Vector2] = []
var _electric_lifetimes: Array[float] = []
var _electric_seeds: Array[int] = []
var _g0_effects_enabled := true


func configure(
	tuning_resource: JuiceTuning,
	enemy_pool: EnemyPool,
	hitstop: Hitstop,
	camera_shake: DirectionalCameraShake,
	audio_hit: LayeredHitAudio,
	combo: ComboSystem
) -> void:
	_tuning = tuning_resource
	_enemy_pool = enemy_pool
	_hitstop = hitstop
	_camera_shake = camera_shake
	_audio_hit = audio_hit
	_combo = combo


func _process(delta: float) -> void:
	for index in range(_spark_positions.size() - 1, -1, -1):
		_spark_lifetimes[index] -= delta
		if _spark_lifetimes[index] <= 0.0:
			_spark_positions.remove_at(index)
			_spark_velocities.remove_at(index)
			_spark_lifetimes.remove_at(index)
			continue
		_spark_positions[index] += _spark_velocities[index] * delta
		_spark_velocities[index] *= maxf(0.0, 1.0 - delta * 12.0)
	for index in range(_electric_origins.size() - 1, -1, -1):
		_electric_lifetimes[index] -= delta
		if _electric_lifetimes[index] <= 0.0:
			_electric_origins.remove_at(index)
			_electric_directions.remove_at(index)
			_electric_lifetimes.remove_at(index)
			_electric_seeds.remove_at(index)
	if not _spark_positions.is_empty() or not _electric_origins.is_empty():
		queue_redraw()


func _draw() -> void:
	if not _g0_effects_enabled:
		return
	for index in _spark_positions.size():
		var life_ratio := _spark_lifetimes[index] / SPARK_LIFETIME
		var velocity_direction := _spark_velocities[index].normalized()
		var tail := _spark_positions[index] - velocity_direction * 9.0 * life_ratio
		draw_line(tail, _spark_positions[index], Color(SPARK_COLOR, life_ratio), 2.0, true)
	for index in _electric_origins.size():
		_draw_electric_bolt(index)


func perform_sweep(
	origin: Vector2,
	aim_angle: float,
	from_local_angle: float,
	to_local_angle: float,
	reach: float
) -> bool:
	var enemy_index := _enemy_pool.find_swept_hit(origin, aim_angle, from_local_angle, to_local_angle, reach)
	if enemy_index < 0:
		return false

	var impact_position := _enemy_pool.get_enemy_position(enemy_index)
	var hit_direction := (impact_position - origin).normalized()
	if hit_direction.is_zero_approx():
		hit_direction = Vector2.from_angle(aim_angle)

	_enemy_pool.hit_enemy(enemy_index, hit_direction)
	var tier := _combo.register_kill()
	if _g0_effects_enabled:
		_spawn_sparks(impact_position, hit_direction)
		if tier >= 3:
			_spawn_electric_sparks(impact_position, hit_direction)
	_camera_shake.kick(hit_direction, _tuning.shake_distance, _tuning.shake_return_time)
	_audio_hit.play_hit(tier)
	_hitstop.begin(_combo.get_hitstop_duration())
	return true


func _spawn_sparks(impact_position: Vector2, direction: Vector2) -> void:
	for spark_index in SPARK_COUNT:
		var normalized_index := float(spark_index) / float(maxi(SPARK_COUNT - 1, 1))
		var spread_angle := lerpf(-SPARK_SPREAD_RADIANS, SPARK_SPREAD_RADIANS, normalized_index)
		var speed_weight := 0.72 + 0.28 * sin(float(spark_index + 1) * 2.17)
		_spark_positions.append(impact_position)
		_spark_velocities.append(direction.rotated(spread_angle) * SPARK_SPEED * speed_weight)
		_spark_lifetimes.append(SPARK_LIFETIME)
	queue_redraw()


func _spawn_electric_sparks(impact_position: Vector2, direction: Vector2) -> void:
	var bolt_count := maxi(1, _tuning.electric_bolt_count)
	for bolt_index in bolt_count:
		var normalized_index := float(bolt_index) / float(maxi(bolt_count - 1, 1))
		var spread_angle := lerpf(-1.25, 1.25, normalized_index)
		_electric_origins.append(impact_position)
		_electric_directions.append(direction.rotated(spread_angle))
		_electric_lifetimes.append(_tuning.electric_bolt_lifetime)
		_electric_seeds.append((bolt_index + 1) * 37 + _combo.combo_count * 11)
	queue_redraw()


func _draw_electric_bolt(index: int) -> void:
	var life_ratio := _electric_lifetimes[index] / maxf(_tuning.electric_bolt_lifetime, 0.001)
	var direction := _electric_directions[index]
	var side := direction.orthogonal()
	var points := PackedVector2Array()
	for segment_index in ELECTRIC_SEGMENTS + 1:
		var progress := float(segment_index) / float(ELECTRIC_SEGMENTS)
		var edge_fade := sin(PI * progress)
		var phase := float(_electric_seeds[index] + segment_index * 19) + _electric_lifetimes[index] * 47.0
		var jitter := sin(phase) * _tuning.electric_bolt_jitter * edge_fade
		points.append(
			_electric_origins[index]
			+ direction * _tuning.electric_bolt_length * progress
			+ side * jitter
		)
	draw_polyline(points, Color(0.0, 0.898, 0.816, life_ratio * 0.72), _tuning.electric_bolt_width * 2.0, true)
	draw_polyline(points, Color(1.0, 1.0, 1.0, life_ratio), _tuning.electric_bolt_width, true)


func set_g0_effects_enabled(enabled: bool) -> void:
	_g0_effects_enabled = enabled
	if enabled:
		return
	_spark_positions.clear()
	_spark_velocities.clear()
	_spark_lifetimes.clear()
	_electric_origins.clear()
	_electric_directions.clear()
	_electric_lifetimes.clear()
	_electric_seeds.clear()
	queue_redraw()
