extends SceneTree

const HIT_TARGET := 100


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var combat := main.get_node("Combat") as CombatSystem
	var hitstop := main.get_node("Hitstop") as Hitstop
	var enemy_pool := main.get_node("EnemyPool") as EnemyPool
	var audio_hit := main.get_node("AudioHit") as LayeredHitAudio

	var completed_hits := 0
	for hit_index in HIT_TARGET:
		if not combat.perform_sweep(Vector2(510.0, 270.0), 0.0, -0.7, 0.7, main.JUICE.sword_reach):
			push_error("100회 연속 타격 중 %d번째 판정 실패" % (hit_index + 1))
			break
		while hitstop.is_active():
			await process_frame
		completed_hits += 1

	if completed_hits == HIT_TARGET and enemy_pool.positions.size() == 1:
		print("M1_100_HIT_TECHNICAL_PASS")
	else:
		push_error("M1_100_HIT_TECHNICAL_FAIL: %d회" % completed_hits)

	for audio_player in audio_hit.get_children():
		if audio_player is AudioStreamPlayer:
			audio_player.stop()
			audio_player.stream = null
	var audio_release_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - audio_release_started < 80:
		await process_frame
	root.remove_child(main)
	main.free()
	_quit_after_cleanup.call_deferred(0 if completed_hits == HIT_TARGET else 1)


func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	await process_frame
	quit(exit_code)
