extends SceneTree


func _initialize() -> void:
	_show_preview.call_deferred()


func _show_preview() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var overlay := main.get_node("TuningOverlay") as TuningOverlay
	var panel := overlay.get("_panel") as PanelContainer
	panel.visible = true
	for frame_index in 8:
		await process_frame
	quit(0)
