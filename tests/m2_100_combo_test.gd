extends SceneTree

const HIT_TARGET := 100

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var combat := main.get_node("Combat") as CombatSystem
	var hitstop := main.get_node("Hitstop") as Hitstop
	var enemy_pool := main.get_node("EnemyPool") as EnemyPool
	var player := main.get_node("Player") as PlayerController
	var combo := main.get_node("Combo") as ComboSystem

	var completed_hits := 0
	for hit_index in HIT_TARGET:
		var hit_registered := combat.perform_sweep(
			player.global_position,
			0.0,
			-0.7,
			0.7,
			player.get_effective_sword_reach()
		)
		if not hit_registered:
			_failures.append("%d번째 타격 판정 실패" % (hit_index + 1))
			break
		var expected_hitstop := combo.get_hitstop_duration()
		while hitstop.is_active():
			await process_frame
		if hitstop.last_measured_duration + 0.001 < expected_hitstop:
			_failures.append("%d번째 티어 히트스톱 부족" % (hit_index + 1))
			break
		completed_hits += 1

	_check(completed_hits == HIT_TARGET, "실제 히트스톱을 거친 100회 연속 타격")
	_check(combo.combo_count == 100, "적 처치마다 콤보 +1")
	_check(combo.current_tier == 4, "100회째 티어 4 도달")
	_check(is_equal_approx(player.get_effective_sword_reach(), main.JUICE.sword_reach * 3.0), "100회째 실제 칼 판정 3.0배")
	_check(enemy_pool.positions.size() == 1, "더미 1마리 즉시 재생성 유지")

	_stop_audio_recursive(main)
	var audio_release_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - audio_release_started < 80:
		await process_frame
	root.remove_child(main)
	main.free()
	_finish()


func _stop_audio_recursive(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio_recursive(child)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("M2_100_COMBO_TECHNICAL_PASS")
		_quit_after_cleanup.call_deferred(0)
	else:
		print("M2_100_COMBO_TECHNICAL_FAIL: ", ", ".join(_failures))
		_quit_after_cleanup.call_deferred(1)


func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	await process_frame
	quit(exit_code)
