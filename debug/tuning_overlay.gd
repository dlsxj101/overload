class_name TuningOverlay
extends CanvasLayer

const PRESET_DIRECTORY := "res://tuning/presets"
const USER_PRESET_PATH := "user://m1_user_preset.tres"
const UI_FONT: Font = preload("res://fonts/BlackHanSans-Regular.ttf")
const PANEL_WIDTH := 430.0
const PANEL_HEIGHT := 508.0
const BUILTIN_PRESET_NAMES := [
	"arc_flash",
	"balanced_default",
	"brutal_stop",
	"cinematic",
	"close_quarters",
	"contest_safe",
	"crunchy",
	"deep_impact",
	"deliberate",
	"directional_push",
	"elastic",
	"heavy_slow",
	"light_fast",
	"long_reach",
	"low_shake",
	"precision",
	"rapid_chain",
	"snappy",
	"white_hot",
	"wide_cleave",
]

var _tuning: JuiceTuning
var _hitstop: Hitstop
var _panel: PanelContainer
var _stats_label: Label
var _status_label: Label
var _preset_picker: OptionButton
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _preset_paths: Array[String] = []
var _preset_names: Array[String] = []
var _snapshot_a: JuiceTuning
var _snapshot_b: JuiceTuning
var _showing_a := true
var _syncing_controls := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100


func configure(tuning_resource: JuiceTuning, hitstop: Hitstop) -> void:
	_tuning = tuning_resource
	_hitstop = hitstop
	_build_interface()
	_load_preset_list()
	_snapshot_a = _tuning.make_snapshot()
	_snapshot_b = _load_snapshot_or_default("res://tuning/presets/heavy_slow.tres")
	_sync_controls()


func _process(_delta: float) -> void:
	if _stats_label == null:
		return
	_stats_label.text = "FPS  %d    마지막 히트스톱  %.4f초" % [
		Engine.get_frames_per_second(),
		_hitstop.last_measured_duration,
	]


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F2:
		_toggle_ab()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	_panel = PanelContainer.new()
	_panel.name = "TuningPanel"
	_panel.position = Vector2(14.0, 14.0)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.visible = false
	var panel_theme := Theme.new()
	panel_theme.default_font = UI_FONT
	panel_theme.default_font_size = 14
	_panel.theme = panel_theme
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)

	var title := Label.new()
	title.text = "M1 타격감 튜닝  ·  F1 닫기"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)

	_stats_label = Label.new()
	_stats_label.text = "FPS  0    마지막 히트스톱  0.0000초"
	content.add_child(_stats_label)
	content.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 286.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	var parameter_list := VBoxContainer.new()
	parameter_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parameter_list.add_theme_constant_override("separation", 4)
	scroll.add_child(parameter_list)

	for spec: Dictionary in JuiceTuning.PARAMETER_SPECS:
		_add_parameter_row(parameter_list, spec)

	var preset_row := HBoxContainer.new()
	_preset_picker = OptionButton.new()
	_preset_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_row.add_child(_preset_picker)
	var load_built_in := _make_button("프리셋 적용", _apply_selected_preset)
	preset_row.add_child(load_built_in)
	preset_row.add_child(_make_button("정답 공개", _reveal_selected_preset))
	content.add_child(preset_row)

	var file_row := HBoxContainer.new()
	file_row.add_child(_make_button("현재값 복사", _copy_values))
	file_row.add_child(_make_button("사용자 저장", _save_user_preset))
	file_row.add_child(_make_button("사용자 불러오기", _load_user_preset))
	content.add_child(file_row)

	var ab_row := HBoxContainer.new()
	ab_row.add_child(_make_button("A 캡처", _capture_a))
	ab_row.add_child(_make_button("B 캡처", _capture_b))
	ab_row.add_child(_make_button("A/B 전환  F2", _toggle_ab))
	content.add_child(ab_row)

	_status_label = Label.new()
	_status_label.text = "A 사용 중 · F2로 즉시 비교"
	_status_label.add_theme_color_override("font_color", Color("00e5d0"))
	content.add_child(_status_label)


func _add_parameter_row(parent: VBoxContainer, spec: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = spec["label"]
	name_label.custom_minimum_size.x = 112.0
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = spec["min"]
	slider.max_value = spec["max"]
	slider.step = spec["step"]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 62.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	var key: String = spec["key"]
	_sliders[key] = slider
	_value_labels[key] = value_label
	slider.value_changed.connect(_on_slider_changed.bind(key, value_label, spec["integer"]))


func _make_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _on_slider_changed(value: float, key: String, value_label: Label, integer_value: bool) -> void:
	if integer_value:
		value_label.text = str(int(round(value)))
	else:
		value_label.text = "%.3f" % value
	if _syncing_controls:
		return
	_tuning.set(key, int(round(value)) if integer_value else value)
	_tuning.emit_changed()


func _sync_controls() -> void:
	_syncing_controls = true
	for spec: Dictionary in JuiceTuning.PARAMETER_SPECS:
		var key: String = spec["key"]
		var value: Variant = _tuning.get(key)
		var slider: HSlider = _sliders[key]
		var value_label: Label = _value_labels[key]
		slider.value = float(value)
		value_label.text = str(int(value)) if spec["integer"] else "%.3f" % float(value)
	_syncing_controls = false


func _load_preset_list() -> void:
	var shuffled_names: Array = BUILTIN_PRESET_NAMES.duplicate()
	shuffled_names.shuffle()
	for preset_name: String in shuffled_names:
		_preset_paths.append("%s/%s.tres" % [PRESET_DIRECTORY, preset_name])
		_preset_names.append(preset_name)
		_preset_picker.add_item("후보 %02d" % (_preset_picker.item_count + 1))
		if preset_name == "balanced_default":
			_preset_picker.select(_preset_picker.item_count - 1)


func _apply_selected_preset() -> void:
	var selected := _preset_picker.selected
	if selected < 0 or selected >= _preset_paths.size():
		return
	var preset := ResourceLoader.load(_preset_paths[selected]) as JuiceTuning
	if preset == null:
		_set_status("프리셋 불러오기 실패")
		return
	_tuning.copy_from(preset)
	_sync_controls()
	_set_status("적용: %s" % _preset_picker.get_item_text(selected))


func _reveal_selected_preset() -> void:
	var selected := _preset_picker.selected
	if selected < 0 or selected >= _preset_names.size():
		return
	_set_status("%s 정답: %s" % [_preset_picker.get_item_text(selected), _preset_names[selected]])


func _copy_values() -> void:
	DisplayServer.clipboard_set(_tuning.values_text())
	_set_status("현재 값 전체를 클립보드에 복사함")


func _save_user_preset() -> void:
	var snapshot := _tuning.make_snapshot()
	var result := ResourceSaver.save(snapshot, USER_PRESET_PATH)
	_set_status("사용자 프리셋 저장 완료" if result == OK else "사용자 프리셋 저장 실패: %d" % result)


func _load_user_preset() -> void:
	if not ResourceLoader.exists(USER_PRESET_PATH):
		_set_status("저장된 사용자 프리셋 없음")
		return
	var preset := ResourceLoader.load(USER_PRESET_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as JuiceTuning
	if preset == null:
		_set_status("사용자 프리셋 불러오기 실패")
		return
	_tuning.copy_from(preset)
	_sync_controls()
	_set_status("사용자 프리셋 불러오기 완료")


func _capture_a() -> void:
	_snapshot_a = _tuning.make_snapshot()
	_showing_a = true
	_set_status("현재 값을 A에 캡처")


func _capture_b() -> void:
	_snapshot_b = _tuning.make_snapshot()
	_showing_a = false
	_set_status("현재 값을 B에 캡처")


func _toggle_ab() -> void:
	if _snapshot_a == null or _snapshot_b == null:
		return
	_showing_a = not _showing_a
	_tuning.copy_from(_snapshot_a if _showing_a else _snapshot_b)
	_sync_controls()
	_set_status("%s 사용 중 · F2로 즉시 비교" % ("A" if _showing_a else "B"))


func _load_snapshot_or_default(path: String) -> JuiceTuning:
	var preset := ResourceLoader.load(path) as JuiceTuning
	return preset.make_snapshot() if preset != null else _tuning.make_snapshot()


func _set_status(message: String) -> void:
	_status_label.text = message
