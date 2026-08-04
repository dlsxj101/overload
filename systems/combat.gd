class_name CombatSystem
extends Node2D

const SPARK_COUNT := 6
const SPARK_SPEED := 180.0
const SPARK_LIFETIME := 0.11
const SPARK_SPREAD_RADIANS := 0.75
const SPARK_COLOR := Color("00e5d0")

var _tuning: JuiceTuning
var _enemy_pool: EnemyPool
var _hitstop: Hitstop
var _camera_shake: DirectionalCameraShake
var _audio_hit: LayeredHitAudio
var _spark_positions: Array[Vector2] = []
var _spark_velocities: Array[Vector2] = []
var _spark_lifetimes: Array[float] = []


func configure(
	tuning_resource: JuiceTuning,
	enemy_pool: EnemyPool,
	hitstop: Hitstop,
	camera_shake: DirectionalCameraShake,
	audio_hit: LayeredHitAudio
) -> void:
	_tuning = tuning_resource
	_enemy_pool = enemy_pool
	_hitstop = hitstop
	_camera_shake = camera_shake
	_audio_hit = audio_hit


func _process(delta: float) -> void:
	if _spark_positions.is_empty():
		return
	for index in range(_spark_positions.size() - 1, -1, -1):
		_spark_lifetimes[index] -= delta
		if _spark_lifetimes[index] <= 0.0:
			_spark_positions.remove_at(index)
			_spark_velocities.remove_at(index)
			_spark_lifetimes.remove_at(index)
			continue
		_spark_positions[index] += _spark_velocities[index] * delta
		_spark_velocities[index] *= maxf(0.0, 1.0 - delta * 12.0)
	queue_redraw()


func _draw() -> void:
	for index in _spark_positions.size():
		var life_ratio := _spark_lifetimes[index] / SPARK_LIFETIME
		var velocity_direction := _spark_velocities[index].normalized()
		var tail := _spark_positions[index] - velocity_direction * 9.0 * life_ratio
		draw_line(tail, _spark_positions[index], Color(SPARK_COLOR, life_ratio), 2.0, true)


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
	_spawn_sparks(impact_position, hit_direction)
	_camera_shake.kick(hit_direction, _tuning.shake_distance, _tuning.shake_return_time)
	_audio_hit.play_hit()
	_hitstop.begin(_tuning.hitstop_duration)
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
